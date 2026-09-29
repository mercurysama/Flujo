"""Authoritative task state transitions."""

from __future__ import annotations

from .domain import TaskState


class InvalidTransitionError(ValueError):
    pass


VALID_TRANSITIONS: dict[TaskState, frozenset[TaskState]] = {
    TaskState.ASSIGNED: frozenset(
        {TaskState.RUNNING, TaskState.BLOCKED, TaskState.CANCELLED}
    ),
    TaskState.RUNNING: frozenset(
        {
            TaskState.REVIEW,
            TaskState.NOT_COMPLETED,
            TaskState.BLOCKED,
            TaskState.CANCELLED,
        }
    ),
    TaskState.REVIEW: frozenset(
        {
            TaskState.DONE,
            TaskState.NOT_COMPLETED,
            TaskState.BLOCKED,
            TaskState.CANCELLED,
        }
    ),
    TaskState.NOT_COMPLETED: frozenset(
        {TaskState.ASSIGNED, TaskState.BLOCKED, TaskState.CANCELLED}
    ),
    TaskState.BLOCKED: frozenset({TaskState.ASSIGNED, TaskState.CANCELLED}),
    TaskState.DONE: frozenset(),
    TaskState.CANCELLED: frozenset(),
}


def validate_transition(from_state: TaskState, to_state: TaskState) -> None:
    if to_state not in VALID_TRANSITIONS[from_state]:
        raise InvalidTransitionError(
            f"Invalid task transition: {from_state.value} -> {to_state.value}"
        )
