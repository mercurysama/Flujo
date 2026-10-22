"""Registered action execution and report lifecycle."""

from __future__ import annotations

import hashlib
import json
import os
import subprocess
import sys
import threading
from dataclasses import asdict, dataclass
from datetime import UTC, datetime
from pathlib import Path
from threading import Event
from typing import Any, Callable, Mapping

from flow_coordinator import SQLiteCoordinatorStore
from flow_coordinator.git_adapter import GitReadError, ReadOnlyGitAdapter

from .actions import ActionDefinition
from .clipboard import ClipboardWriter
from .coordinator_facade import CoordinatorGotaFacade, CoordinatorOutcome
from .durable import DurableRunStore, RunPaths, default_coordinator_database
from .envelope import PromptEnvelope
from .prompt_library import PromptComposition, PromptLibrary
from .reporting import ReportData, ReportManager, PersistedReport


class ExecutionError(RuntimeError):
    """A registered action could not be prepared or executed."""


@dataclass(frozen=True, slots=True)
class TUIConfig:
    repository: Path
    database: Path
    opencode_executable: str = "opencode"
    model_override: str | None = None
    variant_override: str | None = None
    timeout: float = 1800.0


@dataclass(frozen=True, slots=True)
class PreparedAction:
    action: ActionDefinition
    envelope: PromptEnvelope
    composition: PromptComposition | None
    paths: RunPaths


@dataclass(slots=True)
class ActionExecutionResult:
    run_id: str
    paths: RunPaths
    report: str
    report_path: str
    log_path: str
    clipboard_status: str
    clipboard_error: str | None
    verdict: str
    coordinator_state: str | None
    task_id: str | None
    coordinator_run_id: str | None
    diagnostic: str


