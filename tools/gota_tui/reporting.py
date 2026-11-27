"""Stable reports intended for pasting into ChatGPT."""

from __future__ import annotations

import json
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any, Iterable, Mapping

from .clipboard import ClipboardError, ClipboardWriter
from .durable import DurableRunStore
from .timing import format_duration_ms
from flow_coordinator.sensitive_output import redact_sensitive_text


OUTPUT_EMBED_STATUS_OK = "OK"
OUTPUT_EMBED_STATUS_EMPTY = "EMPTY"
OUTPUT_EMBED_STATUS_NO_STDOUT_BLOCK = "NO_STDOUT_BLOCK"
OUTPUT_EMBED_STATUS_UNAVAILABLE = "UNAVAILABLE"
OUTPUT_EMBED_SOURCE = "OPENCODE_STDOUT"
OPENCODE_STDOUT_BEGIN = "GOTA_OPENCODE_STDOUT_BEGIN"
OPENCODE_STDOUT_END = "GOTA_OPENCODE_STDOUT_END"


def _value(value: object) -> str:
    if value is None or value == "":
        return "UNKNOWN"
    return redact_sensitive_text(str(value)).replace("\r", " ").replace("\n", " ").strip()


def _findings(value: Iterable[Mapping[str, Any]] | None) -> str:
    if value is None:
        return "[]"
    compact: list[dict[str, str]] = []
    for finding in value:
        compact.append(
            {
                key: _value(finding.get(key))
                for key in ("id", "severity", "description", "path", "required_change")
                if finding.get(key) is not None
            }
        )
        if len(compact) >= 12:
            break
    return json.dumps(compact, ensure_ascii=False, separators=(",", ":"))


def _duration_human(value: object) -> str:
    if isinstance(value, bool) or not isinstance(value, int) or value < 0:
        return "UNKNOWN"
    return format_duration_ms(value)


def _duration_ms(value: object) -> int | None:
    if isinstance(value, bool) or not isinstance(value, int) or value < 0:
        return None
    return value


@dataclass(frozen=True, slots=True)
class OpenCodeStdoutEmbedding:
    """The report-safe projection of the durable OpenCode stdout artifact."""

    status: str
    text: str | None
    byte_count: int | None
    source: str = OUTPUT_EMBED_SOURCE


def _unavailable_stdout_embedding() -> OpenCodeStdoutEmbedding:
    return OpenCodeStdoutEmbedding(
        status=OUTPUT_EMBED_STATUS_UNAVAILABLE,
        text=None,
        byte_count=None,
    )


def extract_opencode_stdout(
    output_path: str | Path | None,
) -> OpenCodeStdoutEmbedding:
    """Extract only the complete stdout block from ``OUTPUT_PATH``.

    ``DurableRunStore.persist_opencode_output`` writes one framing newline
    before ``STDOUT_END``. Removing that one framing character recovers the
    original stdout exactly, including any newline that stdout itself ended
    with. The stderr block is never consulted.
    """

    if output_path is None or not str(output_path).strip():
        return _unavailable_stdout_embedding()
    try:
        output_text = Path(output_path).read_bytes().decode("utf-8")
        lines = output_text.splitlines(keepends=True)
    except (OSError, TypeError, UnicodeError, ValueError):
        return _unavailable_stdout_embedding()

    begin_index: int | None = None
    for index, line in enumerate(lines):
        if line.rstrip("\r\n") == "STDOUT_BEGIN":
            begin_index = index
            break
    if begin_index is None:
        return OpenCodeStdoutEmbedding(
            status=OUTPUT_EMBED_STATUS_NO_STDOUT_BLOCK,
            text=None,
            byte_count=None,
        )

    end_index: int | None = None
    for index in range(begin_index + 1, len(lines)):
        if lines[index].rstrip("\r\n") == "STDOUT_END":
            end_index = index
            break
    if end_index is None:
        return OpenCodeStdoutEmbedding(
            status=OUTPUT_EMBED_STATUS_NO_STDOUT_BLOCK,
            text=None,
            byte_count=None,
        )

    stdout = "".join(lines[begin_index + 1 : end_index])
    # The durable wrapper adds one separator matching the BEGIN line ending,
    # even when stdout already ends in a newline. Remove only that framing
    # separator; all prior text is part of stdout and must remain byte-for-byte
    # faithful after UTF-8 encode.
    begin_line = lines[begin_index]
    begin_ending = begin_line[len("STDOUT_BEGIN") :]
    framing_ending = (
        "\r\n"
        if begin_ending.endswith("\r\n")
        else "\r"
        if begin_ending.endswith("\r")
        else "\n"
    )
    if stdout.endswith(framing_ending):
        stdout = stdout[: -len(framing_ending)]
    status = OUTPUT_EMBED_STATUS_EMPTY if stdout == "" else OUTPUT_EMBED_STATUS_OK
    return OpenCodeStdoutEmbedding(
        status=status,
        text=stdout,
        byte_count=len(stdout.encode("utf-8")),
    )


