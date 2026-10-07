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
    GotaWorkerPersistenceBoundary,
    GotaWorkerRecoveryRequiredError,
    GotaWorkerReservationError,
    GotaWorkerResult,
    OpenCodeRunResult,
    OpenCodeRunStatus,
    WorkerResultStatus,
)
from flow_coordinator.domain import TaskSpec, utc_now
from flow_coordinator.service import CoordinatorService
from flow_coordinator.store import (
    AcceptanceEvidenceError,
    FencingTokenError,
    GotaWorkerResultError,
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


class SneakyKind(str):
    def __hash__(self) -> int:
        return hash("not-reserved")


class AdversarialKind(str):
    def __hash__(self) -> int:
        return hash("not-reserved")

    def __eq__(self, other: object) -> bool:
        return True


class StringLikeKind:
    def __str__(self) -> str:
        return "gota_worker_result_received"


class PersistenceRunner:
    def __init__(self, step: Callable[[str, str], OpenCodeRunResult]) -> None:
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
            {"agent": agent, "prompt": prompt, "cwd": Path(cwd), "timeout": timeout}
        )
        return self.step(agent, prompt)


class GotaPersistenceStoreTest(CoordinatorTestCase):
    @staticmethod
    def _worker_result(
        run_id: str,
        task_id: str,
        *,
        attempt: int = 1,
        commit_sha: str = "a" * 40,
        changed_paths: tuple[str, ...] = ("src/change.py",),
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
            changed_paths=changed_paths,
            evidence=(
                {"kind": "worker", "passed": True, "details": {"count": 2}},
                {"kind": "checkpoint", "label": "implementation"},
            ),
            checkpoint=GotaCheckpoint(
                completed_steps=("inspect", "implementation"),
                remaining_phase="review",
            ),
        )

    def _started_run(self, task_id: str) -> tuple[object, object, GotaWorkerResult]:
        _, run = self.create_task(task_id)
        lease = self.service.start(run.run_id, owner_id="worker")
        return run, lease, self._worker_result(run.run_id, run.task_id)

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

    def test_valid_result_round_trips_all_authoritative_fields(self) -> None:
        run, lease, result = self._started_run("round-trip")

        evidence = self.store.persist_gota_worker_result(run.run_id, result, lease)
        reopened = SQLiteCoordinatorStore(self.database)
        loaded = reopened.load_gota_worker_result(
            run.run_id, result.attempt, result.request_id
        )

        self.assertEqual(loaded, result)
        self.assertIsNotNone(loaded)
        self.assertEqual(loaded.phase, GotaPhase.WORKER)
        self.assertEqual(evidence.kind, "gota_worker_result_received")
        self.assertEqual(evidence.payload, result.to_payload())
        self.assertEqual(evidence.digest, _digest(result.to_payload()))
        self.assertTrue(evidence.evidence_id)
        self.assertEqual(reopened.list_evidence(run.run_id), (evidence,))

    def test_persistence_uses_store_clock_and_reserves_worker_evidence(self) -> None:
        run, lease, result = self._started_run("store-clock")
        trusted_now = lease.acquired_at + timedelta(seconds=1)
        trusted_store = FixedClockStore(self.database, trusted_now)

        evidence = trusted_store.persist_gota_worker_result(
            run.run_id, result, lease
        )

        self.assertEqual(evidence.created_at, trusted_now)
        with self.assertRaises(AcceptanceEvidenceError):
            self.store.append_evidence(
                run.run_id,
                "gota_worker_result_received",
                result.to_payload(),
                lease,
            )

    def test_append_evidence_rejects_exact_reserved_worker_kind(self) -> None:
        run, lease, result = self._started_run("reserved-worker")

        with self.assertRaises(AcceptanceEvidenceError):
            self.store.append_evidence(
                run.run_id,
                "gota_worker_result_received",
                result.to_payload(),
                lease,
            )

        self.assertEqual(self.store.list_evidence(run.run_id), ())
        self.assertIsNone(
            self.store.load_gota_worker_result(
                run.run_id, result.attempt, result.request_id
            )
        )

    def test_append_evidence_rejects_adversarial_and_noncanonical_kinds(self) -> None:
        run, lease, result = self._started_run("noncanonical-kinds")

        for kind in (
            SneakyKind("gota_worker_result_received"),
            AdversarialKind("gota_acceptance_verified"),
            StringLikeKind(),
        ):
            with self.subTest(kind=type(kind).__name__):
                with self.assertRaises(AcceptanceEvidenceError):
                    self.store.append_evidence(
                        run.run_id,
                        kind,  # type: ignore[arg-type]
                        result.to_payload(),
                        lease,
                    )

        self.assertEqual(self.store.list_evidence(run.run_id), ())
        self.assertIsNone(
            self.store.load_gota_worker_result(
                run.run_id, result.attempt, result.request_id
            )
        )

    def test_append_evidence_accepts_canonical_non_reserved_kind(self) -> None:
        run, lease, _result = self._started_run("normal-evidence")

        evidence = self.store.append_evidence(
            run.run_id,
            "legacy_note",
            {"source": "caller"},
            lease,
        )

        self.assertEqual(evidence.kind, "legacy_note")
        self.assertEqual(self.store.list_evidence(run.run_id), (evidence,))

    def test_append_evidence_rejects_expired_lease_with_backdated_now(self) -> None:
        start = datetime(2026, 1, 1, tzinfo=UTC)
        _, run = self.create_task("expired-append-clock")
        lease = self.service.start(
            run.run_id, owner_id="worker", lease_seconds=60, now=start
        )
        trusted_store = FixedClockStore(
            self.database, start + timedelta(seconds=61)
        )

        with self.assertRaises(LeaseExpiredError):
            trusted_store.append_evidence(
                run.run_id,
                "legacy_note",
                {"source": "caller"},
                lease,
                now=start,
            )

        self.assertEqual(self.store.list_evidence(run.run_id), ())

    def test_append_evidence_uses_trusted_clock_for_live_lease_and_timestamp(self) -> None:
        start = datetime(2026, 1, 1, tzinfo=UTC)
        _, run = self.create_task("live-append-clock")
        lease = self.service.start(
            run.run_id, owner_id="worker", lease_seconds=60, now=start
        )
        trusted_now = start + timedelta(seconds=10)
        trusted_store = FixedClockStore(self.database, trusted_now)

        evidence = trusted_store.append_evidence(
            run.run_id,
            "legacy_note",
            {"source": "caller"},
            lease,
            now=start,
        )

        self.assertEqual(evidence.created_at, trusted_now)
        self.assertEqual(trusted_store.list_evidence(run.run_id), (evidence,))

    def test_idempotent_duplicate_does_not_create_second_authority(self) -> None:
        run, lease, result = self._started_run("idempotent")

        first = self.store.persist_gota_worker_result(run.run_id, result, lease)
        second = self.store.persist_gota_worker_result(run.run_id, result, lease)

        self.assertEqual(second, first)
        self.assertEqual(
            [item.kind for item in self.store.list_evidence(run.run_id)],
            ["gota_worker_result_received"],
        )

    def test_conflicting_result_fails_closed_without_overwrite(self) -> None:
        run, lease, result = self._started_run("conflict")
        self.store.persist_gota_worker_result(run.run_id, result, lease)
        conflicting = replace(result, commit_sha="b" * 40)

        with self.assertRaises(GotaWorkerResultError):
            self.store.persist_gota_worker_result(run.run_id, conflicting, lease)

        loaded = self.store.load_gota_worker_result(
            run.run_id, result.attempt, result.request_id
        )
        self.assertEqual(loaded, result)
        self.assertEqual(len(self.store.list_evidence(run.run_id)), 1)

    def test_digest_tampering_is_rejected(self) -> None:
        run, lease, result = self._started_run("digest-tamper")
        evidence = self.store.persist_gota_worker_result(run.run_id, result, lease)
        self._rewrite_evidence(evidence.evidence_id, result.to_payload(), "0" * 64)

        with self.assertRaises(GotaWorkerResultError):
            self.store.load_gota_worker_result(
                run.run_id, result.attempt, result.request_id
            )

    def test_invalid_payload_tampering_is_rejected(self) -> None:
        run, lease, result = self._started_run("payload-tamper")
        evidence = self.store.persist_gota_worker_result(run.run_id, result, lease)
        invalid_payload = {"protocol": GOTA_PROTOCOL, "message": "worker.result"}
        self._rewrite_evidence(
            evidence.evidence_id,
            invalid_payload,
            _digest(invalid_payload),
        )

        with self.assertRaises(GotaWorkerResultError):
            self.store.load_gota_worker_result(
                run.run_id, result.attempt, result.request_id
            )

    def test_incoherent_identity_tampering_is_rejected(self) -> None:
        run, lease, result = self._started_run("identity-tamper")
        evidence = self.store.persist_gota_worker_result(run.run_id, result, lease)
        incoherent = replace(result, task_id="another-task").to_payload()
        self._rewrite_evidence(evidence.evidence_id, incoherent, _digest(incoherent))

        with self.assertRaises(GotaWorkerResultError):
            self.store.load_gota_worker_result(
                run.run_id, result.attempt, result.request_id
            )

    def test_duplicate_ledger_rows_fail_closed_on_load(self) -> None:
        run, lease, result = self._started_run("duplicate-ledger")
        self.store.persist_gota_worker_result(run.run_id, result, lease)
        with self.store.transaction(immediate=True) as connection:
            self.store._insert_evidence(
                connection,
                run.run_id,
                "gota_worker_result_received",
                result.to_payload(),
                lease,
                utc_now(),
            )

        with self.assertRaises(GotaWorkerResultError):
            self.store.load_gota_worker_result(
                run.run_id, result.attempt, result.request_id
            )

    def test_wrong_run_or_task_result_is_not_accepted(self) -> None:
        run, lease, result = self._started_run("identity-reject")
        wrong_run = replace(
            result,
            run_id="different-run",
            request_id="different-run:1:worker",
        )
        wrong_task = replace(result, task_id="different-task")

        with self.assertRaises(GotaWorkerResultError):
            self.store.persist_gota_worker_result(run.run_id, wrong_run, lease)
        with self.assertRaises(GotaWorkerResultError):
            self.store.persist_gota_worker_result(run.run_id, wrong_task, lease)
        self.assertIsNone(
            self.store.load_gota_worker_result(
                run.run_id, result.attempt, result.request_id
            )
        )

    def test_other_attempt_is_not_returned_as_requested_authority(self) -> None:
        run, lease, result = self._started_run("attempt-reject")
        other_attempt = replace(result, attempt=2, request_id=f"{run.run_id}:2:worker")
        self.store.persist_gota_worker_result(run.run_id, other_attempt, lease)

        self.assertIsNone(
            self.store.load_gota_worker_result(
                run.run_id, result.attempt, result.request_id
            )
        )
        self.assertEqual(
            self.store.load_gota_worker_result(
                run.run_id, other_attempt.attempt, other_attempt.request_id
            ),
            other_attempt,
        )

    def test_invalid_result_is_not_persisted(self) -> None:
        run, lease, result = self._started_run("invalid-result")
        object.__setattr__(result, "commit_sha", "not-a-sha")

        with self.assertRaises(GotaWorkerResultError):
            self.store.persist_gota_worker_result(run.run_id, result, lease)
        self.assertEqual(self.store.list_evidence(run.run_id), ())

    def test_restart_and_missing_result_do_not_read_or_fabricate_from_git(self) -> None:
        run, _lease, result = self._started_run("git-is-not-authority")
        repository = self.root / "git-repository"
        repository.mkdir()
        subprocess.run(
            ("git", "init", "--initial-branch=feature/no-result"),
            cwd=repository,
            check=True,
            capture_output=True,
            text=True,
        )
        subprocess.run(
            ("git", "config", "user.name", "Persistence Test"),
            cwd=repository,
            check=True,
        )
        subprocess.run(
            ("git", "config", "user.email", "persistence@example.invalid"),
            cwd=repository,
            check=True,
        )
        (repository / "commit.txt").write_text("commit exists\n", encoding="utf-8")
        subprocess.run(("git", "add", "commit.txt"), cwd=repository, check=True)
        subprocess.run(
            ("git", "commit", "-m", "commit without WorkerResult"),
            cwd=repository,
            check=True,
            capture_output=True,
            text=True,
        )

        reopened = SQLiteCoordinatorStore(self.database)
        self.assertIsNone(
            reopened.load_gota_worker_result(
                run.run_id, result.attempt, result.request_id
            )
        )
        self.assertEqual(reopened.list_evidence(run.run_id), ())

    def test_stale_and_expired_leases_reject_persistence(self) -> None:
        run, lease, result = self._started_run("fencing")
        stale = replace(lease, fencing_token=lease.fencing_token - 1)

        with self.assertRaises(FencingTokenError):
            self.store.persist_gota_worker_result(run.run_id, result, stale)
        self.assertEqual(self.store.list_evidence(run.run_id), ())

        with self.store.transaction(immediate=True) as connection:
            connection.execute(
                "UPDATE global_lock SET lease_expires_at = ? WHERE lock_name = 'global'",
                ((datetime.now(UTC) - timedelta(seconds=1)).isoformat(),),
            )
        with self.assertRaises(LeaseExpiredError):
            self.store.persist_gota_worker_result(run.run_id, result, lease)
        self.assertEqual(self.store.list_evidence(run.run_id), ())


