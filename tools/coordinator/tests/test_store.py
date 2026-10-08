from __future__ import annotations

import hashlib
import json
import sqlite3
import subprocess
from dataclasses import replace
from datetime import UTC, datetime, timedelta
from pathlib import Path

from flow_coordinator.domain import ProjectBinding, TaskSpec, TaskState
from flow_coordinator.executor import FakeExecutor
from flow_coordinator.gota_protocol import (
    GOTA_PROTOCOL,
    GotaCheckpoint,
    GotaMessage,
    GotaPhase,
    GotaRequest,
    GotaReviewResult,
    GotaWorkerResult,
    ReviewDecision,
    WorkerResultStatus,
)
from flow_coordinator import GotaWorkerReviewBoundary
from flow_coordinator.store import (
    AcceptanceEvidenceError,
    FencingTokenError,
    LeaseExpiredError,
    SQLiteCoordinatorStore,
)

from support import CoordinatorTestCase


def _canonical_json(value: object) -> str:
    return json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=False)


def _digest(value: object) -> str:
    return hashlib.sha256(_canonical_json(value).encode("utf-8")).hexdigest()


class FixedClockStore(SQLiteCoordinatorStore):
    def __init__(self, path: str | Path, trusted_now: datetime) -> None:
        self._fixed_trusted_now = trusted_now
        super().__init__(path)

    def _trusted_now(self) -> datetime:
        return self._fixed_trusted_now


