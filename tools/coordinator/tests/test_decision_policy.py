from __future__ import annotations

from collections.abc import Callable
import unittest
from dataclasses import replace
from decimal import Decimal
from unittest.mock import patch

from flow_coordinator import (
    GOTA_PROTOCOL,
    GotaCycleFailure,
    GotaCyclePhase,
    GotaCheckpoint,
    GotaDecisionPolicy,
    GotaDecisionResult,
    GotaFinding,
    GotaNextAction,
    GotaReviewCycleResult,
    GotaReviewResult,
    GotaWorkerResult,
    ReviewDecision,
    WorkerResultStatus,
)


class FabricatedReviewResult(GotaReviewResult):
    pass


class FabricatedText(str):
    def __eq__(self, _other: object) -> bool:
        return True

    def __hash__(self) -> int:
        return str.__hash__(self)


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

    def _resolve_with_post_validation_mutation(
        self,
        review_result: GotaReviewResult,
        mutation: Callable[[GotaReviewResult], None],
    ) -> GotaDecisionResult:
        cycle_result = self._cycle_result(review_result=review_result)
        original_authority_error = GotaDecisionPolicy._authority_error

        def validate_then_mutate(
            cycle: GotaReviewCycleResult,
            review: object,
            *,
            canonical_review_result: bool,
        ) -> str | None:
            authority_error = original_authority_error(
                cycle,
                review,
                canonical_review_result=canonical_review_result,
            )
            self.assertIsNone(authority_error)
            mutation(review_result)
            return authority_error

        with patch.object(
            GotaDecisionPolicy,
            "_authority_error",
            new=staticmethod(validate_then_mutate),
        ):
            return GotaDecisionPolicy.resolve(cycle_result)

    def test_valid_review_decisions_map_to_next_actions(self) -> None:
        expected = {
            ReviewDecision.PASSED: GotaNextAction.COMPLETE,
            ReviewDecision.CORRECTION_REQUIRED: GotaNextAction.CORRECT,
            ReviewDecision.HUMAN_REVIEW_REQUIRED: GotaNextAction.WAIT_FOR_HUMAN,
            ReviewDecision.BLOCKED: GotaNextAction.BLOCK,
        }

        for decision, action in expected.items():
            with self.subTest(decision=decision):
                review_result = self._review_result(decision)
                result = GotaDecisionPolicy.resolve(
                    self._cycle_result(review_result=review_result)
                )

                self.assertEqual(result.action, action)
                self.assertEqual(result.review_decision, decision)
                self.assertIsNone(result.cycle_failure)
                self.assertEqual(result.reason, "cycle diagnostic")
                self.assertIsNot(result.review_result, review_result)

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

    def test_authority_snapshot_survives_post_validation_decision_mutation(self) -> None:
        review_result = self._review_result(ReviewDecision.PASSED)
        result = self._resolve_with_post_validation_mutation(
            review_result,
            lambda review: object.__setattr__(
                review,
                "decision",
                ReviewDecision.CORRECTION_REQUIRED,
            ),
        )

        self.assertEqual(result.action, GotaNextAction.COMPLETE)
        self.assertEqual(result.review_decision, ReviewDecision.PASSED)
        self.assertIsNot(result.review_result, review_result)

    def test_authority_snapshot_survives_post_validation_commit_mutation(self) -> None:
        review_result = self._review_result(ReviewDecision.PASSED)
        result = self._resolve_with_post_validation_mutation(
            review_result,
            lambda review: object.__setattr__(
                review,
                "reviewed_commit_sha",
                "fedcba9876543210fedcba9876543210fedcba98",
            ),
        )

        self.assertEqual(result.action, GotaNextAction.COMPLETE)
        self.assertEqual(result.review_result.reviewed_commit_sha, self.commit_sha)

    def test_authority_snapshot_survives_post_validation_evidence_mutation(self) -> None:
        review_result = self._review_result(ReviewDecision.PASSED)
        object.__setattr__(
            review_result,
            "evidence",
            ({"kind": "audit", "metadata": {"passed": True}},),
        )
        result = self._resolve_with_post_validation_mutation(
            review_result,
            lambda review: review.evidence[0]["metadata"].__setitem__(
                "passed",
                False,
            ),
        )

        self.assertEqual(result.action, GotaNextAction.COMPLETE)
        self.assertEqual(
            result.review_result.evidence,
            ({"kind": "audit", "metadata": {"passed": True}},),
        )

    def test_authority_snapshot_survives_post_validation_findings_mutation(self) -> None:
        review_result = self._review_result(ReviewDecision.PASSED)
        result = self._resolve_with_post_validation_mutation(
            review_result,
            lambda review: object.__setattr__(
                review,
                "findings",
                (
                    GotaFinding(
                        id="finding-1",
                        severity="high",
                        description="mutated",
                    ),
                ),
            ),
        )

        self.assertEqual(result.action, GotaNextAction.COMPLETE)
        self.assertEqual(result.review_result.findings, ())

    def test_authority_snapshot_survives_post_validation_attempt_mutation(self) -> None:
        review_result = self._review_result(ReviewDecision.PASSED)
        result = self._resolve_with_post_validation_mutation(
            review_result,
            lambda review: object.__setattr__(review, "attempt", 2),
        )

        self.assertEqual(result.action, GotaNextAction.COMPLETE)
        self.assertEqual(result.review_result.attempt, 1)

    def test_authority_snapshot_survives_post_validation_identity_mutation(self) -> None:
        review_result = self._review_result(ReviewDecision.PASSED)
        result = self._resolve_with_post_validation_mutation(
            review_result,
            lambda review: object.__setattr__(review, "task_id", "other-task"),
        )

        self.assertEqual(result.action, GotaNextAction.COMPLETE)
        self.assertEqual(result.review_result.task_id, "task-policy")

    def test_authority_snapshot_is_independent_after_multiple_original_mutations(
        self,
    ) -> None:
        review_result = self._review_result(ReviewDecision.PASSED)

        def mutate_original(review: GotaReviewResult) -> None:
            object.__setattr__(review, "decision", ReviewDecision.BLOCKED)
            object.__setattr__(
                review,
                "reviewed_commit_sha",
                "fedcba9876543210fedcba9876543210fedcba98",
            )
            object.__setattr__(review, "evidence", ({"kind": "mutated"},))
            object.__setattr__(
                review,
                "findings",
                (
                    GotaFinding(
                        id="finding-2",
                        severity="critical",
                        description="mutated",
                    ),
                ),
            )
            object.__setattr__(review, "attempt", 9)
            object.__setattr__(review, "task_id", "other-task")

        result = self._resolve_with_post_validation_mutation(
            review_result,
            mutate_original,
        )

        self.assertEqual(result.action, GotaNextAction.COMPLETE)
        self.assertEqual(result.review_decision, ReviewDecision.PASSED)
        self.assertIsNot(result.review_result, review_result)
        self.assertEqual(result.review_result.reviewed_commit_sha, self.commit_sha)
        self.assertEqual(result.review_result.evidence, ({"kind": "audit", "passed": True},))
        self.assertEqual(result.review_result.findings, ())
        self.assertEqual(result.review_result.attempt, 1)
        self.assertEqual(result.review_result.task_id, "task-policy")

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

    def test_mutated_review_evidence_cannot_complete(self) -> None:
        review_result = self._review_result()
        cycle_result = self._cycle_result(review_result=review_result)
        object.__setattr__(review_result, "evidence", list(review_result.evidence))

        result = GotaDecisionPolicy.resolve(cycle_result)

        self.assertEqual(result.action, GotaNextAction.CYCLE_FAILED)
        self.assertIsNone(result.review_result)
        self.assertIsNone(result.review_decision)
        self.assertFalse(result.allows_completion)

    def test_reviewed_commit_must_match_verified_commit(self) -> None:
        review_result = self._review_result()
        object.__setattr__(
            review_result,
            "reviewed_commit_sha",
            "fedcba9876543210fedcba9876543210fedcba98",
        )

        result = GotaDecisionPolicy.resolve(
            self._cycle_result(review_result=review_result)
        )

        self.assertEqual(result.action, GotaNextAction.CYCLE_FAILED)
        self.assertEqual(result.review_decision, ReviewDecision.PASSED)

    def test_non_terminal_cycle_cannot_select_a_business_action(self) -> None:
        cycle_result = replace(
            self._cycle_result(),
            phase=GotaCyclePhase.REVIEWER_RESULT,
        )

        result = GotaDecisionPolicy.resolve(cycle_result)

        self.assertEqual(result.action, GotaNextAction.CYCLE_FAILED)
        self.assertIsNone(result.cycle_failure)
        self.assertEqual(result.review_decision, ReviewDecision.PASSED)

    def test_adversarial_review_field_mutation_cannot_complete(self) -> None:
        review_result = self._review_result()
        object.__setattr__(review_result, "task_id", FabricatedText("task-policy"))

        result = GotaDecisionPolicy.resolve(
            self._cycle_result(review_result=review_result)
        )

        self.assertEqual(result.action, GotaNextAction.CYCLE_FAILED)
        self.assertIsNone(result.review_result)
        self.assertIsNone(result.review_decision)

    def test_noncanonical_reviewed_commit_type_cannot_complete(self) -> None:
        review_result = self._review_result()
        object.__setattr__(
            review_result,
            "reviewed_commit_sha",
            FabricatedText(self.commit_sha),
        )

        result = GotaDecisionPolicy.resolve(
            self._cycle_result(review_result=review_result)
        )

        self.assertEqual(result.action, GotaNextAction.CYCLE_FAILED)
        self.assertIsNone(result.review_result)
        self.assertIsNone(result.review_decision)

    def test_noncanonical_attempt_type_cannot_complete(self) -> None:
        review_result = self._review_result()
        object.__setattr__(review_result, "attempt", Decimal("1.0"))

        result = GotaDecisionPolicy.resolve(
            self._cycle_result(review_result=review_result)
        )

        self.assertEqual(result.action, GotaNextAction.CYCLE_FAILED)
        self.assertIsNone(result.review_result)
        self.assertIsNone(result.review_decision)

    def test_noncanonical_review_decision_cannot_complete(self) -> None:
        review_result = self._review_result()
        object.__setattr__(review_result, "decision", "PASSED")

        result = GotaDecisionPolicy.resolve(
            self._cycle_result(review_result=review_result)
        )

        self.assertEqual(result.action, GotaNextAction.CYCLE_FAILED)
        self.assertIsNone(result.review_result)
        self.assertIsNone(result.review_decision)

    def test_coherent_worker_identity_is_required_when_present(self) -> None:
        review_result = self._review_result()
        worker_result = GotaWorkerResult(
            protocol=GOTA_PROTOCOL,
            message="worker.result",
            request_id="run-policy:1:worker",
            task_id="other-task",
            run_id="run-policy",
            attempt=1,
            result=WorkerResultStatus.READY_FOR_REVIEW,
            commit_sha=self.commit_sha,
            changed_paths=("src/change.py",),
            evidence=({"kind": "test", "passed": True},),
            checkpoint=GotaCheckpoint(
                completed_steps=("implementation",),
                remaining_phase="review",
            ),
        )

        result = GotaDecisionPolicy.resolve(
            replace(
                self._cycle_result(review_result=review_result),
                worker_payload=worker_result,
            )
        )

        self.assertEqual(result.action, GotaNextAction.CYCLE_FAILED)
        self.assertEqual(result.review_decision, ReviewDecision.PASSED)

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
