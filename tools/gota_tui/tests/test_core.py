from __future__ import annotations

import hashlib
import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from typing import Any
from unittest.mock import patch

from gota_tui.actions import ActionRegistry, ActionRegistryError
from gota_tui.clipboard import (
    ClipboardCommandError,
    ClipboardReader,
    ClipboardWriter,
)
from gota_tui.durable import DurableRunStore
from gota_tui.envelope import PromptEnvelope, PromptEnvelopeError
from gota_tui.execution import ActionExecutor, ExecutionError, TUIConfig
from flow_coordinator import OpenCodeRunResult, OpenCodeRunStatus
from gota_tui.prompt_library import PromptLibrary
from gota_tui.reporting import ReportData, ReportManager, render_report


class FakeClipboard:
    def __init__(self, *, fail: bool = False) -> None:
        self.calls: list[tuple[list[str], dict[str, Any]]] = []
        self.fail = fail

    def run(self, argv: list[str], **kwargs: Any) -> subprocess.CompletedProcess[bytes]:
        self.calls.append((argv, kwargs))
        if self.fail:
            raise subprocess.CalledProcessError(1, argv, stderr=b"no clipboard")
        if argv[0] == "wl-paste":
            return subprocess.CompletedProcess(argv, 0, stdout="Prompt 🌧️\n".encode(), stderr=b"")
        return subprocess.CompletedProcess(argv, 0, stdout=b"", stderr=b"")


