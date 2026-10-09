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
from typing import Callable

from flow_coordinator import (
    GOTA_PROTOCOL,
    GotaCheckpoint,
    GotaFinding,
    GotaMessage,
    GotaPhase,
    GotaRequest,
    GotaReviewResult,
    GotaReviewerPersistenceBoundary,
    GotaWorkerReviewBoundary,
    GotaWorkerResult,
    OpenCodeRunResult,
    OpenCodeRunStatus,
    ReviewDecision,
    ReviewPhaseResult,
    TaskState,
    WorkerResultStatus,
)
from flow_coordinator.domain import Lease, TaskSpec, isoformat
from flow_coordinator.service import CoordinatorService
from flow_coordinator.store import (
    AcceptanceEvidenceError,
    FencingTokenError,
    GotaReviewResultError,
    LeaseExpiredError,
    SQLiteCoordinatorStore,
)


def _canonical_json(value: object) -> str:
    return json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=False)


def _digest(value: object) -> str:
    return hashlib.sha256(_canonical_json(value).encode("utf-8")).hexdigest()


class ReviewRunner:
    def __init__(self, step: Callable[[str], OpenCodeRunResult]) -> None:
        self.step = step
        self.calls: list[dict[str, object]] = []

    def run(
        self,
        *,
        agent: str,
        prompt: str,
        cwd: str | Path,
        timeout: float,
    ) -> OpenCodeRunResult:
        self.calls.append(
            {
                "agent": agent,
                "prompt": prompt,
                "cwd": Path(cwd),
                "timeout": timeout,
            }
        )
        return self.step(prompt)


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


