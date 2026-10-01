"""Pure mapping from a completed Gota review cycle to its next action."""

from __future__ import annotations

from dataclasses import dataclass
from enum import StrEnum

from .gota_cycle import GotaCycleFailure, GotaReviewCycleResult
from .gota_protocol import GotaReviewResult, ReviewDecision


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


class GotaDecisionPolicy:
    """Resolve a cycle result without performing the selected next action."""

    @staticmethod
    def resolve(cycle_result: GotaReviewCycleResult) -> GotaDecisionResult:
        review_result = cycle_result.review_result
        observed_decision = (
            review_result.decision
            if isinstance(review_result, GotaReviewResult)
            and isinstance(review_result.decision, ReviewDecision)
            else None
        )
        accepted_decision = (
            cycle_result.decision
            if isinstance(review_result, GotaReviewResult)
            else None
        )

        if (
            not cycle_result.valid
            or not isinstance(review_result, GotaReviewResult)
            or not isinstance(accepted_decision, ReviewDecision)
        ):
            return GotaDecisionResult(
                action=GotaNextAction.CYCLE_FAILED,
                review_result=(
                    review_result
                    if isinstance(review_result, GotaReviewResult)
                    else None
                ),
                review_decision=observed_decision,
                cycle_failure=cycle_result.failure,
                reason=GotaDecisionPolicy._failure_reason(cycle_result),
            )

        action = _DECISION_TO_ACTION.get(accepted_decision)
        if action is None:
            return GotaDecisionResult(
                action=GotaNextAction.CYCLE_FAILED,
                review_result=review_result,
                review_decision=observed_decision,
                cycle_failure=cycle_result.failure,
                reason="Cycle contains an unsupported ReviewDecision",
            )

        return GotaDecisionResult(
            action=action,
            review_result=review_result,
            review_decision=accepted_decision,
            cycle_failure=None,
            reason=cycle_result.diagnostic,
        )

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
