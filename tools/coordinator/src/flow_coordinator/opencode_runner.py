"""Small, state-free subprocess boundary for OpenCode."""

from __future__ import annotations

import math
import os
import signal
import subprocess
import sys
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
_SUPERVISOR_SCRIPT: Final[Path] = Path(__file__).with_name("opencode_supervisor.py")


class OpenCodeRunStatus(StrEnum):
    """The mutually exclusive outcome of one OpenCode process attempt."""

    SUCCEEDED = "succeeded"
    INVALID_PAYLOAD = "invalid_payload"
    NON_ZERO_EXIT = "non_zero_exit"
    TIMEOUT = "timeout"
    START_FAILED = "start_failed"


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


class OpenCodeRunner:
    """Run one command; Linux uses a per-run supervisor, other OSes use fallback cleanup."""

    def __init__(
        self,
        *,
        executable: str | Path = "opencode",
        model: str = DEFAULT_OPENCODE_MODEL,
        variant: str = DEFAULT_OPENCODE_VARIANT,
    ) -> None:
        self.executable = self._required_text(executable, "executable")
        self.model = self._required_text(model, "model")
        self.variant = self._required_text(variant, "variant")

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
            self.model,
            "--variant",
            self.variant,
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
        """Stop the supervisor first, then apply a bounded fallback."""

        if process.poll() is not None:
            return
        if sys.platform == "linux":
            try:
                process.terminate()
            except ProcessLookupError:
                pass
            cls._bounded_wait(
                process,
                _PROCESS_TERM_GRACE_SECONDS
                + _PROCESS_KILL_GRACE_SECONDS
                + _PROCESS_REAP_GRACE_SECONDS,
            )
            if process.poll() is None:
                try:
                    process.kill()
                except ProcessLookupError:
                    pass
            cls._bounded_wait(process, _PROCESS_REAP_GRACE_SECONDS)
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
    def _start_linux_supervisor(
        argv: list[str],
        *,
        cwd: Path,
        environment: dict[str, str],
    ) -> tuple[subprocess.Popen[str], int]:
        status_read_fd, status_write_fd = os.pipe()
        supervisor_argv = [
            sys.executable,
            str(_SUPERVISOR_SCRIPT),
            "--flow-opencode-supervisor",
            str(status_write_fd),
            "--",
            *argv,
        ]
        try:
            process = subprocess.Popen(
                supervisor_argv,
                cwd=cwd,
                env=environment,
                shell=False,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True,
                encoding="utf-8",
                errors="replace",
                start_new_session=True,
                pass_fds=(status_write_fd,),
            )
        except BaseException:
            os.close(status_read_fd)
            os.close(status_write_fd)
            raise
        os.close(status_write_fd)
        return process, status_read_fd

    @staticmethod
    def _read_startup_error(status_fd: int | None) -> str | None:
        if status_fd is None:
            return None
        try:
            os.set_blocking(status_fd, False)
            chunks: list[bytes] = []
            while True:
                try:
                    chunk = os.read(status_fd, 4096)
                except BlockingIOError:
                    break
                if not chunk:
                    break
                chunks.append(chunk)
        except OSError:
            return None
        finally:
            try:
                os.close(status_fd)
            except OSError:
                pass
        status = b"".join(chunks)
        if not status:
            return None
        if status.startswith((b"E:", b"S:")):
            status = status[2:]
        return status.decode("utf-8", errors="replace")

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
            )

        environment = os.environ.copy()
        environment["GIT_PAGER"] = "cat"
        environment["PAGER"] = "cat"

        startup_status_fd: int | None = None
        try:
            if sys.platform == "linux":
                process, startup_status_fd = self._start_linux_supervisor(
                    argv,
                    cwd=cwd_path,
                    environment=environment,
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
            return OpenCodeRunResult(
                status=OpenCodeRunStatus.START_FAILED,
                argv=argv_tuple,
                cwd=str(cwd_path),
                stdout="",
                stderr="",
                exit_code=None,
                timed_out=False,
                error=str(error),
            )

        try:
            stdout, stderr = process.communicate(timeout=timeout_seconds)
        except subprocess.TimeoutExpired as timeout_error:
            self._terminate_process(process)
            stdout, stderr = self._bounded_timeout_communication(process, timeout_error)
            self._read_startup_error(startup_status_fd)
            return OpenCodeRunResult(
                status=OpenCodeRunStatus.TIMEOUT,
                argv=argv_tuple,
                cwd=str(cwd_path),
                stdout=stdout,
                stderr=stderr,
                exit_code=process.returncode,
                timed_out=True,
                error=f"process exceeded timeout of {timeout_seconds:g} seconds",
            )

        startup_error = self._read_startup_error(startup_status_fd)
        if startup_error is not None:
            return OpenCodeRunResult(
                status=OpenCodeRunStatus.START_FAILED,
                argv=argv_tuple,
                cwd=str(cwd_path),
                stdout=stdout,
                stderr=stderr,
                exit_code=None,
                timed_out=False,
                error=startup_error,
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


__all__ = [
    "DEFAULT_OPENCODE_MODEL",
    "DEFAULT_OPENCODE_VARIANT",
    "OpenCodeRunResult",
    "OpenCodeRunStatus",
    "OpenCodeRunner",
]