def report_header(report: str) -> str:
    """Return the key/value section without the optional multiline body."""

    if type(report) is not str:
        raise TypeError("Report text must be a string")
    body_marker = f"\n\n{OPENCODE_STDOUT_BEGIN}\n"
    return report.split(body_marker, 1)[0]


@dataclass(slots=True)
class ReportData:
    run_id: str
    action: str
    task_id: str | None = None
    context_id: str | None = None
    model: str | None = None
    variant: str | None = None
    opencode_version: str | None = None
    agent: str | None = None
    role: str | None = None
    model_source: str | None = None
    variant_source: str | None = None
    role_source: str | None = None
    agent_source: str | None = None
    repository: str | None = None
    base_sha: str | None = None
    commit_sha: str | None = None
    coordinator_state: str | None = None
    worker_result: str | None = None
    review_result: str | None = None
    tests: str | None = None
    diff_check: str | None = None
    prompt_sha256: str | None = None
    report_path: str | None = None
    log_path: str | None = None
    output_path: str | None = None
    timestamp: str | None = None
    started_at: str | None = None
    finished_at: str | None = None
    duration_ms: int | None = None
    process_duration_ms: int | None = None
    timeout: float | None = None
    readonly_policy: str | None = None
    mutation_guard: str | None = None
    process_status: str | None = None
    process_exit_code: int | None = None
    embedded_report_id: str | None = None
    embedded_status: str | None = None
    embedded_verdict: str | None = None
    result_consistency: str = "NO_EMBEDDED_REPORT"
    clipboard_copy: str = "NOT_ATTEMPTED"
    findings: list[Mapping[str, Any]] = field(default_factory=list)
    verdict: str = "UNKNOWN"
    diagnostic: str | None = None


def render_report(
    data: ReportData,
    *,
    stdout_embedding: OpenCodeStdoutEmbedding | None = None,
) -> str:
    embedding = stdout_embedding or extract_opencode_stdout(data.output_path)
    duration_ms = _duration_ms(data.duration_ms)
    process_duration_ms = _duration_ms(data.process_duration_ms)
    if (
        process_duration_ms is not None
        and duration_ms is not None
        and process_duration_ms > duration_ms
    ):
        process_duration_ms = None
    lines = [
        "GOTA_REPORT_V1",
        f"RUN_ID={_value(data.run_id)}",
        f"ACTION={_value(data.action)}",
        f"TASK_ID={_value(data.task_id)}",
        f"CONTEXT_ID={_value(data.context_id)}",
        f"MODEL={_value(data.model)}",
        f"VARIANT={_value(data.variant)}",
        f"OPENCODE_VERSION={_value(data.opencode_version)}",
        f"AGENT={_value(data.agent)}",
        f"ROLE={_value(data.role)}",
        f"MODEL_SOURCE={_value(data.model_source)}",
        f"VARIANT_SOURCE={_value(data.variant_source)}",
        f"ROLE_SOURCE={_value(data.role_source)}",
        f"AGENT_SOURCE={_value(data.agent_source)}",
        f"REPOSITORY={_value(data.repository)}",
        f"BASE_SHA={_value(data.base_sha)}",
        f"COMMIT_SHA={_value(data.commit_sha)}",
        f"COORDINATOR_STATE={_value(data.coordinator_state)}",
        f"WORKER_RESULT={_value(data.worker_result)}",
        f"REVIEW_RESULT={_value(data.review_result)}",
        f"TESTS={_value(data.tests)}",
        f"DIFF_CHECK={_value(data.diff_check)}",
        f"PROMPT_SHA256={_value(data.prompt_sha256)}",
        f"REPORT_PATH={_value(data.report_path)}",
        f"LOG_PATH={_value(data.log_path)}",
        f"OUTPUT_PATH={_value(data.output_path)}",
        f"TIMESTAMP={_value(data.timestamp)}",
        f"STARTED_AT={_value(data.started_at)}",
        f"FINISHED_AT={_value(data.finished_at)}",
        f"DURATION_MS={_value(duration_ms)}",
        f"DURATION_HUMAN={_duration_human(duration_ms)}",
        f"PROCESS_DURATION_MS={_value(process_duration_ms)}",
        f"PROCESS_DURATION_HUMAN={_duration_human(process_duration_ms)}",
        f"TIMEOUT={_value(data.timeout)}",
        f"READONLY_POLICY={_value(data.readonly_policy)}",
        f"UNEXPECTED_MUTATION_GUARD={_value(data.mutation_guard)}",
        f"PROCESS_STATUS={_value(data.process_status)}",
        f"PROCESS_EXIT_CODE={_value(data.process_exit_code)}",
        f"EMBEDDED_REPORT_ID={_value(data.embedded_report_id)}",
        f"EMBEDDED_STATUS={_value(data.embedded_status)}",
        f"EMBEDDED_VERDICT={_value(data.embedded_verdict)}",
        f"RESULT_CONSISTENCY={_value(data.result_consistency)}",
        f"CLIPBOARD_COPY={_value(data.clipboard_copy)}",
        f"FINDINGS={_findings(data.findings)}",
        f"DIAGNOSTIC={_value(data.diagnostic)}",
        f"VERDICT={_value(data.verdict)}",
        f"OUTPUT_EMBED_STATUS={_value(embedding.status)}",
        f"OUTPUT_EMBED_SOURCE={_value(embedding.source)}",
        f"OUTPUT_EMBED_BYTES={_value(embedding.byte_count)}",
    ]
    report = "\n".join(lines) + "\n"
    if embedding.status in {OUTPUT_EMBED_STATUS_OK, OUTPUT_EMBED_STATUS_EMPTY}:
        report += f"\n{OPENCODE_STDOUT_BEGIN}\n"
        report += embedding.text or ""
        if not report.endswith("\n"):
            report += "\n"
        report += f"{OPENCODE_STDOUT_END}\n"
    return report


