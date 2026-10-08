from __future__ import annotations

import hashlib
import json
import sqlite3
import subprocess
import tempfile
import unittest
from datetime import UTC, datetime, timedelta
from pathlib import Path
from unittest.mock import patch

from flow_coordinator import (
    GOTA_PROTOCOL,
    GotaCheckpoint,
    GotaDecisionApplicationBoundary,
    GotaDecisionApplicationError,
    GotaDecisionResult,
    GotaMessage,
    GotaNextAction,
    GotaPhase,
    GotaRequest,
    GotaReviewResult,
    GotaWorkerReviewBoundary,
    GotaWorkerResult,
    ReviewDecision,
    SQLiteCoordinatorStore,
    TaskSpec,
    TaskState,
    WorkerResultStatus,
)
from flow_coordinator.domain import isoformat
from flow_coordinator.service import CoordinatorService
from flow_coordinator.store import FencingTokenError, LeaseExpiredError


def _canonical_json(value: object) -> str:
    return json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=False)


def _digest(value: object) -> str:
    return hashlib.sha256(_canonical_json(value).encode("utf-8")).hexdigest()


class FixedClockStore(SQLiteCoordinatorStore):
    def __init__(self, path: str | Path, trusted_now: datetime) -> None:
        self.fixed_trusted_now = trusted_now
        super().__init__(path)

    def _trusted_now(self) -> datetime:
        return self.fixed_trusted_now


class SequencedClockStore(SQLiteCoordinatorStore):
    def __init__(self, path: str | Path, trusted_times: tuple[datetime, ...]) -> None:
        self.trusted_times = iter(trusted_times)
        self.last_trusted_time = trusted_times[-1]
        super().__init__(path)

    def _trusted_now(self) -> datetime:
        try:
            self.last_trusted_time = next(self.trusted_times)
        except StopIteration:
            pass
        return self.last_trusted_time


class FailOnFencedCheckStore(SQLiteCoordinatorStore):
    def __init__(self, path: str | Path, fail_on: int) -> None:
        self.fenced_checks = 0
        self.fail_on = fail_on
        super().__init__(path)

    def _assert_fenced_connection(self, connection, lease, current_time) -> None:
        self.fenced_checks += 1
        super()._assert_fenced_connection(connection, lease, current_time)
        if self.fenced_checks == self.fail_on:
            raise LeaseExpiredError("controlled final lease failure")


