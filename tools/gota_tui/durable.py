"""Crash-tolerant local state for the Gota TUI."""

from __future__ import annotations

import json
import os
import re
import tempfile
import uuid
from dataclasses import dataclass
from datetime import UTC, datetime
from pathlib import Path
from typing import Any, Mapping

from flow_coordinator.sensitive_output import redact_sensitive_text


class DurableStateError(RuntimeError):
    """A local TUI state operation could not be completed safely."""


_SAFE_RUN_ID = re.compile(r"[A-Za-z0-9][A-Za-z0-9_.-]{0,127}")
_INCOMPLETE_STATES = frozenset({"PREPARED", "RUNNING", "CANCEL_REQUESTED"})


def default_state_root() -> Path:
    configured = os.environ.get("XDG_STATE_HOME", "").strip()
    root = Path(configured).expanduser() if configured else Path.home() / ".local/state"
    return root / "flow-coordinator" / "tui"


def default_coordinator_database(state_root: str | Path | None = None) -> Path:
    root = Path(state_root) if state_root is not None else default_state_root()
    return root.parent / "coordinator.sqlite3"


def _timestamp() -> str:
    return datetime.now(UTC).isoformat()


def _safe_run_id(run_id: str) -> str:
    if type(run_id) is not str or _SAFE_RUN_ID.fullmatch(run_id) is None:
        raise DurableStateError(f"Unsafe UI run_id: {run_id!r}")
    return run_id


def _fsync_directory(directory: Path) -> None:
    try:
        descriptor = os.open(directory, os.O_RDONLY | getattr(os, "O_DIRECTORY", 0))
    except OSError:
        return
    try:
        os.fsync(descriptor)
    except OSError:
        pass
    finally:
        os.close(descriptor)


def _atomic_bytes(path: Path, value: bytes) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    descriptor, temporary_name = tempfile.mkstemp(
        prefix=f".{path.name}.", suffix=".tmp", dir=path.parent
    )
    temporary_path = Path(temporary_name)
    try:
        with os.fdopen(descriptor, "wb") as file:
            file.write(value)
            file.flush()
            os.fsync(file.fileno())
        os.replace(temporary_path, path)
        _fsync_directory(path.parent)
    except BaseException:
        try:
            temporary_path.unlink()
        except FileNotFoundError:
            pass
        raise


def _atomic_text(path: Path, value: str) -> None:
    _atomic_bytes(path, value.encode("utf-8"))


def _atomic_json(path: Path, value: Mapping[str, Any]) -> None:
    _atomic_text(
        path,
        json.dumps(value, ensure_ascii=False, sort_keys=True, indent=2) + "\n",
    )


@dataclass(frozen=True, slots=True)
class RunPaths:
    run_id: str
    directory: Path

    @property
    def request(self) -> Path:
        return self.directory / "request.json"

    @property
    def prompt(self) -> Path:
        return self.directory / "prompt.txt"

    @property
    def prompt_sha(self) -> Path:
        return self.directory / "prompt.sha256"

    @property
    def live_log(self) -> Path:
        return self.directory / "live.log"

    @property
    def result(self) -> Path:
        return self.directory / "result.json"

    @property
    def report(self) -> Path:
        return self.directory / "report.txt"

    @property
    def opencode_output(self) -> Path:
        return self.directory / "opencode-output.txt"


