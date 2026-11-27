from __future__ import annotations

import tempfile
import unittest
from pathlib import Path

from gota_tui.durable import DurableRunStore
from gota_tui.reporting import (
    OPENCODE_STDOUT_BEGIN,
    OPENCODE_STDOUT_END,
    OUTPUT_EMBED_STATUS_EMPTY,
    OUTPUT_EMBED_STATUS_NO_STDOUT_BLOCK,
    OUTPUT_EMBED_STATUS_OK,
    OUTPUT_EMBED_STATUS_UNAVAILABLE,
    ReportData,
    ReportManager,
    extract_opencode_stdout,
    render_report,
    report_header,
)


def _output_artifact(stdout: str, stderr: str = "diagnostic trace") -> str:
    return (
        "STDOUT_BEGIN\n"
        + stdout
        + "\nSTDOUT_END\n"
        + "STDERR_BEGIN\n"
        + stderr
        + "\nSTDERR_END\n"
    )


class GotaReportingOutputTest(unittest.TestCase):
    def setUp(self) -> None:
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)

    def _write_output(self, stdout: str, stderr: str = "diagnostic trace") -> Path:
        path = self.root / "opencode-output.txt"
        path.write_bytes(_output_artifact(stdout, stderr).encode("utf-8"))
        return path

    @staticmethod
    def _data(path: Path | None) -> ReportData:
        return ReportData(
            run_id="report-run",
            action="clipboard-prompt",
            output_path=str(path) if path is not None else None,
            result_consistency="NO_EMBEDDED_REPORT",
            process_status="succeeded",
            process_exit_code=0,
            verdict="SUCCEEDED",
        )

    def test_successful_extraction_preserves_unicode_markdown_and_key_values(self) -> None:
        stdout = (
            "D3 COMPLETE — PROVE PASS — READY FOR D4\n"
            "\n"
            "```python\n"
            "print('emoji 🌊')\n"
            "```\n"
            "RESULT_CONSISTENCY=PROCESS_FAIL_REPORT_PASS\n"
        )
        path = self._write_output(stdout, "RID teardown and tool trace")

        embedding = extract_opencode_stdout(path)

        self.assertEqual(embedding.status, OUTPUT_EMBED_STATUS_OK)
        self.assertEqual(embedding.text, stdout)
        self.assertEqual(embedding.byte_count, len(stdout.encode("utf-8")))
        report = render_report(self._data(path))
        self.assertIn("OUTPUT_EMBED_STATUS=OK", report)
        self.assertIn("OUTPUT_EMBED_SOURCE=OPENCODE_STDOUT", report)
        self.assertIn(
            f"OUTPUT_EMBED_BYTES={len(stdout.encode('utf-8'))}",
            report,
        )
        self.assertIn(f"{OPENCODE_STDOUT_BEGIN}\n{stdout}{OPENCODE_STDOUT_END}", report)
        self.assertNotIn("RID teardown and tool trace", report)
        self.assertIn("RESULT_CONSISTENCY=NO_EMBEDDED_REPORT", report_header(report))
        self.assertNotIn("RESULT_CONSISTENCY=PROCESS_FAIL_REPORT_PASS", report_header(report))

    def test_stdout_is_not_truncated(self) -> None:
        stdout = "".join(f"line-{index:05d} 🌧️\n" for index in range(2500))
        path = self._write_output(stdout)

        embedding = extract_opencode_stdout(path)

        self.assertEqual(embedding.status, OUTPUT_EMBED_STATUS_OK)
        self.assertEqual(embedding.text, stdout)
        self.assertEqual(embedding.byte_count, len(stdout.encode("utf-8")))

    def test_line_endings_are_preserved_exactly(self) -> None:
        stdout = "first line\r\nsecond line\r\n"
        path = self._write_output(stdout)

        embedding = extract_opencode_stdout(path)

        self.assertEqual(embedding.text, stdout)
        self.assertEqual(embedding.byte_count, len(stdout.encode("utf-8")))

    def test_crlf_framing_does_not_change_crlf_stdout(self) -> None:
        stdout = "first line\r\nsecond line\r\n"
        path = self.root / "crlf-opencode-output.txt"
        path.write_bytes(
            (
                "STDOUT_BEGIN\r\n"
                + stdout
                + "\r\nSTDOUT_END\r\n"
                + "STDERR_BEGIN\r\ntrace\r\nSTDERR_END\r\n"
            ).encode("utf-8")
        )

        embedding = extract_opencode_stdout(path)

        self.assertEqual(embedding.text, stdout)

    def test_empty_stdout_has_a_distinct_state_and_empty_body(self) -> None:
        path = self._write_output("", "stderr remains diagnostic only")

        embedding = extract_opencode_stdout(path)
        report = render_report(self._data(path))

        self.assertEqual(embedding.status, OUTPUT_EMBED_STATUS_EMPTY)
        self.assertEqual(embedding.text, "")
        self.assertEqual(embedding.byte_count, 0)
        self.assertIn(
            f"{OPENCODE_STDOUT_BEGIN}\n{OPENCODE_STDOUT_END}",
            report,
        )
        self.assertNotIn("stderr remains diagnostic only", report)

    def test_missing_stdout_markers_do_not_invent_a_body(self) -> None:
        for content in (
            "STDERR_BEGIN\nonly stderr\nSTDERR_END\n",
            "STDOUT_BEGIN\npartial stdout\n",
            "ordinary output without framing\n",
        ):
            with self.subTest(content=content):
                path = self.root / "missing-markers.txt"
                path.write_text(content, encoding="utf-8")
                embedding = extract_opencode_stdout(path)
                report = render_report(self._data(path))

                self.assertEqual(embedding.status, OUTPUT_EMBED_STATUS_NO_STDOUT_BLOCK)
                self.assertIsNone(embedding.text)
                self.assertIsNone(embedding.byte_count)
                self.assertIn("OUTPUT_EMBED_STATUS=NO_STDOUT_BLOCK", report)
                self.assertNotIn(OPENCODE_STDOUT_BEGIN, report)
                self.assertNotIn("partial stdout", report)

    def test_unavailable_output_is_reported_without_failing_render(self) -> None:
        missing = self.root / "does-not-exist.txt"
        invalid_utf8 = self.root / "invalid-utf8.txt"
        invalid_utf8.write_bytes(b"\xff\xfe")

        for output_path in (missing, invalid_utf8, None):
            with self.subTest(output_path=output_path):
                embedding = extract_opencode_stdout(output_path)
                report = render_report(self._data(output_path))

                self.assertEqual(embedding.status, OUTPUT_EMBED_STATUS_UNAVAILABLE)
                self.assertIsNone(embedding.text)
                self.assertIsNone(embedding.byte_count)
                self.assertIn("OUTPUT_EMBED_STATUS=UNAVAILABLE", report)
                self.assertNotIn(OPENCODE_STDOUT_BEGIN, report)

    def test_report_file_and_clipboard_share_the_same_embedded_stdout(self) -> None:
        state = DurableRunStore(self.root / "state")
        prompt = "prompt"
        paths = state.prepare(
            action_id="clipboard-prompt",
            model="model",
            variant="variant",
            agent="build",
            repository=str(self.root),
            prompt=prompt,
            prompt_sha256="sha",
            template={},
            envelope={},
            run_id="report-manager-run",
            opencode_output=True,
        )
        stdout = "D3 COMPLETE — PROVE PASS — READY FOR D4\ncheck=value\n"
        state.persist_opencode_output(paths.run_id, stdout, "large irrelevant diagnostic trace")
        copied: list[str] = []

        class Writer:
            def copy(self, text: str) -> str:
                copied.append(text)
                return "mock"

        persisted = ReportManager(state, Writer()).persist_before_copy(
            ReportData(
                run_id=paths.run_id,
                action="clipboard-prompt",
                output_path=str(paths.opencode_output),
                result_consistency="NO_EMBEDDED_REPORT",
                process_status="succeeded",
                process_exit_code=0,
                verdict="SUCCEEDED",
            )
        )
        report_file = state.read_report(paths.run_id)

        self.assertEqual(len(copied), 1)
        for report in (persisted.text, report_file, copied[0]):
            self.assertIn("RESULT_CONSISTENCY=NO_EMBEDDED_REPORT", report)
            self.assertIn("OUTPUT_EMBED_STATUS=OK", report)
            self.assertIn(stdout, report)
            self.assertNotIn("large irrelevant diagnostic trace", report)
        self.assertEqual(report_file, persisted.text)
        self.assertIn("CLIPBOARD_COPY=PENDING", copied[0])
        self.assertIn("CLIPBOARD_COPY=OK", report_file)


if __name__ == "__main__":
    unittest.main()
