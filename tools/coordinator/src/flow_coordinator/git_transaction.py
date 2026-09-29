"""Recoverable, selectively staged Git acceptance for authorized repositories."""

from __future__ import annotations

import hashlib
import subprocess
from collections.abc import Callable, Mapping, Sequence
from dataclasses import dataclass
from datetime import datetime
from enum import StrEnum
from pathlib import Path, PurePosixPath
from typing import Any

from .domain import Evidence, Lease, TaskRun, TaskSpec, TaskState, utc_now
from .lock import GlobalLockManager
from .store import SQLiteCoordinatorStore


class GitMutationError(RuntimeError):
    pass


class MutationBoundaryError(GitMutationError):
    pass


class ProtectedPathError(GitMutationError):
    pass


class UnauthorizedPathError(GitMutationError):
    pass


class AmbiguousRepositoryError(GitMutationError):
    pass


class UnexpectedHeadError(GitMutationError):
    pass


class UnexpectedBranchError(GitMutationError):
    pass


class CommitParentMismatchError(GitMutationError):
    pass


class CommitOwnershipError(GitMutationError):
    pass


class CommitManifestMismatchError(GitMutationError):
    pass


class RecoveryEvidenceError(GitMutationError):
    pass


class GitAcceptancePhase(StrEnum):
    REVIEW_VERIFIED = "review_verified"
    STAGED = "staged"
    COMMIT_CREATED = "commit_created"
    COMMIT_RECORDED = "commit_recorded"


@dataclass(frozen=True, slots=True)
class StagingManifest:
    parent_sha: str
    paths: tuple[str, ...]
    diff_sha256: str
    index_entries_sha256: str

    def to_payload(self) -> dict[str, Any]:
        return {
            "parent_sha": self.parent_sha,
            "paths": list(self.paths),
            "diff_sha256": self.diff_sha256,
            "index_entries_sha256": self.index_entries_sha256,
        }

    @classmethod
    def from_payload(cls, payload: Mapping[str, Any]) -> "StagingManifest":
        return cls(
            parent_sha=str(payload["parent_sha"]),
            paths=tuple(str(path) for path in payload["paths"]),
            diff_sha256=str(payload["diff_sha256"]),
            index_entries_sha256=str(payload["index_entries_sha256"]),
        )


@dataclass(frozen=True, slots=True)
class VerifiedCommit:
    sha: str
    parent_sha: str
    task_id: str
    run_id: str
    manifest: StagingManifest


