"""Production executor policy, using isolated fake binaries only."""

from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "tools/godot"))
from resolve_godot import GodotResolutionError, REQUIRED_VERSION, resolve_production_godot


class ProductionGodotTest(unittest.TestCase):
    def setUp(self) -> None:
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.env = {"HOME": str(self.root / "home"), "PATH": str(self.root / "bin")}
        self.canonical = self.root / "home/.local/share/flujo/toolchains/godot/4.7.2-stable/godot"

    def fake(self, path: Path, version: str = REQUIRED_VERSION, code: int = 0) -> Path:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(f"#!/bin/sh\nprintf '%s\\n' '{version}'\nexit {code}\n")
        path.chmod(0o755)
        return path

    def test_valid_override_has_priority(self) -> None:
        override = self.fake(self.root / "override with spaces")
        self.fake(self.canonical, "wrong")
        self.env["FLUJO_GODOT_BIN"] = str(override)
        self.assertEqual(resolve_production_godot(self.env), override)

    def test_canonical_pinned_accepted(self) -> None:
        self.fake(self.canonical)
        self.assertEqual(resolve_production_godot(self.env), self.canonical)

    def test_missing_pinned_fails_closed_without_path_fallback(self) -> None:
        path_godot = self.fake(self.root / "bin/godot")
        path_godot.write_text(f"#!/bin/sh\nprintf called > '{self.root / 'called'}'\nprintf '%s\\n' '{REQUIRED_VERSION}'\n")
        with self.assertRaisesRegex(GodotResolutionError, "not a file"):
            resolve_production_godot(self.env)
        self.assertFalse((self.root / "called").exists())

    def test_non_executable_fails_closed(self) -> None:
        self.fake(self.canonical).chmod(0o644)
        with self.assertRaisesRegex(GodotResolutionError, "not executable"):
            resolve_production_godot(self.env)

    def test_wrong_version_fails_closed(self) -> None:
        self.fake(self.canonical, "4.8.stable.official.other")
        with self.assertRaisesRegex(GodotResolutionError, "expected.*4.7.2.stable.official.ed1daf0bf"):
            resolve_production_godot(self.env)

    def test_fedora_same_commit_rejected(self) -> None:
        self.fake(self.canonical, "4.7.2.stable.fedora.ed1daf0bf")
        with self.assertRaisesRegex(GodotResolutionError, "fedora"):
            resolve_production_godot(self.env)

    def test_custom_xdg_data_home(self) -> None:
        self.env["XDG_DATA_HOME"] = str(self.root / "custom data")
        expected = self.fake(self.root / "custom data/flujo/toolchains/godot/4.7.2-stable/godot")
        self.assertEqual(resolve_production_godot(self.env), expected)

    def test_home_fallback_without_xdg(self) -> None:
        self.assertNotIn("XDG_DATA_HOME", self.env)
        self.fake(self.canonical)
        self.assertEqual(resolve_production_godot(self.env), self.canonical)

    def test_empty_xdg_uses_home(self) -> None:
        self.env["XDG_DATA_HOME"] = ""
        self.fake(self.canonical)
        self.assertEqual(resolve_production_godot(self.env), self.canonical)

    def test_invalid_override_does_not_fall_back_to_valid_pinned(self) -> None:
        self.fake(self.canonical)
        for override in ("", str(self.root / "missing")):
            with self.subTest(override=override):
                self.env["FLUJO_GODOT_BIN"] = override
                with self.assertRaises(GodotResolutionError):
                    resolve_production_godot(self.env)

    def test_probe_nonzero_is_not_accepted_even_with_exact_version(self) -> None:
        self.fake(self.canonical, code=9)
        with self.assertRaisesRegex(GodotResolutionError, "exit 9"):
            resolve_production_godot(self.env)

    def test_extra_version_output_rejected(self) -> None:
        self.fake(self.canonical, REQUIRED_VERSION + "\nextra")
        with self.assertRaises(GodotResolutionError):
            resolve_production_godot(self.env)

    def test_override_fedora_cannot_fall_back_to_official_pinned(self) -> None:
        self.fake(self.canonical)
        self.env["FLUJO_GODOT_BIN"] = str(self.fake(self.root / "fedora", "4.7.2.stable.fedora.ed1daf0bf"))
        with self.assertRaisesRegex(GodotResolutionError, "fedora"):
            resolve_production_godot(self.env)

    def test_probe_timeout_fails_closed(self) -> None:
        self.fake(self.canonical)
        with patch("resolve_godot.subprocess.run", side_effect=subprocess.TimeoutExpired("fake", 10)) as run:
            with self.assertRaisesRegex(GodotResolutionError, "version probe failed"):
                resolve_production_godot(self.env)
        self.assertEqual(run.call_args.kwargs["timeout"], 10)

    def test_invalid_executable_format_fails_closed(self) -> None:
        self.fake(self.canonical).write_text("not an executable format")
        with self.assertRaisesRegex(GodotResolutionError, "version probe failed"):
            resolve_production_godot(self.env)

    def test_missing_home_fails_closed(self) -> None:
        del self.env["HOME"]
        with self.assertRaisesRegex(GodotResolutionError, "HOME is required"):
            resolve_production_godot(self.env)

    def test_relative_xdg_rejected(self) -> None:
        self.env["XDG_DATA_HOME"] = "relative"
        with self.assertRaisesRegex(GodotResolutionError, "absolute path"):
            resolve_production_godot(self.env)

    def test_cli_prints_selected_path(self) -> None:
        self.fake(self.canonical)
        result = self.cli()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.strip(), str(self.canonical))

    def test_cli_failure_has_clear_diagnostic(self) -> None:
        result = self.cli()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Production Godot", result.stderr)
        self.assertIn(str(self.canonical), result.stderr)
        self.assertEqual(result.stdout, "")

    def test_cli_forwards_literal_arguments_and_exit_status(self) -> None:
        self.fake(self.canonical)
        self.canonical.write_text(
            f"#!/bin/sh\nif [ \"$1\" = --version ]; then\nprintf '%s\\n' '{REQUIRED_VERSION}'\nexit 0\nfi\nprintf '%s\\n' \"$@\"\nexit 7\n"
        )
        args = ["space value", "$(touch forbidden)", "--path", "."]
        result = self.cli("--", *args)
        self.assertEqual(result.returncode, 7)
        self.assertEqual(result.stdout.splitlines(), args)
        self.assertFalse((self.root / "forbidden").exists())

    def cli(self, *args: str) -> subprocess.CompletedProcess[str]:
        helper = Path(__file__).resolve().parents[2] / "tools/godot/resolve_godot.py"
        return subprocess.run(
            [sys.executable, "-B", str(helper), *args],
            env={**self.env, "PYTHONDONTWRITEBYTECODE": "1"}, cwd=self.root,
            capture_output=True, text=True, timeout=10,
        )


if __name__ == "__main__":
    unittest.main()
