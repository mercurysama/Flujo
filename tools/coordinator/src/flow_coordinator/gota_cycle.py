"""One state-free Worker -> Git verification -> Reviewer cycle."""

from __future__ import annotations

import json
from dataclasses import dataclass, replace
from enum import StrEnum
from pathlib import Path
from typing import Protocol

from .git_adapter import GitReadError, ReadOnlyGitAdapter
from .gota_protocol import (
    GotaPhase,
    GotaRequest,
    GotaReviewResult,
    GotaWorkerResult,
    ReviewDecision,
    WorkerResultStatus,
)
from .opencode_runner import (
    OpenCodeRunResult,
    OpenCodeRunStatus,
    OpenCodeStartFailure,
)


class GotaCycleRunner(Protocol):
    def run(
        self,
        *,
        agent: str,
        prompt: str,
        cwd: str | Path,
        timeout: float,
    ) -> OpenCodeRunResult: ...


class GotaCyclePhase(StrEnum):
    INITIAL_GIT = "initial_git"
    WORKER_EXECUTION = "worker_execution"
    WORKER_RESULT = "worker_result"
    WORKER_GIT_VERIFICATION = "worker_git_verification"
    REVIEWER_EXECUTION = "reviewer_execution"
    REVIEWER_RESULT = "reviewer_result"
    REVIEWER_INTEGRITY = "reviewer_integrity"
    COMPLETED = "completed"


class GotaCycleFailure(StrEnum):
    REQUEST_INVALID = "request_invalid"
    WORKSPACE_MISMATCH = "workspace_mismatch"
    INITIAL_GIT_FAILURE = "initial_git_failure"
    INITIAL_BASE_MISMATCH = "initial_base_mismatch"
    INITIAL_BRANCH_MISMATCH = "initial_branch_mismatch"
    INITIAL_WORKTREE_DIRTY = "initial_worktree_dirty"
    WORKER_TIMEOUT = "worker_timeout"
    WORKER_CONTAINMENT_FAILURE = "worker_containment_failure"
    WORKER_STARTUP_FAILURE = "worker_startup_failure"
    WORKER_NON_ZERO_EXIT = "worker_non_zero_exit"
    WORKER_INVALID_PAYLOAD = "worker_invalid_payload"
    WORKER_RESULT_INVALID = "worker_result_invalid"
    WORKER_COMMIT_NOT_FOUND = "worker_commit_not_found"
    WORKER_COMMIT_INVALID = "worker_commit_invalid"
    WORKER_HEAD_MISMATCH = "worker_head_mismatch"
    WORKER_BRANCH_CHANGED = "worker_branch_changed"
    WORKER_WORKTREE_DIRTY = "worker_worktree_dirty"
    WORKER_NOT_DESCENDANT = "worker_commit_not_descendant"
    WORKER_NO_COMMIT = "worker_no_commit"
    WORKER_MULTIPLE_COMMITS = "worker_multiple_commits"
    WORKER_GIT_FAILURE = "worker_git_failure"
    WORKER_CHANGED_PATHS_MISMATCH = "worker_changed_paths_mismatch"
    REVIEWER_TIMEOUT = "reviewer_timeout"
    REVIEWER_CONTAINMENT_FAILURE = "reviewer_containment_failure"
    REVIEWER_STARTUP_FAILURE = "reviewer_startup_failure"
    REVIEWER_NON_ZERO_EXIT = "reviewer_non_zero_exit"
    REVIEWER_INVALID_PAYLOAD = "reviewer_invalid_payload"
    REVIEWER_RESULT_INVALID = "reviewer_result_invalid"
    REVIEWER_COMMIT_MISMATCH = "reviewer_commit_mismatch"
    REVIEWER_HEAD_CHANGED = "reviewer_head_changed"
    REVIEWER_BRANCH_CHANGED = "reviewer_branch_changed"
    REVIEWER_WORKTREE_DIRTY = "reviewer_worktree_dirty"
    REVIEWER_REFS_CHANGED = "reviewer_refs_changed"
    REVIEWER_GIT_FAILURE = "reviewer_git_failure"


