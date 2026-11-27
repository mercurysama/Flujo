"""Small, state-free subprocess boundary for OpenCode."""

from __future__ import annotations

import math
import os
import shutil
import signal
import subprocess
import sys
import tempfile
import codecs
import threading
import time
import uuid
from dataclasses import dataclass, replace
from enum import StrEnum
from pathlib import Path
from typing import Any, Callable, Final

from .gota_protocol import (
    GotaProtocolError,
    GotaProtocolErrorCode,
    GotaReviewResult,
    GotaWorkerResult,
    parse_gota_output,
)
from .sensitive_output import SensitiveOutputRedactor


DEFAULT_OPENCODE_MODEL: Final[str] = "openai/gpt-5.6-luna"
DEFAULT_OPENCODE_VARIANT: Final[str] = "max"
DEFAULT_OPENCODE_AGENT: Final[str] = "build"
_PROCESS_TERM_GRACE_SECONDS: Final[float] = 0.25
_PROCESS_KILL_GRACE_SECONDS: Final[float] = 0.25
_POST_TIMEOUT_COMMUNICATE_SECONDS: Final[float] = 0.25
_PROCESS_REAP_GRACE_SECONDS: Final[float] = 0.05
_SYSTEMD_COMMAND_TIMEOUT_SECONDS: Final[float] = 0.25
_SYSTEMD_COLLECTION_GRACE_SECONDS: Final[float] = 1.0
_SYSTEMD_COLLECTION_POLL_SECONDS: Final[float] = 0.01
_SYSTEMD_UNIT_PREFIX: Final[str] = "flow-gota-"
_WRAPPER_SCRIPT: Final[Path] = Path(__file__).with_name("opencode_wrapper.py")


class OpenCodeRunStatus(StrEnum):
    """The mutually exclusive outcome of one OpenCode process attempt."""

    SUCCEEDED = "succeeded"
    INVALID_PAYLOAD = "invalid_payload"
    NON_ZERO_EXIT = "non_zero_exit"
    TIMEOUT = "timeout"
    CANCELLED = "cancelled"
    START_FAILED = "start_failed"


class OpenCodeStartFailure(StrEnum):
    """The failed boundary when a run cannot reach a target result."""

    INVALID_CWD = "invalid_cwd"
    CONTAINMENT_UNAVAILABLE = "containment_unavailable"
    TARGET_EXECUTABLE = "target_executable"


GotaResult = GotaWorkerResult | GotaReviewResult
OutputCallback = Callable[[str, str], None]


@dataclass(frozen=True, slots=True)
class OpenCodeRunResult:
    """Captured process data and, when valid, one parsed Gota result.

    ``process_duration_ms`` is optional because no child exists for some
    pre-start failures. When present, it is measured monotonically from the
    existing runner subprocess spawn through final pipe collection.
    """

    status: OpenCodeRunStatus
    argv: tuple[str, ...]
    cwd: str
    stdout: str
    stderr: str
    exit_code: int | None
    timed_out: bool
    payload: GotaResult | None = None
    error: str | None = None
    protocol_error_code: GotaProtocolErrorCode | None = None
    start_failure: OpenCodeStartFailure | None = None
    process_duration_ms: int | None = None


