"""Durable boundary between one validated Worker phase and later work.

If Worker creates a commit and exits before producing a valid WorkerResult or
before this boundary persists it, the store contains no recovery authority.
This module deliberately does not inspect Git to reconstruct that result or
rerun Worker; a later recovery layer must classify the condition as
human-review/fail-closed.
"""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
from typing import Any, Mapping

from .domain import Evidence, Lease, TaskRun, TaskState
from .git_adapter import GitReadError, GitSnapshot, ReadOnlyGitAdapter
from .gota_phases import (
    GotaCycleRunner,
    WorkerPhase,
    WorkerPhaseResult,
    verify_worker_commit_git,
)
from .gota_protocol import GotaRequest, GotaWorkerResult, WorkerResultStatus
from .store import (
    GotaWorkerResultError,
    GotaWorkerReservationError,
    GotaWorkerReviewBoundaryError,
    GotaWorkerReviewPersistence,
    SQLiteCoordinatorStore,
)


class GotaWorkerRecoveryRequiredError(GotaWorkerReservationError):
    """A reserved attempt has no durable result and cannot be retried."""


@dataclass(frozen=True, slots=True)
class GotaWorkerReviewBoundaryResult:
    """Observable result of the durable Worker-to-Review frontier."""

    run: TaskRun
    commit_evidence: Evidence
    created: bool

    @property
    def already_completed(self) -> bool:
        return not self.created

    @property
    def state(self) -> TaskState:
        return self.run.state

    @property
    def commit_sha(self) -> str:
        return str(self.commit_evidence.payload["commit_sha"])


class GotaWorkerReviewBoundary:
    """Revalidate durable Worker authority and enter REVIEW without Worker."""

    def __init__(
        self,
        repository: str | Path,
        *,
        store: SQLiteCoordinatorStore,
        git: ReadOnlyGitAdapter | None = None,
    ) -> None:
        self.repository = Path(repository).resolve()
        self.store = store
        self.git = git if git is not None else ReadOnlyGitAdapter(self.repository)

    @staticmethod
    def _authority_error(message: str) -> GotaWorkerReviewBoundaryError:
        return GotaWorkerReviewBoundaryError(message)

    def _load_authority(
        self,
        run_id: str,
        attempt: int,
        request_id: str,
    ) -> tuple[TaskRun, GotaRequest, GotaWorkerResult]:
        run = self.store.get_run(run_id)
        try:
            reservation = self.store.load_gota_worker_invocation(
                run_id, attempt, request_id
            )
            request = self.store.load_gota_worker_request(
                run_id, attempt, request_id
            )
            result = self.store.load_gota_worker_result(
                run_id, attempt, request_id
            )
        except GotaWorkerReservationError as error:
            raise self._authority_error(str(error)) from error
        if reservation is None or request is None:
            raise self._authority_error(
                "Durable Worker request and invocation reservation are required"
            )
        if request != reservation.request:
            raise self._authority_error(
                "Durable Worker request authorities disagree"
            )
        if result is None:
            raise self._authority_error("A durable WorkerResult is required")
        if (
            request.run_id != run_id
            or request.task_id != run.task_id
            or request.attempt != attempt
            or request.request_id != request_id
            or result.run_id != run_id
            or result.task_id != run.task_id
            or result.attempt != attempt
            or result.request_id != request_id
            or result.result is not WorkerResultStatus.READY_FOR_REVIEW
        ):
            raise self._authority_error(
                "Durable Worker request and result identities are incoherent"
            )
        if Path(request.workspace).resolve() != self.repository:
            raise self._authority_error(
                "Durable Worker request workspace does not match the boundary repository"
            )
        return run, request, result

    @staticmethod
    def _observation(
        request: GotaRequest,
        result: GotaWorkerResult,
        verification: object,
    ) -> dict[str, Any]:
        if not hasattr(verification, "valid") or not verification.valid:
            failure = getattr(verification, "failure", None)
            diagnostic = getattr(verification, "diagnostic", "Git verification failed")
            raise GotaWorkerReviewBoundaryError(
                f"Independent Git verification failed: {failure}: {diagnostic}"
            )
        snapshot = getattr(verification, "snapshot", None)
        changed_paths = getattr(verification, "changed_paths", None)
        if type(snapshot) is not GitSnapshot or type(changed_paths) is not tuple:
            raise GotaWorkerReviewBoundaryError(
                "Independent Git verification returned a non-canonical result"
            )
        return {
            "base_sha": request.base_sha,
            "commit_sha": result.commit_sha,
            "changed_paths": tuple(changed_paths),
            "branch": request.branch,
            "head": snapshot.head,
            "status": snapshot.status,
            "refs": snapshot.refs,
        }

    def _verify(
        self,
        request: GotaRequest,
        result: GotaWorkerResult,
        expected_snapshot: GitSnapshot,
    ) -> dict[str, Any]:
        if expected_snapshot.branch != request.branch:
            raise GotaWorkerReviewBoundaryError(
                "Independent Git verification observed an unexpected branch"
            )
        try:
            verification = verify_worker_commit_git(
                self.git,
                base_sha=request.base_sha,
                expected_branch=request.branch,
                verified_commit_sha=result.commit_sha,
                worker_changed_paths=result.changed_paths,
                expected_snapshot=expected_snapshot,
            )
        except Exception as error:
            raise GotaWorkerReviewBoundaryError(
                f"Independent Git verification failed: {error}"
            ) from error
        return self._observation(request, result, verification)

    @staticmethod
    def _review_already_completed_verifier(
        _request: GotaRequest,
        _result: GotaWorkerResult,
    ) -> Mapping[str, Any]:
        raise GotaWorkerReviewBoundaryError(
            "An intact REVIEW frontier must not perform a new Git verification"
        )

    def run(
        self,
        run_id: str,
        lease: Lease,
        *,
        attempt: int,
        request_id: str,
    ) -> GotaWorkerReviewBoundaryResult:
        """Revalidate durable authority and atomically enter REVIEW."""

        run, request, result = self._load_authority(run_id, attempt, request_id)
        existing = self.store.load_gota_worker_commit_verified(
            run_id, attempt, request_id
        )
        if run.state is TaskState.REVIEW:
            if existing is None or existing.payload["commit_sha"] != result.commit_sha:
                raise self._authority_error(
                    "REVIEW requires one coherent Worker commit verification"
                )
            persistence = self.store._persist_gota_worker_commit_verified_and_review(
                run_id,
                attempt,
                request_id,
                lease,
                verify=self._review_already_completed_verifier,
            )
            return self._result(persistence)
        if run.state is not TaskState.RUNNING:
            raise self._authority_error(
                "Worker review entry is allowed only from RUNNING or an intact REVIEW frontier"
            )
        if existing is not None:
            raise self._authority_error(
                "RUNNING already contains a Worker commit verification"
            )

        try:
            expected_snapshot = self.git.snapshot()
        except GitReadError as error:
            raise GotaWorkerReviewBoundaryError(
                f"Independent Git snapshot inspection failed: {error}"
            ) from error
        self._verify(request, result, expected_snapshot)

        def verify_final(
            durable_request: GotaRequest,
            durable_result: GotaWorkerResult,
        ) -> Mapping[str, Any]:
            return self._verify(durable_request, durable_result, expected_snapshot)

        persistence = self.store._persist_gota_worker_commit_verified_and_review(
            run_id,
            attempt,
            request_id,
            lease,
            verify=verify_final,
        )
        return self._result(persistence)

    @staticmethod
    def _result(
        persistence: GotaWorkerReviewPersistence,
    ) -> GotaWorkerReviewBoundaryResult:
        return GotaWorkerReviewBoundaryResult(
            run=persistence.run,
            commit_evidence=persistence.commit_evidence,
            created=persistence.created,
        )


