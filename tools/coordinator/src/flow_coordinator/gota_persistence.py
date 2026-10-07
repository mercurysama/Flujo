"""Durable boundary between one validated Worker phase and later work.

If Worker creates a commit and exits before producing a valid WorkerResult or
before this boundary persists it, the store contains no recovery authority.
This module deliberately does not inspect Git to reconstruct that result or
rerun Worker; a later recovery layer must classify the condition as
human-review/fail-closed.
"""

from __future__ import annotations

from pathlib import Path

from .domain import Lease
from .gota_phases import GotaCycleRunner, WorkerPhase, WorkerPhaseResult
from .gota_protocol import GotaRequest, GotaWorkerResult
from .store import (
    GotaWorkerResultError,
    GotaWorkerReservationError,
    SQLiteCoordinatorStore,
)


class GotaWorkerRecoveryRequiredError(GotaWorkerReservationError):
    """A reserved attempt has no durable result and cannot be retried."""


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
    "GotaWorkerPersistenceBoundary",
    "GotaWorkerRecoveryRequiredError",
]
