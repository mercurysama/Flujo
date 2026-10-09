"""SQLite operational store and schema migration v1."""

from __future__ import annotations

import hashlib
import json
import re
import sqlite3
import uuid
from collections.abc import Callable, Iterator, Mapping, Sequence
from contextlib import closing, contextmanager
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path
from typing import Any

from .dependency_graph import validate_dependency_graph
from .decision_policy import GotaDecisionResult, GotaNextAction
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
    isoformat,
    parse_datetime,
    utc_now,
)
from .gota_protocol import (
    GotaPhase,
    GotaRequest,
    GotaReviewResult,
    GotaWorkerResult,
    ReviewDecision,
    WorkerResultStatus,
    parse_gota_payload,
)
from .state_machine import validate_transition


class CoordinatorStoreError(RuntimeError):
    pass


class FencingTokenError(CoordinatorStoreError):
    pass


class LeaseExpiredError(CoordinatorStoreError):
    pass


class UnsatisfiedDependencyError(CoordinatorStoreError):
    pass


class QueueBlockedError(CoordinatorStoreError):
    pass


class AcceptanceEvidenceError(CoordinatorStoreError):
    pass


class GotaWorkerResultError(CoordinatorStoreError):
    """Fail-closed error for the durable WorkerResult authority boundary."""


class GotaReviewResultError(CoordinatorStoreError):
    """Fail-closed error for the durable ReviewResult authority boundary."""


class GotaWorkerReservationError(GotaWorkerResultError):
    """Fail-closed error for the durable pre-Worker reservation boundary."""


class GotaWorkerReviewBoundaryError(GotaWorkerReservationError):
    """Fail-closed error for the durable Worker-to-Review boundary."""


class GotaDecisionApplicationError(CoordinatorStoreError):
    """Fail-closed error for the durable Gota decision application boundary."""


_RESERVED_EVIDENCE_KINDS = frozenset(
    {
        "gota_acceptance_verified",
        "gota_decision_applied",
        "gota_worker_result_received",
        "gota_worker_request_registered",
        "gota_worker_invocation_started",
        "gota_worker_commit_verified",
        "gota_review_result",
    }
)

_GOTA_NON_PASSED_ACTIONS: dict[GotaNextAction, tuple[TaskState, bool]] = {
    GotaNextAction.CORRECT: (TaskState.NOT_COMPLETED, False),
    GotaNextAction.WAIT_FOR_HUMAN: (TaskState.NOT_COMPLETED, True),
    GotaNextAction.BLOCK: (TaskState.BLOCKED, False),
}


def _canonical_json(value: Any) -> str:
    return json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=False)


def _digest(value: Any) -> str:
    return hashlib.sha256(_canonical_json(value).encode("utf-8")).hexdigest()


@dataclass(frozen=True, slots=True)
class GotaWorkerInvocationReservation:
    """The two immutable authorities created by one Worker reservation."""

    request: GotaRequest
    request_evidence: Evidence
    invocation_evidence: Evidence
    created: bool


@dataclass(frozen=True, slots=True)
class GotaWorkerReviewPersistence:
    """Result of the private atomic Worker-to-Review store operation."""

    run: TaskRun
    commit_evidence: Evidence
    created: bool


@dataclass(frozen=True, slots=True)
class GotaWorkerReviewBoundaryAnchor:
    """Durable Gota-only authority for one Worker-to-Review frontier."""

    run_id: str
    attempt: int
    request_id: str
    commit_evidence_id: str
    commit_evidence_digest: str
    transition_event_id: int
    created_at: datetime


@dataclass(frozen=True, slots=True)
class GotaReviewResultAnchor:
    """Durable Gota-only authority for one persisted ReviewResult."""

    run_id: str
    attempt: int
    request_id: str
    review_evidence_id: str
    review_evidence_digest: str
    worker_commit_evidence_id: str
    created_at: datetime


@dataclass(frozen=True, slots=True)
class GotaDecisionAuthorities:
    """One coherent durable Worker-to-Review and ReviewResult frontier."""

    run: TaskRun
    request: GotaRequest
    worker_result: GotaWorkerResult
    worker_result_evidence: Evidence
    worker_commit_evidence: Evidence
    worker_review_anchor: GotaWorkerReviewBoundaryAnchor
    review_result: GotaReviewResult
    review_evidence: Evidence
    review_anchor: GotaReviewResultAnchor
    # The fence of the immutable Worker frontier, not the fence of a later
    # mutation such as ReviewResult or terminal decision application.
    fencing_token: int


@dataclass(frozen=True, slots=True)
class GotaHumanReviewHold:
    """Immutable durable hold created by HUMAN_REVIEW_REQUIRED."""

    run_id: str
    attempt: int
    request_id: str
    review_evidence_id: str
    review_evidence_digest: str
    decision_evidence_id: str
    decision_evidence_digest: str
    created_at: datetime


@dataclass(frozen=True, slots=True)
class GotaDecisionApplicationPersistence:
    """Store result for one non-PASSED Gota decision application."""

    run: TaskRun
    decision_evidence: Evidence
    hold: GotaHumanReviewHold | None
    created: bool

    @property
    def state(self) -> TaskState:
        return self.run.state

    @property
    def already_applied(self) -> bool:
        return not self.created