class DurableRunStore:
    """Owns only TUI files, never the Coordinator's operational state."""

    def __init__(self, state_root: str | Path | None = None) -> None:
        self.root = Path(state_root).expanduser() if state_root is not None else default_state_root()
        self.runs_root = self.root / "runs"
        self.history_path = self.root / "history.jsonl"

    def paths(self, run_id: str) -> RunPaths:
        safe_id = _safe_run_id(run_id)
        return RunPaths(safe_id, self.runs_root / safe_id)

    def prepare(
        self,
        *,
        action_id: str,
        model: str,
        variant: str,
        agent: str,
        repository: str,
        prompt: str,
        prompt_sha256: str,
        template: Mapping[str, Any],
        envelope: Mapping[str, Any],
        run_id: str | None = None,
        allow_empty_prompt: bool = False,
        timeout: float | None = None,
        opencode_output: bool = False,
        role: str | None = None,
        model_source: str | None = None,
        variant_source: str | None = None,
        role_source: str | None = None,
        agent_source: str | None = None,
    ) -> RunPaths:
        if type(prompt) is not str or (not allow_empty_prompt and not prompt.strip()):
            raise DurableStateError("Cannot persist an empty prompt")
        chosen_id = _safe_run_id(run_id or str(uuid.uuid4()))
        paths = self.paths(chosen_id)
        if paths.directory.exists():
            raise DurableStateError(f"TUI run already exists: {chosen_id}")
        paths.directory.mkdir(parents=True, exist_ok=False)
        created_at = _timestamp()
        # The prompt and its digest are durable before request metadata can say
        # that this run is ready. The caller cannot spawn until this returns.
        _atomic_text(paths.prompt, prompt)
        _atomic_text(paths.prompt_sha, prompt_sha256 + "\n")
        _atomic_bytes(paths.live_log, b"")
        if opencode_output:
            _atomic_bytes(paths.opencode_output, b"")
        request = {
            "schema": "flow.coordinator/tui-run/v1",
            "run_id": chosen_id,
            "created_at": created_at,
            "timestamp": created_at,
            "updated_at": created_at,
            "ui_state": "PREPARED",
            "action_id": action_id,
            "model": model,
            "variant": variant,
            "agent": agent,
            "role": role,
            "model_source": model_source,
            "variant_source": variant_source,
            "role_source": role_source,
            "agent_source": agent_source,
            "repository": repository,
            "prompt": prompt,
            "prompt_sha256": prompt_sha256,
            "timeout": timeout,
            "template": dict(template),
            "envelope": dict(envelope),
            "coordinator_run_id": None,
        }
        if opencode_output:
            request["opencode_output_path"] = str(paths.opencode_output)
        _atomic_json(paths.request, request)
        self._append_history(
            {
                "event": "prepared",
                "run_id": chosen_id,
                "updated_at": created_at,
                "ui_state": "PREPARED",
                "action_id": action_id,
                "model": model,
                "variant": variant,
                "agent": agent,
                "role": role,
                "model_source": model_source,
                "variant_source": variant_source,
                "role_source": role_source,
                "agent_source": agent_source,
                "repository": repository,
                "prompt_sha256": prompt_sha256,
                "coordinator_run_id": None,
                "task_id": None,
                "verdict": None,
            }
        )
        return paths

    def _read_request(self, run_id: str) -> dict[str, Any]:
        paths = self.paths(run_id)
        try:
            payload = json.loads(paths.request.read_text(encoding="utf-8"))
        except (OSError, UnicodeError, json.JSONDecodeError) as error:
            raise DurableStateError(f"Cannot read TUI request for {run_id}: {error}") from error
        if type(payload) is not dict:
            raise DurableStateError(f"TUI request for {run_id} is not an object")
        return payload

    def request(self, run_id: str) -> Mapping[str, Any]:
        return dict(self._read_request(run_id))

    def update_request(self, run_id: str, **updates: Any) -> Mapping[str, Any]:
        payload = self._read_request(run_id)
        payload.update(updates)
        payload["updated_at"] = _timestamp()
        _atomic_json(self.paths(run_id).request, payload)
        self._append_history(
            {
                "event": "updated",
                "run_id": run_id,
                "updated_at": payload["updated_at"],
                "ui_state": payload.get("ui_state"),
                "action_id": payload.get("action_id"),
                "model": payload.get("model"),
                "variant": payload.get("variant"),
                "agent": payload.get("agent"),
                "role": payload.get("role"),
                "model_source": payload.get("model_source"),
                "variant_source": payload.get("variant_source"),
                "role_source": payload.get("role_source"),
                "agent_source": payload.get("agent_source"),
                "repository": payload.get("repository"),
                "prompt_sha256": payload.get("prompt_sha256"),
                "coordinator_run_id": payload.get("coordinator_run_id"),
                "task_id": payload.get("task_id"),
                "verdict": payload.get("verdict"),
                "coordinator_state": payload.get("coordinator_state"),
                "report_path": payload.get("report_path"),
                "run_started_at": payload.get("run_started_at"),
                "run_finished_at": payload.get("run_finished_at"),
                "run_duration_ms": payload.get("run_duration_ms"),
                "run_process_duration_ms": payload.get("run_process_duration_ms"),
            }
        )
        return dict(payload)

    def append_log(self, run_id: str, text: str) -> None:
        if type(text) is not str:
            raise TypeError("TUI log text must be a string")
        text = redact_sensitive_text(text)
        path = self.paths(run_id).live_log
        path.parent.mkdir(parents=True, exist_ok=True)
        with path.open("ab") as file:
            file.write(text.encode("utf-8"))
            file.flush()
            os.fsync(file.fileno())

    def persist_result(self, run_id: str, result: Mapping[str, Any]) -> Path:
        payload = dict(result)
        _atomic_json(self.paths(run_id).result, payload)
        return self.paths(run_id).result

    def persist_report(self, run_id: str, report: str) -> Path:
        if type(report) is not str or not report.strip():
            raise DurableStateError("Cannot persist an empty report")
        path = self.paths(run_id).report
        _atomic_text(path, report)
        return path

    def persist_opencode_output(self, run_id: str, stdout: str, stderr: str) -> Path:
        """Persist complete observed OpenCode channels as an associated artifact."""

        if type(stdout) is not str or type(stderr) is not str:
            raise TypeError("OpenCode output must be text")
        stdout = redact_sensitive_text(stdout)
        stderr = redact_sensitive_text(stderr)
        text = "STDOUT_BEGIN\n" + stdout + "\nSTDOUT_END\n"
        text += "STDERR_BEGIN\n" + stderr + "\nSTDERR_END\n"
        path = self.paths(run_id).opencode_output
        _atomic_text(path, text)
        return path

    def finalize(
        self,
        run_id: str,
        *,
        ui_state: str,
        verdict: str,
        coordinator_state: str | None,
        task_id: str | None,
        coordinator_run_id: str | None,
        run_started_at: str | None = None,
        run_finished_at: str | None = None,
        run_duration_ms: int | None = None,
        run_process_duration_ms: int | None = None,
    ) -> Mapping[str, Any]:
        updates: dict[str, Any] = {
            "ui_state": ui_state,
            "verdict": verdict,
            "coordinator_state": coordinator_state,
            "task_id": task_id,
            "coordinator_run_id": coordinator_run_id,
            "report_path": str(self.paths(run_id).report),
            "log_path": str(self.paths(run_id).live_log),
        }
        if run_started_at is not None:
            updates["run_started_at"] = run_started_at
        if run_finished_at is not None:
            updates["run_finished_at"] = run_finished_at
        if run_duration_ms is not None:
            updates["run_duration_ms"] = run_duration_ms
        if run_process_duration_ms is not None:
            updates["run_process_duration_ms"] = run_process_duration_ms
        return self.update_request(
            run_id,
            **updates,
        )

    def mark_interrupted(self, run_id: str) -> Mapping[str, Any]:
        return self.update_request(
            run_id,
            ui_state="UI_INTERRUPTED",
            interrupted_reason="TUI ended before a durable final result was recorded",
        )

    def _append_history(self, payload: Mapping[str, Any]) -> None:
        self.root.mkdir(parents=True, exist_ok=True)
        line = json.dumps(dict(payload), ensure_ascii=False, sort_keys=True) + "\n"
        with self.history_path.open("ab") as file:
            if self.history_path.stat().st_size:
                with self.history_path.open("rb") as existing:
                    existing.seek(-1, os.SEEK_END)
                    if existing.read(1) != b"\n":
                        file.write(b"\n")
            file.write(line.encode("utf-8"))
            file.flush()
            os.fsync(file.fileno())

    def history_records(self) -> tuple[Mapping[str, Any], ...]:
        if not self.history_path.exists():
            return ()
        latest: dict[str, dict[str, Any]] = {}
        try:
            lines = self.history_path.read_text(encoding="utf-8").splitlines()
        except (OSError, UnicodeError) as error:
            raise DurableStateError(f"Cannot read TUI history: {error}") from error
        for line in lines:
            if not line.strip():
                continue
            try:
                payload = json.loads(line)
            except json.JSONDecodeError:
                # A truncated final JSONL record must not hide earlier runs.
                continue
            if type(payload) is not dict or type(payload.get("run_id")) is not str:
                continue
            latest[payload["run_id"]] = payload
        return tuple(
            sorted(
                (dict(record) for record in latest.values()),
                key=lambda record: str(record.get("updated_at", "")),
                reverse=True,
            )
        )

    def recover_interrupted(self) -> tuple[str, ...]:
        interrupted: list[str] = []
        for record in self.history_records():
            run_id = record.get("run_id")
            if type(run_id) is not str:
                continue
            try:
                request = self.request(run_id)
            except DurableStateError:
                continue
            if request.get("ui_state") not in _INCOMPLETE_STATES:
                continue
            if self.paths(run_id).result.exists() or self.paths(run_id).report.exists():
                continue
            self.mark_interrupted(run_id)
            interrupted.append(run_id)
        return tuple(interrupted)

    def read_prompt(self, run_id: str) -> str:
        try:
            return self.paths(run_id).prompt.read_text(encoding="utf-8")
        except (OSError, UnicodeError) as error:
            raise DurableStateError(f"Cannot read prompt for {run_id}: {error}") from error

    def read_report(self, run_id: str) -> str:
        try:
            return self.paths(run_id).report.read_text(encoding="utf-8")
        except (OSError, UnicodeError) as error:
            raise DurableStateError(f"Cannot read report for {run_id}: {error}") from error
