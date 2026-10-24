from __future__ import annotations

import asyncio
import hashlib
import os
import subprocess
import sys
import tempfile
import threading
import unittest
from pathlib import Path
from unittest.mock import patch

from gota_tui.runtime import default_tui_python


class GotaTUIRuntimeTest(unittest.TestCase):
    def setUp(self) -> None:
        self.repository = Path(__file__).resolve().parents[3]
        self.environment = os.environ.copy()
        self.environment["PYTHONDONTWRITEBYTECODE"] = "1"
        self.environment["PYTHONNOUSERSITE"] = "1"
        self.environment.pop("PYTHONPATH", None)
        self.venv_python = default_tui_python(self.environment)
        self.install_script = self.repository / "tools/gota_tui/install_launcher.py"

    def test_dedicated_python_imports_textual_rich_and_gota_app_without_global_path(self) -> None:
        self.assertTrue(self.venv_python.is_file(), self.venv_python)
        import_environment = self.environment.copy()
        import_environment["PYTHONPATH"] = str(self.repository / "tools/coordinator/src")
        result = subprocess.run(
            [
                str(self.venv_python),
                "-B",
                "-c",
                (
                    "import rich, textual; "
                    "from tools.gota_tui.app import GotaApp; "
                    "print(textual.__file__); print(rich.__file__); print(GotaApp.__module__)"
                ),
            ],
            cwd=self.repository,
            env=import_environment,
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn(str(self.venv_python.parent.parent), result.stdout)
        self.assertIn("tools.gota_tui.app", result.stdout)

    def test_dedicated_venv_path_uses_xdg_data_home(self) -> None:
        data_home = Path(tempfile.gettempdir()) / "gota-tui-xdg-data"
        environment = {"XDG_DATA_HOME": str(data_home), "HOME": "/ignored"}
        self.assertEqual(
            default_tui_python(environment),
            data_home / "flow-coordinator" / "gota-tui-venv" / "bin" / "python",
        )

    def test_generated_launcher_uses_dedicated_python_and_self_check_imports_app(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            destination = root / "bin" / "gota"
            install = subprocess.run(
                [
                    sys.executable,
                    str(self.install_script),
                    "--destination",
                    str(destination),
                    "--force",
                ],
                cwd=self.repository,
                env=self.environment,
                capture_output=True,
                text=True,
                check=False,
            )
            self.assertEqual(install.returncode, 0, install.stderr)
            self.assertEqual(
                destination.read_text(encoding="utf-8").splitlines()[0],
                f"#!{self.venv_python}",
            )

            check_environment = self.environment.copy()
            check_environment["XDG_STATE_HOME"] = str(root / "state")
            check = subprocess.run(
                [str(destination), "--self-check"],
                cwd=self.repository,
                env=check_environment,
                capture_output=True,
                text=True,
                check=False,
            )
            self.assertEqual(check.returncode, 0, check.stderr)
            self.assertIn("PYTHON_RUNTIME=PASS", check.stdout)
            self.assertIn("VENV=PASS", check.stdout)
            self.assertIn("TEXTUAL_IMPORT=PASS", check.stdout)
            self.assertIn("RICH_IMPORT=PASS", check.stdout)
            self.assertIn("GOTA_APP_IMPORT=PASS", check.stdout)
            self.assertIn("ACTION_REGISTRY=PASS", check.stdout)
            self.assertIn("PROMPT_LIBRARY=PASS", check.stdout)
            self.assertIn("SELF_CHECK=PASS", check.stdout)

    def test_textual_main_screen_mounts_and_unmounts_headlessly(self) -> None:
        from gota_tui.actions import ActionRegistry
        from gota_tui.app import GotaApp
        from gota_tui.clipboard import ClipboardReader, ClipboardWriter
        from gota_tui.durable import DurableRunStore
        from gota_tui.execution import TUIConfig
        from gota_tui.prompt_library import PromptLibrary

        async def exercise() -> None:
            with tempfile.TemporaryDirectory() as temporary:
                root = Path(temporary)
                app = GotaApp(
                    registry=ActionRegistry.default(),
                    runs=DurableRunStore(root / "state"),
                    prompts=PromptLibrary.default(),
                    config=TUIConfig(
                        repository=root,
                        database=root / "coordinator.sqlite3",
                        opencode_executable="true",
                    ),
                    clipboard_reader=ClipboardReader(which=lambda _: None),
                    clipboard_writer=ClipboardWriter(which=lambda _: None),
                )
                async with app.run_test() as pilot:
                    await pilot.pause()
                    app.query_one("#screen-title")
                    app.query_one("#action-list")

        asyncio.run(exercise())

    def test_main_menu_clipboard_prompt_runs_with_one_enter_and_shows_final_report(self) -> None:
        from flow_coordinator import OpenCodeRunResult, OpenCodeRunStatus
        from gota_tui.actions import ActionRegistry
        from gota_tui.app import GotaApp
        from gota_tui.durable import DurableRunStore
        from gota_tui.execution import TUIConfig
        from gota_tui.prompt_library import PromptLibrary

        prompt = "Responde únicamente: GOTA_CLIPBOARD_DIRECT_OK"
        started = threading.Event()
        release = threading.Event()
        runner_calls: list[dict[str, object]] = []
        copied: list[str] = []

        class Reader:
            def read(self) -> str:
                return prompt

        class Writer:
            def copy(self, text: str) -> str:
                copied.append(text)
                return "mock"

        class Runner:
            def __init__(self, *, executable: str, model: str, variant: str) -> None:
                runner_calls.append(
                    {"executable": executable, "model": model, "variant": variant}
                )

            def run(
                self,
                *,
                agent: str,
                prompt: str,
                cwd: Path,
                timeout: float,
                output_callback: object,
                cancel_event: object,
            ) -> OpenCodeRunResult:
                del timeout, cancel_event
                runner_calls.append(
                    {"agent": agent, "prompt": prompt, "cwd": cwd}
                )
                assert callable(output_callback)
                output_callback("stdout", "direct stdout\n")  # type: ignore[operator]
                started.set()
                release.wait(timeout=2.0)
                output_callback("stderr", "direct stderr\n")  # type: ignore[operator]
                return OpenCodeRunResult(
                    status=OpenCodeRunStatus.INVALID_PAYLOAD,
                    argv=("opencode", "run", "--auto", prompt),
                    cwd=str(cwd),
                    stdout="direct stdout\n",
                    stderr="direct stderr\n",
                    exit_code=0,
                    timed_out=False,
                    error="plain direct response",
                )

        async def exercise() -> None:
            with tempfile.TemporaryDirectory() as temporary:
                root = Path(temporary)
                state = DurableRunStore(root / "state")
                app = GotaApp(
                    registry=ActionRegistry.default(),
                    runs=state,
                    prompts=PromptLibrary.default(),
                    config=TUIConfig(
                        repository=root,
                        database=root / "coordinator.sqlite3",
                        opencode_executable=sys.executable,
                    ),
                    clipboard_reader=Reader(),  # type: ignore[arg-type]
                    clipboard_writer=Writer(),  # type: ignore[arg-type]
                )
                with patch("gota_tui.coordinator_facade.OpenCodeRunner", Runner):
                    async with app.run_test(size=(100, 40)) as pilot:
                        await pilot.pause()
                        action_list = app.query_one("#action-list")
                        action_list.focus()
                        await pilot.press("down")
                        await pilot.pause()
                        self.assertEqual(app._selected_action.id, "clipboard-prompt")

                        await pilot.press("enter")
                        self.assertTrue(await asyncio.to_thread(started.wait, 1.0))
                        await pilot.pause()
                        self.assertEqual(app._screen, "running")
                        self.assertFalse(app._confirming)
                        self.assertNotIn(app._screen, {"preview", "confirmation"})
                        self.assertEqual(len(runner_calls), 2)

                        release.set()
                        for _ in range(100):
                            await pilot.pause(0.01)
                            if app._screen == "final":
                                break
                        self.assertEqual(app._screen, "final")
                        self.assertIn("Final report", str(app.query_one("#screen-title").render()))
                        self.assertIn("TASK_ID=NOT_APPLICABLE", str(app.query_one("#report-view").render()))
                        self.assertEqual(len(runner_calls), 2)
                        self.assertEqual(len(copied), 1)
                        run_id = app._result.run_id
                        paths = state.paths(run_id)
                        self.assertEqual(paths.prompt.read_text(encoding="utf-8"), prompt)
                        self.assertEqual(
                            paths.prompt_sha.read_text(encoding="utf-8").strip(),
                            hashlib.sha256(prompt.encode("utf-8")).hexdigest(),
                        )
                        self.assertTrue(paths.request.exists())
                        self.assertTrue(paths.live_log.exists())
                        self.assertTrue(paths.result.exists())
                        self.assertTrue(paths.report.exists())
                        live_log = paths.live_log.read_text(encoding="utf-8")
                        self.assertIn("[STDOUT] direct stdout", live_log)
                        self.assertIn("[STDERR] direct stderr", live_log)
                        self.assertTrue(paths.report.exists())
                        self.assertIn("CLIPBOARD_COPY=OK", paths.report.read_text(encoding="utf-8"))
                        self.assertEqual(state.history_records()[0]["ui_state"], "COMPLETED")

        asyncio.run(exercise())

    def test_final_report_highlights_process_report_conflict(self) -> None:
        from gota_tui.actions import ActionRegistry
        from gota_tui.app import GotaApp
        from gota_tui.clipboard import ClipboardReader, ClipboardWriter
        from gota_tui.durable import DurableRunStore
        from gota_tui.execution import ActionExecutionResult, TUIConfig
        from gota_tui.prompt_library import PromptLibrary

        async def exercise() -> None:
            with tempfile.TemporaryDirectory() as temporary:
                root = Path(temporary)
                state = DurableRunStore(root / "state")
                app = GotaApp(
                    registry=ActionRegistry.default(),
                    runs=state,
                    prompts=PromptLibrary.default(),
                    config=TUIConfig(
                        repository=root,
                        database=root / "coordinator.sqlite3",
                    ),
                    clipboard_reader=ClipboardReader(which=lambda _: None),
                    clipboard_writer=ClipboardWriter(which=lambda _: None),
                )
                result = ActionExecutionResult(
                    run_id="conflict",
                    paths=state.paths("conflict"),
                    report=(
                        "GOTA_REPORT_V1\n"
                        "PROCESS_STATUS=non_zero_exit\n"
                        "PROCESS_EXIT_CODE=1\n"
                        "RESULT_CONSISTENCY=PROCESS_FAIL_REPORT_PASS\n"
                        "VERDICT=FAIL\n"
                    ),
                    report_path=str(state.paths("conflict").report),
                    log_path=str(state.paths("conflict").live_log),
                    clipboard_status="OK",
                    clipboard_error=None,
                    verdict="FAIL",
                    coordinator_state="NOT_APPLICABLE",
                    task_id="NOT_APPLICABLE",
                    coordinator_run_id=None,
                    diagnostic=(
                        "Process failed, but the embedded task report declared PASS. "
                        "Manual review required."
                    ),
                    process_status="non_zero_exit",
                    process_exit_code=1,
                    embedded_report_id="VIT_001R",
                    embedded_status="PASA",
                    embedded_verdict="PASA",
                    result_consistency="PROCESS_FAIL_REPORT_PASS",
                )
                async with app.run_test(size=(100, 40)) as pilot:
                    await pilot.pause()
                    app._show_final(result)
                    status = str(app.query_one("#status").render())
                    self.assertIn("RESULT CONFLICT — review required", status)
                    self.assertIn("PROCESS_FAIL_REPORT_PASS", status)
                    self.assertTrue(app.query_one("#report-view").has_class("result-conflict"))

        asyncio.run(exercise())

    def test_historical_report_recalculates_result_conflict_in_both_directions(self) -> None:
        from gota_tui.actions import ActionRegistry
        from gota_tui.app import GotaApp
        from gota_tui.clipboard import ClipboardReader, ClipboardWriter
        from gota_tui.durable import DurableRunStore
        from gota_tui.execution import TUIConfig
        from gota_tui.prompt_library import PromptLibrary

        async def exercise() -> None:
            with tempfile.TemporaryDirectory() as temporary:
                root = Path(temporary)
                state = DurableRunStore(root / "state")
                conflict_report = (
                    "GOTA_REPORT_V1\n"
                    "RESULT_CONSISTENCY=PROCESS_FAIL_REPORT_PASS\n"
                )
                normal_report = "GOTA_REPORT_V1\nRESULT_CONSISTENCY=NO_EMBEDDED_REPORT\n"
                for run_id, report in (
                    ("conflict", conflict_report),
                    ("normal", normal_report),
                ):
                    state.paths(run_id).directory.mkdir(parents=True)
                    state.persist_report(run_id, report)
                app = GotaApp(
                    registry=ActionRegistry.default(),
                    runs=state,
                    prompts=PromptLibrary.default(),
                    config=TUIConfig(
                        repository=root,
                        database=root / "coordinator.sqlite3",
                    ),
                    clipboard_reader=ClipboardReader(which=lambda _: None),
                    clipboard_writer=ClipboardWriter(which=lambda _: None),
                )

                async with app.run_test(size=(100, 40)) as pilot:
                    await pilot.pause()
                    report_view = app.query_one("#report-view")

                    app._update_report_view(conflict_report)
                    self.assertTrue(report_view.has_class("result-conflict"))
                    app._update_report_view(normal_report)
                    self.assertFalse(report_view.has_class("result-conflict"))
                    app._update_report_view(conflict_report)
                    self.assertTrue(report_view.has_class("result-conflict"))

                    app._history = [{"run_id": "conflict"}]
                    app._history_index = 0
                    app._screen = "history"
                    app.action_open_report()
                    self.assertTrue(report_view.has_class("result-conflict"))

                    app._history = [{"run_id": "normal"}]
                    app._history_index = 0
                    app._screen = "history"
                    app.action_open_report()
                    self.assertFalse(report_view.has_class("result-conflict"))

                    app._history = [{"run_id": "conflict"}]
                    app._history_index = 0
                    app._screen = "history"
                    app.action_open_report()
                    self.assertTrue(report_view.has_class("result-conflict"))

        asyncio.run(exercise())

    def test_selected_audit_reads_clipboard_and_runs_with_one_enter(self) -> None:
        from flow_coordinator import OpenCodeRunResult, OpenCodeRunStatus
        from gota_tui.actions import ActionRegistry
        from gota_tui.app import GotaApp
        from gota_tui.durable import DurableRunStore
        from gota_tui.execution import ActionExecutor, TUIConfig
        from gota_tui.prompt_library import PromptLibrary

        prompt = "Inspect the repository read-only. Do not modify files."
        started = threading.Event()
        release = threading.Event()
        runner_calls: list[dict[str, object]] = []
        copied: list[str] = []

        class Reader:
            reads = 0

            def read(self) -> str:
                self.reads += 1
                return prompt

        class Writer:
            def copy(self, text: str) -> str:
                copied.append(text)
                return "mock"

        reader = Reader()

        class Runner:
            def __init__(self, *, executable: str, model: str, variant: str) -> None:
                runner_calls.append(
                    {"executable": executable, "model": model, "variant": variant}
                )

            def run(
                self,
                *,
                agent: str,
                prompt: str,
                cwd: Path,
                timeout: float,
                output_callback: object,
                cancel_event: object,
            ) -> OpenCodeRunResult:
                del timeout, cancel_event
                runner_calls.append(
                    {"agent": agent, "prompt": prompt, "cwd": cwd}
                )
                assert callable(output_callback)
                output_callback("stdout", "GOTA_READ_ONLY_UI_OK\n")  # type: ignore[operator]
                started.set()
                release.wait(timeout=2.0)
                return OpenCodeRunResult(
                    status=OpenCodeRunStatus.INVALID_PAYLOAD,
                    argv=(
                        "opencode",
                        "run",
                        "--standalone",
                        "--model",
                        "openai/gpt-5.6-luna#max",
                        "--agent",
                        agent,
                        "--auto",
                        prompt,
                    ),
                    cwd=str(cwd),
                    stdout="GOTA_READ_ONLY_UI_OK\n",
                    stderr="",
                    exit_code=0,
                    timed_out=False,
                    error="generic read-only response",
                )

        async def exercise() -> None:
            with tempfile.TemporaryDirectory() as temporary:
                root = Path(temporary)
                state = DurableRunStore(root / "state")
                app = GotaApp(
                    registry=ActionRegistry.default(),
                    runs=state,
                    prompts=PromptLibrary.default(),
                    config=TUIConfig(
                        repository=self.repository,
                        database=root / "coordinator.sqlite3",
                        opencode_executable="fake-opencode",
                    ),
                    clipboard_reader=reader,  # type: ignore[arg-type]
                    clipboard_writer=Writer(),  # type: ignore[arg-type]
                )
                with patch("gota_tui.coordinator_facade.OpenCodeRunner", Runner), patch.object(
                    ActionExecutor,
                    "_opencode_version",
                    return_value="opencode v2.0.32",
                ):
                    async with app.run_test(size=(100, 40)) as pilot:
                        await pilot.pause()
                        action_list = app.query_one("#action-list")
                        audit_index = next(
                            index
                            for index, action in enumerate(app.registry.actions)
                            if action.id == "audit-opencode"
                        )
                        action_list.focus()
                        for _ in range(len(app.registry.actions)):
                            await pilot.press("down")
                            await pilot.pause()
                            if app._selected_action is not None and app._selected_action.id == "audit-opencode":
                                break
                        self.assertEqual(app._selected_action.id, "audit-opencode")
                        self.assertEqual(action_list.index, audit_index)

                        await pilot.press("enter")
                        self.assertTrue(await asyncio.to_thread(started.wait, 1.0))
                        await pilot.pause()
                        self.assertEqual(app._screen, "running")
                        self.assertFalse(app._confirming)
                        self.assertEqual(reader.reads, 1)
                        self.assertNotIn(app._screen, {"preview", "confirmation"})

                        release.set()
                        for _ in range(100):
                            await pilot.pause(0.01)
                            if app._screen == "final":
                                break
                        self.assertEqual(app._screen, "final")
                        report = str(app.query_one("#report-view").render())
                        self.assertIn("ACTION=audit-opencode", report)
                        self.assertIn("MODEL=openai/gpt-5.6-luna", report)
                        self.assertIn("AGENT=gota-auditor", report)
                        self.assertIn("VERDICT=READ_ONLY_OK", report)
                        self.assertEqual(len(runner_calls), 2)
                        self.assertEqual(runner_calls[1]["prompt"], prompt)
                        self.assertEqual(len(copied), 1)

        asyncio.run(exercise())

    def test_empty_clipboard_blocks_selected_audit_without_starting_runner(self) -> None:
        from gota_tui.actions import ActionRegistry
        from gota_tui.app import GotaApp
        from gota_tui.durable import DurableRunStore
        from gota_tui.execution import TUIConfig
        from gota_tui.prompt_library import PromptLibrary

        class Reader:
            reads = 0

            def read(self) -> str:
                self.reads += 1
                return " \n"

        class Writer:
            def copy(self, text: str) -> str:
                del text
                return "mock"

        async def exercise() -> None:
            with tempfile.TemporaryDirectory() as temporary:
                root = Path(temporary)
                reader = Reader()
                app = GotaApp(
                    registry=ActionRegistry.default(),
                    runs=DurableRunStore(root / "state"),
                    prompts=PromptLibrary.default(),
                    config=TUIConfig(
                        repository=self.repository,
                        database=root / "coordinator.sqlite3",
                        opencode_executable="must-not-run",
                    ),
                    clipboard_reader=reader,  # type: ignore[arg-type]
                    clipboard_writer=Writer(),  # type: ignore[arg-type]
                )
                async with app.run_test(size=(100, 40)) as pilot:
                    await pilot.pause()
                    action_list = app.query_one("#action-list")
                    action_list.focus()
                    for _ in range(len(app.registry.actions)):
                        await pilot.press("down")
                        await pilot.pause()
                        if app._selected_action is not None and app._selected_action.id == "audit-opencode":
                            break
                    await pilot.press("enter")
                    await pilot.pause()
                    self.assertEqual(reader.reads, 1)
                    self.assertEqual(app._screen, "menu")
                    self.assertIsNone(app._execution_task)
                    self.assertIn("Clipboard prompt is empty", str(app.query_one("#status").render()))
                    self.assertEqual(tuple(app.runs.history_records()), ())

        asyncio.run(exercise())

    def test_c_runs_direct_clipboard_prompt_and_footer_is_unambiguous(self) -> None:
        from flow_coordinator import OpenCodeRunResult, OpenCodeRunStatus
        from gota_tui.actions import ActionRegistry
        from gota_tui.app import GotaApp
        from gota_tui.durable import DurableRunStore
        from gota_tui.execution import TUIConfig
        from gota_tui.prompt_library import PromptLibrary

        prompt = "Responde únicamente: GOTA_CLIPBOARD_DIRECT_OK"
        runner_calls: list[dict[str, object]] = []

        class Reader:
            def read(self) -> str:
                return prompt

        class Writer:
            def copy(self, text: str) -> str:
                del text
                return "mock"

        class Runner:
            def __init__(self, *, executable: str, model: str, variant: str) -> None:
                runner_calls.append({"executable": executable, "model": model, "variant": variant})

            def run(self, **kwargs: object) -> OpenCodeRunResult:
                runner_calls.append({"agent": kwargs["agent"], "prompt": kwargs["prompt"]})
                return OpenCodeRunResult(
                    status=OpenCodeRunStatus.INVALID_PAYLOAD,
                    argv=("opencode", "run"),
                    cwd=str(kwargs["cwd"]),
                    stdout="GOTA_CLIPBOARD_DIRECT_OK\n",
                    stderr="",
                    exit_code=0,
                    timed_out=False,
                )

        async def exercise() -> None:
            with tempfile.TemporaryDirectory() as temporary:
                root = Path(temporary)
                state = DurableRunStore(root / "state")
                app = GotaApp(
                    registry=ActionRegistry.default(),
                    runs=state,
                    prompts=PromptLibrary.default(),
                    config=TUIConfig(
                        repository=self.repository,
                        database=root / "coordinator.sqlite3",
                        opencode_executable="fake-opencode",
                    ),
                    clipboard_reader=Reader(),  # type: ignore[arg-type]
                    clipboard_writer=Writer(),  # type: ignore[arg-type]
                )
                with patch("gota_tui.coordinator_facade.OpenCodeRunner", Runner):
                    async with app.run_test(size=(100, 40)) as pilot:
                        await pilot.pause()
                        action_list = app.query_one("#action-list")
                        action_list.focus()
                        for _ in range(len(app.registry.actions)):
                            await pilot.press("down")
                            await pilot.pause()
                            if app._selected_action is not None and app._selected_action.id == "audit-opencode":
                                break
                        await pilot.press("c")
                        for _ in range(100):
                            await pilot.pause(0.01)
                            if app._screen == "final":
                                break
                        self.assertEqual(app._screen, "final")
                        self.assertEqual(app._selected_action.id, "clipboard-prompt")
                        self.assertEqual(runner_calls[1]["agent"], "build")
                        self.assertIn("ACTION=clipboard-prompt", str(app.query_one("#report-view").render()))
                        c_binding = next(binding for binding in app.BINDINGS if binding[0] == "c")
                        self.assertEqual(c_binding[2], "Run clipboard prompt")

        asyncio.run(exercise())

    def test_cli_clipboard_reads_and_starts_direct_flow_without_selector(self) -> None:
        from gota_tui.cli import main

        prompt = "direct CLI prompt"
        created: list[dict[str, object]] = []

        class Reader:
            def read(self) -> str:
                return prompt

        class App:
            def __init__(self, **kwargs: object) -> None:
                created.append(kwargs)

            def run(self) -> None:
                return None

        with patch("gota_tui.cli.ClipboardReader", return_value=Reader()), patch(
            "gota_tui.cli.ClipboardWriter"
        ), patch("gota_tui.app.GotaApp", App):
            result = main(
                [
                    "--repo",
                    str(self.repository),
                    "--state-root",
                    str(self.repository / ".godot/flujo_tests/cli-state"),
                    "clipboard",
                ]
            )

        self.assertEqual(result, 0)
        self.assertEqual(len(created), 1)
        self.assertEqual(created[0]["initial_action"], "clipboard-prompt")
        self.assertEqual(created[0]["initial_prompt"], prompt)

    def test_empty_cli_clipboard_does_not_construct_or_start_app(self) -> None:
        from gota_tui.cli import main

        class Reader:
            def read(self) -> str:
                return " \n"

        with patch("gota_tui.cli.ClipboardReader", return_value=Reader()), patch(
            "gota_tui.app.GotaApp"
        ) as app:
            result = main(["clipboard"])

        self.assertEqual(result, 2)
        app.assert_not_called()

    def test_plain_preview_enter_confirmation_enter_starts_read_only_action(self) -> None:
        from gota_tui.actions import ActionRegistry
        from gota_tui.app import GotaApp
        from gota_tui.clipboard import ClipboardReader, ClipboardWriter
        from gota_tui.durable import DurableRunStore
        from gota_tui.execution import TUIConfig
        from gota_tui.prompt_library import PromptLibrary

        async def exercise() -> None:
            with tempfile.TemporaryDirectory() as temporary:
                root = Path(temporary)
                app = GotaApp(
                    registry=ActionRegistry.default(),
                    runs=DurableRunStore(root / "state"),
                    prompts=PromptLibrary.default(),
                    config=TUIConfig(
                        repository=root,
                        database=root / "coordinator.sqlite3",
                        opencode_executable="true",
                    ),
                    clipboard_reader=ClipboardReader(which=lambda _: None),
                    clipboard_writer=ClipboardWriter(which=lambda _: None),
                    initial_prompt="plain prompt from clipboard",
                )
                execution_started = asyncio.Event()

                async def fake_execute_prepared(_executor: object, _prepared: object) -> None:
                    execution_started.set()

                app._execute_prepared = fake_execute_prepared  # type: ignore[method-assign]
                async with app.run_test(size=(100, 40)) as pilot:
                    await pilot.pause()
                    self.assertEqual(app._screen, "preview")
                    action_list = app.query_one("#action-list")
                    audit_index = next(
                        index
                        for index, action in enumerate(app.registry.actions)
                        if action.id == "audit-readonly"
                    )
                    action_list.focus()
                    for _ in range(len(app.registry.actions)):
                        await pilot.press("down")
                        await pilot.pause()
                        if action_list.index == audit_index:
                            break
                    self.assertEqual(action_list.index, audit_index)
                    self.assertEqual(app._selected_action.id, "audit-readonly")

                    await pilot.press("enter")
                    await pilot.pause()
                    self.assertEqual(app._screen, "confirmation")
                    self.assertIn("Confirmation", str(app.query_one("#screen-title").render()))
                    self.assertTrue(app._confirming)

                    await pilot.press("enter")
                    await pilot.pause()
                    self.assertEqual(app._screen, "running")
                    await asyncio.wait_for(execution_started.wait(), timeout=1.0)

        asyncio.run(exercise())

    def test_cli_preselection_requires_confirmation_escape_returns_and_focus_is_safe(self) -> None:
        from gota_tui.actions import ActionRegistry
        from gota_tui.app import GotaApp
        from gota_tui.clipboard import ClipboardReader, ClipboardWriter
        from gota_tui.durable import DurableRunStore
        from gota_tui.execution import TUIConfig
        from gota_tui.prompt_library import PromptLibrary

        async def exercise() -> None:
            with tempfile.TemporaryDirectory() as temporary:
                root = Path(temporary)
                app = GotaApp(
                    registry=ActionRegistry.default(),
                    runs=DurableRunStore(root / "state"),
                    prompts=PromptLibrary.default(),
                    config=TUIConfig(
                        repository=root,
                        database=root / "coordinator.sqlite3",
                        opencode_executable="true",
                    ),
                    clipboard_reader=ClipboardReader(which=lambda _: None),
                    clipboard_writer=ClipboardWriter(which=lambda _: None),
                    initial_prompt="plain prompt",
                    initial_action="audit-readonly",
                )
                async with app.run_test(size=(100, 40)) as pilot:
                    await pilot.pause()
                    self.assertEqual(app._screen, "preview")
                    self.assertEqual(app._selected_action.id, "audit-readonly")
                    self.assertFalse(app._confirming)
                    self.assertIsNone(app._execution_task)
                    self.assertIn("Enter Select/confirm", str(app.query_one("#status").render()))
                    enter_binding = next(binding for binding in app.BINDINGS if binding[0] == "enter")
                    self.assertEqual(enter_binding[2], "Select/confirm")

                    await pilot.press("enter")
                    await pilot.pause()
                    self.assertEqual(app._screen, "confirmation")
                    await pilot.press("escape")
                    await pilot.pause()
                    self.assertEqual(app._screen, "preview")
                    self.assertEqual(app._selected_action.id, "audit-readonly")
                    self.assertIsNone(app._execution_task)

                    app.set_focus(app.query_one("#prompt-view"))
                    await pilot.press("enter")
                    await pilot.pause()
                    self.assertEqual(app._screen, "confirmation")

        asyncio.run(exercise())

    def test_plain_prompt_marks_mutable_action_unavailable_and_blocks_enter(self) -> None:
        from gota_tui.actions import ActionRegistry
        from gota_tui.app import GotaApp
        from gota_tui.clipboard import ClipboardReader, ClipboardWriter
        from gota_tui.durable import DurableRunStore
        from gota_tui.execution import TUIConfig
        from gota_tui.prompt_library import PromptLibrary

        async def exercise() -> None:
            with tempfile.TemporaryDirectory() as temporary:
                root = Path(temporary)
                app = GotaApp(
                    registry=ActionRegistry.default(),
                    runs=DurableRunStore(root / "state"),
                    prompts=PromptLibrary.default(),
                    config=TUIConfig(
                        repository=root,
                        database=root / "coordinator.sqlite3",
                        opencode_executable="true",
                    ),
                    clipboard_reader=ClipboardReader(which=lambda _: None),
                    clipboard_writer=ClipboardWriter(which=lambda _: None),
                    initial_prompt="plain prompt",
                    initial_action="execute-task",
                )
                async with app.run_test(size=(100, 40)) as pilot:
                    await pilot.pause()
                    action_list = app.query_one("#action-list")
                    execute_index = next(
                        index
                        for index, action in enumerate(app.registry.actions)
                        if action.id == "execute-task"
                    )
                    self.assertTrue(action_list.children[execute_index].disabled)
                    self.assertIn("unavailable", str(app.query_one("#status").render()))
                    await pilot.press("enter")
                    await pilot.pause()
                    self.assertEqual(app._screen, "preview")
                    self.assertFalse(app._confirming)
                    self.assertIn("Action unavailable", str(app.query_one("#status").render()))

        asyncio.run(exercise())

    def test_mouse_selected_event_uses_the_same_preview_activation_path(self) -> None:
        from gota_tui.actions import ActionRegistry
        from gota_tui.app import GotaApp
        from gota_tui.clipboard import ClipboardReader, ClipboardWriter
        from gota_tui.durable import DurableRunStore
        from gota_tui.execution import TUIConfig
        from gota_tui.prompt_library import PromptLibrary

        async def exercise() -> None:
            with tempfile.TemporaryDirectory() as temporary:
                root = Path(temporary)
                app = GotaApp(
                    registry=ActionRegistry.default(),
                    runs=DurableRunStore(root / "state"),
                    prompts=PromptLibrary.default(),
                    config=TUIConfig(
                        repository=root,
                        database=root / "coordinator.sqlite3",
                        opencode_executable="true",
                    ),
                    clipboard_reader=ClipboardReader(which=lambda _: None),
                    clipboard_writer=ClipboardWriter(which=lambda _: None),
                    initial_prompt="plain prompt",
                )
                async with app.run_test(size=(100, 40)) as pilot:
                    await pilot.pause()
                    action_list = app.query_one("#action-list")
                    audit_index = next(
                        index
                        for index, action in enumerate(app.registry.actions)
                        if action.id == "audit-readonly"
                    )
                    await pilot.click(action_list.children[audit_index])
                    await pilot.pause()
                    self.assertEqual(app._selected_action.id, "audit-readonly")
                    self.assertEqual(app._screen, "confirmation")

        asyncio.run(exercise())

    def test_structured_mutable_preview_keeps_mandatory_confirmation(self) -> None:
        from gota_tui.actions import ActionRegistry
        from gota_tui.app import GotaApp
        from gota_tui.clipboard import ClipboardReader, ClipboardWriter
        from gota_tui.durable import DurableRunStore
        from gota_tui.execution import TUIConfig
        from gota_tui.prompt_library import PromptLibrary

        async def exercise() -> None:
            with tempfile.TemporaryDirectory() as temporary:
                root = Path(temporary)
                prompt = (
                    "+++\n"
                    "version = 1\n"
                    "task_id = 'task'\n"
                    "title = 'Task'\n"
                    "project_id = 'project'\n"
                    "repository_id = 'repo'\n"
                    f"workspace = '{root}'\n"
                    "branch = 'feature/task'\n"
                    "base_sha = '0123456789abcdef0123456789abcdef01234567'\n"
                    "context_id = 'context'\n"
                    "allowed_paths = ['src/change.py']\n"
                    "protected_paths = ['protected.txt']\n"
                    "acceptance_criteria = ['tests pass']\n"
                    "commit_message = 'feat: task'\n"
                    "attempt = 1\n"
                    "+++\n"
                    "Implement the task.\n"
                )
                app = GotaApp(
                    registry=ActionRegistry.default(),
                    runs=DurableRunStore(root / "state"),
                    prompts=PromptLibrary.default(),
                    config=TUIConfig(
                        repository=root,
                        database=root / "coordinator.sqlite3",
                        opencode_executable="true",
                    ),
                    clipboard_reader=ClipboardReader(which=lambda _: None),
                    clipboard_writer=ClipboardWriter(which=lambda _: None),
                    initial_prompt=prompt,
                    initial_action="execute-task",
                )
                async with app.run_test(size=(100, 40)) as pilot:
                    await pilot.pause()
                    self.assertFalse(app.query_one("#action-list").children[0].disabled)
                    await pilot.press("enter")
                    await pilot.pause()
                    self.assertEqual(app._screen, "confirmation")
                    self.assertTrue(app._confirming)

        asyncio.run(exercise())


if __name__ == "__main__":
    unittest.main()
