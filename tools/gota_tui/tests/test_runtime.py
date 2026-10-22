from __future__ import annotations

import asyncio
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

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


if __name__ == "__main__":
    unittest.main()