class TransactionalGitAdapter:
    """The only mutable Git boundary; callers must provide an authorized root."""

    _READ_COMMANDS = frozenset(
        {"diff", "ls-files", "rev-parse", "rev-list", "show", "status"}
    )
    _WRITE_COMMANDS = frozenset({"add", "commit"})

    def __init__(self, repository: str | Path, *, authorized_root: str | Path) -> None:
        self.repository = Path(repository).resolve()
        self.authorized_root = Path(authorized_root).resolve()
        try:
            self.repository.relative_to(self.authorized_root)
        except ValueError as error:
            raise MutationBoundaryError(
                f"Repository {self.repository} is outside authorized root {self.authorized_root}"
            ) from error
        if self.repository == self.authorized_root:
            raise MutationBoundaryError("Authorized root must contain, not equal, the repository")
        if not (self.repository / ".git").exists():
            raise MutationBoundaryError(f"Not an authorized Git repository: {self.repository}")

    def _run_bytes(self, *arguments: str, mutable: bool = False) -> bytes:
        if not arguments:
            raise GitMutationError("A Git subcommand is required")
        allowed = self._WRITE_COMMANDS if mutable else self._READ_COMMANDS
        if arguments[0] not in allowed:
            raise GitMutationError(
                f"Git subcommand is outside the {'mutable' if mutable else 'read-only'} boundary: {arguments[0]}"
            )
        command = (
            ("git", "-c", "core.hooksPath=/dev/null", *arguments)
            if mutable
            else ("git", *arguments)
        )
        result = subprocess.run(
            command,
            cwd=self.repository,
            check=False,
            capture_output=True,
        )
        if result.returncode != 0:
            message = result.stderr.decode("utf-8", errors="replace").strip()
            raise GitMutationError(message or f"Git {arguments[0]} failed")
        return result.stdout

    def _run_text(self, *arguments: str, mutable: bool = False) -> str:
        return self._run_bytes(*arguments, mutable=mutable).decode(
            "utf-8", errors="surrogateescape"
        ).rstrip("\n")

    @staticmethod
    def _normalize_paths(paths: Sequence[str]) -> tuple[str, ...]:
        normalized: list[str] = []
        for value in paths:
            path = PurePosixPath(value)
            if not value or path.is_absolute() or ".." in path.parts or value != path.as_posix():
                raise UnauthorizedPathError(f"Git path must be normalized and relative: {value}")
            normalized.append(value)
        result = tuple(sorted(set(normalized)))
        if not result:
            raise UnauthorizedPathError("At least one authorized path is required")
        return result

    @staticmethod
    def _nul_paths(raw: bytes) -> tuple[str, ...]:
        return tuple(
            sorted(
                entry.decode("utf-8", errors="surrogateescape")
                for entry in raw.split(b"\0")
                if entry
            )
        )

    def head(self) -> str:
        return self._run_text("rev-parse", "HEAD")

    def branch(self) -> str:
        return self._run_text("rev-parse", "--abbrev-ref", "HEAD")

    def _cached_paths(self) -> tuple[str, ...]:
        return self._nul_paths(
            self._run_bytes("diff", "--cached", "--name-only", "-z")
        )

    def _unstaged_paths(self) -> tuple[str, ...]:
        tracked = self._nul_paths(self._run_bytes("diff", "--name-only", "-z"))
        untracked = self._nul_paths(
            self._run_bytes("ls-files", "--others", "--exclude-standard", "-z")
        )
        return tuple(sorted(set((*tracked, *untracked))))

    def _validate_requested_paths(
        self, spec: TaskSpec, requested_paths: Sequence[str]
    ) -> tuple[str, ...]:
        requested = self._normalize_paths(requested_paths)
        protected = set(spec.protected_paths)
        allowed = set(spec.allowed_paths)
        if set(requested) & protected:
            raise ProtectedPathError(
                f"Protected paths cannot be staged: {sorted(set(requested) & protected)}"
            )
        if set(requested) - allowed:
            raise UnauthorizedPathError(
                f"Unauthorized paths cannot be staged: {sorted(set(requested) - allowed)}"
            )
        return requested

    def _assert_branch(self, expected_branch: str) -> None:
        branch = self.branch()
        if branch != expected_branch:
            raise UnexpectedBranchError(
                f"Expected branch {expected_branch}, observed {branch}"
            )

    def _manifest_from_index(self, expected_parent: str) -> StagingManifest:
        paths = self._cached_paths()
        patch = self._run_bytes(
            "diff", "--cached", "--binary", "--full-index", "--no-ext-diff"
        )
        entries = self._run_bytes("ls-files", "-s", "-z", "--", *paths)
        return StagingManifest(
            parent_sha=expected_parent,
            paths=paths,
            diff_sha256=hashlib.sha256(patch).hexdigest(),
            index_entries_sha256=hashlib.sha256(entries).hexdigest(),
        )

    def inspect_staging(self, expected_parent: str) -> StagingManifest:
        if self.head() != expected_parent:
            raise UnexpectedHeadError(
                f"Expected HEAD {expected_parent}, observed {self.head()}"
            )
        manifest = self._manifest_from_index(expected_parent)
        if not manifest.paths:
            raise AmbiguousRepositoryError("The Git index is empty")
        return manifest

    def stage_or_reuse(
        self,
        spec: TaskSpec,
        requested_paths: Sequence[str],
        *,
        expected_manifest: StagingManifest | None = None,
        fence_check: Callable[[], None],
    ) -> StagingManifest:
        requested = self._validate_requested_paths(spec, requested_paths)
        self._assert_branch(spec.branch)
        if self.head() != spec.base_sha:
            raise UnexpectedHeadError(
                f"Expected HEAD {spec.base_sha}, observed {self.head()}"
            )
        cached = self._cached_paths()
        unstaged = self._unstaged_paths()
        changed = set((*cached, *unstaged))
        protected_changes = changed & set(spec.protected_paths)
        if protected_changes:
            raise ProtectedPathError(
                f"Protected paths have changes: {sorted(protected_changes)}"
            )
        unrelated = changed - set(requested)
        if unrelated:
            raise AmbiguousRepositoryError(
                f"Repository contains changes outside this task: {sorted(unrelated)}"
            )
        if cached:
            if cached != requested or unstaged:
                raise AmbiguousRepositoryError(
                    "Existing index or worktree content does not match the requested staging set"
                )
            manifest = self._manifest_from_index(spec.base_sha)
        else:
            if expected_manifest is not None:
                raise CommitManifestMismatchError(
                    "Recorded staging is no longer present in the Git index"
                )
            if unstaged != requested:
                raise AmbiguousRepositoryError(
                    f"Requested paths {list(requested)} do not exactly match worktree changes {list(unstaged)}"
                )
            fence_check()
            self._run_bytes("add", "--", *requested, mutable=True)
            if self._unstaged_paths():
                raise AmbiguousRepositoryError(
                    "Worktree still contains unstaged or untracked changes after selective staging"
                )
            manifest = self._manifest_from_index(spec.base_sha)
        if manifest.paths != requested:
            raise AmbiguousRepositoryError(
                f"Staged paths differ from authorization: {list(manifest.paths)}"
            )
        if expected_manifest is not None and manifest != expected_manifest:
            raise CommitManifestMismatchError(
                "Existing staging manifest differs from the recoverable checkpoint"
            )
        return manifest

    def _commit_manifest(self, parent_sha: str, commit_sha: str) -> StagingManifest:
        paths = self._nul_paths(
            self._run_bytes("diff", "--name-only", "-z", parent_sha, commit_sha)
        )
        patch = self._run_bytes(
            "diff",
            "--binary",
            "--full-index",
            "--no-ext-diff",
            parent_sha,
            commit_sha,
        )
        return StagingManifest(
            parent_sha=parent_sha,
            paths=paths,
            diff_sha256=hashlib.sha256(patch).hexdigest(),
            index_entries_sha256="",
        )

    def _commit_parent(self, commit_sha: str) -> str:
        parts = self._run_text("rev-list", "--parents", "-n", "1", commit_sha).split()
        if len(parts) != 2:
            raise CommitParentMismatchError("Accepted task commit must have exactly one parent")
        return parts[1]

    def _trailer(self, commit_sha: str, key: str) -> tuple[str, ...]:
        output = self._run_text(
            "show", "-s", f"--format=%(trailers:key={key},valueonly)", commit_sha
        )
        return tuple(value for value in output.splitlines() if value)

    def verify_existing_commit(
        self,
        spec: TaskSpec,
        run_id: str,
        expected_manifest: StagingManifest,
        *,
        commit_sha: str | None = None,
    ) -> VerifiedCommit:
        self._assert_branch(spec.branch)
        observed_sha = commit_sha or self.head()
        if self.head() != observed_sha:
            raise UnexpectedHeadError(
                f"Expected existing commit at HEAD {observed_sha}, observed {self.head()}"
            )
        task_trailers = self._trailer(observed_sha, "Coordinator-Task-ID")
        run_trailers = self._trailer(observed_sha, "Coordinator-Run-ID")
        if task_trailers != (spec.task_id,) or run_trailers != (run_id,):
            raise CommitOwnershipError(
                "Existing commit belongs to another task or TaskRun"
            )
        subject = self._run_text("show", "-s", "--format=%s", observed_sha)
        if subject != spec.commit_message:
            raise CommitOwnershipError(
                "Existing commit message does not match the accepted task"
            )
        parent_sha = self._commit_parent(observed_sha)
        if parent_sha != spec.base_sha or parent_sha != expected_manifest.parent_sha:
            raise CommitParentMismatchError(
                f"Expected commit parent {spec.base_sha}, observed {parent_sha}"
            )
        committed = self._commit_manifest(parent_sha, observed_sha)
        if (
            committed.paths != expected_manifest.paths
            or committed.diff_sha256 != expected_manifest.diff_sha256
        ):
            raise CommitManifestMismatchError(
                "Existing commit does not match the recorded staging manifest"
            )
        if self._cached_paths():
            raise AmbiguousRepositoryError("Index is not empty after the existing commit")
        return VerifiedCommit(
            sha=observed_sha,
            parent_sha=parent_sha,
            task_id=spec.task_id,
            run_id=run_id,
            manifest=expected_manifest,
        )

    def commit_or_reuse(
        self,
        spec: TaskSpec,
        run_id: str,
        manifest: StagingManifest,
        *,
        fence_check: Callable[[], None],
    ) -> VerifiedCommit:
        current_head = self.head()
        if current_head != spec.base_sha:
            return self.verify_existing_commit(spec, run_id, manifest)
        observed = self.inspect_staging(spec.base_sha)
        if observed != manifest:
            raise CommitManifestMismatchError(
                "Current staging differs from the recorded manifest"
            )
        fence_check()
        trailer_block = (
            f"Coordinator-Task-ID: {spec.task_id}\n"
            f"Coordinator-Run-ID: {run_id}"
        )
        self._run_bytes(
            "commit",
            "--no-gpg-sign",
            "-m",
            spec.commit_message,
            "-m",
            trailer_block,
            mutable=True,
        )
        return self.verify_existing_commit(spec, run_id, manifest)


