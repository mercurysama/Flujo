"""Minimal target wrapper for a systemd-managed OpenCode cgroup."""

from __future__ import annotations

import os
import signal
import subprocess
import sys
from pathlib import Path


_ARGUMENT_MARKER = "--flow-opencode-wrapper"
_STARTED_STATUS = "started\n"
_TARGET_START_FAILURE_STATUS = "target-start-failed\n"


def _write_status(path: Path, value: str) -> None:
    try:
        path.write_text(value, encoding="utf-8")
    except OSError as error:
        sys.stderr.write(f"wrapper status error: {type(error).__name__}: {error}\n")


def _propagate_return_code(return_code: int) -> int:
    if return_code >= 0:
        return return_code
    signum = -return_code
    signal.signal(signum, signal.SIG_DFL)
    os.kill(os.getpid(), signum)
    return 128 + signum


def main(arguments: list[str]) -> int:
    if len(arguments) < 4 or arguments[0] != _ARGUMENT_MARKER:
        sys.stderr.write("invalid OpenCode wrapper arguments\n")
        return 125
    status_path = Path(arguments[1])
    if arguments[2] != "--" or len(arguments) == 3:
        sys.stderr.write("invalid OpenCode wrapper target arguments\n")
        return 125
    target_argv = arguments[3:]
    try:
        target = subprocess.Popen(target_argv, shell=False)
    except (OSError, ValueError) as error:
        message = f"{type(error).__name__}: {error}"
        _write_status(status_path, _TARGET_START_FAILURE_STATUS + message + "\n")
        sys.stderr.write(message + "\n")
        return 127

    _write_status(status_path, _STARTED_STATUS)
    return _propagate_return_code(target.wait())


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
