"""Command-line entry point for ``gota``, ``gota clipboard`` and history."""

from __future__ import annotations

import argparse
import importlib
from importlib import metadata
import os
import sys
from pathlib import Path

from . import __version__
from .actions import ActionRegistry, ActionRegistryError
from .clipboard import ClipboardReader, ClipboardWriter
from .durable import DurableRunStore, default_coordinator_database, default_state_root
from .execution import TUIConfig
from .prompt_library import PromptLibrary, PromptTemplateError
from .runtime import RuntimePathError, default_tui_python, default_tui_venv


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
    parser.add_argument("--role", help="Override the semantic OpenCode role")
    parser.add_argument("--agent", help="Override the configured OpenCode agent")
    parser.add_argument("--opencode", default=os.environ.get("GOTA_OPENCODE", "opencode"))
    parser.add_argument(
        "--self-check",
        action="store_true",
        help="Check the dedicated runtime and production TUI dependencies",
    )
    subcommands = parser.add_subparsers(dest="command")
    subcommands.add_parser("clipboard", help="Execute the current clipboard prompt directly")
    subcommands.add_parser("history", help="Open durable TUI history")
    subcommands.add_parser(
        "doctor", help="Check the dedicated runtime and production TUI dependencies"
    )
    return parser


def _dependency_error() -> int:
    print(
        "Gota TUI requires Textual and Rich. Install user dependencies with "
        "python3 -m pip install --user is not supported; use the documented "
        "dedicated venv and tools/gota_tui/requirements.txt.",
        file=sys.stderr,
    )
    return 2


def _self_check() -> int:
    failures = 0

    print("Gota TUI self-check")

    def report(label: str, detail: str, *, ok: bool = True, warning: bool = False) -> None:
        nonlocal failures
        if warning:
            status = "WARNING"
        elif ok:
            status = "PASS"
        else:
            status = "FAIL"
            failures += 1
        print(f"{label}={status} {detail}")

    try:
        expected_venv = default_tui_venv()
        expected_python = default_tui_python()
        executable = Path(sys.executable)
        prefix = Path(sys.prefix)
        runtime_ok = (
            expected_python.is_file()
            and executable.is_absolute()
            and executable.parent == expected_python.parent
            and prefix.resolve() == expected_venv.resolve()
        )
        report(
            "PYTHON_RUNTIME",
            f"executable={sys.executable} version={sys.version.split()[0]}",
            ok=runtime_ok,
        )
        report(
            "VENV",
            f"expected={expected_venv} prefix={sys.prefix}",
            ok=runtime_ok,
        )
    except (OSError, RuntimePathError) as error:
        report("PYTHON_RUNTIME", str(error), ok=False)
        report("VENV", str(error), ok=False)

    for package in ("textual", "rich"):
        try:
            module = importlib.import_module(package)
            location = getattr(module, "__file__", "unknown")
            try:
                version = metadata.version(package)
            except metadata.PackageNotFoundError:
                version = "unknown"
            report(f"{package.upper()}_IMPORT", f"version={version} path={location}")
        except Exception as error:
            report(f"{package.upper()}_IMPORT", f"{type(error).__name__}: {error}", ok=False)

    try:
        from .app import GotaApp

        del GotaApp
        report("GOTA_APP_IMPORT", "from gota_tui.app import GotaApp")
    except Exception as error:
        report("GOTA_APP_IMPORT", f"{type(error).__name__}: {error}", ok=False)

    try:
        state_root = default_state_root()
        report("STATE_ROOT", str(state_root), ok=state_root.is_absolute())
    except Exception as error:
        report("STATE_ROOT", f"{type(error).__name__}: {error}", ok=False)

    try:
        registry = ActionRegistry.default()
        report("ACTION_REGISTRY", f"actions={len(registry)}")
    except Exception as error:
        report("ACTION_REGISTRY", f"{type(error).__name__}: {error}", ok=False)

    try:
        prompts = PromptLibrary.default()
        report("PROMPT_LIBRARY", f"templates={len(prompts.templates)}")
    except Exception as error:
        report("PROMPT_LIBRARY", f"{type(error).__name__}: {error}", ok=False)

    try:
        reader_names = tuple(backend.name for backend in ClipboardReader().available_backends())
        writer_names = tuple(backend.name for backend in ClipboardWriter().available_backends())
        report("CLIPBOARD_INPUT", ",".join(reader_names) or "none", warning=not reader_names)
        report("CLIPBOARD_OUTPUT", ",".join(writer_names) or "none", warning=not writer_names)
    except Exception as error:
        report("CLIPBOARD_INPUT", f"{type(error).__name__}: {error}", warning=True)
        report("CLIPBOARD_OUTPUT", f"{type(error).__name__}: {error}", warning=True)

    verdict = "PASS" if failures == 0 else "FAIL"
    print(f"SELF_CHECK={verdict}")
    return 0 if failures == 0 else 1


def main(arguments: list[str] | None = None) -> int:
    options = build_parser().parse_args(arguments)
    if options.self_check or options.command == "doctor":
        return _self_check()
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
        if error.name in {"textual", "rich"}:
            return _dependency_error()
        raise

    runs = DurableRunStore(state_root)
    config = TUIConfig(
        repository=options.repo.expanduser().resolve(),
        database=database,
        opencode_executable=options.opencode,
        model_override=options.model or os.environ.get("GOTA_TUI_MODEL") or None,
        variant_override=options.variant or os.environ.get("GOTA_TUI_VARIANT") or None,
        role_override=options.role or os.environ.get("GOTA_TUI_ROLE") or None,
        agent_override=options.agent or os.environ.get("GOTA_TUI_AGENT") or None,
    )
    initial_prompt: str | None = None
    initial_action: str | None = None
    if options.command == "clipboard":
        try:
            initial_prompt = ClipboardReader().read()
        except Exception as error:
            print(f"Clipboard diagnostic: {error}", file=sys.stderr)
            return 2
        if not initial_prompt.strip():
            print("Clipboard diagnostic: Clipboard prompt is empty", file=sys.stderr)
            return 2
        initial_action = "clipboard-prompt"
    if options.command == "history":
        initial_prompt = None
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
