from __future__ import annotations

import json
import tempfile
import unittest
from pathlib import Path
from typing import Any
from unittest.mock import patch

from flow_coordinator import OpenCodeRunResult, OpenCodeRunStatus
from gota_tui.actions import ActionRegistry
from gota_tui.durable import DurableRunStore
from gota_tui.embedded_report import (
    AMBIGUOUS_EMBEDDED_REPORT,
    EMBEDDED_REPORT_UNCLASSIFIED,
    INCOMPLETE_EMBEDDED_REPORT,
    NO_EMBEDDED_REPORT,
    PROCESS_AND_REPORT_FAIL,
    PROCESS_AND_REPORT_PASS,
    PROCESS_FAIL_REPORT_PASS,
    PROCESS_PASS_REPORT_FAIL,
    parse_embedded_report,
    result_consistency,
)
from gota_tui.envelope import PromptEnvelope
from gota_tui.execution import ActionExecutor, TUIConfig
from gota_tui.prompt_library import PromptLibrary


def _report(report_id: str, status: str, verdict: str) -> str:
    return (
        f"=== {report_id}_REPORT_BEGIN ===\n"
        f"STATUS={status}\n"
        "detail=This is agent output, not an authority\n"
        f"VERDICT={verdict}\n"
        f"=== {report_id}_REPORT_END ===\n"
    )


