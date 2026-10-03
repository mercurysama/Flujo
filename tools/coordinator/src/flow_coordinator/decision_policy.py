"""Pure mapping from a completed Gota review cycle to its next action."""

from __future__ import annotations

from copy import deepcopy
from dataclasses import dataclass
from enum import StrEnum
from typing import cast

from .gota_cycle import GotaCycleFailure, GotaCyclePhase, GotaReviewCycleResult
from .gota_phases import (
    _canonical_execution,
    _canonical_payload,
    _canonical_sha,
    _canonical_text,
    _canonical_text_tuple,
    _strictly_equal,
    validate_successful_execution,
)
from .gota_protocol import (
    GotaReviewResult,
    GotaWorkerResult,
    ReviewDecision,
    parse_gota_payload,
)


class GotaNextAction(StrEnum):
    COMPLETE = "COMPLETE"
    CORRECT = "CORRECT"
    WAIT_FOR_HUMAN = "WAIT_FOR_HUMAN"
    BLOCK = "BLOCK"
    CYCLE_FAILED = "CYCLE_FAILED"


@dataclass(frozen=True, slots=True)
class GotaDecisionResult:
    """The action selected from one cycle, without applying that action."""

    action: GotaNextAction
    review_result: GotaReviewResult | None
    review_decision: ReviewDecision | None
    cycle_failure: GotaCycleFailure | None
    reason: str

    @property
    def requires_human(self) -> bool:
        return self.action is GotaNextAction.WAIT_FOR_HUMAN

    @property
    def allows_completion(self) -> bool:
        return self.action is GotaNextAction.COMPLETE

    @property
    def requires_correction(self) -> bool:
        return self.action is GotaNextAction.CORRECT


_DECISION_TO_ACTION: dict[ReviewDecision, GotaNextAction] = {
    ReviewDecision.PASSED: GotaNextAction.COMPLETE,
    ReviewDecision.CORRECTION_REQUIRED: GotaNextAction.CORRECT,
    ReviewDecision.HUMAN_REVIEW_REQUIRED: GotaNextAction.WAIT_FOR_HUMAN,
    ReviewDecision.BLOCKED: GotaNextAction.BLOCK,
}


def _canonical_review_snapshot(value: object) -> GotaReviewResult | None:
    """Rebuild the accepted review payload before any business mapping."""

    if type(value) is not GotaReviewResult:
        return None
    review_result = cast(GotaReviewResult, value)
    try:
        canonical = parse_gota_payload(deepcopy(review_result.to_payload()))
    except Exception:
        return None
    if type(canonical) is not GotaReviewResult:
        return None
    if not _strictly_equal(canonical, review_result):
        return None
    return canonical