class GotaReviewPersistenceTest(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary_directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary_directory.cleanup)
        self.root = Path(self.temporary_directory.name)
        self.repository = self.root / "repository"
        self.repository.mkdir()
        self._git("init", "--initial-branch=feature/gota-review-persistence")
        self._git("config", "user.name", "Gota Review Persistence Test")
        self._git("config", "user.email", "gota-review-persistence@example.invalid")
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
            task_id="review-persistence-task",
            title="Review persistence task",
            objective="Persist one durable Reviewer result",
            project_id="review-persistence-project",
            repository_id="review-persistence-repository",
            branch="feature/gota-review-persistence",
            base_sha=self.base_sha,
            context_id="review-persistence-context",
            allowed_paths=("src/change.py",),
            protected_paths=("demo/main.tscn", "export_presets.cfg"),
            required_resources=(),
            acceptance_criteria=("Remain in REVIEW after reviewing",),
            commit_message="test: persist review result",
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
        completed = subprocess.run(
            ("git", *arguments),
            cwd=self.repository,
            check=True,
            capture_output=True,
            text=True,
        )
        return completed.stdout.rstrip("\n")

    def _worker_result(self, commit_sha: str) -> GotaWorkerResult:
        return GotaWorkerResult(
            protocol=GOTA_PROTOCOL,
            message=GotaMessage.WORKER_RESULT.value,
            request_id=self.request.request_id,
            task_id=self.request.task_id,
            run_id=self.request.run_id,
            attempt=self.request.attempt,
            result=WorkerResultStatus.READY_FOR_REVIEW,
            commit_sha=commit_sha,
            changed_paths=("src/change.py",),
            evidence=({"kind": "worker", "passed": True},),
            checkpoint=GotaCheckpoint(
                completed_steps=("implementation",), remaining_phase="review"
            ),
        )

    def _review_result(
        self,
        *,
        commit_sha: str,
        decision: ReviewDecision = ReviewDecision.PASSED,
    ) -> GotaReviewResult:
        return GotaReviewResult(
            protocol=GOTA_PROTOCOL,
            message=GotaMessage.REVIEW_RESULT.value,
            request_id=f"{self.run.run_id}:1:review",
            task_id=self.run.task_id,
            run_id=self.run.run_id,
            attempt=1,
            reviewed_commit_sha=commit_sha,
            decision=decision,
            findings=(
                GotaFinding(
                    id="review-finding",
                    severity="info",
                    description="The reviewed commit is durable.",
                    path="src/change.py",
                    required_change="None",
                ),
            ),
            evidence=(
                {"kind": "review", "checked_sha": commit_sha},
                {"kind": "manual", "note": "read-only"},
            ),
        )

    def _successful_execution(
        self,
        result: GotaReviewResult,
        *,
        commit_sha: str | None = None,
    ) -> OpenCodeRunResult:
        if commit_sha is not None:
            result = replace(result, reviewed_commit_sha=commit_sha)
        return OpenCodeRunResult(
            status=OpenCodeRunStatus.SUCCEEDED,
            argv=("fake-reviewer",),
            cwd=str(self.repository),
            stdout="review output",
            stderr="",
            exit_code=0,
            timed_out=False,
            payload=result,
        )

    def _durable_worker_and_review_frontier(self) -> GotaWorkerResult:
        self.store.reserve_gota_worker_invocation(
            self.run.run_id, self.request, self.lease
        )
        (self.repository / "src/change.py").write_text(
            "value = 'worker'\n", encoding="utf-8"
        )
        self._git("add", "--", "src/change.py")
        self._git("commit", "-m", "worker change")
        commit_sha = self._git("rev-parse", "HEAD")
        worker_result = self._worker_result(commit_sha)
        self.store.persist_gota_worker_result(
            self.run.run_id, worker_result, self.lease
        )
        entered = GotaWorkerReviewBoundary(self.repository, store=self.store).run(
            self.run.run_id,
            self.lease,
            attempt=1,
            request_id=self.request.request_id,
        )
        self.assertEqual(entered.state, TaskState.REVIEW)
        return worker_result

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

    def _boundary(self, runner: ReviewRunner, *, store=None) -> GotaReviewerPersistenceBoundary:
        return GotaReviewerPersistenceBoundary(
            self.repository,
            runner=runner,
            store=store or self.store,
        )

    def _run_boundary(
        self, boundary: GotaReviewerPersistenceBoundary
    ) -> ReviewPhaseResult | GotaReviewResult:
        return boundary.run(
            self.run.run_id,
            self.lease,
            attempt=1,
            request_id=self.request.request_id,
            timeout=3,
        )

    def _tamper_evidence(
        self,
        evidence_id: str,
        *,
        payload: dict[str, object] | None = None,
        digest: str | None = None,
        created_at: str | None = None,
        evidence_id_replacement: str | None = None,
    ) -> None:
        connection = sqlite3.connect(self.database)
        try:
            connection.execute("PRAGMA foreign_keys = OFF")
            connection.execute("DROP TRIGGER immutable_evidence_update")
            values: list[object] = []
            assignments: list[str] = []
            if payload is not None:
                assignments.append("payload_json = ?")
                values.append(_canonical_json(payload))
            if digest is not None:
                assignments.append("digest = ?")
                values.append(digest)
            if created_at is not None:
                assignments.append("created_at = ?")
                values.append(created_at)
            if evidence_id_replacement is not None:
                assignments.append("evidence_id = ?")
                values.append(evidence_id_replacement)
            values.append(evidence_id)
            connection.execute(
                f"UPDATE evidence SET {', '.join(assignments)} WHERE evidence_id = ?",
                values,
            )
            connection.commit()
        finally:
            connection.close()

    def _tamper_anchor(self, field: str, value: object) -> None:
        self.assertIn(
            field,
            {
                "review_evidence_id",
                "review_evidence_digest",
                "worker_commit_evidence_id",
                "created_at",
            },
        )
        connection = sqlite3.connect(self.database)
        try:
            connection.execute("PRAGMA foreign_keys = OFF")
            connection.execute(
                "DROP TRIGGER IF EXISTS immutable_gota_review_results_update"
            )
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

    def test_happy_path_reuses_durable_result_without_reviewer_retry(self) -> None:
        worker = self._durable_worker_and_review_frontier()
        expected = self._review_result(commit_sha=worker.commit_sha)
        runner = ReviewRunner(lambda _prompt: self._successful_execution(expected))
        boundary = self._boundary(runner)

        first = self._run_boundary(boundary)

        self.assertIsInstance(first, ReviewPhaseResult)
        assert isinstance(first, ReviewPhaseResult)
        self.assertTrue(first.valid)
        self.assertEqual(first.review_result, expected)
        self.assertEqual(self.store.get_run(self.run.run_id).state, TaskState.REVIEW)
        self.assertEqual(len(runner.calls), 1)
        self.assertIn(worker.commit_sha, str(runner.calls[0]["prompt"]))
        self.assertNotIn(
            "gota_acceptance_verified",
            [item.kind for item in self.store.list_evidence(self.run.run_id)],
        )
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
        anchor = self.store.load_gota_review_result_anchor(
            self.run.run_id, 1, expected.request_id
        )
        review_evidence = self.store.list_evidence(self.run.run_id)[-1]
        commit_evidence = self.store.load_gota_worker_commit_verified(
            self.run.run_id, 1, self.request.request_id
        )
        assert commit_evidence is not None
        self.assertEqual(anchor.review_evidence_id, review_evidence.evidence_id)
        self.assertEqual(anchor.review_evidence_digest, review_evidence.digest)
        self.assertEqual(anchor.worker_commit_evidence_id, commit_evidence.evidence_id)
        self.assertEqual(anchor.created_at, review_evidence.created_at)

        second = self._run_boundary(boundary)
        self.assertIsInstance(second, GotaReviewResult)
        self.assertEqual(second, expected)
        self.assertEqual(len(runner.calls), 1)

    def test_reviewer_takeover_uses_new_lease_and_same_worker_sha(self) -> None:
        worker = self._durable_worker_and_review_frontier()
        expected = self._review_result(commit_sha=worker.commit_sha)
        historical_evidence = self.store.list_evidence(self.run.run_id)
        historical_events = self.store.list_events(self.run.run_id)
        takeover = self._takeover_lease()
        runner = ReviewRunner(lambda _prompt: self._successful_execution(expected))
        boundary = self._boundary(runner)

        first = boundary.run(
            self.run.run_id,
            takeover,
            attempt=1,
            request_id=self.request.request_id,
            timeout=3,
        )

        self.assertIsInstance(first, ReviewPhaseResult)
        assert isinstance(first, ReviewPhaseResult)
        self.assertTrue(first.valid)
        self.assertEqual(first.review_result, expected)
        self.assertEqual(len(runner.calls), 1)
        self.assertIn(worker.commit_sha, str(runner.calls[0]["prompt"]))
        self.assertEqual(
            self.store.list_evidence(self.run.run_id)[: len(historical_evidence)],
            historical_evidence,
        )
        self.assertEqual(
            self.store.list_events(self.run.run_id)[: len(historical_events)],
            historical_events,
        )
        with self.store._connect() as connection:
            fences = connection.execute(
                "SELECT kind, fencing_token FROM evidence WHERE run_id = ? ORDER BY rowid",
                (self.run.run_id,),
            ).fetchall()
        self.assertEqual(
            [row["fencing_token"] for row in fences],
            [self.lease.fencing_token] * 4 + [takeover.fencing_token],
        )

        with self.assertRaises(FencingTokenError):
            boundary.run(
                self.run.run_id,
                self.lease,
                attempt=1,
                request_id=self.request.request_id,
                timeout=3,
            )
        second = boundary.run(
            self.run.run_id,
            takeover,
            attempt=1,
            request_id=self.request.request_id,
            timeout=3,
        )
        self.assertEqual(second, expected)
        self.assertEqual(len(runner.calls), 1)

    def test_all_canonical_decisions_remain_review(self) -> None:
        for decision in ReviewDecision:
            with self.subTest(decision=decision):
                self.setUp()
                worker = self._durable_worker_and_review_frontier()
                expected = self._review_result(
                    commit_sha=worker.commit_sha, decision=decision
                )
                runner = ReviewRunner(
                    lambda _prompt, expected=expected: self._successful_execution(expected)
                )
                outcome = self._run_boundary(self._boundary(runner))
                self.assertTrue(getattr(outcome, "valid", False))
                self.assertEqual(
                    self.store.get_run(self.run.run_id).state, TaskState.REVIEW
                )
                self.assertEqual(
                    [event.to_state for event in self.store.list_events(self.run.run_id)],
                    [TaskState.ASSIGNED, TaskState.RUNNING, TaskState.REVIEW],
                )
                self.assertNotIn(
                    "gota_acceptance_verified",
                    [item.kind for item in self.store.list_evidence(self.run.run_id)],
                )
                self.doCleanups()

    def test_failure_and_timeout_can_retry_without_a_reviewer_reservation(self) -> None:
        worker = self._durable_worker_and_review_frontier()
        expected = self._review_result(commit_sha=worker.commit_sha)
        outcomes = [
            OpenCodeRunResult(
                status=OpenCodeRunStatus.NON_ZERO_EXIT,
                argv=("fake-reviewer",),
                cwd=str(self.repository),
                stdout="",
                stderr="failed",
                exit_code=3,
                timed_out=False,
                error="reviewer failed",
            ),
            self._successful_execution(expected),
        ]
        runner = ReviewRunner(lambda _prompt: outcomes.pop(0))
        boundary = self._boundary(runner)

        failed = self._run_boundary(boundary)
        self.assertIsInstance(failed, ReviewPhaseResult)
        assert isinstance(failed, ReviewPhaseResult)
        self.assertFalse(failed.valid)
        self.assertIsNone(
            self.store.load_gota_review_result(
                self.run.run_id, 1, expected.request_id
            )
        )
        self.assertEqual(self.store.get_run(self.run.run_id).state, TaskState.REVIEW)
        self.assertEqual(
            sum(item.kind == "gota_reviewer_invocation_started" for item in self.store.list_evidence(self.run.run_id)),
            0,
        )

        recovered = self._run_boundary(boundary)
        self.assertTrue(getattr(recovered, "valid", False))
        self.assertEqual(len(runner.calls), 2)

    def test_invalid_sha_does_not_persist_and_can_retry(self) -> None:
        worker = self._durable_worker_and_review_frontier()
        expected = self._review_result(commit_sha=worker.commit_sha)
        invalid = self._review_result(commit_sha="b" * 40)
        outcomes = [
            self._successful_execution(invalid),
            self._successful_execution(expected),
        ]
        runner = ReviewRunner(lambda _prompt: outcomes.pop(0))
        boundary = self._boundary(runner)

        first = self._run_boundary(boundary)
        self.assertIsInstance(first, ReviewPhaseResult)
        assert isinstance(first, ReviewPhaseResult)
        self.assertFalse(first.valid)
        self.assertEqual(
            [item.kind for item in self.store.list_evidence(self.run.run_id)],
            [
                "gota_worker_request_registered",
                "gota_worker_invocation_started",
                "gota_worker_result_received",
                "gota_worker_commit_verified",
            ],
        )
        second = self._run_boundary(boundary)
        self.assertTrue(getattr(second, "valid", False))
        self.assertEqual(len(runner.calls), 2)

    def test_timeout_does_not_persist_and_can_retry(self) -> None:
        worker = self._durable_worker_and_review_frontier()
        expected = self._review_result(commit_sha=worker.commit_sha)
        outcomes = [
            OpenCodeRunResult(
                status=OpenCodeRunStatus.TIMEOUT,
                argv=("fake-reviewer",),
                cwd=str(self.repository),
                stdout="partial",
                stderr="",
                exit_code=None,
                timed_out=True,
                error="reviewer timeout",
            ),
            self._successful_execution(expected),
        ]
        runner = ReviewRunner(lambda _prompt: outcomes.pop(0))
        boundary = self._boundary(runner)

        failed = self._run_boundary(boundary)
        self.assertIsInstance(failed, ReviewPhaseResult)
        assert isinstance(failed, ReviewPhaseResult)
        self.assertFalse(failed.valid)
        self.assertIsNone(
            self.store.load_gota_review_result(
                self.run.run_id, 1, expected.request_id
            )
        )

        recovered = self._run_boundary(boundary)
        self.assertTrue(getattr(recovered, "valid", False))
        self.assertEqual(len(runner.calls), 2)

    def test_restart_loads_complete_result_and_skips_reviewer(self) -> None:
        worker = self._durable_worker_and_review_frontier()
        expected = self._review_result(commit_sha=worker.commit_sha)
        first_runner = ReviewRunner(lambda _prompt: self._successful_execution(expected))
        self.assertTrue(getattr(self._run_boundary(self._boundary(first_runner)), "valid", False))

        reopened = SQLiteCoordinatorStore(self.database)
        second_runner = ReviewRunner(
            lambda _prompt: self.fail("durable ReviewResult must skip Reviewer")
        )
        second_boundary = self._boundary(second_runner, store=reopened)
        loaded = self._run_boundary(second_boundary)

        self.assertEqual(loaded, expected)
        self.assertEqual(second_runner.calls, [])
        self.assertEqual(
            reopened.load_gota_review_result(
                self.run.run_id, 1, expected.request_id
            ),
            expected,
        )

    def test_git_change_during_reviewer_fails_closed(self) -> None:
        worker = self._durable_worker_and_review_frontier()
        expected = self._review_result(commit_sha=worker.commit_sha)

        def mutate_git(_prompt: str) -> OpenCodeRunResult:
            self._git("tag", "reviewer-mutated-ref")
            return self._successful_execution(expected)

        runner = ReviewRunner(mutate_git)
        outcome = self._run_boundary(self._boundary(runner))

        self.assertIsInstance(outcome, ReviewPhaseResult)
        assert isinstance(outcome, ReviewPhaseResult)
        self.assertFalse(outcome.valid)
        self.assertEqual(self.store.get_run(self.run.run_id).state, TaskState.REVIEW)
        self.assertIsNone(
            self.store.load_gota_review_result(
                self.run.run_id, 1, expected.request_id
            )
        )

    def test_lease_expiry_during_reviewer_rejects_persistence(self) -> None:
        worker = self._durable_worker_and_review_frontier()
        expected = self._review_result(commit_sha=worker.commit_sha)
        start = self.lease.acquired_at
        live = start + timedelta(seconds=0.1)
        expired = start + timedelta(seconds=61)
        clocked_store = SequencedClockStore(
            self.database,
            (live, live, expired),
        )
        runner = ReviewRunner(lambda _prompt: self._successful_execution(expected))
        with self.assertRaises(LeaseExpiredError):
            self._run_boundary(self._boundary(runner, store=clocked_store))
        self.assertEqual(clocked_store.get_run(self.run.run_id).state, TaskState.REVIEW)
        self.assertIsNone(
            clocked_store.load_gota_review_result(
                self.run.run_id, 1, expected.request_id
            )
        )

    def test_stale_fence_before_persist_rejects_result(self) -> None:
        worker = self._durable_worker_and_review_frontier()
        expected = self._review_result(commit_sha=worker.commit_sha)

        def stale_fence(_prompt: str) -> OpenCodeRunResult:
            with self.store.transaction(immediate=True) as connection:
                connection.execute(
                    "UPDATE global_lock SET stale = 1 WHERE lock_name = 'global'"
                )
            return self._successful_execution(expected)

        runner = ReviewRunner(stale_fence)
        with self.assertRaises(FencingTokenError):
            self._run_boundary(self._boundary(runner))
        self.assertEqual(self.store.get_run(self.run.run_id).state, TaskState.REVIEW)
        self.assertEqual(
            sum(item.kind == "gota_review_result" for item in self.store.list_evidence(self.run.run_id)),
            0,
        )

    def test_store_round_trip_idempotence_and_conflict(self) -> None:
        worker = self._durable_worker_and_review_frontier()
        expected = self._review_result(commit_sha=worker.commit_sha)
        evidence = self.store.persist_gota_review_result(
            self.run.run_id, expected, self.lease
        )
        same = self.store.persist_gota_review_result(
            self.run.run_id, expected, self.lease
        )
        self.assertEqual(same, evidence)

        reopened = SQLiteCoordinatorStore(self.database)
        self.assertEqual(
            reopened.load_gota_review_result(
                self.run.run_id, 1, expected.request_id
            ),
            expected,
        )
        with self.assertRaises(GotaReviewResultError):
            reopened.persist_gota_review_result(
                self.run.run_id,
                replace(expected, decision=ReviewDecision.CORRECTION_REQUIRED),
                self.lease,
            )
        self.assertEqual(
            reopened.load_gota_review_result(
                self.run.run_id, 1, expected.request_id
            ),
            expected,
        )
        self.assertEqual(
            sum(item.kind == "gota_review_result" for item in reopened.list_evidence(self.run.run_id)),
            1,
        )
        with reopened._connect() as connection:
            self.assertEqual(
                connection.execute(
                    "SELECT COUNT(*) FROM gota_review_results WHERE run_id = ?",
                    (self.run.run_id,),
                ).fetchone()[0],
                1,
            )

    def test_public_append_cannot_fabricate_review_result(self) -> None:
        self._durable_worker_and_review_frontier()
        with self.assertRaises(AcceptanceEvidenceError):
            self.store.append_evidence(
                self.run.run_id,
                "gota_review_result",
                {"arbitrary": True},
                self.lease,
            )

    def test_evidence_payload_tampering_fails_closed(self) -> None:
        worker = self._durable_worker_and_review_frontier()
        expected = self._review_result(commit_sha=worker.commit_sha)
        self.store.persist_gota_review_result(self.run.run_id, expected, self.lease)
        evidence = self.store.list_evidence(self.run.run_id)[-1]
        payload = dict(evidence.payload)
        payload["decision"] = ReviewDecision.CORRECTION_REQUIRED.value
        self._tamper_evidence(evidence.evidence_id, payload=payload)
        with self.assertRaises(GotaReviewResultError):
            self.store.load_gota_review_result(
                self.run.run_id, 1, expected.request_id
            )

    def test_recalculated_digest_and_field_tampering_fail_by_anchor(self) -> None:
        fields = {
            "decision": ReviewDecision.CORRECTION_REQUIRED.value,
            "reviewed_commit_sha": "b" * 40,
            "findings": [],
            "evidence": [{"kind": "tampered"}],
            "attempt": 2,
            "request_id": f"{self.run.run_id}:2:review",
        }
        for field, value in fields.items():
            with self.subTest(field=field):
                self.setUp()
                worker = self._durable_worker_and_review_frontier()
                expected = self._review_result(commit_sha=worker.commit_sha)
                self.store.persist_gota_review_result(
                    self.run.run_id, expected, self.lease
                )
                evidence = self.store.list_evidence(self.run.run_id)[-1]
                payload = dict(evidence.payload)
                payload[field] = value
                self._tamper_evidence(
                    evidence.evidence_id,
                    payload=payload,
                    digest=_digest(payload),
                )
                with self.assertRaises(GotaReviewResultError):
                    self.store.load_gota_review_result(
                        self.run.run_id, 1, expected.request_id
                    )
                self.doCleanups()

    def test_anchor_id_digest_worker_link_and_timestamp_tampering_fail_closed(self) -> None:
        worker = self._durable_worker_and_review_frontier()
        expected = self._review_result(commit_sha=worker.commit_sha)
        self.store.persist_gota_review_result(self.run.run_id, expected, self.lease)
        evidence = self.store.list_evidence(self.run.run_id)[-1]
        commit = self.store.load_gota_worker_commit_verified(
            self.run.run_id, 1, self.request.request_id
        )
        assert commit is not None

        tamper_cases = (
            ("review_evidence_id", "missing-review-evidence"),
            ("review_evidence_digest", "0" * 64),
            ("worker_commit_evidence_id", "missing-worker-evidence"),
            ("created_at", isoformat(evidence.created_at + timedelta(seconds=1))),
        )
        for field, value in tamper_cases:
            with self.subTest(field=field):
                self._tamper_anchor(field, value)
                with self.assertRaises(GotaReviewResultError):
                    self.store.load_gota_review_result(
                        self.run.run_id, 1, expected.request_id
                    )
                with self.store.transaction(immediate=True) as connection:
                    connection.execute(
                        "DROP TRIGGER immutable_gota_review_results_update"
                    )
                    connection.execute(
                        f"UPDATE gota_review_results SET {field} = ? WHERE run_id = ?",
                        (
                            {
                                "review_evidence_id": evidence.evidence_id,
                                "review_evidence_digest": evidence.digest,
                                "worker_commit_evidence_id": commit.evidence_id,
                                "created_at": isoformat(evidence.created_at),
                            }[field],
                            self.run.run_id,
                        ),
                    )

    def test_payload_recalculated_digest_cannot_bypass_anchor(self) -> None:
        worker = self._durable_worker_and_review_frontier()
        expected = self._review_result(commit_sha=worker.commit_sha)
        self.store.persist_gota_review_result(self.run.run_id, expected, self.lease)
        evidence = self.store.list_evidence(self.run.run_id)[-1]
        payload = dict(evidence.payload)
        payload["evidence"] = [{"kind": "tampered", "value": 1}]
        self._tamper_evidence(
            evidence.evidence_id,
            payload=payload,
            digest=_digest(payload),
        )
        with self.assertRaises(GotaReviewResultError):
            self.store.load_gota_review_result(
                self.run.run_id, 1, expected.request_id
            )

    def test_duplicate_review_authorities_and_partial_anchor_fail_closed(self) -> None:
        worker = self._durable_worker_and_review_frontier()
        expected = self._review_result(commit_sha=worker.commit_sha)
        self.store.persist_gota_review_result(self.run.run_id, expected, self.lease)
        evidence = self.store.list_evidence(self.run.run_id)[-1]

        with self.store.transaction(immediate=True) as connection:
            self.store._insert_evidence(
                connection,
                self.run.run_id,
                "gota_review_result",
                evidence.payload,
                self.lease,
                self.store._trusted_now(),
            )
        with self.assertRaises(GotaReviewResultError):
            self.store.load_gota_review_result(
                self.run.run_id, 1, expected.request_id
            )

        # The duplicate is removed only inside this adversarial fixture; the
        # immutable production path never exposes deletion.
        with self.store.transaction(immediate=True) as connection:
            connection.execute("DROP TRIGGER immutable_evidence_delete")
            connection.execute(
                "DELETE FROM evidence WHERE rowid = (SELECT MAX(rowid) FROM evidence WHERE run_id = ? AND kind = ?)",
                (self.run.run_id, "gota_review_result"),
            )
        self._tamper_anchor("review_evidence_id", "missing-review-evidence")
        with self.assertRaises(GotaReviewResultError):
            self.store.load_gota_review_result(
                self.run.run_id, 1, expected.request_id
            )


if __name__ == "__main__":
    unittest.main()
