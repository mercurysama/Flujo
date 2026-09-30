"""Linux-only supervisor for one OpenCode execution."""

from __future__ import annotations

import ctypes
import os
import signal
import sys
import time
from dataclasses import dataclass
from pathlib import Path
from typing import Final


_PR_SET_CHILD_SUBREAPER: Final[int] = 36
_TERM_GRACE_SECONDS: Final[float] = 0.25
_KILL_GRACE_SECONDS: Final[float] = 0.25
_POLL_SECONDS: Final[float] = 0.01
_STATUS_ERROR_PREFIX: Final[bytes] = b"S:"
_TARGET_ERROR_PREFIX: Final[bytes] = b"E:"


@dataclass(frozen=True, slots=True)
class _ProcessIdentity:
    pid: int
    start_time: int


@dataclass(frozen=True, slots=True)
class _LinuxProcess:
    identity: _ProcessIdentity
    parent_pid: int
    state: str


def _write_all(fd: int, value: bytes) -> None:
    offset = 0
    while offset < len(value):
        try:
            offset += os.write(fd, value[offset:])
        except OSError:
            return


def _report_failure(status_fd: int, prefix: bytes, error: BaseException) -> None:
    message = f"{type(error).__name__}: {error}".encode("utf-8", errors="replace")
    _write_all(status_fd, prefix + message)
    _write_all(2, message + b"\n")


def _set_child_subreaper() -> None:
    libc = ctypes.CDLL(None, use_errno=True)
    prctl = libc.prctl
    prctl.argtypes = [
        ctypes.c_int,
        ctypes.c_ulong,
        ctypes.c_ulong,
        ctypes.c_ulong,
        ctypes.c_ulong,
    ]
    prctl.restype = ctypes.c_int
    if prctl(_PR_SET_CHILD_SUBREAPER, 1, 0, 0, 0) != 0:
        error_number = ctypes.get_errno()
        raise OSError(error_number, os.strerror(error_number))


def _set_close_on_exec(fd: int) -> None:
    os.set_inheritable(fd, False)


def _read_linux_process(pid: int) -> _LinuxProcess | None:
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


def _collect_descendants(root_pid: int) -> tuple[_ProcessIdentity, ...]:
    identities: dict[int, _ProcessIdentity] = {}
    pending: list[int] = [root_pid]
    while pending:
        parent_pid = pending.pop()
        try:
            children_text = Path(
                f"/proc/{parent_pid}/task/{parent_pid}/children"
            ).read_text(encoding="ascii")
        except (OSError, UnicodeError):
            continue
        for child_text in children_text.split():
            try:
                child_pid = int(child_text)
            except ValueError:
                continue
            child = _read_linux_process(child_pid)
            if child is None or child.identity.pid in identities:
                continue
            if child.identity.pid != child_pid or child.parent_pid != parent_pid:
                continue
            identities[child.identity.pid] = child.identity
            if child.state not in {"Z", "X"}:
                pending.append(child.identity.pid)
    return tuple(identities.values())


def _merge_processes(
    *process_groups: tuple[_ProcessIdentity, ...],
) -> tuple[_ProcessIdentity, ...]:
    merged: dict[int, _ProcessIdentity] = {}
    for process_group in process_groups:
        for identity in process_group:
            merged.setdefault(identity.pid, identity)
    return tuple(merged.values())


def _process_is_active(identity: _ProcessIdentity) -> bool:
    current = _read_linux_process(identity.pid)
    return (
        current is not None
        and current.identity.start_time == identity.start_time
        and current.state not in {"Z", "X"}
    )


def _signal_processes(
    processes: tuple[_ProcessIdentity, ...], signum: signal.Signals
) -> None:
    for identity in processes:
        current = _read_linux_process(identity.pid)
        if (
            current is None
            or current.identity.start_time != identity.start_time
            or current.state in {"Z", "X"}
        ):
            continue
        try:
            os.kill(identity.pid, signum)
        except (PermissionError, ProcessLookupError):
            continue


