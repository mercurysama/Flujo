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
from flow_coordinator.domain import TaskSpec, TaskState
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
        self.assertEqual(adapter.snapshot_count, snapshots_before)

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