class GitAcceptanceWorkflow:
    """Idempotent REVIEW-to-DONE Git acceptance workflow."""

    _WORKFLOW = "git_acceptance_v1"
    _PHASE_ORDER = {
        GitAcceptancePhase.REVIEW_VERIFIED: 1,
        GitAcceptancePhase.STAGED: 2,
        GitAcceptancePhase.COMMIT_CREATED: 3,
        GitAcceptancePhase.COMMIT_RECORDED: 4,
    }

    def __init__(self, store: SQLiteCoordinatorStore) -> None:
        self.store = store
        self.locks = GlobalLockManager(store)

    def _latest_checkpoint(self, run_id: str) -> Mapping[str, Any] | None:
        checkpoints = self.store.list_checkpoints(run_id)
        for checkpoint in reversed(checkpoints):
            if checkpoint.payload.get("workflow") == self._WORKFLOW:
                return checkpoint.payload
        return None

    def _workflow_evidence(self, run_id: str, kind: str) -> Evidence | None:
        matches = [
            evidence
            for evidence in self.store.list_evidence(run_id)
            if evidence.kind == kind
            and evidence.payload.get("workflow") == self._WORKFLOW
        ]
        if len(matches) > 1:
            raise RecoveryEvidenceError(
                f"Multiple immutable {kind} records make recovery ambiguous"
            )
        return matches[0] if matches else None

    def _checkpoint_payload(
        self,
        spec: TaskSpec,
        run_id: str,
        phase: GitAcceptancePhase,
        paths: tuple[str, ...],
        *,
        manifest: StagingManifest | None = None,
        commit_sha: str | None = None,
    ) -> dict[str, Any]:
        payload: dict[str, Any] = {
            "workflow": self._WORKFLOW,
            "phase": phase.value,
            "task_id": spec.task_id,
            "run_id": run_id,
            "branch": spec.branch,
            "expected_parent": spec.base_sha,
            "paths": list(paths),
        }
        if manifest is not None:
            payload["manifest"] = manifest.to_payload()
        if commit_sha is not None:
            payload["commit_sha"] = commit_sha
        return payload

    def _validate_checkpoint(
        self,
        checkpoint: Mapping[str, Any],
        spec: TaskSpec,
        run_id: str,
        paths: tuple[str, ...],
    ) -> GitAcceptancePhase:
        expected = {
            "workflow": self._WORKFLOW,
            "task_id": spec.task_id,
            "run_id": run_id,
            "branch": spec.branch,
            "expected_parent": spec.base_sha,
            "paths": list(paths),
        }
        for key, value in expected.items():
            if checkpoint.get(key) != value:
                raise RecoveryEvidenceError(
                    f"Checkpoint field {key} conflicts with current acceptance context"
                )
        try:
            return GitAcceptancePhase(str(checkpoint["phase"]))
        except (KeyError, ValueError) as error:
            raise RecoveryEvidenceError("Checkpoint has an unknown phase") from error

    def _notify(
        self,
        hook: Callable[[GitAcceptancePhase], None] | None,
        phase: GitAcceptancePhase,
    ) -> None:
        if hook is not None:
            hook(phase)

    def accept(
        self,
        run_id: str,
        lease: Lease,
        adapter: TransactionalGitAdapter,
        *,
        staged_paths: Sequence[str],
        microaudit: Mapping[str, Any],
        progress_hook: Callable[[GitAcceptancePhase], None] | None = None,
        now: datetime | None = None,
    ) -> tuple[TaskRun, str]:
        current_time = now or utc_now()
        run = self.store.get_run(run_id)
        if run.state is not TaskState.REVIEW:
            raise RecoveryEvidenceError("Git acceptance requires a REVIEW task")
        if not bool(microaudit.get("passed")):
            raise RecoveryEvidenceError("Microaudit must pass before Git acceptance")
        spec = self.store.get_task_spec(run.task_id)
        paths = TransactionalGitAdapter._normalize_paths(staged_paths)
        self.locks.assert_current(lease, now=current_time)

        checkpoint = self._latest_checkpoint(run_id)
        phase: GitAcceptancePhase | None = None
        manifest: StagingManifest | None = None
        recorded_sha: str | None = None
        if checkpoint is not None:
            phase = self._validate_checkpoint(checkpoint, spec, run_id, paths)
            if "manifest" in checkpoint:
                manifest = StagingManifest.from_payload(checkpoint["manifest"])
            recorded_sha = (
                str(checkpoint["commit_sha"])
                if checkpoint.get("commit_sha") is not None
                else None
            )

        audit = self._workflow_evidence(run_id, "microaudit")
        expected_audit = dict(microaudit)
        expected_audit["workflow"] = self._WORKFLOW
        if audit is None:
            audit = self.store.append_evidence(
                run_id, "microaudit", expected_audit, lease, now=current_time
            )
        elif dict(audit.payload) != expected_audit:
            raise RecoveryEvidenceError(
                "Stored microaudit evidence conflicts with the recovery request"
            )

        if phase is None:
            self.store.append_checkpoint(
                run_id,
                self._checkpoint_payload(
                    spec, run_id, GitAcceptancePhase.REVIEW_VERIFIED, paths
                ),
                lease,
                now=current_time,
            )
            phase = GitAcceptancePhase.REVIEW_VERIFIED
        self._notify(progress_hook, GitAcceptancePhase.REVIEW_VERIFIED)

        staging_evidence = self._workflow_evidence(run_id, "selective_staging")
        if staging_evidence is not None:
            evidence_manifest = StagingManifest.from_payload(
                staging_evidence.payload["manifest"]
            )
            if manifest is not None and manifest != evidence_manifest:
                raise RecoveryEvidenceError(
                    "Staging evidence conflicts with its checkpoint"
                )
            manifest = evidence_manifest

        commit_evidence = self._workflow_evidence(run_id, "local_commit")
        if commit_evidence is not None:
            if staging_evidence is None:
                raise RecoveryEvidenceError(
                    "Commit evidence exists without its staging evidence"
                )
            commit_manifest = StagingManifest.from_payload(
                commit_evidence.payload["manifest"]
            )
            if manifest is not None and manifest != commit_manifest:
                raise RecoveryEvidenceError(
                    "Commit evidence conflicts with the staging manifest"
                )
            manifest = commit_manifest
            evidence_sha = str(commit_evidence.payload.get("sha", ""))
            if recorded_sha is not None and recorded_sha != evidence_sha:
                raise RecoveryEvidenceError(
                    "Commit evidence conflicts with checkpoint SHA"
                )
            recorded_sha = evidence_sha
            if adapter.head() != recorded_sha:
                raise RecoveryEvidenceError(
                    "Repository HEAD conflicts with recorded commit evidence"
                )

        if phase is GitAcceptancePhase.COMMIT_RECORDED and (
            commit_evidence is None or recorded_sha is None
        ):
            raise RecoveryEvidenceError(
                "Commit-recorded checkpoint is missing immutable commit evidence"
            )

        if (
            phase is not None
            and self._PHASE_ORDER[phase] >= self._PHASE_ORDER[GitAcceptancePhase.STAGED]
            and manifest is None
        ):
            raise RecoveryEvidenceError(
                "Staged checkpoint is missing its immutable manifest"
            )

        if adapter.head() == spec.base_sha:
            manifest = adapter.stage_or_reuse(
                spec,
                paths,
                expected_manifest=manifest,
                fence_check=lambda: self.locks.assert_current(
                    lease, now=current_time
                ),
            )
        elif manifest is None:
            raise UnexpectedHeadError(
                "HEAD changed before a recoverable staging manifest was recorded"
            )

        if manifest is None:
            raise RecoveryEvidenceError("Staging did not produce a recoverable manifest")
        if staging_evidence is None:
            self.store.append_evidence(
                run_id,
                "selective_staging",
                {
                    "workflow": self._WORKFLOW,
                    "paths": list(paths),
                    "inspected": True,
                    "manifest": manifest.to_payload(),
                },
                lease,
                now=current_time,
            )
        if phase is GitAcceptancePhase.REVIEW_VERIFIED:
            self.store.append_checkpoint(
                run_id,
                self._checkpoint_payload(
                    spec,
                    run_id,
                    GitAcceptancePhase.STAGED,
                    paths,
                    manifest=manifest,
                ),
                lease,
                now=current_time,
            )
            phase = GitAcceptancePhase.STAGED
        self._notify(progress_hook, GitAcceptancePhase.STAGED)

        verified = adapter.commit_or_reuse(
            spec,
            run_id,
            manifest,
            fence_check=lambda: self.locks.assert_current(lease, now=current_time),
        )
        if recorded_sha is not None and verified.sha != recorded_sha:
            raise RecoveryEvidenceError("Repository HEAD conflicts with recorded commit SHA")
        self._notify(progress_hook, GitAcceptancePhase.COMMIT_CREATED)

        if commit_evidence is None:
            self.store.append_evidence(
                run_id,
                "local_commit",
                {
                    "workflow": self._WORKFLOW,
                    "sha": verified.sha,
                    "parent_sha": verified.parent_sha,
                    "message": spec.commit_message,
                    "manifest": manifest.to_payload(),
                },
                lease,
                now=current_time,
            )
        if phase is not GitAcceptancePhase.COMMIT_RECORDED:
            self.store.append_checkpoint(
                run_id,
                self._checkpoint_payload(
                    spec,
                    run_id,
                    GitAcceptancePhase.COMMIT_RECORDED,
                    paths,
                    manifest=manifest,
                    commit_sha=verified.sha,
                ),
                lease,
                now=current_time,
            )
        self._notify(progress_hook, GitAcceptancePhase.COMMIT_RECORDED)

        accepted = self.store.transition_run(
            run_id,
            TaskState.DONE,
            lease,
            actor=lease.owner_id,
            reason="microaudit_staging_and_local_commit_verified",
            now=current_time,
        )
        self.locks.release(lease, now=current_time)
        return accepted, verified.sha
