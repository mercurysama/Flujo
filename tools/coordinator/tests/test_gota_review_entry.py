from __future__ import annotations

import hashlib
import json
import sqlite3
import subprocess
import tempfile
import unittest
from dataclasses import replace
from datetime import UTC, datetime, timedelta
from pathlib import Path

from flow_coordinator import (
    GOTA_PROTOCOL,
    GotaCheckpoint,
    GotaMessage,
    GotaPhase,
    GotaRequest,
    GotaWorkerResult,
    GotaWorkerReviewBoundary,
    GotaWorkerReviewBoundaryError,
    WorkerResultStatus,
)
from flow_coordinator.domain import Lease, TaskSpec, TaskState, isoformat
from flow_coordinator.git_adapter import GitSnapshot, ReadOnlyGitAdapter
from flow_coordinator.service import CoordinatorService
from flow_coordinator.store import (
    AcceptanceEvidenceError,
    FencingTokenError,
    LeaseExpiredError,
    SQLiteCoordinatorStore,
)


def _canonical_json(value: object) -> str:
    return json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=False)


def _digest(value: object) -> str:
    return hashlib.sha256(_canonical_json(value).encode("utf-8")).hexdigest()


class SpyReadOnlyGitAdapter(ReadOnlyGitAdapter):
    def __init__(self, repository: str | Path) -> None:
        super().__init__(repository)
        self.commands: list[str] = []
        self.snapshot_count = 0

    def snapshot(self) -> GitSnapshot:
        self.snapshot_count += 1
        return super().snapshot()

    def _run_bytes(self, *arguments: str) -> bytes:
        self.commands.append(arguments[0])
        return super()._run_bytes(*arguments)

    def is_ancestor(self, ancestor_sha: str, descendant_sha: str) -> bool:
        self.commands.append("merge-base")
        return super().is_ancestor(ancestor_sha, descendant_sha)


class RefChangingReadOnlyGitAdapter(SpyReadOnlyGitAdapter):
    def __init__(self, repository: str | Path) -> None:
        super().__init__(repository)
        self.snapshot_count = 0

    def snapshot(self) -> GitSnapshot:
        self.snapshot_count += 1
        snapshot = ReadOnlyGitAdapter.snapshot(self)
        if self.snapshot_count == 2:
            return replace(
                snapshot,
                refs=tuple(
                    (*snapshot.refs, ("refs/tags/observed-mutation", snapshot.head, ""))
                ),
            )
        return snapshot


class ReviewRefChangingReadOnlyGitAdapter(SpyReadOnlyGitAdapter):
    def snapshot(self) -> GitSnapshot:
        self.snapshot_count += 1
        snapshot = ReadOnlyGitAdapter.snapshot(self)
        return replace(
            snapshot,
            refs=tuple(
                (*snapshot.refs, ("refs/tags/review-tamper", snapshot.head, ""))
            ),
        )


class SequencedClockStore(SQLiteCoordinatorStore):
    def __init__(self, path: str | Path, trusted_times: tuple[datetime, ...]) -> None:
        self._trusted_times = iter(trusted_times)
        self._last_trusted_time = trusted_times[-1]
        super().__init__(path)

    def _trusted_now(self) -> datetime:
        try:
            self._last_trusted_time = next(self._trusted_times)
        except StopIteration:
            pass
        return self._last_trusted_time


class FailsAfterAnchorStore(SQLiteCoordinatorStore):
    def __init__(self, path: str | Path) -> None:
        self.fence_checks = 0
        super().__init__(path)

    def _assert_fenced_connection(self, connection, lease, current_time) -> None:
        super()._assert_fenced_connection(connection, lease, current_time)
        self.fence_checks += 1
        if self.fence_checks == 2:
            raise GotaWorkerReviewBoundaryError("controlled after-anchor rollback")


