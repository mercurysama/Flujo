"""Compact, stable reports intended for pasting into ChatGPT."""

from __future__ import annotations

import json
from dataclasses import dataclass, field
from typing import Any, Iterable, Mapping

from .clipboard import ClipboardError, ClipboardWriter
from .durable import DurableRunStore


def _value(value: object) -> str:
    if value is None or value == "":
        return "UNKNOWN"
    return str(value).replace("\r", " ").replace("\n", " ").strip()


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


@dataclass(slots=True)
class ReportData:
    run_id: str
    action: str
    task_id: str | None = None
    context_id: str | None = None
    model: str | None = None
    variant: str | None = None
    opencode_version: str | None = None
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
    clipboard_copy: str = "NOT_ATTEMPTED"
    findings: list[Mapping[str, Any]] = field(default_factory=list)
    verdict: str = "UNKNOWN"
    diagnostic: str | None = None


def render_report(data: ReportData) -> str:
    lines = [
        "GOTA_REPORT_V1",
        f"RUN_ID={_value(data.run_id)}",
        f"ACTION={_value(data.action)}",
        f"TASK_ID={_value(data.task_id)}",
        f"CONTEXT_ID={_value(data.context_id)}",
        f"MODEL={_value(data.model)}",
        f"VARIANT={_value(data.variant)}",
        f"OPENCODE_VERSION={_value(data.opencode_version)}",
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
        f"CLIPBOARD_COPY={_value(data.clipboard_copy)}",
        f"FINDINGS={_findings(data.findings)}",
        f"DIAGNOSTIC={_value(data.diagnostic)}",
        f"VERDICT={_value(data.verdict)}",
    ]
    return "\n".join(lines) + "\n"


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
        pending = self._copy_with_status(data, "PENDING")
        path = self.runs.persist_report(data.run_id, render_report(pending))
        copy_status = "FAILED"
        copy_error: str | None = None
        try:
            self.writer.copy(render_report(pending))
            copy_status = "OK"
        except ClipboardError as error:
            copy_error = str(error)
        except Exception as error:  # defensive boundary for injected writers
            copy_error = f"{type(error).__name__}: {error}"
        final = self._copy_with_status(data, copy_status)
        final.report_path = str(path)
        final_text = render_report(final)
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
            clipboard_copy=status,
            findings=list(data.findings),
            verdict=data.verdict,
            diagnostic=data.diagnostic,
        )

    def copy_existing(self, run_id: str) -> str:
        return self.writer.copy(self.runs.read_report(run_id))
