"""SQLite operational store and schema migration v1."""

from __future__ import annotations

import hashlib
import json
import re
import sqlite3
import uuid
from collections.abc import Iterator, Mapping, Sequence
from contextlib import closing, contextmanager
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path
from typing import Any

from .dependency_graph import validate_dependency_graph
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


class GotaWorkerReservationError(GotaWorkerResultError):
    """Fail-closed error for the durable pre-Worker reservation boundary."""


_RESERVED_EVIDENCE_KINDS = frozenset(
    {
        "gota_acceptance_verified",
        "gota_worker_result_received",
        "gota_worker_request_registered",
        "gota_worker_invocation_started",
    }
)


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
            for table in ("contexts", "transition_events", "evidence", "checkpoints"):
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
            row = connection.execute(
                "SELECT * FROM global_lock WHERE lock_name = 'global'"
            ).fetchone()
            problem: CoordinatorStoreError | None = None
            if (
                row["owner_id"] != lease.owner_id
                or row["run_id"] != lease.run_id
                or int(row["fencing_token"]) != lease.fencing_token
                or bool(row["stale"])
            ):
                problem = FencingTokenError(
                    f"Stale or foreign fencing token {lease.fencing_token} for {lease.owner_id}"
                )
            elif parse_datetime(row["lease_expires_at"]) <= current_time:
                connection.execute(
                    "UPDATE global_lock SET stale = 1 WHERE lock_name = 'global'"
                )
                problem = LeaseExpiredError(
                    f"Lease {lease.fencing_token} expired at {row['lease_expires_at']}"
                )
            if problem is not None:
                if isinstance(problem, LeaseExpiredError):
                    connection.commit()
                else:
                    connection.rollback()
                connection.close()
                raise problem
            yield connection
            connection.commit()
        except (FencingTokenError, LeaseExpiredError):
            raise
        except BaseException:
            connection.rollback()
            raise
        finally:
            try:
                connection.close()
            except sqlite3.Error:
                pass

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

        def load_one_evidence(
            connection: sqlite3.Connection,
            kind: str,
        ) -> sqlite3.Row:
            rows = connection.execute(
                """
                SELECT * FROM evidence
                WHERE run_id = ? AND kind = ?
                ORDER BY rowid
                """,
                (run_id, kind),
            ).fetchall()
            if len(rows) != 1:
                raise AcceptanceEvidenceError(
                    f"Gota DONE requires exactly one {kind} evidence record"
                )
            row = rows[0]
            if int(row["fencing_token"]) != lease.fencing_token:
                raise AcceptanceEvidenceError(
                    f"Gota evidence {kind} was not recorded by the current fencing token"
                )
            try:
                payload = json.loads(row["payload_json"])
            except (TypeError, json.JSONDecodeError) as error:
                raise AcceptanceEvidenceError(
                    f"Gota evidence {kind} contains invalid JSON"
                ) from error
            if type(payload) is not dict or _digest(payload) != row["digest"]:
                raise AcceptanceEvidenceError(
                    f"Gota evidence {kind} failed its persisted digest check"
                )
            return row

        def load_worker_result(
            connection: sqlite3.Connection,
        ) -> tuple[sqlite3.Row, GotaWorkerResult]:
            row = load_one_evidence(connection, "gota_worker_result_received")
            try:
                payload = json.loads(row["payload_json"])
                result = GotaWorkerResult.from_payload(payload)
            except (TypeError, ValueError, KeyError) as error:
                raise AcceptanceEvidenceError(
                    "Persisted Gota Worker result is invalid"
                ) from error
            if _canonical_json(result.to_payload()) != _canonical_json(payload):
                raise AcceptanceEvidenceError(
                    "Persisted Gota Worker result is not canonical"
                )
            return row, result

        def load_review_result(
            connection: sqlite3.Connection,
        ) -> tuple[sqlite3.Row, GotaReviewResult]:
            row = load_one_evidence(connection, "gota_review_result")
            try:
                payload = json.loads(row["payload_json"])
                result = GotaReviewResult.from_payload(payload)
            except (TypeError, ValueError, KeyError) as error:
                raise AcceptanceEvidenceError(
                    "Persisted Gota Review result is invalid"
                ) from error
            if _canonical_json(result.to_payload()) != _canonical_json(payload):
                raise AcceptanceEvidenceError(
                    "Persisted Gota Review result is not canonical"
                )
            return row, result

        def load_verified_commit(
            connection: sqlite3.Connection,
        ) -> tuple[sqlite3.Row, dict[str, Any]]:
            row = load_one_evidence(connection, "gota_worker_commit_verified")
            try:
                payload = json.loads(row["payload_json"])
            except (TypeError, json.JSONDecodeError) as error:
                raise AcceptanceEvidenceError(
                    "Persisted Gota Worker commit verification is invalid JSON"
                ) from error
            required = {
                "request_id",
                "task_id",
                "run_id",
                "attempt",
                "commit_sha",
            }
            if type(payload) is not dict or set(payload) != required:
                raise AcceptanceEvidenceError(
                    "Persisted Gota Worker commit verification has invalid fields"
                )
            if (
                type(payload["request_id"]) is not str
                or type(payload["task_id"]) is not str
                or type(payload["run_id"]) is not str
                or type(payload["attempt"]) is not int
                or payload["attempt"] < 1
                or type(payload["commit_sha"]) is not str
                or re.fullmatch(r"[0-9a-f]{40}", payload["commit_sha"]) is None
            ):
                raise AcceptanceEvidenceError(
                    "Persisted Gota Worker commit verification has non-canonical values"
                )
            if _digest(payload) != row["digest"]:
                raise AcceptanceEvidenceError(
                    "Persisted Gota Worker commit verification failed its digest check"
                )
            return row, payload

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

            worker_row, worker_result = load_worker_result(connection)
            verified_row, verified_commit = load_verified_commit(connection)
            review_row, review_result = load_review_result(connection)
            task_id = run_row["task_id"]

            if (
                worker_result.run_id != run_id
                or worker_result.task_id != task_id
                or worker_result.result is not WorkerResultStatus.READY_FOR_REVIEW
            ):
                raise AcceptanceEvidenceError(
                    "Persisted Gota Worker identity or result is incoherent"
                )
            if (
                verified_commit["request_id"] != worker_result.request_id
                or verified_commit["task_id"] != worker_result.task_id
                or verified_commit["run_id"] != worker_result.run_id
                or verified_commit["attempt"] != worker_result.attempt
                or verified_commit["commit_sha"] != worker_result.commit_sha
            ):
                raise AcceptanceEvidenceError(
                    "Persisted Gota Worker commit SHA or identity is incoherent"
                )
            if (
                review_result.run_id != run_id
                or review_result.task_id != task_id
                or review_result.attempt != worker_result.attempt
                or review_result.decision is not ReviewDecision.PASSED
                or review_result.reviewed_commit_sha != worker_result.commit_sha
            ):
                raise AcceptanceEvidenceError(
                    "Persisted Gota Review result is incoherent or not PASSED"
                )

            acceptance_payload = {
                "run_id": run_id,
                "task_id": task_id,
                "attempt": worker_result.attempt,
                "worker_request_id": worker_result.request_id,
                "review_request_id": review_result.request_id,
                "worker_commit_sha": worker_result.commit_sha,
                "reviewed_commit_sha": review_result.reviewed_commit_sha,
                "decision": review_result.decision.value,
                "fencing_token": lease.fencing_token,
                "worker_result_evidence_id": worker_row["evidence_id"],
                "worker_commit_evidence_id": verified_row["evidence_id"],
                "review_result_evidence_id": review_row["evidence_id"],
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
