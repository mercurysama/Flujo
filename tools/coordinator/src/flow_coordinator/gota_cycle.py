"""Composition facade for one state-free Worker -> Reviewer cycle."""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path

# Keep this module-level name available to existing callers that patch the
# historical cycle boundary while the productive Git work lives in phases.
from .git_adapter import ReadOnlyGitAdapter
from .gota_phases import (
    GotaCycleFailure,
    GotaCyclePhase,
    GotaCycleRunner,
    ReviewPhase,
    ReviewPhaseResult,
    VerifiedWorkerCommit,
    WorkerPhase,
    WorkerPhaseResult,
)
from .gota_protocol import GotaRequest, GotaReviewResult, GotaWorkerResult, ReviewDecision
from .opencode_runner import OpenCodeRunResult


@dataclass(frozen=True, slots=True)
class GotaReviewCycleResult:
    """Validated output of one Worker -> Reviewer pass."""

    base_sha: str
    branch: str
    worker_execution: OpenCodeRunResult | None
    worker_payload: GotaWorkerResult | None
    verified_commit_sha: str | None
    verified_changed_paths: tuple[str, ...]
    reviewer_execution: OpenCodeRunResult | None
    review_result: GotaReviewResult | None
    phase: GotaCyclePhase
    failure: GotaCycleFailure | None
    diagnostic: str

    @property
    def valid(self) -> bool:
        return self.failure is None and self.review_result is not None

    @property
    def decision(self) -> ReviewDecision | None:
        if self.failure is not None or self.review_result is None:
            return None
        return self.review_result.decision


class GotaReviewCycle:
    """Compose WorkerPhase and ReviewPhase without owning their validation."""

    WORKER_AGENT = WorkerPhase.WORKER_AGENT
    REVIEWER_AGENT = ReviewPhase.REVIEWER_AGENT

    def __init__(self, repository: str | Path, *, runner: GotaCycleRunner) -> None:
        self.repository = Path(repository).resolve()
        self.runner = runner
        self.worker_phase = WorkerPhase(self.repository, runner=runner)
        self.review_phase = ReviewPhase(runner=runner)

    @staticmethod
    def _worker_failure_result(result: WorkerPhaseResult) -> GotaReviewCycleResult:
        return GotaReviewCycleResult(
            base_sha=result.base_sha,
            branch=result.branch,
            worker_execution=result.worker_execution,
            worker_payload=result.worker_payload,
            verified_commit_sha=result.verified_commit_sha,
            verified_changed_paths=result.verified_changed_paths,
            reviewer_execution=None,
            review_result=None,
            phase=result.phase,
            failure=result.failure,
            diagnostic=result.diagnostic,
        )

    @staticmethod
    def _review_result(result: ReviewPhaseResult) -> GotaReviewCycleResult:
        verified = result.verified_commit
        return GotaReviewCycleResult(
            base_sha=verified.base_sha,
            branch=verified.branch,
            worker_execution=verified.worker_execution,
            worker_payload=verified.worker_payload,
            verified_commit_sha=verified.verified_commit_sha,
            verified_changed_paths=verified.verified_changed_paths,
            reviewer_execution=result.reviewer_execution,
            review_result=result.review_result,
            phase=result.phase,
            failure=result.failure,
            diagnostic=result.diagnostic,
        )

    def run(self, request: GotaRequest, *, timeout: float) -> GotaReviewCycleResult:
        """Run WorkerPhase once, then ReviewPhase only after verification."""

        worker_result = self.worker_phase.run(request, timeout=timeout)
        if not worker_result.valid:
            return self._worker_failure_result(worker_result)

        verified = worker_result.verified_commit
        if verified is None:
            return GotaReviewCycleResult(
                base_sha=worker_result.base_sha,
                branch=worker_result.branch,
                worker_execution=worker_result.worker_execution,
                worker_payload=worker_result.worker_payload,
                verified_commit_sha=None,
                verified_changed_paths=worker_result.verified_changed_paths,
                reviewer_execution=None,
                review_result=None,
                phase=worker_result.phase,
                failure=GotaCycleFailure.WORKER_RESULT_INVALID,
                diagnostic="Worker phase completed without a verified commit",
            )

        review_result = self.review_phase.run(worker_result, timeout=timeout)
        return self._review_result(review_result)


__all__ = [
    "GotaCycleFailure",
    "GotaCyclePhase",
    "GotaCycleRunner",
    "GotaReviewCycle",
    "GotaReviewCycleResult",
    "ReviewPhase",
    "ReviewPhaseResult",
    "VerifiedWorkerCommit",
    "WorkerPhase",
    "WorkerPhaseResult",
]
