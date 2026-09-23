"""SQLite operational store and schema migration v1."""

from __future__ import annotations

import hashlib
import json
import sqlite3
import uuid
from collections.abc import Iterator, Mapping, Sequence
from contextlib import closing, contextmanager
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


def _canonical_json(value: Any) -> str:
    return json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=False)


def _digest(value: Any) -> str:
    return hashlib.sha256(_canonical_json(value).encode("utf-8")).hexdigest()


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
                if len(commits) != 1 or len(str(commits[0].get("sha", ""))) != 40:
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

    def append_evidence(
        self,
        run_id: str,
        kind: str,
        payload: Mapping[str, Any],
        lease: Lease,
        *,
        now: datetime | None = None,
    ) -> Evidence:
        evidence_id = str(uuid.uuid4())
        current_time = now or utc_now()
        payload_dict = dict(payload)
        digest = _digest(payload_dict)
        with self.fenced_transaction(lease, now=current_time) as connection:
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
