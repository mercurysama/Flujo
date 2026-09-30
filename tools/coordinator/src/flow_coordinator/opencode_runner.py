"""Small, state-free subprocess boundary for OpenCode."""

from __future__ import annotations

import math
import os
import signal
import subprocess
import sys
import time
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


class OpenCodeRunStatus(StrEnum):
    """The mutually exclusive outcome of one OpenCode process attempt."""

    SUCCEEDED = "succeeded"
    INVALID_PAYLOAD = "invalid_payload"
    NON_ZERO_EXIT = "non_zero_exit"
    TIMEOUT = "timeout"
    START_FAILED = "start_failed"


GotaResult = GotaWorkerResult | GotaReviewResult


@dataclass(frozen=True, slots=True)
class _ProcessIdentity:
    """A Linux PID plus its creation marker, safe against PID reuse."""

    pid: int
    start_time: int


@dataclass(frozen=True, slots=True)
class _LinuxProcess:
    identity: _ProcessIdentity
    parent_pid: int
    state: str


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
    def _read_linux_process(pid: int) -> _LinuxProcess | None:
        """Read the small part of ``/proc/<pid>/stat`` needed for cleanup."""

        try:
            stat_text = Path(f"/proc/{pid}/stat").read_text(encoding="ascii")
        except (OSError, UnicodeError):
            return None

        closing_parenthesis = stat_text.rfind(")")
        if closing_parenthesis < 0:
            return None
        fields = stat_text[closing_parenthesis + 2 :].split()
        if len(fields) <= 19:
            return None
        try:
            parent_pid = int(fields[1])
            start_time = int(fields[19])
        except ValueError:
            return None
        return _LinuxProcess(
            identity=_ProcessIdentity(pid=pid, start_time=start_time),
            parent_pid=parent_pid,
            state=fields[0],
        )

    @classmethod
    def _collect_linux_process_tree(cls, root_pid: int) -> tuple[_ProcessIdentity, ...]:
        """Collect only descendants reachable through Linux parent-child links."""

        root = cls._read_linux_process(root_pid)
        if root is None:
            return ()

        identities: dict[int, _ProcessIdentity] = {root.identity.pid: root.identity}
        pending: list[_LinuxProcess] = [root]
        while pending:
            parent = pending.pop()
            try:
                children_text = Path(
                    f"/proc/{parent.identity.pid}/task/{parent.identity.pid}/children"
                ).read_text(encoding="ascii")
            except (OSError, UnicodeError):
                continue
            for child_text in children_text.split():
                try:
                    child_pid = int(child_text)
                except ValueError:
                    continue
                child = cls._read_linux_process(child_pid)
                if child is None or child.identity.pid in identities:
                    continue
                if child.identity.pid != child_pid:
                    continue
                if child.identity.pid == parent.identity.pid:
                    continue
                if child.parent_pid != parent.identity.pid:
                    continue
                if child.state in {"Z", "X"}:
                    identities[child.identity.pid] = child.identity
                    continue
                identities[child.identity.pid] = child.identity
                pending.append(child)
        return tuple(identities.values())

    @classmethod
    def _merge_processes(
        cls, *process_groups: tuple[_ProcessIdentity, ...]
    ) -> tuple[_ProcessIdentity, ...]:
        merged: dict[int, _ProcessIdentity] = {}
        for process_group in process_groups:
            for identity in process_group:
                merged.setdefault(identity.pid, identity)
        return tuple(merged.values())

    @classmethod
    def _process_is_active(cls, identity: _ProcessIdentity) -> bool:
        current = cls._read_linux_process(identity.pid)
        return (
            current is not None
            and current.identity.start_time == identity.start_time
            and current.state not in {"Z", "X"}
        )

    @classmethod
    def _signal_linux_processes(
        cls, processes: tuple[_ProcessIdentity, ...], signum: signal.Signals
    ) -> None:
        """Signal verified descendants, never an arbitrary PID or process group."""

        for identity in processes:
            current = cls._read_linux_process(identity.pid)
            if (
                current is None
                or current.identity.start_time != identity.start_time
                or current.state in {"Z", "X"}
            ):
                continue
            try:
                os.kill(identity.pid, signum)
            except (ProcessLookupError, PermissionError):
                continue

    @staticmethod
    def _bounded_wait(process: subprocess.Popen[str], timeout: float) -> None:
        try:
            process.wait(timeout=timeout)
        except subprocess.TimeoutExpired:
            pass

    @classmethod
    def _terminate_process(
        cls,
        process: subprocess.Popen[str],
        known_processes: tuple[_ProcessIdentity, ...] = (),
    ) -> None:
        """Stop the execution tree and reap the runner process within fixed bounds."""

        if sys.platform == "linux":
            processes = cls._merge_processes(
                known_processes, cls._collect_linux_process_tree(process.pid)
            )
            if not any(identity.pid == process.pid for identity in processes):
                if process.poll() is None:
                    try:
                        process.terminate()
                    except ProcessLookupError:
                        pass

            cls._signal_linux_processes(processes, signal.SIGTERM)
            term_deadline = time.monotonic() + _PROCESS_TERM_GRACE_SECONDS
            while time.monotonic() < term_deadline:
                processes = cls._merge_processes(
                    processes, cls._collect_linux_process_tree(process.pid)
                )
                cls._signal_linux_processes(processes, signal.SIGTERM)
                if process.poll() is not None and not any(
                    cls._process_is_active(identity) for identity in processes
                ):
                    break
                time.sleep(min(0.01, max(0.0, term_deadline - time.monotonic())))

            processes = cls._merge_processes(
                processes, cls._collect_linux_process_tree(process.pid)
            )
            if process.poll() is None:
                try:
                    process.kill()
                except ProcessLookupError:
                    pass
            cls._signal_linux_processes(processes, signal.SIGKILL)
            kill_deadline = time.monotonic() + _PROCESS_KILL_GRACE_SECONDS
            while time.monotonic() < kill_deadline:
                processes = cls._merge_processes(
                    processes, cls._collect_linux_process_tree(process.pid)
                )
                cls._signal_linux_processes(processes, signal.SIGKILL)
                if process.poll() is not None and not any(
                    cls._process_is_active(identity) for identity in processes
                ):
                    break
                time.sleep(min(0.01, max(0.0, kill_deadline - time.monotonic())))
            if process.poll() is None:
                try:
                    process.kill()
                except ProcessLookupError:
                    pass
            cls._bounded_wait(process, _PROCESS_REAP_GRACE_SECONDS)
            return

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

        known_processes = (
            self._collect_linux_process_tree(process.pid)
            if sys.platform == "linux"
            else ()
        )
        try:
            stdout, stderr = process.communicate(timeout=timeout_seconds)
        except subprocess.TimeoutExpired as timeout_error:
            self._terminate_process(process, known_processes)
            stdout, stderr = self._bounded_timeout_communication(process, timeout_error)
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