class GotaDecisionApplicationTest(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary_directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary_directory.cleanup)
        self.root = Path(self.temporary_directory.name)
        self.repository = self.root / "repository"
        self.repository.mkdir()
        self._git("init", "--initial-branch=feature/gota-decision-application")
        self._git("config", "user.name", "Gota Decision Application Test")
        self._git("config", "user.email", "gota-decision-application@example.invalid")
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
            task_id="gota-decision-application-task",
            title="Gota decision application task",
            objective="Apply one durable Gota review decision",
            project_id="gota-decision-application-project",
            repository_id="gota-decision-application-repository",
            branch="feature/gota-decision-application",
            base_sha=self.base_sha,
            context_id="gota-decision-application-context",
            allowed_paths=("src/change.py",),
            protected_paths=("demo/main.tscn", "export_presets.cfg"),
            required_resources=(),
            acceptance_criteria=("Apply the durable review action",),
            commit_message="test: apply durable gota decision",
        )
        self.run = self.service.create_task(
            spec, {"workspace": str(self.repository)}
        )
        self.lease = self.service.start(self.run.run_id, owner_id="gota-worker")
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
        self._prepare_worker_review_frontier()
        self.review_request_id = f"{self.run.run_id}:1:review"

    def _git(self, *arguments: str) -> str:
        completed = subprocess.run(
            ("git", *arguments),
            cwd=self.repository,
            check=True,
            capture_output=True,
            text=True,
        )
        return completed.stdout.rstrip("\n")

    def _prepare_worker_review_frontier(self) -> None:
        self.store.reserve_gota_worker_invocation(
            self.run.run_id, self.request, self.lease
        )
        (self.repository / "src/change.py").write_text(
            "value = 'worker'\n", encoding="utf-8"
        )
        self._git("add", "--", "src/change.py")
        self._git("commit", "-m", "worker change")
        self.worker_sha = self._git("rev-parse", "HEAD")
        self.worker_result = GotaWorkerResult(
            protocol=GOTA_PROTOCOL,
            message=GotaMessage.WORKER_RESULT.value,
            request_id=self.request.request_id,
            task_id=self.request.task_id,
            run_id=self.request.run_id,
            attempt=self.request.attempt,
            result=WorkerResultStatus.READY_FOR_REVIEW,
            commit_sha=self.worker_sha,
            changed_paths=("src/change.py",),
            evidence=({"kind": "worker", "durable": True},),
            checkpoint=GotaCheckpoint(
                completed_steps=("implementation",), remaining_phase="review"
            ),
        )
        self.store.persist_gota_worker_result(
            self.run.run_id, self.worker_result, self.lease
        )
        entered = GotaWorkerReviewBoundary(
            self.repository, store=self.store
        ).run(
            self.run.run_id,
            self.lease,
            attempt=1,
            request_id=self.request.request_id,
        )
        self.assertEqual(entered.state, TaskState.REVIEW)

    def _review_result(
        self,
        decision: ReviewDecision = ReviewDecision.PASSED,
    ) -> GotaReviewResult:
        return GotaReviewResult(
            protocol=GOTA_PROTOCOL,
            message=GotaMessage.REVIEW_RESULT.value,
            request_id=self.review_request_id,
            task_id=self.run.task_id,
            run_id=self.run.run_id,
            attempt=1,
            reviewed_commit_sha=self.worker_sha,
            decision=decision,
            findings=(),
            evidence=({"kind": "review", "durable": True},),
        )

    def _persist_review(
        self,
        decision: ReviewDecision = ReviewDecision.PASSED,
    ) -> GotaReviewResult:
        review = self._review_result(decision)
        self.store.persist_gota_review_result(self.run.run_id, review, self.lease)
        return review

    def _apply(
        self,
        decision: ReviewDecision = ReviewDecision.PASSED,
        *,
        store: SQLiteCoordinatorStore | None = None,
        request_id: str | None = None,
    ):
        self._persist_review(decision)
        active_store = store or self.store
        return GotaDecisionApplicationBoundary(active_store).run(
            self.run.run_id,
            self.lease,
            attempt=1,
            request_id=request_id or self.request.request_id,
        )

    def _evidence(self, kind: str):
        matches = [
            item for item in self.store.list_evidence(self.run.run_id)
            if item.kind == kind
        ]
        self.assertEqual(len(matches), 1)
        return matches[0]

    def _update_evidence(self, evidence_id: str, payload: dict[str, object]) -> None:
        connection = sqlite3.connect(self.database)
        try:
            connection.execute("PRAGMA foreign_keys = OFF")
            connection.execute("DROP TRIGGER immutable_evidence_update")
            connection.execute(
                "UPDATE evidence SET payload_json = ?, digest = ? WHERE evidence_id = ?",
                (_canonical_json(payload), _digest(payload), evidence_id),
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

    def _update_anchor(self, field: str, value: object) -> None:
        connection = sqlite3.connect(self.database)
        try:
            connection.execute("PRAGMA foreign_keys = OFF")
            connection.execute("DROP TRIGGER immutable_gota_review_results_update")
            connection.execute(
                f"UPDATE gota_review_results SET {field} = ? WHERE run_id = ?",
                (value, self.run.run_id),
            )
            connection.commit()
        finally:
            connection.execute(
                """
                CREATE TRIGGER IF NOT EXISTS immutable_gota_review_results_update
                BEFORE UPDATE ON gota_review_results
                BEGIN SELECT RAISE(ABORT, 'gota_review_results is immutable'); END
                """
            )
            connection.commit()
            connection.close()

    def _update_worker_anchor(self, field: str, value: object) -> None:
        connection = sqlite3.connect(self.database)
        try:
            connection.execute("PRAGMA foreign_keys = OFF")
            connection.execute(
                "DROP TRIGGER immutable_gota_worker_review_boundaries_update"
            )
            connection.execute(
                f"UPDATE gota_worker_review_boundaries SET {field} = ? WHERE run_id = ?",
                (value, self.run.run_id),
            )
            connection.commit()
        finally:
            connection.execute(
                """
                CREATE TRIGGER IF NOT EXISTS immutable_gota_worker_review_boundaries_update
                BEFORE UPDATE ON gota_worker_review_boundaries
                BEGIN SELECT RAISE(ABORT, 'gota_worker_review_boundaries is immutable'); END
                """
            )
            connection.commit()
            connection.close()

    def _delete_hold(self) -> None:
        connection = sqlite3.connect(self.database)
        try:
            connection.execute("PRAGMA foreign_keys = OFF")
            connection.execute("DROP TRIGGER immutable_gota_human_review_holds_delete")
            connection.execute(
                "DELETE FROM gota_human_review_holds WHERE run_id = ?",
                (self.run.run_id,),
            )
            connection.commit()
        finally:
            connection.execute(
                """
                CREATE TRIGGER IF NOT EXISTS immutable_gota_human_review_holds_delete
                BEFORE DELETE ON gota_human_review_holds
                BEGIN SELECT RAISE(ABORT, 'gota_human_review_holds is immutable'); END
                """
            )
            connection.commit()
            connection.close()

    def _force_legacy_state(self, state: TaskState, reason: str = "legacy") -> None:
        connection = sqlite3.connect(self.database)
        try:
            connection.execute(
                "UPDATE task_runs SET state = ? WHERE run_id = ?",
                (state.value, self.run.run_id),
            )
            connection.execute(
                """
                INSERT INTO transition_events(
                    run_id, from_state, to_state, actor, reason,
                    fencing_token, created_at
                ) VALUES (?, ?, ?, ?, ?, ?, ?)
                """,
                (
                    self.run.run_id,
                    TaskState.REVIEW.value,
                    state.value,
                    "legacy",
                    reason,
                    self.lease.fencing_token,
                    isoformat(self.lease.acquired_at),
                ),
            )
            connection.commit()
        finally:
            connection.close()

    def test_policy_resolve_is_the_real_application_authority(self) -> None:
        with patch(
            "flow_coordinator.gota_decision_application.GotaDecisionPolicy.resolve",
            wraps=__import__(
                "flow_coordinator.decision_policy",
                fromlist=["GotaDecisionPolicy"],
            ).GotaDecisionPolicy.resolve,
        ) as resolver:
            result = self._apply(ReviewDecision.CORRECTION_REQUIRED)
        self.assertEqual(result.action, GotaNextAction.CORRECT)
        resolver.assert_called_once()

    def test_policy_action_is_dispatched_without_review_decision_mapping(self) -> None:
        review = self._persist_review(ReviewDecision.PASSED)
        forced = GotaDecisionResult(
            action=GotaNextAction.BLOCK,
            review_result=review,
            review_decision=ReviewDecision.PASSED,
            cycle_failure=None,
            reason="controlled policy action",
        )
        with patch(
            "flow_coordinator.gota_decision_application.GotaDecisionPolicy.resolve",
            return_value=forced,
        ):
            result = GotaDecisionApplicationBoundary(self.store).run(
                self.run.run_id,
                self.lease,
                attempt=1,
                request_id=self.request.request_id,
            )
        self.assertEqual(result.action, GotaNextAction.BLOCK)
        self.assertEqual(result.state, TaskState.BLOCKED)

    def test_passed_uses_transition_gota_to_done(self) -> None:
        with patch.object(
            self.store,
            "transition_gota_to_done",
            wraps=self.store.transition_gota_to_done,
        ) as transition:
            result = self._apply(ReviewDecision.PASSED)
        transition.assert_called_once_with(self.run.run_id, self.lease)
        self.assertEqual(result.state, TaskState.DONE)

    def test_passed_creates_exactly_one_acceptance_evidence(self) -> None:
        self._apply(ReviewDecision.PASSED)
        evidence = self.store.list_evidence(self.run.run_id)
        self.assertEqual(
            sum(item.kind == "gota_acceptance_verified" for item in evidence), 1
        )
        self.assertEqual(
            sum(
                event.reason == "gota_acceptance_verified"
                and event.from_state is TaskState.REVIEW
                and event.to_state is TaskState.DONE
                for event in self.store.list_events(self.run.run_id)
            ),
            1,
        )

    def test_passed_second_call_does_not_duplicate_any_authority(self) -> None:
        self._apply(ReviewDecision.PASSED)
        before_evidence = self.store.list_evidence(self.run.run_id)
        before_events = self.store.list_events(self.run.run_id)
        with patch.object(
            self.store,
            "transition_gota_to_done",
            wraps=self.store.transition_gota_to_done,
        ) as transition:
            result = GotaDecisionApplicationBoundary(self.store).run(
                self.run.run_id,
                self.lease,
                attempt=1,
                request_id=self.request.request_id,
            )
        transition.assert_not_called()
        self.assertTrue(result.already_applied)
        self.assertEqual(self.store.list_evidence(self.run.run_id), before_evidence)
        self.assertEqual(self.store.list_events(self.run.run_id), before_events)

    def test_done_recovery_is_read_only_and_requires_gota_authority(self) -> None:
        self._apply(ReviewDecision.PASSED)
        reopened = SQLiteCoordinatorStore(self.database)
        result = GotaDecisionApplicationBoundary(reopened).run(
            self.run.run_id,
            self.lease,
            attempt=1,
            request_id=self.review_request_id,
        )
        self.assertEqual(result.state, TaskState.DONE)
        self.assertTrue(result.already_applied)

    def test_correction_required_reaches_not_completed(self) -> None:
        result = self._apply(ReviewDecision.CORRECTION_REQUIRED)
        self.assertEqual(result.action, GotaNextAction.CORRECT)
        self.assertEqual(result.state, TaskState.NOT_COMPLETED)

    def test_correction_creates_one_evidence_and_no_hold(self) -> None:
        self._apply(ReviewDecision.CORRECTION_REQUIRED)
        self.assertEqual(
            sum(
                item.kind == "gota_decision_applied"
                for item in self.store.list_evidence(self.run.run_id)
            ),
            1,
        )
        self.assertIsNone(
            self.store.load_gota_human_review_hold(
                self.run.run_id, 1, self.review_request_id
            )
        )

    def test_correction_second_call_is_idempotent(self) -> None:
        self._apply(ReviewDecision.CORRECTION_REQUIRED)
        before_evidence = self.store.list_evidence(self.run.run_id)
        before_events = self.store.list_events(self.run.run_id)
        result = GotaDecisionApplicationBoundary(self.store).run(
            self.run.run_id,
            self.lease,
            attempt=1,
            request_id=self.request.request_id,
        )
        self.assertTrue(result.already_applied)
        self.assertEqual(self.store.list_evidence(self.run.run_id), before_evidence)
        self.assertEqual(self.store.list_events(self.run.run_id), before_events)

    def test_human_review_required_reaches_not_completed(self) -> None:
        result = self._apply(ReviewDecision.HUMAN_REVIEW_REQUIRED)
        self.assertEqual(result.action, GotaNextAction.WAIT_FOR_HUMAN)
        self.assertEqual(result.state, TaskState.NOT_COMPLETED)

    def test_human_review_creates_one_evidence_and_one_hold(self) -> None:
        result = self._apply(ReviewDecision.HUMAN_REVIEW_REQUIRED)
        self.assertIsNotNone(result.human_review_hold)
        self.assertEqual(
            sum(
                item.kind == "gota_decision_applied"
                for item in self.store.list_evidence(self.run.run_id)
            ),
            1,
        )
        self.assertEqual(
            self.store.load_gota_human_review_hold(
                self.run.run_id, 1, self.review_request_id
            ),
            result.human_review_hold,
        )

    def test_human_review_hold_persists_after_reopen(self) -> None:
        result = self._apply(ReviewDecision.HUMAN_REVIEW_REQUIRED)
        reopened = SQLiteCoordinatorStore(self.database)
        self.assertEqual(
            reopened.load_gota_human_review_hold(
                self.run.run_id, 1, self.review_request_id
            ),
            result.human_review_hold,
        )

    def test_human_review_second_call_is_idempotent(self) -> None:
        self._apply(ReviewDecision.HUMAN_REVIEW_REQUIRED)
        before_evidence = self.store.list_evidence(self.run.run_id)
        before_events = self.store.list_events(self.run.run_id)
        result = GotaDecisionApplicationBoundary(self.store).run(
            self.run.run_id,
            self.lease,
            attempt=1,
            request_id=self.request.request_id,
        )
        self.assertTrue(result.already_applied)
        self.assertEqual(self.store.list_evidence(self.run.run_id), before_evidence)
        self.assertEqual(self.store.list_events(self.run.run_id), before_events)
        self.assertEqual(
            len(
                [
                    item
                    for item in self.store.list_evidence(self.run.run_id)
                    if item.kind == "gota_decision_applied"
                ]
            ),
            1,
        )

    def test_blocked_reaches_blocked(self) -> None:
        result = self._apply(ReviewDecision.BLOCKED)
        self.assertEqual(result.action, GotaNextAction.BLOCK)
        self.assertEqual(result.state, TaskState.BLOCKED)

    def test_blocked_creates_one_evidence_and_no_hold(self) -> None:
        self._apply(ReviewDecision.BLOCKED)
        self.assertEqual(
            sum(
                item.kind == "gota_decision_applied"
                for item in self.store.list_evidence(self.run.run_id)
            ),
            1,
        )
        self.assertIsNone(
            self.store.load_gota_human_review_hold(
                self.run.run_id, 1, self.review_request_id
            )
        )

    def test_blocked_second_call_is_idempotent(self) -> None:
        self._apply(ReviewDecision.BLOCKED)
        before_evidence = self.store.list_evidence(self.run.run_id)
        before_events = self.store.list_events(self.run.run_id)
        result = GotaDecisionApplicationBoundary(self.store).run(
            self.run.run_id,
            self.lease,
            attempt=1,
            request_id=self.request.request_id,
        )
        self.assertTrue(result.already_applied)
        self.assertEqual(self.store.list_evidence(self.run.run_id), before_evidence)
        self.assertEqual(self.store.list_events(self.run.run_id), before_events)

    def test_cycle_failed_is_not_reachable_from_intact_durable_review(self) -> None:
        self._persist_review(ReviewDecision.PASSED)
        authorities = self.store.load_gota_decision_authorities(
            self.run.run_id, 1, self.request.request_id
        )
        from flow_coordinator.gota_decision_application import (
            GotaDecisionApplicationBoundary as Boundary,
        )

        resolution = __import__(
            "flow_coordinator.decision_policy",
            fromlist=["GotaDecisionPolicy"],
        ).GotaDecisionPolicy.resolve(Boundary._canonical_cycle(authorities))
        self.assertNotEqual(resolution.action, GotaNextAction.CYCLE_FAILED)

    def test_cycle_failed_is_rejected_without_materialization(self) -> None:
        review = self._persist_review(ReviewDecision.PASSED)
        forced = GotaDecisionResult(
            action=GotaNextAction.CYCLE_FAILED,
            review_result=review,
            review_decision=ReviewDecision.PASSED,
            cycle_failure=None,
            reason="ephemeral failure is not durable",
        )
        with patch(
            "flow_coordinator.gota_decision_application.GotaDecisionPolicy.resolve",
            return_value=forced,
        ), self.assertRaises(GotaDecisionApplicationError):
            GotaDecisionApplicationBoundary(self.store).run(
                self.run.run_id,
                self.lease,
                attempt=1,
                request_id=self.request.request_id,
            )
        self.assertEqual(self.store.get_run(self.run.run_id).state, TaskState.REVIEW)
        self.assertEqual(self.store.list_evidence(self.run.run_id)[-1].kind, "gota_review_result")

    def test_worker_calls_are_zero(self) -> None:
        self._persist_review(ReviewDecision.CORRECTION_REQUIRED)
        boundary = GotaDecisionApplicationBoundary(self.store)
        self.assertFalse(hasattr(boundary, "worker_phase"))
        self.assertEqual(self._apply(ReviewDecision.CORRECTION_REQUIRED).state, TaskState.NOT_COMPLETED)

    def test_reviewer_calls_are_zero(self) -> None:
        self._persist_review(ReviewDecision.BLOCKED)
        boundary = GotaDecisionApplicationBoundary(self.store)
        self.assertFalse(hasattr(boundary, "review_phase"))
        self.assertEqual(self._apply(ReviewDecision.BLOCKED).state, TaskState.BLOCKED)

    def test_failure_between_evidence_and_state_rolls_back(self) -> None:
        self._persist_review(ReviewDecision.CORRECTION_REQUIRED)
        with self.store.transaction(immediate=True) as connection:
            connection.execute(
                f"""
                CREATE TRIGGER reject_decision_state
                BEFORE UPDATE ON task_runs
                WHEN NEW.run_id = '{self.run.run_id}'
                  AND NEW.state = '{TaskState.NOT_COMPLETED.value}'
                BEGIN SELECT RAISE(ABORT, 'controlled decision rollback'); END
                """
            )
        try:
            with self.assertRaisesRegex(sqlite3.IntegrityError, "controlled decision rollback"):
                GotaDecisionApplicationBoundary(self.store).run(
                    self.run.run_id,
                    self.lease,
                    attempt=1,
                    request_id=self.request.request_id,
                )
        finally:
            with self.store.transaction(immediate=True) as connection:
                connection.execute("DROP TRIGGER reject_decision_state")
        self.assertEqual(self.store.get_run(self.run.run_id).state, TaskState.REVIEW)
        self.assertEqual(
            [item.kind for item in self.store.list_evidence(self.run.run_id)],
            [
                "gota_worker_request_registered",
                "gota_worker_invocation_started",
                "gota_worker_result_received",
                "gota_worker_commit_verified",
                "gota_review_result",
            ],
        )

    def test_failure_after_hold_rolls_back_everything(self) -> None:
        self._persist_review(ReviewDecision.HUMAN_REVIEW_REQUIRED)
        failing_store = FailOnFencedCheckStore(self.database, fail_on=2)
        with self.assertRaisesRegex(LeaseExpiredError, "controlled final"):
            GotaDecisionApplicationBoundary(failing_store).run(
                self.run.run_id,
                self.lease,
                attempt=1,
                request_id=self.request.request_id,
            )
        self.assertEqual(self.store.get_run(self.run.run_id).state, TaskState.REVIEW)
        self.assertNotIn(
            "gota_decision_applied",
            [item.kind for item in self.store.list_evidence(self.run.run_id)],
        )
        self.assertEqual(
            self.store.table_names().count("gota_human_review_holds"), 1
        )
        self.assertIsNone(
            self.store.load_gota_human_review_hold(
                self.run.run_id, 1, self.review_request_id
            )
        )

    def test_expired_lease_rejects_without_evidence(self) -> None:
        self._persist_review(ReviewDecision.CORRECTION_REQUIRED)
        expired_store = FixedClockStore(
            self.database, self.lease.expires_at + timedelta(seconds=1)
        )
        with self.assertRaises(LeaseExpiredError):
            GotaDecisionApplicationBoundary(expired_store).run(
                self.run.run_id,
                self.lease,
                attempt=1,
                request_id=self.request.request_id,
            )
        self.assertEqual(self.store.get_run(self.run.run_id).state, TaskState.REVIEW)

    def test_stale_fence_rejects_without_evidence(self) -> None:
        self._persist_review(ReviewDecision.CORRECTION_REQUIRED)
        with self.store.transaction(immediate=True) as connection:
            connection.execute(
                "UPDATE global_lock SET stale = 1 WHERE lock_name = 'global'"
            )
        with self.assertRaises(FencingTokenError):
            GotaDecisionApplicationBoundary(self.store).run(
                self.run.run_id,
                self.lease,
                attempt=1,
                request_id=self.request.request_id,
            )
        self.assertEqual(self.store.get_run(self.run.run_id).state, TaskState.REVIEW)

    def test_expiry_in_final_check_rolls_back(self) -> None:
        self._persist_review(ReviewDecision.CORRECTION_REQUIRED)
        live = self.lease.acquired_at + timedelta(seconds=1)
        expired = self.lease.expires_at + timedelta(seconds=1)
        sequenced = SequencedClockStore(self.database, (live, expired))
        with self.assertRaises(LeaseExpiredError):
            GotaDecisionApplicationBoundary(sequenced).run(
                self.run.run_id,
                self.lease,
                attempt=1,
                request_id=self.request.request_id,
            )
        self.assertEqual(self.store.get_run(self.run.run_id).state, TaskState.REVIEW)
        self.assertNotIn(
            "gota_decision_applied",
            [item.kind for item in self.store.list_evidence(self.run.run_id)],
        )

    def test_review_with_preexisting_decision_evidence_fails_closed(self) -> None:
        self._persist_review(ReviewDecision.CORRECTION_REQUIRED)
        with self.store.transaction(immediate=True) as connection:
            self.store._insert_evidence(
                connection,
                self.run.run_id,
                "gota_decision_applied",
                {"partial": True},
                self.lease,
                self.store._trusted_now(),
            )
        with self.assertRaises(GotaDecisionApplicationError):
            GotaDecisionApplicationBoundary(self.store).run(
                self.run.run_id,
                self.lease,
                attempt=1,
                request_id=self.request.request_id,
            )
        self.assertEqual(self.store.get_run(self.run.run_id).state, TaskState.REVIEW)

    def test_terminal_without_gota_authority_fails_closed(self) -> None:
        self._persist_review(ReviewDecision.CORRECTION_REQUIRED)
        self._force_legacy_state(TaskState.NOT_COMPLETED, "legacy_failure")
        with self.assertRaises(GotaDecisionApplicationError):
            GotaDecisionApplicationBoundary(self.store).run(
                self.run.run_id,
                self.lease,
                attempt=1,
                request_id=self.request.request_id,
            )

    def test_duplicate_decision_evidence_fails_closed(self) -> None:
        self._apply(ReviewDecision.CORRECTION_REQUIRED)
        decision = self._evidence("gota_decision_applied")
        with self.store.transaction(immediate=True) as connection:
            self.store._insert_evidence(
                connection,
                self.run.run_id,
                "gota_decision_applied",
                decision.payload,
                self.lease,
                self.store._trusted_now(),
            )
        with self.assertRaises(GotaDecisionApplicationError):
            GotaDecisionApplicationBoundary(self.store).run(
                self.run.run_id,
                self.lease,
                attempt=1,
                request_id=self.request.request_id,
            )

    def test_review_evidence_link_tampering_fails_closed(self) -> None:
        self._persist_review()
        worker_evidence = self._evidence("gota_worker_result_received")
        self._update_anchor("review_evidence_id", worker_evidence.evidence_id)
        with self.assertRaises(GotaDecisionApplicationError):
            GotaDecisionApplicationBoundary(self.store).run(
                self.run.run_id,
                self.lease,
                attempt=1,
                request_id=self.request.request_id,
            )

    def test_review_digest_tampering_fails_closed(self) -> None:
        self._persist_review()
        review_evidence = self._evidence("gota_review_result")
        connection = sqlite3.connect(self.database)
        try:
            connection.execute("PRAGMA foreign_keys = OFF")
            connection.execute("DROP TRIGGER immutable_evidence_update")
            connection.execute(
                "UPDATE evidence SET digest = ? WHERE evidence_id = ?",
                ("0" * 64, review_evidence.evidence_id),
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
        with self.assertRaises(GotaDecisionApplicationError):
            GotaDecisionApplicationBoundary(self.store).run(
                self.run.run_id,
                self.lease,
                attempt=1,
                request_id=self.request.request_id,
            )

    def test_worker_commit_link_tampering_fails_closed(self) -> None:
        self._persist_review()
        worker_evidence = self._evidence("gota_worker_result_received")
        self._update_anchor("worker_commit_evidence_id", worker_evidence.evidence_id)
        with self.assertRaises(GotaDecisionApplicationError):
            GotaDecisionApplicationBoundary(self.store).run(
                self.run.run_id,
                self.lease,
                attempt=1,
                request_id=self.request.request_id,
            )

    def test_worker_review_event_mismatch_fails_closed(self) -> None:
        self._persist_review()
        initial_event = self.store.list_events(self.run.run_id)[0]
        self._update_worker_anchor("transition_event_id", initial_event.event_id)
        with self.assertRaises(GotaDecisionApplicationError):
            GotaDecisionApplicationBoundary(self.store).run(
                self.run.run_id,
                self.lease,
                attempt=1,
                request_id=self.request.request_id,
            )

    def test_target_state_mismatch_fails_closed(self) -> None:
        self._apply(ReviewDecision.CORRECTION_REQUIRED)
        decision = self._evidence("gota_decision_applied")
        payload = dict(decision.payload)
        payload["to_state"] = TaskState.BLOCKED.value
        self._update_evidence(decision.evidence_id, payload)
        with self.assertRaises(GotaDecisionApplicationError):
            GotaDecisionApplicationBoundary(self.store).run(
                self.run.run_id,
                self.lease,
                attempt=1,
                request_id=self.request.request_id,
            )

    def test_human_review_without_hold_fails_closed(self) -> None:
        self._apply(ReviewDecision.HUMAN_REVIEW_REQUIRED)
        self._delete_hold()
        with self.assertRaises(GotaDecisionApplicationError):
            GotaDecisionApplicationBoundary(self.store).run(
                self.run.run_id,
                self.lease,
                attempt=1,
                request_id=self.request.request_id,
            )

    def test_correction_with_unexpected_hold_fails_closed(self) -> None:
        self._apply(ReviewDecision.CORRECTION_REQUIRED)
        review_evidence = self._evidence("gota_review_result")
        decision = self._evidence("gota_decision_applied")
        with self.store.transaction(immediate=True) as connection:
            connection.execute(
                """
                INSERT INTO gota_human_review_holds(
                    run_id, attempt, request_id, review_evidence_id,
                    review_evidence_digest, decision_evidence_id,
                    decision_evidence_digest, created_at
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                """,
                (
                    self.run.run_id,
                    1,
                    self.review_request_id,
                    review_evidence.evidence_id,
                    review_evidence.digest,
                    decision.evidence_id,
                    decision.digest,
                    isoformat(decision.created_at),
                ),
            )
        with self.assertRaises(GotaDecisionApplicationError):
            GotaDecisionApplicationBoundary(self.store).run(
                self.run.run_id,
                self.lease,
                attempt=1,
                request_id=self.request.request_id,
            )

    def test_append_evidence_cannot_fabricate_decision_authority(self) -> None:
        self._persist_review(ReviewDecision.CORRECTION_REQUIRED)
        with self.assertRaisesRegex(Exception, "reserved"):
            self.store.append_evidence(
                self.run.run_id,
                "gota_decision_applied",
                {"arbitrary": True},
                self.lease,
            )
        self.assertNotIn(
            "gota_decision_applied",
            [item.kind for item in self.store.list_evidence(self.run.run_id)],
        )

    def test_legacy_done_is_not_confused_with_gota_done(self) -> None:
        self._persist_review(ReviewDecision.PASSED)
        self._force_legacy_state(TaskState.DONE, "legacy_done")
        with self.assertRaises(GotaDecisionApplicationError):
            GotaDecisionApplicationBoundary(self.store).run(
                self.run.run_id,
                self.lease,
                attempt=1,
                request_id=self.request.request_id,
            )

    def test_restart_preserves_non_passed_idempotence(self) -> None:
        self._apply(ReviewDecision.BLOCKED)
        reopened = SQLiteCoordinatorStore(self.database)
        before = reopened.list_evidence(self.run.run_id)
        result = GotaDecisionApplicationBoundary(reopened).run(
            self.run.run_id,
            self.lease,
            attempt=1,
            request_id=self.review_request_id,
        )
        self.assertTrue(result.already_applied)
        self.assertEqual(reopened.list_evidence(self.run.run_id), before)


if __name__ == "__main__":
    unittest.main()
