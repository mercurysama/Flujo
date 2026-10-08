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
    ReviewPhase,
    ReviewPhaseResult,
    VerifiedWorkerCommit,
    WorkerPhase,
    WorkerPhaseResult,
    verify_worker_commit_git,
)
from .gota_protocol import (
    GotaRequest,
    GotaReviewResult,
    GotaWorkerResult,
    WorkerResultStatus,
)
from .opencode_runner import OpenCodeRunResult, OpenCodeRunStatus
from .store import (
    GotaReviewResultError,
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

    def _review_expected_snapshot(self, evidence: Evidence) -> GitSnapshot:
        """Rebuild the persisted Git fingerprint used for REVIEW revalidation."""

        payload = evidence.payload
        try:
            refs = payload["refs"]
            if type(refs) is not list or any(
                type(ref) is not list or len(ref) != 3 for ref in refs
            ):
                raise ValueError("Persisted REVIEW refs are not canonical")
            return GitSnapshot(
                repository=str(self.repository),
                head=payload["head"],
                branch=payload["branch"],
                status=payload["status"],
                refs=tuple(tuple(ref) for ref in refs),
            )
        except (KeyError, TypeError, ValueError) as error:
            raise self._authority_error(
                "Persisted REVIEW Git fingerprint is malformed"
            ) from error

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

            expected_snapshot = self._review_expected_snapshot(existing)

            def verify_review(
                durable_request: GotaRequest,
                durable_result: GotaWorkerResult,
            ) -> Mapping[str, Any]:
                return self._verify(
                    durable_request,
                    durable_result,
                    expected_snapshot,
                )

            persistence = self.store._persist_gota_worker_commit_verified_and_review(
                run_id,
                attempt,
                request_id,
                lease,
                verify=verify_review,
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


class GotaReviewerPersistenceBoundary:
    """Run and durably anchor one read-only Reviewer result in REVIEW."""

    def __init__(
        self,
        repository: str | Path,
        *,
        runner: GotaCycleRunner,
        store: SQLiteCoordinatorStore,
        git: ReadOnlyGitAdapter | None = None,
    ) -> None:
        self.repository = Path(repository)
        self.store = store
        self.worker_review_boundary = GotaWorkerReviewBoundary(
            self.repository,
            store=store,
            git=git,
        )
        self.review_phase = ReviewPhase(runner=runner)

    @staticmethod
    def _durable_handoff(
        repository: Path,
        request: GotaRequest,
        worker_result: GotaWorkerResult,
        commit_evidence: Evidence,
    ) -> VerifiedWorkerCommit:
        """Adapt only durable Worker authorities to ReviewPhase's handoff API."""

        payload = commit_evidence.payload
        try:
            refs = payload["refs"]
            snapshot = GitSnapshot(
                repository=str(repository),
                head=payload["head"],
                branch=payload["branch"],
                status=payload["status"],
                refs=tuple(tuple(ref) for ref in refs),
            )
        except (KeyError, TypeError, ValueError) as error:
            raise GotaReviewResultError(
                "Durable Worker commit evidence cannot build a ReviewPhase handoff"
            ) from error
        execution = OpenCodeRunResult(
            status=OpenCodeRunStatus.SUCCEEDED,
            argv=(),
            cwd=str(repository),
            stdout="",
            stderr="",
            exit_code=0,
            timed_out=False,
            payload=worker_result,
        )
        return VerifiedWorkerCommit(
            request=request,
            repository=repository,
            base_sha=request.base_sha,
            branch=request.branch,
            verified_commit_sha=worker_result.commit_sha,
            verified_changed_paths=tuple(sorted(worker_result.changed_paths)),
            worker_execution=execution,
            worker_payload=worker_result,
            worker_snapshot=snapshot,
        )

    def run(
        self,
        run_id: str,
        lease: Lease,
        *,
        attempt: int,
        request_id: str,
        timeout: float,
    ) -> ReviewPhaseResult | GotaReviewResult:
        """Revalidate REVIEW, run Reviewer only when no result is durable."""

        run = self.store.get_run(run_id)
        if run.state is not TaskState.REVIEW:
            raise GotaWorkerReviewBoundaryError(
                "Gota Reviewer persistence requires a REVIEW task"
            )

        worker_request_id = request_id
        frontier = self.worker_review_boundary.run(
            run_id,
            lease,
            attempt=attempt,
            request_id=worker_request_id,
        )
        if frontier.state is not TaskState.REVIEW:
            raise GotaWorkerReviewBoundaryError(
                "Worker-to-Review frontier did not remain in REVIEW"
            )

        review_request_id = f"{run_id}:{attempt}:review"
        durable = self.store.load_gota_review_result(
            run_id,
            attempt,
            review_request_id,
        )
        if durable is not None:
            return durable

        request = self.store.load_gota_worker_request(
            run_id,
            attempt,
            worker_request_id,
        )
        worker_result = self.store.load_gota_worker_result(
            run_id,
            attempt,
            worker_request_id,
        )
        commit_evidence = self.store.load_gota_worker_commit_verified(
            run_id,
            attempt,
            worker_request_id,
        )
        if request is None or worker_result is None or commit_evidence is None:
            raise GotaWorkerReviewBoundaryError(
                "An intact Worker-to-Review frontier is required before Reviewer"
            )
        if (
            worker_result.commit_sha != frontier.commit_sha
            or commit_evidence.payload.get("commit_sha") != worker_result.commit_sha
        ):
            raise GotaWorkerReviewBoundaryError(
                "Reviewer SHA authority does not match the durable WorkerResult"
            )

        handoff = self._durable_handoff(
            self.worker_review_boundary.repository,
            request,
            worker_result,
            commit_evidence,
        )
        phase_result = self.review_phase.run(handoff, timeout=timeout)
        if not phase_result.valid:
            return phase_result
        review_result = phase_result.review_result
        if type(review_result) is not GotaReviewResult:
            raise GotaReviewResultError(
                "A successful ReviewPhase result has no canonical ReviewResult"
            )

        self.worker_review_boundary.run(
            run_id,
            lease,
            attempt=attempt,
            request_id=worker_request_id,
        )
        self.store.persist_gota_review_result(run_id, review_result, lease)
        return phase_result


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
    "GotaReviewerPersistenceBoundary",
    "GotaWorkerReviewBoundary",
    "GotaWorkerReviewBoundaryResult",
    "GotaWorkerPersistenceBoundary",
    "GotaWorkerRecoveryRequiredError",
]
