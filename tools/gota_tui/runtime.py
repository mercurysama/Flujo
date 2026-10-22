"""Runtime paths shared by the Gota installer and self-check."""

from __future__ import annotations

import os
from collections.abc import Mapping
from pathlib import Path


class RuntimePathError(ValueError):
    """Raised when an XDG runtime path cannot be resolved safely."""


def xdg_data_home(environment: Mapping[str, str] | None = None) -> Path:
    """Return the absolute XDG data directory used by the TUI runtime."""

    values = environment if environment is not None else os.environ
    configured = values.get("XDG_DATA_HOME", "").strip()
    if configured:
        root = Path(configured).expanduser()
    else:
        home_value = values.get("HOME", "").strip()
        home = Path(home_value).expanduser() if home_value else Path.home()
        root = home / ".local" / "share"
    if not root.is_absolute():
        raise RuntimePathError(
            f"XDG_DATA_HOME/HOME must resolve to an absolute path: {root}"
        )
    return root


def default_tui_venv(environment: Mapping[str, str] | None = None) -> Path:
    """Return the user-owned dedicated Gota TUI virtual environment."""

    return xdg_data_home(environment) / "flow-coordinator" / "gota-tui-venv"


def default_tui_python(environment: Mapping[str, str] | None = None) -> Path:
    """Return the dedicated venv interpreter used by the production launcher."""

    return default_tui_venv(environment) / "bin" / "python"
