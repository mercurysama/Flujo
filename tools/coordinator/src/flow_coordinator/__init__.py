"""Local multiproject task coordinator core."""

from .domain import (
    COORDINATOR_SCHEMA_VERSION,
    Checkpoint,
    Context,
    CoordinatorResource,
    Evidence,
    Lease,
    ProjectBinding,
    ResourceState,
    TaskRun,
    TaskSpec,
    TaskState,
    TransitionEvent,
)
from .service import CoordinatorService
from .git_transaction import GitAcceptanceWorkflow, TransactionalGitAdapter
from .store import SQLiteCoordinatorStore

__all__ = [
    "COORDINATOR_SCHEMA_VERSION",
    "Checkpoint",
    "Context",
    "CoordinatorResource",
    "CoordinatorService",
    "Evidence",
    "GitAcceptanceWorkflow",
    "Lease",
    "ProjectBinding",
    "ResourceState",
    "SQLiteCoordinatorStore",
    "TaskRun",
    "TaskSpec",
    "TaskState",
    "TransitionEvent",
    "TransactionalGitAdapter",
]