class SQLiteStoreTest(CoordinatorTestCase):
    @staticmethod
    def _git(repository: Path, *arguments: str) -> str:
        completed = subprocess.run(
            ("git", *arguments),
            cwd=repository,
            check=True,
            capture_output=True,
            text=True,
        )
        return completed.stdout.rstrip("\n")

    def _rewrite_evidence_payload(
        self,
        run_id: str,
        kind: str,
        payload: dict[str, object],
    ) -> str:
        connection = sqlite3.connect(self.database)
        try:
            connection.execute("PRAGMA foreign_keys = OFF")
            connection.execute("DROP TRIGGER IF EXISTS immutable_evidence_update")
            row = connection.execute(
                "SELECT evidence_id FROM evidence WHERE run_id = ? AND kind = ?",
                (run_id, kind),
            ).fetchone()
            self.assertIsNotNone(row)
            digest = _digest(payload)
            connection.execute(
                "UPDATE evidence SET payload_json = ?, digest = ? WHERE evidence_id = ?",
                (_canonical_json(payload), digest, row[0]),
            )
            connection.commit()
            return digest
        finally:
            connection.execute(
                """
                CREATE TRIGGER IF NOT EXISTS immutable_evidence_update
                BEFORE UPDATE ON evidence
                BEGIN SELECT RAISE(ABORT, 'evidence is immutable'); END
                """
            )
            connection.commit()
            connection.close()

    def _rewrite_evidence_storage(
        self,
        run_id: str,
        kind: str,
        *,
        payload_json: str | None = None,
        digest: str | None = None,
    ) -> None:
        self.assertTrue(payload_json is not None or digest is not None)
        connection = sqlite3.connect(self.database)
        try:
            connection.execute("PRAGMA foreign_keys = OFF")
            connection.execute("DROP TRIGGER IF EXISTS immutable_evidence_update")
            row = connection.execute(
                "SELECT evidence_id FROM evidence WHERE run_id = ? AND kind = ?",
                (run_id, kind),
            ).fetchone()
            self.assertIsNotNone(row)
            assignments: list[str] = []
            values: list[object] = []
            if payload_json is not None:
                assignments.append("payload_json = ?")
                values.append(payload_json)
            if digest is not None:
                assignments.append("digest = ?")
                values.append(digest)
            values.append(row[0])
            connection.execute(
                f"UPDATE evidence SET {', '.join(assignments)} WHERE evidence_id = ?",
                values,
            )
            connection.commit()
        finally:
            connection.execute(
                """
                CREATE TRIGGER IF NOT EXISTS immutable_evidence_update
                BEFORE UPDATE ON evidence
                BEGIN SELECT RAISE(ABORT, 'evidence is immutable'); END
                """
            )
            connection.commit()
            connection.close()

    def _rewrite_anchor_field(
        self,
        table: str,
        field: str,
        run_id: str,
        value: object,
    ) -> None:
        self.assertIn(table, {"gota_worker_review_boundaries", "gota_review_results"})
        self.assertIn(
            field,
            {"commit_evidence_digest", "review_evidence_digest"},
        )
        connection = sqlite3.connect(self.database)
        try:
            connection.execute("PRAGMA foreign_keys = OFF")
            connection.execute(
                f"DROP TRIGGER IF EXISTS immutable_{table}_update"
            )
            connection.execute(
                f"UPDATE {table} SET {field} = ? WHERE run_id = ?",
                (value, run_id),
            )
            connection.commit()
        finally:
            connection.execute(
                f"""
                CREATE TRIGGER IF NOT EXISTS immutable_{table}_update
                BEFORE UPDATE ON {table}
                BEGIN SELECT RAISE(ABORT, '{table} is immutable'); END
                """
            )
            connection.commit()
            connection.close()

    def _remove_evidence_kind(self, run_id: str, kind: str) -> None:
        connection = sqlite3.connect(self.database)
        try:
            connection.execute("PRAGMA foreign_keys = OFF")
            connection.execute("DROP TRIGGER IF EXISTS immutable_evidence_delete")
            connection.execute(
                "DELETE FROM evidence WHERE run_id = ? AND kind = ?",
                (run_id, kind),
            )
            connection.commit()
        finally:
            connection.execute(
                """
                CREATE TRIGGER IF NOT EXISTS immutable_evidence_delete
                BEFORE DELETE ON evidence
                BEGIN SELECT RAISE(ABORT, 'evidence is immutable'); END
                """
            )
            connection.commit()
            connection.close()

    @staticmethod
    def _worker_result(
        run_id: str,
        task_id: str,
        *,
        commit_sha: str = "a" * 40,
        attempt: int = 1,
    ) -> GotaWorkerResult:
        return GotaWorkerResult(
            protocol=GOTA_PROTOCOL,
            message=GotaMessage.WORKER_RESULT.value,
            request_id=f"{run_id}:{attempt}:worker",
            task_id=task_id,
            run_id=run_id,
            attempt=attempt,
            result=WorkerResultStatus.READY_FOR_REVIEW,
            commit_sha=commit_sha,
            changed_paths=("src/change.py",),
            evidence=({"kind": "worker_commit"},),
            checkpoint=GotaCheckpoint(
                completed_steps=("implementation",),
                remaining_phase="review",
            ),
        )

    @staticmethod
    def _review_result(
        run_id: str,
        task_id: str,
        *,
        reviewed_commit_sha: str = "a" * 40,
        decision: ReviewDecision = ReviewDecision.PASSED,
        attempt: int = 1,
    ) -> GotaReviewResult:
        return GotaReviewResult(
            protocol=GOTA_PROTOCOL,
            message=GotaMessage.REVIEW_RESULT.value,
            request_id=f"{run_id}:{attempt}:review",
            task_id=task_id,
            run_id=run_id,
            attempt=attempt,
            reviewed_commit_sha=reviewed_commit_sha,
            decision=decision,
            findings=(),
            evidence=({"kind": "review"},),
        )

    def _gota_review_fixture(
        self,
        task_id: str,
        *,
        worker_sha: str | None = None,
        verified_sha: str | None = None,
        reviewed_sha: str | None = None,
        decision: ReviewDecision = ReviewDecision.PASSED,
        evidence_kinds: tuple[str, ...] = (
            "gota_worker_result_received",
            "gota_worker_commit_verified",
            "gota_review_result",
        ),
        now: datetime | None = None,
    ):
        repository = self.root / f"repository-{task_id}"
        repository.mkdir()
        branch = f"feature/{task_id}"
        self._git(repository, "init", f"--initial-branch={branch}")
        self._git(repository, "config", "user.name", "Gota Store Test")
        self._git(repository, "config", "user.email", "gota-store@example.invalid")
        (repository / "src").mkdir()
        (repository / "src/change.py").write_text(
            "value = 'base'\n", encoding="utf-8"
        )
        self._git(repository, "add", "--", "src/change.py")
        self._git(repository, "commit", "-m", "fixture base")
        base_sha = self._git(repository, "rev-parse", "HEAD")

        spec = TaskSpec(
            task_id=task_id,
            title=f"Task {task_id}",
            objective="Exercise the local coordinator core",
            project_id="project-a",
            repository_id="repo-project-a",
            branch=branch,
            base_sha=base_sha,
            context_id=f"context-{task_id}",
            allowed_paths=("src/change.py",),
            protected_paths=("demo/main.tscn", "export_presets.cfg"),
            required_resources=(),
            acceptance_criteria=("All focal checks pass",),
            commit_message=f"test: complete {task_id}",
        )
        run = self.service.create_task(
            spec,
            {"workspace": str(repository), "task": task_id},
        )
        lease = self.service.start(
            run.run_id,
            owner_id="worker",
            now=now,
        )
        persistence_store = (
            FixedClockStore(self.database, now) if now is not None else self.store
        )
        if not evidence_kinds:
            self.service.complete_execution(run.run_id, lease, now=now)
            return run, lease, None, None
        request = GotaRequest(
            protocol=GOTA_PROTOCOL,
            request_id=f"{run.run_id}:1:worker",
            task_id=run.task_id,
            run_id=run.run_id,
            attempt=1,
            phase=GotaPhase.WORKER,
            objective=spec.objective,
            acceptance_criteria=spec.acceptance_criteria,
            workspace=str(repository),
            branch=branch,
            base_sha=base_sha,
            allowed_paths=spec.allowed_paths,
            protected_paths=spec.protected_paths,
        )
        persistence_store.reserve_gota_worker_invocation(
            run.run_id, request, lease
        )
        (repository / "src/change.py").write_text(
            "value = 'worker'\n", encoding="utf-8"
        )
        self._git(repository, "add", "--", "src/change.py")
        self._git(repository, "commit", "-m", "worker change")
        actual_worker_sha = self._git(repository, "rev-parse", "HEAD")
        worker = self._worker_result(
            run.run_id,
            run.task_id,
            commit_sha=actual_worker_sha,
        )
        persistence_store.persist_gota_worker_result(
            run.run_id, worker, lease
        )
        entered = GotaWorkerReviewBoundary(
            repository,
            store=persistence_store,
        ).run(
            run.run_id,
            lease,
            attempt=1,
            request_id=request.request_id,
        )
        self.assertEqual(entered.state, TaskState.REVIEW)
        review = self._review_result(
            run.run_id,
            run.task_id,
            reviewed_commit_sha=actual_worker_sha,
            decision=decision,
        )
        persistence_store.persist_gota_review_result(
            run.run_id, review, lease
        )

        if worker_sha is not None and worker_sha != actual_worker_sha:
            worker_payload = dict(worker.to_payload())
            worker_payload["commit_sha"] = worker_sha
            self._rewrite_evidence_payload(
                run.run_id,
                "gota_worker_result_received",
                worker_payload,
            )
        if verified_sha is not None and verified_sha != actual_worker_sha:
            commit_evidence = next(
                item
                for item in self.store.list_evidence(run.run_id)
                if item.kind == "gota_worker_commit_verified"
            )
            commit_payload = dict(commit_evidence.payload)
            commit_payload["commit_sha"] = verified_sha
            commit_payload["head"] = verified_sha
            commit_digest = self._rewrite_evidence_payload(
                run.run_id,
                "gota_worker_commit_verified",
                commit_payload,
            )
            self._rewrite_anchor_field(
                "gota_worker_review_boundaries",
                "commit_evidence_digest",
                run.run_id,
                commit_digest,
            )
        if reviewed_sha is not None and reviewed_sha != actual_worker_sha:
            review_payload = dict(review.to_payload())
            review_payload["reviewed_commit_sha"] = reviewed_sha
            review_digest = self._rewrite_evidence_payload(
                run.run_id,
                "gota_review_result",
                review_payload,
            )
            self._rewrite_anchor_field(
                "gota_review_results",
                "review_evidence_digest",
                run.run_id,
                review_digest,
            )
        for kind in {
            "gota_worker_result_received",
            "gota_worker_commit_verified",
            "gota_review_result",
        } - set(evidence_kinds):
            self._remove_evidence_kind(run.run_id, kind)
        return run, lease, worker, review

    def test_schema_contains_every_required_operational_table(self) -> None:
        self.assertTrue(
            {
                "schema_migrations",
                "task_specs",
                "task_runs",
                "contexts",
                "dependencies",
                "transition_events",
                "gota_worker_review_boundaries",
                "gota_review_results",
                "evidence",
                "checkpoints",
                "resource_attempts",
                "coordinator_resources",
                "global_lock",
                "project_bindings",
            }.issubset(set(self.store.table_names()))
        )
        self.assertEqual(self.store.schema_version(), 1)

    def test_gota_boundary_table_is_recreated_when_an_existing_store_reopens(self) -> None:
        with self.store.transaction(immediate=True) as connection:
            connection.execute("DROP TABLE gota_worker_review_boundaries")
        reopened = SQLiteCoordinatorStore(self.database)
        self.assertIn(
            "gota_worker_review_boundaries",
            reopened.table_names(),
        )

    def test_gota_review_result_table_is_recreated_when_an_existing_store_reopens(self) -> None:
        with self.store.transaction(immediate=True) as connection:
            connection.execute("DROP TABLE gota_review_results")
        reopened = SQLiteCoordinatorStore(self.database)
        self.assertIn("gota_review_results", reopened.table_names())

    def test_state_persists_after_coordinator_restart(self) -> None:
        spec, run = self.create_task("persistent")
        self.store.bind_project(
            ProjectBinding(
                project_id=spec.project_id,
                repository_id=spec.repository_id,
                workspace_path="/isolated/project-a",
                context_id=spec.context_id,
            )
        )
        reopened = SQLiteCoordinatorStore(self.database)
        self.assertEqual(reopened.get_task_spec(spec.task_id), spec)
        self.assertEqual(reopened.get_run(run.run_id).state, TaskState.ASSIGNED)
        self.assertEqual(
            reopened.get_project_binding(spec.project_id).workspace_path,
            "/isolated/project-a",
        )

    def test_evidence_and_events_are_append_only(self) -> None:
        _, run = self.create_task("immutable")
        lease = self.service.start(run.run_id, owner_id="worker")
        evidence = self.store.append_evidence(
            run.run_id, "command", {"exit_code": 0}, lease
        )
        with self.assertRaises(sqlite3.IntegrityError):
            with self.store.transaction(immediate=True) as connection:
                connection.execute(
                    "UPDATE evidence SET kind = 'changed' WHERE evidence_id = ?",
                    (evidence.evidence_id,),
                )
        event_id = self.store.list_events(run.run_id)[0].event_id
        with self.assertRaises(sqlite3.IntegrityError):
            with self.store.transaction(immediate=True) as connection:
                connection.execute(
                    "DELETE FROM transition_events WHERE event_id = ?", (event_id,)
                )

    def test_legacy_done_transition_does_not_provide_gota_boundary(self) -> None:
        _, run = self.create_task("gota-boundary")
        lease = self.service.start(run.run_id, owner_id="worker")
        self.service.complete_execution(run.run_id, lease)
        for kind in (
            "gota_worker_result_received",
            "gota_worker_commit_verified",
            "gota_review_result",
        ):
            if kind == "gota_worker_result_received":
                self.store.persist_gota_worker_result(
                    run.run_id,
                    self._worker_result(run.run_id, run.task_id),
                    lease,
                )
            elif kind == "gota_worker_commit_verified":
                with self.store.transaction(immediate=True) as connection:
                    self.store._insert_evidence(
                        connection,
                        run.run_id,
                        kind,
                        {"source": "fixture"},
                        lease,
                        self.store._trusted_now(),
                    )
            elif kind == "gota_review_result":
                with self.store.transaction(immediate=True) as connection:
                    self.store._insert_evidence(
                        connection,
                        run.run_id,
                        kind,
                        {"source": "fixture"},
                        lease,
                        self.store._trusted_now(),
                    )
            else:
                self.store.append_evidence(
                    run.run_id,
                    kind,
                    {"source": "fixture"},
                    lease,
                )

        with self.assertRaisesRegex(AcceptanceEvidenceError, "microaudit"):
            self.store.transition_run(
                run.run_id,
                TaskState.DONE,
                lease,
                actor="worker",
                reason="gota_fixture_must_not_use_legacy_acceptance",
            )
        self.assertEqual(self.store.get_run(run.run_id).state, TaskState.REVIEW)

    def test_transition_gota_to_done_happy_path_is_atomic_and_auditable(self) -> None:
        run, lease, worker, review = self._gota_review_fixture("gota-happy")

        accepted = self.store.transition_gota_to_done(run.run_id, lease, actor="reviewer")

        self.assertEqual(accepted.state, TaskState.DONE)
        evidence = self.store.list_evidence(run.run_id)
        self.assertEqual(
            [item.kind for item in evidence],
            [
                "gota_worker_request_registered",
                "gota_worker_invocation_started",
                "gota_worker_result_received",
                "gota_worker_commit_verified",
                "gota_review_result",
                "gota_acceptance_verified",
            ],
        )
        acceptance = evidence[-1].payload
        self.assertEqual(acceptance["run_id"], run.run_id)
        self.assertEqual(acceptance["task_id"], run.task_id)
        self.assertEqual(acceptance["worker_commit_sha"], worker.commit_sha)
        self.assertEqual(acceptance["reviewed_commit_sha"], review.reviewed_commit_sha)
        self.assertEqual(acceptance["decision"], ReviewDecision.PASSED.value)
        self.assertEqual(acceptance["fencing_token"], lease.fencing_token)

    def test_append_evidence_rejects_reserved_acceptance_before_transition(self) -> None:
        run, lease, _, _ = self._gota_review_fixture(
            "gota-reserved-before", evidence_kinds=()
        )

        with self.assertRaisesRegex(AcceptanceEvidenceError, "reserved"):
            self.store.append_evidence(
                run.run_id,
                "gota_acceptance_verified",
                {"arbitrary": "caller-payload"},
                lease,
            )

        self.assertEqual(self.store.get_run(run.run_id).state, TaskState.REVIEW)
        self.assertEqual(self.store.list_evidence(run.run_id), ())

    def test_transition_gota_to_done_uses_store_clock_for_timestamps(self) -> None:
        start = datetime(2026, 1, 1, tzinfo=UTC)
        trusted_now = start + timedelta(seconds=10)
        run, lease, _, _ = self._gota_review_fixture("gota-store-clock", now=start)
        trusted_store = FixedClockStore(self.database, trusted_now)

        accepted = trusted_store.transition_gota_to_done(run.run_id, lease)

        acceptance = trusted_store.list_evidence(run.run_id)[-1]
        transition = trusted_store.list_events(run.run_id)[-1]
        self.assertEqual(accepted.state, TaskState.DONE)
        self.assertEqual(acceptance.kind, "gota_acceptance_verified")
        self.assertEqual(acceptance.created_at, trusted_now)
        self.assertEqual(accepted.updated_at, trusted_now)
        self.assertEqual(transition.created_at, trusted_now)

    def test_append_evidence_rejects_reserved_acceptance_after_transition(self) -> None:
        run, lease, _, _ = self._gota_review_fixture("gota-reserved-after")
        self.store.transition_gota_to_done(run.run_id, lease)

        with self.assertRaisesRegex(AcceptanceEvidenceError, "reserved"):
            self.store.append_evidence(
                run.run_id,
                "gota_acceptance_verified",
                {"arbitrary": "caller-payload"},
                lease,
            )

        evidence = self.store.list_evidence(run.run_id)
        self.assertEqual(
            sum(item.kind == "gota_acceptance_verified" for item in evidence), 1
        )

    def test_transition_gota_to_done_rejects_non_review_state(self) -> None:
        _, run = self.create_task("gota-running")
        lease = self.service.start(run.run_id, owner_id="worker")

        with self.assertRaisesRegex(ValueError, "REVIEW"):
            self.store.transition_gota_to_done(run.run_id, lease)
        self.assertEqual(self.store.get_run(run.run_id).state, TaskState.RUNNING)
        self.assertEqual(self.store.list_evidence(run.run_id), ())

    def test_transition_gota_to_done_rejects_expired_lease(self) -> None:
        start = datetime(2026, 1, 1, tzinfo=UTC)
        run, lease, _, _ = self._gota_review_fixture("gota-expired", now=start)
        trusted_store = FixedClockStore(
            self.database, start + timedelta(seconds=61)
        )

        with self.assertRaises(TypeError):
            trusted_store.transition_gota_to_done(run.run_id, lease, now=start)
        with self.assertRaises(LeaseExpiredError):
            trusted_store.transition_gota_to_done(run.run_id, lease)
        self.assertEqual(self.store.get_run(run.run_id).state, TaskState.REVIEW)
        self.assertNotIn(
            "gota_acceptance_verified",
            [item.kind for item in self.store.list_evidence(run.run_id)],
        )

    def test_transition_gota_to_done_rejects_old_fencing_token(self) -> None:
        run, lease, _, _ = self._gota_review_fixture("gota-old-fence")
        old_lease = replace(lease, fencing_token=lease.fencing_token - 1)

        with self.assertRaises(FencingTokenError):
            self.store.transition_gota_to_done(run.run_id, old_lease)
        self.assertEqual(self.store.get_run(run.run_id).state, TaskState.REVIEW)
        self.assertNotIn(
            "gota_acceptance_verified",
            [item.kind for item in self.store.list_evidence(run.run_id)],
        )

    def test_transition_gota_to_done_rejects_incoherent_worker_sha(self) -> None:
        run, lease, _, _ = self._gota_review_fixture(
            "gota-worker-sha",
            worker_sha="a" * 40,
            verified_sha="b" * 40,
        )

        with self.assertRaisesRegex(AcceptanceEvidenceError, "commit SHA"):
            self.store.transition_gota_to_done(run.run_id, lease)
        self.assertEqual(self.store.get_run(run.run_id).state, TaskState.REVIEW)
        self.assertNotIn(
            "gota_acceptance_verified",
            [item.kind for item in self.store.list_evidence(run.run_id)],
        )

    def test_transition_gota_to_done_rejects_distinct_reviewed_sha(self) -> None:
        run, lease, _, _ = self._gota_review_fixture(
            "gota-reviewed-sha",
            reviewed_sha="b" * 40,
        )

        with self.assertRaisesRegex(AcceptanceEvidenceError, "incoherent or not PASSED"):
            self.store.transition_gota_to_done(run.run_id, lease)
        self.assertEqual(self.store.get_run(run.run_id).state, TaskState.REVIEW)

    def test_transition_gota_to_done_rejects_wrong_worker_identity_fields(self) -> None:
        run, lease, _, _ = self._gota_review_fixture("gota-worker-identity")
        commit_evidence = next(
            item
            for item in self.store.list_evidence(run.run_id)
            if item.kind == "gota_worker_commit_verified"
        )
        original_payload = dict(commit_evidence.payload)
        original_digest = commit_evidence.digest
        mutations = {
            "run_id": "other-run",
            "task_id": "other-task",
            "attempt": 2,
            "request_id": f"{run.run_id}:1:review",
        }
        for field, value in mutations.items():
            with self.subTest(field=field):
                payload = dict(original_payload)
                payload[field] = value
                digest = self._rewrite_evidence_payload(
                    run.run_id,
                    "gota_worker_commit_verified",
                    payload,
                )
                self._rewrite_anchor_field(
                    "gota_worker_review_boundaries",
                    "commit_evidence_digest",
                    run.run_id,
                    digest,
                )
                with self.assertRaises(AcceptanceEvidenceError):
                    self.store.transition_gota_to_done(run.run_id, lease)
                self.assertEqual(
                    self.store.get_run(run.run_id).state,
                    TaskState.REVIEW,
                )
                self._rewrite_evidence_payload(
                    run.run_id,
                    "gota_worker_commit_verified",
                    original_payload,
                )
                self._rewrite_anchor_field(
                    "gota_worker_review_boundaries",
                    "commit_evidence_digest",
                    run.run_id,
                    original_digest,
                )

    def test_transition_gota_to_done_rejects_malformed_and_bad_digest_commit_evidence(
        self,
    ) -> None:
        run, lease, _, _ = self._gota_review_fixture("gota-corrupt-commit")
        commit_evidence = next(
            item
            for item in self.store.list_evidence(run.run_id)
            if item.kind == "gota_worker_commit_verified"
        )
        with self.assertRaises(AcceptanceEvidenceError):
            self._rewrite_evidence_storage(
                run.run_id,
                commit_evidence.kind,
                payload_json="{",
                digest=commit_evidence.digest,
            )
            self.store.transition_gota_to_done(run.run_id, lease)
        self._rewrite_evidence_payload(
            run.run_id,
            commit_evidence.kind,
            dict(commit_evidence.payload),
        )
        with self.assertRaises(AcceptanceEvidenceError):
            self._rewrite_evidence_storage(
                run.run_id,
                commit_evidence.kind,
                digest="0" * 64,
            )
            self.store.transition_gota_to_done(run.run_id, lease)

    def test_transition_gota_to_done_rejects_duplicate_commit_evidence(self) -> None:
        run, lease, _, _ = self._gota_review_fixture("gota-duplicate-commit")
        commit_evidence = next(
            item
            for item in self.store.list_evidence(run.run_id)
            if item.kind == "gota_worker_commit_verified"
        )
        with self.store.transaction(immediate=True) as connection:
            self.store._insert_evidence(
                connection,
                run.run_id,
                commit_evidence.kind,
                dict(commit_evidence.payload),
                lease,
                self.store._trusted_now(),
            )
        with self.assertRaisesRegex(
            AcceptanceEvidenceError,
            "gota_worker_commit_verified",
        ):
            self.store.transition_gota_to_done(run.run_id, lease)
        self.assertEqual(self.store.get_run(run.run_id).state, TaskState.REVIEW)

    def test_transition_gota_to_done_rejects_correction_required(self) -> None:
        run, lease, _, _ = self._gota_review_fixture(
            "gota-decision-correction",
            decision=ReviewDecision.CORRECTION_REQUIRED,
        )
        with self.assertRaisesRegex(AcceptanceEvidenceError, "incoherent or not PASSED"):
            self.store.transition_gota_to_done(run.run_id, lease)
        self.assertEqual(self.store.get_run(run.run_id).state, TaskState.REVIEW)
        self.assertNotIn(
            "gota_acceptance_verified",
            [item.kind for item in self.store.list_evidence(run.run_id)],
        )

    def test_transition_gota_to_done_rejects_human_review_required(self) -> None:
        run, lease, _, _ = self._gota_review_fixture(
            "gota-decision-human",
            decision=ReviewDecision.HUMAN_REVIEW_REQUIRED,
        )
        with self.assertRaisesRegex(AcceptanceEvidenceError, "incoherent or not PASSED"):
            self.store.transition_gota_to_done(run.run_id, lease)
        self.assertEqual(self.store.get_run(run.run_id).state, TaskState.REVIEW)
        self.assertNotIn(
            "gota_acceptance_verified",
            [item.kind for item in self.store.list_evidence(run.run_id)],
        )

    def test_transition_gota_to_done_rejects_blocked(self) -> None:
        run, lease, _, _ = self._gota_review_fixture(
            "gota-decision-blocked",
            decision=ReviewDecision.BLOCKED,
        )
        with self.assertRaisesRegex(AcceptanceEvidenceError, "incoherent or not PASSED"):
            self.store.transition_gota_to_done(run.run_id, lease)
        self.assertEqual(self.store.get_run(run.run_id).state, TaskState.REVIEW)
        self.assertNotIn(
            "gota_acceptance_verified",
            [item.kind for item in self.store.list_evidence(run.run_id)],
        )

    def test_transition_gota_to_done_rejects_missing_worker_result_evidence(self) -> None:
        required = (
            "gota_worker_commit_verified",
            "gota_review_result",
        )
        run, lease, _, _ = self._gota_review_fixture(
            "gota-missing-worker-result",
            evidence_kinds=required,
        )
        with self.assertRaisesRegex(
            AcceptanceEvidenceError, "gota_worker_result_received"
        ):
            self.store.transition_gota_to_done(run.run_id, lease)
        self.assertEqual(self.store.get_run(run.run_id).state, TaskState.REVIEW)

    def test_transition_gota_to_done_rejects_missing_commit_evidence(self) -> None:
        required = (
            "gota_worker_result_received",
            "gota_review_result",
        )
        run, lease, _, _ = self._gota_review_fixture(
            "gota-missing-commit",
            evidence_kinds=required,
        )
        with self.assertRaisesRegex(
            AcceptanceEvidenceError, "gota_worker_commit_verified"
        ):
            self.store.transition_gota_to_done(run.run_id, lease)
        self.assertEqual(self.store.get_run(run.run_id).state, TaskState.REVIEW)

    def test_transition_gota_to_done_rejects_missing_review_evidence(self) -> None:
        required = (
            "gota_worker_result_received",
            "gota_worker_commit_verified",
        )
        run, lease, _, _ = self._gota_review_fixture(
            "gota-missing-review",
            evidence_kinds=required,
        )
        with self.assertRaisesRegex(AcceptanceEvidenceError, "gota_review_result"):
            self.store.transition_gota_to_done(run.run_id, lease)
        self.assertEqual(self.store.get_run(run.run_id).state, TaskState.REVIEW)

    def test_transition_gota_to_done_does_not_accept_caller_evidence_argument(self) -> None:
        run, lease, _, _ = self._gota_review_fixture(
            "gota-fabricated-argument",
            evidence_kinds=(),
        )

        with self.assertRaises(TypeError):
            self.store.transition_gota_to_done(  # type: ignore[call-arg]
                run.run_id,
                lease,
                evidence=["gota_worker_result_received", "trust=True"],
            )
        self.assertEqual(self.store.get_run(run.run_id).state, TaskState.REVIEW)
        self.assertEqual(self.store.list_evidence(run.run_id), ())

    def test_transition_gota_to_done_rolls_back_acceptance_and_state_together(self) -> None:
        run, lease, _, _ = self._gota_review_fixture("gota-rollback")
        before = self.store.list_evidence(run.run_id)
        with self.store.transaction(immediate=True) as connection:
            connection.execute(
                """
                CREATE TRIGGER reject_gota_transition
                BEFORE INSERT ON transition_events
                WHEN NEW.reason = 'gota_acceptance_verified'
                BEGIN
                    SELECT RAISE(ABORT, 'controlled gota rollback');
                END
                """
            )
        try:
            with self.assertRaisesRegex(sqlite3.IntegrityError, "controlled gota rollback"):
                self.store.transition_gota_to_done(run.run_id, lease)
        finally:
            with self.store.transaction(immediate=True) as connection:
                connection.execute("DROP TRIGGER reject_gota_transition")

        self.assertEqual(self.store.get_run(run.run_id).state, TaskState.REVIEW)
        self.assertEqual(self.store.list_evidence(run.run_id), before)
        self.assertNotIn(
            "gota_acceptance_verified",
            [item.kind for item in self.store.list_evidence(run.run_id)],
        )

    def test_transition_gota_to_done_rejects_second_call_without_side_effects(self) -> None:
        run, lease, _, _ = self._gota_review_fixture("gota-second-call")
        self.store.transition_gota_to_done(run.run_id, lease)
        before = self.store.list_evidence(run.run_id)
        events_before = self.store.list_events(run.run_id)

        with self.assertRaisesRegex(ValueError, "REVIEW"):
            self.store.transition_gota_to_done(run.run_id, lease)

        self.assertEqual(self.store.get_run(run.run_id).state, TaskState.DONE)
        self.assertEqual(self.store.list_evidence(run.run_id), before)
        self.assertEqual(self.store.list_events(run.run_id), events_before)

    def test_checkpoints_resume_without_repeating_confirmed_steps(self) -> None:
        _, run = self.create_task("recover")
        lease = self.service.start(run.run_id, owner_id="worker")
        executor = FakeExecutor(self.store)
        calls: list[str] = []
        steps = (
            ("inspect", lambda: calls.append("inspect")),
            ("edit", lambda: calls.append("edit")),
        )
        self.assertEqual(executor.execute_steps(run.run_id, lease, steps), ("inspect", "edit"))
        self.assertEqual(executor.execute_steps(run.run_id, lease, steps), ())
        self.assertEqual(calls, ["inspect", "edit"])
        checkpoint = self.store.latest_checkpoint(run.run_id)
        self.assertEqual(checkpoint.payload["confirmed_steps"], ["inspect", "edit"])

    def test_checkpoint_is_immutable_and_recoverable_after_reopen(self) -> None:
        _, run = self.create_task("checkpoint")
        lease = self.service.start(run.run_id, owner_id="worker")
        checkpoint = self.store.append_checkpoint(
            run.run_id, {"confirmed_steps": ["one"]}, lease
        )
        reopened = SQLiteCoordinatorStore(self.database)
        self.assertEqual(
            reopened.latest_checkpoint(run.run_id).digest,
            checkpoint.digest,
        )
        with self.assertRaises(sqlite3.IntegrityError):
            with reopened.transaction(immediate=True) as connection:
                connection.execute(
                    "UPDATE checkpoints SET payload_json = '{}' WHERE checkpoint_id = ?",
                    (checkpoint.checkpoint_id,),
                )

    def test_projects_with_same_task_shape_remain_isolated(self) -> None:
        spec_a, run_a = self.create_task("alpha", project_id="project-a")
        spec_b, run_b = self.create_task("beta", project_id="project-b")
        self.assertNotEqual(spec_a.context_id, spec_b.context_id)
        self.assertNotEqual(run_a.run_id, run_b.run_id)
        self.assertEqual(self.store.get_context(spec_a.context_id).project_id, "project-a")
        self.assertEqual(self.store.get_context(spec_b.context_id).project_id, "project-b")


if __name__ == "__main__":
    import unittest

    unittest.main()
