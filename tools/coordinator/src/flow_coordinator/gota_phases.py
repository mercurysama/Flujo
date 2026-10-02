"""Reusable, state-free Worker and Reviewer phases for one Gota cycle."""

from __future__ import annotations

import json
from dataclasses import dataclass, fields, replace
from decimal import Decimal
from enum import Enum, StrEnum
from pathlib import Path
from typing import Protocol

from .git_adapter import GitReadError, GitSnapshot, ReadOnlyGitAdapter
from .gota_protocol import (
    GOTA_PROTOCOL,
    GotaCheckpoint,
    GotaFinding,
    GotaPhase,
    GotaMessage,
    GotaProtocolErrorCode,
    GotaRequest,
    GotaReviewResult,
    GotaWorkerResult,
    ReviewDecision,
    WorkerResultStatus,
    parse_gota_payload,
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
class VerifiedWorkerCommit:
    """Immutable handoff from WorkerPhase to ReviewPhase."""

    request: GotaRequest
    repository: Path
    base_sha: str
    branch: str
    verified_commit_sha: str
    verified_changed_paths: tuple[str, ...]
    worker_execution: OpenCodeRunResult
    worker_payload: GotaWorkerResult
    worker_snapshot: GitSnapshot

    def __post_init__(self) -> None:
        object.__setattr__(self, "repository", Path(self.repository).resolve())
        object.__setattr__(
            self,
            "verified_changed_paths",
            tuple(self.verified_changed_paths),
        )

    @property
    def commit_sha(self) -> str:
        return self.verified_commit_sha

    @property
    def changed_paths(self) -> tuple[str, ...]:
        return self.verified_changed_paths

    @property
    def worker_result(self) -> GotaWorkerResult:
        return self.worker_payload

    @property
    def workspace(self) -> str:
        return self.request.workspace

    @property
    def task_id(self) -> str:
        return self.request.task_id

    @property
    def run_id(self) -> str:
        return self.request.run_id

    @property
    def attempt(self) -> int:
        return self.request.attempt


@dataclass(frozen=True, slots=True)
class GitHandoffVerification:
    """Ephemeral result of one read-only Worker commit verification."""

    snapshot: GitSnapshot | None
    changed_paths: tuple[str, ...]
    failure: GotaCycleFailure | None
    diagnostic: str

    @property
    def valid(self) -> bool:
        return self.failure is None and self.snapshot is not None


def _strictly_equal(left: object, right: object) -> bool:
    """Compare canonical values without invoking attacker-controlled equality."""

    if type(left) is not type(right):
        return False
    if left is None:
        return True
    if type(left) is _CANONICAL_PATH_TYPE:
        return _strictly_equal(str(left), str(right))
    if type(left) in (str, bool, int, float, Decimal):
        return left == right
    if isinstance(left, Enum):
        return left is right
    if type(left) is dict:
        assert type(right) is dict
        if len(left) != len(right):
            return False
        unmatched = list(right.items())
        for left_key, left_value in left.items():
            match_index = next(
                (
                    index
                    for index, (right_key, right_value) in enumerate(unmatched)
                    if _strictly_equal(left_key, right_key)
                ),
                None,
            )
            if match_index is None:
                return False
            if not _strictly_equal(left_value, unmatched[match_index][1]):
                return False
            unmatched.pop(match_index)
        return not unmatched
    if type(left) in (list, tuple):
        assert type(right) is type(left)
        if len(left) != len(right):
            return False
        return all(
            _strictly_equal(
                left_item,
                right_item,
            )
            for left_item, right_item in zip(left, right)
        )
    if type(left) in _canonical_dataclass_types():
        return all(
            _strictly_equal(left_item, right_item)
            for field in fields(left)
            for left_item, right_item in (
                (getattr(left, field.name), getattr(right, field.name)),
            )
        )
    return False


_CANONICAL_PATH_TYPE = type(Path())


def _canonical_dataclass_types() -> tuple[type[object], ...]:
    """Return the only dataclass types allowed in authoritative comparisons."""

    return (
        GotaFinding,
        GotaCheckpoint,
        GotaRequest,
        GotaWorkerResult,
        GotaReviewResult,
        OpenCodeRunResult,
        GitSnapshot,
        VerifiedWorkerCommit,
        WorkerPhaseResult,
        ReviewPhaseResult,
    )


def _canonical_text(value: object, *, allow_empty: bool = False) -> bool:
    return type(value) is str and (allow_empty or bool(value.strip()))


def _canonical_sha(value: object) -> bool:
    return (
        type(value) is str
        and len(value) == 40
        and all(character in "0123456789abcdef" for character in value)
    )


def _canonical_enum(value: object, enum_type: type[Enum]) -> bool:
    return type(value) is enum_type and any(value is member for member in enum_type)


def _canonical_text_tuple(value: object, *, allow_empty: bool = False) -> bool:
    return type(value) is tuple and all(
        _canonical_text(item, allow_empty=allow_empty) for item in value
    )


def _canonical_finding_shape(value: object) -> bool:
    if type(value) is not GotaFinding:
        return False
    return (
        type(value.id) is str
        and type(value.severity) is str
        and type(value.description) is str
        and (
            value.path is None
            or type(value.path) is str
        )
        and (
            value.required_change is None
            or type(value.required_change) is str
        )
    )


def _canonical_findings_shape(value: object) -> bool:
    return type(value) is tuple and all(
        _canonical_finding_shape(item) for item in value
    )


def _canonical_evidence(value: object) -> bool:
    """Keep evidence contents opaque, while fixing its protocol container shape."""

    return type(value) is tuple and all(type(item) is dict for item in value)


def _canonical_checkpoint_shape(value: object) -> bool:
    if type(value) is not GotaCheckpoint:
        return False
    return type(value.completed_steps) is tuple and all(
        type(item) is str for item in value.completed_steps
    ) and type(value.remaining_phase) is str


def _canonical_request_shape(value: object) -> bool:
    if type(value) is not GotaRequest:
        return False
    return (
        type(value.protocol) is str
        and type(value.request_id) is str
        and type(value.task_id) is str
        and type(value.run_id) is str
        and type(value.attempt) is int
        and type(value.phase) is GotaPhase
        and type(value.objective) is str
        and type(value.acceptance_criteria) is tuple
        and all(type(item) is str for item in value.acceptance_criteria)
        and type(value.workspace) is str
        and type(value.branch) is str
        and type(value.base_sha) is str
        and type(value.allowed_paths) is tuple
        and all(type(item) is str for item in value.allowed_paths)
        and type(value.protected_paths) is tuple
        and all(type(item) is str for item in value.protected_paths)
        and _canonical_findings_shape(value.previous_findings)
    )


def _canonical_request(value: object) -> bool:
    if not _canonical_request_shape(value):
        return False
    try:
        reparsed = GotaRequest.from_payload(value.to_payload())
    except Exception:
        return False
    return type(reparsed) is GotaRequest and _strictly_equal(reparsed, value)


def _canonical_payload(
    value: object,
    expected_type: type[GotaWorkerResult] | type[GotaReviewResult],
) -> bool:
    if type(value) is not expected_type:
        return False
    if (
        type(value.protocol) is not str
        or type(value.message) is not str
        or type(value.request_id) is not str
        or type(value.task_id) is not str
        or type(value.run_id) is not str
        or type(value.attempt) is not int
        or not _canonical_evidence(value.evidence)
    ):
        return False
    if expected_type is GotaWorkerResult:
        if (
            type(value.result) is not WorkerResultStatus
            or type(value.commit_sha) is not str
            or type(value.changed_paths) is not tuple
            or not all(type(item) is str for item in value.changed_paths)
            or not _canonical_checkpoint_shape(value.checkpoint)
        ):
            return False
    else:
        if (
            type(value.reviewed_commit_sha) is not str
            or type(value.decision) is not ReviewDecision
            or not _canonical_findings_shape(value.findings)
        ):
            return False
    try:
        reparsed = parse_gota_payload(value.to_payload())
    except Exception:
        return False
    return type(reparsed) is expected_type and _strictly_equal(reparsed, value)


def _canonical_execution(
    value: object,
    expected_payload_type: type[GotaWorkerResult] | type[GotaReviewResult],
) -> bool:
    if type(value) is not OpenCodeRunResult:
        return False
    return (
        _canonical_enum(value.status, OpenCodeRunStatus)
        and type(value.argv) is tuple
        and all(type(argument) is str for argument in value.argv)
        and _canonical_text(value.cwd, allow_empty=True)
        and _canonical_text(value.stdout, allow_empty=True)
        and _canonical_text(value.stderr, allow_empty=True)
        and (
            value.exit_code is None
            or type(value.exit_code) is int
        )
        and type(value.timed_out) is bool
        and (
            value.payload is None
            or _canonical_payload(value.payload, expected_payload_type)
        )
        and (
            value.error is None
            or _canonical_text(value.error, allow_empty=True)
        )
        and (
            value.protocol_error_code is None
            or _canonical_enum(value.protocol_error_code, GotaProtocolErrorCode)
        )
        and (
            value.start_failure is None
            or _canonical_enum(value.start_failure, OpenCodeStartFailure)
        )
    )


def _canonical_snapshot(value: object) -> bool:
    if type(value) is not GitSnapshot:
        return False
    return (
        _canonical_text(value.repository)
        and _canonical_sha(value.head)
        and _canonical_text(value.branch)
        and _canonical_text(value.status, allow_empty=True)
        and type(value.refs) is tuple
        and all(
            type(ref) is tuple
            and len(ref) == 3
            and _canonical_text(ref[0])
            and _canonical_text(ref[1])
            and _canonical_text(ref[2], allow_empty=True)
            for ref in value.refs
        )
    )


def validate_successful_execution(
    execution: object,
    expected_payload_type: type[GotaWorkerResult] | type[GotaReviewResult],
    *,
    expected_cwd: Path | None = None,
) -> str | None:
    """Accept an execution only when every success signal is coherent."""

    if not _canonical_execution(execution, expected_payload_type):
        return "execution is not a canonical OpenCodeRunResult"
    if execution.status is not OpenCodeRunStatus.SUCCEEDED:
        return f"status is {execution.status!r}, not succeeded"
    if not _strictly_equal(execution.exit_code, 0):
        return "exit code is not zero"
    if execution.timed_out is not False:
        return "execution is marked as timed out"
    if execution.error is not None:
        return "execution contains an error"
    if execution.protocol_error_code is not None:
        return "execution contains a protocol error"
    if execution.start_failure is not None:
        return "execution contains a startup failure"
    if expected_cwd is not None and not _strictly_equal(
        Path(execution.cwd).resolve(), expected_cwd.resolve()
    ):
        return "execution cwd does not match the expected repository"
    if not _canonical_payload(execution.payload, expected_payload_type):
        return "execution payload has the wrong type"
    try:
        reparsed_payload = parse_gota_payload(execution.payload.to_payload())
    except Exception as error:
        return f"execution payload is internally invalid: {error}"
    if type(reparsed_payload) is not expected_payload_type:
        return "execution payload has the wrong protocol message type"
    if not _strictly_equal(reparsed_payload, execution.payload):
        return "execution payload is internally inconsistent"
    return None


def verify_worker_commit_git(
    git: ReadOnlyGitAdapter,
    *,
    base_sha: str,
    expected_branch: str,
    verified_commit_sha: str,
    worker_changed_paths: tuple[str, ...],
    verified_changed_paths: tuple[str, ...] | None = None,
    expected_snapshot: GitSnapshot | None = None,
) -> GitHandoffVerification:
    """Verify one Worker handoff against the current repository, read-only."""

    invalid_argument_failure = (
        GotaCycleFailure.REVIEWER_GIT_FAILURE
        if expected_snapshot is not None
        else GotaCycleFailure.WORKER_GIT_FAILURE
    )
    if (
        not _canonical_sha(base_sha)
        or not _canonical_text(expected_branch)
        or not _canonical_sha(verified_commit_sha)
        or not _canonical_text_tuple(worker_changed_paths)
        or (
            verified_changed_paths is not None
            and not _canonical_text_tuple(verified_changed_paths)
        )
        or (
            expected_snapshot is not None
            and not _canonical_snapshot(expected_snapshot)
        )
    ):
        return GitHandoffVerification(
            snapshot=None,
            changed_paths=(),
            failure=invalid_argument_failure,
            diagnostic="Git verification received non-canonical authority data",
        )

    try:
        observed = git.snapshot()
    except GitReadError as error:
        return GitHandoffVerification(
            snapshot=None,
            changed_paths=(),
            failure=GotaCycleFailure.WORKER_GIT_FAILURE,
            diagnostic=f"Git snapshot inspection failed: {error}",
        )

    if not _canonical_snapshot(observed):
        return GitHandoffVerification(
            snapshot=None,
            changed_paths=(),
            failure=invalid_argument_failure,
            diagnostic="Git snapshot is not canonical",
        )

    if expected_snapshot is not None:
        if not _strictly_equal(observed.head, expected_snapshot.head):
            return GitHandoffVerification(
                snapshot=observed,
                changed_paths=(),
                failure=GotaCycleFailure.REVIEWER_HEAD_CHANGED,
                diagnostic=(
                    "Git HEAD changed before or after Reviewer: "
                    f"expected {expected_snapshot.head}, observed {observed.head}"
                ),
            )
        if not _strictly_equal(observed.branch, expected_snapshot.branch):
            return GitHandoffVerification(
                snapshot=observed,
                changed_paths=(),
                failure=GotaCycleFailure.REVIEWER_BRANCH_CHANGED,
                diagnostic=(
                    "Git branch changed before or after Reviewer: "
                    f"expected {expected_snapshot.branch}, observed {observed.branch}"
                ),
            )
        if observed.status:
            return GitHandoffVerification(
                snapshot=observed,
                changed_paths=(),
                failure=GotaCycleFailure.REVIEWER_WORKTREE_DIRTY,
                diagnostic=f"Worktree changed before or after Reviewer: {observed.status}",
            )
        if not _strictly_equal(observed.refs, expected_snapshot.refs):
            return GitHandoffVerification(
                snapshot=observed,
                changed_paths=(),
                failure=GotaCycleFailure.REVIEWER_REFS_CHANGED,
                diagnostic=(
                    "Git refs changed before or after Reviewer: "
                    f"expected {expected_snapshot.refs!r}, observed {observed.refs!r}"
                ),
            )

    if expected_snapshot is None and not _strictly_equal(
        observed.branch, expected_branch
    ):
        return GitHandoffVerification(
            snapshot=observed,
            changed_paths=(),
            failure=GotaCycleFailure.WORKER_BRANCH_CHANGED,
            diagnostic=(
                f"Worker branch is {observed.branch}, expected {expected_branch}"
            ),
        )
    if expected_snapshot is None and observed.status:
        return GitHandoffVerification(
            snapshot=observed,
            changed_paths=(),
            failure=GotaCycleFailure.WORKER_WORKTREE_DIRTY,
            diagnostic=f"Worker left a dirty worktree: {observed.status}",
        )

    try:
        base_type = git.object_type(base_sha)
    except GitReadError as error:
        return GitHandoffVerification(
            snapshot=observed,
            changed_paths=(),
            failure=GotaCycleFailure.WORKER_GIT_FAILURE,
            diagnostic=f"Worker base SHA inspection failed: {error}",
        )
    if not _strictly_equal(base_type, "commit"):
        return GitHandoffVerification(
            snapshot=observed,
            changed_paths=(),
            failure=GotaCycleFailure.WORKER_GIT_FAILURE,
            diagnostic=(
                f"Worker base SHA is a Git object of type {base_type}, not a commit"
            ),
        )

    try:
        commit_type = git.object_type(verified_commit_sha)
    except GitReadError:
        return GitHandoffVerification(
            snapshot=observed,
            changed_paths=(),
            failure=GotaCycleFailure.WORKER_COMMIT_NOT_FOUND,
            diagnostic=f"Worker declared a SHA that does not exist: {verified_commit_sha}",
        )
    if not _strictly_equal(commit_type, "commit"):
        return GitHandoffVerification(
            snapshot=observed,
            changed_paths=(),
            failure=GotaCycleFailure.WORKER_COMMIT_INVALID,
            diagnostic=(
                f"Worker declared a Git object of type {commit_type}, not a commit"
            ),
        )

    if not _strictly_equal(observed.head, verified_commit_sha):
        return GitHandoffVerification(
            snapshot=observed,
            changed_paths=(),
            failure=GotaCycleFailure.WORKER_HEAD_MISMATCH,
            diagnostic=(
                f"Worker declared {verified_commit_sha}, observed HEAD {observed.head}"
            ),
        )

    try:
        if not git.is_ancestor(base_sha, verified_commit_sha):
            return GitHandoffVerification(
                snapshot=observed,
                changed_paths=(),
                failure=GotaCycleFailure.WORKER_NOT_DESCENDANT,
                diagnostic=(
                    f"Worker commit {verified_commit_sha} does not descend from {base_sha}"
                ),
            )
        commit_count = git.commit_count_between(base_sha, verified_commit_sha)
    except GitReadError as error:
        return GitHandoffVerification(
            snapshot=observed,
            changed_paths=(),
            failure=GotaCycleFailure.WORKER_GIT_FAILURE,
            diagnostic=f"Worker commit ancestry inspection failed: {error}",
        )
    if type(commit_count) is not int:
        return GitHandoffVerification(
            snapshot=observed,
            changed_paths=(),
            failure=GotaCycleFailure.WORKER_GIT_FAILURE,
            diagnostic="Git returned a non-canonical commit count",
        )
    if _strictly_equal(commit_count, 0):
        return GitHandoffVerification(
            snapshot=observed,
            changed_paths=(),
            failure=GotaCycleFailure.WORKER_NO_COMMIT,
            diagnostic="Worker did not produce a commit after the captured base",
        )
    if commit_count > 1:
        return GitHandoffVerification(
            snapshot=observed,
            changed_paths=(),
            failure=GotaCycleFailure.WORKER_MULTIPLE_COMMITS,
            diagnostic=f"Worker produced {commit_count} commits; exactly one is allowed",
        )

    try:
        changed_paths = git.changed_paths(base_sha, verified_commit_sha)
    except GitReadError as error:
        return GitHandoffVerification(
            snapshot=observed,
            changed_paths=(),
            failure=GotaCycleFailure.WORKER_GIT_FAILURE,
            diagnostic=f"Worker changed-path inspection failed: {error}",
        )

    if not _canonical_text_tuple(changed_paths):
        return GitHandoffVerification(
            snapshot=observed,
            changed_paths=(),
            failure=GotaCycleFailure.WORKER_GIT_FAILURE,
            diagnostic="Git returned non-canonical changed paths",
        )

    declared_worker_paths = tuple(sorted(worker_changed_paths))
    if not _strictly_equal(declared_worker_paths, changed_paths):
        return GitHandoffVerification(
            snapshot=observed,
            changed_paths=changed_paths,
            failure=GotaCycleFailure.WORKER_CHANGED_PATHS_MISMATCH,
            diagnostic=(
                "Worker changed_paths differ from the independent Git diff: "
                f"declared={declared_worker_paths!r}, actual={changed_paths!r}"
            ),
        )
    if (
        verified_changed_paths is not None
        and not _strictly_equal(
            tuple(sorted(verified_changed_paths)), changed_paths
        )
    ):
        return GitHandoffVerification(
            snapshot=observed,
            changed_paths=changed_paths,
            failure=GotaCycleFailure.WORKER_CHANGED_PATHS_MISMATCH,
            diagnostic=(
                "Verified changed_paths differ from the independent Git diff: "
                f"verified={tuple(sorted(verified_changed_paths))!r}, actual={changed_paths!r}"
            ),
        )

    return GitHandoffVerification(
        snapshot=observed,
        changed_paths=changed_paths,
        failure=None,
        diagnostic="Worker commit Git state independently verified",
    )


@dataclass(frozen=True, slots=True)
class WorkerPhaseResult:
    """WorkerPhase outcome, including a verified handoff only on success."""

    base_sha: str
    branch: str
    worker_execution: OpenCodeRunResult | None
    worker_payload: GotaWorkerResult | None
    verified_commit: VerifiedWorkerCommit | None
    verified_changed_paths: tuple[str, ...]
    phase: GotaCyclePhase
    failure: GotaCycleFailure | None
    diagnostic: str

    @property
    def valid(self) -> bool:
        return self.failure is None and self.verified_commit is not None

    @property
    def verified_commit_sha(self) -> str | None:
        if self.verified_commit is None:
            return None
        return self.verified_commit.verified_commit_sha

    @property
    def verified_worker_commit(self) -> VerifiedWorkerCommit | None:
        return self.verified_commit


@dataclass(frozen=True, slots=True)
class ReviewPhaseResult:
    """ReviewPhase outcome for one already verified Worker commit."""

    verified_commit: VerifiedWorkerCommit | None
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
        if (
            self.failure is not None
            or type(self.review_result) is not GotaReviewResult
            or not _canonical_payload(self.review_result, GotaReviewResult)
        ):
            return None
        return self.review_result.decision


def _canonical_handoff(value: object) -> bool:
    if type(value) is not VerifiedWorkerCommit:
        return False
    return (
        _canonical_request(value.request)
        and type(value.repository) is _CANONICAL_PATH_TYPE
        and _canonical_sha(value.base_sha)
        and _canonical_text(value.branch)
        and _canonical_sha(value.verified_commit_sha)
        and _canonical_text_tuple(value.verified_changed_paths)
        and _canonical_execution(value.worker_execution, GotaWorkerResult)
        and _canonical_payload(value.worker_payload, GotaWorkerResult)
        and _canonical_snapshot(value.worker_snapshot)
    )


def _canonical_worker_phase_result(value: object) -> bool:
    if type(value) is not WorkerPhaseResult:
        return False
    return (
        _canonical_text(value.base_sha, allow_empty=True)
        and _canonical_text(value.branch, allow_empty=True)
        and (
            value.worker_execution is None
            or _canonical_execution(value.worker_execution, GotaWorkerResult)
        )
        and (
            value.worker_payload is None
            or _canonical_payload(value.worker_payload, GotaWorkerResult)
        )
        and (
            value.verified_commit is None
            or _canonical_handoff(value.verified_commit)
        )
        and _canonical_text_tuple(value.verified_changed_paths)
        and _canonical_enum(value.phase, GotaCyclePhase)
        and (
            value.failure is None
            or _canonical_enum(value.failure, GotaCycleFailure)
        )
        and _canonical_text(value.diagnostic, allow_empty=True)
    )


def _identity_matches(
    request: GotaRequest,
    request_id: str,
    task_id: str,
    run_id: str,
    attempt: int,
) -> bool:
    return (
        _canonical_request(request)
        and _strictly_equal(request.request_id, request_id)
        and _strictly_equal(request.task_id, task_id)
        and _strictly_equal(request.run_id, run_id)
        and _strictly_equal(request.attempt, attempt)
    )


def _invalid_worker_handoff(detail: str) -> tuple[GotaCycleFailure, str]:
    return (
        GotaCycleFailure.WORKER_RESULT_INVALID,
        f"Invalid Worker handoff: {detail}",
    )


def validate_verified_worker_commit(
    handoff: object,
) -> tuple[GotaCycleFailure, str] | None:
    """Validate the pure Worker evidence carried across the phase boundary."""

    if not _canonical_handoff(handoff):
        return _invalid_worker_handoff("handoff is not a VerifiedWorkerCommit")

    request = handoff.request
    if request.phase is not GotaPhase.WORKER:
        return _invalid_worker_handoff("request phase is not worker")
    if not _strictly_equal(
        handoff.repository,
        Path(request.workspace).resolve(),
    ):
        return _invalid_worker_handoff(
            "repository does not match the request workspace"
        )
    if not _strictly_equal(handoff.base_sha, request.base_sha):
        return _invalid_worker_handoff("base SHA does not match the request")
    if not _strictly_equal(handoff.branch, request.branch):
        return _invalid_worker_handoff("branch does not match the request")

    execution = handoff.worker_execution
    execution_failure = validate_successful_execution(
        execution,
        GotaWorkerResult,
        expected_cwd=handoff.repository,
    )
    if execution_failure is not None:
        return _invalid_worker_handoff(
            f"Worker execution is incoherent: {execution_failure}"
        )
    assert type(execution) is OpenCodeRunResult

    payload = handoff.worker_payload
    if (
        not _strictly_equal(payload.protocol, GOTA_PROTOCOL)
        or not _strictly_equal(payload.message, GotaMessage.WORKER_RESULT.value)
        or payload.phase is not GotaPhase.WORKER
    ):
        return _invalid_worker_handoff("Worker payload is not a worker result")
    if payload.result is not WorkerResultStatus.READY_FOR_REVIEW:
        return _invalid_worker_handoff("Worker result is not READY_FOR_REVIEW")
    if not _identity_matches(
        request,
        payload.request_id,
        payload.task_id,
        payload.run_id,
        payload.attempt,
    ):
        return _invalid_worker_handoff("WorkerResult identity does not match request")
    if not _strictly_equal(execution.payload, payload):
        return _invalid_worker_handoff(
            "Worker execution payload differs from the handoff payload"
        )
    if not _strictly_equal(payload.commit_sha, handoff.verified_commit_sha):
        return _invalid_worker_handoff(
            "WorkerResult commit SHA differs from verified commit SHA"
        )
    if not _strictly_equal(
        handoff.verified_changed_paths,
        tuple(sorted(payload.changed_paths)),
    ):
        return _invalid_worker_handoff(
            "WorkerResult changed_paths differ from verified changed paths"
        )

    snapshot = handoff.worker_snapshot
    if (
        not _strictly_equal(snapshot.repository, str(handoff.repository))
    ):
        return _invalid_worker_handoff("Worker Git snapshot repository is incoherent")
    if not _strictly_equal(snapshot.head, handoff.verified_commit_sha):
        return _invalid_worker_handoff("Worker Git snapshot HEAD is incoherent")
    if not _strictly_equal(snapshot.branch, handoff.branch):
        return _invalid_worker_handoff("Worker Git snapshot branch is incoherent")
    if not _strictly_equal(snapshot.status, ""):
        return _invalid_worker_handoff("Worker Git snapshot is not clean")

    return None


class WorkerPhase:
    """Execute one Worker and independently verify its resulting commit."""

    WORKER_AGENT = "gota-worker"

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

    @staticmethod
    def _runner_failure(
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

    def _failure(
        self,
        *,
        base_sha: str,
        branch: str,
        worker_execution: OpenCodeRunResult | None,
        worker_payload: GotaWorkerResult | None,
        verified_changed_paths: tuple[str, ...],
        phase: GotaCyclePhase,
        reason: GotaCycleFailure,
        diagnostic: str,
    ) -> WorkerPhaseResult:
        return WorkerPhaseResult(
            base_sha=base_sha,
            branch=branch,
            worker_execution=worker_execution,
            worker_payload=worker_payload,
            verified_commit=None,
            verified_changed_paths=verified_changed_paths,
            phase=phase,
            failure=reason,
            diagnostic=diagnostic,
        )

    def run(self, request: GotaRequest, *, timeout: float) -> WorkerPhaseResult:
        """Run Worker once and return a reusable verified commit handoff."""

        base_sha = ""
        branch = ""
        worker_execution: OpenCodeRunResult | None = None
        worker_payload: GotaWorkerResult | None = None
        verified_changed_paths: tuple[str, ...] = ()

        if not _canonical_request(request) or request.phase is not GotaPhase.WORKER:
            return self._failure(
                base_sha=base_sha,
                branch=branch,
                worker_execution=worker_execution,
                worker_payload=worker_payload,
                verified_changed_paths=verified_changed_paths,
                phase=GotaCyclePhase.INITIAL_GIT,
                reason=GotaCycleFailure.REQUEST_INVALID,
                diagnostic="GotaReviewCycle requires a worker-phase GotaRequest",
            )

        try:
            git = ReadOnlyGitAdapter(self.repository)
            initial = git.snapshot()
        except GitReadError as error:
            return self._failure(
                base_sha=base_sha,
                branch=branch,
                worker_execution=worker_execution,
                worker_payload=worker_payload,
                verified_changed_paths=verified_changed_paths,
                phase=GotaCyclePhase.INITIAL_GIT,
                reason=GotaCycleFailure.INITIAL_GIT_FAILURE,
                diagnostic=f"Initial Git inspection failed: {error}",
            )

        if not _canonical_snapshot(initial):
            return self._failure(
                base_sha=base_sha,
                branch=branch,
                worker_execution=worker_execution,
                worker_payload=worker_payload,
                verified_changed_paths=verified_changed_paths,
                phase=GotaCyclePhase.INITIAL_GIT,
                reason=GotaCycleFailure.INITIAL_GIT_FAILURE,
                diagnostic="Initial Git snapshot is not canonical",
            )

        base_sha = initial.head
        branch = initial.branch
        if not _strictly_equal(
            Path(request.workspace).resolve(), self.repository
        ):
            return self._failure(
                base_sha=base_sha,
                branch=branch,
                worker_execution=worker_execution,
                worker_payload=worker_payload,
                verified_changed_paths=verified_changed_paths,
                phase=GotaCyclePhase.INITIAL_GIT,
                reason=GotaCycleFailure.WORKSPACE_MISMATCH,
                diagnostic="Gota request workspace does not match the cycle repository",
            )
        if not _strictly_equal(request.base_sha, base_sha):
            return self._failure(
                base_sha=base_sha,
                branch=branch,
                worker_execution=worker_execution,
                worker_payload=worker_payload,
                verified_changed_paths=verified_changed_paths,
                phase=GotaCyclePhase.INITIAL_GIT,
                reason=GotaCycleFailure.INITIAL_BASE_MISMATCH,
                diagnostic=(
                    f"Request base SHA {request.base_sha} differs from Git HEAD {base_sha}"
                ),
            )
        if not _strictly_equal(request.branch, branch):
            return self._failure(
                base_sha=base_sha,
                branch=branch,
                worker_execution=worker_execution,
                worker_payload=worker_payload,
                verified_changed_paths=verified_changed_paths,
                phase=GotaCyclePhase.INITIAL_GIT,
                reason=GotaCycleFailure.INITIAL_BRANCH_MISMATCH,
                diagnostic=f"Request branch {request.branch} differs from Git branch {branch}",
            )
        if initial.status:
            return self._failure(
                base_sha=base_sha,
                branch=branch,
                worker_execution=worker_execution,
                worker_payload=worker_payload,
                verified_changed_paths=verified_changed_paths,
                phase=GotaCyclePhase.INITIAL_GIT,
                reason=GotaCycleFailure.INITIAL_WORKTREE_DIRTY,
                diagnostic=f"Initial worktree is not clean: {initial.status}",
            )

        worker_execution = self.runner.run(
            agent=self.WORKER_AGENT,
            prompt=self._worker_prompt(request),
            cwd=self.repository,
            timeout=timeout,
        )
        if not _canonical_execution(worker_execution, GotaWorkerResult):
            return self._failure(
                base_sha=base_sha,
                branch=branch,
                worker_execution=(
                    worker_execution
                    if type(worker_execution) is OpenCodeRunResult
                    else None
                ),
                worker_payload=worker_payload,
                verified_changed_paths=verified_changed_paths,
                phase=GotaCyclePhase.WORKER_EXECUTION,
                reason=GotaCycleFailure.WORKER_RESULT_INVALID,
                diagnostic="Worker runner did not return canonical execution data",
            )
        runner_failure = self._runner_failure(worker_execution)
        if runner_failure is not None:
            return self._failure(
                base_sha=base_sha,
                branch=branch,
                worker_execution=worker_execution,
                worker_payload=worker_payload,
                verified_changed_paths=verified_changed_paths,
                phase=GotaCyclePhase.WORKER_EXECUTION,
                reason=runner_failure[0],
                diagnostic=runner_failure[1],
            )
        if (
            worker_execution.status is OpenCodeRunStatus.SUCCEEDED
            and not _strictly_equal(worker_execution.exit_code, 0)
        ):
            return self._failure(
                base_sha=base_sha,
                branch=branch,
                worker_execution=worker_execution,
                worker_payload=worker_payload,
                verified_changed_paths=verified_changed_paths,
                phase=GotaCyclePhase.WORKER_EXECUTION,
                reason=GotaCycleFailure.WORKER_NON_ZERO_EXIT,
                diagnostic=(
                    "Worker runner reported SUCCEEDED with exit code "
                    f"{worker_execution.exit_code!r}"
                ),
            )
        if worker_execution.status is not OpenCodeRunStatus.SUCCEEDED:
            return self._failure(
                base_sha=base_sha,
                branch=branch,
                worker_execution=worker_execution,
                worker_payload=worker_payload,
                verified_changed_paths=verified_changed_paths,
                phase=GotaCyclePhase.WORKER_EXECUTION,
                reason=GotaCycleFailure.WORKER_RESULT_INVALID,
                diagnostic=(
                    f"Unexpected Worker runner status: {worker_execution.status.value}"
                ),
            )
        if type(worker_execution.payload) is not GotaWorkerResult:
            return self._failure(
                base_sha=base_sha,
                branch=branch,
                worker_execution=worker_execution,
                worker_payload=worker_payload,
                verified_changed_paths=verified_changed_paths,
                phase=GotaCyclePhase.WORKER_RESULT,
                reason=GotaCycleFailure.WORKER_RESULT_INVALID,
                diagnostic="Worker runner succeeded without a WorkerResult payload",
            )
        worker_payload = worker_execution.payload
        execution_failure = validate_successful_execution(
            worker_execution,
            GotaWorkerResult,
            expected_cwd=self.repository,
        )
        if execution_failure is not None:
            return self._failure(
                base_sha=base_sha,
                branch=branch,
                worker_execution=worker_execution,
                worker_payload=worker_payload,
                verified_changed_paths=verified_changed_paths,
                phase=GotaCyclePhase.WORKER_EXECUTION,
                reason=GotaCycleFailure.WORKER_RESULT_INVALID,
                diagnostic=f"Worker execution is incoherent: {execution_failure}",
            )

        if not _identity_matches(
            request,
            worker_payload.request_id,
            worker_payload.task_id,
            worker_payload.run_id,
            worker_payload.attempt,
        ) or worker_payload.phase is not GotaPhase.WORKER or (
            worker_payload.result is not WorkerResultStatus.READY_FOR_REVIEW
        ):
            return self._failure(
                base_sha=base_sha,
                branch=branch,
                worker_execution=worker_execution,
                worker_payload=worker_payload,
                verified_changed_paths=verified_changed_paths,
                phase=GotaCyclePhase.WORKER_RESULT,
                reason=GotaCycleFailure.WORKER_RESULT_INVALID,
                diagnostic="WorkerResult identity or result is not valid for this cycle",
            )

        git_verification = verify_worker_commit_git(
            git,
            base_sha=base_sha,
            expected_branch=branch,
            verified_commit_sha=worker_payload.commit_sha,
            worker_changed_paths=worker_payload.changed_paths,
        )
        if not git_verification.valid:
            return self._failure(
                base_sha=base_sha,
                branch=branch,
                worker_execution=worker_execution,
                worker_payload=worker_payload,
                verified_changed_paths=git_verification.changed_paths,
                phase=GotaCyclePhase.WORKER_GIT_VERIFICATION,
                reason=git_verification.failure or GotaCycleFailure.WORKER_GIT_FAILURE,
                diagnostic=git_verification.diagnostic,
            )
        assert git_verification.snapshot is not None
        verified_changed_paths = git_verification.changed_paths
        after_worker = git_verification.snapshot

        verified_commit = VerifiedWorkerCommit(
            request=request,
            repository=self.repository,
            base_sha=base_sha,
            branch=branch,
            verified_commit_sha=worker_payload.commit_sha,
            verified_changed_paths=verified_changed_paths,
            worker_execution=worker_execution,
            worker_payload=worker_payload,
            worker_snapshot=after_worker,
        )
        handoff_failure = validate_verified_worker_commit(verified_commit)
        if handoff_failure is not None:
            return self._failure(
                base_sha=base_sha,
                branch=branch,
                worker_execution=worker_execution,
                worker_payload=worker_payload,
                verified_changed_paths=verified_changed_paths,
                phase=GotaCyclePhase.WORKER_RESULT,
                reason=handoff_failure[0],
                diagnostic=handoff_failure[1],
            )
        return WorkerPhaseResult(
            base_sha=base_sha,
            branch=branch,
            worker_execution=worker_execution,
            worker_payload=worker_payload,
            verified_commit=verified_commit,
            verified_changed_paths=verified_changed_paths,
            phase=GotaCyclePhase.WORKER_GIT_VERIFICATION,
            failure=None,
            diagnostic="Worker commit independently verified",
        )


class ReviewPhase:
    """Review one VerifiedWorkerCommit without executing Worker."""

    REVIEWER_AGENT = "gota-reviewer"

    def __init__(self, *, runner: GotaCycleRunner) -> None:
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
    def _review_request(cls, request: GotaRequest) -> GotaRequest:
        return replace(
            request,
            request_id=f"{request.run_id}:{request.attempt}:review",
            phase=GotaPhase.REVIEW,
            previous_findings=(),
        )

    @classmethod
    def _reviewer_prompt(cls, verified: VerifiedWorkerCommit) -> str:
        review_request = cls._review_request(verified.request)
        return (
            "Audit exactly the verified commit identified below using the "
            "flujo.gota/v1 review phase.\n"
            f"base SHA: {verified.base_sha}\n"
            f"verified commit SHA: {verified.verified_commit_sha}\n"
            f"task ID: {verified.request.task_id}\n"
            f"run ID: {verified.request.run_id}\n"
            f"request ID: {review_request.request_id}\n"
            f"verified changed paths: {json.dumps(verified.verified_changed_paths)}\n"
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
    def _runner_failure(
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

    def _failure(
        self,
        *,
        verified: VerifiedWorkerCommit | None,
        reviewer_execution: OpenCodeRunResult | None,
        review_result: GotaReviewResult | None,
        phase: GotaCyclePhase,
        reason: GotaCycleFailure,
        diagnostic: str,
    ) -> ReviewPhaseResult:
        return ReviewPhaseResult(
            verified_commit=verified,
            reviewer_execution=reviewer_execution,
            review_result=review_result,
            phase=phase,
            failure=reason,
            diagnostic=diagnostic,
        )

    def run(
        self,
        verified: VerifiedWorkerCommit | WorkerPhaseResult,
        *,
        timeout: float,
    ) -> ReviewPhaseResult:
        """Validate an untrusted Worker handoff before running Reviewer."""

        if type(verified) is WorkerPhaseResult:
            handoff_failure: tuple[GotaCycleFailure, str] | None = None
            if not _canonical_worker_phase_result(verified):
                handoff = None
                handoff_failure = _invalid_worker_handoff(
                    "WorkerPhase result is not canonical"
                )
            else:
                handoff = verified.verified_commit
            if handoff_failure is None and verified.failure is not None:
                handoff_failure = _invalid_worker_handoff(
                    f"WorkerPhase result contains failure {verified.failure!r}"
                )
            elif handoff_failure is None and (
                verified.phase is not GotaCyclePhase.WORKER_GIT_VERIFICATION
            ):
                handoff_failure = _invalid_worker_handoff(
                    "WorkerPhase result is not a verified Git handoff"
                )
            elif handoff_failure is None and handoff is None:
                handoff_failure = _invalid_worker_handoff(
                    "WorkerPhase result has no verified commit"
                )
            elif handoff_failure is None and type(handoff) is not VerifiedWorkerCommit:
                handoff_failure = _invalid_worker_handoff(
                    "WorkerPhase result contains an invalid verified commit"
                )
            elif handoff_failure is None and (
                verified.worker_execution is None
                or verified.worker_payload is None
            ):
                handoff_failure = _invalid_worker_handoff(
                    "WorkerPhase result is missing Worker evidence"
                )
            elif handoff_failure is None and (
                not _strictly_equal(verified.base_sha, handoff.base_sha)
                or not _strictly_equal(verified.branch, handoff.branch)
                or not _strictly_equal(
                    verified.worker_execution, handoff.worker_execution
                )
                or not _strictly_equal(verified.worker_payload, handoff.worker_payload)
                or not _strictly_equal(
                    verified.verified_changed_paths,
                    handoff.verified_changed_paths,
                )
            ):
                handoff_failure = _invalid_worker_handoff(
                    "WorkerPhase result does not match its verified commit"
                )
            if handoff_failure is None and handoff is not None:
                handoff_failure = validate_verified_worker_commit(handoff)
        elif type(verified) is VerifiedWorkerCommit:
            handoff = verified
            handoff_failure = validate_verified_worker_commit(handoff)
        else:
            handoff = None
            handoff_failure = _invalid_worker_handoff(
                "handoff is not a VerifiedWorkerCommit or WorkerPhaseResult"
            )

        if handoff_failure is not None:
            return self._failure(
                verified=handoff,
                reviewer_execution=None,
                review_result=None,
                phase=GotaCyclePhase.WORKER_RESULT,
                reason=handoff_failure[0],
                diagnostic=handoff_failure[1],
            )

        assert handoff is not None
        verified = handoff

        reviewer_execution: OpenCodeRunResult | None = None
        review_result: GotaReviewResult | None = None
        review_request = self._review_request(verified.request)

        try:
            git = ReadOnlyGitAdapter(verified.repository)
        except GitReadError as error:
            return self._failure(
                verified=verified,
                reviewer_execution=reviewer_execution,
                review_result=review_result,
                phase=GotaCyclePhase.REVIEWER_INTEGRITY,
                reason=GotaCycleFailure.REVIEWER_GIT_FAILURE,
                diagnostic=f"Pre-review Git inspection failed: {error}",
            )
        pre_review_verification = verify_worker_commit_git(
            git,
            base_sha=verified.base_sha,
            expected_branch=verified.branch,
            verified_commit_sha=verified.verified_commit_sha,
            worker_changed_paths=verified.worker_payload.changed_paths,
            verified_changed_paths=verified.verified_changed_paths,
            expected_snapshot=verified.worker_snapshot,
        )
        if not pre_review_verification.valid:
            return self._failure(
                verified=verified,
                reviewer_execution=reviewer_execution,
                review_result=review_result,
                phase=GotaCyclePhase.REVIEWER_INTEGRITY,
                reason=pre_review_verification.failure
                or GotaCycleFailure.REVIEWER_GIT_FAILURE,
                diagnostic=pre_review_verification.diagnostic,
            )
        assert pre_review_verification.snapshot is not None
        before_reviewer = pre_review_verification.snapshot

        reviewer_execution = self.runner.run(
            agent=self.REVIEWER_AGENT,
            prompt=self._reviewer_prompt(verified),
            cwd=verified.repository,
            timeout=timeout,
        )
        post_review_verification = verify_worker_commit_git(
            git,
            base_sha=verified.base_sha,
            expected_branch=verified.branch,
            verified_commit_sha=verified.verified_commit_sha,
            worker_changed_paths=verified.worker_payload.changed_paths,
            verified_changed_paths=verified.verified_changed_paths,
            expected_snapshot=before_reviewer,
        )
        if not post_review_verification.valid:
            return self._failure(
                verified=verified,
                reviewer_execution=reviewer_execution,
                review_result=review_result,
                phase=GotaCyclePhase.REVIEWER_INTEGRITY,
                reason=post_review_verification.failure
                or GotaCycleFailure.REVIEWER_GIT_FAILURE,
                diagnostic=post_review_verification.diagnostic,
            )

        if not _canonical_execution(reviewer_execution, GotaReviewResult):
            return self._failure(
                verified=verified,
                reviewer_execution=(
                    reviewer_execution
                    if type(reviewer_execution) is OpenCodeRunResult
                    else None
                ),
                review_result=review_result,
                phase=GotaCyclePhase.REVIEWER_EXECUTION,
                reason=GotaCycleFailure.REVIEWER_RESULT_INVALID,
                diagnostic="Reviewer runner did not return canonical execution data",
            )

        runner_failure = self._runner_failure(reviewer_execution)
        if runner_failure is not None:
            return self._failure(
                verified=verified,
                reviewer_execution=reviewer_execution,
                review_result=review_result,
                phase=GotaCyclePhase.REVIEWER_EXECUTION,
                reason=runner_failure[0],
                diagnostic=runner_failure[1],
            )
        if (
            reviewer_execution.status is OpenCodeRunStatus.SUCCEEDED
            and not _strictly_equal(reviewer_execution.exit_code, 0)
        ):
            return self._failure(
                verified=verified,
                reviewer_execution=reviewer_execution,
                review_result=review_result,
                phase=GotaCyclePhase.REVIEWER_EXECUTION,
                reason=GotaCycleFailure.REVIEWER_NON_ZERO_EXIT,
                diagnostic=(
                    "Reviewer runner reported SUCCEEDED with exit code "
                    f"{reviewer_execution.exit_code!r}"
                ),
            )
        if reviewer_execution.status is not OpenCodeRunStatus.SUCCEEDED:
            return self._failure(
                verified=verified,
                reviewer_execution=reviewer_execution,
                review_result=review_result,
                phase=GotaCyclePhase.REVIEWER_EXECUTION,
                reason=GotaCycleFailure.REVIEWER_RESULT_INVALID,
                diagnostic=(
                    f"Unexpected Reviewer runner status: {reviewer_execution.status.value}"
                ),
            )
        if type(reviewer_execution.payload) is not GotaReviewResult:
            return self._failure(
                verified=verified,
                reviewer_execution=reviewer_execution,
                review_result=review_result,
                phase=GotaCyclePhase.REVIEWER_RESULT,
                reason=GotaCycleFailure.REVIEWER_RESULT_INVALID,
                diagnostic="Reviewer runner succeeded without a ReviewResult payload",
            )
        execution_failure = validate_successful_execution(
            reviewer_execution,
            GotaReviewResult,
            expected_cwd=verified.repository,
        )
        if execution_failure is not None:
            return self._failure(
                verified=verified,
                reviewer_execution=reviewer_execution,
                review_result=review_result,
                phase=GotaCyclePhase.REVIEWER_EXECUTION,
                reason=GotaCycleFailure.REVIEWER_RESULT_INVALID,
                diagnostic=f"Reviewer execution is incoherent: {execution_failure}",
            )

        assert type(reviewer_execution.payload) is GotaReviewResult
        review_result = reviewer_execution.payload
        if (
            review_request.phase is not GotaPhase.REVIEW
            or review_result.phase is not GotaPhase.REVIEW
            or not _identity_matches(
                review_request,
                review_result.request_id,
                review_result.task_id,
                review_result.run_id,
                review_result.attempt,
            )
        ):
            return self._failure(
                verified=verified,
                reviewer_execution=reviewer_execution,
                review_result=review_result,
                phase=GotaCyclePhase.REVIEWER_RESULT,
                reason=GotaCycleFailure.REVIEWER_RESULT_INVALID,
                diagnostic="ReviewResult identity is not valid for this cycle",
            )
        if not _strictly_equal(
            review_result.reviewed_commit_sha,
            verified.verified_commit_sha,
        ):
            return self._failure(
                verified=verified,
                reviewer_execution=reviewer_execution,
                review_result=review_result,
                phase=GotaCyclePhase.REVIEWER_RESULT,
                reason=GotaCycleFailure.REVIEWER_COMMIT_MISMATCH,
                diagnostic="ReviewResult does not identify the verified Worker commit",
            )

        return ReviewPhaseResult(
            verified_commit=verified,
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
    "ReviewPhase",
    "ReviewPhaseResult",
    "VerifiedWorkerCommit",
    "WorkerPhase",
    "WorkerPhaseResult",
    "validate_verified_worker_commit",
]