class ReviewEntryTest(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary_directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary_directory.cleanup)
        self.root = Path(self.temporary_directory.name)
        self.repository = self.root / "repository"
        self.repository.mkdir()
        self._git("init", "--initial-branch=feature/gota-review-entry")
        self._git("config", "user.name", "Gota Review Entry Test")
        self._git("config", "user.email", "gota-review-entry@example.invalid")
        (self.repository / "src").mkdir()
        (self.repository / "src/change.py").write_text(
            "value = 'base'\n", encoding="utf-8"
        )
        self._git("add", "--", "src/change.py")
        self._git("commit", "-m", "fixture base")
        self.base_sha = self._git("rev-parse", "HEAD")

        self.database = self.root / "coordinator.sqlite3"
        self.store = SQLiteCoordinatorStore(self.database)
        self.service = CoordinatorService(self.store)
        spec = TaskSpec(
            task_id="review-entry-task",
            title="Review entry task",
            objective="Persist the verified Worker frontier",
            project_id="review-entry-project",
            repository_id="review-entry-repository",
            branch="feature/gota-review-entry",
            base_sha=self.base_sha,
            context_id="review-entry-context",
            allowed_paths=("src/change.py",),
            protected_paths=("demo/main.tscn", "export_presets.cfg"),
            required_resources=(),
            acceptance_criteria=("Enter REVIEW only after independent Git verification",),
            commit_message="test: verified Worker review entry",
        )
        self.run = self.service.create_task(spec, {"workspace": str(self.repository)})
        self.lease = self.service.start(self.run.run_id, owner_id="worker")
        self.request = GotaRequest(
            protocol=GOTA_PROTOCOL,
            request_id=f"{self.run.run_id}:1:worker",
            task_id=spec.task_id,
            run_id=self.run.run_id,
            attempt=1,
            phase=GotaPhase.WORKER,
            objective=spec.objective,
            acceptance_criteria=spec.acceptance_criteria,
            workspace=str(self.repository),
            branch=spec.branch,
            base_sha=spec.base_sha,
            allowed_paths=spec.allowed_paths,
            protected_paths=spec.protected_paths,
        )

    def _git(self, *arguments: str) -> str:
        result = subprocess.run(
            ("git", *arguments),
            cwd=self.repository,
            check=True,
            capture_output=True,
            text=True,
        )
        return result.stdout.rstrip("\n")

    def _worker_result(
        self,
        *,
        commit_sha: str,
        changed_paths: tuple[str, ...] = ("src/change.py",),
        run_id: str | None = None,
        task_id: str | None = None,
    ) -> GotaWorkerResult:
        return GotaWorkerResult(
            protocol=GOTA_PROTOCOL,
            message=GotaMessage.WORKER_RESULT.value,
            request_id=f"{run_id or self.run.run_id}:1:worker",
            task_id=task_id or self.run.task_id,
            run_id=run_id or self.run.run_id,
            attempt=1,
            result=WorkerResultStatus.READY_FOR_REVIEW,
            commit_sha=commit_sha,
            changed_paths=changed_paths,
            evidence=({"kind": "worker", "passed": True},),
            checkpoint=GotaCheckpoint(
                completed_steps=("implementation",), remaining_phase="review"
            ),
        )

    def _commit_worker(self, *, count: int = 1) -> str:
        for index in range(count):
            (self.repository / "src/change.py").write_text(
                f"value = 'worker-{index}'\n", encoding="utf-8"
            )
            self._git("add", "--", "src/change.py")
            self._git("commit", "-m", f"worker change {index}")
        return self._git("rev-parse", "HEAD")

    def _durable_worker(
        self,
        *,
        changed_paths: tuple[str, ...] = ("src/change.py",),
        request: GotaRequest | None = None,
        result: GotaWorkerResult | None = None,
        commit_count: int = 1,
    ) -> tuple[GotaRequest, GotaWorkerResult, str]:
        request = request or self.request
        self.store.reserve_gota_worker_invocation(
            self.run.run_id, request, self.lease
        )
        commit_sha = self._commit_worker(count=commit_count)
        result = result or self._worker_result(
            commit_sha=commit_sha, changed_paths=changed_paths
        )
        self.store.persist_gota_worker_result(self.run.run_id, result, self.lease)
        return request, result, commit_sha

    def _takeover_lease(self) -> Lease:
        takeover_now = self.lease.expires_at + timedelta(seconds=1)
        with self.store.transaction(immediate=True) as connection:
            connection.execute(
                "UPDATE global_lock SET lease_expires_at = ? WHERE lock_name = 'global'",
                (isoformat(self.lease.expires_at),),
            )
        with self.assertRaises(LeaseExpiredError):
            self.service.locks.acquire(
                "reviewer-b", self.run.run_id, now=takeover_now
            )
        self.service.locks.recover_stale(authorized=True)
        return self.service.locks.acquire(
            "reviewer-b", self.run.run_id, now=takeover_now
        )

    def _boundary(
        self,
        *,
        store: SQLiteCoordinatorStore | None = None,
        git: ReadOnlyGitAdapter | None = None,
    ) -> GotaWorkerReviewBoundary:
        return GotaWorkerReviewBoundary(
            self.repository,
            store=store or self.store,
            git=git,
        )

    def _rewrite_evidence(
        self,
        evidence_id: str,
        payload: dict[str, object],
        digest: str,
    ) -> None:
        with self.store.transaction(immediate=True) as connection:
            connection.execute("DROP TRIGGER immutable_evidence_update")
            connection.execute(
                """
                UPDATE evidence
                SET payload_json = ?, digest = ?
                WHERE evidence_id = ?
                """,
                (_canonical_json(payload), digest, evidence_id),
            )

    def _rewrite_anchor(self, field: str, value: object) -> None:
        self.assertIn(
            field,
            {
                "commit_evidence_id",
                "commit_evidence_digest",
                "transition_event_id",
                "created_at",
            },
        )
        with self.store.transaction(immediate=True) as connection:
            connection.execute("DROP TRIGGER immutable_gota_worker_review_boundaries_update")
            connection.execute(
                f"UPDATE gota_worker_review_boundaries SET {field} = ? WHERE run_id = ?",
                (value, self.run.run_id),
            )

    def _rewrite_event_created_at(self, event_id: int, value: datetime) -> None:
        with self.store.transaction(immediate=True) as connection:
            connection.execute("DROP TRIGGER immutable_transition_events_update")
            connection.execute(
                "UPDATE transition_events SET created_at = ? WHERE event_id = ?",
                (isoformat(value), event_id),
            )

    def _rewrite_evidence_created_at(self, evidence_id: str, value: datetime) -> None:
        with self.store.transaction(immediate=True) as connection:
            connection.execute("DROP TRIGGER immutable_evidence_update")
            connection.execute(
                "UPDATE evidence SET created_at = ? WHERE evidence_id = ?",
                (isoformat(value), evidence_id),
            )

    def _rewrite_evidence_id_without_foreign_keys(
        self, evidence_id: str, replacement: str
    ) -> None:
        connection = sqlite3.connect(self.database)
        try:
            connection.execute("DROP TRIGGER immutable_evidence_update")
            connection.execute(
                "UPDATE evidence SET evidence_id = ? WHERE evidence_id = ?",
                (replacement, evidence_id),
            )
            connection.commit()
        finally:
            connection.close()

    def test_happy_path_is_atomic_and_auditable(self) -> None:
        _request, result, commit_sha = self._durable_worker()
        entered = self._boundary().run(
            self.run.run_id,
            self.lease,
            attempt=result.attempt,
            request_id=result.request_id,
        )

        self.assertEqual(entered.state, TaskState.REVIEW)
        self.assertTrue(entered.created)
        self.assertEqual(entered.commit_sha, commit_sha)
        evidence = self.store.list_evidence(self.run.run_id)
        self.assertEqual(
            [item.kind for item in evidence],
            [
                "gota_worker_request_registered",
                "gota_worker_invocation_started",
                "gota_worker_result_received",
                "gota_worker_commit_verified",
            ],
        )
        commit_evidence = evidence[-1]
        snapshot = ReadOnlyGitAdapter(self.repository).snapshot()
        self.assertEqual(
            dict(commit_evidence.payload),
            {
                "request_id": self.request.request_id,
                "task_id": self.request.task_id,
                "run_id": self.request.run_id,
                "attempt": self.request.attempt,
                "base_sha": self.request.base_sha,
                "commit_sha": commit_sha,
                "changed_paths": ["src/change.py"],
                "branch": self.request.branch,
                "head": commit_sha,
                "status": "",
                "refs": [list(ref) for ref in snapshot.refs],
                "request_evidence_id": evidence[0].evidence_id,
                "invocation_evidence_id": evidence[1].evidence_id,
                "result_evidence_id": evidence[2].evidence_id,
            },
        )

        events = self.store.list_events(self.run.run_id)
        self.assertEqual(events[-1].from_state, TaskState.RUNNING)
        self.assertEqual(events[-1].to_state, TaskState.REVIEW)
        self.assertEqual(events[-1].reason, "gota_worker_commit_verified")
        anchor = self.store.load_gota_worker_review_boundary(
            self.run.run_id, result.attempt, result.request_id
        )
        self.assertEqual(anchor.run_id, self.run.run_id)
        self.assertEqual(anchor.attempt, result.attempt)
        self.assertEqual(anchor.request_id, result.request_id)
        self.assertEqual(anchor.commit_evidence_id, commit_evidence.evidence_id)
        self.assertEqual(anchor.commit_evidence_digest, commit_evidence.digest)
        self.assertEqual(anchor.transition_event_id, events[-1].event_id)
        self.assertEqual(anchor.created_at, commit_evidence.created_at)
        self.assertEqual(anchor.created_at, events[-1].created_at)

        reopened = SQLiteCoordinatorStore(self.database)
        reopened_anchor = reopened.load_gota_worker_review_boundary(
            self.run.run_id, result.attempt, result.request_id
        )
        self.assertEqual(reopened_anchor, anchor)

    def test_takeover_after_worker_result_enters_review_with_new_lease(self) -> None:
        request, result, _sha = self._durable_worker()
        historical_evidence = self.store.list_evidence(self.run.run_id)
        historical_events = self.store.list_events(self.run.run_id)
        takeover = self._takeover_lease()

        entered = self._boundary().run(
            self.run.run_id,
            takeover,
            attempt=result.attempt,
            request_id=request.request_id,
        )

        self.assertEqual(entered.state, TaskState.REVIEW)
        self.assertTrue(entered.created)
        self.assertEqual(takeover.fencing_token, self.lease.fencing_token + 1)
        self.assertEqual(
            self.store.list_evidence(self.run.run_id)[: len(historical_evidence)],
            historical_evidence,
        )
        self.assertEqual(
            self.store.list_events(self.run.run_id)[: len(historical_events)],
            historical_events,
        )
        with self.assertRaises(FencingTokenError):
            self._boundary().run(
                self.run.run_id,
                self.lease,
                attempt=result.attempt,
                request_id=request.request_id,
            )
        self.assertEqual(self.store.get_run(self.run.run_id).state, TaskState.REVIEW)

    def test_missing_request_reservation_or_result_fails_closed(self) -> None:
        commit_sha = self._commit_worker()
        result = self._worker_result(commit_sha=commit_sha)
        self.store.persist_gota_worker_result(self.run.run_id, result, self.lease)
        with self.assertRaises(GotaWorkerReviewBoundaryError):
            self._boundary().run(
                self.run.run_id,
                self.lease,
                attempt=1,
                request_id=self.request.request_id,
            )

        self.setUp()
        self.store.reserve_gota_worker_invocation(
            self.run.run_id, self.request, self.lease
        )
        with self.assertRaises(GotaWorkerReviewBoundaryError):
            self._boundary().run(
                self.run.run_id,
                self.lease,
                attempt=1,
                request_id=self.request.request_id,
            )

    def test_incoherent_identity_fails_closed(self) -> None:
        reservation = self.store.reserve_gota_worker_invocation(
            self.run.run_id, self.request, self.lease
        )
        commit_sha = self._commit_worker()
        self.store.persist_gota_worker_result(
            self.run.run_id, self._worker_result(commit_sha=commit_sha), self.lease
        )
        tampered = replace(self.request, task_id="another-task").to_payload()
        self._rewrite_evidence(
            reservation.request_evidence.evidence_id, tampered, _digest(tampered)
        )
        with self.assertRaises(GotaWorkerReviewBoundaryError):
            self._boundary().run(
                self.run.run_id,
                self.lease,
                attempt=1,
                request_id=self.request.request_id,
            )

    def test_worker_sha_parent_and_multiple_commit_failures_do_not_promote(self) -> None:
        self._durable_worker(result=self._worker_result(commit_sha="a" * 40))
        with self.assertRaises(GotaWorkerReviewBoundaryError):
            self._boundary().run(
                self.run.run_id,
                self.lease,
                attempt=1,
                request_id=self.request.request_id,
            )
        self.assertEqual(self.store.get_run(self.run.run_id).state, TaskState.RUNNING)
        self.assertIsNone(
            self.store.load_gota_worker_commit_verified(
                self.run.run_id, 1, self.request.request_id
            )
        )

        self.setUp()
        wrong_base_request = replace(self.request, base_sha="0" * 40)
        self._durable_worker(request=wrong_base_request)
        with self.assertRaises(GotaWorkerReviewBoundaryError):
            self._boundary().run(
                self.run.run_id,
                self.lease,
                attempt=1,
                request_id=self.request.request_id,
            )

        self.setUp()
        request, result, _sha = self._durable_worker(commit_count=2)
        with self.assertRaises(GotaWorkerReviewBoundaryError):
            self._boundary().run(
                self.run.run_id,
                self.lease,
                attempt=result.attempt,
                request_id=request.request_id,
            )

    def test_worktree_changed_paths_and_branch_failures_do_not_promote(self) -> None:
        request, result, _sha = self._durable_worker(
            changed_paths=("other.py",)
        )
        with self.assertRaises(GotaWorkerReviewBoundaryError):
            self._boundary().run(
                self.run.run_id,
                self.lease,
                attempt=result.attempt,
                request_id=request.request_id,
            )

        self.setUp()
        request, result, _sha = self._durable_worker()
        (self.repository / "dirty.txt").write_text("dirty\n", encoding="utf-8")
        with self.assertRaises(GotaWorkerReviewBoundaryError):
            self._boundary().run(
                self.run.run_id,
                self.lease,
                attempt=result.attempt,
                request_id=request.request_id,
            )

        self.setUp()
        request, result, _sha = self._durable_worker()
        self._git("checkout", "-b", "unexpected-branch")
        with self.assertRaises(GotaWorkerReviewBoundaryError):
            self._boundary().run(
                self.run.run_id,
                self.lease,
                attempt=result.attempt,
                request_id=request.request_id,
            )

    def test_refs_are_fingerprinted_without_mutating_git(self) -> None:
        request, result, _sha = self._durable_worker()
        adapter = RefChangingReadOnlyGitAdapter(self.repository)
        with self.assertRaises(GotaWorkerReviewBoundaryError):
            self._boundary(git=adapter).run(
                self.run.run_id,
                self.lease,
                attempt=result.attempt,
                request_id=request.request_id,
            )
        self.assertEqual(self.store.get_run(self.run.run_id).state, TaskState.RUNNING)
        self.assertIsNone(
            self.store.load_gota_worker_commit_verified(
                self.run.run_id, 1, request.request_id
            )
        )
        self.assertTrue(set(adapter.commands).issubset(ReadOnlyGitAdapter._ALLOWED_COMMANDS))

    def test_atomic_failure_rolls_back_evidence_state_and_event(self) -> None:
        request, result, _sha = self._durable_worker()
        with self.store.transaction(immediate=True) as connection:
            connection.execute(
                """
                CREATE TRIGGER reject_review_entry
                BEFORE INSERT ON transition_events
                WHEN NEW.reason = 'gota_worker_commit_verified'
                BEGIN
                    SELECT RAISE(ABORT, 'controlled review-entry rollback');
                END
                """
            )
        try:
            with self.assertRaisesRegex(sqlite3.IntegrityError, "controlled review-entry rollback"):
                self._boundary().run(
                    self.run.run_id,
                    self.lease,
                    attempt=result.attempt,
                    request_id=request.request_id,
                )
        finally:
            with self.store.transaction(immediate=True) as connection:
                connection.execute("DROP TRIGGER reject_review_entry")
        self.assertEqual(self.store.get_run(self.run.run_id).state, TaskState.RUNNING)
        self.assertEqual(
            [item.kind for item in self.store.list_evidence(self.run.run_id)],
            [
                "gota_worker_request_registered",
                "gota_worker_invocation_started",
                "gota_worker_result_received",
            ],
        )
        self.assertEqual(self.store.list_events(self.run.run_id)[-1].to_state, TaskState.RUNNING)
        with self.store._connect() as connection:
            self.assertEqual(
                connection.execute(
                    "SELECT COUNT(*) FROM gota_worker_review_boundaries WHERE run_id = ?",
                    (self.run.run_id,),
                ).fetchone()[0],
                0,
            )

    def test_failure_after_anchor_rolls_back_everything(self) -> None:
        request, result, _sha = self._durable_worker()
        failing_store = FailsAfterAnchorStore(self.database)
        with self.assertRaisesRegex(
            GotaWorkerReviewBoundaryError, "controlled after-anchor rollback"
        ):
            GotaWorkerReviewBoundary(
                self.repository, store=failing_store
            ).run(
                self.run.run_id,
                self.lease,
                attempt=result.attempt,
                request_id=request.request_id,
            )
        self.assertEqual(failing_store.fence_checks, 2)
        self.assertEqual(failing_store.get_run(self.run.run_id).state, TaskState.RUNNING)
        self.assertIsNone(
            failing_store.load_gota_worker_commit_verified(
                self.run.run_id, result.attempt, request.request_id
            )
        )
        with failing_store._connect() as connection:
            self.assertEqual(
                connection.execute(
                    "SELECT COUNT(*) FROM gota_worker_review_boundaries WHERE run_id = ?",
                    (self.run.run_id,),
                ).fetchone()[0],
                0,
            )
        self.assertEqual(
            self.store.list_events(self.run.run_id)[-1].to_state,
            TaskState.RUNNING,
        )

    def test_failure_before_anchor_rolls_back_evidence_and_event(self) -> None:
        request, result, _sha = self._durable_worker()
        with self.store.transaction(immediate=True) as connection:
            connection.execute(
                """
                CREATE TRIGGER reject_review_boundary_anchor
                BEFORE INSERT ON gota_worker_review_boundaries
                BEGIN
                    SELECT RAISE(ABORT, 'controlled anchor rollback');
                END
                """
            )
        try:
            with self.assertRaisesRegex(sqlite3.IntegrityError, "controlled anchor rollback"):
                self._boundary().run(
                    self.run.run_id,
                    self.lease,
                    attempt=result.attempt,
                    request_id=request.request_id,
                )
        finally:
            with self.store.transaction(immediate=True) as connection:
                connection.execute("DROP TRIGGER reject_review_boundary_anchor")
        self.assertEqual(self.store.get_run(self.run.run_id).state, TaskState.RUNNING)
        self.assertIsNone(
            self.store.load_gota_worker_commit_verified(
                self.run.run_id, result.attempt, request.request_id
            )
        )
        with self.store._connect() as connection:
            self.assertEqual(
                connection.execute(
                    "SELECT COUNT(*) FROM gota_worker_review_boundaries WHERE run_id = ?",
                    (self.run.run_id,),
                ).fetchone()[0],
                0,
            )
        self.assertEqual(self.store.list_events(self.run.run_id)[-1].to_state, TaskState.RUNNING)

    def test_lease_expiry_during_final_verification_rolls_back(self) -> None:
        request, result, _sha = self._durable_worker()
        initial = datetime.now(UTC)
        final = initial + timedelta(seconds=2)
        with self.store.transaction(immediate=True) as connection:
            connection.execute(
                "UPDATE global_lock SET lease_expires_at = ? WHERE lock_name = 'global'",
                (isoformat(initial + timedelta(seconds=1)),),
            )
        clocked_store = SequencedClockStore(self.database, (initial, final))
        with self.assertRaises(LeaseExpiredError):
            GotaWorkerReviewBoundary(
                self.repository, store=clocked_store
            ).run(
                self.run.run_id,
                self.lease,
                attempt=result.attempt,
                request_id=request.request_id,
            )
        self.assertEqual(clocked_store.get_run(self.run.run_id).state, TaskState.RUNNING)
        self.assertIsNone(
            clocked_store.load_gota_worker_commit_verified(
                self.run.run_id, result.attempt, request.request_id
            )
        )
        with clocked_store._connect() as connection:
            self.assertEqual(
                connection.execute(
                    "SELECT COUNT(*) FROM gota_worker_review_boundaries WHERE run_id = ?",
                    (self.run.run_id,),
                ).fetchone()[0],
                0,
            )

    def test_anchor_evidence_id_tampering_fails_closed(self) -> None:
        request, result, _sha = self._durable_worker()
        self._boundary().run(
            self.run.run_id, self.lease, attempt=result.attempt, request_id=request.request_id
        )
        reservation = self.store.load_gota_worker_invocation(
            self.run.run_id, result.attempt, request.request_id
        )
        assert reservation is not None
        self._rewrite_anchor("commit_evidence_id", reservation.request_evidence.evidence_id)
        with self.assertRaises(GotaWorkerReviewBoundaryError):
            self._boundary().run(
                self.run.run_id,
                self.lease,
                attempt=result.attempt,
                request_id=request.request_id,
            )

    def test_anchor_digest_tampering_fails_closed(self) -> None:
        request, result, _sha = self._durable_worker()
        self._boundary().run(
            self.run.run_id, self.lease, attempt=result.attempt, request_id=request.request_id
        )
        self._rewrite_anchor("commit_evidence_digest", "0" * 64)
        with self.assertRaises(GotaWorkerReviewBoundaryError):
            self._boundary().run(
                self.run.run_id,
                self.lease,
                attempt=result.attempt,
                request_id=request.request_id,
            )

    def test_anchor_transition_event_id_tampering_fails_closed(self) -> None:
        request, result, _sha = self._durable_worker()
        self._boundary().run(
            self.run.run_id, self.lease, attempt=result.attempt, request_id=request.request_id
        )
        event_id = self.store.list_events(self.run.run_id)[0].event_id
        self._rewrite_anchor("transition_event_id", event_id)
        with self.assertRaises(GotaWorkerReviewBoundaryError):
            self._boundary().run(
                self.run.run_id,
                self.lease,
                attempt=result.attempt,
                request_id=request.request_id,
            )

    def test_anchor_and_authority_timestamps_must_match(self) -> None:
        request, result, _sha = self._durable_worker()
        self._boundary().run(
            self.run.run_id, self.lease, attempt=result.attempt, request_id=request.request_id
        )
        evidence = self.store.load_gota_worker_commit_verified(
            self.run.run_id, result.attempt, request.request_id
        )
        assert evidence is not None
        event_id = self.store.list_events(self.run.run_id)[-1].event_id
        self._rewrite_anchor("created_at", isoformat(evidence.created_at + timedelta(seconds=1)))
        with self.assertRaises(GotaWorkerReviewBoundaryError):
            self._boundary().run(
                self.run.run_id,
                self.lease,
                attempt=result.attempt,
                request_id=request.request_id,
            )

        self.setUp()
        request, result, _sha = self._durable_worker()
        self._boundary().run(
            self.run.run_id, self.lease, attempt=result.attempt, request_id=request.request_id
        )
        evidence = self.store.load_gota_worker_commit_verified(
            self.run.run_id, result.attempt, request.request_id
        )
        assert evidence is not None
        self._rewrite_evidence_created_at(
            evidence.evidence_id, evidence.created_at + timedelta(seconds=1)
        )
        with self.assertRaises(GotaWorkerReviewBoundaryError):
            self._boundary().run(
                self.run.run_id,
                self.lease,
                attempt=result.attempt,
                request_id=request.request_id,
            )

        self.setUp()
        request, result, _sha = self._durable_worker()
        self._boundary().run(
            self.run.run_id, self.lease, attempt=result.attempt, request_id=request.request_id
        )
        event_id = self.store.list_events(self.run.run_id)[-1].event_id
        self._rewrite_event_created_at(event_id, datetime.now(UTC) + timedelta(seconds=1))
        with self.assertRaises(GotaWorkerReviewBoundaryError):
            self._boundary().run(
                self.run.run_id,
                self.lease,
                attempt=result.attempt,
                request_id=request.request_id,
            )

    def test_evidence_id_tampering_fails_closed(self) -> None:
        request, result, _sha = self._durable_worker()
        self._boundary().run(
            self.run.run_id, self.lease, attempt=result.attempt, request_id=request.request_id
        )
        evidence = self.store.load_gota_worker_commit_verified(
            self.run.run_id, result.attempt, request.request_id
        )
        assert evidence is not None
        self._rewrite_evidence_id_without_foreign_keys(
            evidence.evidence_id, f"tampered-{evidence.evidence_id}"
        )
        with self.assertRaises(GotaWorkerReviewBoundaryError):
            self._boundary().run(
                self.run.run_id,
                self.lease,
                attempt=result.attempt,
                request_id=request.request_id,
            )

    def test_recalculated_digest_cannot_bypass_review_authority(self) -> None:
        request, result, _sha = self._durable_worker()
        self._boundary().run(
            self.run.run_id, self.lease, attempt=result.attempt, request_id=request.request_id
        )
        evidence = self.store.load_gota_worker_commit_verified(
            self.run.run_id, result.attempt, request.request_id
        )
        assert evidence is not None
        tampered = dict(evidence.payload)
        refs = list(tampered["refs"])
        refs.append(["refs/tags/recalculated-tamper", tampered["commit_sha"], ""])
        tampered["refs"] = sorted(refs)
        self._rewrite_evidence(evidence.evidence_id, tampered, _digest(tampered))
        with self.assertRaises(GotaWorkerReviewBoundaryError):
            self._boundary().run(
                self.run.run_id,
                self.lease,
                attempt=result.attempt,
                request_id=request.request_id,
            )

    def test_recalculated_payload_variants_fail_closed(self) -> None:
        variants = (
            ("head", "b" * 40),
            ("status", " M src/change.py"),
            ("changed_paths", ["other.py"]),
            ("branch", "tampered-branch"),
            ("base_sha", "c" * 40),
        )
        for field, value in variants:
            with self.subTest(field=field):
                case = ReviewEntryTest("test_happy_path_is_atomic_and_auditable")
                case.setUp()
                try:
                    request, result, _sha = case._durable_worker()
                    case._boundary().run(
                        case.run.run_id,
                        case.lease,
                        attempt=result.attempt,
                        request_id=request.request_id,
                    )
                    evidence = case.store.load_gota_worker_commit_verified(
                        case.run.run_id, result.attempt, request.request_id
                    )
                    assert evidence is not None
                    tampered = dict(evidence.payload)
                    tampered[field] = value
                    case._rewrite_evidence(
                        evidence.evidence_id, tampered, _digest(tampered)
                    )
                    with case.assertRaises(GotaWorkerReviewBoundaryError):
                        case._boundary().run(
                            case.run.run_id,
                            case.lease,
                            attempt=result.attempt,
                            request_id=request.request_id,
                        )
                finally:
                    case.doCleanups()

    def test_review_git_refs_head_branch_and_dirty_state_fail_closed(self) -> None:
        mutations = (
            ("refs", lambda case: case._git("tag", "review-mutated-ref")),
            (
                "head",
                lambda case: case._git("checkout", "--detach", case.base_sha),
            ),
            (
                "branch",
                lambda case: case._git("checkout", "-b", "review-mutated-branch"),
            ),
            (
                "status",
                lambda case: (case.repository / "dirty.txt").write_text(
                    "dirty\n", encoding="utf-8"
                ),
            ),
        )
        for field, mutate in mutations:
            with self.subTest(field=field):
                case = ReviewEntryTest("test_happy_path_is_atomic_and_auditable")
                case.setUp()
                try:
                    request, result, _sha = case._durable_worker()
                    case._boundary().run(
                        case.run.run_id,
                        case.lease,
                        attempt=result.attempt,
                        request_id=request.request_id,
                    )
                    evidence_before = case.store.list_evidence(case.run.run_id)
                    events_before = case.store.list_events(case.run.run_id)
                    mutate(case)
                    with case.assertRaises(GotaWorkerReviewBoundaryError):
                        case._boundary().run(
                            case.run.run_id,
                            case.lease,
                            attempt=result.attempt,
                            request_id=request.request_id,
                        )
                    case.assertEqual(case.store.list_evidence(case.run.run_id), evidence_before)
                    case.assertEqual(case.store.list_events(case.run.run_id), events_before)
                finally:
                    case.doCleanups()

    def test_review_revalidates_git_without_mutating_authorities(self) -> None:
        request, result, _sha = self._durable_worker()
        self._boundary().run(
            self.run.run_id, self.lease, attempt=result.attempt, request_id=request.request_id
        )
        evidence_before = self.store.list_evidence(self.run.run_id)
        events_before = self.store.list_events(self.run.run_id)
        anchor_before = self.store.load_gota_worker_review_boundary(
            self.run.run_id, result.attempt, request.request_id
        )
        with self.assertRaises(GotaWorkerReviewBoundaryError):
            self._boundary(git=ReviewRefChangingReadOnlyGitAdapter(self.repository)).run(
                self.run.run_id,
                self.lease,
                attempt=result.attempt,
                request_id=request.request_id,
            )
        self.assertEqual(self.store.list_evidence(self.run.run_id), evidence_before)
        self.assertEqual(self.store.list_events(self.run.run_id), events_before)
        self.assertEqual(
            self.store.load_gota_worker_review_boundary(
                self.run.run_id, result.attempt, request.request_id
            ),
            anchor_before,
        )

    def test_worker_authority_links_are_revalidated_against_real_evidence(self) -> None:
        for field in (
            "request_evidence_id",
            "invocation_evidence_id",
            "result_evidence_id",
        ):
            with self.subTest(field=field):
                case = ReviewEntryTest("test_happy_path_is_atomic_and_auditable")
                case.setUp()
                try:
                    request, result, _sha = case._durable_worker()
                    case._boundary().run(
                        case.run.run_id,
                        case.lease,
                        attempt=result.attempt,
                        request_id=request.request_id,
                    )
                    evidence = case.store.load_gota_worker_commit_verified(
                        case.run.run_id, result.attempt, request.request_id
                    )
                    assert evidence is not None
                    tampered = dict(evidence.payload)
                    tampered[field] = "unrelated-evidence-id"
                    case._rewrite_evidence(
                        evidence.evidence_id, tampered, _digest(tampered)
                    )
                    with case.assertRaises(GotaWorkerReviewBoundaryError):
                        case._boundary().run(
                            case.run.run_id,
                            case.lease,
                            attempt=result.attempt,
                            request_id=request.request_id,
                        )
                finally:
                    case.doCleanups()

    def test_idempotence_restart_and_zero_worker_calls(self) -> None:
        request, result, _sha = self._durable_worker()
        adapter = SpyReadOnlyGitAdapter(self.repository)
        boundary = self._boundary(git=adapter)
        first = boundary.run(
            self.run.run_id,
            self.lease,
            attempt=result.attempt,
            request_id=request.request_id,
        )
        evidence_before = self.store.list_evidence(self.run.run_id)
        events_before = self.store.list_events(self.run.run_id)
        anchor_before = self.store.load_gota_worker_review_boundary(
            self.run.run_id, result.attempt, request.request_id
        )
        snapshots_before = adapter.snapshot_count

        reopened = SQLiteCoordinatorStore(self.database)
        second = GotaWorkerReviewBoundary(self.repository, store=reopened, git=adapter).run(
            self.run.run_id,
            self.lease,
            attempt=result.attempt,
            request_id=request.request_id,
        )
        self.assertTrue(first.created)
        self.assertTrue(second.already_completed)
        self.assertEqual(reopened.list_evidence(self.run.run_id), evidence_before)
        self.assertEqual(reopened.list_events(self.run.run_id), events_before)
        self.assertEqual(
            reopened.load_gota_worker_review_boundary(
                self.run.run_id, result.attempt, request.request_id
            ),
            anchor_before,
        )
        self.assertGreater(adapter.snapshot_count, snapshots_before)

    def test_tampered_review_evidence_and_partial_states_fail_closed(self) -> None:
        request, result, _sha = self._durable_worker()
        self._boundary().run(
            self.run.run_id,
            self.lease,
            attempt=result.attempt,
            request_id=request.request_id,
        )
        evidence = self.store.load_gota_worker_commit_verified(
            self.run.run_id, 1, request.request_id
        )
        assert evidence is not None
        tampered = dict(evidence.payload)
        tampered["commit_sha"] = "b" * 40
        self._rewrite_evidence(evidence.evidence_id, tampered, _digest(tampered))
        with self.assertRaises(GotaWorkerReviewBoundaryError):
            self._boundary().run(
                self.run.run_id,
                self.lease,
                attempt=result.attempt,
                request_id=request.request_id,
            )

        self.setUp()
        request, result, _sha = self._durable_worker()
        with self.store.transaction(immediate=True) as connection:
            connection.execute(
                "UPDATE task_runs SET state = ? WHERE run_id = ?",
                (TaskState.REVIEW.value, self.run.run_id),
            )
        with self.assertRaises(GotaWorkerReviewBoundaryError):
            self._boundary().run(
                self.run.run_id,
                self.lease,
                attempt=result.attempt,
                request_id=request.request_id,
            )

        self.setUp()
        request, result, _sha = self._durable_worker()
        with self.store.transaction(immediate=True) as connection:
            self.store._insert_evidence(
                connection,
                self.run.run_id,
                "gota_worker_commit_verified",
                {
                    "request_id": request.request_id,
                    "task_id": request.task_id,
                    "run_id": request.run_id,
                    "attempt": request.attempt,
                    "commit_sha": result.commit_sha,
                },
                self.lease,
                datetime.now(UTC),
            )
        with self.assertRaises(GotaWorkerReviewBoundaryError):
            self._boundary().run(
                self.run.run_id,
                self.lease,
                attempt=result.attempt,
                request_id=request.request_id,
            )

    def test_expired_lease_and_stale_fence_do_not_promote(self) -> None:
        request, result, _sha = self._durable_worker()
        with self.store.transaction(immediate=True) as connection:
            connection.execute(
                "UPDATE global_lock SET lease_expires_at = ? WHERE lock_name = 'global'",
                ((datetime.now(UTC) - timedelta(seconds=1)).isoformat(),),
            )
        with self.assertRaises(LeaseExpiredError):
            self._boundary().run(
                self.run.run_id,
                self.lease,
                attempt=result.attempt,
                request_id=request.request_id,
            )
        self.assertEqual(self.store.get_run(self.run.run_id).state, TaskState.RUNNING)

        self.setUp()
        request, result, _sha = self._durable_worker()
        stale = replace(self.lease, fencing_token=self.lease.fencing_token - 1)
        with self.assertRaises(FencingTokenError):
            self._boundary().run(
                self.run.run_id,
                stale,
                attempt=result.attempt,
                request_id=request.request_id,
            )
        self.assertEqual(self.store.get_run(self.run.run_id).state, TaskState.RUNNING)

    def test_reserved_commit_evidence_cannot_be_fabricated_publicly(self) -> None:
        with self.assertRaises(AcceptanceEvidenceError):
            self.store.append_evidence(
                self.run.run_id,
                "gota_worker_commit_verified",
                {"trusted": True},
                self.lease,
            )
        self.assertEqual(self.store.list_evidence(self.run.run_id), ())


if __name__ == "__main__":
    unittest.main()
