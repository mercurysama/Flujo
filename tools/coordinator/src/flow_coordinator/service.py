"""Coordinator application service over the transactional core."""

from __future__ import annotations

import hashlib
import json
from datetime import datetime
from typing import Any, Mapping, Sequence

from .commit_policy import Committer
from .domain import Context, Lease, TaskRun, TaskSpec, TaskState, utc_now
from .lock import GlobalLockManager
from .store import (
    QueueBlockedError,
    SQLiteCoordinatorStore,
)


class ResourceCooldownError(RuntimeError):
    pass


class CoordinatorService:
    def __init__(self, store: SQLiteCoordinatorStore) -> None:
        self.store = store
        self.locks = GlobalLockManager(store)

    def create_task(
        self,
        spec: TaskSpec,
        context_payload: Mapping[str, Any],
        *,
        dependencies: Sequence[str] = (),
    ) -> TaskRun:
        self.store.create_task_spec(spec)
        self.store.create_context(
            Context(
                context_id=spec.context_id,
                task_id=spec.task_id,
                project_id=spec.project_id,
                payload=dict(context_payload),
            )
        )
        for dependency_id in dependencies:
            self.store.add_dependency(spec.task_id, dependency_id)
        return self.store.create_run(spec.task_id)

    def start(
        self,
        run_id: str,
        *,
        owner_id: str,
        lease_seconds: int = 60,
        now: datetime | None = None,
    ) -> Lease:
        current_time = now or utc_now()
        run = self.store.get_run(run_id)
        spec = self.store.get_task_spec(run.task_id)
        lease = self.locks.acquire(
            owner_id, run_id, lease_seconds=lease_seconds, now=current_time
        )
        try:
            if self.store.has_active_or_review_run(except_run_id=run_id):
                raise QueueBlockedError("Another task is RUNNING or awaiting REVIEW")
            if self.store.has_queue_blocker(except_run_id=run_id):
                raise QueueBlockedError("A BLOCKED task prevents queue continuation")
            self.store.assert_dependencies_satisfied(spec.task_id)
            unavailable = [
                resource_id
                for resource_id in spec.required_resources
                if not self.store.resource_available(resource_id, now=current_time)
            ]
            if unavailable:
                raise ResourceCooldownError(
                    f"Resources remain in cooldown: {', '.join(sorted(unavailable))}"
                )
            self.store.transition_run(
                run_id,
                TaskState.RUNNING,
                lease,
                actor=owner_id,
                reason="execution_started",
                now=current_time,
            )
            return lease
        except BaseException:
            self.locks.release(lease, now=current_time)
            raise

    def complete_execution(
        self,
        run_id: str,
        lease: Lease,
        *,
        used_resources: Sequence[str] = (),
        now: datetime | None = None,
    ) -> TaskRun:
        current_time = now or utc_now()
        run = self.store.transition_run(
            run_id,
            TaskState.REVIEW,
            lease,
            actor=lease.owner_id,
            reason="execution_completed",
            now=current_time,
        )
        self.store.activate_cooldowns(used_resources, lease, now=current_time)
        return run

    def accept_review(
        self,
        run_id: str,
        lease: Lease,
        *,
        committer: Committer,
        staged_paths: Sequence[str],
        microaudit: Mapping[str, Any],
        now: datetime | None = None,
    ) -> tuple[TaskRun, str]:
        current_time = now or utc_now()
        run = self.store.get_run(run_id)
        if run.state is not TaskState.REVIEW:
            raise ValueError("Only a REVIEW task can be accepted")
        if not bool(microaudit.get("passed")):
            raise ValueError("Microaudit must pass before a task is accepted")
        spec = self.store.get_task_spec(run.task_id)
        audit_evidence = self.store.append_evidence(
            run_id, "microaudit", dict(microaudit), lease, now=current_time
        )
        staged = tuple(sorted(set(staged_paths)))
        self.store.append_evidence(
            run_id,
            "selective_staging",
            {"paths": staged, "inspected": True},
            lease,
            now=current_time,
        )
        commit_sha = committer.create_local_commit(spec, staged, audit_evidence.digest)
        self.store.append_evidence(
            run_id,
            "local_commit",
            {"sha": commit_sha, "message": spec.commit_message},
            lease,
            now=current_time,
        )
        accepted = self.store.transition_run(
            run_id,
            TaskState.DONE,
            lease,
            actor=lease.owner_id,
            reason="microaudit_approved_and_local_commit_recorded",
            now=current_time,
        )
        self.locks.release(lease, now=current_time)
        return accepted, commit_sha

    def fail(
        self,
        run_id: str,
        lease: Lease,
        *,
        resource_id: str,
        details: Mapping[str, Any],
        used_resources: Sequence[str] = (),
        now: datetime | None = None,
    ) -> tuple[int, TaskRun]:
        current_time = now or utc_now()
        attempt, run = self.store.record_failure(
            run_id,
            resource_id,
            details,
            lease,
            actor=lease.owner_id,
            now=current_time,
        )
        self.store.activate_cooldowns(used_resources, lease, now=current_time)
        self.locks.release(lease, now=current_time)
        return attempt, run

    def cancel(
        self,
        run_id: str,
        lease: Lease,
        *,
        used_resources: Sequence[str] = (),
        reason: str = "cancelled_by_authority",
        now: datetime | None = None,
    ) -> TaskRun:
        current_time = now or utc_now()
        cancelled = self.store.transition_run(
            run_id,
            TaskState.CANCELLED,
            lease,
            actor=lease.owner_id,
            reason=reason,
            now=current_time,
        )
        self.store.activate_cooldowns(used_resources, lease, now=current_time)
        self.locks.release(lease, now=current_time)
        return cancelled

    def authorize_retry(
        self,
        run_id: str,
        *,
        owner_id: str,
        authorization: str,
        now: datetime | None = None,
    ) -> TaskRun:
        if not authorization.strip():
            raise PermissionError("Retry requires explicit authorization evidence")
        current_time = now or utc_now()
        lease = self.locks.acquire(owner_id, run_id, now=current_time)
        try:
            self.store.append_evidence(
                run_id,
                "retry_authorization",
                {"authorization": authorization},
                lease,
                now=current_time,
            )
            return self.store.transition_run(
                run_id,
                TaskState.ASSIGNED,
                lease,
                actor=owner_id,
                reason="retry_authorized",
                now=current_time,
            )
        finally:
            self.locks.release(lease, now=current_time)

    @staticmethod
    def evidence_digest(payload: Mapping[str, Any]) -> str:
        material = json.dumps(payload, sort_keys=True, separators=(",", ":")).encode()
        return hashlib.sha256(material).hexdigest()
