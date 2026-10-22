#!/usr/bin/env python3
"""Install a user-local launcher without touching system directories."""

from __future__ import annotations

import argparse
import os
import stat
import sys
import tempfile
from pathlib import Path


_PACKAGE_ROOT = Path(__file__).resolve().parent.parent
if str(_PACKAGE_ROOT) not in sys.path:
    sys.path.insert(0, str(_PACKAGE_ROOT))

from gota_tui.runtime import RuntimePathError, default_tui_python


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(prog="install-gota-launcher")
    parser.add_argument(
        "--destination",
        type=Path,
        default=Path.home() / ".local/bin/gota",
        help="User-local launcher path",
    )
    parser.add_argument("--force", action="store_true", help="Replace an existing launcher")
    return parser


def main(arguments: list[str] | None = None) -> int:
    options = build_parser().parse_args(arguments)
    destination = options.destination.expanduser()
    target = Path(__file__).resolve().with_name("gota.py")
    try:
        interpreter = default_tui_python()
    except RuntimePathError as error:
        print(f"Cannot resolve the dedicated Gota TUI venv: {error}", file=sys.stderr)
        return 2
    if not interpreter.is_file() or not os.access(interpreter, os.X_OK):
        print(
            "Dedicated Gota TUI Python is missing or not executable: "
            f"{interpreter}\n"
            "Create the venv and install tools/gota_tui/requirements.txt before "
            "installing the launcher.",
            file=sys.stderr,
        )
        return 2
    if destination.exists() or destination.is_symlink():
        if not options.force:
            print(f"Refusing to replace existing launcher: {destination}", file=sys.stderr)
            return 2
        destination.unlink()
    destination.parent.mkdir(parents=True, exist_ok=True)
    content = (
        f"#!{interpreter}\n"
        "import runpy\n"
        f"runpy.run_path({str(target)!r}, run_name='__main__')\n"
    )
    descriptor, temporary_name = tempfile.mkstemp(
        prefix=f".{destination.name}.", suffix=".tmp", dir=destination.parent
    )
    temporary = Path(temporary_name)
    try:
        with os.fdopen(descriptor, "w", encoding="utf-8") as file:
            file.write(content)
            file.flush()
            os.fsync(file.fileno())
        temporary.chmod(
            stat.S_IRUSR
            | stat.S_IWUSR
            | stat.S_IXUSR
            | stat.S_IRGRP
            | stat.S_IXGRP
            | stat.S_IROTH
            | stat.S_IXOTH
        )
        os.replace(temporary, destination)
    except BaseException:
        try:
            temporary.unlink()
        except FileNotFoundError:
            pass
        raise
    in_path = str(destination.parent) in os.environ.get("PATH", "").split(os.pathsep)
    print(f"Installed {destination} -> {target} using {interpreter}")
    if not in_path:
        print(f"Notice: {destination.parent} is not in PATH", file=sys.stderr)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
