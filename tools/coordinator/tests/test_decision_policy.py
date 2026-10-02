from __future__ import annotations

import unittest
from dataclasses import replace
from unittest.mock import patch

from flow_coordinator import (
    GOTA_PROTOCOL,
    GotaCycleFailure,
    GotaCyclePhase,
    GotaDecisionPolicy,
    GotaDecisionResult,
    GotaNextAction,
    GotaReviewCycleResult,
    GotaReviewResult,
    ReviewDecision,
)


class FabricatedReviewResult(GotaReviewResult):
    pass


class GotaDecisionPolicyTest(unittest.TestCase):
    commit_sha = "0123456789abcdef0123456789abcdef01234567"

    def _review_result(
        self, decision: ReviewDecision = ReviewDecision.PASSED
    ) -> GotaReviewResult:
        return GotaReviewResult(
            protocol=GOTA_PROTOCOL,
            message="review.result",
            request_id="run-policy:1:review",
            task_id="task-policy",
            run_id="run-policy",
            attempt=1,
            reviewed_commit_sha=self.commit_sha,
            decision=decision,
            findings=(),
            evidence=({"kind": "audit", "passed": True},),
        )

    def _cycle_result(
        self,
        *,
        decision: ReviewDecision = ReviewDecision.PASSED,
        failure: GotaCycleFailure | None = None,
        review_result: GotaReviewResult | None = None,
        diagnostic: str = "cycle diagnostic",
    ) -> GotaReviewCycleResult:
        return GotaReviewCycleResult(
            base_sha=self.commit_sha,
            branch="feature/policy",
            worker_execution=None,
            worker_payload=None,
            verified_commit_sha=self.commit_sha,
            verified_changed_paths=("src/change.py",),
            reviewer_execution=None,
            review_result=(
                self._review_result(decision)
                if review_result is None and failure is None
                else review_result
            ),
            phase=(
                GotaCyclePhase.COMPLETED
                if failure is None
                else GotaCyclePhase.REVIEWER_INTEGRITY
            ),
            failure=failure,
            diagnostic=diagnostic,
        )

    def test_valid_review_decisions_map_to_next_actions(self) -> None:
        expected = {
            ReviewDecision.PASSED: GotaNextAction.COMPLETE,
            ReviewDecision.CORRECTION_REQUIRED: GotaNextAction.CORRECT,
            ReviewDecision.HUMAN_REVIEW_REQUIRED: GotaNextAction.WAIT_FOR_HUMAN,
            ReviewDecision.BLOCKED: GotaNextAction.BLOCK,
        }

        for decision, action in expected.items():
            with self.subTest(decision=decision):
                result = GotaDecisionPolicy.resolve(
                    self._cycle_result(decision=decision)
                )

                self.assertEqual(result.action, action)
                self.assertEqual(result.review_decision, decision)
                self.assertIsNone(result.cycle_failure)
                self.assertEqual(result.reason, "cycle diagnostic")

        self.assertTrue(
            GotaDecisionPolicy.resolve(
                self._cycle_result(decision=ReviewDecision.PASSED)
            ).allows_completion
        )
        self.assertTrue(
            GotaDecisionPolicy.resolve(
                self._cycle_result(decision=ReviewDecision.CORRECTION_REQUIRED)
            ).requires_correction
        )
        self.assertTrue(
            GotaDecisionPolicy.resolve(
                self._cycle_result(decision=ReviewDecision.HUMAN_REVIEW_REQUIRED)
            ).requires_human
        )

    def test_invalid_cycle_is_a_technical_failure_action(self) -> None:
        cycle_result = self._cycle_result(
            failure=GotaCycleFailure.WORKER_RESULT_INVALID,
            diagnostic="worker result was not accepted",
        )

        result = GotaDecisionPolicy.resolve(cycle_result)

        self.assertEqual(result.action, GotaNextAction.CYCLE_FAILED)
        self.assertEqual(result.cycle_failure, GotaCycleFailure.WORKER_RESULT_INVALID)
        self.assertIsNone(result.review_decision)
        self.assertEqual(result.reason, "worker result was not accepted")

    def test_missing_review_result_and_decision_fail_without_business_action(self) -> None:
        no_review = replace(
            self._cycle_result(),
            review_result=None,
            diagnostic="Reviewer did not produce an accepted result",
        )

        result = GotaDecisionPolicy.resolve(no_review)

        self.assertEqual(result.action, GotaNextAction.CYCLE_FAILED)
        self.assertIsNone(result.review_result)
        self.assertIsNone(result.review_decision)

    def test_worker_git_and_reviewer_failures_are_not_blocked(self) -> None:
        failures = (
            GotaCycleFailure.WORKER_NON_ZERO_EXIT,
            GotaCycleFailure.WORKER_GIT_FAILURE,
            GotaCycleFailure.REVIEWER_INVALID_PAYLOAD,
        )

        for failure in failures:
            with self.subTest(failure=failure):
                result = GotaDecisionPolicy.resolve(self._cycle_result(failure=failure))

                self.assertEqual(result.action, GotaNextAction.CYCLE_FAILED)
                self.assertNotEqual(result.action, GotaNextAction.BLOCK)
                self.assertEqual(result.cycle_failure, failure)

    def test_mutated_post_review_cycle_cannot_complete_raw_passed_payload(self) -> None:
        review_result = self._review_result(ReviewDecision.PASSED)
        cycle_result = self._cycle_result(
            failure=GotaCycleFailure.REVIEWER_HEAD_CHANGED,
            review_result=review_result,
            diagnostic="Reviewer changed HEAD after returning PASSED",
        )

        result = GotaDecisionPolicy.resolve(cycle_result)

        self.assertEqual(result.action, GotaNextAction.CYCLE_FAILED)
        self.assertIs(result.review_result, review_result)
        self.assertEqual(result.review_decision, ReviewDecision.PASSED)
        self.assertEqual(result.cycle_failure, GotaCycleFailure.REVIEWER_HEAD_CHANGED)
        self.assertFalse(result.allows_completion)

    def test_invalid_review_payload_is_preserved_only_for_diagnostics(self) -> None:
        review_result = self._review_result(ReviewDecision.PASSED)
        cycle_result = self._cycle_result(
            failure=GotaCycleFailure.REVIEWER_COMMIT_MISMATCH,
            review_result=review_result,
            diagnostic="ReviewResult did not identify the verified commit",
        )

        result = GotaDecisionPolicy.resolve(cycle_result)

        self.assertEqual(result.action, GotaNextAction.CYCLE_FAILED)
        self.assertIs(result.review_result, review_result)
        self.assertEqual(result.review_decision, ReviewDecision.PASSED)
        self.assertEqual(
            result.reason, "ReviewResult did not identify the verified commit"
        )

    def test_noncanonical_review_result_cannot_select_a_business_action(self) -> None:
        source = self._review_result(ReviewDecision.PASSED)
        fabricated = FabricatedReviewResult(
            protocol=source.protocol,
            message=source.message,
            request_id=source.request_id,
            task_id=source.task_id,
            run_id=source.run_id,
            attempt=source.attempt,
            reviewed_commit_sha=source.reviewed_commit_sha,
            decision=source.decision,
            findings=source.findings,
            evidence=source.evidence,
        )

        result = GotaDecisionPolicy.resolve(
            self._cycle_result(review_result=fabricated)
        )

        self.assertEqual(result.action, GotaNextAction.CYCLE_FAILED)
        self.assertIsNone(result.review_result)
        self.assertIsNone(result.review_decision)

    def test_resolution_is_deterministic_and_has_no_runner_git_or_sqlite_side_effects(
        self,
    ) -> None:
        cycle_result = self._cycle_result(
            decision=ReviewDecision.CORRECTION_REQUIRED
        )

        with (
            patch("flow_coordinator.gota_cycle.ReadOnlyGitAdapter") as git_adapter,
            patch("flow_coordinator.opencode_runner.OpenCodeRunner") as runner,
            patch("flow_coordinator.store.SQLiteCoordinatorStore") as store,
        ):
            first = GotaDecisionPolicy.resolve(cycle_result)
            second = GotaDecisionPolicy.resolve(cycle_result)

        self.assertIsInstance(first, GotaDecisionResult)
        self.assertEqual(first, second)
        git_adapter.assert_not_called()
        runner.assert_not_called()
        store.assert_not_called()


if __name__ == "__main__":
    unittest.main()
