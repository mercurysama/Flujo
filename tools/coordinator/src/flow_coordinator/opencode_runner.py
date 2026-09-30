"""Small, state-free subprocess boundary for OpenCode."""

from __future__ import annotations

import math
import os
import signal
import subprocess
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
    """Run one non-interactive OpenCode command without coordinating state."""

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
    def _terminate_process(process: subprocess.Popen[str]) -> None:
        """Stop the process and its local process group within a short bound."""

        if process.poll() is not None:
            return

        if os.name == "posix":
            try:
                os.killpg(process.pid, signal.SIGTERM)
            except ProcessLookupError:
                pass
            except OSError:
                process.terminate()
        else:
            process.terminate()

        try:
            process.wait(timeout=0.25)
            return
        except subprocess.TimeoutExpired:
            pass

        if os.name == "posix":
            try:
                os.killpg(process.pid, signal.SIGKILL)
            except ProcessLookupError:
                pass
            except OSError:
                process.kill()
        else:
            process.kill()
        process.wait()

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

        try:
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
        except subprocess.TimeoutExpired:
            self._terminate_process(process)
            stdout, stderr = process.communicate()
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
