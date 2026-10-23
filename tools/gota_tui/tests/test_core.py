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
from flow_coordinator.git_adapter import GitSnapshot
from gota_tui.prompt_library import PromptLibrary
from gota_tui.read_only_agent import ReadOnlyAgentError
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
                "audit-opencode",
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
        git_audit = registry.get("audit-readonly")
        self.assertEqual(git_audit.label, "Read-only Git audit")
        audit = registry.get("audit-opencode")
        self.assertEqual(audit.label, "Read-only OpenCode audit")
        self.assertEqual(audit.backend, "opencode-readonly")
        self.assertTrue(audit.requires_prompt)
        self.assertTrue(audit.requires_confirmation)
        self.assertFalse(audit.mutable)
        self.assertEqual(audit.model + "#" + audit.variant, "openai/gpt-5.6-luna#max")
        self.assertEqual(audit.agent, "gota-auditor")
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

    def test_opencode_audit_reuses_runner_durable_prompt_and_persists_evidence(self) -> None:
        prompt = "audit $(not-shell)\nFINDINGS_BEGIN\nFINDINGS_END"
        repository = Path(__file__).resolve().parents[3]
        state = DurableRunStore(self.root / "opencode-audit-state")
        runner_calls: list[dict[str, object]] = []
        copy_observations: list[bool] = []
        head = "a" * 40

        class Writer:
            report_path: Path

            def copy(self, text: str) -> str:
                del text
                copy_observations.append(self.report_path.exists())
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
                assert callable(output_callback)
                output_callback("stdout", "real finding\nFINDINGS_BEGIN\nimportant\nFINDINGS_END\n")  # type: ignore[operator]
                output_callback("stderr", "read-only diagnostic\n")  # type: ignore[operator]
                runner_calls.append(
                    {
                        "agent": agent,
                        "prompt": prompt,
                        "cwd": cwd,
                        "argv": (
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
                    }
                )
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
                    stdout="real finding\nFINDINGS_BEGIN\nimportant\nFINDINGS_END\n",
                    stderr="read-only diagnostic\n",
                    exit_code=0,
                    timed_out=False,
                    error="generic output is not a Gota payload",
                )

        class Git:
            def __init__(self, root: Path) -> None:
                self.root = root

            def snapshot(self) -> GitSnapshot:
                return GitSnapshot(
                    repository=str(self.root),
                    head=head,
                    branch="feature/audit",
                    status="",
                    refs=(("refs/heads/feature/audit", head, ""),),
                )

        writer = Writer()
        executor = ActionExecutor(
            config=TUIConfig(
                repository=repository,
                database=self.root / "coordinator.sqlite3",
                opencode_executable="fake-opencode",
                timeout=37.0,
            ),
            runs=state,
            prompts=PromptLibrary.default(),
            clipboard_writer=writer,
        )
        action = ActionRegistry.default().get("audit-opencode")
        prepared = executor.prepare(
            action,
            PromptEnvelope.parse(prompt),
            run_id="opencode-audit-run",
        )
        writer.report_path = prepared.paths.report

        with patch("gota_tui.coordinator_facade.OpenCodeRunner", Runner), patch(
            "gota_tui.execution.ReadOnlyGitAdapter", Git
        ), patch.object(ActionExecutor, "_opencode_version", return_value="opencode v2.0.32"):
            result = executor.execute(prepared)

        self.assertEqual(result.verdict, "READ_ONLY_OK")
        self.assertEqual(copy_observations, [True])
        self.assertEqual(runner_calls[0]["model"], "openai/gpt-5.6-luna")
        self.assertEqual(runner_calls[0]["variant"], "max")
        self.assertEqual(runner_calls[1]["agent"], "gota-auditor")
        self.assertEqual(runner_calls[1]["prompt"], prompt)
        self.assertEqual(runner_calls[1]["cwd"], repository)
        self.assertEqual(runner_calls[1]["argv"][4], "openai/gpt-5.6-luna#max")
        self.assertTrue(prepared.paths.prompt.exists())
        self.assertIn("[STDOUT] real finding", prepared.paths.live_log.read_text(encoding="utf-8"))
        self.assertIn("[STDERR] read-only diagnostic", prepared.paths.live_log.read_text(encoding="utf-8"))
        self.assertIn("FINDINGS_BEGIN\nimportant\nFINDINGS_END", prepared.paths.opencode_output.read_text(encoding="utf-8"))
        report = state.read_report(result.run_id)
        for line in (
            "ACTION=audit-opencode",
            "MODEL=openai/gpt-5.6-luna",
            "VARIANT=max",
            "OPENCODE_VERSION=opencode v2.0.32",
            "AGENT=gota-auditor",
            "COORDINATOR_STATE=READ_ONLY",
            "TASK_ID=NOT_APPLICABLE",
            "CONTEXT_ID=NOT_APPLICABLE",
            "WORKER_RESULT=NOT_APPLICABLE",
            "REVIEW_RESULT=NOT_APPLICABLE",
            "UNEXPECTED_MUTATION_GUARD=PASS",
            "VERDICT=READ_ONLY_OK",
        ):
            self.assertIn(line, report)
        request = json.loads(prepared.paths.request.read_text(encoding="utf-8"))
        stored_result = json.loads(prepared.paths.result.read_text(encoding="utf-8"))
        self.assertEqual(request["timeout"], 37.0)
        self.assertEqual(request["opencode_version"], "opencode v2.0.32")
        self.assertEqual(stored_result["action_id"], "audit-opencode")
        self.assertEqual(stored_result["model"], "openai/gpt-5.6-luna")
        self.assertEqual(stored_result["variant"], "max")
        self.assertEqual(stored_result["opencode_version"], "opencode v2.0.32")
        self.assertEqual(stored_result["timeout"], 37.0)
        self.assertEqual(stored_result["clipboard_copy"], "OK")

    def test_opencode_audit_failure_and_unexpected_git_mutation_fail_closed(self) -> None:
        repository = Path(__file__).resolve().parents[3]
        action = ActionRegistry.default().get("audit-opencode")
        head = "b" * 40

        class Writer:
            def copy(self, text: str) -> str:
                del text
                return "mock"

        class Runner:
            status = OpenCodeRunStatus.NON_ZERO_EXIT

            def __init__(self, *, executable: str, model: str, variant: str) -> None:
                del executable, model, variant

            def run(self, **kwargs: object) -> OpenCodeRunResult:
                callback = kwargs["output_callback"]
                assert callable(callback)
                callback("stderr", "OpenCode failed\n")  # type: ignore[operator]
                return OpenCodeRunResult(
                    status=self.status,
                    argv=("opencode", "run", "--standalone"),
                    cwd=str(kwargs["cwd"]),
                    stdout="",
                    stderr="OpenCode failed\n",
                    exit_code=9,
                    timed_out=False,
                    error="process exited with code 9",
                )

        class Git:
            snapshots: list[GitSnapshot] = []

            def __init__(self, root: Path) -> None:
                self.root = root

            def snapshot(self) -> GitSnapshot:
                return self.snapshots.pop(0)

        def snapshot(root: Path, value: str) -> GitSnapshot:
            return GitSnapshot(
                repository=str(root),
                head=value,
                branch="feature/audit",
                status="",
                refs=(("refs/heads/feature/audit", value, ""),),
            )

        for status, expected in (
            (OpenCodeRunStatus.NON_ZERO_EXIT, "FAIL"),
            (OpenCodeRunStatus.INVALID_PAYLOAD, "FAIL"),
        ):
            with self.subTest(status=status):
                state = DurableRunStore(self.root / f"audit-failure-{status.value}")
                executor = ActionExecutor(
                    config=TUIConfig(
                        repository=repository,
                        database=self.root / "coordinator.sqlite3",
                        opencode_executable="fake-opencode",
                    ),
                    runs=state,
                    prompts=PromptLibrary.default(),
                    clipboard_writer=Writer(),
                )
                prepared = executor.prepare(
                    action,
                    PromptEnvelope.parse("failure audit"),
                    run_id=f"failure-{status.value}",
                )
                Runner.status = status
                Git.snapshots = [snapshot(repository, head), snapshot(repository, head)]
                with patch("gota_tui.coordinator_facade.OpenCodeRunner", Runner), patch(
                    "gota_tui.execution.ReadOnlyGitAdapter", Git
                ), patch.object(ActionExecutor, "_opencode_version", return_value="opencode v2.0.32"):
                    result = executor.execute(prepared)
                self.assertEqual(result.verdict, expected)
                self.assertNotIn("READ_ONLY_OK", state.read_report(result.run_id))

        state = DurableRunStore(self.root / "audit-mutation")
        executor = ActionExecutor(
            config=TUIConfig(
                repository=repository,
                database=self.root / "coordinator.sqlite3",
                opencode_executable="fake-opencode",
            ),
            runs=state,
            prompts=PromptLibrary.default(),
            clipboard_writer=Writer(),
        )
        prepared = executor.prepare(action, PromptEnvelope.parse("mutation audit"), run_id="mutation-audit")
        Git.snapshots = [snapshot(repository, head), snapshot(repository, "c" * 40)]
        Runner.status = OpenCodeRunStatus.INVALID_PAYLOAD
        with patch("gota_tui.coordinator_facade.OpenCodeRunner", Runner), patch(
            "gota_tui.execution.ReadOnlyGitAdapter", Git
        ), patch.object(ActionExecutor, "_opencode_version", return_value="opencode v2.0.32"):
            result = executor.execute(prepared)
        self.assertEqual(result.verdict, "FAIL")
        self.assertIn("HEAD changed", state.read_report(result.run_id))
        self.assertNotIn("READ_ONLY_OK", state.read_report(result.run_id))

    def test_opencode_output_redacts_local_service_credentials_from_durable_artifacts(self) -> None:
        repository = self.root / "repository"
        repository.mkdir()
        secret = "FAKE_TUI_SERVICE_PASSWORD_123456"
        service_directory = repository / ".opencode"
        service_directory.mkdir()
        (service_directory / "service.json").write_text(
            json.dumps({"password": secret}),
            encoding="utf-8",
        )
        state = DurableRunStore(self.root / "redaction-state")
        action = ActionRegistry.default().get("audit-opencode")
        output = f"password={secret}\n"
        error_output = f"Authorization: Bearer {secret}\n"

        class Writer:
            def copy(self, text: str) -> str:
                del text
                return "mock"

        class Runner:
            def __init__(self, **kwargs: object) -> None:
                del kwargs

            def run(self, **kwargs: object) -> OpenCodeRunResult:
                callback = kwargs["output_callback"]
                assert callable(callback)
                callback("stdout", output)  # type: ignore[operator]
                callback("stderr", error_output)  # type: ignore[operator]
                return OpenCodeRunResult(
                    status=OpenCodeRunStatus.INVALID_PAYLOAD,
                    argv=("opencode", "run"),
                    cwd=str(kwargs["cwd"]),
                    stdout=output,
                    stderr=error_output,
                    exit_code=0,
                    timed_out=False,
                    error="generic output",
                )

        class Git:
            def __init__(self, root: Path) -> None:
                self.root = root

            def snapshot(self) -> GitSnapshot:
                return GitSnapshot(
                    repository=str(self.root),
                    head="a" * 40,
                    branch="feature/audit",
                    status="",
                    refs=(("refs/heads/feature/audit", "a" * 40, ""),),
                )

        executor = ActionExecutor(
            config=TUIConfig(
                repository=repository,
                database=self.root / "coordinator.sqlite3",
                opencode_executable="fake-opencode",
            ),
            runs=state,
            prompts=PromptLibrary.default(),
            clipboard_writer=Writer(),
        )
        prepared = executor.prepare(
            action,
            PromptEnvelope.parse("redact local output"),
            run_id="redaction-run",
        )

        with patch("gota_tui.coordinator_facade.OpenCodeRunner", Runner), patch(
            "gota_tui.execution.ReadOnlyGitAdapter", Git
        ), patch.object(ActionExecutor, "_opencode_version", return_value="opencode v2.0.32"):
            result = executor.execute(prepared)

        self.assertEqual(result.verdict, "READ_ONLY_OK")
        for path in (
            prepared.paths.live_log,
            prepared.paths.opencode_output,
            prepared.paths.report,
            prepared.paths.result,
        ):
            content = path.read_text(encoding="utf-8")
            self.assertNotIn(secret, content, path)
            self.assertIn("[REDACTED]", content, path)

    def test_opencode_audit_missing_prompt_invalid_model_and_policy_never_start_runner(self) -> None:
        repository = Path(__file__).resolve().parents[3]
        action = ActionRegistry.default().get("audit-opencode")

        class Writer:
            def copy(self, text: str) -> str:
                return "mock"

        class NeverRunner:
            def __init__(self, **kwargs: object) -> None:
                raise AssertionError(f"runner must not start: {kwargs}")

        state = DurableRunStore(self.root / "missing-prompt")
        executor = ActionExecutor(
            config=TUIConfig(
                repository=repository,
                database=self.root / "coordinator.sqlite3",
                opencode_executable="fake-opencode",
            ),
            runs=state,
            prompts=PromptLibrary.default(),
            clipboard_writer=Writer(),
        )
        prepared = executor.prepare(action, PromptEnvelope.parse("durable prompt"), run_id="missing-prompt")
        prepared.paths.prompt.unlink()
        with patch("gota_tui.coordinator_facade.OpenCodeRunner", NeverRunner):
            result = executor.execute(prepared)
        self.assertEqual(result.verdict, "FAIL")
        self.assertNotIn("READ_ONLY_OK", state.read_report(result.run_id))

        with self.assertRaises(ExecutionError):
            ActionExecutor(
                config=TUIConfig(
                    repository=repository,
                    database=self.root / "coordinator.sqlite3",
                    model_override="invalid model",
                ),
                runs=DurableRunStore(self.root / "invalid-model"),
                prompts=PromptLibrary.default(),
                clipboard_writer=Writer(),
            ).prepare(action, PromptEnvelope.parse("prompt"), run_id="invalid-model")

        with patch(
            "gota_tui.execution.validate_read_only_agent",
            side_effect=ReadOnlyAgentError("incoherent read-only policy"),
        ):
            with self.assertRaises(ExecutionError):
                ActionExecutor(
                    config=TUIConfig(
                        repository=repository,
                        database=self.root / "coordinator.sqlite3",
                    ),
                    runs=DurableRunStore(self.root / "invalid-policy"),
                    prompts=PromptLibrary.default(),
                    clipboard_writer=Writer(),
                ).prepare(action, PromptEnvelope.parse("prompt"), run_id="invalid-policy")

    def test_existing_git_audit_remains_local_and_model_free(self) -> None:
        repository = Path(__file__).resolve().parents[3]
        state = DurableRunStore(self.root / "git-audit")
        action = ActionRegistry.default().get("audit-readonly")
        head = "d" * 40

        class Writer:
            def copy(self, text: str) -> str:
                del text
                return "mock"

        class Git:
            def __init__(self, root: Path) -> None:
                self.root = root

            def snapshot(self) -> GitSnapshot:
                return GitSnapshot(str(self.root), head, "feature/audit", "", ())

        executor = ActionExecutor(
            config=TUIConfig(
                repository=repository,
                database=self.root / "coordinator.sqlite3",
                opencode_executable="must-not-run",
            ),
            runs=state,
            prompts=PromptLibrary.default(),
            clipboard_writer=Writer(),
        )
        prepared = executor.prepare(action, PromptEnvelope.parse("local audit"), run_id="git-audit")
        with patch("gota_tui.execution.ReadOnlyGitAdapter", Git), patch.object(
            ActionExecutor, "_opencode_version", side_effect=AssertionError("Git audit must not query OpenCode")
        ):
            result = executor.execute(prepared)
        self.assertEqual(result.verdict, "READ_ONLY_OK")
        report = state.read_report(result.run_id)
        self.assertIn("ACTION=audit-readonly", report)
        self.assertIn("MODEL=NOT_APPLICABLE", report)
        self.assertIn("OPENCODE_VERSION=NOT_APPLICABLE", report)

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

    def test_opencode_audit_reuses_runner_durable_prompt_and_persists_report_before_copy(self) -> None:
        from unittest.mock import patch

        repository = Path(__file__).resolve().parents[3]
        prompt = "Audit $(not-shell) and preserve AUDIT_BEGIN/AUDIT_END."
        output = "AUDIT_BEGIN\nreal finding 🌧️\nAUDIT_END\n"
        snapshots = [
            GitSnapshot(str(repository), "a" * 40, "feature/audit", "", (("refs/heads/feature/audit", "a" * 40, ""),)),
            GitSnapshot(str(repository), "a" * 40, "feature/audit", "", (("refs/heads/feature/audit", "a" * 40, ""),)),
        ]
        runner_calls: list[dict[str, object]] = []
        copied_after_report: list[bool] = []

        class Writer:
            report_path: Path

            def copy(self, text: str) -> str:
                del text
                copied_after_report.append(self.report_path.exists())
                return "mock"

        writer = Writer()

        class Git:
            def __init__(self, path: Path) -> None:
                self.path = path

            def snapshot(self) -> GitSnapshot:
                return snapshots.pop(0)

        class Runner:
            def __init__(self, *, executable: str, model: str, variant: str) -> None:
                runner_calls.append(
                    {"executable": executable, "model": model, "variant": variant}
                )

            def run(self, **kwargs: object) -> OpenCodeRunResult:
                callback = kwargs["output_callback"]
                assert callable(callback)
                callback("stdout", output)
                callback("stderr", "audit diagnostic\n")
                runner_calls.append(
                    {
                        "agent": kwargs["agent"],
                        "prompt": kwargs["prompt"],
                        "cwd": kwargs["cwd"],
                    }
                )
                return OpenCodeRunResult(
                    status=OpenCodeRunStatus.INVALID_PAYLOAD,
                    argv=(
                        "opencode",
                        "run",
                        "--standalone",
                        "--model",
                        "openai/gpt-5.6-luna#max",
                        "--agent",
                        "gota-auditor",
                        "--auto",
                        prompt,
                    ),
                    cwd=str(repository),
                    stdout=output,
                    stderr="audit diagnostic\n",
                    exit_code=0,
                    timed_out=False,
                    error="generic response",
                )

        state = DurableRunStore(self.root / "audit-state")
        executor = ActionExecutor(
            config=TUIConfig(
                repository=repository,
                database=self.root / "coordinator.sqlite3",
                opencode_executable="opencode",
                timeout=17.0,
            ),
            runs=state,
            prompts=PromptLibrary.default(),
            clipboard_writer=writer,
        )
        prepared = executor.prepare(
            ActionRegistry.default().get("audit-opencode"),
            PromptEnvelope.parse(prompt),
            run_id="opencode-audit",
        )
        writer.report_path = prepared.paths.report

        with (
            patch("gota_tui.coordinator_facade.OpenCodeRunner", Runner),
            patch("gota_tui.execution.ReadOnlyGitAdapter", Git),
            patch.object(executor, "_opencode_version", return_value="opencode v2.0.32"),
        ):
            result = executor.execute(prepared)

        self.assertEqual(result.verdict, "READ_ONLY_OK")
        self.assertEqual(runner_calls[0]["model"], "openai/gpt-5.6-luna")
        self.assertEqual(runner_calls[0]["variant"], "max")
        self.assertEqual(runner_calls[1]["agent"], "gota-auditor")
        self.assertEqual(runner_calls[1]["prompt"], prompt)
        self.assertEqual(runner_calls[1]["cwd"], repository)
        self.assertEqual(copied_after_report, [True])
        live_log = prepared.paths.live_log.read_text(encoding="utf-8")
        self.assertIn("real finding 🌧️", live_log)
        self.assertIn("audit diagnostic", live_log)
        self.assertIn(output, prepared.paths.opencode_output.read_text(encoding="utf-8"))
        report = state.read_report(result.run_id)
        for line in (
            "ACTION=audit-opencode",
            "MODEL=openai/gpt-5.6-luna",
            "VARIANT=max",
            "OPENCODE_VERSION=opencode v2.0.32",
            "AGENT=gota-auditor",
            "COORDINATOR_STATE=READ_ONLY",
            "TASK_ID=NOT_APPLICABLE",
            "CONTEXT_ID=NOT_APPLICABLE",
            "WORKER_RESULT=NOT_APPLICABLE",
            "REVIEW_RESULT=NOT_APPLICABLE",
            "UNEXPECTED_MUTATION_GUARD=PASS",
            "VERDICT=READ_ONLY_OK",
        ):
            self.assertIn(line, report)
        request = json.loads(prepared.paths.request.read_text(encoding="utf-8"))
        persisted_result = json.loads(prepared.paths.result.read_text(encoding="utf-8"))
        for payload in (request, persisted_result):
            self.assertEqual(payload["run_id"], "opencode-audit")
            self.assertEqual(payload["action_id"], "audit-opencode")
            self.assertEqual(payload["prompt_sha256"], hashlib.sha256(prompt.encode()).hexdigest())
            self.assertEqual(payload["model"], "openai/gpt-5.6-luna")
            self.assertEqual(payload["variant"], "max")
            self.assertEqual(payload["agent"], "gota-auditor")
            self.assertEqual(payload["repository"], str(repository))
            self.assertEqual(payload["timeout"], 17.0)
        self.assertEqual(persisted_result["opencode_version"], "opencode v2.0.32")
        self.assertEqual(persisted_result["clipboard_copy"], "OK")

    def test_opencode_audit_failures_and_git_mutation_never_report_read_only_ok(self) -> None:
        from unittest.mock import patch

        repository = Path(__file__).resolve().parents[3]
        action = ActionRegistry.default().get("audit-opencode")

        class Writer:
            def copy(self, text: str) -> str:
                del text
                return "mock"

        class Runner:
            status = OpenCodeRunStatus.NON_ZERO_EXIT

            def __init__(self, **kwargs: object) -> None:
                del kwargs

            def run(self, **kwargs: object) -> OpenCodeRunResult:
                return OpenCodeRunResult(
                    status=self.status,
                    argv=("opencode", "run"),
                    cwd=str(kwargs["cwd"]),
                    stdout="failure output\n",
                    stderr="OpenCode failed\n",
                    exit_code=9,
                    timed_out=False,
                    error="injected failure",
                )

        class Git:
            snapshots: list[GitSnapshot] = []

            def __init__(self, path: Path) -> None:
                del path

            def snapshot(self) -> GitSnapshot:
                return self.snapshots.pop(0)

        for name, snapshots, status, expected in (
            (
                "audit-failure",
                [
                    GitSnapshot(str(repository), "b" * 40, "feature/audit", "", ()),
                    GitSnapshot(str(repository), "b" * 40, "feature/audit", "", ()),
                ],
                OpenCodeRunStatus.NON_ZERO_EXIT,
                "FAIL",
            ),
            (
                "audit-mutation",
                [
                    GitSnapshot(str(repository), "c" * 40, "feature/audit", "", ()),
                    GitSnapshot(str(repository), "d" * 40, "feature/audit", "", ()),
                ],
                OpenCodeRunStatus.INVALID_PAYLOAD,
                "FAIL",
            ),
        ):
            with self.subTest(name=name):
                state = DurableRunStore(self.root / name)
                executor = ActionExecutor(
                    config=TUIConfig(
                        repository=repository,
                        database=self.root / "coordinator.sqlite3",
                        opencode_executable="opencode",
                    ),
                    runs=state,
                    prompts=PromptLibrary.default(),
                    clipboard_writer=Writer(),
                )
                prepared = executor.prepare(
                    action,
                    PromptEnvelope.parse("read only audit"),
                    run_id=name,
                )
                Git.snapshots = list(snapshots)
                Runner.status = status
                with (
                    patch("gota_tui.coordinator_facade.OpenCodeRunner", Runner),
                    patch("gota_tui.execution.ReadOnlyGitAdapter", Git),
                    patch.object(executor, "_opencode_version", return_value="opencode v2.0.32"),
                ):
                    result = executor.execute(prepared)
                self.assertEqual(result.verdict, expected)
                self.assertNotIn("VERDICT=READ_ONLY_OK", state.read_report(name))

    def test_opencode_audit_fails_closed_before_runner_for_missing_prompt_or_invalid_model(self) -> None:
        from unittest.mock import patch

        action = ActionRegistry.default().get("audit-opencode")
        with self.assertRaises(ExecutionError):
            ActionExecutor(
                config=TUIConfig(
                    repository=Path(__file__).resolve().parents[3],
                    database=self.root / "coordinator.sqlite3",
                    model_override="invalid model",
                ),
                runs=self.state,
                prompts=PromptLibrary.default(),
                clipboard_writer=ClipboardWriter(which=lambda _: None),
            ).prepare(action, PromptEnvelope.parse("audit"))

        class Runner:
            def __init__(self, **kwargs: object) -> None:
                raise AssertionError("runner must not start without durable prompt")

        executor = ActionExecutor(
            config=TUIConfig(
                repository=Path(__file__).resolve().parents[3],
                database=self.root / "coordinator.sqlite3",
                opencode_executable="opencode",
            ),
            runs=self.state,
            prompts=PromptLibrary.default(),
            clipboard_writer=ClipboardWriter(which=lambda _: None),
        )
        prepared = executor.prepare(action, PromptEnvelope.parse("audit"), run_id="missing-prompt")
        prepared.paths.prompt.unlink()
        with patch("gota_tui.coordinator_facade.OpenCodeRunner", Runner):
            result = executor.execute(prepared)
        self.assertEqual(result.verdict, "FAIL")

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
