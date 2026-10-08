"""Durable application of one already-persisted Gota review decision."""

from __future__ import annotations

from dataclasses import dataclass

from .decision_policy import GotaDecisionPolicy, GotaDecisionResult, GotaNextAction
from .domain import Evidence, Lease, TaskRun, TaskState
from .gota_cycle import GotaCyclePhase, GotaReviewCycleResult
from .gota_protocol import GotaReviewResult
from .store import (
    GotaDecisionApplicationError,
    GotaDecisionApplicationPersistence,
    GotaDecisionAuthorities,
    GotaHumanReviewHold,
    SQLiteCoordinatorStore,
)


_DURABLE_CYCLE_DIAGNOSTIC = (
    "Durable Worker-to-Review and ReviewResult authorities are complete"
)


@dataclass(frozen=True, slots=True)
class GotaDecisionApplicationResult:
    """Observable result of one applied or recognized Policy action."""

    run: TaskRun
    resolution: GotaDecisionResult
    created: bool
    decision_evidence: Evidence | None = None
    human_review_hold: GotaHumanReviewHold | None = None

    @property
    def state(self) -> TaskState:
        return self.run.state

    @property
    def action(self) -> GotaNextAction:
        return self.resolution.action

    @property
    def already_applied(self) -> bool:
        return not self.created


class GotaDecisionApplicationBoundary:
    """Apply GotaDecisionPolicy using durable authorities only."""

    def __init__(self, store: SQLiteCoordinatorStore) -> None:
        self.store = store

    @staticmethod
    def _worker_request_id(
        run_id: str,
        attempt: int,
        request_id: str,
    ) -> str:
        worker_request_id = f"{run_id}:{attempt}:worker"
        review_request_id = f"{run_id}:{attempt}:review"
        if request_id not in {worker_request_id, review_request_id}:
            raise GotaDecisionApplicationError(
                "Gota decision request identity is not canonical"
            )
        return worker_request_id

    @staticmethod
    def _canonical_cycle(
        authorities: GotaDecisionAuthorities,
    ) -> GotaReviewCycleResult:
        payload = authorities.worker_commit_evidence.payload
        try:
            base_sha = payload["base_sha"]
            branch = payload["branch"]
            verified_commit_sha = payload["commit_sha"]
            verified_changed_paths = tuple(payload["changed_paths"])
        except (KeyError, TypeError, ValueError) as error:
            raise GotaDecisionApplicationError(
                "Durable Worker commit authority cannot build the Policy input"
            ) from error
        return GotaReviewCycleResult(
            base_sha=base_sha,
            branch=branch,
            worker_execution=None,
            worker_payload=authorities.worker_result,
            verified_commit_sha=verified_commit_sha,
            verified_changed_paths=verified_changed_paths,
            reviewer_execution=None,
            review_result=authorities.review_result,
            phase=GotaCyclePhase.COMPLETED,
            failure=None,
            diagnostic=_DURABLE_CYCLE_DIAGNOSTIC,
        )

    def run(
        self,
        run_id: str,
        lease: Lease,
        *,
        attempt: int,
        request_id: str,
    ) -> GotaDecisionApplicationResult:
        """Resolve and apply one durable ReviewResult without rerunning phases."""

        worker_request_id = self._worker_request_id(
            run_id, attempt, request_id
        )
        authorities = self.store.load_gota_decision_authorities(
            run_id,
            attempt,
            worker_request_id,
        )
        cycle_result = self._canonical_cycle(authorities)
        resolution = GotaDecisionPolicy.resolve(cycle_result)

        if resolution.action is GotaNextAction.COMPLETE:
            if authorities.run.state is TaskState.REVIEW:
                # The frozen store primitive is the sole PASSED transition.
                run = self.store.transition_gota_to_done(run_id, lease)
                return GotaDecisionApplicationResult(
                    run=run,
                    resolution=resolution,
                    created=True,
                )
            if authorities.run.state is TaskState.DONE:
                run = self.store.recognize_gota_acceptance(
                    run_id,
                    attempt,
                    worker_request_id,
                    resolution,
                )
                return GotaDecisionApplicationResult(
                    run=run,
                    resolution=resolution,
                    created=False,
                )
            raise GotaDecisionApplicationError(
                "PASSED Policy action does not match the durable task state"
            )

        if resolution.action in {
            GotaNextAction.CORRECT,
            GotaNextAction.WAIT_FOR_HUMAN,
            GotaNextAction.BLOCK,
        }:
            if authorities.run.state is TaskState.REVIEW:
                persistence = self.store.apply_gota_decision(
                    run_id,
                    lease,
                    resolution,
                )
                return self._result(resolution, persistence)
            if authorities.run.state in {
                TaskState.NOT_COMPLETED,
                TaskState.BLOCKED,
            }:
                persistence = self.store.recognize_gota_decision_application(
                    run_id,
                    attempt,
                    worker_request_id,
                    resolution,
                )
                return self._result(resolution, persistence)
            raise GotaDecisionApplicationError(
                "Non-PASSED Policy action does not match the durable task state"
            )

        if resolution.action is GotaNextAction.CYCLE_FAILED:
            raise GotaDecisionApplicationError(
                f"CYCLE_FAILED cannot be applied: {resolution.reason}"
            )
        raise GotaDecisionApplicationError(
            "DecisionPolicy returned an unsupported action"
        )

    @staticmethod
    def _result(
        resolution: GotaDecisionResult,
        persistence: object,
    ) -> GotaDecisionApplicationResult:
        if not isinstance(persistence, GotaDecisionApplicationPersistence):
            raise GotaDecisionApplicationError(
                "Gota decision store returned a non-canonical persistence result"
            )
        return GotaDecisionApplicationResult(
            run=persistence.run,
            resolution=resolution,
            created=persistence.created,
            decision_evidence=persistence.decision_evidence,
            human_review_hold=persistence.hold,
        )


__all__ = [
    "GotaDecisionApplicationBoundary",
    "GotaDecisionApplicationResult",
]
