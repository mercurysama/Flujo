#!/usr/bin/env python3
"""User-facing launcher target; installation may symlink ``~/.local/bin/gota`` here."""

from __future__ import annotations

import sys
from pathlib import Path

sys.dont_write_bytecode = True
_package_directory = Path(__file__).resolve().parent
_repository = _package_directory.parent.parent
sys.path.insert(0, str(_package_directory.parent))
sys.path.insert(0, str(_repository / "tools/coordinator/src"))

from gota_tui.cli import main


if __name__ == "__main__":
    raise SystemExit(main())
