"""Resolve and validate the pinned production Godot; never search PATH."""

from collections.abc import Mapping, Sequence
import os
from pathlib import Path
import subprocess
import sys

REQUIRED_VERSION = "4.7.2.stable.official.ed1daf0bf"
PINNED_RELATIVE_PATH = Path("flujo/toolchains/godot/4.7.2-stable/godot")
VERSION_TIMEOUT_SECONDS = 10


class GodotResolutionError(RuntimeError):
    """The selected executable cannot serve as production authority."""


def resolve_production_godot(env: Mapping[str, str] | None = None) -> Path:
    environment = os.environ if env is None else env
    if "FLUJO_GODOT_BIN" in environment:
        override = environment["FLUJO_GODOT_BIN"]
        if not override.strip():
            raise GodotResolutionError("FLUJO_GODOT_BIN is empty; no fallback allowed")
        candidate = Path(override).absolute()
    else:
        data_home = environment.get("XDG_DATA_HOME")
        if data_home:
            base = Path(data_home)
        else:
            home = environment.get("HOME")
            if not home:
                raise GodotResolutionError("HOME is required when XDG_DATA_HOME is unset")
            base = Path(home) / ".local/share"
        if not base.is_absolute():
            raise GodotResolutionError("XDG_DATA_HOME/HOME must be an absolute path")
        candidate = base / PINNED_RELATIVE_PATH

    if not candidate.is_file():
        raise GodotResolutionError(f"{candidate}: not a file; no fallback allowed")
    if not os.access(candidate, os.X_OK):
        raise GodotResolutionError(f"{candidate}: not executable; no fallback allowed")
    try:
        probe = subprocess.run(
            [str(candidate), "--version"], env=dict(environment),
            capture_output=True, text=True, timeout=VERSION_TIMEOUT_SECONDS,
            check=False,
        )
    except (OSError, subprocess.TimeoutExpired, UnicodeError) as error:
        raise GodotResolutionError(f"{candidate}: version probe failed: {error}") from error
    if probe.returncode != 0:
        raise GodotResolutionError(
            f"{candidate}: version probe exit {probe.returncode}: {probe.stderr.strip()}"
        )
    version = probe.stdout.strip()
    if version != REQUIRED_VERSION:
        raise GodotResolutionError(
            f"{candidate}: expected {REQUIRED_VERSION}, received {version!r}; no fallback allowed"
        )
    return candidate


def main(args: Sequence[str] | None = None) -> int:
    arguments = list(sys.argv[1:] if args is None else args)
    if arguments and arguments[0] != "--":
        print("Usage: resolve_godot.py [-- GODOT_ARGUMENTS...]", file=sys.stderr)
        return 2
    try:
        executable = resolve_production_godot()
        if not arguments:
            print(executable)
            return 0
        result = subprocess.run([str(executable), *arguments[1:]], check=False)
        return result.returncode if result.returncode >= 0 else 128 - result.returncode
    except (GodotResolutionError, OSError) as error:
        print(f"Production Godot resolution/launch failed: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
