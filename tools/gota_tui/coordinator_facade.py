"""Minimal application facade over the public Coordinator/Gota APIs."""

from __future__ import annotations

import os
from dataclasses import dataclass, field
from pathlib import Path
from threading import Event
from typing import Any, Callable, Mapping, Protocol

from flow_coordinator import (
    CoordinatorService,
    GotaDecisionApplicationBoundary,
    GotaReviewResult,
    GotaReviewerPersistenceBoundary,
    GotaWorkerPersistenceBoundary,
    GotaWorkerReviewBoundary,
    OpenCodeRunResult,
    OpenCodeRunner,
    SQLiteCoordinatorStore,
    TaskState,
)
from flow_coordinator.gota_phases import ReviewPhaseResult, WorkerPhaseResult

from .envelope import PromptEnvelope
from .prompt_library import PromptComposition


class CoordinatorFacadeError(RuntimeError):
    """A public Coordinator boundary refused an application operation."""


class OutputCallback(Protocol):
    def __call__(self, source: str, text: str) -> None: ...


@dataclass(slots=True)
class CoordinatorOutcome:
    coordinator_run_id: str | None = None
    task_id: str | None = None
    context_id: str | None = None
    coordinator_state: str | None = None
    base_sha: str | None = None
    commit_sha: str | None = None
    worker_result: str | None = None
    review_result: str | None = None
    verdict: str = "CYCLE_FAILED"
    findings: list[Mapping[str, Any]] = field(default_factory=list)
    tests: str | None = None
    diff_check: str | None = None
    diagnostic: str = ""
    cancelled: bool = False


class _ObservingRunner:
    def __init__(
        self,
        *,
        model: str,
        variant: str,
        executable: str,
        output: OutputCallback,
        cancel_event: Event,
    ) -> None:
        self._runner = OpenCodeRunner(
            executable=executable,
            model=model,
            variant=variant,
        )
        self._output = output
        self._cancel_event = cancel_event

    def run(
        self, *, agent: str, prompt: str, cwd: str | Path, timeout: float
    ) -> OpenCodeRunResult:
        return self._runner.run(
            agent=agent,
            prompt=prompt,
            cwd=cwd,
            timeout=timeout,
            output_callback=self._output,
            cancel_event=self._cancel_event,
        )


class OpenCodePromptFacade:
    """Run one direct prompt through the existing shell-free OpenCodeRunner."""

    def __init__(
        self,
        *,
        opencode_executable: str,
        model: str,
        variant: str,
        timeout: float,
        output: OutputCallback,
        cancel_event: Event,
    ) -> None:
        self.opencode_executable = opencode_executable
        self.model = model
        self.variant = variant
        self.timeout = timeout
        self.output = output
        self.cancel_event = cancel_event

    def execute(self, *, agent: str, prompt: str, cwd: str | Path) -> OpenCodeRunResult:
        return _ObservingRunner(
            model=self.model,
            variant=self.variant,
            executable=self.opencode_executable,
            output=self.output,
            cancel_event=self.cancel_event,
        ).run(agent=agent, prompt=prompt, cwd=cwd, timeout=self.timeout)


