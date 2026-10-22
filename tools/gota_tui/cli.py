"""Command-line entry point for ``gota``, ``gota clipboard`` and history."""

from __future__ import annotations

import argparse
import os
import sys
from pathlib import Path

from . import __version__
from .actions import ActionRegistry, ActionRegistryError
from .clipboard import ClipboardReader, ClipboardWriter
from .durable import DurableRunStore, default_coordinator_database, default_state_root
from .execution import TUIConfig
from .prompt_library import PromptLibrary, PromptTemplateError


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="gota",
        description="Production local Textual interface for Flujo Gota/OpenCode.",
    )
    parser.add_argument("--version", action="version", version=f"gota-tui {__version__}")
    parser.add_argument("--repo", type=Path, default=Path.cwd(), help="Repository workspace")
    parser.add_argument("--state-root", type=Path, help="TUI state root (testing/advanced use)")
    parser.add_argument("--coordinator-db", type=Path, help="Coordinator SQLite path")
    parser.add_argument("--model", help="Override the configured OpenCode model")
    parser.add_argument("--variant", help="Override the configured OpenCode variant")
    parser.add_argument("--opencode", default=os.environ.get("GOTA_OPENCODE", "opencode"))
    subcommands = parser.add_subparsers(dest="command")
    clipboard = subcommands.add_parser("clipboard", help="Preview the Fedora clipboard")
    clipboard.add_argument("--action", help="Preselect an action; confirmation remains required")
    subcommands.add_parser("history", help="Open durable TUI history")
    return parser


def _dependency_error() -> int:
    print(
        "Gota TUI requires Textual. Install the user dependency with "
        "python3 -m pip install --user is not supported; use the documented "
        "dedicated venv and tools/gota_tui/requirements.txt.",
        file=sys.stderr,
    )
    return 2


def main(arguments: list[str] | None = None) -> int:
    options = build_parser().parse_args(arguments)
    state_root = options.state_root.expanduser() if options.state_root else default_state_root()
    database = (
        options.coordinator_db.expanduser()
        if options.coordinator_db is not None
        else default_coordinator_database(state_root)
    )
    try:
        registry = ActionRegistry.default()
        prompts = PromptLibrary.default()
    except (ActionRegistryError, PromptTemplateError) as error:
        print(f"Gota configuration error: {error}", file=sys.stderr)
        return 2

    try:
        from .app import GotaApp
    except ModuleNotFoundError as error:
        if error.name == "textual":
            return _dependency_error()
        raise

    runs = DurableRunStore(state_root)
    config = TUIConfig(
        repository=options.repo.expanduser().resolve(),
        database=database,
        opencode_executable=options.opencode,
        model_override=options.model or os.environ.get("GOTA_TUI_MODEL") or None,
        variant_override=options.variant or os.environ.get("GOTA_TUI_VARIANT") or None,
    )
    initial_prompt: str | None = None
    initial_action: str | None = None
    if options.command == "clipboard":
        try:
            initial_prompt = ClipboardReader().read()
        except Exception as error:
            print(f"Clipboard diagnostic: {error}", file=sys.stderr)
    if options.command == "history":
        initial_prompt = None
    if options.command == "clipboard":
        initial_action = options.action
    app = GotaApp(
        registry=registry,
        runs=runs,
        prompts=prompts,
        config=config,
        clipboard_reader=ClipboardReader(),
        clipboard_writer=ClipboardWriter(),
        initial_prompt=initial_prompt,
        initial_action=initial_action,
        initial_history=options.command == "history",
    )
    app.run()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
