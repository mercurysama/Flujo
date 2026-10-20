"""Small, state-free subprocess boundary for OpenCode."""

from __future__ import annotations

import math
import os
import shutil
import signal
import subprocess
import sys
import tempfile
import time
import uuid
from dataclasses import dataclass
from enum import StrEnum
from pathlib import Path
from typing import Final

from .gota_protocol import (
    GotaProtocolError,
    GotaProtocolErrorCode,
    GotaReviewResult,
    GotaWorkerResult,
    parse_gota_output,
)


DEFAULT_OPENCODE_MODEL: Final[str] = "openai/gpt-5.6-luna"
DEFAULT_OPENCODE_VARIANT: Final[str] = "max"
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
    START_FAILED = "start_failed"


class OpenCodeStartFailure(StrEnum):
    """The failed boundary when a run cannot reach a target result."""

    INVALID_CWD = "invalid_cwd"
    CONTAINMENT_UNAVAILABLE = "containment_unavailable"
    TARGET_EXECUTABLE = "target_executable"


GotaResult = GotaWorkerResult | GotaReviewResult


@dataclass(frozen=True, slots=True)
class OpenCodeRunResult:
    """Captured process data and, when valid, one parsed Gota result."""

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


class OpenCodeRunner:
    """Run one command behind an externally managed Linux cgroup."""

    def __init__(
        self,
        *,
        executable: str | Path = "opencode",
        model: str = DEFAULT_OPENCODE_MODEL,
        variant: str | None = DEFAULT_OPENCODE_VARIANT,
    ) -> None:
        self.executable = self._required_text(executable, "executable")
        self.model = self._required_text(model, "model")
        self.variant = None if variant is None else self._required_text(variant, "variant")

    @staticmethod
    def _required_text(value: str | Path, field: str) -> str:
        text = str(value)
        if not text.strip():
            raise ValueError(f"{field} must be a non-empty string")
        return text

    def _build_argv(self, agent: str, prompt: str) -> list[str]:
        return [
            self.executable,
            "run",
            "--model",
            self.model if self.variant is None else f"{self.model}#{self.variant}",
            "--agent",
            agent,
            "--auto",
            prompt,
        ]

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
    ) -> OpenCodeRunResult:
        """Execute OpenCode once and classify its captured result."""

        if not isinstance(agent, str) or not agent.strip():
            raise ValueError("agent must be a non-empty string")
        if not isinstance(prompt, str):
            raise TypeError("prompt must be a string")
        timeout_seconds = self._validate_timeout(timeout)
        cwd_path = Path(cwd)
        argv = self._build_argv(agent, prompt)
        argv_tuple = tuple(argv)

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
        environment["GIT_PAGER"] = "cat"
        environment["PAGER"] = "cat"

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
        process: subprocess.Popen[str]
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
                process = subprocess.Popen(
                    systemd_argv,
                    cwd=cwd_path,
                    env=environment,
                    shell=False,
                    stdin=subprocess.DEVNULL,
                    stdout=subprocess.PIPE,
                    stderr=subprocess.PIPE,
                    text=True,
                    encoding="utf-8",
                    errors="replace",
                )
            else:
                process = subprocess.Popen(
                    argv,
                    cwd=cwd_path,
                    env=environment,
                    shell=False,
                    stdout=subprocess.PIPE,
                    stderr=subprocess.PIPE,
                    text=True,
                    encoding="utf-8",
                    errors="replace",
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

        try:
            try:
                stdout, stderr = process.communicate(timeout=timeout_seconds)
            except subprocess.TimeoutExpired as timeout_error:
                cleanup_error: str | None = None
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
                timeout_message = f"process exceeded timeout of {timeout_seconds:g} seconds"
                if cleanup_error is not None:
                    timeout_message = f"{timeout_message}; cleanup: {cleanup_error}"
                return OpenCodeRunResult(
                    status=OpenCodeRunStatus.TIMEOUT,
                    argv=argv_tuple,
                    cwd=str(cwd_path),
                    stdout=stdout,
                    stderr=stderr,
                    exit_code=process.returncode,
                    timed_out=True,
                    error=timeout_message,
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
                return OpenCodeRunResult(
                    status=OpenCodeRunStatus.NON_ZERO_EXIT,
                    argv=argv_tuple,
                    cwd=str(cwd_path),
                    stdout=stdout,
                    stderr=stderr,
                    exit_code=process.returncode,
                    timed_out=False,
                    error=f"process exited with code {process.returncode}",
                )

            try:
                payload = parse_gota_output(stdout)
            except GotaProtocolError as error:
                return OpenCodeRunResult(
                    status=OpenCodeRunStatus.INVALID_PAYLOAD,
                    argv=argv_tuple,
                    cwd=str(cwd_path),
                    stdout=stdout,
                    stderr=stderr,
                    exit_code=process.returncode,
                    timed_out=False,
                    error=str(error),
                    protocol_error_code=error.code,
                )

            return OpenCodeRunResult(
                status=OpenCodeRunStatus.SUCCEEDED,
                argv=argv_tuple,
                cwd=str(cwd_path),
                stdout=stdout,
                stderr=stderr,
                exit_code=process.returncode,
                timed_out=False,
                payload=payload,
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
    "DEFAULT_OPENCODE_MODEL",
    "DEFAULT_OPENCODE_VARIANT",
    "OpenCodeRunResult",
    "OpenCodeRunStatus",
    "OpenCodeStartFailure",
    "OpenCodeRunner",
]