class GotaWorkerBoundaryTest(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary_directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary_directory.cleanup)
        self.root = Path(self.temporary_directory.name)
        self.repository = self.root / "repository"
        self.repository.mkdir()
        self._git("init", "--initial-branch=feature/gota-persistence")
        self._git("config", "user.name", "Gota Persistence Test")
        self._git("config", "user.email", "gota-persistence@example.invalid")
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
            task_id="persistence-task",
            title="Persistence task",
            objective="Persist the WorkerResult before review",
            project_id="persistence-project",
            repository_id="persistence-repository",
            branch="feature/gota-persistence",
            base_sha=self.base_sha,
            context_id="persistence-context",
            allowed_paths=("src/change.py",),
            protected_paths=("demo/main.tscn", "export_presets.cfg"),
            required_resources=(),
            acceptance_criteria=("WorkerResult is durable",),
            commit_message="test: durable WorkerResult",
        )
        self.run = self.service.create_task(spec, {"workspace": str(self.repository)})
        self.lease = self.service.start(self.run.run_id, owner_id="worker")
        self.request = GotaRequest(
            protocol=GOTA_PROTOCOL,
            request_id=f"{self.run.run_id}:1:worker",
            task_id=spec.task_id,
            run_id=self.run.run_id,
            attempt=1,
            phase="worker",
            objective=spec.objective,
            acceptance_criteria=spec.acceptance_criteria,
            workspace=str(self.repository),
            branch=spec.branch,
            base_sha=spec.base_sha,
            allowed_paths=spec.allowed_paths,
            protected_paths=spec.protected_paths,
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

    def _git(self, *arguments: str) -> str:
        result = subprocess.run(
            ("git", *arguments),
            cwd=self.repository,
            check=True,
            capture_output=True,
            text=True,
        )
        return result.stdout.rstrip("\n")

    def _valid_worker_step(self, _agent: str, _prompt: str) -> OpenCodeRunResult:
        (self.repository / "src/change.py").write_text(
            "value = 'worker'\n", encoding="utf-8"
        )
        self._git("add", "--", "src/change.py")
        self._git("commit", "-m", "worker result")
        payload = GotaPersistenceStoreTest._worker_result(
            self.run.run_id,
            self.run.task_id,
            commit_sha=self._git("rev-parse", "HEAD"),
        )
        return OpenCodeRunResult(
            status=OpenCodeRunStatus.SUCCEEDED,
            argv=("fake-opencode",),
            cwd=str(self.repository),
            stdout="",
            stderr="",
            exit_code=0,
            timed_out=False,
            payload=payload,
        )

    def test_boundary_persists_before_returning_valid_worker_phase(self) -> None:
        runner = PersistenceRunner(self._valid_worker_step)
        boundary = GotaWorkerPersistenceBoundary(
            self.repository,
            runner=runner,
            store=self.store,
        )

        phase_result = boundary.run(self.request, self.lease, timeout=3)

        self.assertTrue(phase_result.valid)
        self.assertEqual(len(runner.calls), 1)
        self.assertIsNotNone(
            self.store.load_gota_worker_result(
                self.run.run_id, self.request.attempt, self.request.request_id
            )
        )

    def test_invalid_worker_after_commit_has_no_durable_result_or_retry(self) -> None:
        def invalid_step(_agent: str, _prompt: str) -> OpenCodeRunResult:
            (self.repository / "src/change.py").write_text(
                "value = 'committed without result'\n", encoding="utf-8"
            )
            self._git("add", "--", "src/change.py")
            self._git("commit", "-m", "commit without result")
            return OpenCodeRunResult(
                status=OpenCodeRunStatus.INVALID_PAYLOAD,
                argv=("fake-opencode",),
                cwd=str(self.repository),
                stdout="",
                stderr="invalid payload",
                exit_code=0,
                timed_out=False,
                error="missing WorkerResult",
            )

        runner = PersistenceRunner(invalid_step)
        boundary = GotaWorkerPersistenceBoundary(
            self.repository,
            runner=runner,
            store=self.store,
        )

        phase_result = boundary.run(self.request, self.lease, timeout=3)

        self.assertFalse(phase_result.valid)
        self.assertEqual(len(runner.calls), 1)
        self.assertIsNone(
            self.store.load_gota_worker_result(
                self.run.run_id, self.request.attempt, self.request.request_id
            )
        )
        self.assertNotEqual(self._git("rev-parse", "HEAD"), self.base_sha)

    def test_timeout_worker_has_no_durable_result(self) -> None:
        runner = PersistenceRunner(
            lambda _agent, _prompt: OpenCodeRunResult(
                status=OpenCodeRunStatus.TIMEOUT,
                argv=("fake-opencode",),
                cwd=str(self.repository),
                stdout="partial",
                stderr="timeout",
                exit_code=1,
                timed_out=True,
                error="timed out",
            )
        )
        boundary = GotaWorkerPersistenceBoundary(
            self.repository,
            runner=runner,
            store=self.store,
        )

        phase_result = boundary.run(self.request, self.lease, timeout=3)

        self.assertFalse(phase_result.valid)
        self.assertEqual(len(runner.calls), 1)
        self.assertIsNone(
            self.store.load_gota_worker_result(
                self.run.run_id, self.request.attempt, self.request.request_id
            )
        )

    def test_reservation_round_trips_complete_request_and_both_authorities(self) -> None:
        request = replace(
            self.request,
            objective="A non-trivial durable reservation objective",
            acceptance_criteria=("Preserve every request field", "Require review"),
            previous_findings=(
                GotaFinding(
                    id="finding-1",
                    severity="high",
                    description="Previous durable finding",
                    path="src/change.py",
                    required_change="Keep the full request",
                ),
            ),
        )

        reservation = self.store.reserve_gota_worker_invocation(
            self.run.run_id, request, self.lease
        )

        self.assertTrue(reservation.created)
        self.assertEqual(
            [item.kind for item in self.store.list_evidence(self.run.run_id)],
            [
                "gota_worker_request_registered",
                "gota_worker_invocation_started",
            ],
        )
        reopened = SQLiteCoordinatorStore(self.database)
        loaded = reopened.load_gota_worker_request(
            self.run.run_id, request.attempt, request.request_id
        )
        self.assertEqual(loaded, request)
        self.assertEqual(loaded.to_payload(), request.to_payload())
        loaded_reservation = reopened.load_gota_worker_invocation(
            self.run.run_id, request.attempt, request.request_id
        )
        self.assertIsNotNone(loaded_reservation)
        self.assertFalse(loaded_reservation.created)
        self.assertEqual(
            loaded_reservation.invocation_evidence.payload["request_digest"],
            reservation.request_evidence.digest,
        )

    def test_reservation_rolls_back_request_when_marker_insert_fails(self) -> None:
        with self.store.transaction(immediate=True) as connection:
            connection.execute(
                """
                CREATE TRIGGER reject_worker_invocation_marker
                BEFORE INSERT ON evidence
                WHEN NEW.kind = 'gota_worker_invocation_started'
                BEGIN
                    SELECT RAISE(ABORT, 'controlled reservation rollback');
                END
                """
            )
        try:
            with self.assertRaisesRegex(sqlite3.IntegrityError, "controlled reservation rollback"):
                self.store.reserve_gota_worker_invocation(
                    self.run.run_id, self.request, self.lease
                )
        finally:
            with self.store.transaction(immediate=True) as connection:
                connection.execute("DROP TRIGGER reject_worker_invocation_marker")

        self.assertEqual(self.store.list_evidence(self.run.run_id), ())
        self.assertIsNone(
            self.store.load_gota_worker_request(
                self.run.run_id, self.request.attempt, self.request.request_id
            )
        )

    def test_reservation_is_idempotent_and_conflicts_fail_closed(self) -> None:
        first = self.store.reserve_gota_worker_invocation(
            self.run.run_id, self.request, self.lease
        )
        second = self.store.reserve_gota_worker_invocation(
            self.run.run_id, self.request, self.lease
        )

        self.assertTrue(first.created)
        self.assertFalse(second.created)
        self.assertEqual(first.request, second.request)
        self.assertEqual(first.request_evidence, second.request_evidence)
        self.assertEqual(first.invocation_evidence, second.invocation_evidence)
        self.assertEqual(len(self.store.list_evidence(self.run.run_id)), 2)

        conflicting = replace(self.request, base_sha="b" * 40)
        with self.assertRaises(GotaWorkerReservationError):
            self.store.reserve_gota_worker_invocation(
                self.run.run_id, conflicting, self.lease
            )
        self.assertEqual(len(self.store.list_evidence(self.run.run_id)), 2)
        self.assertEqual(
            self.store.load_gota_worker_request(
                self.run.run_id, self.request.attempt, self.request.request_id
            ),
            self.request,
        )

    def test_reservation_integrity_rejects_tampering_and_duplicates(self) -> None:
        reservation = self.store.reserve_gota_worker_invocation(
            self.run.run_id, self.request, self.lease
        )
        tampered = replace(self.request, base_sha="b" * 40).to_payload()
        self._rewrite_evidence(
            reservation.request_evidence.evidence_id,
            tampered,
            _digest(tampered),
        )
        with self.assertRaises(GotaWorkerReservationError):
            self.store.load_gota_worker_request(
                self.run.run_id, self.request.attempt, self.request.request_id
            )

        # A second malformed authority is also a closed failure, not a choice.
        with self.store.transaction(immediate=True) as connection:
            self.store._insert_evidence(
                connection,
                self.run.run_id,
                "gota_worker_request_registered",
                self.request.to_payload(),
                self.lease,
                utc_now(),
            )
        with self.assertRaises(GotaWorkerReservationError):
            self.store.load_gota_worker_request(
                self.run.run_id, self.request.attempt, self.request.request_id
            )

    def test_reserved_request_and_marker_kinds_reject_generic_append(self) -> None:
        for kind in (
            "gota_worker_request_registered",
            "gota_worker_invocation_started",
            SneakyKind("gota_worker_request_registered"),
            SneakyKind("gota_worker_invocation_started"),
            AdversarialKind("gota_worker_request_registered"),
            AdversarialKind("gota_worker_invocation_started"),
        ):
            with self.subTest(kind=type(kind).__name__):
                with self.assertRaisesRegex(AcceptanceEvidenceError, "reserved|canonical"):
                    self.store.append_evidence(
                        self.run.run_id,
                        kind,  # type: ignore[arg-type]
                        {"source": "caller"},
                        self.lease,
                    )
        self.assertEqual(self.store.list_evidence(self.run.run_id), ())

    def test_reservation_rejects_expired_lease_and_stale_fencing(self) -> None:
        stale = replace(self.lease, fencing_token=self.lease.fencing_token - 1)
        with self.assertRaises(FencingTokenError):
            self.store.reserve_gota_worker_invocation(
                self.run.run_id, self.request, stale
            )
        with self.store.transaction(immediate=True) as connection:
            connection.execute(
                "UPDATE global_lock SET lease_expires_at = ? WHERE lock_name = 'global'",
                ((datetime.now(UTC) - timedelta(seconds=1)).isoformat(),),
            )
        with self.assertRaises(LeaseExpiredError):
            self.store.reserve_gota_worker_invocation(
                self.run.run_id, self.request, self.lease
            )
        self.assertEqual(self.store.list_evidence(self.run.run_id), ())

    def test_reservation_uses_store_trusted_clock(self) -> None:
        trusted_now = self.lease.acquired_at + timedelta(seconds=1)
        trusted_store = FixedClockStore(self.database, trusted_now)

        reservation = trusted_store.reserve_gota_worker_invocation(
            self.run.run_id, self.request, self.lease
        )

        self.assertEqual(reservation.request_evidence.created_at, trusted_now)
        self.assertEqual(reservation.invocation_evidence.created_at, trusted_now)

    def test_boundary_reserves_before_worker_and_reuses_durable_result(self) -> None:
        observed_kinds: list[tuple[str, ...]] = []

        def valid_step(agent: str, prompt: str) -> OpenCodeRunResult:
            observed_kinds.append(
                tuple(item.kind for item in self.store.list_evidence(self.run.run_id))
            )
            return self._valid_worker_step(agent, prompt)

        runner = PersistenceRunner(valid_step)
        boundary = GotaWorkerPersistenceBoundary(
            self.repository,
            runner=runner,
            store=self.store,
        )
        first = boundary.run(self.request, self.lease, timeout=3)
        self.assertTrue(first.valid)
        self.assertEqual(
            observed_kinds,
            [
                (
                    "gota_worker_request_registered",
                    "gota_worker_invocation_started",
                )
            ],
        )

        reopened = SQLiteCoordinatorStore(self.database)
        second_runner = PersistenceRunner(
            lambda _agent, _prompt: (_ for _ in ()).throw(
                AssertionError("Worker must not be called again")
            )
        )
        second_boundary = GotaWorkerPersistenceBoundary(
            self.repository,
            runner=second_runner,
            store=reopened,
        )
        reused = second_boundary.run(self.request, self.lease, timeout=3)
        self.assertIsInstance(reused, GotaWorkerResult)
        self.assertEqual(
            reused,
            reopened.load_gota_worker_result(
                self.run.run_id, self.request.attempt, self.request.request_id
            ),
        )
        self.assertEqual(len(runner.calls), 1)
        self.assertEqual(len(second_runner.calls), 0)

    def test_boundary_fails_closed_when_reservation_has_no_result(self) -> None:
        self.store.reserve_gota_worker_invocation(
            self.run.run_id, self.request, self.lease
        )
        runner = PersistenceRunner(
            lambda _agent, _prompt: (_ for _ in ()).throw(
                AssertionError("reserved attempts cannot retry Worker")
            )
        )
        boundary = GotaWorkerPersistenceBoundary(
            self.repository,
            runner=runner,
            store=self.store,
        )

        with self.assertRaises(GotaWorkerRecoveryRequiredError):
            boundary.run(self.request, self.lease, timeout=3)
        self.assertEqual(len(runner.calls), 0)

    def _assert_worker_failure_cannot_retry(
        self,
        status: OpenCodeRunStatus,
        timed_out: bool,
    ) -> None:
        runner = PersistenceRunner(
            lambda _agent, _prompt: OpenCodeRunResult(
                status=status,
                argv=("fake-opencode",),
                cwd=str(self.repository),
                stdout="partial",
                stderr="failure",
                exit_code=1,
                timed_out=timed_out,
                error="worker failed",
            )
        )
        boundary = GotaWorkerPersistenceBoundary(
            self.repository,
            runner=runner,
            store=self.store,
        )
        first = boundary.run(self.request, self.lease, timeout=3)
        self.assertFalse(first.valid)
        with self.assertRaises(GotaWorkerRecoveryRequiredError):
            boundary.run(self.request, self.lease, timeout=3)
        self.assertEqual(len(runner.calls), 1)

    def test_worker_failure_cannot_retry_reserved_attempt(self) -> None:
        self._assert_worker_failure_cannot_retry(
            OpenCodeRunStatus.INVALID_PAYLOAD,
            False,
        )

    def test_worker_timeout_cannot_retry_reserved_attempt(self) -> None:
        self._assert_worker_failure_cannot_retry(
            OpenCodeRunStatus.TIMEOUT,
            True,
        )


if __name__ == "__main__":
    unittest.main()
