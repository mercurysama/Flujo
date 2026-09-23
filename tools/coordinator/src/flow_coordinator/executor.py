"""Deterministic fake executor used by core recovery tests."""

from __future__ import annotations

from collections.abc import Callable, Sequence
from dataclasses import dataclass, field

from .domain import Lease
from .store import SQLiteCoordinatorStore


@dataclass(slots=True)
class FakeExecutor:
    store: SQLiteCoordinatorStore
    execution_counts: dict[str, int] = field(default_factory=dict)

    def execute_steps(
        self,
        run_id: str,
        lease: Lease,
        steps: Sequence[tuple[str, Callable[[], None]]],
    ) -> tuple[str, ...]:
        checkpoint = self.store.latest_checkpoint(run_id)
        confirmed = list(checkpoint.payload.get("confirmed_steps", ())) if checkpoint else []
        executed: list[str] = []
        for step_id, callback in steps:
            if step_id in confirmed:
                continue
            callback()
            self.execution_counts[step_id] = self.execution_counts.get(step_id, 0) + 1
            confirmed.append(step_id)
            executed.append(step_id)
            self.store.append_checkpoint(
                run_id,
                {"confirmed_steps": tuple(confirmed), "last_step": step_id},
                lease,
            )
        return tuple(executed)