class SQLiteCoordinatorStore:
    """Versioned SQLite storage. Each operation opens its own connection."""

    def __init__(self, path: str | Path) -> None:
        self.path = Path(path)
        self.path.parent.mkdir(parents=True, exist_ok=True)
        self.migrate()

    def _connect(self) -> sqlite3.Connection:
        connection = sqlite3.connect(self.path, timeout=10.0, isolation_level=None)
        connection.row_factory = sqlite3.Row
        connection.execute("PRAGMA foreign_keys = ON")
        connection.execute("PRAGMA busy_timeout = 10000")
        return connection

    def _trusted_now(self) -> datetime:
        """Return the store-owned clock used by authoritative transitions."""
        return utc_now()

    @contextmanager
    def transaction(self, *, immediate: bool = False) -> Iterator[sqlite3.Connection]:
        connection = self._connect()
        try:
            connection.execute("BEGIN IMMEDIATE" if immediate else "BEGIN")
            yield connection
            connection.commit()
        except BaseException:
            connection.rollback()
            raise
        finally:
            connection.close()

    def migrate(self) -> None:
        connection = self._connect()
        try:
            connection.executescript(
                """
                BEGIN IMMEDIATE;

                CREATE TABLE IF NOT EXISTS schema_migrations (
                    version INTEGER PRIMARY KEY,
                    applied_at TEXT NOT NULL
                );

                CREATE TABLE IF NOT EXISTS task_specs (
                    task_id TEXT PRIMARY KEY,
                    schema_name TEXT NOT NULL,
                    title TEXT NOT NULL,
                    objective TEXT NOT NULL,
                    project_id TEXT NOT NULL,
                    repository_id TEXT NOT NULL,
                    branch TEXT NOT NULL,
                    base_sha TEXT NOT NULL,
                    context_id TEXT NOT NULL,
                    allowed_paths_json TEXT NOT NULL,
                    protected_paths_json TEXT NOT NULL,
                    required_resources_json TEXT NOT NULL,
                    acceptance_criteria_json TEXT NOT NULL,
                    commit_message TEXT NOT NULL,
                    created_at TEXT NOT NULL
                );

                CREATE TABLE IF NOT EXISTS contexts (
                    context_id TEXT PRIMARY KEY,
                    task_id TEXT NOT NULL REFERENCES task_specs(task_id),
                    project_id TEXT NOT NULL,
                    schema_name TEXT NOT NULL,
                    payload_json TEXT NOT NULL,
                    created_at TEXT NOT NULL
                );

                CREATE TABLE IF NOT EXISTS task_runs (
                    run_id TEXT PRIMARY KEY,
                    task_id TEXT NOT NULL REFERENCES task_specs(task_id),
                    state TEXT NOT NULL,
                    created_at TEXT NOT NULL,
                    updated_at TEXT NOT NULL
                );

                CREATE TABLE IF NOT EXISTS dependencies (
                    task_id TEXT NOT NULL REFERENCES task_specs(task_id),
                    depends_on_task_id TEXT NOT NULL REFERENCES task_specs(task_id),
                    PRIMARY KEY (task_id, depends_on_task_id),
                    CHECK (task_id <> depends_on_task_id)
                );

                CREATE TABLE IF NOT EXISTS transition_events (
                    event_id INTEGER PRIMARY KEY AUTOINCREMENT,
                    run_id TEXT NOT NULL REFERENCES task_runs(run_id),
                    from_state TEXT,
                    to_state TEXT NOT NULL,
                    actor TEXT NOT NULL,
                    reason TEXT NOT NULL,
                    fencing_token INTEGER,
                    created_at TEXT NOT NULL
                );

                CREATE TABLE IF NOT EXISTS gota_worker_review_boundaries (
                    run_id TEXT NOT NULL REFERENCES task_runs(run_id),
                    attempt INTEGER NOT NULL CHECK (attempt > 0),
                    request_id TEXT NOT NULL,
                    commit_evidence_id TEXT NOT NULL UNIQUE REFERENCES evidence(evidence_id),
                    commit_evidence_digest TEXT NOT NULL,
                    transition_event_id INTEGER NOT NULL UNIQUE REFERENCES transition_events(event_id),
                    created_at TEXT NOT NULL,
                    PRIMARY KEY (run_id, attempt, request_id)
                );

                CREATE TABLE IF NOT EXISTS gota_review_results (
                    run_id TEXT NOT NULL REFERENCES task_runs(run_id),
                    attempt INTEGER NOT NULL CHECK (attempt > 0),
                    request_id TEXT NOT NULL,
                    review_evidence_id TEXT NOT NULL UNIQUE REFERENCES evidence(evidence_id),
                    review_evidence_digest TEXT NOT NULL,
                    worker_commit_evidence_id TEXT NOT NULL REFERENCES evidence(evidence_id),
                    created_at TEXT NOT NULL,
                    PRIMARY KEY (run_id, attempt, request_id)
                );

                CREATE TABLE IF NOT EXISTS gota_human_review_holds (
                    run_id TEXT NOT NULL REFERENCES task_runs(run_id),
                    attempt INTEGER NOT NULL CHECK (attempt > 0),
                    request_id TEXT NOT NULL,
                    review_evidence_id TEXT NOT NULL UNIQUE REFERENCES evidence(evidence_id),
                    review_evidence_digest TEXT NOT NULL,
                    decision_evidence_id TEXT NOT NULL UNIQUE REFERENCES evidence(evidence_id),
                    decision_evidence_digest TEXT NOT NULL,
                    created_at TEXT NOT NULL,
                    PRIMARY KEY (run_id, attempt, request_id)
                );

                CREATE TABLE IF NOT EXISTS evidence (
                    evidence_id TEXT PRIMARY KEY,
                    run_id TEXT NOT NULL REFERENCES task_runs(run_id),
                    kind TEXT NOT NULL,
                    payload_json TEXT NOT NULL,
                    digest TEXT NOT NULL,
                    fencing_token INTEGER NOT NULL,
                    created_at TEXT NOT NULL
                );

                CREATE TABLE IF NOT EXISTS checkpoints (
                    checkpoint_id TEXT PRIMARY KEY,
                    run_id TEXT NOT NULL REFERENCES task_runs(run_id),
                    payload_json TEXT NOT NULL,
                    digest TEXT NOT NULL,
                    fencing_token INTEGER NOT NULL,
                    created_at TEXT NOT NULL
                );

                CREATE TABLE IF NOT EXISTS resource_attempts (
                    run_id TEXT NOT NULL REFERENCES task_runs(run_id),
                    resource_id TEXT NOT NULL,
                    attempt_count INTEGER NOT NULL,
                    last_failure_json TEXT NOT NULL,
                    updated_at TEXT NOT NULL,
                    PRIMARY KEY (run_id, resource_id)
                );

                CREATE TABLE IF NOT EXISTS coordinator_resources (
                    resource_id TEXT PRIMARY KEY,
                    cooldown_required INTEGER NOT NULL CHECK (cooldown_required IN (0, 1)),
                    minimum_seconds INTEGER NOT NULL CHECK (minimum_seconds >= 0),
                    state TEXT CHECK (state IS NULL OR state = 'COOLDOWN'),
                    cooldown_started_at TEXT,
                    not_before TEXT
                );

                CREATE TABLE IF NOT EXISTS global_lock (
                    lock_name TEXT PRIMARY KEY,
                    owner_id TEXT,
                    run_id TEXT,
                    fencing_token INTEGER NOT NULL DEFAULT 0,
                    acquired_at TEXT,
                    heartbeat_at TEXT,
                    lease_expires_at TEXT,
                    stale INTEGER NOT NULL DEFAULT 0 CHECK (stale IN (0, 1))
                );

                CREATE TABLE IF NOT EXISTS project_bindings (
                    project_id TEXT PRIMARY KEY,
                    repository_id TEXT NOT NULL,
                    workspace_path TEXT NOT NULL,
                    context_id TEXT NOT NULL REFERENCES contexts(context_id)
                );

                INSERT OR IGNORE INTO global_lock(lock_name, fencing_token, stale)
                VALUES ('global', 0, 0);
                """
            )
            for table in (
                "contexts",
                "transition_events",
                "evidence",
                "checkpoints",
                "gota_worker_review_boundaries",
                "gota_review_results",
                "gota_human_review_holds",
            ):
                connection.execute(
                    f"""
                    CREATE TRIGGER IF NOT EXISTS immutable_{table}_update
                    BEFORE UPDATE ON {table}
                    BEGIN SELECT RAISE(ABORT, '{table} is immutable'); END
                    """
                )
                connection.execute(
                    f"""
                    CREATE TRIGGER IF NOT EXISTS immutable_{table}_delete
                    BEFORE DELETE ON {table}
                    BEGIN SELECT RAISE(ABORT, '{table} is immutable'); END
                    """
                )
            connection.execute(
                "INSERT OR IGNORE INTO schema_migrations(version, applied_at) VALUES (?, ?)",
                (COORDINATOR_SCHEMA_VERSION, isoformat(utc_now())),
            )
            connection.execute(f"PRAGMA user_version = {COORDINATOR_SCHEMA_VERSION}")
            connection.commit()
        except BaseException:
            connection.rollback()
            raise
        finally:
            connection.close()

    def schema_version(self) -> int:
        with closing(self._connect()) as connection:
            row = connection.execute("PRAGMA user_version").fetchone()
        return int(row[0])

    def create_task_spec(self, spec: TaskSpec) -> None:
        spec.validate()
        with self.transaction(immediate=True) as connection:
            connection.execute(
                """
                INSERT INTO task_specs(
                    task_id, schema_name, title, objective, project_id, repository_id,
                    branch, base_sha, context_id, allowed_paths_json,
                    protected_paths_json, required_resources_json,
                    acceptance_criteria_json, commit_message, created_at
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                (
                    spec.task_id,
                    spec.schema,
                    spec.title,
                    spec.objective,
                    spec.project_id,
                    spec.repository_id,
                    spec.branch,
                    spec.base_sha,
                    spec.context_id,
                    _canonical_json(spec.allowed_paths),
                    _canonical_json(spec.protected_paths),
                    _canonical_json(spec.required_resources),
                    _canonical_json(spec.acceptance_criteria),
                    spec.commit_message,
                    isoformat(spec.created_at),
                ),
            )

    def get_task_spec(self, task_id: str) -> TaskSpec:
        with closing(self._connect()) as connection:
            row = connection.execute(
                "SELECT * FROM task_specs WHERE task_id = ?", (task_id,)
            ).fetchone()
        if row is None:
            raise KeyError(task_id)
        return TaskSpec(
            task_id=row["task_id"],
            schema=row["schema_name"],
            title=row["title"],
            objective=row["objective"],
            project_id=row["project_id"],
            repository_id=row["repository_id"],
            branch=row["branch"],
            base_sha=row["base_sha"],
            context_id=row["context_id"],
            allowed_paths=tuple(json.loads(row["allowed_paths_json"])),
            protected_paths=tuple(json.loads(row["protected_paths_json"])),
            required_resources=tuple(json.loads(row["required_resources_json"])),
            acceptance_criteria=tuple(json.loads(row["acceptance_criteria_json"])),
            commit_message=row["commit_message"],
            created_at=parse_datetime(row["created_at"]),
        )

    def list_task_specs(self) -> tuple[TaskSpec, ...]:
        with closing(self._connect()) as connection:
            task_ids = [
                row[0]
                for row in connection.execute(
                    "SELECT task_id FROM task_specs ORDER BY task_id"
                ).fetchall()
            ]
        return tuple(self.get_task_spec(task_id) for task_id in task_ids)

    def create_context(self, context: Context) -> None:
        if context.schema != "flow.coordinator/context/v1":
            raise ValueError(f"Unsupported context schema: {context.schema}")
        with self.transaction(immediate=True) as connection:
            connection.execute(
                """
                INSERT INTO contexts(context_id, task_id, project_id, schema_name, payload_json, created_at)
                VALUES (?, ?, ?, ?, ?, ?)
                """,
                (
                    context.context_id,
                    context.task_id,
                    context.project_id,
                    context.schema,
                    _canonical_json(context.payload),
                    isoformat(context.created_at),
                ),
            )

    def get_context(self, context_id: str) -> Context:
        with closing(self._connect()) as connection:
            row = connection.execute(
                "SELECT * FROM contexts WHERE context_id = ?", (context_id,)
            ).fetchone()
        if row is None:
            raise KeyError(context_id)
        return Context(
            context_id=row["context_id"],
            task_id=row["task_id"],
            project_id=row["project_id"],
            schema=row["schema_name"],
            payload=json.loads(row["payload_json"]),
            created_at=parse_datetime(row["created_at"]),
        )

    def bind_project(self, binding: ProjectBinding) -> None:
        with self.transaction(immediate=True) as connection:
            connection.execute(
                """
                INSERT INTO project_bindings(project_id, repository_id, workspace_path, context_id)
                VALUES (?, ?, ?, ?)
                """,
                (
                    binding.project_id,
                    binding.repository_id,
                    binding.workspace_path,
                    binding.context_id,
                ),
            )

    def get_project_binding(self, project_id: str) -> ProjectBinding:
        with closing(self._connect()) as connection:
            row = connection.execute(
                "SELECT * FROM project_bindings WHERE project_id = ?", (project_id,)
            ).fetchone()
        if row is None:
            raise KeyError(project_id)
        return ProjectBinding(
            project_id=row["project_id"],
            repository_id=row["repository_id"],
            workspace_path=row["workspace_path"],
            context_id=row["context_id"],
        )

    def create_run(self, task_id: str, *, actor: str = "coordinator") -> TaskRun:
        run_id = str(uuid.uuid4())
        now = utc_now()
        with self.transaction(immediate=True) as connection:
            connection.execute(
                "INSERT INTO task_runs(run_id, task_id, state, created_at, updated_at) VALUES (?, ?, ?, ?, ?)",
                (run_id, task_id, TaskState.ASSIGNED.value, isoformat(now), isoformat(now)),
            )
            connection.execute(
                """
                INSERT INTO transition_events(run_id, from_state, to_state, actor, reason, created_at)
                VALUES (?, NULL, ?, ?, ?, ?)
                """,
                (run_id, TaskState.ASSIGNED.value, actor, "task_run_created", isoformat(now)),
            )
        return TaskRun(run_id, task_id, TaskState.ASSIGNED, now, now)

    def get_run(self, run_id: str) -> TaskRun:
        with closing(self._connect()) as connection:
            row = connection.execute(
                "SELECT * FROM task_runs WHERE run_id = ?", (run_id,)
            ).fetchone()
        if row is None:
            raise KeyError(run_id)
        return TaskRun(
            run_id=row["run_id"],
            task_id=row["task_id"],
            state=TaskState(row["state"]),
            created_at=parse_datetime(row["created_at"]),
            updated_at=parse_datetime(row["updated_at"]),
        )

    def latest_run_for_task(self, task_id: str) -> TaskRun | None:
        with closing(self._connect()) as connection:
            row = connection.execute(
                "SELECT run_id FROM task_runs WHERE task_id = ? ORDER BY created_at DESC LIMIT 1",
                (task_id,),
            ).fetchone()
        return self.get_run(row["run_id"]) if row else None

    def list_runs(self) -> tuple[TaskRun, ...]:
        with closing(self._connect()) as connection:
            run_ids = [
                row[0]
                for row in connection.execute(
                    "SELECT run_id FROM task_runs ORDER BY created_at, run_id"
                ).fetchall()
            ]
        return tuple(self.get_run(run_id) for run_id in run_ids)

    @contextmanager
    def fenced_transaction(
        self, lease: Lease, *, now: datetime | None = None
    ) -> Iterator[sqlite3.Connection]:
        current_time = now or utc_now()
        connection = self._connect()
        try:
            connection.execute("BEGIN IMMEDIATE")
            try:
                self._assert_fenced_connection(connection, lease, current_time)
            except LeaseExpiredError:
                # An entry check preserves the existing stale-lock marker
                # semantics.  A check made by the transaction body is
                # rolled back by the body exception path below.
                connection.commit()
                raise
            except FencingTokenError:
                connection.rollback()
                raise
            try:
                yield connection
            except BaseException:
                connection.rollback()
                raise
            else:
                connection.commit()
        except BaseException:
            try:
                connection.rollback()
            except sqlite3.Error:
                pass
            raise
        finally:
            try:
                connection.close()
            except sqlite3.Error:
                pass

    @staticmethod
    def _assert_fenced_connection(
        connection: sqlite3.Connection,
        lease: Lease,
        current_time: datetime,
    ) -> None:
        """Validate owner, run, fencing token, and lease expiry on a connection."""

        row = connection.execute(
            "SELECT * FROM global_lock WHERE lock_name = 'global'"
        ).fetchone()
        if row is None:
            raise FencingTokenError("The global fencing lock is missing")
        if (
            row["owner_id"] != lease.owner_id
            or row["run_id"] != lease.run_id
            or int(row["fencing_token"]) != lease.fencing_token
            or bool(row["stale"])
        ):
            raise FencingTokenError(
                f"Stale or foreign fencing token {lease.fencing_token} for {lease.owner_id}"
            )
        if parse_datetime(row["lease_expires_at"]) <= current_time:
            connection.execute(
                "UPDATE global_lock SET stale = 1 WHERE lock_name = 'global'"
            )
            raise LeaseExpiredError(
                f"Lease {lease.fencing_token} expired at {row['lease_expires_at']}"
            )

    def transition_run(
        self,
        run_id: str,
        to_state: TaskState,
        lease: Lease,
        *,
        actor: str,
        reason: str,
        now: datetime | None = None,
    ) -> TaskRun:
        current_time = now or utc_now()
        with self.fenced_transaction(lease, now=current_time) as connection:
            row = connection.execute(
                "SELECT state FROM task_runs WHERE run_id = ?", (run_id,)
            ).fetchone()
            if row is None:
                raise KeyError(run_id)
            from_state = TaskState(row["state"])
            validate_transition(from_state, to_state)
            if to_state is TaskState.DONE:
                evidence_rows = connection.execute(
                    "SELECT kind, payload_json FROM evidence WHERE run_id = ? ORDER BY rowid",
                    (run_id,),
                ).fetchall()
                microaudits = [
                    json.loads(item["payload_json"])
                    for item in evidence_rows
                    if item["kind"] == "microaudit"
                ]
                staging = [
                    json.loads(item["payload_json"])
                    for item in evidence_rows
                    if item["kind"] == "selective_staging"
                ]
                commits = [
                    json.loads(item["payload_json"])
                    for item in evidence_rows
                    if item["kind"] == "local_commit"
                ]
                if not microaudits or not bool(microaudits[-1].get("passed")):
                    raise AcceptanceEvidenceError(
                        "DONE requires an approved microaudit evidence record"
                    )
                if not staging or not bool(staging[-1].get("inspected")):
                    raise AcceptanceEvidenceError(
                        "DONE requires inspected selective staging evidence"
                    )
                commit_sha = (
                    str(commits[0].get("sha", "")) if len(commits) == 1 else ""
                )
                valid_sha = re.fullmatch(
                    r"[0-9a-f]{40}|[0-9a-f]{64}", commit_sha
                )
                if len(commits) != 1 or valid_sha is None:
                    raise AcceptanceEvidenceError(
                        "DONE requires exactly one local commit SHA evidence record"
                    )
            connection.execute(
                "UPDATE task_runs SET state = ?, updated_at = ? WHERE run_id = ?",
                (to_state.value, isoformat(current_time), run_id),
            )
            connection.execute(
                """
                INSERT INTO transition_events(
                    run_id, from_state, to_state, actor, reason, fencing_token, created_at
                ) VALUES (?, ?, ?, ?, ?, ?, ?)
                """,
                (
                    run_id,
                    from_state.value,
                    to_state.value,
                    actor,
                    reason,
                    lease.fencing_token,
                    isoformat(current_time),
                ),
            )
        return self.get_run(run_id)

    def transition_gota_to_done(
        self,
        run_id: str,
        lease: Lease,
        *,
        actor: str | None = None,
    ) -> TaskRun:
        """Atomically accept one persisted Gota review from REVIEW to DONE.

        The Gota result records are read from the immutable evidence ledger. No
        caller-supplied payload, digest, decision, or commit SHA participates in
        the acceptance decision.
        """

        trusted_now = self._trusted_now()
        if lease.run_id != run_id:
            raise FencingTokenError(
                f"Lease run {lease.run_id} does not match Gota run {run_id}"
            )

        def load_worker_identity(
            connection: sqlite3.Connection,
            task_id: str,
        ) -> tuple[int, str]:
            rows = connection.execute(
                """
                SELECT * FROM evidence
                WHERE run_id = ? AND kind = ?
                ORDER BY rowid
                """,
                (run_id, "gota_worker_result_received"),
            ).fetchall()
            if len(rows) != 1:
                raise AcceptanceEvidenceError(
                    "Gota DONE requires exactly one gota_worker_result_received evidence record"
                )
            try:
                result, _payload = self._stored_worker_result(
                    rows[0],
                    expected_run_id=run_id,
                    expected_task_id=task_id,
                )
            except GotaWorkerResultError as error:
                raise AcceptanceEvidenceError(str(error)) from error
            if result.result is not WorkerResultStatus.READY_FOR_REVIEW:
                raise AcceptanceEvidenceError(
                    "Persisted Gota Worker result is not READY_FOR_REVIEW"
                )
            expected_request_id = f"{run_id}:{result.attempt}:worker"
            if result.request_id != expected_request_id:
                raise AcceptanceEvidenceError(
                    "Persisted Gota Worker request identity is not canonical"
                )
            return result.attempt, result.request_id

        with self.fenced_transaction(lease, now=trusted_now) as connection:
            run_row = connection.execute(
                "SELECT task_id, state FROM task_runs WHERE run_id = ?", (run_id,)
            ).fetchone()
            if run_row is None:
                raise KeyError(run_id)
            if TaskState(run_row["state"]) is not TaskState.REVIEW:
                raise ValueError("Gota acceptance requires a REVIEW task")

            existing_acceptance = connection.execute(
                "SELECT COUNT(*) FROM evidence WHERE run_id = ? AND kind = ?",
                (run_id, "gota_acceptance_verified"),
            ).fetchone()
            if existing_acceptance is None or int(existing_acceptance[0]) != 0:
                raise AcceptanceEvidenceError(
                    "Gota acceptance evidence already exists or is incoherent"
                )

            task_id = run_row["task_id"]
            attempt, worker_request_id = load_worker_identity(connection, task_id)
            try:
                authorities = self._load_gota_decision_authorities_connection(
                    connection,
                    run_id=run_id,
                    attempt=attempt,
                    worker_request_id=worker_request_id,
                    allowed_states=frozenset({TaskState.REVIEW}),
                )
            except (
                GotaDecisionApplicationError,
                GotaWorkerReservationError,
                GotaWorkerResultError,
                GotaWorkerReviewBoundaryError,
                GotaReviewResultError,
                TypeError,
                ValueError,
                KeyError,
            ) as error:
                message = str(error)
                if message == "Exactly one durable Worker commit verification is required":
                    message = (
                        "Gota DONE requires exactly one "
                        "gota_worker_commit_verified evidence record"
                    )
                elif message == "Exactly one durable ReviewResult is required":
                    message = (
                        "Gota DONE requires exactly one gota_review_result "
                        "evidence record"
                    )
                elif message == "Persisted Worker commit verification is incoherent":
                    message = "Persisted Gota Worker commit SHA or identity is incoherent"
                elif message == "Durable ReviewResult identity or Worker SHA is incoherent":
                    message = "Persisted Gota Review result is incoherent or not PASSED"
                raise AcceptanceEvidenceError(
                    message
                ) from error
            if authorities.review_result.decision is not ReviewDecision.PASSED:
                raise AcceptanceEvidenceError(
                    "Persisted Gota Review result is incoherent or not PASSED"
                )

            acceptance_payload = {
                "run_id": run_id,
                "task_id": task_id,
                "attempt": authorities.worker_result.attempt,
                "worker_request_id": authorities.worker_result.request_id,
                "review_request_id": authorities.review_result.request_id,
                "worker_commit_sha": authorities.worker_result.commit_sha,
                "reviewed_commit_sha": authorities.review_result.reviewed_commit_sha,
                "decision": authorities.review_result.decision.value,
                "fencing_token": lease.fencing_token,
                "worker_result_evidence_id": authorities.worker_result_evidence.evidence_id,
                "worker_commit_evidence_id": authorities.worker_commit_evidence.evidence_id,
                "review_result_evidence_id": authorities.review_evidence.evidence_id,
            }
            self._insert_evidence(
                connection,
                run_id,
                "gota_acceptance_verified",
                acceptance_payload,
                lease,
                trusted_now,
            )
            updated = connection.execute(
                """
                UPDATE task_runs
                SET state = ?, updated_at = ?
                WHERE run_id = ? AND state = ?
                """,
                (
                    TaskState.DONE.value,
                    isoformat(trusted_now),
                    run_id,
                    TaskState.REVIEW.value,
                ),
            )
            if updated.rowcount != 1:
                raise ValueError("Gota acceptance requires a REVIEW task")
            connection.execute(
                """
                INSERT INTO transition_events(
                    run_id, from_state, to_state, actor, reason, fencing_token, created_at
                ) VALUES (?, ?, ?, ?, ?, ?, ?)
                """,
                (
                    run_id,
                    TaskState.REVIEW.value,
                    TaskState.DONE.value,
                    actor if actor is not None else lease.owner_id,
                    "gota_acceptance_verified",
                    lease.fencing_token,
                    isoformat(trusted_now),
                ),
            )
            final_now = self._trusted_now()
            self._assert_fenced_connection(connection, lease, final_now)
        return self.get_run(run_id)

    @staticmethod
    def _canonical_worker_result(
        result: GotaWorkerResult,
    ) -> tuple[GotaWorkerResult, dict[str, Any]]:
        """Revalidate one in-memory result through the protocol parser."""

        if type(result) is not GotaWorkerResult:
            raise GotaWorkerResultError(
                "Gota Worker result must be the canonical GotaWorkerResult type"
            )
        try:
            payload = result.to_payload()
            parsed = parse_gota_payload(payload)
        except (TypeError, ValueError, KeyError) as error:
            raise GotaWorkerResultError(
                "Gota Worker result does not satisfy the canonical protocol"
            ) from error
        if type(parsed) is not GotaWorkerResult:
            raise GotaWorkerResultError(
                "Gota Worker result payload has the wrong protocol message type"
            )
        canonical_payload = parsed.to_payload()
        try:
            if _canonical_json(canonical_payload) != _canonical_json(payload):
                raise GotaWorkerResultError(
                    "Gota Worker result payload is not canonical"
                )
        except (TypeError, ValueError) as error:
            raise GotaWorkerResultError(
                "Gota Worker result payload is not JSON-serializable"
            ) from error
        return parsed, canonical_payload

    @staticmethod
    def _canonical_review_result(
        result: GotaReviewResult,
    ) -> tuple[GotaReviewResult, dict[str, Any]]:
        """Revalidate one in-memory ReviewResult through the protocol parser."""

        if type(result) is not GotaReviewResult:
            raise GotaReviewResultError(
                "Gota Review result must be the canonical GotaReviewResult type"
            )
        try:
            payload = result.to_payload()
            parsed = parse_gota_payload(payload)
        except Exception as error:
            raise GotaReviewResultError(
                "Gota Review result does not satisfy the canonical protocol"
            ) from error
        if type(parsed) is not GotaReviewResult:
            raise GotaReviewResultError(
                "Gota Review result payload has the wrong protocol message type"
            )
        canonical_payload = parsed.to_payload()
        try:
            if _canonical_json(canonical_payload) != _canonical_json(payload):
                raise GotaReviewResultError(
                    "Gota Review result payload is not canonical"
                )
        except GotaReviewResultError:
            raise
        except Exception as error:
            raise GotaReviewResultError(
                "Gota Review result payload is not JSON-serializable"
            ) from error
        return parsed, canonical_payload

    @staticmethod
    def _stored_worker_result(
        row: sqlite3.Row,
        *,
        expected_run_id: str,
        expected_task_id: str,
    ) -> tuple[GotaWorkerResult, dict[str, Any]]:
        """Verify ledger integrity and parse one stored WorkerResult."""

        try:
            parse_datetime(row["created_at"])
            payload = json.loads(row["payload_json"])
            if type(payload) is not dict:
                raise GotaWorkerResultError(
                    "Stored Gota Worker result payload is not an object"
                )
            if _digest(payload) != row["digest"]:
                raise GotaWorkerResultError(
                    "Stored Gota Worker result failed its digest check"
                )
            parsed = parse_gota_payload(payload)
        except GotaWorkerResultError:
            raise
        except (TypeError, ValueError, KeyError) as error:
            raise GotaWorkerResultError(
                "Stored Gota Worker result is invalid"
            ) from error
        if type(parsed) is not GotaWorkerResult:
            raise GotaWorkerResultError(
                "Stored Gota evidence is not a WorkerResult"
            )
        canonical_payload = parsed.to_payload()
        try:
            if _canonical_json(canonical_payload) != row["payload_json"]:
                raise GotaWorkerResultError(
                    "Stored Gota Worker result is not canonical"
                )
        except (TypeError, ValueError) as error:
            raise GotaWorkerResultError(
                "Stored Gota Worker result is not JSON-serializable"
            ) from error
        if parsed.run_id != expected_run_id:
            raise GotaWorkerResultError(
                "Stored Gota Worker result run identity is incoherent"
            )
        if parsed.task_id != expected_task_id:
            raise GotaWorkerResultError(
                "Stored Gota Worker result task identity is incoherent"
            )
        return parsed, canonical_payload

    @staticmethod
    def _stored_review_result(
        row: sqlite3.Row,
        *,
        expected_run_id: str,
        expected_task_id: str,
    ) -> tuple[GotaReviewResult, dict[str, Any]]:
        """Verify ledger integrity and parse one stored ReviewResult."""

        try:
            created_at_value = row["created_at"]
            created_at = parse_datetime(created_at_value)
            payload = json.loads(row["payload_json"])
            if type(payload) is not dict:
                raise GotaReviewResultError(
                    "Stored Gota Review result payload is not an object"
                )
            if _digest(payload) != row["digest"]:
                raise GotaReviewResultError(
                    "Stored Gota Review result failed its digest check"
                )
            parsed = parse_gota_payload(payload)
            if type(parsed) is not GotaReviewResult:
                raise GotaReviewResultError(
                    "Stored Gota evidence is not a ReviewResult"
                )
            canonical_payload = parsed.to_payload()
            if _canonical_json(canonical_payload) != row["payload_json"]:
                raise GotaReviewResultError(
                    "Stored Gota Review result is not canonical"
                )
            if (
                type(row["created_at"]) is not str
                or isoformat(created_at) != created_at_value
            ):
                raise GotaReviewResultError(
                    "Stored Gota Review result timestamp is not canonical"
                )
        except GotaReviewResultError:
            raise
        except Exception as error:
            raise GotaReviewResultError(
                "Stored Gota Review result is invalid"
            ) from error
        if parsed.run_id != expected_run_id:
            raise GotaReviewResultError(
                "Stored Gota Review result run identity is incoherent"
            )
        if parsed.task_id != expected_task_id:
            raise GotaReviewResultError(
                "Stored Gota Review result task identity is incoherent"
            )
        return parsed, canonical_payload

    @staticmethod
    def _stored_worker_commit_verified(
        row: sqlite3.Row,
        *,
        expected_run_id: str,
        expected_task_id: str,
    ) -> tuple[Evidence, dict[str, Any]]:
        """Verify one persisted Worker commit-verification authority."""

        required = {
            "request_id",
            "task_id",
            "run_id",
            "attempt",
            "base_sha",
            "commit_sha",
            "changed_paths",
            "branch",
            "head",
            "status",
            "refs",
            "request_evidence_id",
            "invocation_evidence_id",
            "result_evidence_id",
        }
        try:
            parse_datetime(row["created_at"])
            payload = json.loads(row["payload_json"])
            if type(payload) is not dict or set(payload) != required:
                raise GotaWorkerReviewBoundaryError(
                    "Stored Gota Worker commit verification has invalid fields"
                )
            if _digest(payload) != row["digest"]:
                raise GotaWorkerReviewBoundaryError(
                    "Stored Gota Worker commit verification failed its digest check"
                )
            if _canonical_json(payload) != row["payload_json"]:
                raise GotaWorkerReviewBoundaryError(
                    "Stored Gota Worker commit verification is not canonical"
                )
            if (
                type(payload["request_id"]) is not str
                or payload["request_id"]
                != f"{payload['run_id']}:{payload['attempt']}:worker"
                or type(payload["task_id"]) is not str
                or type(payload["run_id"]) is not str
                or type(payload["attempt"]) is not int
                or payload["attempt"] < 1
                or type(payload["base_sha"]) is not str
                or re.fullmatch(r"[0-9a-f]{40}", payload["base_sha"]) is None
                or type(payload["commit_sha"]) is not str
                or re.fullmatch(r"[0-9a-f]{40}", payload["commit_sha"]) is None
                or type(payload["head"]) is not str
                or re.fullmatch(r"[0-9a-f]{40}", payload["head"]) is None
                or payload["head"] != payload["commit_sha"]
                or type(payload["branch"]) is not str
                or not payload["branch"]
                or type(payload["status"]) is not str
                or payload["status"] != ""
                or type(payload["changed_paths"]) is not list
                or not payload["changed_paths"]
                or any(
                    type(path) is not str or not path
                    for path in payload["changed_paths"]
                )
                or payload["changed_paths"] != sorted(payload["changed_paths"])
                or type(payload["refs"]) is not list
                or any(
                    type(ref) is not list
                    or len(ref) != 3
                    or type(ref[0]) is not str
                    or not ref[0]
                    or type(ref[1]) is not str
                    or not ref[1]
                    or type(ref[2]) is not str
                    for ref in payload["refs"]
                )
                or payload["refs"]
                != sorted(payload["refs"], key=lambda ref: tuple(ref))
                or any(
                    type(payload[evidence_id]) is not str
                    or not payload[evidence_id]
                    for evidence_id in (
                        "request_evidence_id",
                        "invocation_evidence_id",
                        "result_evidence_id",
                    )
                )
            ):
                raise GotaWorkerReviewBoundaryError(
                    "Stored Gota Worker commit verification has non-canonical values"
                )
        except GotaWorkerReviewBoundaryError:
            raise
        except (TypeError, ValueError, json.JSONDecodeError) as error:
            raise GotaWorkerReviewBoundaryError(
                "Stored Gota Worker commit verification is invalid"
            ) from error

        if (
            payload["run_id"] != expected_run_id
            or payload["task_id"] != expected_task_id
        ):
            raise GotaWorkerReviewBoundaryError(
                "Stored Gota Worker commit verification identity is incoherent"
            )
        return (
            SQLiteCoordinatorStore._evidence_from_row(row, payload),
            payload,
        )

    @staticmethod
    def _worker_commit_identity_payload(
        request: GotaRequest,
        result: GotaWorkerResult,
        *,
        request_evidence_id: str,
        invocation_evidence_id: str,
        result_evidence_id: str,
    ) -> dict[str, Any]:
        """Build the durable, independently observed Worker frontier identity."""

        return {
            "request_id": request.request_id,
            "task_id": request.task_id,
            "run_id": request.run_id,
            "attempt": request.attempt,
            "base_sha": request.base_sha,
            "commit_sha": result.commit_sha,
            "changed_paths": list(sorted(result.changed_paths)),
            "branch": request.branch,
            "head": result.commit_sha,
            "status": "",
            "request_evidence_id": request_evidence_id,
            "invocation_evidence_id": invocation_evidence_id,
            "result_evidence_id": result_evidence_id,
        }

    @staticmethod
    def _worker_commit_payload(
        identity_payload: Mapping[str, Any],
        observation: Mapping[str, Any],
    ) -> dict[str, Any]:
        """Add the Git ref fingerprint to a validated Worker frontier identity."""

        payload = dict(identity_payload)
        payload["head"] = observation["head"]
        payload["status"] = observation["status"]
        payload["changed_paths"] = list(observation["changed_paths"])
        payload["refs"] = [list(ref) for ref in observation["refs"]]
        return payload

    @staticmethod
    def _validate_worker_review_verification(
        observation: Mapping[str, Any],
        *,
        request: GotaRequest,
        result: GotaWorkerResult,
    ) -> None:
        """Validate the private verifier handoff against durable authority."""

        required = {
            "base_sha",
            "commit_sha",
            "changed_paths",
            "branch",
            "head",
            "status",
            "refs",
        }
        if type(observation) is not dict or set(observation) != required:
            raise GotaWorkerReviewBoundaryError(
                "Git verifier returned a non-canonical observation"
            )
        changed_paths = observation["changed_paths"]
        if (
            type(observation["base_sha"]) is not str
            or type(observation["commit_sha"]) is not str
            or type(observation["head"]) is not str
            or type(observation["branch"]) is not str
            or type(observation["status"]) is not str
            or type(changed_paths) is not tuple
            or any(type(path) is not str for path in changed_paths)
            or observation["base_sha"] != request.base_sha
            or observation["commit_sha"] != result.commit_sha
            or observation["head"] != result.commit_sha
            or observation["branch"] != request.branch
            or observation["status"] != ""
            or tuple(changed_paths) != tuple(sorted(changed_paths))
            or tuple(sorted(changed_paths)) != tuple(sorted(result.changed_paths))
        ):
            raise GotaWorkerReviewBoundaryError(
                "Git verifier observation conflicts with durable Worker authority"
            )
        refs = observation["refs"]
        if type(refs) is not tuple or any(
            type(ref) is not tuple
            or len(ref) != 3
            or any(type(value) is not str for value in ref)
            for ref in refs
        ):
            raise GotaWorkerReviewBoundaryError(
                "Git verifier returned a non-canonical ref snapshot"
            )
        if tuple(refs) != tuple(sorted(refs)):
            raise GotaWorkerReviewBoundaryError(
                "Git verifier returned an unsorted ref snapshot"
            )

    @staticmethod
    def _canonical_worker_request(
        request: GotaRequest,
    ) -> tuple[GotaRequest, dict[str, Any]]:
        """Revalidate one in-memory Worker request through its protocol type."""

        if type(request) is not GotaRequest:
            raise GotaWorkerReservationError(
                "Gota Worker request must be the canonical GotaRequest type"
            )
        try:
            payload = request.to_payload()
            parsed = GotaRequest.from_payload(payload)
            canonical_payload = parsed.to_payload()
            if _canonical_json(canonical_payload) != _canonical_json(payload):
                raise GotaWorkerReservationError(
                    "Gota Worker request payload is not canonical"
                )
        except GotaWorkerReservationError:
            raise
        except Exception as error:
            raise GotaWorkerReservationError(
                "Gota Worker request does not satisfy the canonical protocol"
            ) from error
        if parsed.phase is not GotaPhase.WORKER:
            raise GotaWorkerReservationError(
                "Gota Worker reservation requires a worker-phase request"
            )
        return parsed, canonical_payload

    @staticmethod
    def _request_identity(
        run_id: str,
        attempt: int,
        request_id: str,
    ) -> tuple[str, int, str]:
        if type(run_id) is not str or not run_id.strip():
            raise GotaWorkerReservationError(
                "Gota run identity must be a non-empty string"
            )
        if type(attempt) is not int or attempt < 1:
            raise GotaWorkerReservationError(
                "Gota attempt must be a positive integer"
            )
        if type(request_id) is not str or request_id != f"{run_id}:{attempt}:worker":
            raise GotaWorkerReservationError(
                "Gota Worker request identity is not canonical"
            )
        return run_id, attempt, request_id

    @staticmethod
    def _review_request_identity(
        run_id: str,
        attempt: int,
        request_id: str,
    ) -> tuple[str, int, str]:
        if type(run_id) is not str or not run_id.strip():
            raise GotaReviewResultError(
                "Gota run identity must be a non-empty string"
            )
        if type(attempt) is not int or attempt < 1:
            raise GotaReviewResultError(
                "Gota attempt must be a positive integer"
            )
        if type(request_id) is not str or request_id != f"{run_id}:{attempt}:review":
            raise GotaReviewResultError(
                "Gota Review request identity is not canonical"
            )
        return run_id, attempt, request_id

    @staticmethod
    def _stored_worker_request(
        row: sqlite3.Row,
        *,
        expected_run_id: str,
        expected_task_id: str,
    ) -> tuple[GotaRequest, dict[str, Any]]:
        """Verify one persisted canonical Worker request authority."""

        try:
            parse_datetime(row["created_at"])
            payload = json.loads(row["payload_json"])
            if type(payload) is not dict:
                raise GotaWorkerReservationError(
                    "Stored Gota Worker request payload is not an object"
                )
            if _digest(payload) != row["digest"]:
                raise GotaWorkerReservationError(
                    "Stored Gota Worker request failed its digest check"
                )
            parsed = GotaRequest.from_payload(payload)
            if parsed.phase is not GotaPhase.WORKER:
                raise GotaWorkerReservationError(
                    "Stored Gota Worker request is not a worker-phase request"
                )
            canonical_payload = parsed.to_payload()
            if _canonical_json(canonical_payload) != row["payload_json"]:
                raise GotaWorkerReservationError(
                    "Stored Gota Worker request is not canonical"
                )
        except GotaWorkerReservationError:
            raise
        except Exception as error:
            raise GotaWorkerReservationError(
                "Stored Gota Worker request is invalid"
            ) from error
        if parsed.run_id != expected_run_id:
            raise GotaWorkerReservationError(
                "Stored Gota Worker request run identity is incoherent"
            )
        if parsed.task_id != expected_task_id:
            raise GotaWorkerReservationError(
                "Stored Gota Worker request task identity is incoherent"
            )
        return parsed, canonical_payload

    @staticmethod
    def _stored_worker_invocation_marker(
        row: sqlite3.Row,
        *,
        expected_run_id: str,
        expected_task_id: str,
    ) -> dict[str, Any]:
        """Verify one persisted invocation-start authority."""

        required = {
            "request_evidence_id",
            "request_digest",
            "request_id",
            "task_id",
            "run_id",
            "attempt",
        }
        try:
            parse_datetime(row["created_at"])
            payload = json.loads(row["payload_json"])
            if type(payload) is not dict or set(payload) != required:
                raise GotaWorkerReservationError(
                    "Stored Gota Worker invocation marker has invalid fields"
                )
            if _digest(payload) != row["digest"]:
                raise GotaWorkerReservationError(
                    "Stored Gota Worker invocation marker failed its digest check"
                )
            if (
                type(payload["request_evidence_id"]) is not str
                or not payload["request_evidence_id"].strip()
                or type(payload["request_digest"]) is not str
                or re.fullmatch(r"[0-9a-f]{64}", payload["request_digest"])
                is None
                or type(payload["request_id"]) is not str
                or type(payload["task_id"]) is not str
                or type(payload["run_id"]) is not str
                or type(payload["attempt"]) is not int
                or payload["attempt"] < 1
            ):
                raise GotaWorkerReservationError(
                    "Stored Gota Worker invocation marker has non-canonical values"
                )
            if _canonical_json(payload) != row["payload_json"]:
                raise GotaWorkerReservationError(
                    "Stored Gota Worker invocation marker is not canonical"
                )
        except GotaWorkerReservationError:
            raise
        except Exception as error:
            raise GotaWorkerReservationError(
                "Stored Gota Worker invocation marker is invalid"
            ) from error
        if (
            payload["run_id"] != expected_run_id
            or payload["task_id"] != expected_task_id
        ):
            raise GotaWorkerReservationError(
                "Stored Gota Worker invocation marker identity is incoherent"
            )
        return payload

    def _load_gota_worker_reservation(
        self,
        connection: sqlite3.Connection,
        *,
        run_id: str,
        task_id: str,
        attempt: int,
        request_id: str,
    ) -> GotaWorkerInvocationReservation | None:
        """Load and cross-check every reservation authority for one run."""

        request_rows = connection.execute(
            """
            SELECT * FROM evidence
            WHERE run_id = ? AND kind = ?
            ORDER BY rowid
            """,
            (run_id, "gota_worker_request_registered"),
        ).fetchall()
        request_authorities: dict[
            tuple[int, str], tuple[sqlite3.Row, GotaRequest, dict[str, Any]]
        ] = {}
        for row in request_rows:
            parsed, payload = self._stored_worker_request(
                row,
                expected_run_id=run_id,
                expected_task_id=task_id,
            )
            key = (parsed.attempt, parsed.request_id)
            if key in request_authorities:
                raise GotaWorkerReservationError(
                    "Multiple durable Gota Worker requests make the run ambiguous"
                )
            request_authorities[key] = (row, parsed, payload)

        marker_rows = connection.execute(
            """
            SELECT * FROM evidence
            WHERE run_id = ? AND kind = ?
            ORDER BY rowid
            """,
            (run_id, "gota_worker_invocation_started"),
        ).fetchall()
        marker_authorities: dict[tuple[int, str], tuple[sqlite3.Row, dict[str, Any]]] = {}
        for row in marker_rows:
            payload = self._stored_worker_invocation_marker(
                row,
                expected_run_id=run_id,
                expected_task_id=task_id,
            )
            key = (payload["attempt"], payload["request_id"])
            if key in marker_authorities:
                raise GotaWorkerReservationError(
                    "Multiple durable Gota Worker invocation markers make the run ambiguous"
                )
            marker_authorities[key] = (row, payload)

        if set(request_authorities) != set(marker_authorities):
            raise GotaWorkerReservationError(
                "Gota Worker request and invocation authorities are not paired"
            )
        for key, (marker_row, marker_payload) in marker_authorities.items():
            request_row, _request, request_payload = request_authorities[key]
            try:
                matching_fence = int(marker_row["fencing_token"]) == int(
                    request_row["fencing_token"]
                )
            except (TypeError, ValueError) as error:
                raise GotaWorkerReservationError(
                    "Gota Worker authority fencing token is invalid"
                ) from error
            if (
                marker_payload["request_evidence_id"] != request_row["evidence_id"]
                or marker_payload["request_digest"] != request_row["digest"]
                or not matching_fence
            ):
                raise GotaWorkerReservationError(
                    "Gota Worker invocation marker is not linked to its request authority"
                )
            if marker_payload["request_digest"] != _digest(request_payload):
                raise GotaWorkerReservationError(
                    "Gota Worker request authority digest is incoherent"
                )

        requested_key = (attempt, request_id)
        authority = request_authorities.get(requested_key)
        if authority is None:
            return None
        request_row, request, _request_payload = authority
        marker_row, marker_payload = marker_authorities[requested_key]
        return GotaWorkerInvocationReservation(
            request=request,
            request_evidence=self._evidence_from_row(
                request_row, request.to_payload()
            ),
            invocation_evidence=self._evidence_from_row(marker_row, marker_payload),
            created=False,
        )

    def reserve_gota_worker_invocation(
        self,
        run_id: str,
        request: GotaRequest,
        lease: Lease,
    ) -> GotaWorkerInvocationReservation:
        """Atomically register a complete Worker request and its start marker."""

        canonical_request, request_payload = self._canonical_worker_request(request)
        self._request_identity(
            run_id, canonical_request.attempt, canonical_request.request_id
        )
        if canonical_request.run_id != run_id:
            raise GotaWorkerReservationError(
                "Gota Worker request run identity does not match the requested run"
            )
        if lease.run_id != run_id:
            raise FencingTokenError(
                f"Lease run {lease.run_id} does not match Gota run {run_id}"
            )

        trusted_now = self._trusted_now()
        with self.fenced_transaction(lease, now=trusted_now) as connection:
            run_row = connection.execute(
                "SELECT task_id, state FROM task_runs WHERE run_id = ?",
                (run_id,),
            ).fetchone()
            if run_row is None:
                raise KeyError(run_id)
            task_id = run_row["task_id"]
            if canonical_request.task_id != task_id:
                raise GotaWorkerReservationError(
                    "Gota Worker request task identity does not match the run"
                )
            try:
                state = TaskState(run_row["state"])
            except ValueError as error:
                raise GotaWorkerReservationError(
                    "Gota run has an unknown task state"
                ) from error
            if state not in {TaskState.RUNNING, TaskState.REVIEW}:
                raise GotaWorkerReservationError(
                    "Gota Worker reservation requires a RUNNING or REVIEW task"
                )

            existing = self._load_gota_worker_reservation(
                connection,
                run_id=run_id,
                task_id=task_id,
                attempt=canonical_request.attempt,
                request_id=canonical_request.request_id,
            )
            if existing is not None:
                if _canonical_json(existing.request.to_payload()) != _canonical_json(
                    request_payload
                ):
                    raise GotaWorkerReservationError(
                        "A different Gota Worker request already exists for this attempt"
                    )
                return existing

            if state is not TaskState.RUNNING:
                raise GotaWorkerReservationError(
                    "A new Gota Worker reservation requires a RUNNING task"
                )

            result_rows = connection.execute(
                """
                SELECT * FROM evidence
                WHERE run_id = ? AND kind = ?
                ORDER BY rowid
                """,
                (run_id, "gota_worker_result_received"),
            ).fetchall()
            if result_rows:
                if len(result_rows) != 1:
                    raise GotaWorkerReservationError(
                        "Multiple durable Worker results prevent a new Gota reservation"
                    )
                existing_result, _result_payload = self._stored_worker_result(
                    result_rows[0],
                    expected_run_id=run_id,
                    expected_task_id=task_id,
                )
                if (
                    existing_result.attempt == canonical_request.attempt
                    and existing_result.request_id == canonical_request.request_id
                ):
                    raise GotaWorkerReservationError(
                        "A durable WorkerResult exists without its reservation"
                    )
                raise GotaWorkerReservationError(
                    "A durable WorkerResult already exists for this run"
                )

            request_evidence = self._insert_evidence(
                connection,
                run_id,
                "gota_worker_request_registered",
                request_payload,
                lease,
                trusted_now,
            )
            marker_payload = {
                "request_evidence_id": request_evidence.evidence_id,
                "request_digest": request_evidence.digest,
                "request_id": canonical_request.request_id,
                "task_id": canonical_request.task_id,
                "run_id": canonical_request.run_id,
                "attempt": canonical_request.attempt,
            }
            invocation_evidence = self._insert_evidence(
                connection,
                run_id,
                "gota_worker_invocation_started",
                marker_payload,
                lease,
                trusted_now,
            )
            return GotaWorkerInvocationReservation(
                request=canonical_request,
                request_evidence=request_evidence,
                invocation_evidence=invocation_evidence,
                created=True,
            )

    def load_gota_worker_invocation(
        self,
        run_id: str,
        attempt: int,
        request_id: str,
    ) -> GotaWorkerInvocationReservation | None:
        """Load one complete reservation, or return ``None`` when absent."""

        self._request_identity(run_id, attempt, request_id)
        with closing(self._connect()) as connection:
            run_row = connection.execute(
                "SELECT task_id FROM task_runs WHERE run_id = ?", (run_id,)
            ).fetchone()
            if run_row is None:
                raise KeyError(run_id)
            return self._load_gota_worker_reservation(
                connection,
                run_id=run_id,
                task_id=run_row["task_id"],
                attempt=attempt,
                request_id=request_id,
            )

    def load_gota_worker_request(
        self,
        run_id: str,
        attempt: int,
        request_id: str,
    ) -> GotaRequest | None:
        """Load the complete canonical request behind one reservation."""

        reservation = self.load_gota_worker_invocation(run_id, attempt, request_id)
        return reservation.request if reservation is not None else None

    def has_gota_worker_invocation(
        self,
        run_id: str,
        attempt: int,
        request_id: str,
    ) -> bool:
        """Return whether one intact Worker invocation reservation exists."""

        return self.load_gota_worker_invocation(run_id, attempt, request_id) is not None

    @staticmethod
    def _evidence_from_row(
        row: sqlite3.Row, payload: Mapping[str, Any]
    ) -> Evidence:
        return Evidence(
            evidence_id=row["evidence_id"],
            run_id=row["run_id"],
            kind=row["kind"],
            payload=dict(payload),
            digest=row["digest"],
            created_at=parse_datetime(row["created_at"]),
        )

    @staticmethod
    def _coherent_historical_fencing_token(
        rows: Sequence[sqlite3.Row],
        *,
        error_type: type[CoordinatorStoreError],
        context: str,
    ) -> int:
        """Return the one fence shared by authorities created as one frontier."""

        tokens = [row["fencing_token"] for row in rows]
        if any(type(token) is not int or token < 1 for token in tokens):
            raise error_type(f"{context} fencing token is invalid")
        if len(set(tokens)) != 1:
            raise error_type(f"{context} authorities disagree on fencing")
        return tokens[0]

    def persist_gota_worker_result(
        self,
        run_id: str,
        result: GotaWorkerResult,
        lease: Lease,
    ) -> Evidence:
        """Persist one complete canonical WorkerResult as immutable authority.

        The result payload is stored in the existing evidence ledger. The
        ledger-generated evidence ID, digest, fencing token, and trusted
        timestamp are never accepted from the caller.
        """

        if type(run_id) is not str or not run_id.strip():
            raise GotaWorkerResultError("Gota run identity must be a non-empty string")
        if lease.run_id != run_id:
            raise FencingTokenError(
                f"Lease run {lease.run_id} does not match Gota run {run_id}"
            )
        canonical_result, payload = self._canonical_worker_result(result)
        if canonical_result.run_id != run_id:
            raise GotaWorkerResultError(
                "Gota Worker result run identity does not match the requested run"
            )

        trusted_now = self._trusted_now()
        with self.fenced_transaction(lease, now=trusted_now) as connection:
            run_row = connection.execute(
                "SELECT task_id, state FROM task_runs WHERE run_id = ?",
                (run_id,),
            ).fetchone()
            if run_row is None:
                raise KeyError(run_id)
            try:
                state = TaskState(run_row["state"])
            except ValueError as error:
                raise GotaWorkerResultError(
                    "Gota run has an unknown task state"
                ) from error
            if state not in {TaskState.RUNNING, TaskState.REVIEW}:
                raise GotaWorkerResultError(
                    "Gota Worker result requires a RUNNING or REVIEW task"
                )
            task_id = run_row["task_id"]
            if canonical_result.task_id != task_id:
                raise GotaWorkerResultError(
                    "Gota Worker result task identity does not match the run"
                )

            rows = connection.execute(
                """
                SELECT * FROM evidence
                WHERE run_id = ? AND kind = ?
                ORDER BY rowid
                """,
                (run_id, "gota_worker_result_received"),
            ).fetchall()
            if len(rows) > 1:
                raise GotaWorkerResultError(
                    "Multiple durable Gota Worker results make the run ambiguous"
                )
            if rows:
                existing, existing_payload = self._stored_worker_result(
                    rows[0],
                    expected_run_id=run_id,
                    expected_task_id=task_id,
                )
                if _canonical_json(existing_payload) == _canonical_json(payload):
                    return self._evidence_from_row(rows[0], existing_payload)
                raise GotaWorkerResultError(
                    "A different Gota Worker result already exists for the run"
                )

            return self._insert_evidence(
                connection,
                run_id,
                "gota_worker_result_received",
                payload,
                lease,
                trusted_now,
            )

    def load_gota_worker_result(
        self,
        run_id: str,
        attempt: int,
        request_id: str,
    ) -> GotaWorkerResult | None:
        """Load exactly one durable WorkerResult for a requested identity.

        No Git inspection occurs here. Missing evidence is represented by
        ``None``; malformed, tampered, duplicated, or incoherent evidence is
        rejected closed.
        """

        if type(run_id) is not str or not run_id.strip():
            raise GotaWorkerResultError("Gota run identity must be a non-empty string")
        if type(attempt) is not int or attempt < 1:
            raise GotaWorkerResultError("Gota attempt must be a positive integer")
        if type(request_id) is not str or request_id != f"{run_id}:{attempt}:worker":
            raise GotaWorkerResultError(
                "Gota Worker request identity is not canonical"
            )

        with closing(self._connect()) as connection:
            run_row = connection.execute(
                "SELECT task_id FROM task_runs WHERE run_id = ?", (run_id,)
            ).fetchone()
            if run_row is None:
                raise KeyError(run_id)
            rows = connection.execute(
                """
                SELECT * FROM evidence
                WHERE run_id = ? AND kind = ?
                ORDER BY rowid
                """,
                (run_id, "gota_worker_result_received"),
            ).fetchall()
            if not rows:
                return None
            if len(rows) > 1:
                raise GotaWorkerResultError(
                    "Multiple durable Gota Worker results make the run ambiguous"
                )
            result, _payload = self._stored_worker_result(
                rows[0],
                expected_run_id=run_id,
                expected_task_id=run_row["task_id"],
            )
            if result.attempt != attempt or result.request_id != request_id:
                return None
            return result

    def load_gota_worker_commit_verified(
        self,
        run_id: str,
        attempt: int,
        request_id: str,
    ) -> Evidence | None:
        """Load one intact durable Worker commit-verification authority."""

        self._request_identity(run_id, attempt, request_id)
        with closing(self._connect()) as connection:
            run_row = connection.execute(
                "SELECT task_id FROM task_runs WHERE run_id = ?", (run_id,)
            ).fetchone()
            if run_row is None:
                raise KeyError(run_id)
            rows = connection.execute(
                """
                SELECT * FROM evidence
                WHERE run_id = ? AND kind = ?
                ORDER BY rowid
                """,
                (run_id, "gota_worker_commit_verified"),
            ).fetchall()
            if not rows:
                return None
            if len(rows) != 1:
                raise GotaWorkerReviewBoundaryError(
                    "Multiple Gota Worker commit verifications make the run ambiguous"
                )
            evidence, payload = self._stored_worker_commit_verified(
                rows[0],
                expected_run_id=run_id,
                expected_task_id=run_row["task_id"],
            )
            if payload["attempt"] != attempt or payload["request_id"] != request_id:
                raise GotaWorkerReviewBoundaryError(
                    "Stored Gota Worker commit verification does not match the request"
                )
            return evidence

    @staticmethod
    def _stored_gota_worker_review_boundary_anchor(
        row: sqlite3.Row,
        *,
        expected_run_id: str,
        expected_attempt: int,
        expected_request_id: str,
    ) -> GotaWorkerReviewBoundaryAnchor:
        """Validate the canonical fields of one durable Gota boundary anchor."""

        try:
            created_at_value = row["created_at"]
            created_at = parse_datetime(created_at_value)
            if (
                type(row["run_id"]) is not str
                or row["run_id"] != expected_run_id
                or type(row["attempt"]) is not int
                or row["attempt"] != expected_attempt
                or type(row["request_id"]) is not str
                or row["request_id"] != expected_request_id
                or type(row["commit_evidence_id"]) is not str
                or not row["commit_evidence_id"]
                or type(row["commit_evidence_digest"]) is not str
                or re.fullmatch(r"[0-9a-f]{64}", row["commit_evidence_digest"])
                is None
                or type(row["transition_event_id"]) is not int
                or row["transition_event_id"] < 1
                or type(created_at_value) is not str
                or isoformat(created_at) != created_at_value
            ):
                raise GotaWorkerReviewBoundaryError(
                    "Gota Worker review boundary anchor has non-canonical values"
                )
        except GotaWorkerReviewBoundaryError:
            raise
        except (TypeError, ValueError, KeyError) as error:
            raise GotaWorkerReviewBoundaryError(
                "Gota Worker review boundary anchor is malformed"
            ) from error
        return GotaWorkerReviewBoundaryAnchor(
            run_id=expected_run_id,
            attempt=expected_attempt,
            request_id=expected_request_id,
            commit_evidence_id=row["commit_evidence_id"],
            commit_evidence_digest=row["commit_evidence_digest"],
            transition_event_id=row["transition_event_id"],
            created_at=created_at,
        )

    def _load_gota_worker_review_boundary_anchor(
        self,
        connection: sqlite3.Connection,
        *,
        run_id: str,
        attempt: int,
        request_id: str,
    ) -> GotaWorkerReviewBoundaryAnchor:
        rows = connection.execute(
            """
            SELECT * FROM gota_worker_review_boundaries
            WHERE run_id = ? AND attempt = ? AND request_id = ?
            ORDER BY rowid
            """,
            (run_id, attempt, request_id),
        ).fetchall()
        if len(rows) != 1:
            raise GotaWorkerReviewBoundaryError(
                "REVIEW requires exactly one Gota Worker boundary anchor"
            )
        return self._stored_gota_worker_review_boundary_anchor(
            rows[0],
            expected_run_id=run_id,
            expected_attempt=attempt,
            expected_request_id=request_id,
        )

    @staticmethod
    def _validate_gota_worker_review_boundary_links(
        connection: sqlite3.Connection,
        anchor: GotaWorkerReviewBoundaryAnchor,
        *,
        commit_evidence_row: sqlite3.Row,
        expected_fencing_token: int | None,
        expected_actor: str | None,
    ) -> None:
        """Validate the anchor's exact evidence and transition-event links."""

        evidence_rows = connection.execute(
            "SELECT * FROM evidence WHERE evidence_id = ?",
            (anchor.commit_evidence_id,),
        ).fetchall()
        if len(evidence_rows) != 1:
            raise GotaWorkerReviewBoundaryError(
                "Gota Worker review boundary anchor points to missing evidence"
            )
        evidence_row = evidence_rows[0]
        if (
            evidence_row["evidence_id"] != commit_evidence_row["evidence_id"]
            or evidence_row["evidence_id"] != anchor.commit_evidence_id
            or evidence_row["run_id"] != anchor.run_id
            or evidence_row["kind"] != "gota_worker_commit_verified"
            or evidence_row["digest"] != anchor.commit_evidence_digest
            or commit_evidence_row["digest"] != anchor.commit_evidence_digest
        ):
            raise GotaWorkerReviewBoundaryError(
                "Gota Worker review boundary anchor evidence link is incoherent"
            )

        try:
            evidence_created_at = parse_datetime(evidence_row["created_at"])
            if (
                type(evidence_row["created_at"]) is not str
                or isoformat(evidence_created_at) != evidence_row["created_at"]
                or evidence_created_at != anchor.created_at
            ):
                raise GotaWorkerReviewBoundaryError(
                    "Gota Worker review boundary anchor timestamp disagrees with evidence"
                )
        except GotaWorkerReviewBoundaryError:
            raise
        except (TypeError, ValueError) as error:
            raise GotaWorkerReviewBoundaryError(
                "Gota Worker review boundary evidence timestamp is malformed"
            ) from error

        event_rows = connection.execute(
            "SELECT * FROM transition_events WHERE event_id = ?",
            (anchor.transition_event_id,),
        ).fetchall()
        if len(event_rows) != 1:
            raise GotaWorkerReviewBoundaryError(
                "Gota Worker review boundary anchor points to missing transition event"
            )
        event_row = event_rows[0]
        try:
            event_created_at = parse_datetime(event_row["created_at"])
            fencing_token = event_row["fencing_token"]
            evidence_fencing_token = evidence_row["fencing_token"]
            if (
                event_row["run_id"] != anchor.run_id
                or event_row["from_state"] != TaskState.RUNNING.value
                or event_row["to_state"] != TaskState.REVIEW.value
                or event_row["reason"] != "gota_worker_commit_verified"
                or type(event_row["actor"]) is not str
                or not event_row["actor"]
                or type(fencing_token) is not int
                or fencing_token < 1
                or type(evidence_fencing_token) is not int
                or evidence_fencing_token < 1
                or fencing_token != evidence_fencing_token
                or event_created_at != anchor.created_at
                or type(event_row["created_at"]) is not str
                or isoformat(event_created_at) != event_row["created_at"]
                or (
                    expected_fencing_token is not None
                    and fencing_token != expected_fencing_token
                )
                or (expected_actor is not None and event_row["actor"] != expected_actor)
            ):
                raise GotaWorkerReviewBoundaryError(
                    "Gota Worker review boundary transition event is incoherent"
                )
        except GotaWorkerReviewBoundaryError:
            raise
        except (TypeError, ValueError, KeyError) as error:
            raise GotaWorkerReviewBoundaryError(
                "Gota Worker review boundary transition event is malformed"
            ) from error

    def load_gota_worker_review_boundary(
        self,
        run_id: str,
        attempt: int,
        request_id: str,
    ) -> GotaWorkerReviewBoundaryAnchor:
        """Load and validate the durable Gota Worker-to-Review anchor."""

        self._request_identity(run_id, attempt, request_id)
        with closing(self._connect()) as connection:
            run_row = connection.execute(
                "SELECT task_id FROM task_runs WHERE run_id = ?", (run_id,)
            ).fetchone()
            if run_row is None:
                raise KeyError(run_id)
            anchor = self._load_gota_worker_review_boundary_anchor(
                connection,
                run_id=run_id,
                attempt=attempt,
                request_id=request_id,
            )
            commit_rows = connection.execute(
                "SELECT * FROM evidence WHERE evidence_id = ?",
                (anchor.commit_evidence_id,),
            ).fetchall()
            if len(commit_rows) != 1:
                raise GotaWorkerReviewBoundaryError(
                    "Gota Worker review boundary anchor points to missing evidence"
                )
            _evidence, payload = self._stored_worker_commit_verified(
                commit_rows[0],
                expected_run_id=run_id,
                expected_task_id=run_row["task_id"],
            )
            if payload["attempt"] != attempt or payload["request_id"] != request_id:
                raise GotaWorkerReviewBoundaryError(
                    "Gota Worker review boundary evidence identity is incoherent"
                )
            self._validate_gota_worker_review_boundary_links(
                connection,
                anchor,
                commit_evidence_row=commit_rows[0],
                expected_fencing_token=None,
                expected_actor=None,
            )
            return anchor

    @staticmethod
    def _stored_gota_review_result_anchor(
        row: sqlite3.Row,
        *,
        expected_run_id: str,
        expected_attempt: int,
        expected_request_id: str,
    ) -> GotaReviewResultAnchor:
        """Validate the canonical fields of one ReviewResult anchor."""

        try:
            created_at_value = row["created_at"]
            created_at = parse_datetime(created_at_value)
            if (
                type(row["run_id"]) is not str
                or row["run_id"] != expected_run_id
                or type(row["attempt"]) is not int
                or row["attempt"] != expected_attempt
                or type(row["request_id"]) is not str
                or row["request_id"] != expected_request_id
                or type(row["review_evidence_id"]) is not str
                or not row["review_evidence_id"]
                or type(row["review_evidence_digest"]) is not str
                or re.fullmatch(r"[0-9a-f]{64}", row["review_evidence_digest"])
                is None
                or type(row["worker_commit_evidence_id"]) is not str
                or not row["worker_commit_evidence_id"]
                or type(created_at_value) is not str
                or isoformat(created_at) != created_at_value
            ):
                raise GotaReviewResultError(
                    "Gota Review result anchor has non-canonical values"
                )
        except GotaReviewResultError:
            raise
        except (TypeError, ValueError, KeyError) as error:
            raise GotaReviewResultError(
                "Gota Review result anchor is malformed"
            ) from error
        return GotaReviewResultAnchor(
            run_id=expected_run_id,
            attempt=expected_attempt,
            request_id=expected_request_id,
            review_evidence_id=row["review_evidence_id"],
            review_evidence_digest=row["review_evidence_digest"],
            worker_commit_evidence_id=row["worker_commit_evidence_id"],
            created_at=created_at,
        )

    def _load_gota_review_result_anchor(
        self,
        connection: sqlite3.Connection,
        *,
        run_id: str,
        attempt: int,
        request_id: str,
    ) -> GotaReviewResultAnchor:
        rows = connection.execute(
            """
            SELECT * FROM gota_review_results
            WHERE run_id = ?
            ORDER BY rowid
            """,
            (run_id,),
        ).fetchall()
        if len(rows) != 1:
            raise GotaReviewResultError(
                "REVIEW requires exactly one Gota Review result anchor"
            )
        return self._stored_gota_review_result_anchor(
            rows[0],
            expected_run_id=run_id,
            expected_attempt=attempt,
            expected_request_id=request_id,
        )

    def load_gota_review_result_anchor(
        self,
        run_id: str,
        attempt: int,
        request_id: str,
    ) -> GotaReviewResultAnchor:
        """Load and validate the independent ReviewResult anchor."""

        self._review_request_identity(run_id, attempt, request_id)
        worker_request_id = f"{run_id}:{attempt}:worker"
        with closing(self._connect()) as connection:
            task_id, _request, worker_result, _result_row, commit_row, _worker_anchor, _reservation = self._load_gota_review_frontier(
                connection,
                run_id=run_id,
                attempt=attempt,
                request_id=worker_request_id,
            )
            review_rows = connection.execute(
                """
                SELECT * FROM evidence
                WHERE run_id = ? AND kind = ?
                ORDER BY rowid
                """,
                (run_id, "gota_review_result"),
            ).fetchall()
            if len(review_rows) != 1:
                raise GotaReviewResultError(
                    "REVIEW requires exactly one Gota Review result evidence record"
                )
            review_row = review_rows[0]
            result, _payload = self._stored_review_result(
                review_row,
                expected_run_id=run_id,
                expected_task_id=task_id,
            )
            if (
                result.attempt != attempt
                or result.request_id != request_id
                or result.reviewed_commit_sha != worker_result.commit_sha
            ):
                raise GotaReviewResultError(
                    "Stored Gota Review result identity or Worker SHA is incoherent"
                )
            anchor = self._load_gota_review_result_anchor(
                connection,
                run_id=run_id,
                attempt=attempt,
                request_id=request_id,
            )
            self._validate_gota_review_result_anchor_links(
                connection,
                anchor,
                review_evidence_row=review_row,
                worker_commit_evidence_row=commit_row,
            )
            return anchor

    @staticmethod
    def _validate_gota_review_result_anchor_links(
        connection: sqlite3.Connection,
        anchor: GotaReviewResultAnchor,
        *,
        review_evidence_row: sqlite3.Row,
        worker_commit_evidence_row: sqlite3.Row,
    ) -> None:
        """Validate the ReviewResult anchor's exact evidence links."""

        review_rows = connection.execute(
            "SELECT * FROM evidence WHERE evidence_id = ?",
            (anchor.review_evidence_id,),
        ).fetchall()
        if len(review_rows) != 1:
            raise GotaReviewResultError(
                "Gota Review result anchor points to missing evidence"
            )
        review_row = review_rows[0]
        if (
            review_row["evidence_id"] != review_evidence_row["evidence_id"]
            or review_row["evidence_id"] != anchor.review_evidence_id
            or review_row["run_id"] != anchor.run_id
            or review_row["kind"] != "gota_review_result"
            or review_row["digest"] != anchor.review_evidence_digest
            or review_evidence_row["digest"] != anchor.review_evidence_digest
        ):
            raise GotaReviewResultError(
                "Gota Review result anchor evidence link is incoherent"
            )

        try:
            review_created_at = parse_datetime(review_row["created_at"])
            if (
                type(review_row["created_at"]) is not str
                or isoformat(review_created_at) != review_row["created_at"]
                or review_created_at != anchor.created_at
            ):
                raise GotaReviewResultError(
                    "Gota Review result anchor timestamp disagrees with evidence"
                )
        except GotaReviewResultError:
            raise
        except (TypeError, ValueError) as error:
            raise GotaReviewResultError(
                "Gota Review result evidence timestamp is malformed"
            ) from error

        worker_commit_rows = connection.execute(
            "SELECT * FROM evidence WHERE evidence_id = ?",
            (anchor.worker_commit_evidence_id,),
        ).fetchall()
        if len(worker_commit_rows) != 1:
            raise GotaReviewResultError(
                "Gota Review result anchor points to missing Worker commit evidence"
            )
        worker_commit_row = worker_commit_rows[0]
        if (
            worker_commit_row["evidence_id"]
            != worker_commit_evidence_row["evidence_id"]
            or worker_commit_row["evidence_id"]
            != anchor.worker_commit_evidence_id
            or worker_commit_row["run_id"] != anchor.run_id
            or worker_commit_row["kind"] != "gota_worker_commit_verified"
        ):
            raise GotaReviewResultError(
                "Gota Review result anchor Worker commit link is incoherent"
            )
        if (
            type(review_row["fencing_token"]) is not int
            or type(worker_commit_row["fencing_token"]) is not int
            or review_row["fencing_token"] < 1
            or worker_commit_row["fencing_token"] < 1
        ):
            raise GotaReviewResultError(
                "Gota Review result authority fencing is malformed"
            )

    def _load_gota_review_frontier(
        self,
        connection: sqlite3.Connection,
        *,
        run_id: str,
        attempt: int,
        request_id: str,
    ) -> tuple[
        str,
        GotaRequest,
        GotaWorkerResult,
        sqlite3.Row,
        sqlite3.Row,
        GotaWorkerReviewBoundaryAnchor,
        GotaWorkerInvocationReservation,
    ]:
        """Load and cross-check the complete durable Worker-to-Review frontier."""

        run_row = connection.execute(
            "SELECT task_id, state FROM task_runs WHERE run_id = ?",
            (run_id,),
        ).fetchone()
        if run_row is None:
            raise KeyError(run_id)
        if TaskState(run_row["state"]) is not TaskState.REVIEW:
            raise GotaReviewResultError(
                "Gota Review result requires a REVIEW task"
            )
        task_id = run_row["task_id"]
        reservation = self._load_gota_worker_reservation(
            connection,
            run_id=run_id,
            task_id=task_id,
            attempt=attempt,
            request_id=request_id,
        )
        if reservation is None:
            raise GotaReviewResultError(
                "Durable Worker request and invocation reservation are required"
            )
        request = reservation.request
        if (
            request.run_id != run_id
            or request.task_id != task_id
            or request.attempt != attempt
            or request.request_id != request_id
        ):
            raise GotaReviewResultError(
                "Durable Worker request identity is incoherent"
            )

        result_rows = connection.execute(
            """
            SELECT * FROM evidence
            WHERE run_id = ? AND kind = ?
            ORDER BY rowid
            """,
            (run_id, "gota_worker_result_received"),
        ).fetchall()
        if len(result_rows) != 1:
            raise GotaReviewResultError(
                "Exactly one durable WorkerResult is required"
            )
        result_row = result_rows[0]
        worker_result, _result_payload = self._stored_worker_result(
            result_row,
            expected_run_id=run_id,
            expected_task_id=task_id,
        )
        if (
            worker_result.request_id != request_id
            or worker_result.attempt != attempt
            or worker_result.result is not WorkerResultStatus.READY_FOR_REVIEW
        ):
            raise GotaReviewResultError(
                "Durable WorkerResult identity or status is incoherent"
            )

        authority_ids = (
            reservation.request_evidence.evidence_id,
            reservation.invocation_evidence.evidence_id,
            result_row["evidence_id"],
        )
        authority_rows = connection.execute(
            """
            SELECT evidence_id, fencing_token
            FROM evidence
            WHERE evidence_id IN (?, ?, ?)
            """,
            authority_ids,
        ).fetchall()
        if len(authority_rows) != len(authority_ids):
            raise GotaReviewResultError(
                "Durable Worker authorities are incomplete"
            )
        historical_fencing_token = self._coherent_historical_fencing_token(
            authority_rows,
            error_type=GotaReviewResultError,
            context="Durable Worker",
        )

        commit_rows = connection.execute(
            """
            SELECT * FROM evidence
            WHERE run_id = ? AND kind = ?
            ORDER BY rowid
            """,
            (run_id, "gota_worker_commit_verified"),
        ).fetchall()
        if len(commit_rows) != 1:
            raise GotaReviewResultError(
                "Exactly one durable Worker commit verification is required"
            )
        commit_row = commit_rows[0]
        _commit_evidence, commit_payload = self._stored_worker_commit_verified(
            commit_row,
            expected_run_id=run_id,
            expected_task_id=task_id,
        )
        expected_commit_identity = self._worker_commit_identity_payload(
            request,
            worker_result,
            request_evidence_id=authority_ids[0],
            invocation_evidence_id=authority_ids[1],
            result_evidence_id=authority_ids[2],
        )
        if any(
            commit_payload[field] != value
            for field, value in expected_commit_identity.items()
        ):
            raise GotaReviewResultError(
                "Persisted Worker commit verification is incoherent"
            )
        if (
            type(commit_row["fencing_token"]) is not int
            or commit_row["fencing_token"] != historical_fencing_token
        ):
            raise GotaReviewResultError(
                "Worker commit verification fencing is incoherent"
            )

        anchor = self._load_gota_worker_review_boundary_anchor(
            connection,
            run_id=run_id,
            attempt=attempt,
            request_id=request_id,
        )
        self._validate_gota_worker_review_boundary_links(
            connection,
            anchor,
            commit_evidence_row=commit_row,
            expected_fencing_token=historical_fencing_token,
            expected_actor=None,
        )
        return (
            task_id,
            request,
            worker_result,
            result_row,
            commit_row,
            anchor,
            reservation,
        )

    @staticmethod
    def _decision_worker_request_id(
        run_id: str,
        attempt: int,
        request_id: str,
    ) -> str:
        """Accept only the two canonical request identities at this boundary."""

        if type(run_id) is not str or not run_id.strip():
            raise GotaDecisionApplicationError(
                "Gota run identity must be a non-empty string"
            )
        if type(attempt) is not int or attempt < 1:
            raise GotaDecisionApplicationError(
                "Gota attempt must be a positive integer"
            )
        worker_request_id = f"{run_id}:{attempt}:worker"
        review_request_id = f"{run_id}:{attempt}:review"
        if type(request_id) is not str or request_id not in {
            worker_request_id,
            review_request_id,
        }:
            raise GotaDecisionApplicationError(
                "Gota decision request identity is not canonical"
            )
        return worker_request_id

    @staticmethod
    def _task_run_from_row(row: sqlite3.Row) -> TaskRun:
        return TaskRun(
            run_id=row["run_id"],
            task_id=row["task_id"],
            state=TaskState(row["state"]),
            created_at=parse_datetime(row["created_at"]),
            updated_at=parse_datetime(row["updated_at"]),
        )

    def _load_gota_decision_authorities_connection(
        self,
        connection: sqlite3.Connection,
        *,
        run_id: str,
        attempt: int,
        worker_request_id: str,
        allowed_states: frozenset[TaskState],
    ) -> GotaDecisionAuthorities:
        """Load every durable authority needed by DecisionPolicy."""

        run_row = connection.execute(
            "SELECT * FROM task_runs WHERE run_id = ?", (run_id,)
        ).fetchone()
        if run_row is None:
            raise KeyError(run_id)
        try:
            run = self._task_run_from_row(run_row)
        except (TypeError, ValueError, KeyError) as error:
            raise GotaDecisionApplicationError(
                "Gota run state or timestamps are not canonical"
            ) from error
        if run.state not in allowed_states:
            raise GotaDecisionApplicationError(
                "Gota decision application requires an intact REVIEW or terminal frontier"
            )

        reservation = self._load_gota_worker_reservation(
            connection,
            run_id=run_id,
            task_id=run.task_id,
            attempt=attempt,
            request_id=worker_request_id,
        )
        if reservation is None:
            raise GotaDecisionApplicationError(
                "Durable Worker request and invocation reservation are required"
            )
        request = reservation.request
        if (
            request.run_id != run_id
            or request.task_id != run.task_id
            or request.attempt != attempt
            or request.request_id != worker_request_id
        ):
            raise GotaDecisionApplicationError(
                "Durable Worker request identity is incoherent"
            )

        result_rows = connection.execute(
            """
            SELECT * FROM evidence
            WHERE run_id = ? AND kind = ?
            ORDER BY rowid
            """,
            (run_id, "gota_worker_result_received"),
        ).fetchall()
        if len(result_rows) != 1:
            raise GotaDecisionApplicationError(
                "Exactly one durable WorkerResult is required"
            )
        result_row = result_rows[0]
        try:
            worker_result, worker_payload = self._stored_worker_result(
                result_row,
                expected_run_id=run_id,
                expected_task_id=run.task_id,
            )
        except GotaWorkerResultError as error:
            raise GotaDecisionApplicationError(str(error)) from error
        if (
            worker_result.request_id != worker_request_id
            or worker_result.attempt != attempt
            or worker_result.result is not WorkerResultStatus.READY_FOR_REVIEW
        ):
            raise GotaDecisionApplicationError(
                "Durable WorkerResult identity or status is incoherent"
            )

        authority_ids = (
            reservation.request_evidence.evidence_id,
            reservation.invocation_evidence.evidence_id,
            result_row["evidence_id"],
        )
        authority_rows = connection.execute(
            """
            SELECT evidence_id, fencing_token
            FROM evidence
            WHERE evidence_id IN (?, ?, ?)
            """,
            authority_ids,
        ).fetchall()
        if len(authority_rows) != len(authority_ids):
            raise GotaDecisionApplicationError(
                "Durable Worker authorities are incomplete"
            )
        fencing_token = self._coherent_historical_fencing_token(
            authority_rows,
            error_type=GotaDecisionApplicationError,
            context="Durable Worker",
        )

        commit_rows = connection.execute(
            """
            SELECT * FROM evidence
            WHERE run_id = ? AND kind = ?
            ORDER BY rowid
            """,
            (run_id, "gota_worker_commit_verified"),
        ).fetchall()
        if len(commit_rows) != 1:
            raise GotaDecisionApplicationError(
                "Exactly one durable Worker commit verification is required"
            )
        commit_row = commit_rows[0]
        try:
            worker_commit_evidence, commit_payload = (
                self._stored_worker_commit_verified(
                    commit_row,
                    expected_run_id=run_id,
                    expected_task_id=run.task_id,
                )
            )
        except GotaWorkerReviewBoundaryError as error:
            raise GotaDecisionApplicationError(str(error)) from error
        expected_commit_identity = self._worker_commit_identity_payload(
            request,
            worker_result,
            request_evidence_id=authority_ids[0],
            invocation_evidence_id=authority_ids[1],
            result_evidence_id=authority_ids[2],
        )
        if any(
            commit_payload[field] != value
            for field, value in expected_commit_identity.items()
        ):
            raise GotaDecisionApplicationError(
                "Persisted Worker commit verification is incoherent"
            )
        if (
            type(commit_row["fencing_token"]) is not int
            or commit_row["fencing_token"] != fencing_token
        ):
            raise GotaDecisionApplicationError(
                "Worker commit verification fencing is incoherent"
            )

        try:
            worker_review_anchor = self._load_gota_worker_review_boundary_anchor(
                connection,
                run_id=run_id,
                attempt=attempt,
                request_id=worker_request_id,
            )
            self._validate_gota_worker_review_boundary_links(
                connection,
                worker_review_anchor,
                commit_evidence_row=commit_row,
                expected_fencing_token=fencing_token,
                expected_actor=None,
            )
        except GotaWorkerReviewBoundaryError as error:
            raise GotaDecisionApplicationError(str(error)) from error

        review_request_id = f"{run_id}:{attempt}:review"
        review_rows = connection.execute(
            """
            SELECT * FROM evidence
            WHERE run_id = ? AND kind = ?
            ORDER BY rowid
            """,
            (run_id, "gota_review_result"),
        ).fetchall()
        if len(review_rows) != 1:
            raise GotaDecisionApplicationError(
                "Exactly one durable ReviewResult is required"
            )
        review_row = review_rows[0]
        try:
            review_result, review_payload = self._stored_review_result(
                review_row,
                expected_run_id=run_id,
                expected_task_id=run.task_id,
            )
        except GotaReviewResultError as error:
            raise GotaDecisionApplicationError(str(error)) from error
        if (
            review_result.request_id != review_request_id
            or review_result.attempt != attempt
            or review_result.reviewed_commit_sha != worker_result.commit_sha
        ):
            raise GotaDecisionApplicationError(
                "Durable ReviewResult identity or Worker SHA is incoherent"
            )
        if (
            type(review_row["fencing_token"]) is not int
            or review_row["fencing_token"] < 1
        ):
            raise GotaDecisionApplicationError(
                "ReviewResult fencing is malformed"
            )

        try:
            review_anchor = self._load_gota_review_result_anchor(
                connection,
                run_id=run_id,
                attempt=attempt,
                request_id=review_request_id,
            )
            self._validate_gota_review_result_anchor_links(
                connection,
                review_anchor,
                review_evidence_row=review_row,
                worker_commit_evidence_row=commit_row,
            )
        except GotaReviewResultError as error:
            raise GotaDecisionApplicationError(str(error)) from error
        if review_anchor.worker_commit_evidence_id != commit_row["evidence_id"]:
            raise GotaDecisionApplicationError(
                "ReviewResult Worker commit link is incoherent"
            )

        return GotaDecisionAuthorities(
            run=run,
            request=request,
            worker_result=worker_result,
            worker_result_evidence=self._evidence_from_row(
                result_row, worker_payload
            ),
            worker_commit_evidence=worker_commit_evidence,
            worker_review_anchor=worker_review_anchor,
            review_result=review_result,
            review_evidence=self._evidence_from_row(review_row, review_payload),
            review_anchor=review_anchor,
            fencing_token=fencing_token,
        )

    def load_gota_decision_authorities(
        self,
        run_id: str,
        attempt: int,
        request_id: str,
    ) -> GotaDecisionAuthorities:
        """Load a coherent durable frontier for application or recovery."""

        worker_request_id = self._decision_worker_request_id(
            run_id, attempt, request_id
        )
        with closing(self._connect()) as connection:
            try:
                return self._load_gota_decision_authorities_connection(
                    connection,
                    run_id=run_id,
                    attempt=attempt,
                    worker_request_id=worker_request_id,
                    allowed_states=frozenset(
                        {
                            TaskState.REVIEW,
                            TaskState.DONE,
                            TaskState.NOT_COMPLETED,
                            TaskState.BLOCKED,
                        }
                    ),
                )
            except GotaDecisionApplicationError:
                raise
            except (
                GotaWorkerReservationError,
                GotaWorkerResultError,
                GotaWorkerReviewBoundaryError,
                GotaReviewResultError,
                TypeError,
                ValueError,
                KeyError,
            ) as error:
                raise GotaDecisionApplicationError(str(error)) from error

    @staticmethod
    def _validate_gota_policy_resolution(
        resolution: GotaDecisionResult,
        authorities: GotaDecisionAuthorities,
        *,
        allowed_actions: frozenset[GotaNextAction],
    ) -> None:
        """Check that the pure policy result still names durable authority."""

        if type(resolution) is not GotaDecisionResult:
            raise GotaDecisionApplicationError(
                "DecisionPolicy did not return a canonical decision result"
            )
        if type(resolution.action) is not GotaNextAction:
            raise GotaDecisionApplicationError(
                "DecisionPolicy returned a non-canonical action"
            )
        if resolution.action not in allowed_actions:
            raise GotaDecisionApplicationError(
                "DecisionPolicy action is not valid for this store operation"
            )
        if resolution.cycle_failure is not None:
            raise GotaDecisionApplicationError(
                "A failed Gota cycle cannot be applied as a business decision"
            )
        if type(resolution.reason) is not str:
            raise GotaDecisionApplicationError(
                "DecisionPolicy reason is not canonical"
            )
        if type(resolution.review_result) is not GotaReviewResult:
            raise GotaDecisionApplicationError(
                "DecisionPolicy did not retain the durable ReviewResult"
            )
        if resolution.review_decision is not authorities.review_result.decision:
            raise GotaDecisionApplicationError(
                "DecisionPolicy ReviewDecision disagrees with durable ReviewResult"
            )
        try:
            _canonical_result, policy_payload = SQLiteCoordinatorStore._canonical_review_result(
                resolution.review_result
            )
        except GotaReviewResultError as error:
            raise GotaDecisionApplicationError(str(error)) from error
        if _canonical_json(policy_payload) != _canonical_json(
            authorities.review_result.to_payload()
        ):
            raise GotaDecisionApplicationError(
                "DecisionPolicy ReviewResult disagrees with durable ReviewResult"
            )

    @staticmethod
    def _stored_gota_decision_applied(
        row: sqlite3.Row,
        authorities: GotaDecisionAuthorities,
    ) -> tuple[Evidence, dict[str, Any]]:
        """Validate the reserved, store-generated non-PASSED authority."""

        required = {
            "run_id",
            "task_id",
            "attempt",
            "request_id",
            "worker_request_id",
            "review_evidence_id",
            "review_evidence_digest",
            "worker_result_evidence_id",
            "worker_commit_evidence_id",
            "review_decision",
            "policy_action",
            "from_state",
            "to_state",
            "fencing_token",
        }
        try:
            created_at_value = row["created_at"]
            created_at = parse_datetime(created_at_value)
            payload = json.loads(row["payload_json"])
            if type(payload) is not dict or set(payload) != required:
                raise GotaDecisionApplicationError(
                    "Stored Gota decision evidence has invalid fields"
                )
            if _digest(payload) != row["digest"]:
                raise GotaDecisionApplicationError(
                    "Stored Gota decision evidence failed its digest check"
                )
            if _canonical_json(payload) != row["payload_json"]:
                raise GotaDecisionApplicationError(
                    "Stored Gota decision evidence is not canonical"
                )
            if (
                type(payload["run_id"]) is not str
                or payload["run_id"] != authorities.run.run_id
                or type(payload["task_id"]) is not str
                or payload["task_id"] != authorities.run.task_id
                or type(payload["attempt"]) is not int
                or payload["attempt"] != authorities.worker_result.attempt
                or type(payload["request_id"]) is not str
                or payload["request_id"] != authorities.review_result.request_id
                or type(payload["worker_request_id"]) is not str
                or payload["worker_request_id"] != authorities.request.request_id
                or type(payload["review_evidence_id"]) is not str
                or payload["review_evidence_id"]
                != authorities.review_evidence.evidence_id
                or type(payload["review_evidence_digest"]) is not str
                or payload["review_evidence_digest"]
                != authorities.review_evidence.digest
                or type(payload["worker_result_evidence_id"]) is not str
                or payload["worker_result_evidence_id"]
                != authorities.worker_result_evidence.evidence_id
                or type(payload["worker_commit_evidence_id"]) is not str
                or payload["worker_commit_evidence_id"]
                != authorities.worker_commit_evidence.evidence_id
                or type(payload["review_decision"]) is not str
                or payload["review_decision"]
                != authorities.review_result.decision.value
                or type(payload["policy_action"]) is not str
                or payload["policy_action"]
                not in {action.value for action in _GOTA_NON_PASSED_ACTIONS}
                or payload["from_state"] != TaskState.REVIEW.value
                or payload["to_state"]
                not in {
                    TaskState.NOT_COMPLETED.value,
                    TaskState.BLOCKED.value,
                }
                or type(payload["fencing_token"]) is not int
                or payload["fencing_token"] != int(row["fencing_token"])
                or type(row["created_at"]) is not str
                or isoformat(created_at) != created_at_value
            ):
                raise GotaDecisionApplicationError(
                    "Stored Gota decision evidence has non-canonical values"
                )
        except GotaDecisionApplicationError:
            raise
        except (TypeError, ValueError, KeyError, json.JSONDecodeError) as error:
            raise GotaDecisionApplicationError(
                "Stored Gota decision evidence is malformed"
            ) from error
        return SQLiteCoordinatorStore._evidence_from_row(row, payload), payload

    @staticmethod
    def _stored_gota_human_review_hold(
        row: sqlite3.Row,
        authorities: GotaDecisionAuthorities,
        decision_evidence: Evidence,
    ) -> GotaHumanReviewHold:
        try:
            created_at_value = row["created_at"]
            created_at = parse_datetime(created_at_value)
            if (
                type(row["run_id"]) is not str
                or row["run_id"] != authorities.run.run_id
                or type(row["attempt"]) is not int
                or row["attempt"] != authorities.worker_result.attempt
                or type(row["request_id"]) is not str
                or row["request_id"] != authorities.review_result.request_id
                or type(row["review_evidence_id"]) is not str
                or row["review_evidence_id"] != authorities.review_evidence.evidence_id
                or type(row["review_evidence_digest"]) is not str
                or row["review_evidence_digest"] != authorities.review_evidence.digest
                or type(row["decision_evidence_id"]) is not str
                or row["decision_evidence_id"] != decision_evidence.evidence_id
                or type(row["decision_evidence_digest"]) is not str
                or row["decision_evidence_digest"] != decision_evidence.digest
                or type(row["created_at"]) is not str
                or isoformat(created_at) != created_at_value
                or created_at != decision_evidence.created_at
            ):
                raise GotaDecisionApplicationError(
                    "Gota human-review hold has incoherent links"
                )
        except GotaDecisionApplicationError:
            raise
        except (TypeError, ValueError, KeyError) as error:
            raise GotaDecisionApplicationError(
                "Gota human-review hold is malformed"
            ) from error
        return GotaHumanReviewHold(
            run_id=authorities.run.run_id,
            attempt=authorities.worker_result.attempt,
            request_id=authorities.review_result.request_id,
            review_evidence_id=row["review_evidence_id"],
            review_evidence_digest=row["review_evidence_digest"],
            decision_evidence_id=row["decision_evidence_id"],
            decision_evidence_digest=row["decision_evidence_digest"],
            created_at=created_at,
        )

    def _load_gota_human_review_hold_connection(
        self,
        connection: sqlite3.Connection,
        authorities: GotaDecisionAuthorities,
    ) -> GotaHumanReviewHold | None:
        rows = connection.execute(
            """
            SELECT * FROM gota_human_review_holds
            WHERE run_id = ? AND attempt = ? AND request_id = ?
            ORDER BY rowid
            """,
            (
                authorities.run.run_id,
                authorities.worker_result.attempt,
                authorities.review_result.request_id,
            ),
        ).fetchall()
        if not rows:
            return None
        if len(rows) != 1:
            raise GotaDecisionApplicationError(
                "Multiple Gota human-review holds make the run ambiguous"
            )
        decision_rows = connection.execute(
            """
            SELECT * FROM evidence
            WHERE run_id = ? AND kind = ?
            ORDER BY rowid
            """,
            (authorities.run.run_id, "gota_decision_applied"),
        ).fetchall()
        if len(decision_rows) != 1:
            raise GotaDecisionApplicationError(
                "A Gota human-review hold requires exactly one decision authority"
            )
        decision_evidence, decision_payload = self._stored_gota_decision_applied(
            decision_rows[0], authorities
        )
        if (
            decision_payload["policy_action"]
            != GotaNextAction.WAIT_FOR_HUMAN.value
            or decision_payload["to_state"] != TaskState.NOT_COMPLETED.value
        ):
            raise GotaDecisionApplicationError(
                "Gota human-review hold is linked to a non-human decision"
            )
        return self._stored_gota_human_review_hold(
            rows[0], authorities, decision_evidence
        )

    def load_gota_human_review_hold(
        self,
        run_id: str,
        attempt: int,
        request_id: str,
    ) -> GotaHumanReviewHold | None:
        """Read one immutable human-review hold without releasing it."""

        worker_request_id = self._decision_worker_request_id(
            run_id, attempt, request_id
        )
        with closing(self._connect()) as connection:
            authorities = self._load_gota_decision_authorities_connection(
                connection,
                run_id=run_id,
                attempt=attempt,
                worker_request_id=worker_request_id,
                allowed_states=frozenset(
                    {
                        TaskState.REVIEW,
                        TaskState.DONE,
                        TaskState.NOT_COMPLETED,
                        TaskState.BLOCKED,
                    }
                ),
            )
            return self._load_gota_human_review_hold_connection(
                connection, authorities
            )

    def _insert_gota_human_review_hold(
        self,
        connection: sqlite3.Connection,
        authorities: GotaDecisionAuthorities,
        decision_evidence: Evidence,
        current_time: datetime,
    ) -> GotaHumanReviewHold:
        connection.execute(
            """
            INSERT INTO gota_human_review_holds(
                run_id, attempt, request_id, review_evidence_id,
                review_evidence_digest, decision_evidence_id,
                decision_evidence_digest, created_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (
                authorities.run.run_id,
                authorities.worker_result.attempt,
                authorities.review_result.request_id,
                authorities.review_evidence.evidence_id,
                authorities.review_evidence.digest,
                decision_evidence.evidence_id,
                decision_evidence.digest,
                isoformat(current_time),
            ),
        )
        return GotaHumanReviewHold(
            run_id=authorities.run.run_id,
            attempt=authorities.worker_result.attempt,
            request_id=authorities.review_result.request_id,
            review_evidence_id=authorities.review_evidence.evidence_id,
            review_evidence_digest=authorities.review_evidence.digest,
            decision_evidence_id=decision_evidence.evidence_id,
            decision_evidence_digest=decision_evidence.digest,
            created_at=current_time,
        )

    def apply_gota_decision(
        self,
        run_id: str,
        lease: Lease,
        resolution: GotaDecisionResult,
    ) -> GotaDecisionApplicationPersistence:
        """Atomically apply only a Policy-produced non-PASSED action."""

        if lease.run_id != run_id:
            raise FencingTokenError(
                f"Lease run {lease.run_id} does not match Gota run {run_id}"
            )
        if type(resolution) is not GotaDecisionResult or type(
            resolution.review_result
        ) is not GotaReviewResult:
            raise GotaDecisionApplicationError(
                "A canonical Policy resolution with a ReviewResult is required"
            )
        attempt = resolution.review_result.attempt
        worker_request_id = self._decision_worker_request_id(
            run_id, attempt, resolution.review_result.request_id
        )
        if resolution.action not in _GOTA_NON_PASSED_ACTIONS:
            raise GotaDecisionApplicationError(
                "Only a non-PASSED Policy action may use the decision primitive"
            )
        target_state, requires_hold = _GOTA_NON_PASSED_ACTIONS[resolution.action]
        trusted_now = self._trusted_now()
        decision_evidence: Evidence | None = None
        hold: GotaHumanReviewHold | None = None
        with self.fenced_transaction(lease, now=trusted_now) as connection:
            authorities = self._load_gota_decision_authorities_connection(
                connection,
                run_id=run_id,
                attempt=attempt,
                worker_request_id=worker_request_id,
                allowed_states=frozenset({TaskState.REVIEW}),
            )
            self._validate_gota_policy_resolution(
                resolution,
                authorities,
                allowed_actions=frozenset(_GOTA_NON_PASSED_ACTIONS),
            )
            existing_decisions = connection.execute(
                """
                SELECT * FROM evidence
                WHERE run_id = ? AND kind = ?
                ORDER BY rowid
                """,
                (run_id, "gota_decision_applied"),
            ).fetchall()
            if existing_decisions:
                raise GotaDecisionApplicationError(
                    "REVIEW contains preexisting Gota decision evidence"
                )
            existing_holds = connection.execute(
                "SELECT * FROM gota_human_review_holds WHERE run_id = ? ORDER BY rowid",
                (run_id,),
            ).fetchall()
            if existing_holds:
                raise GotaDecisionApplicationError(
                    "REVIEW contains a preexisting Gota human-review hold"
                )
            existing_acceptance = connection.execute(
                """
                SELECT * FROM evidence
                WHERE run_id = ? AND kind = ?
                ORDER BY rowid
                """,
                (run_id, "gota_acceptance_verified"),
            ).fetchall()
            if existing_acceptance:
                raise GotaDecisionApplicationError(
                    "REVIEW contains preexisting Gota acceptance evidence"
                )
            validate_transition(TaskState.REVIEW, target_state)
            if resolution.review_decision is None:
                raise GotaDecisionApplicationError(
                    "A non-PASSED Policy action requires a ReviewDecision"
                )
            decision_payload = {
                "run_id": authorities.run.run_id,
                "task_id": authorities.run.task_id,
                "attempt": authorities.worker_result.attempt,
                "request_id": authorities.review_result.request_id,
                "worker_request_id": authorities.request.request_id,
                "review_evidence_id": authorities.review_evidence.evidence_id,
                "review_evidence_digest": authorities.review_evidence.digest,
                "worker_result_evidence_id": authorities.worker_result_evidence.evidence_id,
                "worker_commit_evidence_id": authorities.worker_commit_evidence.evidence_id,
                "review_decision": resolution.review_decision.value,
                "policy_action": resolution.action.value,
                "from_state": TaskState.REVIEW.value,
                "to_state": target_state.value,
                "fencing_token": lease.fencing_token,
            }
            decision_evidence = self._insert_evidence(
                connection,
                run_id,
                "gota_decision_applied",
                decision_payload,
                lease,
                trusted_now,
            )
            updated = connection.execute(
                """
                UPDATE task_runs
                SET state = ?, updated_at = ?
                WHERE run_id = ? AND state = ?
                """,
                (
                    target_state.value,
                    isoformat(trusted_now),
                    run_id,
                    TaskState.REVIEW.value,
                ),
            )
            if updated.rowcount != 1:
                raise GotaDecisionApplicationError(
                    "Gota decision application requires a REVIEW task"
                )
            connection.execute(
                """
                INSERT INTO transition_events(
                    run_id, from_state, to_state, actor, reason,
                    fencing_token, created_at
                ) VALUES (?, ?, ?, ?, ?, ?, ?)
                """,
                (
                    run_id,
                    TaskState.REVIEW.value,
                    target_state.value,
                    lease.owner_id,
                    "gota_decision_applied",
                    lease.fencing_token,
                    isoformat(trusted_now),
                ),
            )
            if requires_hold:
                hold = self._insert_gota_human_review_hold(
                    connection,
                    authorities,
                    decision_evidence,
                    trusted_now,
                )
            final_now = self._trusted_now()
            self._assert_fenced_connection(connection, lease, final_now)
        assert decision_evidence is not None
        return GotaDecisionApplicationPersistence(
            run=self.get_run(run_id),
            decision_evidence=decision_evidence,
            hold=hold,
            created=True,
        )

    def recognize_gota_decision_application(
        self,
        run_id: str,
        attempt: int,
        request_id: str,
        resolution: GotaDecisionResult,
    ) -> GotaDecisionApplicationPersistence:
        """Recognize one already-applied non-PASSED decision read-only."""

        worker_request_id = self._decision_worker_request_id(
            run_id, attempt, request_id
        )
        if type(resolution) is not GotaDecisionResult:
            raise GotaDecisionApplicationError(
                "A canonical Policy resolution is required for recovery"
            )
        if resolution.action not in _GOTA_NON_PASSED_ACTIONS:
            raise GotaDecisionApplicationError(
                "Recovery requires a non-PASSED Policy action"
            )
        target_state, requires_hold = _GOTA_NON_PASSED_ACTIONS[resolution.action]
        with closing(self._connect()) as connection:
            authorities = self._load_gota_decision_authorities_connection(
                connection,
                run_id=run_id,
                attempt=attempt,
                worker_request_id=worker_request_id,
                allowed_states=frozenset(
                    {TaskState.REVIEW, TaskState.NOT_COMPLETED, TaskState.BLOCKED}
                ),
            )
            self._validate_gota_policy_resolution(
                resolution,
                authorities,
                allowed_actions=frozenset(_GOTA_NON_PASSED_ACTIONS),
            )
            if authorities.run.state is not target_state:
                raise GotaDecisionApplicationError(
                    "Terminal Gota state does not match the Policy action"
                )
            decision_rows = connection.execute(
                """
                SELECT * FROM evidence
                WHERE run_id = ? AND kind = ?
                ORDER BY rowid
                """,
                (run_id, "gota_decision_applied"),
            ).fetchall()
            if len(decision_rows) != 1:
                raise GotaDecisionApplicationError(
                    "Terminal Gota state requires exactly one decision authority"
                )
            decision_evidence, decision_payload = self._stored_gota_decision_applied(
                decision_rows[0], authorities
            )
            if (
                decision_payload["policy_action"] != resolution.action.value
                or decision_payload["to_state"] != target_state.value
            ):
                raise GotaDecisionApplicationError(
                    "Stored Gota decision action or target state disagrees"
                )
            events = connection.execute(
                """
                SELECT * FROM transition_events
                WHERE run_id = ? AND from_state = ?
                ORDER BY event_id
                """,
                (run_id, TaskState.REVIEW.value),
            ).fetchall()
            if len(events) != 1:
                raise GotaDecisionApplicationError(
                    "Terminal Gota state requires exactly one REVIEW decision event"
                )
            event = events[0]
            try:
                event_created_at = parse_datetime(event["created_at"])
                if (
                    event["to_state"] != target_state.value
                    or event["reason"] != "gota_decision_applied"
                    or type(event["actor"]) is not str
                    or not event["actor"]
                    or type(event["fencing_token"]) is not int
                    or event["fencing_token"] != decision_evidence.payload["fencing_token"]
                    or type(event["created_at"]) is not str
                    or isoformat(event_created_at) != event["created_at"]
                    or event_created_at != decision_evidence.created_at
                ):
                    raise GotaDecisionApplicationError(
                        "Gota decision transition event is incoherent"
                    )
            except GotaDecisionApplicationError:
                raise
            except (TypeError, ValueError, KeyError) as error:
                raise GotaDecisionApplicationError(
                    "Gota decision transition event is malformed"
                ) from error
            acceptance_rows = connection.execute(
                """
                SELECT * FROM evidence
                WHERE run_id = ? AND kind = ?
                """,
                (run_id, "gota_acceptance_verified"),
            ).fetchall()
            if acceptance_rows:
                raise GotaDecisionApplicationError(
                    "Non-PASSED Gota decision has acceptance evidence"
                )
            hold_rows = connection.execute(
                "SELECT * FROM gota_human_review_holds WHERE run_id = ? ORDER BY rowid",
                (run_id,),
            ).fetchall()
            if requires_hold:
                if len(hold_rows) != 1:
                    raise GotaDecisionApplicationError(
                        "HUMAN_REVIEW_REQUIRED requires exactly one durable hold"
                    )
                hold = self._load_gota_human_review_hold_connection(
                    connection, authorities
                )
                if hold is None:
                    raise GotaDecisionApplicationError(
                        "HUMAN_REVIEW_REQUIRED hold is missing"
                    )
            else:
                if hold_rows:
                    raise GotaDecisionApplicationError(
                        "This Gota decision must not create a human-review hold"
                    )
                hold = None
            return GotaDecisionApplicationPersistence(
                run=authorities.run,
                decision_evidence=decision_evidence,
                hold=hold,
                created=False,
            )

    def _stored_gota_acceptance_verified(
        self,
        row: sqlite3.Row,
        authorities: GotaDecisionAuthorities,
    ) -> Evidence:
        required = {
            "run_id",
            "task_id",
            "attempt",
            "worker_request_id",
            "review_request_id",
            "worker_commit_sha",
            "reviewed_commit_sha",
            "decision",
            "fencing_token",
            "worker_result_evidence_id",
            "worker_commit_evidence_id",
            "review_result_evidence_id",
        }
        try:
            created_at_value = row["created_at"]
            created_at = parse_datetime(created_at_value)
            payload = json.loads(row["payload_json"])
            if type(payload) is not dict or set(payload) != required:
                raise GotaDecisionApplicationError(
                    "Stored Gota acceptance evidence has invalid fields"
                )
            if _digest(payload) != row["digest"]:
                raise GotaDecisionApplicationError(
                    "Stored Gota acceptance evidence failed its digest check"
                )
            if _canonical_json(payload) != row["payload_json"]:
                raise GotaDecisionApplicationError(
                    "Stored Gota acceptance evidence is not canonical"
                )
            if (
                payload["run_id"] != authorities.run.run_id
                or payload["task_id"] != authorities.run.task_id
                or type(payload["attempt"]) is not int
                or payload["attempt"] != authorities.worker_result.attempt
                or payload["worker_request_id"] != authorities.request.request_id
                or payload["review_request_id"] != authorities.review_result.request_id
                or payload["worker_commit_sha"] != authorities.worker_result.commit_sha
                or payload["reviewed_commit_sha"]
                != authorities.review_result.reviewed_commit_sha
                or payload["decision"] != ReviewDecision.PASSED.value
                or type(payload["fencing_token"]) is not int
                or payload["fencing_token"] != int(row["fencing_token"])
                or payload["worker_result_evidence_id"]
                != authorities.worker_result_evidence.evidence_id
                or payload["worker_commit_evidence_id"]
                != authorities.worker_commit_evidence.evidence_id
                or payload["review_result_evidence_id"]
                != authorities.review_evidence.evidence_id
                or type(row["created_at"]) is not str
                or isoformat(created_at) != created_at_value
            ):
                raise GotaDecisionApplicationError(
                    "Stored Gota acceptance evidence has incoherent values"
                )
        except GotaDecisionApplicationError:
            raise
        except (TypeError, ValueError, KeyError, json.JSONDecodeError) as error:
            raise GotaDecisionApplicationError(
                "Stored Gota acceptance evidence is malformed"
            ) from error
        return self._evidence_from_row(row, payload)

    def recognize_gota_acceptance(
        self,
        run_id: str,
        attempt: int,
        request_id: str,
        resolution: GotaDecisionResult,
    ) -> TaskRun:
        """Recognize a Gota PASSED/DONE authority without mutating SQLite."""

        worker_request_id = self._decision_worker_request_id(
            run_id, attempt, request_id
        )
        with closing(self._connect()) as connection:
            authorities = self._load_gota_decision_authorities_connection(
                connection,
                run_id=run_id,
                attempt=attempt,
                worker_request_id=worker_request_id,
                allowed_states=frozenset({TaskState.REVIEW, TaskState.DONE}),
            )
            self._validate_gota_policy_resolution(
                resolution,
                authorities,
                allowed_actions=frozenset({GotaNextAction.COMPLETE}),
            )
            if authorities.run.state is not TaskState.DONE:
                raise GotaDecisionApplicationError(
                    "PASSED recovery requires a DONE task"
                )
            acceptance_rows = connection.execute(
                """
                SELECT * FROM evidence
                WHERE run_id = ? AND kind = ?
                ORDER BY rowid
                """,
                (run_id, "gota_acceptance_verified"),
            ).fetchall()
            if len(acceptance_rows) != 1:
                raise GotaDecisionApplicationError(
                    "DONE requires exactly one Gota acceptance authority"
                )
            acceptance_evidence = self._stored_gota_acceptance_verified(
                acceptance_rows[0], authorities
            )
            decision_rows = connection.execute(
                """
                SELECT * FROM evidence
                WHERE run_id = ? AND kind = ?
                """,
                (run_id, "gota_decision_applied"),
            ).fetchall()
            if decision_rows:
                raise GotaDecisionApplicationError(
                    "PASSED Gota completion has non-PASSED decision evidence"
                )
            hold_rows = connection.execute(
                "SELECT * FROM gota_human_review_holds WHERE run_id = ?",
                (run_id,),
            ).fetchall()
            if hold_rows:
                raise GotaDecisionApplicationError(
                    "PASSED Gota completion has a human-review hold"
                )
            events = connection.execute(
                """
                SELECT * FROM transition_events
                WHERE run_id = ? AND from_state = ?
                ORDER BY event_id
                """,
                (run_id, TaskState.REVIEW.value),
            ).fetchall()
            if len(events) != 1:
                raise GotaDecisionApplicationError(
                    "DONE requires exactly one REVIEW -> DONE Gota event"
                )
            event = events[0]
            try:
                event_created_at = parse_datetime(event["created_at"])
                if (
                    event["to_state"] != TaskState.DONE.value
                    or event["reason"] != "gota_acceptance_verified"
                    or type(event["actor"]) is not str
                    or not event["actor"]
                    or type(event["fencing_token"]) is not int
                    or event["fencing_token"] != acceptance_evidence.payload["fencing_token"]
                    or type(event["created_at"]) is not str
                    or isoformat(event_created_at) != event["created_at"]
                    or event_created_at != acceptance_evidence.created_at
                ):
                    raise GotaDecisionApplicationError(
                        "Gota acceptance transition event is incoherent"
                    )
            except GotaDecisionApplicationError:
                raise
            except (TypeError, ValueError, KeyError) as error:
                raise GotaDecisionApplicationError(
                    "Gota acceptance transition event is malformed"
                ) from error
            return authorities.run

    def persist_gota_review_result(
        self,
        run_id: str,
        result: GotaReviewResult,
        lease: Lease,
    ) -> Evidence:
        """Persist one canonical ReviewResult and its independent anchor."""

        if type(run_id) is not str or not run_id.strip():
            raise GotaReviewResultError(
                "Gota run identity must be a non-empty string"
            )
        if lease.run_id != run_id:
            raise FencingTokenError(
                f"Lease run {lease.run_id} does not match Gota run {run_id}"
            )
        canonical_result, payload = self._canonical_review_result(result)
        if canonical_result.run_id != run_id:
            raise GotaReviewResultError(
                "Gota Review result run identity does not match the requested run"
            )
        self._review_request_identity(
            run_id, canonical_result.attempt, canonical_result.request_id
        )
        worker_request_id = f"{run_id}:{canonical_result.attempt}:worker"

        trusted_now = self._trusted_now()
        with self.fenced_transaction(lease, now=trusted_now) as connection:
            task_id, worker_request, worker_result, _result_row, commit_row, _worker_anchor, _reservation = self._load_gota_review_frontier(
                connection,
                run_id=run_id,
                attempt=canonical_result.attempt,
                request_id=worker_request_id,
            )
            if (
                canonical_result.task_id != task_id
                or canonical_result.attempt != worker_result.attempt
                or canonical_result.request_id
                != f"{run_id}:{worker_result.attempt}:review"
                or worker_request.task_id != canonical_result.task_id
                or canonical_result.reviewed_commit_sha != worker_result.commit_sha
            ):
                raise GotaReviewResultError(
                    "Gota Review result identity or Worker SHA is incoherent"
                )

            review_rows = connection.execute(
                """
                SELECT * FROM evidence
                WHERE run_id = ? AND kind = ?
                ORDER BY rowid
                """,
                (run_id, "gota_review_result"),
            ).fetchall()
            anchor_rows = connection.execute(
                "SELECT * FROM gota_review_results WHERE run_id = ? ORDER BY rowid",
                (run_id,),
            ).fetchall()
            if len(review_rows) > 1:
                raise GotaReviewResultError(
                    "Multiple durable Gota Review results make the run ambiguous"
                )
            if len(anchor_rows) > 1:
                raise GotaReviewResultError(
                    "Multiple Gota Review result anchors make the run ambiguous"
                )
            if bool(review_rows) != bool(anchor_rows):
                raise GotaReviewResultError(
                    "Gota Review result evidence and anchor must be paired"
                )

            if review_rows:
                review_row = review_rows[0]
                existing, existing_payload = self._stored_review_result(
                    review_row,
                    expected_run_id=run_id,
                    expected_task_id=task_id,
                )
                anchor = self._stored_gota_review_result_anchor(
                    anchor_rows[0],
                    expected_run_id=run_id,
                    expected_attempt=canonical_result.attempt,
                    expected_request_id=canonical_result.request_id,
                )
                self._validate_gota_review_result_anchor_links(
                    connection,
                    anchor,
                    review_evidence_row=review_row,
                    worker_commit_evidence_row=commit_row,
                )
                if _canonical_json(existing_payload) != _canonical_json(payload):
                    raise GotaReviewResultError(
                        "A different Gota Review result already exists for the run"
                    )
                if (
                    existing.attempt != canonical_result.attempt
                    or existing.request_id != canonical_result.request_id
                    or anchor.worker_commit_evidence_id != commit_row["evidence_id"]
                ):
                    raise GotaReviewResultError(
                        "Existing Gota Review result authority is incoherent"
                    )
                final_now = self._trusted_now()
                self._assert_fenced_connection(connection, lease, final_now)
                return self._evidence_from_row(review_row, existing_payload)

            review_evidence = self._insert_evidence(
                connection,
                run_id,
                "gota_review_result",
                payload,
                lease,
                trusted_now,
            )
            connection.execute(
                """
                INSERT INTO gota_review_results(
                    run_id, attempt, request_id, review_evidence_id,
                    review_evidence_digest, worker_commit_evidence_id, created_at
                ) VALUES (?, ?, ?, ?, ?, ?, ?)
                """,
                (
                    run_id,
                    canonical_result.attempt,
                    canonical_result.request_id,
                    review_evidence.evidence_id,
                    review_evidence.digest,
                    commit_row["evidence_id"],
                    isoformat(trusted_now),
                ),
            )
            final_now = self._trusted_now()
            self._assert_fenced_connection(connection, lease, final_now)
            return review_evidence

    def load_gota_review_result(
        self,
        run_id: str,
        attempt: int,
        request_id: str,
    ) -> GotaReviewResult | None:
        """Load one complete, anchored canonical ReviewResult or ``None``."""

        self._review_request_identity(run_id, attempt, request_id)
        worker_request_id = f"{run_id}:{attempt}:worker"
        with closing(self._connect()) as connection:
            task_id, _request, worker_result, _result_row, commit_row, _worker_anchor, _reservation = self._load_gota_review_frontier(
                connection,
                run_id=run_id,
                attempt=attempt,
                request_id=worker_request_id,
            )
            review_rows = connection.execute(
                """
                SELECT * FROM evidence
                WHERE run_id = ? AND kind = ?
                ORDER BY rowid
                """,
                (run_id, "gota_review_result"),
            ).fetchall()
            anchor_rows = connection.execute(
                "SELECT * FROM gota_review_results WHERE run_id = ? ORDER BY rowid",
                (run_id,),
            ).fetchall()
            if not review_rows and not anchor_rows:
                return None
            if len(review_rows) != 1:
                raise GotaReviewResultError(
                    "REVIEW requires exactly one Gota Review result evidence record"
                )
            if len(anchor_rows) != 1:
                raise GotaReviewResultError(
                    "REVIEW requires exactly one Gota Review result anchor"
                )
            review_row = review_rows[0]
            result, _payload = self._stored_review_result(
                review_row,
                expected_run_id=run_id,
                expected_task_id=task_id,
            )
            if (
                result.attempt != attempt
                or result.request_id != request_id
                or result.reviewed_commit_sha != worker_result.commit_sha
            ):
                raise GotaReviewResultError(
                    "Stored Gota Review result identity or Worker SHA is incoherent"
                )
            anchor = self._stored_gota_review_result_anchor(
                anchor_rows[0],
                expected_run_id=run_id,
                expected_attempt=attempt,
                expected_request_id=request_id,
            )
            self._validate_gota_review_result_anchor_links(
                connection,
                anchor,
                review_evidence_row=review_row,
                worker_commit_evidence_row=commit_row,
            )
            if anchor.worker_commit_evidence_id != commit_row["evidence_id"]:
                raise GotaReviewResultError(
                    "Stored Gota Review result Worker commit link is incoherent"
                )
            return result

    def _persist_gota_worker_commit_verified_and_review(
        self,
        run_id: str,
        attempt: int,
        request_id: str,
        lease: Lease,
        *,
        verify: Callable[[GotaRequest, GotaWorkerResult], Mapping[str, Any]],
    ) -> GotaWorkerReviewPersistence:
        """Consume only the internal read-only verifier result atomically.

        The method is intentionally private.  The public Gota entry boundary
        loads the durable authorities and supplies the verifier closure; no
        public store primitive accepts a caller-controlled ``verified`` flag or
        evidence payload.
        """

        self._request_identity(run_id, attempt, request_id)
        if lease.run_id != run_id:
            raise FencingTokenError(
                f"Lease run {lease.run_id} does not match Gota run {run_id}"
            )

        trusted_now = self._trusted_now()
        persisted_evidence: Evidence | None = None
        created = False

        with self.fenced_transaction(lease, now=trusted_now) as connection:
            run_row = connection.execute(
                "SELECT * FROM task_runs WHERE run_id = ?", (run_id,)
            ).fetchone()
            if run_row is None:
                raise KeyError(run_id)
            try:
                state = TaskState(run_row["state"])
            except ValueError as error:
                raise GotaWorkerReviewBoundaryError(
                    "Gota run has an unknown task state"
                ) from error
            if state not in {TaskState.RUNNING, TaskState.REVIEW}:
                raise GotaWorkerReviewBoundaryError(
                    "Gota Worker review entry requires a RUNNING or REVIEW task"
                )

            task_id = run_row["task_id"]
            reservation = self._load_gota_worker_reservation(
                connection,
                run_id=run_id,
                task_id=task_id,
                attempt=attempt,
                request_id=request_id,
            )
            if reservation is None:
                raise GotaWorkerReviewBoundaryError(
                    "Durable Worker request and invocation reservation are required"
                )
            request = reservation.request
            if (
                request.run_id != run_id
                or request.task_id != task_id
                or request.attempt != attempt
                or request.request_id != request_id
            ):
                raise GotaWorkerReviewBoundaryError(
                    "Durable Worker request identity is incoherent"
                )

            result_rows = connection.execute(
                """
                SELECT * FROM evidence
                WHERE run_id = ? AND kind = ?
                ORDER BY rowid
                """,
                (run_id, "gota_worker_result_received"),
            ).fetchall()
            if len(result_rows) != 1:
                raise GotaWorkerReviewBoundaryError(
                    "Exactly one durable WorkerResult is required"
                )
            result_row = result_rows[0]
            worker_result, _result_payload = self._stored_worker_result(
                result_row,
                expected_run_id=run_id,
                expected_task_id=task_id,
            )
            if (
                worker_result.request_id != request_id
                or worker_result.attempt != attempt
                or worker_result.result is not WorkerResultStatus.READY_FOR_REVIEW
            ):
                raise GotaWorkerReviewBoundaryError(
                    "Durable WorkerResult identity or status is incoherent"
                )

            authority_ids = (
                reservation.request_evidence.evidence_id,
                reservation.invocation_evidence.evidence_id,
                result_row["evidence_id"],
            )
            authority_rows = connection.execute(
                """
                SELECT evidence_id, fencing_token
                FROM evidence
                WHERE evidence_id IN (?, ?, ?)
                """,
                authority_ids,
            ).fetchall()
            if len(authority_rows) != len(authority_ids):
                raise GotaWorkerReviewBoundaryError(
                    "Durable Worker authorities are incomplete"
                )
            historical_fencing_token = self._coherent_historical_fencing_token(
                authority_rows,
                error_type=GotaWorkerReviewBoundaryError,
                context="Durable Worker",
            )

            commit_rows = connection.execute(
                """
                SELECT * FROM evidence
                WHERE run_id = ? AND kind = ?
                ORDER BY rowid
                """,
                (run_id, "gota_worker_commit_verified"),
            ).fetchall()

            expected_commit_identity = self._worker_commit_identity_payload(
                request,
                worker_result,
                request_evidence_id=authority_ids[0],
                invocation_evidence_id=authority_ids[1],
                result_evidence_id=authority_ids[2],
            )

            if state is TaskState.REVIEW:
                if len(commit_rows) != 1:
                    raise GotaWorkerReviewBoundaryError(
                        "REVIEW requires exactly one Worker commit verification"
                    )
                anchor_rows = connection.execute(
                    "SELECT * FROM gota_worker_review_boundaries WHERE run_id = ? ORDER BY rowid",
                    (run_id,),
                ).fetchall()
                if len(anchor_rows) != 1:
                    raise GotaWorkerReviewBoundaryError(
                        "REVIEW requires exactly one Gota Worker boundary anchor"
                    )
                persisted_evidence, persisted_payload = (
                    self._stored_worker_commit_verified(
                        commit_rows[0],
                        expected_run_id=run_id,
                        expected_task_id=task_id,
                    )
                )
                if any(
                    persisted_payload[field] != value
                    for field, value in expected_commit_identity.items()
                ):
                    raise GotaWorkerReviewBoundaryError(
                        "Persisted Worker commit verification is incoherent"
                    )
                anchor = self._load_gota_worker_review_boundary_anchor(
                    connection,
                    run_id=run_id,
                    attempt=attempt,
                    request_id=request_id,
                )
                self._validate_gota_worker_review_boundary_links(
                    connection,
                    anchor,
                    commit_evidence_row=commit_rows[0],
                    expected_fencing_token=historical_fencing_token,
                    expected_actor=None,
                )
                current_observation = verify(request, worker_result)
                self._validate_worker_review_verification(
                    current_observation,
                    request=request,
                    result=worker_result,
                )
                persisted_observation = {
                    "base_sha": persisted_payload["base_sha"],
                    "commit_sha": persisted_payload["commit_sha"],
                    "changed_paths": tuple(persisted_payload["changed_paths"]),
                    "branch": persisted_payload["branch"],
                    "head": persisted_payload["head"],
                    "status": persisted_payload["status"],
                    "refs": tuple(tuple(ref) for ref in persisted_payload["refs"]),
                }
                if current_observation != persisted_observation:
                    raise GotaWorkerReviewBoundaryError(
                        "Current Git verification conflicts with the persisted REVIEW frontier"
                    )
                created = False
                final_now = self._trusted_now()
                self._assert_fenced_connection(connection, lease, final_now)
            else:
                anchor_rows = connection.execute(
                    "SELECT * FROM gota_worker_review_boundaries WHERE run_id = ?",
                    (run_id,),
                ).fetchall()
                if anchor_rows:
                    raise GotaWorkerReviewBoundaryError(
                        "RUNNING contains an unexpected Gota Worker boundary anchor"
                    )
                if commit_rows:
                    if len(commit_rows) != 1:
                        raise GotaWorkerReviewBoundaryError(
                            "Multiple Worker commit verifications make RUNNING ambiguous"
                        )
                    self._stored_worker_commit_verified(
                        commit_rows[0],
                        expected_run_id=run_id,
                        expected_task_id=task_id,
                    )
                    raise GotaWorkerReviewBoundaryError(
                        "RUNNING already contains a Worker commit verification"
                    )

                observations: list[Mapping[str, Any]] = []
                for _ in range(3):
                    observation = verify(request, worker_result)
                    self._validate_worker_review_verification(
                        observation,
                        request=request,
                        result=worker_result,
                    )
                    if observations and observation != observations[0]:
                        raise GotaWorkerReviewBoundaryError(
                            "Git verification fingerprint changed before SQLite commit"
                        )
                    observations.append(observation)

                persisted_evidence = self._insert_evidence(
                    connection,
                    run_id,
                    "gota_worker_commit_verified",
                    self._worker_commit_payload(
                        expected_commit_identity, observations[0]
                    ),
                    lease,
                    trusted_now,
                )

                updated = connection.execute(
                    """
                    UPDATE task_runs
                    SET state = ?, updated_at = ?
                    WHERE run_id = ? AND state = ?
                    """,
                    (
                        TaskState.REVIEW.value,
                        isoformat(trusted_now),
                        run_id,
                        TaskState.RUNNING.value,
                    ),
                )
                if updated.rowcount != 1:
                    raise GotaWorkerReviewBoundaryError(
                        "Gota Worker review entry requires a RUNNING task"
                    )
                event_cursor = connection.execute(
                    """
                    INSERT INTO transition_events(
                        run_id, from_state, to_state, actor, reason, fencing_token, created_at
                    ) VALUES (?, ?, ?, ?, ?, ?, ?)
                    """,
                    (
                        run_id,
                        TaskState.RUNNING.value,
                        TaskState.REVIEW.value,
                        lease.owner_id,
                        "gota_worker_commit_verified",
                        lease.fencing_token,
                        isoformat(trusted_now),
                    ),
                )
                transition_event_id = event_cursor.lastrowid
                if type(transition_event_id) is not int or transition_event_id < 1:
                    raise GotaWorkerReviewBoundaryError(
                        "Gota Worker review entry did not produce a transition event ID"
                    )
                if persisted_evidence is None:
                    raise GotaWorkerReviewBoundaryError(
                        "Gota Worker review entry did not produce an evidence authority"
                    )
                connection.execute(
                    """
                    INSERT INTO gota_worker_review_boundaries(
                        run_id, attempt, request_id, commit_evidence_id,
                        commit_evidence_digest, transition_event_id, created_at
                    ) VALUES (?, ?, ?, ?, ?, ?, ?)
                    """,
                    (
                        run_id,
                        attempt,
                        request_id,
                        persisted_evidence.evidence_id,
                        persisted_evidence.digest,
                        transition_event_id,
                        isoformat(trusted_now),
                    ),
                )
                final_observation = verify(request, worker_result)
                self._validate_worker_review_verification(
                    final_observation,
                    request=request,
                    result=worker_result,
                )
                if final_observation != observations[0]:
                    raise GotaWorkerReviewBoundaryError(
                        "Git verification fingerprint changed before SQLite commit"
                    )
                created = True
                final_now = self._trusted_now()
                self._assert_fenced_connection(connection, lease, final_now)

        return GotaWorkerReviewPersistence(
            run=self.get_run(run_id),
            commit_evidence=persisted_evidence,
            created=created,
        )

    def list_events(self, run_id: str | None = None) -> tuple[TransitionEvent, ...]:
        query = "SELECT * FROM transition_events"
        parameters: tuple[str, ...] = ()
        if run_id is not None:
            query += " WHERE run_id = ?"
            parameters = (run_id,)
        query += " ORDER BY event_id"
        with closing(self._connect()) as connection:
            rows = connection.execute(query, parameters).fetchall()
        return tuple(
            TransitionEvent(
                event_id=int(row["event_id"]),
                run_id=row["run_id"],
                from_state=TaskState(row["from_state"]) if row["from_state"] else None,
                to_state=TaskState(row["to_state"]),
                actor=row["actor"],
                reason=row["reason"],
                created_at=parse_datetime(row["created_at"]),
            )
            for row in rows
        )

    def _insert_evidence(
        self,
        connection: sqlite3.Connection,
        run_id: str,
        kind: str,
        payload: Mapping[str, Any],
        lease: Lease,
        current_time: datetime,
    ) -> Evidence:
        evidence_id = str(uuid.uuid4())
        payload_dict = dict(payload)
        digest = _digest(payload_dict)
        connection.execute(
            """
            INSERT INTO evidence(
                evidence_id, run_id, kind, payload_json, digest, fencing_token, created_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?)
            """,
            (
                evidence_id,
                run_id,
                kind,
                _canonical_json(payload_dict),
                digest,
                lease.fencing_token,
                isoformat(current_time),
            ),
        )
        return Evidence(evidence_id, run_id, kind, payload_dict, digest, current_time)

    def append_evidence(
        self,
        run_id: str,
        kind: str,
        payload: Mapping[str, Any],
        lease: Lease,
        *,
        now: datetime | None = None,
    ) -> Evidence:
        if type(kind) is not str:
            raise AcceptanceEvidenceError(
                "Evidence kind must be a canonical str"
            )
        if kind in _RESERVED_EVIDENCE_KINDS:
            raise AcceptanceEvidenceError(
                f"Evidence kind {kind!r} is reserved for an internal Gota authority boundary"
            )
        # Keep the legacy keyword for existing internal callers, but never let
        # caller-provided time authorize or timestamp evidence.
        del now
        current_time = self._trusted_now()
        payload_dict = dict(payload)
        with self.fenced_transaction(lease, now=current_time) as connection:
            return self._insert_evidence(
                connection,
                run_id,
                kind,
                payload_dict,
                lease,
                current_time,
            )

    def list_evidence(self, run_id: str) -> tuple[Evidence, ...]:
        with closing(self._connect()) as connection:
            rows = connection.execute(
                "SELECT * FROM evidence WHERE run_id = ? ORDER BY rowid",
                (run_id,),
            ).fetchall()
        return tuple(
            Evidence(
                evidence_id=row["evidence_id"],
                run_id=row["run_id"],
                kind=row["kind"],
                payload=json.loads(row["payload_json"]),
                digest=row["digest"],
                created_at=parse_datetime(row["created_at"]),
            )
            for row in rows
        )

    def append_checkpoint(
        self,
        run_id: str,
        payload: Mapping[str, Any],
        lease: Lease,
        *,
        now: datetime | None = None,
    ) -> Checkpoint:
        checkpoint_id = str(uuid.uuid4())
        current_time = now or utc_now()
        payload_dict = dict(payload)
        digest = _digest(payload_dict)
        with self.fenced_transaction(lease, now=current_time) as connection:
            connection.execute(
                """
                INSERT INTO checkpoints(
                    checkpoint_id, run_id, payload_json, digest, fencing_token, created_at
                ) VALUES (?, ?, ?, ?, ?, ?)
                """,
                (
                    checkpoint_id,
                    run_id,
                    _canonical_json(payload_dict),
                    digest,
                    lease.fencing_token,
                    isoformat(current_time),
                ),
            )
        return Checkpoint(checkpoint_id, run_id, payload_dict, digest, current_time)

    def latest_checkpoint(self, run_id: str) -> Checkpoint | None:
        with closing(self._connect()) as connection:
            row = connection.execute(
                """
                SELECT * FROM checkpoints WHERE run_id = ?
                ORDER BY rowid DESC LIMIT 1
                """,
                (run_id,),
            ).fetchone()
        if row is None:
            return None
        return Checkpoint(
            checkpoint_id=row["checkpoint_id"],
            run_id=row["run_id"],
            payload=json.loads(row["payload_json"]),
            digest=row["digest"],
            created_at=parse_datetime(row["created_at"]),
        )

    def list_checkpoints(self, run_id: str) -> tuple[Checkpoint, ...]:
        with closing(self._connect()) as connection:
            rows = connection.execute(
                "SELECT * FROM checkpoints WHERE run_id = ? ORDER BY rowid",
                (run_id,),
            ).fetchall()
        return tuple(
            Checkpoint(
                checkpoint_id=row["checkpoint_id"],
                run_id=row["run_id"],
                payload=json.loads(row["payload_json"]),
                digest=row["digest"],
                created_at=parse_datetime(row["created_at"]),
            )
            for row in rows
        )

    def add_dependency(self, task_id: str, depends_on_task_id: str) -> None:
        with self.transaction(immediate=True) as connection:
            known = {
                row[0]
                for row in connection.execute("SELECT task_id FROM task_specs").fetchall()
            }
            dependencies: dict[str, list[str]] = {task: [] for task in known}
            for row in connection.execute(
                "SELECT task_id, depends_on_task_id FROM dependencies"
            ).fetchall():
                dependencies[row["task_id"]].append(row["depends_on_task_id"])
            dependencies.setdefault(task_id, []).append(depends_on_task_id)
            validate_dependency_graph(known, dependencies)
            connection.execute(
                "INSERT INTO dependencies(task_id, depends_on_task_id) VALUES (?, ?)",
                (task_id, depends_on_task_id),
            )

    def list_dependencies(self, task_id: str) -> tuple[str, ...]:
        with closing(self._connect()) as connection:
            rows = connection.execute(
                "SELECT depends_on_task_id FROM dependencies WHERE task_id = ? ORDER BY depends_on_task_id",
                (task_id,),
            ).fetchall()
        return tuple(row[0] for row in rows)

    def assert_dependencies_satisfied(self, task_id: str) -> None:
        for dependency_id in self.list_dependencies(task_id):
            latest = self.latest_run_for_task(dependency_id)
            if latest is None or latest.state is not TaskState.DONE:
                raise UnsatisfiedDependencyError(
                    f"Dependency {dependency_id} for {task_id} is not DONE"
                )

    def has_active_or_review_run(self, *, except_run_id: str | None = None) -> bool:
        query = "SELECT run_id FROM task_runs WHERE state IN (?, ?)"
        parameters: list[str] = [TaskState.RUNNING.value, TaskState.REVIEW.value]
        if except_run_id is not None:
            query += " AND run_id <> ?"
            parameters.append(except_run_id)
        with closing(self._connect()) as connection:
            return connection.execute(query, tuple(parameters)).fetchone() is not None

    def has_queue_blocker(self, *, except_run_id: str | None = None) -> bool:
        query = "SELECT run_id FROM task_runs WHERE state = ?"
        parameters: list[str] = [TaskState.BLOCKED.value]
        if except_run_id is not None:
            query += " AND run_id <> ?"
            parameters.append(except_run_id)
        with closing(self._connect()) as connection:
            return connection.execute(query, tuple(parameters)).fetchone() is not None

    def record_failure(
        self,
        run_id: str,
        resource_id: str,
        details: Mapping[str, Any],
        lease: Lease,
        *,
        actor: str,
        now: datetime | None = None,
    ) -> tuple[int, TaskRun]:
        current_time = now or utc_now()
        with self.fenced_transaction(lease, now=current_time) as connection:
            run_row = connection.execute(
                "SELECT state FROM task_runs WHERE run_id = ?", (run_id,)
            ).fetchone()
            if run_row is None:
                raise KeyError(run_id)
            from_state = TaskState(run_row["state"])
            if from_state is not TaskState.RUNNING:
                raise ValueError("Failures can only be recorded from RUNNING")
            attempt_row = connection.execute(
                "SELECT attempt_count FROM resource_attempts WHERE run_id = ? AND resource_id = ?",
                (run_id, resource_id),
            ).fetchone()
            attempt_count = (int(attempt_row["attempt_count"]) if attempt_row else 0) + 1
            connection.execute(
                """
                INSERT INTO resource_attempts(run_id, resource_id, attempt_count, last_failure_json, updated_at)
                VALUES (?, ?, ?, ?, ?)
                ON CONFLICT(run_id, resource_id) DO UPDATE SET
                    attempt_count = excluded.attempt_count,
                    last_failure_json = excluded.last_failure_json,
                    updated_at = excluded.updated_at
                """,
                (
                    run_id,
                    resource_id,
                    attempt_count,
                    _canonical_json(dict(details)),
                    isoformat(current_time),
                ),
            )
            to_state = (
                TaskState.NOT_COMPLETED if attempt_count == 1 else TaskState.BLOCKED
            )
            validate_transition(from_state, to_state)
            connection.execute(
                "UPDATE task_runs SET state = ?, updated_at = ? WHERE run_id = ?",
                (to_state.value, isoformat(current_time), run_id),
            )
            connection.execute(
                """
                INSERT INTO transition_events(
                    run_id, from_state, to_state, actor, reason, fencing_token, created_at
                ) VALUES (?, ?, ?, ?, ?, ?, ?)
                """,
                (
                    run_id,
                    from_state.value,
                    to_state.value,
                    actor,
                    f"resource_failure:{resource_id}:attempt:{attempt_count}",
                    lease.fencing_token,
                    isoformat(current_time),
                ),
            )
        return attempt_count, self.get_run(run_id)

    def attempt_count(self, run_id: str, resource_id: str) -> int:
        with closing(self._connect()) as connection:
            row = connection.execute(
                "SELECT attempt_count FROM resource_attempts WHERE run_id = ? AND resource_id = ?",
                (run_id, resource_id),
            ).fetchone()
        return int(row[0]) if row else 0

    def register_resource(
        self, resource_id: str, *, cooldown_required: bool, minimum_seconds: int
    ) -> None:
        if not resource_id or minimum_seconds < 0:
            raise ValueError("Resource ID and non-negative minimum_seconds are required")
        with self.transaction(immediate=True) as connection:
            connection.execute(
                """
                INSERT INTO coordinator_resources(resource_id, cooldown_required, minimum_seconds)
                VALUES (?, ?, ?)
                ON CONFLICT(resource_id) DO UPDATE SET
                    cooldown_required = excluded.cooldown_required,
                    minimum_seconds = excluded.minimum_seconds
                """,
                (resource_id, int(cooldown_required), minimum_seconds),
            )

    def get_resource(self, resource_id: str) -> CoordinatorResource:
        with closing(self._connect()) as connection:
            row = connection.execute(
                "SELECT * FROM coordinator_resources WHERE resource_id = ?", (resource_id,)
            ).fetchone()
        if row is None:
            raise KeyError(resource_id)
        return CoordinatorResource(
            resource_id=row["resource_id"],
            cooldown_required=bool(row["cooldown_required"]),
            minimum_seconds=int(row["minimum_seconds"]),
            state=ResourceState(row["state"]) if row["state"] else None,
            cooldown_started_at=(
                parse_datetime(row["cooldown_started_at"])
                if row["cooldown_started_at"]
                else None
            ),
            not_before=parse_datetime(row["not_before"]) if row["not_before"] else None,
        )

    def list_resources(self) -> tuple[CoordinatorResource, ...]:
        with closing(self._connect()) as connection:
            ids = [
                row[0]
                for row in connection.execute(
                    "SELECT resource_id FROM coordinator_resources ORDER BY resource_id"
                ).fetchall()
            ]
        return tuple(self.get_resource(resource_id) for resource_id in ids)

    def activate_cooldowns(
        self,
        resource_ids: Sequence[str],
        lease: Lease,
        *,
        now: datetime | None = None,
    ) -> tuple[str, ...]:
        from datetime import timedelta

        current_time = now or utc_now()
        activated: list[str] = []
        with self.fenced_transaction(lease, now=current_time) as connection:
            for resource_id in sorted(set(resource_ids)):
                row = connection.execute(
                    "SELECT cooldown_required, minimum_seconds FROM coordinator_resources WHERE resource_id = ?",
                    (resource_id,),
                ).fetchone()
                if row is None or not bool(row["cooldown_required"]):
                    continue
                not_before = current_time + timedelta(seconds=int(row["minimum_seconds"]))
                connection.execute(
                    """
                    UPDATE coordinator_resources
                    SET state = ?, cooldown_started_at = ?, not_before = ?
                    WHERE resource_id = ?
                    """,
                    (
                        ResourceState.COOLDOWN.value,
                        isoformat(current_time),
                        isoformat(not_before),
                        resource_id,
                    ),
                )
                activated.append(resource_id)
        return tuple(activated)

    def resource_available(self, resource_id: str, *, now: datetime | None = None) -> bool:
        current_time = now or utc_now()
        with self.transaction(immediate=True) as connection:
            row = connection.execute(
                "SELECT * FROM coordinator_resources WHERE resource_id = ?", (resource_id,)
            ).fetchone()
            if row is None or row["state"] is None:
                return True
            not_before = parse_datetime(row["not_before"])
            if current_time < not_before:
                return False
            connection.execute(
                """
                UPDATE coordinator_resources
                SET state = NULL, cooldown_started_at = NULL, not_before = NULL
                WHERE resource_id = ?
                """,
                (resource_id,),
            )
            return True

    def table_names(self) -> tuple[str, ...]:
        with closing(self._connect()) as connection:
            rows = connection.execute(
                "SELECT name FROM sqlite_master WHERE type = 'table' AND name NOT LIKE 'sqlite_%' ORDER BY name"
            ).fetchall()
        return tuple(row[0] for row in rows)