class OpenCodeRunner:
    """Run one command behind an externally managed Linux cgroup."""

    def __init__(
        self,
        *,
        executable: str | Path = "opencode",
        model: str = DEFAULT_OPENCODE_MODEL,
        variant: str | None = DEFAULT_OPENCODE_VARIANT,
        monotonic_ns: Callable[[], int] | None = None,
    ) -> None:
        self.executable = self._required_text(executable, "executable")
        self.model = self._validate_model(model)
        self.variant = None if variant is None else self._validate_variant(variant)
        self._monotonic_ns = monotonic_ns or time.monotonic_ns

    def _with_process_duration(
        self,
        result: OpenCodeRunResult,
        started_monotonic_ns: int | None,
        finished_monotonic_ns: int | None = None,
    ) -> OpenCodeRunResult:
        if started_monotonic_ns is None:
            return result
        elapsed_ns = (
            (self._monotonic_ns() if finished_monotonic_ns is None else finished_monotonic_ns)
            - started_monotonic_ns
        )
        return replace(result, process_duration_ms=max(0, elapsed_ns // 1_000_000))

    @staticmethod
    def _required_text(value: str | Path, field: str) -> str:
        text = str(value)
        if not text.strip():
            raise ValueError(f"{field} must be a non-empty string")
        return text

    @classmethod
    def _validate_model(cls, value: str | Path) -> str:
        model = cls._required_text(value, "model")
        provider, separator, model_name = model.partition("/")
        if (
            not separator
            or not provider.strip()
            or not model_name.strip()
            or any(character.isspace() for character in model)
            or "#" in model
            or "/" in model_name
        ):
            raise ValueError(
                "model must use the non-empty provider/model format without whitespace"
            )
        return model

    @classmethod
    def _validate_variant(cls, value: str | Path) -> str:
        variant = cls._required_text(value, "variant")
        if any(character.isspace() for character in variant):
            raise ValueError("variant must not contain whitespace")
        return variant

    def _build_argv(self, agent: str, prompt: str) -> list[str]:
        model_selector = (
            self.model if self.variant is None else f"{self.model}#{self.variant}"
        )
        argv = [
            self.executable,
            "run",
            "--standalone",
            "--model",
            model_selector,
        ]
        argv.extend(("--agent", agent, "--auto", prompt))
        return argv

    @staticmethod
    def _validate_timeout(timeout: float) -> float:
        if isinstance(timeout, bool) or not isinstance(timeout, (int, float)):
            raise TypeError("timeout must be a positive finite number")
        if not math.isfinite(timeout) or timeout <= 0:
            raise ValueError("timeout must be a positive finite number")
        return float(timeout)

    @staticmethod
    def _bounded_wait(process: subprocess.Popen[str], timeout: float) -> None:
        try:
            process.wait(timeout=timeout)
        except subprocess.TimeoutExpired:
            pass

    @classmethod
    def _terminate_process(cls, process: subprocess.Popen[str]) -> None:
        """Terminate a non-Linux process group with fixed bounds."""

        if process.poll() is not None:
            return
        if os.name == "posix":
            try:
                os.killpg(process.pid, signal.SIGTERM)
            except ProcessLookupError:
                pass
            except OSError:
                try:
                    process.terminate()
                except ProcessLookupError:
                    pass
        else:
            try:
                process.terminate()
            except ProcessLookupError:
                pass
        cls._bounded_wait(process, _PROCESS_TERM_GRACE_SECONDS)

        if process.poll() is None:
            if os.name == "posix":
                try:
                    os.killpg(process.pid, signal.SIGKILL)
                except ProcessLookupError:
                    pass
                except OSError:
                    try:
                        process.kill()
                    except ProcessLookupError:
                        pass
            else:
                try:
                    process.kill()
                except ProcessLookupError:
                    pass
        cls._bounded_wait(process, _PROCESS_KILL_GRACE_SECONDS)

    @staticmethod
    def _run_systemctl(
        systemctl: str, arguments: list[str], timeout: float
    ) -> subprocess.CompletedProcess[str] | None:
        try:
            return subprocess.run(
                [systemctl, "--user", *arguments],
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True,
                encoding="utf-8",
                errors="replace",
                timeout=timeout,
                check=False,
            )
        except (OSError, subprocess.TimeoutExpired):
            return None

    @classmethod
    def _check_systemd_user(cls) -> tuple[tuple[str, str] | None, str | None]:
        systemd_run = shutil.which("systemd-run")
        systemctl = shutil.which("systemctl")
        if systemd_run is None or systemctl is None:
            return None, "systemd-run and systemctl are required for Linux containment"

        result = cls._run_systemctl(
            systemctl,
            ["is-system-running"],
            _SYSTEMD_COMMAND_TIMEOUT_SECONDS,
        )
        if result is None:
            return None, "systemd --user did not respond within the command bound"
        state = result.stdout.strip()
        if result.returncode != 0 or state != "running":
            detail = result.stderr.strip() or state or "unknown user-manager state"
            return None, f"systemd --user is not running: {detail}"
        return (systemd_run, systemctl), None

    @staticmethod
    def _create_status_file() -> Path:
        descriptor, path = tempfile.mkstemp(prefix=".flow-gota-", suffix=".status")
        os.close(descriptor)
        return Path(path)

    @staticmethod
    def _read_wrapper_status(status_file: Path) -> tuple[str, str | None]:
        try:
            status = status_file.read_text(encoding="utf-8")
        except (OSError, UnicodeError):
            return "missing", None
        if status == "started\n":
            return "started", None
        if status.startswith("target-start-failed\n"):
            return "target-start-failed", status.removeprefix(
                "target-start-failed\n"
            ).rstrip("\n")
        return "invalid", status

    @staticmethod
    def _decode_output(value: str | bytes | None) -> str:
        if value is None:
            return ""
        if isinstance(value, bytes):
            return value.decode("utf-8", errors="replace")
        return value

    @classmethod
    def _bounded_timeout_communication(
        cls,
        process: subprocess.Popen[str],
        timeout_error: subprocess.TimeoutExpired,
    ) -> tuple[str, str]:
        partial_stdout = cls._decode_output(timeout_error.stdout)
        partial_stderr = cls._decode_output(timeout_error.stderr)
        try:
            return process.communicate(timeout=_POST_TIMEOUT_COMMUNICATE_SECONDS)
        except subprocess.TimeoutExpired as cleanup_error:
            stdout = cls._decode_output(cleanup_error.stdout) or partial_stdout
            stderr = cls._decode_output(cleanup_error.stderr) or partial_stderr
            for stream in (process.stdout, process.stderr):
                if stream is not None:
                    try:
                        stream.close()
                    except (OSError, ValueError):
                        pass
            cls._bounded_wait(process, _PROCESS_REAP_GRACE_SECONDS)
            return stdout, stderr

    @classmethod
    def _stream_communication(
        cls,
        process: subprocess.Popen[bytes],
        *,
        timeout: float,
        output_callback: OutputCallback,
        cancel_event: threading.Event | None,
        systemd_tools: tuple[str, str] | None,
        unit: str | None,
        redactor: SensitiveOutputRedactor | None = None,
    ) -> tuple[str, str, str | None, str | None]:
        """Capture binary pipes while optionally publishing decoded chunks.

        The default runner path remains ``communicate``. This path is used only
        by the TUI observer/cancellation boundary, so the existing capture and
        timeout semantics remain unchanged for Coordinator callers that do not
        ask for observation.
        """

        output: dict[str, list[str]] = {"stdout": [], "stderr": []}
        pending: dict[str, str] = {"stdout": "", "stderr": ""}
        threads: list[threading.Thread] = []

        def publish(source: str, text: str) -> None:
            if not text:
                return
            safe_text = redactor.redact(text) if redactor is not None else text
            try:
                output_callback(source, safe_text)
            except Exception:
                # Logging must never change the process boundary.
                pass

        def publish_complete_lines(source: str, text: str) -> None:
            pending[source] += text
            while "\n" in pending[source]:
                line, pending[source] = pending[source].split("\n", 1)
                publish(source, line + "\n")

        def pump(stream: Any, key: str, source: str) -> None:
            decoder = codecs.getincrementaldecoder("utf-8")(errors="replace")
            try:
                while True:
                    read = getattr(stream, "read1", stream.read)
                    chunk = read(4096)
                    if not chunk:
                        break
                    text = decoder.decode(chunk, final=False)
                    if text:
                        output[key].append(text)
                        publish_complete_lines(key, text)
                final_text = decoder.decode(b"", final=True)
                if final_text:
                    output[key].append(final_text)
                    publish_complete_lines(key, final_text)
            except (OSError, ValueError):
                return

        if process.stdout is not None:
            threads.append(
                threading.Thread(
                    target=pump,
                    args=(process.stdout, "stdout", "stdout"),
                    daemon=True,
                )
            )
        if process.stderr is not None:
            threads.append(
                threading.Thread(
                    target=pump,
                    args=(process.stderr, "stderr", "stderr"),
                    daemon=True,
                )
            )
        for thread in threads:
            thread.start()

        deadline = time.monotonic() + timeout
        terminal: str | None = None
        cleanup_error: str | None = None
        while process.poll() is None:
            if cancel_event is not None and cancel_event.is_set():
                terminal = "cancelled"
                if sys.platform == "linux":
                    if systemd_tools is not None and unit is not None:
                        cleanup_error = cls._stop_systemd_unit(
                            systemd_tools[1], unit, process
                        )
                else:
                    cls._terminate_process(process)
                break
            remaining = deadline - time.monotonic()
            if remaining <= 0:
                terminal = "timeout"
                if sys.platform == "linux":
                    if systemd_tools is not None and unit is not None:
                        cleanup_error = cls._stop_systemd_unit(
                            systemd_tools[1], unit, process
                        )
                else:
                    cls._terminate_process(process)
                break
            try:
                process.wait(timeout=min(0.05, remaining))
            except subprocess.TimeoutExpired:
                pass

        for thread in threads:
            thread.join(timeout=_POST_TIMEOUT_COMMUNICATE_SECONDS)
        for stream in (process.stdout, process.stderr):
            if stream is not None:
                try:
                    stream.close()
                except (OSError, ValueError):
                    pass
        for thread in threads:
            thread.join(timeout=_PROCESS_REAP_GRACE_SECONDS)
        for key, text in pending.items():
            publish(key, text)
        return (
            "".join(output["stdout"]),
            "".join(output["stderr"]),
            terminal,
            cleanup_error,
        )

    @classmethod
    def _unit_may_contain_processes(cls, systemctl: str, unit: str) -> bool:
        result = cls._run_systemctl(
            systemctl,
            ["show", unit, "--property=ActiveState", "--value"],
            _SYSTEMD_COMMAND_TIMEOUT_SECONDS,
        )
        if result is None:
            return True
        if result.returncode != 0:
            return False
        return result.stdout.strip() in {"active", "activating", "deactivating"}

    @classmethod
    def _wait_for_unit_collected(cls, systemctl: str, unit: str) -> bool:
        deadline = time.monotonic() + _SYSTEMD_COLLECTION_GRACE_SECONDS
        while True:
            remaining = deadline - time.monotonic()
            if remaining <= 0:
                return False
            result = cls._run_systemctl(
                systemctl,
                ["show", unit, "--property=LoadState", "--value", "--no-pager"],
                min(_SYSTEMD_COMMAND_TIMEOUT_SECONDS, remaining),
            )
            if result is not None:
                load_state = (result.stdout or "").strip().lower()
                stderr = (result.stderr or "").strip().lower()
                if load_state in {"not-found", "loadstate=not-found"}:
                    return True
                if "no such unit" in stderr or "could not be found" in stderr:
                    return True
            remaining = deadline - time.monotonic()
            if remaining <= 0:
                return False
            time.sleep(min(_SYSTEMD_COLLECTION_POLL_SECONDS, remaining))

    @classmethod
    def _stop_systemd_unit(
        cls,
        systemctl: str,
        unit: str,
        runner_process: subprocess.Popen[str],
    ) -> str | None:
        """Stop the unit externally, then kill its cgroup if it remains active."""

        errors: list[str] = []
        stop_result = cls._run_systemctl(
            systemctl,
            ["stop", "--no-block", unit],
            _SYSTEMD_COMMAND_TIMEOUT_SECONDS,
        )
        if stop_result is None:
            errors.append("systemctl stop timed out or failed to start")

        cls._bounded_wait(
            runner_process,
            _PROCESS_TERM_GRACE_SECONDS + _SYSTEMD_COMMAND_TIMEOUT_SECONDS,
        )

        if cls._unit_may_contain_processes(systemctl, unit):
            kill_result = cls._run_systemctl(
                systemctl,
                [
                    "kill",
                    "--kill-who=all",
                    "--signal=SIGKILL",
                    unit,
                ],
                _SYSTEMD_COMMAND_TIMEOUT_SECONDS,
            )
            if kill_result is None or kill_result.returncode != 0:
                detail = "" if kill_result is None else kill_result.stderr.strip()
                errors.append(f"systemctl cgroup kill failed{': ' + detail if detail else ''}")

        cls._bounded_wait(
            runner_process,
            _PROCESS_KILL_GRACE_SECONDS + _SYSTEMD_COMMAND_TIMEOUT_SECONDS,
        )
        if runner_process.poll() is None:
            try:
                runner_process.kill()
            except ProcessLookupError:
                pass
            cls._bounded_wait(runner_process, _PROCESS_REAP_GRACE_SECONDS)
            if runner_process.poll() is None:
                errors.append("systemd-run did not exit within the cleanup bound")

        if not cls._wait_for_unit_collected(systemctl, unit):
            errors.append(f"unit {unit} was not collected within the cleanup bound")
        return "; ".join(errors) if errors else None

    @staticmethod
    def _build_systemd_argv(
        argv: list[str],
        *,
        cwd: Path,
        environment: dict[str, str],
        status_file: Path,
        unit: str,
        systemd_run: str,
    ) -> list[str]:
        command = [
            systemd_run,
            "--user",
            "--quiet",
            "--pipe",
            "--wait",
            "--collect",
            "--expand-environment=no",
            f"--unit={unit}",
            "--service-type=exec",
            f"--working-directory={cwd}",
            "--property=KillMode=control-group",
            "--property=KillSignal=SIGTERM",
            "--property=TimeoutStopSec=0.25s",
            "--property=SendSIGKILL=yes",
        ]
        for name in sorted(environment):
            if name in {"GIT_PAGER", "PAGER"}:
                command.append(f"--setenv={name}=cat")
            else:
                command.append(f"--setenv={name}")
        command.extend(
            [
                sys.executable,
                str(_WRAPPER_SCRIPT),
                "--flow-opencode-wrapper",
                str(status_file),
                "--",
                *argv,
            ]
        )
        return command

    def run(
        self,
        *,
        agent: str,
        prompt: str,
        cwd: str | Path,
        timeout: float,
        output_callback: OutputCallback | None = None,
        cancel_event: threading.Event | None = None,
        expect_gota_payload: bool = True,
    ) -> OpenCodeRunResult:
        """Execute OpenCode once and classify its captured result."""

        if not isinstance(agent, str) or not agent.strip():
            raise ValueError("agent must be a non-empty string")
        if not isinstance(prompt, str):
            raise TypeError("prompt must be a string")
        if type(expect_gota_payload) is not bool:
            raise TypeError("expect_gota_payload must be a bool")
        timeout_seconds = self._validate_timeout(timeout)
        cwd_path = Path(cwd)
        argv = self._build_argv(agent, prompt)
        argv_tuple = tuple(argv)

        if cancel_event is not None and cancel_event.is_set():
            return OpenCodeRunResult(
                status=OpenCodeRunStatus.CANCELLED,
                argv=argv_tuple,
                cwd=str(cwd_path),
                stdout="",
                stderr="",
                exit_code=None,
                timed_out=False,
                error="run cancelled before process start",
            )

        if not cwd_path.exists() or not cwd_path.is_dir():
            return OpenCodeRunResult(
                status=OpenCodeRunStatus.START_FAILED,
                argv=argv_tuple,
                cwd=str(cwd_path),
                stdout="",
                stderr="",
                exit_code=None,
                timed_out=False,
                error=f"cwd is not an existing directory: {cwd_path}",
                start_failure=OpenCodeStartFailure.INVALID_CWD,
            )

        environment = os.environ.copy()
        config_dir = Path(__file__).resolve().parents[4] / ".opencode"
        environment["OPENCODE_CONFIG_DIR"] = str(config_dir)
        environment["GIT_PAGER"] = "cat"
        environment["PAGER"] = "cat"
        redactor = SensitiveOutputRedactor((cwd_path, config_dir))

        systemd_tools: tuple[str, str] | None = None
        if sys.platform == "linux":
            systemd_tools, systemd_error = self._check_systemd_user()
            if systemd_error is not None or systemd_tools is None:
                return OpenCodeRunResult(
                    status=OpenCodeRunStatus.START_FAILED,
                    argv=argv_tuple,
                    cwd=str(cwd_path),
                    stdout="",
                    stderr="",
                    exit_code=None,
                    timed_out=False,
                    error=f"Linux containment unavailable: {systemd_error}",
                    start_failure=OpenCodeStartFailure.CONTAINMENT_UNAVAILABLE,
                )

        status_file: Path | None = None
        unit: str | None = None
        startup_status = "started"
        startup_error: str | None = None
        process: subprocess.Popen[Any]
        streaming = output_callback is not None or cancel_event is not None
        process_started_monotonic_ns: int | None = None
        try:
            if sys.platform == "linux":
                assert systemd_tools is not None
                systemd_run, _systemctl = systemd_tools
                status_file = self._create_status_file()
                unit = f"{_SYSTEMD_UNIT_PREFIX}{uuid.uuid4().hex}.service"
                systemd_argv = self._build_systemd_argv(
                    argv,
                    cwd=cwd_path,
                    environment=environment,
                    status_file=status_file,
                    unit=unit,
                    systemd_run=systemd_run,
                )
                process_started_monotonic_ns = self._monotonic_ns()
                process = subprocess.Popen(
                    systemd_argv,
                    cwd=cwd_path,
                    env=environment,
                    shell=False,
                    stdin=subprocess.DEVNULL,
                    stdout=subprocess.PIPE,
                    stderr=subprocess.PIPE,
                    text=not streaming,
                    encoding="utf-8" if not streaming else None,
                    errors="replace" if not streaming else None,
                )
            else:
                process_started_monotonic_ns = self._monotonic_ns()
                process = subprocess.Popen(
                    argv,
                    cwd=cwd_path,
                    env=environment,
                    shell=False,
                    stdout=subprocess.PIPE,
                    stderr=subprocess.PIPE,
                    text=not streaming,
                    encoding="utf-8" if not streaming else None,
                    errors="replace" if not streaming else None,
                    start_new_session=os.name == "posix",
                )
        except (OSError, ValueError) as error:
            failure = (
                OpenCodeStartFailure.CONTAINMENT_UNAVAILABLE
                if sys.platform == "linux"
                else OpenCodeStartFailure.TARGET_EXECUTABLE
            )
            if status_file is not None:
                try:
                    status_file.unlink()
                except FileNotFoundError:
                    pass
                except OSError:
                    pass
            return OpenCodeRunResult(
                status=OpenCodeRunStatus.START_FAILED,
                argv=argv_tuple,
                cwd=str(cwd_path),
                stdout="",
                stderr="",
                exit_code=None,
                timed_out=False,
                error=str(error),
                start_failure=failure,
            )

        process_finished_monotonic_ns: int | None = None

        def with_process_duration(result: OpenCodeRunResult) -> OpenCodeRunResult:
            return self._with_process_duration(
                result,
                process_started_monotonic_ns,
                process_finished_monotonic_ns,
            )

        def with_process_duration_if_target_started(
            result: OpenCodeRunResult,
        ) -> OpenCodeRunResult:
            if sys.platform == "linux":
                assert status_file is not None
                target_status, _target_error = self._read_wrapper_status(status_file)
                if target_status != "started":
                    return result
            return with_process_duration(result)

        try:
            if streaming:
                callback = output_callback or (lambda _source, _text: None)
                stdout, stderr, terminal, cleanup_error = self._stream_communication(
                    process,
                    timeout=timeout_seconds,
                    output_callback=callback,
                    cancel_event=cancel_event,
                    systemd_tools=systemd_tools,
                    unit=unit,
                    redactor=redactor,
                )
                process_finished_monotonic_ns = self._monotonic_ns()
                if terminal in {"timeout", "cancelled"}:
                    message = (
                        "process exceeded timeout of "
                        f"{timeout_seconds:g} seconds"
                        if terminal == "timeout"
                        else "process cancelled by caller"
                    )
                    if cleanup_error is not None:
                        message = f"{message}; cleanup: {cleanup_error}"
                    return with_process_duration_if_target_started(
                        OpenCodeRunResult(
                            status=(
                                OpenCodeRunStatus.TIMEOUT
                                if terminal == "timeout"
                                else OpenCodeRunStatus.CANCELLED
                            ),
                            argv=argv_tuple,
                            cwd=str(cwd_path),
                            stdout=stdout,
                            stderr=stderr,
                            exit_code=process.returncode,
                            timed_out=terminal == "timeout",
                            error=message,
                        ),
                    )
            else:
                try:
                    stdout, stderr = process.communicate(timeout=timeout_seconds)
                    process_finished_monotonic_ns = self._monotonic_ns()
                except subprocess.TimeoutExpired as timeout_error:
                    cleanup_error = None
                    if sys.platform == "linux":
                        assert systemd_tools is not None
                        _systemd_run, systemctl = systemd_tools
                        assert unit is not None
                        cleanup_error = self._stop_systemd_unit(
                            systemctl,
                            unit,
                            process,
                        )
                    else:
                        self._terminate_process(process)
                    stdout, stderr = self._bounded_timeout_communication(
                        process, timeout_error
                    )
                    process_finished_monotonic_ns = self._monotonic_ns()
                    timeout_message = f"process exceeded timeout of {timeout_seconds:g} seconds"
                    if cleanup_error is not None:
                        timeout_message = f"{timeout_message}; cleanup: {cleanup_error}"
                    return with_process_duration_if_target_started(
                        OpenCodeRunResult(
                            status=OpenCodeRunStatus.TIMEOUT,
                            argv=argv_tuple,
                            cwd=str(cwd_path),
                            stdout=stdout,
                            stderr=stderr,
                            exit_code=process.returncode,
                            timed_out=True,
                            error=timeout_message,
                        ),
                    )

            if sys.platform == "linux":
                assert status_file is not None
                startup_status, startup_error = self._read_wrapper_status(status_file)

            if startup_status == "target-start-failed":
                return OpenCodeRunResult(
                    status=OpenCodeRunStatus.START_FAILED,
                    argv=argv_tuple,
                    cwd=str(cwd_path),
                    stdout=stdout,
                    stderr=stderr,
                    exit_code=None,
                    timed_out=False,
                    error=f"target executable could not start: {startup_error}",
                    start_failure=OpenCodeStartFailure.TARGET_EXECUTABLE,
                )

            if sys.platform == "linux" and startup_status != "started":
                return OpenCodeRunResult(
                    status=OpenCodeRunStatus.START_FAILED,
                    argv=argv_tuple,
                    cwd=str(cwd_path),
                    stdout=stdout,
                    stderr=stderr,
                    exit_code=None,
                    timed_out=False,
                    error=(
                        "Linux containment did not report target startup: "
                        f"{startup_status} {startup_error or ''}".strip()
                    ),
                    start_failure=OpenCodeStartFailure.CONTAINMENT_UNAVAILABLE,
                )

            if process.returncode != 0:
                return with_process_duration(
                    OpenCodeRunResult(
                        status=OpenCodeRunStatus.NON_ZERO_EXIT,
                        argv=argv_tuple,
                        cwd=str(cwd_path),
                        stdout=stdout,
                        stderr=stderr,
                        exit_code=process.returncode,
                        timed_out=False,
                        error=f"process exited with code {process.returncode}",
                    ),
                )

            if not expect_gota_payload:
                return with_process_duration(
                    OpenCodeRunResult(
                        status=OpenCodeRunStatus.SUCCEEDED,
                        argv=argv_tuple,
                        cwd=str(cwd_path),
                        stdout=stdout,
                        stderr=stderr,
                        exit_code=process.returncode,
                        timed_out=False,
                    ),
                )

            try:
                payload = parse_gota_output(stdout)
            except GotaProtocolError as error:
                return with_process_duration(
                    OpenCodeRunResult(
                        status=OpenCodeRunStatus.INVALID_PAYLOAD,
                        argv=argv_tuple,
                        cwd=str(cwd_path),
                        stdout=stdout,
                        stderr=stderr,
                        exit_code=process.returncode,
                        timed_out=False,
                        error=str(error),
                        protocol_error_code=error.code,
                    ),
                )

            return with_process_duration(
                OpenCodeRunResult(
                    status=OpenCodeRunStatus.SUCCEEDED,
                    argv=argv_tuple,
                    cwd=str(cwd_path),
                    stdout=stdout,
                    stderr=stderr,
                    exit_code=process.returncode,
                    timed_out=False,
                    payload=payload,
                ),
            )
        finally:
            if status_file is not None:
                try:
                    status_file.unlink()
                except FileNotFoundError:
                    pass
                except OSError:
                    pass


__all__ = [
    "DEFAULT_OPENCODE_AGENT",
    "DEFAULT_OPENCODE_MODEL",
    "DEFAULT_OPENCODE_VARIANT",
    "OpenCodeRunResult",
    "OpenCodeRunStatus",
    "OpenCodeStartFailure",
    "OpenCodeRunner",
]