class GotaTUIResultConsistencyTest(unittest.TestCase):
    def setUp(self) -> None:
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)

    def _run_direct(
        self,
        *,
        stdout: str,
        stderr: str = "",
        status: OpenCodeRunStatus = OpenCodeRunStatus.SUCCEEDED,
        exit_code: int | None = 0,
        prompt: str = "direct prompt",
        run_id: str = "direct-run",
    ) -> tuple[Any, DurableRunStore, Path, list[dict[str, object]]]:
        state = DurableRunStore(self.root / run_id)
        copied: list[dict[str, object]] = []

        class Writer:
            def copy(inner_self, text: str) -> str:
                del text
                copied.append(
                    {
                        "output_exists": prepared.paths.opencode_output.exists(),
                        "output": prepared.paths.opencode_output.read_text(encoding="utf-8"),
                        "report_exists": prepared.paths.report.exists(),
                    }
                )
                return "mock"

        class Runner:
            def __init__(self, **kwargs: object) -> None:
                del kwargs

            def run(self, **kwargs: object) -> OpenCodeRunResult:
                if kwargs.get("expect_gota_payload") is not False:
                    raise AssertionError("direct facade must not require a Gota payload")
                callback = kwargs["output_callback"]
                assert callable(callback)
                callback("stdout", stdout)
                callback("stderr", stderr)
                return OpenCodeRunResult(
                    status=status,
                    argv=("opencode", "run", "--auto", prompt),
                    cwd=str(kwargs["cwd"]),
                    stdout=stdout,
                    stderr=stderr,
                    exit_code=exit_code,
                    timed_out=status is OpenCodeRunStatus.TIMEOUT,
                    error=(None if exit_code == 0 else "injected process failure"),
                )

        writer = Writer()
        executor = ActionExecutor(
            config=TUIConfig(
                repository=self.root,
                database=self.root / "coordinator.sqlite3",
                opencode_executable="fake-opencode",
            ),
            runs=state,
            prompts=PromptLibrary.default(),
            clipboard_writer=writer,  # type: ignore[arg-type]
        )
        action = ActionRegistry.default().get("clipboard-prompt")
        prepared = executor.prepare(
            action,
            PromptEnvelope(prompt, prompt, False, {}),
            run_id=run_id,
        )
        with (
            patch("gota_tui.coordinator_facade.OpenCodeRunner", Runner),
            patch.object(executor, "_opencode_version", return_value="opencode v2.0.32"),
        ):
            result = executor.execute(prepared)
        return result, state, prepared.paths.opencode_output, copied

    def test_process_and_report_pass_are_both_exposed(self) -> None:
        result, state, output_path, _copied = self._run_direct(
            stdout=_report("VIT_001R", "PASA", "PASA"),
            run_id="pass-pass",
        )
        self.assertEqual(result.verdict, "SUCCEEDED")
        report = state.read_report(result.run_id)
        self.assertIn("PROCESS_STATUS=succeeded", report)
        self.assertIn("PROCESS_EXIT_CODE=0", report)
        self.assertIn("EMBEDDED_REPORT_ID=VIT_001R", report)
        self.assertIn("EMBEDDED_STATUS=PASA", report)
        self.assertIn("EMBEDDED_VERDICT=PASA", report)
        self.assertIn("RESULT_CONSISTENCY=PROCESS_AND_REPORT_PASS", report)
        self.assertIn(f"OUTPUT_PATH={output_path}", report)

    def test_process_failure_and_report_pass_never_promotes_verdict(self) -> None:
        result, state, _output_path, _copied = self._run_direct(
            stdout=_report("VIT_001R", "PASA", "PASA"),
            status=OpenCodeRunStatus.NON_ZERO_EXIT,
            exit_code=1,
            run_id="process-fail-report-pass",
        )
        self.assertEqual(result.verdict, "FAIL")
        self.assertEqual(result.result_consistency, PROCESS_FAIL_REPORT_PASS)
        report = state.read_report(result.run_id)
        self.assertIn("VERDICT=FAIL", report)
        self.assertIn("PROCESS_STATUS=non_zero_exit", report)
        self.assertIn("PROCESS_EXIT_CODE=1", report)
        self.assertIn("RESULT_CONSISTENCY=PROCESS_FAIL_REPORT_PASS", report)
        self.assertIn(
            "Process failed, but the embedded task report declared PASS. Manual review required.",
            report,
        )

    def test_process_pass_report_fail_is_visible_without_overwriting_process_verdict(self) -> None:
        result, state, _output_path, _copied = self._run_direct(
            stdout=_report("VIT_001R", "NO PASA", "NO PASA"),
            run_id="process-pass-report-fail",
        )
        self.assertEqual(result.verdict, "SUCCEEDED")
        self.assertEqual(result.result_consistency, PROCESS_PASS_REPORT_FAIL)
        self.assertIn("RESULT_CONSISTENCY=PROCESS_PASS_REPORT_FAIL", state.read_report(result.run_id))

    def test_process_and_report_fail_are_distinguished_from_a_missing_report(self) -> None:
        result, state, _output_path, _copied = self._run_direct(
            stdout=_report("VIT_001R", "FAIL", "FAIL"),
            status=OpenCodeRunStatus.NON_ZERO_EXIT,
            exit_code=1,
            run_id="fail-fail",
        )
        self.assertEqual(result.verdict, "FAIL")
        self.assertEqual(result.result_consistency, PROCESS_AND_REPORT_FAIL)
        self.assertIn("RESULT_CONSISTENCY=PROCESS_AND_REPORT_FAIL", state.read_report(result.run_id))

    def test_incomplete_and_undelimited_reports_are_not_accepted(self) -> None:
        incomplete = parse_embedded_report("=== VIT_001R_REPORT_BEGIN ===\nVERDICT=PASA\n")
        self.assertTrue(incomplete.incomplete)
        self.assertEqual(
            result_consistency(
                process_status="invalid_payload",
                process_exit_code=0,
                parsed=incomplete,
            ),
            INCOMPLETE_EMBEDDED_REPORT,
        )
        loose = parse_embedded_report("VERDICT=PASA\nPASS is only arbitrary text\n")
        self.assertFalse(loose.marker_seen)
        self.assertEqual(
            result_consistency(
                process_status="invalid_payload",
                process_exit_code=0,
                parsed=loose,
            ),
            NO_EMBEDDED_REPORT,
        )

    def test_multiple_complete_reports_are_ambiguous_even_when_identical(self) -> None:
        parsed = parse_embedded_report(
            _report("DUPLICATE", "PASA", "PASA")
            + _report("DUPLICATE", "PASA", "PASA")
        )
        self.assertTrue(parsed.ambiguous)
        self.assertIsNone(parsed.report)
        self.assertEqual(
            result_consistency(
                process_status="invalid_payload",
                process_exit_code=0,
                parsed=parsed,
            ),
            AMBIGUOUS_EMBEDDED_REPORT,
        )

    def test_duplicate_status_or_verdict_is_ambiguous_even_when_identical(self) -> None:
        for duplicate_field in ("STATUS", "VERDICT"):
            with self.subTest(duplicate_field=duplicate_field):
                report = _report("DUPLICATE", "PASA", "PASA")
                report = report.replace(
                    f"{duplicate_field}=PASA\n",
                    f"{duplicate_field}=PASA\n{duplicate_field}=PASA\n",
                )
                parsed = parse_embedded_report(report)
                self.assertTrue(parsed.ambiguous)
                self.assertIsNotNone(parsed.report)
                assert parsed.report is not None
                self.assertEqual(parsed.report.status, "PASA")
                self.assertEqual(parsed.report.verdict, "PASA")
                self.assertEqual(
                    result_consistency(
                        process_status="invalid_payload",
                        process_exit_code=0,
                        parsed=parsed,
                    ),
                    AMBIGUOUS_EMBEDDED_REPORT,
                )

    def test_ambiguous_report_never_overrides_process_failure(self) -> None:
        result, _state, _output_path, _copied = self._run_direct(
            stdout=_report("DUPLICATE", "PASA", "PASA").replace(
                "STATUS=PASA\n", "STATUS=PASA\nSTATUS=PASA\n"
            ),
            status=OpenCodeRunStatus.NON_ZERO_EXIT,
            exit_code=1,
            run_id="ambiguous-process-failure",
        )
        self.assertEqual(result.verdict, "FAIL")
        self.assertEqual(result.result_consistency, AMBIGUOUS_EMBEDDED_REPORT)

    def test_prompt_only_fake_report_is_not_input_to_parser(self) -> None:
        prompt = _report("FAKE", "PASA", "PASA")
        result, state, _output_path, _copied = self._run_direct(
            prompt=prompt,
            stdout="Agent did not emit a report.\n",
            run_id="prompt-fake",
        )
        self.assertEqual(result.result_consistency, NO_EMBEDDED_REPORT)
        self.assertIn("RESULT_CONSISTENCY=NO_EMBEDDED_REPORT", state.read_report(result.run_id))
        self.assertNotIn("EMBEDDED_REPORT_ID=FAKE", state.read_report(result.run_id))

    def test_stdout_wins_over_stderr_diagnostics_for_embedded_report(self) -> None:
        result, state, output_path, _copied = self._run_direct(
            stdout=_report("STDOUT", "PASA", "PASA"),
            stderr=_report("STDERR", "FAIL", "FAIL"),
            run_id="stdout-only",
        )
        report = state.read_report(result.run_id)
        self.assertEqual(result.result_consistency, PROCESS_AND_REPORT_PASS)
        self.assertIn("EMBEDDED_REPORT_ID=STDOUT", report)
        self.assertNotIn("EMBEDDED_REPORT_ID=STDERR", report)
        self.assertIn("STDERR_REPORT_BEGIN", output_path.read_text(encoding="utf-8"))

    def test_complete_unknown_verdict_does_not_infer_from_partial_words(self) -> None:
        parsed = parse_embedded_report(_report("UNKNOWN", "the word PASS is not a verdict", "maybe PASS"))
        self.assertIsNotNone(parsed.report)
        assert parsed.report is not None
        self.assertIsNone(parsed.report.classification)
        self.assertEqual(
            result_consistency(
                process_status="invalid_payload",
                process_exit_code=0,
                parsed=parsed,
            ),
            EMBEDDED_REPORT_UNCLASSIFIED,
        )

    def test_direct_output_is_redacted_and_exists_before_copy(self) -> None:
        repository = self.root / "repository"
        repository.mkdir()
        secret = "FAKE_DIRECT_SERVICE_PASSWORD_123456"
        service_directory = repository / ".opencode"
        service_directory.mkdir()
        (service_directory / "service.json").write_text(
            json.dumps({"password": secret}), encoding="utf-8"
        )
        state = DurableRunStore(self.root / "redaction")
        copied: list[bool] = []

        class Writer:
            def copy(self, text: str) -> str:
                del text
                copied.append(prepared.paths.opencode_output.exists())
                return "mock"

        class Runner:
            def __init__(self, **kwargs: object) -> None:
                del kwargs

            def run(self, **kwargs: object) -> OpenCodeRunResult:
                callback = kwargs["output_callback"]
                assert callable(callback)
                stdout = _report("SECRET", "PASA", "PASA").replace(
                    "detail=This is agent output, not an authority",
                    f"detail=password={secret}",
                )
                stderr = f"Authorization: Bearer {secret}\n"
                callback("stdout", stdout)
                callback("stderr", stderr)
                return OpenCodeRunResult(
                    status=OpenCodeRunStatus.SUCCEEDED,
                    argv=("opencode", "run"),
                    cwd=str(kwargs["cwd"]),
                    stdout=stdout,
                    stderr=stderr,
                    exit_code=0,
                    timed_out=False,
                )

        writer = Writer()
        executor = ActionExecutor(
            config=TUIConfig(
                repository=repository,
                database=self.root / "coordinator.sqlite3",
                opencode_executable="fake-opencode",
            ),
            runs=state,
            prompts=PromptLibrary.default(),
            clipboard_writer=writer,  # type: ignore[arg-type]
        )
        prepared = executor.prepare(
            ActionRegistry.default().get("clipboard-prompt"),
            PromptEnvelope("secret prompt", "secret prompt", False, {}),
            run_id="secret-direct",
        )
        with (
            patch("gota_tui.coordinator_facade.OpenCodeRunner", Runner),
            patch.object(executor, "_opencode_version", return_value="opencode v2.0.32"),
        ):
            result = executor.execute(prepared)

        self.assertEqual(copied, [True])
        for path in (
            prepared.paths.live_log,
            prepared.paths.opencode_output,
            prepared.paths.report,
            prepared.paths.result,
        ):
            content = path.read_text(encoding="utf-8")
            self.assertNotIn(secret, content, path)
        for path in (prepared.paths.live_log, prepared.paths.opencode_output, prepared.paths.result):
            self.assertIn("[REDACTED]", path.read_text(encoding="utf-8"), path)
        persisted = json.loads(prepared.paths.result.read_text(encoding="utf-8"))
        self.assertEqual(persisted["process_exit_code"], 0)
        self.assertTrue(prepared.paths.opencode_output.exists())
        self.assertEqual(result.result_consistency, PROCESS_AND_REPORT_PASS)


if __name__ == "__main__":
    unittest.main()