class GotaWorkerPersistenceBoundary:
    """Run WorkerPhase and persist its result before returning success."""

    def __init__(
        self,
        repository: str | Path,
        *,
        runner: GotaCycleRunner,
        store: SQLiteCoordinatorStore,
    ) -> None:
        self.worker_phase = WorkerPhase(repository, runner=runner)
        self.store = store

    def run(
        self,
        request: GotaRequest,
        lease: Lease,
        *,
        timeout: float,
    ) -> WorkerPhaseResult | GotaWorkerResult:
        """Reserve once, then run Worker or reuse its durable result."""

        reservation = self.store.reserve_gota_worker_invocation(
            request.run_id,
            request,
            lease,
        )
        if not reservation.created:
            worker_result = self.store.load_gota_worker_result(
                request.run_id,
                request.attempt,
                request.request_id,
            )
            if worker_result is None:
                raise GotaWorkerRecoveryRequiredError(
                    "Worker invocation is durably reserved but has no WorkerResult; "
                    "automatic retry is forbidden and human recovery is required"
                )
            return worker_result

        phase_result = self.worker_phase.run(request, timeout=timeout)
        if not phase_result.valid:
            return phase_result
        worker_result = phase_result.worker_payload
        if type(worker_result) is not GotaWorkerResult:
            raise GotaWorkerResultError(
                "A successful WorkerPhase result has no canonical WorkerResult"
            )
        self.store.persist_gota_worker_result(
            request.run_id,
            worker_result,
            lease,
        )
        return phase_result


__all__ = [
    "GotaWorkerReviewBoundary",
    "GotaWorkerReviewBoundaryResult",
    "GotaWorkerPersistenceBoundary",
    "GotaWorkerRecoveryRequiredError",
]