class GotaDecisionPolicy:
    """Resolve a cycle result without performing the selected next action."""

    @staticmethod
    def resolve(cycle_result: GotaReviewCycleResult) -> GotaDecisionResult:
        if type(cycle_result) is not GotaReviewCycleResult:
            return GotaDecisionResult(
                action=GotaNextAction.CYCLE_FAILED,
                review_result=None,
                review_decision=None,
                cycle_failure=None,
                reason="Cycle result is not canonical",
            )
        review_result = cycle_result.review_result
        canonical_review_result = _canonical_review_snapshot(review_result)
        observed_decision = (
            canonical_review_result.decision
            if canonical_review_result is not None
            else None
        )

        if cycle_result.failure is not None:
            return GotaDecisionResult(
                action=GotaNextAction.CYCLE_FAILED,
                review_result=(
                    review_result
                    if canonical_review_result is not None
                    else None
                ),
                review_decision=observed_decision,
                cycle_failure=cycle_result.failure,
                reason=GotaDecisionPolicy._failure_reason(cycle_result),
            )

        authority_error = GotaDecisionPolicy._authority_error(
            cycle_result,
            review_result,
            canonical_review_result=canonical_review_result is not None,
        )
        if authority_error is not None:
            return GotaDecisionResult(
                action=GotaNextAction.CYCLE_FAILED,
                review_result=(
                    review_result
                    if canonical_review_result is not None
                    else None
                ),
                review_decision=observed_decision,
                cycle_failure=None,
                reason=GotaDecisionPolicy._authority_reason(
                    cycle_result,
                    authority_error,
                ),
            )

        assert canonical_review_result is not None
        accepted_decision = canonical_review_result.decision
        if type(accepted_decision) is not ReviewDecision:
            return GotaDecisionResult(
                action=GotaNextAction.CYCLE_FAILED,
                review_result=canonical_review_result,
                review_decision=None,
                cycle_failure=None,
                reason="Cycle contains a non-canonical ReviewDecision",
            )

        action = _DECISION_TO_ACTION.get(accepted_decision)
        if action is None:
            return GotaDecisionResult(
                action=GotaNextAction.CYCLE_FAILED,
                review_result=canonical_review_result,
                review_decision=observed_decision,
                cycle_failure=cycle_result.failure,
                reason="Cycle contains an unsupported ReviewDecision",
            )

        return GotaDecisionResult(
            action=action,
            review_result=canonical_review_result,
            review_decision=accepted_decision,
            cycle_failure=None,
            reason=cycle_result.diagnostic,
        )

    @staticmethod
    def _authority_error(
        cycle_result: GotaReviewCycleResult,
        review_result: object,
        *,
        canonical_review_result: bool,
    ) -> str | None:
        if cycle_result.phase is not GotaCyclePhase.COMPLETED:
            return "Cycle phase is not the canonical completed phase"
        if not _canonical_sha(cycle_result.base_sha):
            return "Cycle base SHA is not canonical"
        if not _canonical_text(cycle_result.branch):
            return "Cycle branch is not canonical"
        if not _canonical_sha(cycle_result.verified_commit_sha):
            return "Cycle verified commit SHA is not canonical"
        if not _canonical_text_tuple(cycle_result.verified_changed_paths):
            return "Cycle changed paths are not canonical"
        if type(cycle_result.diagnostic) is not str:
            return "Cycle diagnostic is not canonical"
        if not canonical_review_result:
            return "ReviewResult is not canonical"
        assert type(review_result) is GotaReviewResult
        if not _strictly_equal(
            review_result.reviewed_commit_sha,
            cycle_result.verified_commit_sha,
        ):
            return "ReviewResult does not identify the verified commit"

        worker_payload = cycle_result.worker_payload
        if worker_payload is not None:
            if not _canonical_payload(worker_payload, GotaWorkerResult):
                return "WorkerResult is not canonical"
            if not _strictly_equal(
                worker_payload.commit_sha,
                cycle_result.verified_commit_sha,
            ):
                return "WorkerResult does not identify the verified commit"
            if not _strictly_equal(
                tuple(sorted(worker_payload.changed_paths)),
                cycle_result.verified_changed_paths,
            ):
                return "WorkerResult changed paths are not coherent"
            for field_name in ("task_id", "run_id", "attempt"):
                if not _strictly_equal(
                    getattr(worker_payload, field_name),
                    getattr(review_result, field_name),
                ):
                    return f"ReviewResult {field_name} is not coherent with WorkerResult"

        worker_execution = cycle_result.worker_execution
        if worker_execution is not None:
            if not _canonical_execution(worker_execution, GotaWorkerResult):
                return "Worker execution is not canonical"
            if worker_payload is None:
                return "Worker execution has no coherent WorkerResult"
            execution_error = validate_successful_execution(
                worker_execution,
                GotaWorkerResult,
            )
            if execution_error is not None:
                return f"Worker execution is incoherent: {execution_error}"
            if not _strictly_equal(worker_execution.payload, worker_payload):
                return "Worker execution payload is not coherent"

        reviewer_execution = cycle_result.reviewer_execution
        if reviewer_execution is not None:
            if not _canonical_execution(reviewer_execution, GotaReviewResult):
                return "Reviewer execution is not canonical"
            execution_error = validate_successful_execution(
                reviewer_execution,
                GotaReviewResult,
            )
            if execution_error is not None:
                return f"Reviewer execution is incoherent: {execution_error}"
            if not _strictly_equal(reviewer_execution.payload, review_result):
                return "Reviewer execution payload is not coherent"

        return None

    @staticmethod
    def _authority_reason(
        cycle_result: GotaReviewCycleResult,
        authority_error: str,
    ) -> str:
        if type(cycle_result.diagnostic) is str and cycle_result.diagnostic:
            return f"{cycle_result.diagnostic}: {authority_error}"
        return authority_error

    @staticmethod
    def _failure_reason(cycle_result: GotaReviewCycleResult) -> str:
        if cycle_result.diagnostic:
            return cycle_result.diagnostic
        if cycle_result.failure is not None:
            return f"Gota review cycle failed: {cycle_result.failure.value}"
        return "Gota review cycle did not produce an accepted ReviewResult"


__all__ = [
    "GotaDecisionPolicy",
    "GotaDecisionResult",
    "GotaNextAction",
]
