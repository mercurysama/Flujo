from __future__ import annotations

import tempfile
import unittest
from datetime import UTC, datetime, timedelta
from pathlib import Path
from threading import Event
from unittest.mock import patch

from flow_coordinator import OpenCodeRunResult, OpenCodeRunStatus
from gota_tui.actions import ActionRegistry
from gota_tui.durable import DurableRunStore
from gota_tui.envelope import PromptEnvelope
from gota_tui.execution import ActionExecutor, TUIConfig
from gota_tui.prompt_library import PromptLibrary
from gota_tui.reporting import ReportManager, report_header
from gota_tui.timing import format_duration_ms


class FakeClock:
    def __init__(self) -> None:
        self.nanoseconds = 0
        self.base = datetime(2026, 10, 29, 15, 40, 18, 123456, tzinfo=UTC)

    def monotonic_ns(self) -> int:
        return self.nanoseconds

    def now(self) -> datetime:
        return self.base + timedelta(microseconds=self.nanoseconds // 1_000)

    def advance_ms(self, milliseconds: int) -> None:
        self.nanoseconds += milliseconds * 1_000_000


class TimingWriter:
    def __init__(self, clock: FakeClock | None = None, copy_delay_ms: int = 0) -> None:
        self.clock = clock
        self.copy_delay_ms = copy_delay_ms
        self.copied: list[str] = []

    def copy(self, text: str) -> str:
        self.copied.append(text)
        if self.clock is not None:
            self.clock.advance_ms(self.copy_delay_ms)
        return "fake-clipboard"


class GotaTimingTest(unittest.TestCase):
    def setUp(self) -> None:
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)

    def _run_direct(
        self,
        *,
        status: OpenCodeRunStatus = OpenCodeRunStatus.SUCCEEDED,
        exit_code: int | None = 0,
        elapsed_ms: int = 404,
        process_duration_ms: int | None = 123,
        copy_delay_ms: int = 0,
        runner_error: Exception | None = None,
        run_id: str = "timed-run",
        cancel_event: Event | None = None,
    ) -> tuple[object, DurableRunStore, TimingWriter, FakeClock]:
        clock = FakeClock()
        state = DurableRunStore(self.root / run_id)
        writer = TimingWriter(clock, copy_delay_ms)

        class Runner:
            def __init__(self, **kwargs: object) -> None:
                del kwargs

            def run(self, **kwargs: object) -> OpenCodeRunResult:
                clock.advance_ms(elapsed_ms)
                if runner_error is not None:
                    raise runner_error
                return OpenCodeRunResult(
                    status=status,
                    argv=("opencode", "run", "--auto"),
                    cwd=str(kwargs["cwd"]),
                    stdout="timing stdout\n",
                    stderr="timing stderr\n",
                    exit_code=exit_code,
                    timed_out=status is OpenCodeRunStatus.TIMEOUT,
                    error=None if exit_code == 0 else "injected failure",
                    process_duration_ms=process_duration_ms,
                )

        executor = ActionExecutor(
            config=TUIConfig(
                repository=self.root,
                database=self.root / "coordinator.sqlite3",
                opencode_executable="fake-opencode",
            ),
            runs=state,
            prompts=PromptLibrary.default(),
            clipboard_writer=writer,  # type: ignore[arg-type]
            clock=clock,
        )
        prepared = executor.prepare(
            ActionRegistry.default().get("clipboard-prompt"),
            PromptEnvelope("timing prompt", "timing prompt", False, {}),
            run_id=run_id,
        )
        with (
            patch("gota_tui.coordinator_facade.OpenCodeRunner", Runner),
            patch.object(executor, "_opencode_version", return_value="test-opencode"),
        ):
            result = executor.execute(prepared, cancel_event=cancel_event)
        return result, state, writer, clock

    @staticmethod
    def _fields(report: str) -> dict[str, str]:
        return {
            line.split("=", 1)[0]: line.split("=", 1)[1]
            for line in report_header(report).splitlines()
            if "=" in line
        }

    def test_successful_run_has_timing_fields_and_live_boundaries(self) -> None:
        result, state, writer, _clock = self._run_direct()
        report = state.read_report(result.run_id)
        fields = self._fields(report)

        self.assertEqual(result.verdict, "SUCCEEDED")
        self.assertEqual(fields["STARTED_AT"], "2026-10-29T15:40:18.123456+00:00")
        self.assertEqual(fields["FINISHED_AT"], "2026-10-29T15:40:18.527456+00:00")
        self.assertEqual(fields["DURATION_MS"], "404")
        self.assertEqual(fields["DURATION_HUMAN"], "404ms")
        self.assertEqual(fields["PROCESS_DURATION_MS"], "123")
        self.assertEqual(fields["PROCESS_DURATION_HUMAN"], "123ms")
        self.assertEqual(int(fields["DURATION_MS"]), result.duration_ms)
        self.assertEqual(state.read_report(result.run_id), result.report)
        self.assertIn("Run started: 2026-10-29T15:40:18.123456+00:00", state.paths(result.run_id).live_log.read_text())
        self.assertIn("Run finished: 2026-10-29T15:40:18.527456+00:00", state.paths(result.run_id).live_log.read_text())
        self.assertIn("Duration: 404ms", state.paths(result.run_id).live_log.read_text())
        self.assertEqual(len(writer.copied), 1)

    def test_failed_run_has_timing_fields_and_non_negative_duration(self) -> None:
        result, state, _writer, _clock = self._run_direct(
            status=OpenCodeRunStatus.NON_ZERO_EXIT,
            exit_code=9,
            elapsed_ms=0,
            process_duration_ms=0,
            run_id="failed-timed-run",
        )
        fields = self._fields(state.read_report(result.run_id))

        self.assertEqual(result.verdict, "FAIL")
        self.assertEqual(fields["PROCESS_STATUS"], "non_zero_exit")
        self.assertEqual(fields["DURATION_MS"], "0")
        self.assertGreaterEqual(int(fields["DURATION_MS"]), 0)
        self.assertEqual(fields["PROCESS_DURATION_MS"], "0")

    def test_wall_clock_order_is_observable_and_timestamp_keeps_creation_semantics(self) -> None:
        result, state, _writer, _clock = self._run_direct(run_id="wall-clock-run")
        fields = self._fields(state.read_report(result.run_id))
        started = datetime.fromisoformat(fields["STARTED_AT"])
        finished = datetime.fromisoformat(fields["FINISHED_AT"])
        request = state.request(result.run_id)

        self.assertIsNotNone(started.tzinfo)
        self.assertIsNotNone(finished.tzinfo)
        self.assertGreaterEqual(finished, started)
        self.assertEqual(fields["TIMESTAMP"], request["timestamp"])
        self.assertEqual(request["timestamp"], request["created_at"])
        self.assertNotEqual(fields["TIMESTAMP"], fields["STARTED_AT"])

    def test_human_format_is_deterministic(self) -> None:
        expected = {
            842: "842ms",
            4218: "4.218s",
            72405: "1m 12.405s",
            3788002: "1h 03m 08.002s",
        }
        for milliseconds, human in expected.items():
            with self.subTest(milliseconds=milliseconds):
                self.assertEqual(format_duration_ms(milliseconds), human)

    def test_machine_milliseconds_are_parseable_and_process_is_bounded(self) -> None:
        result, state, _writer, _clock = self._run_direct(
            elapsed_ms=842,
            process_duration_ms=417,
            run_id="machine-timing-run",
        )
        fields = self._fields(state.read_report(result.run_id))

        duration = int(fields["DURATION_MS"])
        process_duration = int(fields["PROCESS_DURATION_MS"])
        self.assertEqual(duration, 842)
        self.assertEqual(process_duration, 417)
        self.assertLessEqual(process_duration, duration)

    def test_report_file_and_clipboard_contain_one_timing_snapshot(self) -> None:
        result, state, writer, _clock = self._run_direct(run_id="transport-timing-run")
        persisted = state.read_report(result.run_id)

        self.assertEqual(writer.copied[0], persisted.replace("CLIPBOARD_COPY=OK", "CLIPBOARD_COPY=PENDING"))
        for text in (persisted, writer.copied[0]):
            self.assertIn("STARTED_AT=", text)
            self.assertIn("FINISHED_AT=", text)
            self.assertIn("DURATION_MS=404", text)
            self.assertIn("DURATION_HUMAN=404ms", text)

    def test_existing_report_header_fields_remain_parseable(self) -> None:
        result, state, _writer, _clock = self._run_direct(run_id="compatible-timing-run")
        fields = self._fields(state.read_report(result.run_id))

        self.assertTrue(state.read_report(result.run_id).startswith("GOTA_REPORT_V1\n"))
        self.assertEqual(fields["RUN_ID"], "compatible-timing-run")
        self.assertEqual(fields["ACTION"], "clipboard-prompt")
        self.assertEqual(fields["VERDICT"], "SUCCEEDED")

    def test_cancellation_path_records_timing_without_starting_runner(self) -> None:
        cancelled = Event()
        cancelled.set()
        result, state, _writer, _clock = self._run_direct(
            elapsed_ms=0,
            process_duration_ms=None,
            run_id="cancelled-timing-run",
            cancel_event=cancelled,
        )
        fields = self._fields(state.read_report(result.run_id))

        self.assertEqual(result.verdict, "UI_CANCELLED")
        self.assertEqual(fields["DURATION_MS"], "0")
        self.assertEqual(fields["PROCESS_DURATION_MS"], "UNKNOWN")
        self.assertEqual(fields["PROCESS_DURATION_HUMAN"], "UNKNOWN")

    def test_timeout_and_transport_exception_paths_record_timing(self) -> None:
        timeout_result, timeout_state, _writer, _clock = self._run_direct(
            status=OpenCodeRunStatus.TIMEOUT,
            exit_code=None,
            elapsed_ms=17,
            process_duration_ms=12,
            run_id="timeout-timing-run",
        )
        exception_result, exception_state, _writer, _clock = self._run_direct(
            elapsed_ms=23,
            process_duration_ms=None,
            runner_error=OSError("transport unavailable"),
            run_id="exception-timing-run",
        )

        self.assertIn("DURATION_MS=17", timeout_state.read_report(timeout_result.run_id))
        self.assertIn("PROCESS_DURATION_MS=12", timeout_state.read_report(timeout_result.run_id))
        self.assertIn("DURATION_MS=23", exception_state.read_report(exception_result.run_id))
        self.assertIn("STARTED_AT=", exception_state.read_report(exception_result.run_id))
        self.assertEqual(exception_result.verdict, "FAIL")

    def test_copy_delay_does_not_change_recorded_duration(self) -> None:
        result, state, writer, clock = self._run_direct(
            elapsed_ms=50,
            process_duration_ms=10,
            copy_delay_ms=10_000,
            run_id="copy-delay-timing-run",
        )
        report = state.read_report(result.run_id)
        self.assertIn("DURATION_MS=50", report)

        clock.advance_ms(20_000)
        ReportManager(state, writer).copy_existing(result.run_id)
        self.assertEqual(state.read_report(result.run_id), report)
        self.assertGreater(clock.nanoseconds, 30_000_000_000)


if __name__ == "__main__":
    unittest.main()