@dataclass(frozen=True, slots=True)
class GotaReviewCycleResult:
    """Validated output of one Worker -> Reviewer pass."""

    base_sha: str
    branch: str
    worker_execution: OpenCodeRunResult | None
    worker_payload: GotaWorkerResult | None
    verified_commit_sha: str | None
    verified_changed_paths: tuple[str, ...]
    reviewer_execution: OpenCodeRunResult | None
    review_result: GotaReviewResult | None
    phase: GotaCyclePhase
    failure: GotaCycleFailure | None
    diagnostic: str

    @property
    def valid(self) -> bool:
        return self.failure is None and self.review_result is not None

    @property
    def decision(self) -> ReviewDecision | None:
        if self.failure is not None or self.review_result is None:
            return None
        return self.review_result.decision


class GotaReviewCycle:
    """Run exactly one Worker, read-only Git audit, and Reviewer phase."""

    WORKER_AGENT = "gota-worker"
    REVIEWER_AGENT = "gota-reviewer"

    def __init__(self, repository: str | Path, *, runner: GotaCycleRunner) -> None:
        self.repository = Path(repository).resolve()
        self.runner = runner

    @staticmethod
    def _request_json(request: GotaRequest) -> str:
        return json.dumps(
            request.to_payload(),
            ensure_ascii=False,
            sort_keys=True,
            separators=(",", ":"),
        )

    @classmethod
    def _worker_prompt(cls, request: GotaRequest) -> str:
        return (
            "Execute the flujo.gota/v1 worker phase for this request.\n"
            "Implement the objective and create at most one local commit on the "
            "requested branch. Do not push or merge.\n"
            "Return exactly one validated worker.result payload framed by the "
            "flujo.gota/v1 delimiters.\n"
            "Request JSON:\n"
            f"{cls._request_json(request)}"
        )

    @classmethod
    def _reviewer_prompt(
        cls,
        request: GotaRequest,
        verified_commit_sha: str,
        changed_paths: tuple[str, ...],
    ) -> str:
        review_request = replace(
            request,
            request_id=f"{request.run_id}:{request.attempt}:review",
            phase=GotaPhase.REVIEW,
            previous_findings=(),
        )
        return (
            "Audit exactly the verified commit identified below using the "
            "flujo.gota/v1 review phase.\n"
            f"base SHA: {request.base_sha}\n"
            f"verified commit SHA: {verified_commit_sha}\n"
            f"task ID: {request.task_id}\n"
            f"run ID: {request.run_id}\n"
            f"request ID: {review_request.request_id}\n"
            f"verified changed paths: {json.dumps(changed_paths)}\n"
            "This is a read-only review. Do not modify files, create commits, "
            "push, merge, checkout, reset, or otherwise change Git or the "
            "working tree. Review that exact commit, not the current branch tip "
            "by inference.\n"
            "Return exactly one validated review.result payload framed by the "
            "flujo.gota/v1 delimiters.\n"
            "Review request JSON:\n"
            f"{cls._request_json(review_request)}"
        )

    @staticmethod
    def _identity_matches(
        request: GotaRequest,
        request_id: str,
        task_id: str,
        run_id: str,
        attempt: int,
    ) -> bool:
        return (
            request.request_id == request_id
            and request.task_id == task_id
            and request.run_id == run_id
            and request.attempt == attempt
        )

    @staticmethod
    def _worker_runner_failure(
        execution: OpenCodeRunResult,
    ) -> tuple[GotaCycleFailure, str] | None:
        detail = execution.error or execution.status.value
        if execution.status is OpenCodeRunStatus.TIMEOUT:
            return GotaCycleFailure.WORKER_TIMEOUT, f"Worker runner timeout: {detail}"
        if execution.status is OpenCodeRunStatus.START_FAILED:
            if execution.start_failure is OpenCodeStartFailure.CONTAINMENT_UNAVAILABLE:
                return (
                    GotaCycleFailure.WORKER_CONTAINMENT_FAILURE,
                    f"Worker runner containment failure: {detail}",
                )
            return GotaCycleFailure.WORKER_STARTUP_FAILURE, (
                f"Worker runner startup failure: {detail}"
            )
        if execution.status is OpenCodeRunStatus.NON_ZERO_EXIT:
            return (
                GotaCycleFailure.WORKER_NON_ZERO_EXIT,
                f"Worker runner exit failure: {detail}",
            )
        if execution.status is OpenCodeRunStatus.INVALID_PAYLOAD:
            return (
                GotaCycleFailure.WORKER_INVALID_PAYLOAD,
                f"Worker flujo.gota/v1 payload invalid: {detail}",
            )
        return None

    @staticmethod
    def _reviewer_runner_failure(
        execution: OpenCodeRunResult,
    ) -> tuple[GotaCycleFailure, str] | None:
        detail = execution.error or execution.status.value
        if execution.status is OpenCodeRunStatus.TIMEOUT:
            return GotaCycleFailure.REVIEWER_TIMEOUT, (
                f"Reviewer runner timeout: {detail}"
            )
        if execution.status is OpenCodeRunStatus.START_FAILED:
            if execution.start_failure is OpenCodeStartFailure.CONTAINMENT_UNAVAILABLE:
                return (
                    GotaCycleFailure.REVIEWER_CONTAINMENT_FAILURE,
                    f"Reviewer runner containment failure: {detail}",
                )
            return GotaCycleFailure.REVIEWER_STARTUP_FAILURE, (
                f"Reviewer runner startup failure: {detail}"
            )
        if execution.status is OpenCodeRunStatus.NON_ZERO_EXIT:
            return (
                GotaCycleFailure.REVIEWER_NON_ZERO_EXIT,
                f"Reviewer runner exit failure: {detail}",
            )
        if execution.status is OpenCodeRunStatus.INVALID_PAYLOAD:
            return (
                GotaCycleFailure.REVIEWER_INVALID_PAYLOAD,
                f"Reviewer flujo.gota/v1 payload invalid: {detail}",
            )
        return None

    def run(self, request: GotaRequest, *, timeout: float) -> GotaReviewCycleResult:
        """Execute one cycle without changing TaskRun, SQLite, or Git itself."""

        base_sha = ""
        branch = ""
        worker_execution: OpenCodeRunResult | None = None
        worker_payload: GotaWorkerResult | None = None
        verified_commit_sha: str | None = None
        verified_changed_paths: tuple[str, ...] = ()
        reviewer_execution: OpenCodeRunResult | None = None
        review_result: GotaReviewResult | None = None

        def failure(
            phase: GotaCyclePhase,
            reason: GotaCycleFailure,
            diagnostic: str,
        ) -> GotaReviewCycleResult:
            return GotaReviewCycleResult(
                base_sha=base_sha,
                branch=branch,
                worker_execution=worker_execution,
                worker_payload=worker_payload,
                verified_commit_sha=verified_commit_sha,
                verified_changed_paths=verified_changed_paths,
                reviewer_execution=reviewer_execution,
                review_result=review_result,
                phase=phase,
                failure=reason,
                diagnostic=diagnostic,
            )

        if request.phase is not GotaPhase.WORKER:
            return failure(
                GotaCyclePhase.INITIAL_GIT,
                GotaCycleFailure.REQUEST_INVALID,
                "GotaReviewCycle requires a worker-phase GotaRequest",
            )

        try:
            git = ReadOnlyGitAdapter(self.repository)
            initial = git.snapshot()
        except GitReadError as error:
            return failure(
                GotaCyclePhase.INITIAL_GIT,
                GotaCycleFailure.INITIAL_GIT_FAILURE,
                f"Initial Git inspection failed: {error}",
            )

        base_sha = initial.head
        branch = initial.branch
        if Path(request.workspace).resolve() != self.repository:
            return failure(
                GotaCyclePhase.INITIAL_GIT,
                GotaCycleFailure.WORKSPACE_MISMATCH,
                "Gota request workspace does not match the cycle repository",
            )
        if request.base_sha != base_sha:
            return failure(
                GotaCyclePhase.INITIAL_GIT,
                GotaCycleFailure.INITIAL_BASE_MISMATCH,
                f"Request base SHA {request.base_sha} differs from Git HEAD {base_sha}",
            )
        if request.branch != branch:
            return failure(
                GotaCyclePhase.INITIAL_GIT,
                GotaCycleFailure.INITIAL_BRANCH_MISMATCH,
                f"Request branch {request.branch} differs from Git branch {branch}",
            )
        if initial.status:
            return failure(
                GotaCyclePhase.INITIAL_GIT,
                GotaCycleFailure.INITIAL_WORKTREE_DIRTY,
                f"Initial worktree is not clean: {initial.status}",
            )

        worker_execution = self.runner.run(
            agent=self.WORKER_AGENT,
            prompt=self._worker_prompt(request),
            cwd=self.repository,
            timeout=timeout,
        )
        runner_failure = self._worker_runner_failure(worker_execution)
        if runner_failure is not None:
            return failure(GotaCyclePhase.WORKER_EXECUTION, *runner_failure)
        if (
            worker_execution.status is OpenCodeRunStatus.SUCCEEDED
            and worker_execution.exit_code != 0
        ):
            return failure(
                GotaCyclePhase.WORKER_EXECUTION,
                GotaCycleFailure.WORKER_NON_ZERO_EXIT,
                "Worker runner reported SUCCEEDED with exit code "
                f"{worker_execution.exit_code!r}",
            )
        if worker_execution.status is not OpenCodeRunStatus.SUCCEEDED:
            return failure(
                GotaCyclePhase.WORKER_EXECUTION,
                GotaCycleFailure.WORKER_RESULT_INVALID,
                f"Unexpected Worker runner status: {worker_execution.status.value}",
            )
        if not isinstance(worker_execution.payload, GotaWorkerResult):
            return failure(
                GotaCyclePhase.WORKER_RESULT,
                GotaCycleFailure.WORKER_RESULT_INVALID,
                "Worker runner succeeded without a WorkerResult payload",
            )

        worker_payload = worker_execution.payload
        if not self._identity_matches(
            request,
            worker_payload.request_id,
            worker_payload.task_id,
            worker_payload.run_id,
            worker_payload.attempt,
        ) or worker_payload.result is not WorkerResultStatus.READY_FOR_REVIEW:
            return failure(
                GotaCyclePhase.WORKER_RESULT,
                GotaCycleFailure.WORKER_RESULT_INVALID,
                "WorkerResult identity or result is not valid for this cycle",
            )

        try:
            after_worker = git.snapshot()
        except GitReadError as error:
            return failure(
                GotaCyclePhase.WORKER_GIT_VERIFICATION,
                GotaCycleFailure.WORKER_GIT_FAILURE,
                f"Worker Git inspection failed: {error}",
            )
        if after_worker.branch != branch:
            return failure(
                GotaCyclePhase.WORKER_GIT_VERIFICATION,
                GotaCycleFailure.WORKER_BRANCH_CHANGED,
                f"Worker changed branch from {branch} to {after_worker.branch}",
            )
        if after_worker.status:
            return failure(
                GotaCyclePhase.WORKER_GIT_VERIFICATION,
                GotaCycleFailure.WORKER_WORKTREE_DIRTY,
                f"Worker left a dirty worktree: {after_worker.status}",
            )
        try:
            object_type = git.object_type(worker_payload.commit_sha)
        except GitReadError:
            return failure(
                GotaCyclePhase.WORKER_GIT_VERIFICATION,
                GotaCycleFailure.WORKER_COMMIT_NOT_FOUND,
                f"Worker declared a SHA that does not exist: {worker_payload.commit_sha}",
            )
        if object_type != "commit":
            return failure(
                GotaCyclePhase.WORKER_GIT_VERIFICATION,
                GotaCycleFailure.WORKER_COMMIT_INVALID,
                f"Worker declared a Git object of type {object_type}, not a commit",
            )
        if after_worker.head != worker_payload.commit_sha:
            return failure(
                GotaCyclePhase.WORKER_GIT_VERIFICATION,
                GotaCycleFailure.WORKER_HEAD_MISMATCH,
                f"Worker declared {worker_payload.commit_sha}, observed HEAD {after_worker.head}",
            )
        try:
            if not git.is_ancestor(base_sha, worker_payload.commit_sha):
                return failure(
                    GotaCyclePhase.WORKER_GIT_VERIFICATION,
                    GotaCycleFailure.WORKER_NOT_DESCENDANT,
                    f"Worker commit {worker_payload.commit_sha} does not descend from {base_sha}",
                )
            commit_count = git.commit_count_between(
                base_sha, worker_payload.commit_sha
            )
        except GitReadError as error:
            return failure(
                GotaCyclePhase.WORKER_GIT_VERIFICATION,
                GotaCycleFailure.WORKER_GIT_FAILURE,
                f"Worker commit ancestry inspection failed: {error}",
            )
        if commit_count == 0:
            return failure(
                GotaCyclePhase.WORKER_GIT_VERIFICATION,
                GotaCycleFailure.WORKER_NO_COMMIT,
                "Worker did not produce a commit after the captured base",
            )
        if commit_count > 1:
            return failure(
                GotaCyclePhase.WORKER_GIT_VERIFICATION,
                GotaCycleFailure.WORKER_MULTIPLE_COMMITS,
                f"Worker produced {commit_count} commits; exactly one is allowed",
            )
        try:
            verified_changed_paths = git.changed_paths(
                base_sha, worker_payload.commit_sha
            )
        except GitReadError as error:
            return failure(
                GotaCyclePhase.WORKER_GIT_VERIFICATION,
                GotaCycleFailure.WORKER_GIT_FAILURE,
                f"Worker changed-path inspection failed: {error}",
            )
        declared_paths = tuple(sorted(worker_payload.changed_paths))
        if declared_paths != verified_changed_paths:
            return failure(
                GotaCyclePhase.WORKER_GIT_VERIFICATION,
                GotaCycleFailure.WORKER_CHANGED_PATHS_MISMATCH,
                "Worker changed_paths differ from the independent Git diff: "
                f"declared={declared_paths!r}, actual={verified_changed_paths!r}",
            )

        verified_commit_sha = worker_payload.commit_sha
        review_request = replace(
            request,
            request_id=f"{request.run_id}:{request.attempt}:review",
            phase=GotaPhase.REVIEW,
            previous_findings=(),
        )
        try:
            before_reviewer = git.snapshot()
        except GitReadError as error:
            return failure(
                GotaCyclePhase.REVIEWER_INTEGRITY,
                GotaCycleFailure.REVIEWER_GIT_FAILURE,
                f"Pre-review Git inspection failed: {error}",
            )
        reviewer_execution = self.runner.run(
            agent=self.REVIEWER_AGENT,
            prompt=self._reviewer_prompt(
                request, worker_payload.commit_sha, verified_changed_paths
            ),
            cwd=self.repository,
            timeout=timeout,
        )
        try:
            after_reviewer = git.snapshot()
        except GitReadError as error:
            return failure(
                GotaCyclePhase.REVIEWER_INTEGRITY,
                GotaCycleFailure.REVIEWER_GIT_FAILURE,
                f"Reviewer Git inspection failed: {error}",
            )
        if after_reviewer.head != verified_commit_sha:
            return failure(
                GotaCyclePhase.REVIEWER_INTEGRITY,
                GotaCycleFailure.REVIEWER_HEAD_CHANGED,
                f"Reviewer changed HEAD from {verified_commit_sha} to {after_reviewer.head}",
            )
        if after_reviewer.branch != branch:
            return failure(
                GotaCyclePhase.REVIEWER_INTEGRITY,
                GotaCycleFailure.REVIEWER_BRANCH_CHANGED,
                f"Reviewer changed branch from {branch} to {after_reviewer.branch}",
            )
        if after_reviewer.status:
            return failure(
                GotaCyclePhase.REVIEWER_INTEGRITY,
                GotaCycleFailure.REVIEWER_WORKTREE_DIRTY,
                f"Reviewer left a dirty worktree: {after_reviewer.status}",
            )
        if after_reviewer.refs != before_reviewer.refs:
            return failure(
                GotaCyclePhase.REVIEWER_INTEGRITY,
                GotaCycleFailure.REVIEWER_REFS_CHANGED,
                "Reviewer mutated Git refs: "
                f"before={before_reviewer.refs!r}, after={after_reviewer.refs!r}",
            )

        runner_failure = self._reviewer_runner_failure(reviewer_execution)
        if runner_failure is not None:
            return failure(GotaCyclePhase.REVIEWER_EXECUTION, *runner_failure)
        if (
            reviewer_execution.status is OpenCodeRunStatus.SUCCEEDED
            and reviewer_execution.exit_code != 0
        ):
            return failure(
                GotaCyclePhase.REVIEWER_EXECUTION,
                GotaCycleFailure.REVIEWER_NON_ZERO_EXIT,
                "Reviewer runner reported SUCCEEDED with exit code "
                f"{reviewer_execution.exit_code!r}",
            )
        if reviewer_execution.status is not OpenCodeRunStatus.SUCCEEDED:
            return failure(
                GotaCyclePhase.REVIEWER_EXECUTION,
                GotaCycleFailure.REVIEWER_RESULT_INVALID,
                f"Unexpected Reviewer runner status: {reviewer_execution.status.value}",
            )
        if not isinstance(reviewer_execution.payload, GotaReviewResult):
            return failure(
                GotaCyclePhase.REVIEWER_RESULT,
                GotaCycleFailure.REVIEWER_RESULT_INVALID,
                "Reviewer runner succeeded without a ReviewResult payload",
            )

        review_result = reviewer_execution.payload
        if not self._identity_matches(
            review_request,
            review_result.request_id,
            review_result.task_id,
            review_result.run_id,
            review_result.attempt,
        ):
            return failure(
                GotaCyclePhase.REVIEWER_RESULT,
                GotaCycleFailure.REVIEWER_RESULT_INVALID,
                "ReviewResult identity is not valid for this cycle",
            )
        if review_result.reviewed_commit_sha != verified_commit_sha:
            return failure(
                GotaCyclePhase.REVIEWER_RESULT,
                GotaCycleFailure.REVIEWER_COMMIT_MISMATCH,
                "ReviewResult does not identify the verified Worker commit",
            )

        return GotaReviewCycleResult(
            base_sha=base_sha,
            branch=branch,
            worker_execution=worker_execution,
            worker_payload=worker_payload,
            verified_commit_sha=verified_commit_sha,
            verified_changed_paths=verified_changed_paths,
            reviewer_execution=reviewer_execution,
            review_result=review_result,
            phase=GotaCyclePhase.COMPLETED,
            failure=None,
            diagnostic="Worker commit independently verified and Reviewer result validated",
        )


__all__ = [
    "GotaCycleFailure",
    "GotaCyclePhase",
    "GotaCycleRunner",
    "GotaReviewCycle",
    "GotaReviewCycleResult",
]
