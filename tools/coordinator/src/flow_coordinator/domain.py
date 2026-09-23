"""Versioned domain types for the coordinator core."""

from __future__ import annotations

from dataclasses import dataclass, field
from datetime import UTC, datetime
from enum import StrEnum
from pathlib import Path
from typing import Any, Mapping


COORDINATOR_SCHEMA_VERSION = 1
TASK_SPEC_SCHEMA = "flow.coordinator/task-spec/v1"
CONTEXT_SCHEMA = "flow.coordinator/context/v1"


def utc_now() -> datetime:
    return datetime.now(UTC)


def isoformat(value: datetime) -> str:
    if value.tzinfo is None:
        value = value.replace(tzinfo=UTC)
    return value.astimezone(UTC).isoformat()


def parse_datetime(value: str) -> datetime:
    return datetime.fromisoformat(value).astimezone(UTC)


class TaskState(StrEnum):
    ASSIGNED = "ASSIGNED"
    RUNNING = "RUNNING"
    REVIEW = "REVIEW"
    DONE = "DONE"
    NOT_COMPLETED = "NOT_COMPLETED"
    BLOCKED = "BLOCKED"
    CANCELLED = "CANCELLED"

    @property
    def symbol(self) -> str:
        return {
            TaskState.ASSIGNED: "🌊",
            TaskState.RUNNING: "🛠",
            TaskState.REVIEW: "👀",
            TaskState.DONE: "🙆🏻",
            TaskState.NOT_COMPLETED: "🙅🏻",
            TaskState.BLOCKED: "⛔",
            TaskState.CANCELLED: "❌",
        }[self]

    @property
    def terminal(self) -> bool:
        return self in {TaskState.DONE, TaskState.CANCELLED}


class ResourceState(StrEnum):
    COOLDOWN = "COOLDOWN"

    @property
    def symbol(self) -> str:
        return "❤️‍🔥"


@dataclass(frozen=True, slots=True)
class TaskSpec:
    task_id: str
    title: str
    objective: str
    project_id: str
    repository_id: str
    branch: str
    base_sha: str
    context_id: str
    allowed_paths: tuple[str, ...]
    protected_paths: tuple[str, ...]
    required_resources: tuple[str, ...]
    acceptance_criteria: tuple[str, ...]
    commit_message: str
    schema: str = TASK_SPEC_SCHEMA
    created_at: datetime = field(default_factory=utc_now)

    def validate(self) -> None:
        required = {
            "task_id": self.task_id,
            "title": self.title,
            "objective": self.objective,
            "project_id": self.project_id,
            "repository_id": self.repository_id,
            "branch": self.branch,
            "base_sha": self.base_sha,
            "context_id": self.context_id,
            "commit_message": self.commit_message,
        }
        missing = [name for name, value in required.items() if not value.strip()]
        if missing:
            raise ValueError(f"Missing TaskSpec fields: {', '.join(sorted(missing))}")
        if self.schema != TASK_SPEC_SCHEMA:
            raise ValueError(f"Unsupported TaskSpec schema: {self.schema}")
        overlap = set(self.allowed_paths) & set(self.protected_paths)
        if overlap:
            raise ValueError(f"Paths cannot be both allowed and protected: {sorted(overlap)}")
        for path in (*self.allowed_paths, *self.protected_paths):
            if Path(path).is_absolute() or ".." in Path(path).parts:
                raise ValueError(f"Task paths must be repository-relative: {path}")


@dataclass(frozen=True, slots=True)
class TaskRun:
    run_id: str
    task_id: str
    state: TaskState
    created_at: datetime
    updated_at: datetime


@dataclass(frozen=True, slots=True)
class Context:
    context_id: str
    task_id: str
    project_id: str
    payload: Mapping[str, Any]
    schema: str = CONTEXT_SCHEMA
    created_at: datetime = field(default_factory=utc_now)


@dataclass(frozen=True, slots=True)
class Evidence:
    evidence_id: str
    run_id: str
    kind: str
    payload: Mapping[str, Any]
    digest: str
    created_at: datetime


@dataclass(frozen=True, slots=True)
class Checkpoint:
    checkpoint_id: str
    run_id: str
    payload: Mapping[str, Any]
    digest: str
    created_at: datetime


@dataclass(frozen=True, slots=True)
class TransitionEvent:
    event_id: int
    run_id: str
    from_state: TaskState | None
    to_state: TaskState
    actor: str
    reason: str
    created_at: datetime


@dataclass(frozen=True, slots=True)
class Lease:
    owner_id: str
    run_id: str
    fencing_token: int
    acquired_at: datetime
    expires_at: datetime


@dataclass(frozen=True, slots=True)
class CoordinatorResource:
    resource_id: str
    cooldown_required: bool
    minimum_seconds: int
    state: ResourceState | None
    cooldown_started_at: datetime | None
    not_before: datetime | None


@dataclass(frozen=True, slots=True)
class ProjectBinding:
    project_id: str
    repository_id: str
    workspace_path: str
    context_id: str