class GotaTUICoreTest(unittest.TestCase):
    def setUp(self) -> None:
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.state = DurableRunStore(self.root / "state")

    def _prepare(self, *, prompt: str = "assignment 🌧️", run_id: str = "run-1"):
        return self.state.prepare(
            action_id="audit-readonly",
            model="",
            variant="",
            agent="",
            repository=str(self.root),
            prompt=prompt,
            prompt_sha256=hashlib.sha256(prompt.encode()).hexdigest(),
            template={"id": "read-only-v1", "version": 1},
            envelope={},
            run_id=run_id,
        )

    def test_action_registry_has_initial_actions_and_rejects_invalid_backend(self) -> None:
        registry = ActionRegistry.default()
        self.assertEqual(
            {action.id for action in registry},
            {
                "execute-task",
                "clipboard-prompt",
                "review",
                "audit-readonly",
                "revalidate-production",
                "run-tests",
                "diagnostics",
                "recovery",
                "status",
                "history",
            },
        )
        self.assertTrue(registry.get("execute-task").requires_confirmation)
        direct = registry.get("clipboard-prompt")
        self.assertEqual(direct.backend, "opencode-direct")
        self.assertEqual(direct.model + "#" + direct.variant, "openai/gpt-5.6-luna#max")
        self.assertEqual(direct.agent, "build")
        self.assertFalse(direct.requires_confirmation)
        with self.assertRaises(ActionRegistryError):
            ActionRegistry.from_mapping(
                {
                    "version": 1,
                    "actions": [
                        {
                            "id": "bad",
                            "label": "Bad",
                            "backend": "arbitrary-shell",
                            "mutable": False,
                            "requires_prompt": False,
                            "requires_confirmation": False,
                            "agent": "",
                            "model": "",
                            "variant": "",
                            "template": "",
                            "description": "bad",
                        }
                    ],
                }
            )
        with self.assertRaises(ActionRegistryError):
            ActionRegistry.from_mapping(
                {
                    "version": 1,
                    "actions": [
                        {
                            "id": "misclassified",
                            "label": "Misclassified",
                            "backend": "gota-task",
                            "mutable": False,
                            "requires_prompt": True,
                            "requires_confirmation": False,
                            "agent": "gota-worker",
                            "model": "model",
                            "variant": "max",
                            "template": "gota-worker-v1",
                            "description": "bad",
                        }
                    ],
                }
            )

    def test_empty_prompt_rejected_unicode_and_sha_are_stable(self) -> None:
        with self.assertRaises(PromptEnvelopeError):
            PromptEnvelope.parse(" \n\t")
        prompt = "línea 🌧️\nsegunda"
        envelope = PromptEnvelope.parse(prompt)
        self.assertEqual(envelope.assignment, prompt)
        self.assertEqual(
            envelope.prompt_sha256,
            hashlib.sha256(prompt.encode("utf-8")).hexdigest(),
        )
        self.assertEqual(envelope.prompt_sha256, PromptEnvelope.parse(prompt).prompt_sha256)

    def test_plain_prompt_and_missing_mutable_scope_fail_closed(self) -> None:
        with self.assertRaises(PromptEnvelopeError):
            PromptEnvelope.parse("$(touch must-not-run)").require_mutable_fields()
        structured = "+++\nversion = 1\ntask_id = 'task'\n+++\nassignment"
        with self.assertRaises(PromptEnvelopeError):
            PromptEnvelope.parse(structured).require_mutable_fields()
        self.assertEqual(PromptEnvelope.parse("$(touch must-not-run)").assignment, "$(touch must-not-run)")

        relative_workspace = (
            "+++\n"
            "version = 1\n"
            "task_id = 'task'\n"
            "title = 'Task'\n"
            "project_id = 'project'\n"
            "repository_id = 'repo'\n"
            "workspace = 'relative'\n"
            "branch = 'feature/task'\n"
            "base_sha = '0123456789abcdef0123456789abcdef01234567'\n"
            "context_id = 'context'\n"
            "allowed_paths = ['src/change.py']\n"
            "protected_paths = ['protected.txt']\n"
            "acceptance_criteria = ['tests pass']\n"
            "commit_message = 'feat: task'\n"
            "attempt = 1\n"
            "+++\n"
            "assignment\n"
        )
        with self.assertRaises(PromptEnvelopeError):
            PromptEnvelope.parse(relative_workspace).require_mutable_fields()

    def test_versioned_envelope_preserves_data_and_requires_scope(self) -> None:
        envelope = PromptEnvelope.parse(
            "+++\n"
            "version = 1\n"
            "task_id = 'task-1'\n"
            "title = 'Task'\n"
            "project_id = 'project'\n"
            "repository_id = 'repo'\n"
            f"workspace = '{self.root}'\n"
            "branch = 'feature/task'\n"
            "base_sha = '0123456789abcdef0123456789abcdef01234567'\n"
            "context_id = 'context'\n"
            "allowed_paths = ['src/change.py']\n"
            "protected_paths = ['protected.txt']\n"
            "acceptance_criteria = ['tests pass']\n"
            "commit_message = 'feat: task'\n"
            "attempt = 1\n"
            "template_id = 'gota-worker-v1'\n"
            "+++\n"
            "Implement this Unicode assignment 🌧️\n"
        )
        envelope.require_mutable_fields()
        spec = envelope.to_task_spec("combined objective")
        self.assertEqual(spec.allowed_paths, ("src/change.py",))
        self.assertEqual(envelope.assignment, "Implement this Unicode assignment 🌧️\n")

    def test_durable_prompt_is_complete_before_spawn_and_unicode_survives(self) -> None:
        paths = self._prepare()
        spawn_observation: list[str] = []

        def fake_spawn() -> None:
            spawn_observation.append(paths.prompt.read_text(encoding="utf-8"))

        fake_spawn()
        self.assertEqual(spawn_observation, ["assignment 🌧️"])
        self.assertEqual(paths.prompt_sha.read_text(encoding="utf-8").strip(), hashlib.sha256("assignment 🌧️".encode()).hexdigest())
        self.assertTrue(paths.live_log.exists())

    def test_history_reload_marks_only_ui_interruption_and_tolerates_truncated_tail(self) -> None:
        self._prepare(run_id="before-crash")
        with self.state.history_path.open("ab") as file:
            file.write(b'{"run_id":"truncated"')
        reloaded = DurableRunStore(self.state.root)
        self.assertEqual(reloaded.recover_interrupted(), ("before-crash",))
        records = reloaded.history_records()
        record = next(item for item in records if item["run_id"] == "before-crash")
        self.assertEqual(record["ui_state"], "UI_INTERRUPTED")
        self.assertEqual(reloaded.read_prompt("before-crash"), "assignment 🌧️")
        self.assertFalse(reloaded.paths("before-crash").result.exists())

    def test_clipboard_reader_uses_exact_argv_and_preserves_unicode(self) -> None:
        fake = FakeClipboard()
        reader = ClipboardReader(
            which=lambda name: "/usr/bin/" + name,
            run=fake.run,
        )
        self.assertEqual(reader.read(), "Prompt 🌧️\n")
        argv, kwargs = fake.calls[0]
        self.assertEqual(argv, ["wl-paste", "--no-newline"])
        self.assertFalse(kwargs["shell"])

    def test_clipboard_writer_mock_and_failure_do_not_touch_report_verdict(self) -> None:
        fake = FakeClipboard()
        writer = ClipboardWriter(which=lambda name: "/usr/bin/" + name, run=fake.run)
        self.assertEqual(writer.copy("reporte 🌧️"), "wayland")
        argv, kwargs = fake.calls[0]
        self.assertEqual(argv, ["wl-copy"])
        self.assertEqual(kwargs["input"], "reporte 🌧️".encode())

        failing = FakeClipboard(fail=True)
        failing_writer = ClipboardWriter(which=lambda name: "/usr/bin/" + name, run=failing.run)
        with self.assertRaises(ClipboardCommandError):
            failing_writer.copy("retained")

    def test_report_exists_before_copy_and_final_report_is_compact(self) -> None:
        paths = self._prepare(run_id="report-run")
        observed: list[bool] = []

        class Writer:
            def copy(self, text: str) -> str:
                observed.append(paths.report.exists())
                self.text = text
                return "mock"

        report = ReportManager(self.state, Writer()).persist_before_copy(
            ReportData(
                run_id="report-run",
                action="audit-readonly",
                prompt_sha256="a" * 64,
                verdict="READ_ONLY_OK",
                findings=[{"id": "F1", "severity": "low", "description": "small"}],
            )
        )
        self.assertEqual(observed, [True])
        self.assertEqual(report.clipboard_status, "OK")
        persisted = self.state.read_report("report-run")
        self.assertIn("VERDICT=READ_ONLY_OK", persisted)
        self.assertIn("CLIPBOARD_COPY=OK", persisted)
        self.assertLess(len(persisted), 2000)
        self.assertNotIn("test line 999", persisted)

    def test_history_report_can_be_copied_again(self) -> None:
        self._prepare(run_id="copy-again")
        self.state.persist_report("copy-again", "GOTA_REPORT_V1\nVERDICT=OK\n")
        copied: list[str] = []

        class Writer:
            def copy(self, text: str) -> str:
                copied.append(text)
                return "mock"

        backend = ReportManager(self.state, Writer()).copy_existing("copy-again")
        self.assertEqual(backend, "mock")
        self.assertEqual(copied, ["GOTA_REPORT_V1\nVERDICT=OK\n"])

    def test_registered_read_only_execution_persists_result_and_report(self) -> None:
        class Writer:
            def copy(self, text: str) -> str:
                return "mock"

        action = ActionRegistry.default().get("diagnostics")
        executor = ActionExecutor(
            config=TUIConfig(
                repository=self.root,
                database=self.root / "coordinator.sqlite3",
                opencode_executable=sys.executable,
            ),
            runs=self.state,
            prompts=PromptLibrary.default(),
            clipboard_writer=Writer(),
        )
        prepared = executor.prepare(action, PromptEnvelope("", "", False, {}))
        result = executor.execute(prepared)

        self.assertEqual(result.verdict, "READ_ONLY_OK")
        self.assertTrue(prepared.paths.result.exists())
        self.assertEqual(self.state.read_report(result.run_id), result.report)
        self.assertEqual(result.report_path, str(prepared.paths.report))

    def test_direct_clipboard_execution_reuses_runner_and_persists_before_start(self) -> None:
        prompt = "Responde únicamente: GOTA_CLIPBOARD_DIRECT_OK"
        writer_observations: list[bool] = []
        runner_observations: list[dict[str, object]] = []

        class Writer:
            def copy(self, text: str) -> str:
                writer_observations.append(self.report_path.exists())
                self.copied = text
                return "mock"

            report_path: Path
            copied: str = ""

        writer = Writer()

        class Runner:
            def __init__(self, *, executable: str, model: str, variant: str) -> None:
                runner_observations.append(
                    {"executable": executable, "model": model, "variant": variant}
                )

            def run(self, *, agent: str, prompt: str, cwd: Path, timeout: float, output_callback: Any, cancel_event: Any) -> OpenCodeRunResult:
                del timeout, cancel_event
                paths = prepared.paths
                runner_observations.append(
                    {
                        "agent": agent,
                        "prompt": prompt,
                        "cwd": cwd,
                        "persisted": paths.prompt.exists()
                        and paths.prompt_sha.exists()
                        and paths.request.exists()
                        and paths.live_log.exists(),
                    }
                )
                output_callback("stdout", "stdout direct\n")
                output_callback("stderr", "stderr direct\n")
                return OpenCodeRunResult(
                    status=OpenCodeRunStatus.INVALID_PAYLOAD,
                    argv=("opencode", "run", "--auto", prompt),
                    cwd=str(cwd),
                    stdout="stdout direct\n",
                    stderr="stderr direct\n",
                    exit_code=0,
                    timed_out=False,
                    error="response was not Coordinator protocol",
                )

        action = ActionRegistry.default().get("clipboard-prompt")
        executor = ActionExecutor(
            config=TUIConfig(
                repository=self.root,
                database=self.root / "coordinator.sqlite3",
                opencode_executable="opencode",
            ),
            runs=self.state,
            prompts=PromptLibrary.default(),
            clipboard_writer=writer,
        )
        prepared = executor.prepare(action, PromptEnvelope.parse(prompt), run_id="direct-run")
        writer.report_path = prepared.paths.report

        with patch("gota_tui.coordinator_facade.OpenCodeRunner", Runner):
            result = executor.execute(prepared)

        self.assertEqual(result.verdict, "SUCCEEDED")
        self.assertEqual(runner_observations[0]["model"] + "#" + runner_observations[0]["variant"], "openai/gpt-5.6-luna#max")
        self.assertEqual(runner_observations[1]["agent"], "build")
        self.assertEqual(runner_observations[1]["prompt"], prompt)
        self.assertTrue(runner_observations[1]["persisted"])
        live_log = prepared.paths.live_log.read_text(encoding="utf-8")
        self.assertIn("[STDOUT] stdout direct", live_log)
        self.assertIn("[STDERR] stderr direct", live_log)
        report = self.state.read_report("direct-run")
        for line in (
            "ACTION=clipboard-prompt",
            "TASK_ID=NOT_APPLICABLE",
            "CONTEXT_ID=NOT_APPLICABLE",
            "COORDINATOR_STATE=NOT_APPLICABLE",
            "WORKER_RESULT=NOT_APPLICABLE",
            "REVIEW_RESULT=NOT_APPLICABLE",
            "MODEL=openai/gpt-5.6-luna",
            "VARIANT=max",
            "AGENT=build",
            "VERDICT=SUCCEEDED",
        ):
            self.assertIn(line, report)
        self.assertEqual(writer_observations, [True])
        self.assertNotIn("PREVIEW_ONLY", report)
        self.assertEqual(self.state.history_records()[0]["ui_state"], "COMPLETED")

    def test_direct_empty_prompt_never_starts_runner(self) -> None:
        action = ActionRegistry.default().get("clipboard-prompt")
        executor = ActionExecutor(
            config=TUIConfig(
                repository=self.root,
                database=self.root / "coordinator.sqlite3",
            ),
            runs=self.state,
            prompts=PromptLibrary.default(),
            clipboard_writer=ClipboardWriter(which=lambda _: None),
        )
        with self.assertRaisesRegex(ExecutionError, "non-empty prompt"):
            executor.prepare(action, PromptEnvelope(" \n", " \n", False, {}))

    def test_direct_start_failure_and_timeout_are_failures_not_preview(self) -> None:
        from unittest.mock import patch

        action = ActionRegistry.default().get("clipboard-prompt")

        class Writer:
            def copy(self, text: str) -> str:
                return "mock"

        class Runner:
            status = OpenCodeRunStatus.START_FAILED

            def __init__(self, *, executable: str, model: str, variant: str) -> None:
                del executable, model, variant

            def run(self, **kwargs: Any) -> OpenCodeRunResult:
                prompt = kwargs["prompt"]
                cwd = kwargs["cwd"]
                return OpenCodeRunResult(
                    status=self.status,
                    argv=("opencode", "run", "--auto", prompt),
                    cwd=str(cwd),
                    stdout="",
                    stderr="failed",
                    exit_code=None,
                    timed_out=self.status is OpenCodeRunStatus.TIMEOUT,
                    error="injected failure",
                )

        for status, expected in (
            (OpenCodeRunStatus.START_FAILED, "FAIL"),
            (OpenCodeRunStatus.TIMEOUT, "FAIL/TIMEOUT"),
        ):
            with self.subTest(status=status):
                Runner.status = status
                state = DurableRunStore(self.root / f"state-{status.value}")
                executor = ActionExecutor(
                    config=TUIConfig(
                        repository=self.root,
                        database=self.root / "coordinator.sqlite3",
                        opencode_executable=sys.executable,
                    ),
                    runs=state,
                    prompts=PromptLibrary.default(),
                    clipboard_writer=Writer(),
                )
                prepared = executor.prepare(
                    action,
                    PromptEnvelope.parse("failure prompt"),
                    run_id=f"failure-{status.value}",
                )
                with patch("gota_tui.coordinator_facade.OpenCodeRunner", Runner):
                    result = executor.execute(prepared)
                self.assertEqual(result.verdict, expected)
                self.assertNotIn("PREVIEW_ONLY", state.read_report(result.run_id))

    def test_direct_report_captures_final_git_head(self) -> None:
        action = ActionRegistry.default().get("clipboard-prompt")

        class Writer:
            def copy(self, text: str) -> str:
                return "mock"

        class Runner:
            def __init__(self, *, executable: str, model: str, variant: str) -> None:
                del executable, model, variant

            def run(self, **kwargs: Any) -> OpenCodeRunResult:
                callback = kwargs["output_callback"]
                callback("stdout", "no commit\n")
                return OpenCodeRunResult(
                    status=OpenCodeRunStatus.INVALID_PAYLOAD,
                    argv=("opencode", "run"),
                    cwd=str(kwargs["cwd"]),
                    stdout="no commit\n",
                    stderr="",
                    exit_code=0,
                    timed_out=False,
                )

        class Git:
            heads = iter(("base-head", "final-head"))

            def __init__(self, repository: Path) -> None:
                del repository

            def head(self) -> str:
                return next(self.heads)

        state = DurableRunStore(self.root / "git-state")
        executor = ActionExecutor(
            config=TUIConfig(
                repository=self.root,
                database=self.root / "coordinator.sqlite3",
                opencode_executable=sys.executable,
            ),
            runs=state,
            prompts=PromptLibrary.default(),
            clipboard_writer=Writer(),
        )
        prepared = executor.prepare(
            action,
            PromptEnvelope.parse("capture git head"),
            run_id="git-head-run",
        )
        with patch("gota_tui.coordinator_facade.OpenCodeRunner", Runner), patch(
            "gota_tui.execution.ReadOnlyGitAdapter", Git
        ):
            result = executor.execute(prepared)
        report = state.read_report(result.run_id)
        self.assertIn("BASE_SHA=base-head", report)
        self.assertIn("COMMIT_SHA=final-head", report)

    def test_shell_like_prompt_is_data_and_no_new_tui_source_uses_shell_true(self) -> None:
        prompt = "$(touch /tmp/not-created); source evil.sh\nUnicode 🌧️"
        self.assertEqual(PromptEnvelope.parse(prompt).assignment, prompt)
        for path in Path("tools/gota_tui").rglob("*.py"):
            if "tests" not in path.parts:
                self.assertNotIn("shell=True", path.read_text(encoding="utf-8"))

    def test_action_registry_mutable_actions_require_confirmation(self) -> None:
        for action in ActionRegistry.default():
            if action.mutable:
                self.assertTrue(action.requires_confirmation)

    def test_launcher_clipboard_argument_is_direct_without_action_selection(self) -> None:
        from gota_tui.cli import build_parser

        options = build_parser().parse_args(["clipboard"])
        self.assertEqual(options.command, "clipboard")
        self.assertFalse(hasattr(options, "action"))


if __name__ == "__main__":
    unittest.main()