@dataclass(frozen=True, slots=True)
class PersistedReport:
    text: str
    path: str
    clipboard_status: str
    clipboard_error: str | None


class ReportManager:
    """Enforce report-before-copy ordering and retain copy diagnostics."""

    def __init__(self, runs: DurableRunStore, writer: ClipboardWriter) -> None:
        self.runs = runs
        self.writer = writer

    def persist_before_copy(self, data: ReportData) -> PersistedReport:
        # ReportData uses slots, so build the pending copy without relying on
        # __dict__ in alternate Python implementations.
        stdout_embedding = extract_opencode_stdout(data.output_path)
        pending = self._copy_with_status(data, "PENDING")
        path = self.runs.persist_report(
            data.run_id,
            render_report(pending, stdout_embedding=stdout_embedding),
        )
        copy_status = "FAILED"
        copy_error: str | None = None
        try:
            self.writer.copy(
                render_report(pending, stdout_embedding=stdout_embedding)
            )
            copy_status = "OK"
        except ClipboardError as error:
            copy_error = str(error)
        except Exception as error:  # defensive boundary for injected writers
            copy_error = f"{type(error).__name__}: {error}"
        final = self._copy_with_status(data, copy_status)
        final.report_path = str(path)
        final_text = render_report(final, stdout_embedding=stdout_embedding)
        self.runs.persist_report(data.run_id, final_text)
        return PersistedReport(final_text, str(path), copy_status, copy_error)

    @staticmethod
    def _copy_with_status(data: ReportData, status: str) -> ReportData:
        return ReportData(
            run_id=data.run_id,
            action=data.action,
            task_id=data.task_id,
            context_id=data.context_id,
            model=data.model,
            variant=data.variant,
            opencode_version=data.opencode_version,
            agent=data.agent,
            role=data.role,
            model_source=data.model_source,
            variant_source=data.variant_source,
            role_source=data.role_source,
            agent_source=data.agent_source,
            repository=data.repository,
            base_sha=data.base_sha,
            commit_sha=data.commit_sha,
            coordinator_state=data.coordinator_state,
            worker_result=data.worker_result,
            review_result=data.review_result,
            tests=data.tests,
            diff_check=data.diff_check,
            prompt_sha256=data.prompt_sha256,
            report_path=data.report_path,
            log_path=data.log_path,
            output_path=data.output_path,
            timestamp=data.timestamp,
            started_at=data.started_at,
            finished_at=data.finished_at,
            duration_ms=data.duration_ms,
            process_duration_ms=data.process_duration_ms,
            timeout=data.timeout,
            readonly_policy=data.readonly_policy,
            mutation_guard=data.mutation_guard,
            process_status=data.process_status,
            process_exit_code=data.process_exit_code,
            embedded_report_id=data.embedded_report_id,
            embedded_status=data.embedded_status,
            embedded_verdict=data.embedded_verdict,
            result_consistency=data.result_consistency,
            clipboard_copy=status,
            findings=list(data.findings),
            verdict=data.verdict,
            diagnostic=data.diagnostic,
        )

    def copy_existing(self, run_id: str) -> str:
        return self.writer.copy(self.runs.read_report(run_id))