class CoordinatorGotaFacade:
    """Compose existing Coordinator authorities without mirroring their state."""

    def __init__(
        self,
        *,
        database: str | Path,
        opencode_executable: str,
        model: str,
        variant: str,
        timeout: float,
        owner_id: str,
        output: OutputCallback,
        cancel_event: Event,
    ) -> None:
        self.database = Path(database)
        self.opencode_executable = opencode_executable
        self.model = model
        self.variant = variant
        self.timeout = timeout
        self.owner_id = owner_id
        self.output = output
        self.cancel_event = cancel_event

    def _store_and_service(self) -> tuple[SQLiteCoordinatorStore, CoordinatorService]:
        store = SQLiteCoordinatorStore(self.database)
        return store, CoordinatorService(store)

    def _runner(self) -> _ObservingRunner:
        return _ObservingRunner(
            model=self.model,
            variant=self.variant,
            executable=self.opencode_executable,
            output=self.output,
            cancel_event=self.cancel_event,
        )

    @staticmethod
    def _state(store: SQLiteCoordinatorStore, run_id: str) -> str | None:
        try:
            return store.get_run(run_id).state.value
        except (KeyError, ValueError):
            return None

    @staticmethod
    def _release(service: CoordinatorService, lease: object) -> None:
        try:
            service.locks.release(lease)  # type: ignore[arg-type]
        except Exception:
            # A lease may expire while the child is being collected. The
            # Coordinator remains the authority and recovery is not fabricated.
            pass

    def execute_new_task(
        self,
        envelope: PromptEnvelope,
        composition: PromptComposition,
    ) -> CoordinatorOutcome:
        envelope.require_mutable_fields()
        store, service = self._store_and_service()
        spec = envelope.to_task_spec(composition.combined)
        outcome = CoordinatorOutcome(
            task_id=spec.task_id,
            context_id=spec.context_id,
            base_sha=spec.base_sha,
        )
        if self.cancel_event.is_set():
            outcome.verdict = "UI_CANCELLED"
            outcome.cancelled = True
            outcome.diagnostic = "Cancelled before Coordinator task start"
            return outcome

        try:
            run = service.create_task(spec, envelope.context_payload({
                "template_id": composition.template_id,
                "template_version": composition.template_version,
                "composition_sha256": composition.sha256,
            }))
            outcome.coordinator_run_id = run.run_id
            lease = service.start(run.run_id, owner_id=self.owner_id)
        except Exception as error:
            outcome.verdict = "CYCLE_FAILED"
            outcome.diagnostic = f"Coordinator task start failed: {type(error).__name__}: {error}"
            outcome.coordinator_state = self._state(store, outcome.coordinator_run_id or "")
            return outcome

        request = envelope.to_gota_request(run.run_id, composition.combined)
        runner = self._runner()
        worker_boundary = GotaWorkerPersistenceBoundary(
            request.workspace,
            runner=runner,
            store=store,
        )
        try:
            worker = worker_boundary.run(request, lease, timeout=self.timeout)
            if self.cancel_event.is_set():
                self._release(service, lease)
                outcome.cancelled = True
                outcome.verdict = "UI_CANCELLED"
                outcome.coordinator_state = self._state(store, run.run_id)
                outcome.diagnostic = "Worker execution was cancelled by the UI"
                return outcome

            if isinstance(worker, WorkerPhaseResult):
                outcome.worker_result = (
                    worker.worker_payload.result.value
                    if worker.worker_payload is not None
                    else worker.failure.value if worker.failure is not None else None
                )
                if not worker.valid:
                    outcome.diagnostic = worker.diagnostic
                    outcome.coordinator_state = self._record_worker_failure(
                        service, store, run.run_id, lease, worker.diagnostic
                    )
                    outcome.verdict = "CYCLE_FAILED"
                    return outcome
            else:
                outcome.worker_result = worker.result.value

            frontier = GotaWorkerReviewBoundary(
                request.workspace,
                store=store,
            ).run(
                run.run_id,
                lease,
                attempt=request.attempt,
                request_id=request.request_id,
            )
            outcome.commit_sha = frontier.commit_sha
            outcome.coordinator_state = frontier.state.value
            if self.cancel_event.is_set():
                self._release(service, lease)
                outcome.cancelled = True
                outcome.verdict = "UI_CANCELLED"
                outcome.diagnostic = "Cancelled before Reviewer execution"
                return outcome

            reviewer = GotaReviewerPersistenceBoundary(
                request.workspace,
                runner=runner,
                store=store,
            ).run(
                run.run_id,
                lease,
                attempt=request.attempt,
                request_id=request.request_id,
                timeout=self.timeout,
            )
            review_result: GotaReviewResult | None
            if isinstance(reviewer, GotaReviewResult):
                review_result = reviewer
            elif isinstance(reviewer, ReviewPhaseResult):
                if not reviewer.valid or reviewer.review_result is None:
                    self._release(service, lease)
                    outcome.coordinator_state = self._state(store, run.run_id)
                    outcome.diagnostic = reviewer.diagnostic
                    outcome.verdict = "CYCLE_FAILED"
                    return outcome
                review_result = reviewer.review_result
            else:
                raise CoordinatorFacadeError("Reviewer boundary returned an unknown result")

            outcome.review_result = review_result.decision.value
            outcome.findings = [finding.to_payload() for finding in review_result.findings]
            if self.cancel_event.is_set():
                self._release(service, lease)
                outcome.cancelled = True
                outcome.verdict = "UI_CANCELLED"
                outcome.coordinator_state = self._state(store, run.run_id)
                outcome.diagnostic = "Reviewer result persisted; UI cancelled decision application"
                return outcome

            decision = GotaDecisionApplicationBoundary(store).run(
                run.run_id,
                lease,
                attempt=request.attempt,
                request_id=review_result.request_id,
            )
            outcome.coordinator_state = decision.state.value
            outcome.verdict = review_result.decision.value
            outcome.diagnostic = decision.resolution.reason
            self._release(service, lease)
            return outcome
        except Exception as error:
            self._release(service, lease)
            outcome.coordinator_state = self._state(store, run.run_id)
            outcome.verdict = "CYCLE_FAILED"
            outcome.diagnostic = f"Coordinator Gota boundary failed: {type(error).__name__}: {error}"
            return outcome

    @staticmethod
    def _record_worker_failure(
        service: CoordinatorService,
        store: SQLiteCoordinatorStore,
        run_id: str,
        lease: object,
        diagnostic: str,
    ) -> str | None:
        try:
            _attempt, failed = service.fail(
                run_id,
                lease,  # type: ignore[arg-type]
                resource_id="opencode-worker",
                details={"diagnostic": diagnostic},
            )
            return failed.state.value
        except Exception:
            CoordinatorGotaFacade._release(service, lease)
            return CoordinatorGotaFacade._state(store, run_id)

    def review_existing(
        self,
        envelope: PromptEnvelope,
    ) -> CoordinatorOutcome:
        envelope.require_mutable_fields()
        raw_run_id = envelope.metadata.get("coordinator_run_id")
        if type(raw_run_id) is not str or not raw_run_id.strip():
            raise CoordinatorFacadeError(
                "Review requires coordinator_run_id in the structured envelope"
            )
        store, service = self._store_and_service()
        run = store.get_run(raw_run_id)
        if run.state is not TaskState.REVIEW:
            raise CoordinatorFacadeError(
                f"Review requires a durable REVIEW run; observed {run.state.value}"
            )
        request = store.load_gota_worker_request(
            raw_run_id,
            1,
            f"{raw_run_id}:1:worker",
        )
        if request is None:
            raise CoordinatorFacadeError("Review requires a durable Worker request")
        lease = service.locks.acquire(self.owner_id, raw_run_id)
        runner = self._runner()
        try:
            reviewer = GotaReviewerPersistenceBoundary(
                request.workspace,
                runner=runner,
                store=store,
            ).run(
                raw_run_id,
                lease,
                attempt=1,
                request_id=request.request_id,
                timeout=self.timeout,
            )
            if isinstance(reviewer, ReviewPhaseResult) and not reviewer.valid:
                self._release(service, lease)
                return CoordinatorOutcome(
                    coordinator_run_id=raw_run_id,
                    task_id=run.task_id,
                    coordinator_state=self._state(store, raw_run_id),
                    verdict="CYCLE_FAILED",
                    diagnostic=reviewer.diagnostic,
                )
            result = reviewer if isinstance(reviewer, GotaReviewResult) else reviewer.review_result
            if result is None:
                raise CoordinatorFacadeError("Reviewer returned no durable result")
            decision = GotaDecisionApplicationBoundary(store).run(
                raw_run_id,
                lease,
                attempt=1,
                request_id=result.request_id,
            )
            self._release(service, lease)
            return CoordinatorOutcome(
                coordinator_run_id=raw_run_id,
                task_id=run.task_id,
                coordinator_state=decision.state.value,
                commit_sha=result.reviewed_commit_sha,
                review_result=result.decision.value,
                verdict=result.decision.value,
                findings=[finding.to_payload() for finding in result.findings],
                diagnostic=decision.resolution.reason,
            )
        except Exception:
            self._release(service, lease)
            raise
