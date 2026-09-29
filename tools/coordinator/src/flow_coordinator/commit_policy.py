"""Commit acceptance port and an in-memory fake for this delivery."""

from __future__ import annotations

import hashlib
from dataclasses import dataclass, field
from typing import Protocol

from .domain import TaskSpec


class CommitPolicyError(RuntimeError):
    pass


class Committer(Protocol):
    def create_local_commit(
        self, spec: TaskSpec, staged_paths: tuple[str, ...], evidence_digest: str
    ) -> str: ...


@dataclass(slots=True)
class FakeCommitter:
    """Tests commit policy without touching a repository."""

    commits: list[dict[str, object]] = field(default_factory=list)

    def create_local_commit(
        self, spec: TaskSpec, staged_paths: tuple[str, ...], evidence_digest: str
    ) -> str:
        allowed = set(spec.allowed_paths)
        protected = set(spec.protected_paths)
        requested = set(staged_paths)
        if not requested:
            raise CommitPolicyError("An accepted task must stage at least one authorized file")
        if requested - allowed:
            raise CommitPolicyError(
                f"Staging contains unauthorized paths: {sorted(requested - allowed)}"
            )
        if requested & protected:
            raise CommitPolicyError(
                f"Staging contains protected paths: {sorted(requested & protected)}"
            )
        material = "\n".join(
            [spec.task_id, spec.commit_message, evidence_digest, *sorted(requested)]
        ).encode("utf-8")
        commit_sha = hashlib.sha1(material, usedforsecurity=False).hexdigest()
        self.commits.append(
            {
                "task_id": spec.task_id,
                "message": spec.commit_message,
                "paths": tuple(sorted(requested)),
                "sha": commit_sha,
            }
        )
        return commit_sha