class ActionExecutor:
    """Prepare durable UI state, dispatch only registered backends, and report."""

    def __init__(
        self,
        *,
        config: TUIConfig,
        runs: DurableRunStore,
        prompts: PromptLibrary,
        clipboard_writer: ClipboardWriter,
        output_sink: Callable[[str], None] | None = None,
    ) -> None:
        self.config = config
        self.runs = runs
        self.prompts = prompts
        self.clipboard_writer = clipboard_writer
        self.output_sink = output_sink

    def _model(self, action: ActionDefinition) -> str:
        return self.config.model_override or action.model or ""

    def _variant(self, action: ActionDefinition) -> str:
        return self.config.variant_override or action.variant or ""

    def prepare(
        self,
        action: ActionDefinition,
        envelope: PromptEnvelope,
        *,
        run_id: str | None = None,
    ) -> PreparedAction:
        if action.requires_prompt and not envelope.original.strip():
            raise ExecutionError(f"Action {action.id} requires a non-empty prompt")
        if action.mutable:
            envelope.require_mutable_fields()
        composition: PromptComposition | None = None
        if action.template:
            composition = self.prompts.compose(action.template, envelope.assignment)
        original_sha = hashlib.sha256(envelope.original.encode("utf-8")).hexdigest()
        template_payload: dict[str, Any] = {}
        if composition is not None:
            template_payload = {
                "id": composition.template_id,
                "version": composition.template_version,
                "composition_sha256": composition.sha256,
            }
        paths = self.runs.prepare(
            action_id=action.id,
            model=self._model(action),
            variant=self._variant(action),
            agent=action.agent,
            repository=str(self.config.repository),
            prompt=envelope.original,
            prompt_sha256=original_sha,
            template=template_payload,
            envelope=envelope.metadata,
            run_id=run_id,
            allow_empty_prompt=not action.requires_prompt,
        )
        return PreparedAction(action, envelope, composition, paths)

    def execute(
        self,
        prepared: PreparedAction,
        *,
        cancel_event: Event | None = None,
    ) -> ActionExecutionResult:
        cancel = cancel_event or Event()
        action = prepared.action
        if cancel.is_set():
            return self._finish(
                prepared,
                CoordinatorOutcome(
                    verdict="UI_CANCELLED",
                    cancelled=True,
                    diagnostic="Cancelled before the registered backend started",
                ),
                cancel_status="UI_CANCELLED",
            )
        self.runs.update_request(prepared.paths.run_id, ui_state="RUNNING")
        try:
            if action.backend == "gota-task":
                if prepared.composition is None:
                    raise ExecutionError("Gota task action has no prompt composition")
                outcome = CoordinatorGotaFacade(
                    database=self.config.database,
                    opencode_executable=self.config.opencode_executable,
                    model=self._model(action),
                    variant=self._variant(action),
                    timeout=self.config.timeout,
                    owner_id=f"gota-tui:{os.getpid()}:{prepared.paths.run_id}",
                    output=self._open_code_output(prepared.paths.run_id),
                    cancel_event=cancel,
                ).execute_new_task(prepared.envelope, prepared.composition)
                return self._finish(prepared, outcome)

            if action.backend == "gota-review":
                outcome = CoordinatorGotaFacade(
                    database=self.config.database,
                    opencode_executable=self.config.opencode_executable,
                    model=self._model(action),
                    variant=self._variant(action),
                    timeout=self.config.timeout,
                    owner_id=f"gota-tui:{os.getpid()}:{prepared.paths.run_id}",
                    output=self._open_code_output(prepared.paths.run_id),
                    cancel_event=cancel,
                ).review_existing(prepared.envelope)
                return self._finish(prepared, outcome)

            outcome = self._execute_registered_read_only(prepared, cancel)
            return self._finish(prepared, outcome)
        except Exception as error:
            return self._finish(
                prepared,
                CoordinatorOutcome(
                    verdict="CYCLE_FAILED",
                    diagnostic=f"Registered backend failed: {type(error).__name__}: {error}",
                ),
            )

    def _open_code_output(self, run_id: str) -> Callable[[str, str], None]:
        def receive(source: str, text: str) -> None:
            stamp = datetime.now(UTC).isoformat()
            entry = f"{stamp} [{source.upper()}] {text}"
            self.runs.append_log(run_id, entry)
            if self.output_sink is not None:
                self.output_sink(entry)

        return receive

    def _log(self, run_id: str, text: str) -> None:
        entry = f"{datetime.now(UTC).isoformat()} [GOTA] {text}\n"
        self.runs.append_log(run_id, entry)
        if self.output_sink is not None:
            self.output_sink(entry)

    def _execute_registered_read_only(
        self,
        prepared: PreparedAction,
        cancel: Event,
    ) -> CoordinatorOutcome:
        action = prepared.action
        run_id = prepared.paths.run_id
        if action.backend == "git-audit":
            return self._git_audit(prepared)
        if action.backend == "coordinator-status":
            return self._coordinator_status(prepared)
        if action.backend == "diagnostics":
            return self._diagnostics(prepared)
        if action.backend == "recovery-readonly":
            interrupted = self.runs.recover_interrupted()
            self._log(run_id, f"Recovered UI records: {len(interrupted)}")
            return CoordinatorOutcome(
                verdict="READ_ONLY_OK",
                diagnostic=f"UI recovery inspection found {len(interrupted)} interrupted run(s)",
            )
        if action.backend == "coordinator-tests":
            return self._fixed_command(
                prepared,
                cancel,
                [
                    sys.executable,
                    "-B",
                    "-m",
                    "unittest",
                    "discover",
                    "-s",
                    "tools/coordinator/tests",
                    "-v",
                ],
                tests=True,
            )
        if action.backend == "production-validation":
            resolver = self.config.repository / "tools/godot/resolve_godot.py"
            return self._fixed_command(
                prepared,
                cancel,
                [
                    sys.executable,
                    "-B",
                    str(resolver),
                    "--",
                    "--headless",
                    "--editor",
                    "--path",
                    str(self.config.repository),
                    "--quit-after",
                    "5",
                ],
                tests=True,
            )
        if action.backend == "clipboard-preview":
            return CoordinatorOutcome(
                verdict="PREVIEW_ONLY",
                diagnostic="Clipboard prompt is ready for action selection",
            )
        if action.backend == "history":
            return CoordinatorOutcome(verdict="PREVIEW_ONLY", diagnostic="History is a UI view")
        raise ExecutionError(f"No executor exists for registered backend {action.backend!r}")

    def _git_audit(self, prepared: PreparedAction) -> CoordinatorOutcome:
        try:
            snapshot = ReadOnlyGitAdapter(self.config.repository).snapshot()
        except GitReadError as error:
            return CoordinatorOutcome(verdict="READ_ONLY_FAILED", diagnostic=str(error))
        self._log(
            prepared.paths.run_id,
            f"Read-only Git snapshot: HEAD={snapshot.head} branch={snapshot.branch} status={snapshot.status or 'clean'}",
        )
        return CoordinatorOutcome(
            base_sha=snapshot.head,
            commit_sha=snapshot.head,
            coordinator_state="READ_ONLY",
            verdict="READ_ONLY_OK" if not snapshot.status else "READ_ONLY_FAILED",
            diff_check="NOT_REQUESTED",
            diagnostic="Read-only Git audit completed" if not snapshot.status else snapshot.status,
        )

    def _coordinator_status(self, prepared: PreparedAction) -> CoordinatorOutcome:
        if not self.config.database.exists():
            return CoordinatorOutcome(
                coordinator_state="UNINITIALIZED",
                verdict="READ_ONLY_OK",
                diagnostic=f"Coordinator database does not exist: {self.config.database}",
            )
        try:
            store = SQLiteCoordinatorStore(self.config.database)
            runs = store.list_runs()
            lock = CoordinatorServiceForStatus(store).inspect_lock()
            self._log(
                prepared.paths.run_id,
                f"Coordinator status: tasks={len(store.list_task_specs())} runs={len(runs)} lock={lock}",
            )
            return CoordinatorOutcome(
                coordinator_state="AVAILABLE",
                verdict="READ_ONLY_OK",
                diagnostic=f"Coordinator has {len(runs)} run(s); lock={lock}",
            )
        except Exception as error:
            return CoordinatorOutcome(
                coordinator_state="UNAVAILABLE",
                verdict="READ_ONLY_FAILED",
                diagnostic=f"Coordinator status failed: {type(error).__name__}: {error}",
            )

    def _diagnostics(self, prepared: PreparedAction) -> CoordinatorOutcome:
        version = self._opencode_version()
        self._log(prepared.paths.run_id, f"OpenCode: {version}")
        self._log(prepared.paths.run_id, f"Repository: {self.config.repository}")
        self._log(prepared.paths.run_id, f"Coordinator DB: {self.config.database}")
        return CoordinatorOutcome(
            verdict="READ_ONLY_OK" if not version.startswith("unavailable") else "READ_ONLY_FAILED",
            diagnostic=f"OpenCode={version}; state_root={self.runs.root}",
        )

    def _opencode_version(self) -> str:
        try:
            result = subprocess.run(
                [self.config.opencode_executable, "--version"],
                cwd=self.config.repository,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True,
                encoding="utf-8",
                errors="replace",
                timeout=5,
                check=False,
                shell=False,
            )
        except (OSError, subprocess.SubprocessError) as error:
            return f"unavailable ({type(error).__name__}: {error})"
        output = (result.stdout or result.stderr).strip()
        return output or f"unavailable (exit={result.returncode})"

    def _fixed_command(
        self,
        prepared: PreparedAction,
        cancel: Event,
        argv: list[str],
        *,
        tests: bool,
    ) -> CoordinatorOutcome:
        self._log(prepared.paths.run_id, "Executing fixed read-only argv: " + json.dumps(argv))
        environment = os.environ.copy()
        environment["PYTHONDONTWRITEBYTECODE"] = "1"
        if argv[2:5] == ["-m", "unittest", "discover"]:
            coordinator_source = self.config.repository / "tools/coordinator/src"
            inherited_pythonpath = environment.get("PYTHONPATH")
            environment["PYTHONPATH"] = os.pathsep.join(
                path
                for path in (str(coordinator_source), inherited_pythonpath)
                if path
            )
        try:
            process = subprocess.Popen(
                argv,
                cwd=self.config.repository,
                env=environment,
                stdin=subprocess.DEVNULL,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True,
                encoding="utf-8",
                errors="replace",
                shell=False,
            )
        except OSError as error:
            return CoordinatorOutcome(verdict="READ_ONLY_FAILED", diagnostic=str(error))

        assert process.stdout is not None and process.stderr is not None
        output_lock = threading.Lock()

        def pump(stream: Any, source: str) -> None:
            for line in iter(stream.readline, ""):
                with output_lock:
                    stamp = datetime.now(UTC).isoformat()
                    entry = f"{stamp} [{source}] {line}"
                    self.runs.append_log(prepared.paths.run_id, entry)
                    if self.output_sink is not None:
                        self.output_sink(entry)

        threads = [
            threading.Thread(target=pump, args=(process.stdout, "OUT"), daemon=True),
            threading.Thread(target=pump, args=(process.stderr, "ERR"), daemon=True),
        ]
        for thread in threads:
            thread.start()
        while process.poll() is None:
            if cancel.is_set():
                process.terminate()
                try:
                    process.wait(timeout=1.0)
                except subprocess.TimeoutExpired:
                    process.kill()
                    process.wait(timeout=1.0)
                return CoordinatorOutcome(
                    verdict="UI_CANCELLED",
                    cancelled=True,
                    diagnostic="Fixed read-only process terminated by UI request",
                )
            try:
                process.wait(timeout=0.05)
            except subprocess.TimeoutExpired:
                pass
        for thread in threads:
            thread.join(timeout=1.0)
        status = f"exit={process.returncode}"
        return CoordinatorOutcome(
            verdict="READ_ONLY_OK" if process.returncode == 0 else "READ_ONLY_FAILED",
            tests=status if tests else None,
            diagnostic=f"Fixed read-only command {status}",
        )

    def _finish(
        self,
        prepared: PreparedAction,
        outcome: CoordinatorOutcome,
        *,
        cancel_status: str | None = None,
    ) -> ActionExecutionResult:
        action = prepared.action
        request = self.runs.request(prepared.paths.run_id)
        coordinator_run_id = outcome.coordinator_run_id
        task_id = outcome.task_id
        coordinator_state = outcome.coordinator_state
        verdict = cancel_status or outcome.verdict
        result_payload = asdict(outcome)
        result_payload["ui_run_id"] = prepared.paths.run_id
        self.runs.persist_result(prepared.paths.run_id, result_payload)

        report_data = ReportData(
            run_id=prepared.paths.run_id,
            action=action.id,
            task_id=task_id,
            context_id=(
                prepared.envelope.metadata.get("context_id")
                if type(prepared.envelope.metadata.get("context_id")) is str
                else None
            ),
            model=self._model(action) or None,
            variant=self._variant(action) or None,
            opencode_version=self._opencode_version() if action.backend in {"gota-task", "gota-review"} else None,
            repository=str(self.config.repository),
            base_sha=outcome.base_sha,
            commit_sha=outcome.commit_sha,
            coordinator_state=coordinator_state,
            worker_result=outcome.worker_result,
            review_result=outcome.review_result,
            tests=outcome.tests,
            diff_check=outcome.diff_check,
            prompt_sha256=request.get("prompt_sha256"),
            report_path=str(prepared.paths.report),
            log_path=str(prepared.paths.live_log),
            findings=list(outcome.findings),
            verdict=verdict,
            diagnostic=outcome.diagnostic,
        )
        persisted: PersistedReport = ReportManager(
            self.runs, self.clipboard_writer
        ).persist_before_copy(report_data)
        ui_state = "UI_CANCELLED" if outcome.cancelled or cancel_status else "COMPLETED"
        self.runs.finalize(
            prepared.paths.run_id,
            ui_state=ui_state,
            verdict=verdict,
            coordinator_state=coordinator_state,
            task_id=task_id,
            coordinator_run_id=coordinator_run_id,
        )
        return ActionExecutionResult(
            run_id=prepared.paths.run_id,
            paths=prepared.paths,
            report=persisted.text,
            report_path=persisted.path,
            log_path=str(prepared.paths.live_log),
            clipboard_status=persisted.clipboard_status,
            clipboard_error=persisted.clipboard_error,
            verdict=verdict,
            coordinator_state=coordinator_state,
            task_id=task_id,
            coordinator_run_id=coordinator_run_id,
            diagnostic=outcome.diagnostic,
        )


class CoordinatorServiceForStatus:
    """Tiny read-only adapter kept separate from mutable service methods."""

    def __init__(self, store: SQLiteCoordinatorStore) -> None:
        self.store = store

    def inspect_lock(self) -> Mapping[str, Any]:
        from flow_coordinator.lock import GlobalLockManager

        return GlobalLockManager(self.store).inspect()


def default_config(state_root: str | Path | None = None) -> TUIConfig:
    root = Path(state_root) if state_root is not None else None
    return TUIConfig(
        repository=Path.cwd().resolve(),
        database=default_coordinator_database(root),
        opencode_executable=os.environ.get("GOTA_OPENCODE", "opencode"),
        model_override=os.environ.get("GOTA_TUI_MODEL") or None,
        variant_override=os.environ.get("GOTA_TUI_VARIANT") or None,
    )