def _reap_available(root_pid: int, root_status: list[int | None]) -> bool:
    while True:
        try:
            pid, status = os.waitpid(-1, os.WNOHANG)
        except ChildProcessError:
            return False
        except InterruptedError:
            continue
        if pid == 0:
            return True
        if pid == root_pid:
            root_status[0] = status


def _has_active_processes(processes: tuple[_ProcessIdentity, ...]) -> bool:
    return any(_process_is_active(identity) for identity in processes)


def _terminate_descendants(root_pid: int, root_status: list[int | None]) -> None:
    processes = _collect_descendants(root_pid)
    _signal_processes(processes, signal.SIGTERM)
    term_deadline = time.monotonic() + _TERM_GRACE_SECONDS
    while time.monotonic() < term_deadline:
        has_children = _reap_available(root_pid, root_status)
        processes = _merge_processes(processes, _collect_descendants(root_pid))
        _signal_processes(processes, signal.SIGTERM)
        if not has_children and not _has_active_processes(processes):
            return
        time.sleep(min(_POLL_SECONDS, max(0.0, term_deadline - time.monotonic())))

    processes = _merge_processes(processes, _collect_descendants(root_pid))
    _signal_processes(processes, signal.SIGKILL)
    kill_deadline = time.monotonic() + _KILL_GRACE_SECONDS
    while time.monotonic() < kill_deadline:
        has_children = _reap_available(root_pid, root_status)
        processes = _merge_processes(processes, _collect_descendants(root_pid))
        _signal_processes(processes, signal.SIGKILL)
        if not has_children and not _has_active_processes(processes):
            return
        time.sleep(_POLL_SECONDS)

    _reap_available(root_pid, root_status)


def _exit_like_target(status: int) -> None:
    exit_code = os.waitstatus_to_exitcode(status)
    if exit_code >= 0:
        os._exit(exit_code)
    signum = -exit_code
    if signum not in {signal.SIGKILL, signal.SIGSTOP}:
        signal.signal(signum, signal.SIG_DFL)
    os.kill(os.getpid(), signum)
    os._exit(128 + signum)


def _supervise(status_fd: int, target_argv: list[str]) -> None:
    shutdown_requested = False

    def request_shutdown(_signum: int, _frame: object) -> None:
        nonlocal shutdown_requested
        shutdown_requested = True

    signal.signal(signal.SIGTERM, request_shutdown)
    signal.signal(signal.SIGINT, request_shutdown)
    _set_close_on_exec(status_fd)
    _set_child_subreaper()
    if shutdown_requested:
        os.close(status_fd)
        os._exit(143)
    target_pid = os.fork()
    if target_pid == 0:
        try:
            os.setsid()
            os.execvpe(target_argv[0], target_argv, os.environ)
        except (OSError, ValueError) as error:
            _report_failure(status_fd, _TARGET_ERROR_PREFIX, error)
            os._exit(127)

    os.close(status_fd)
    root_status: list[int | None] = [None]
    while True:
        if shutdown_requested:
            _terminate_descendants(os.getpid(), root_status)
            os._exit(143)
        has_children = _reap_available(target_pid, root_status)
        if root_status[0] is not None and not has_children:
            _exit_like_target(root_status[0])
        time.sleep(_POLL_SECONDS)


def main(arguments: list[str]) -> int:
    if sys.platform != "linux":
        return 125
    if len(arguments) < 4 or arguments[0] != "--flow-opencode-supervisor":
        return 125
    try:
        status_fd = int(arguments[1])
    except ValueError:
        return 125
    if arguments[2] != "--" or len(arguments) == 3:
        return 125
    try:
        _supervise(status_fd, arguments[3:])
    except BaseException as error:
        _report_failure(status_fd, _STATUS_ERROR_PREFIX, error)
        try:
            os.close(status_fd)
        except OSError:
            pass
        return 125
    return 125


if __name__ == "__main__":
    os._exit(main(sys.argv[1:]))
