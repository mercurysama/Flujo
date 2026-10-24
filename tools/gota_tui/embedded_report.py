"""Conservative, informational parsing of reports emitted on OpenCode stdout."""

from __future__ import annotations

import re
from dataclasses import dataclass
from typing import Final


NO_EMBEDDED_REPORT: Final[str] = "NO_EMBEDDED_REPORT"
PROCESS_AND_REPORT_PASS: Final[str] = "PROCESS_AND_REPORT_PASS"
PROCESS_AND_REPORT_FAIL: Final[str] = "PROCESS_AND_REPORT_FAIL"
PROCESS_FAIL_REPORT_PASS: Final[str] = "PROCESS_FAIL_REPORT_PASS"
PROCESS_PASS_REPORT_FAIL: Final[str] = "PROCESS_PASS_REPORT_FAIL"
INCOMPLETE_EMBEDDED_REPORT: Final[str] = "INCOMPLETE_EMBEDDED_REPORT"
EMBEDDED_REPORT_UNCLASSIFIED: Final[str] = "EMBEDDED_REPORT_UNCLASSIFIED"
AMBIGUOUS_EMBEDDED_REPORT: Final[str] = "AMBIGUOUS_EMBEDDED_REPORT"

REPORT_PASS: Final[str] = "PASS"
REPORT_FAIL: Final[str] = "FAIL"

_BEGIN_RE: Final[re.Pattern[str]] = re.compile(
    r"^=== ([A-Za-z0-9][A-Za-z0-9_.-]*)_REPORT_BEGIN ===$"
)
_END_RE: Final[re.Pattern[str]] = re.compile(
    r"^=== ([A-Za-z0-9][A-Za-z0-9_.-]*)_REPORT_END ===$"
)
_STATUS_RE: Final[re.Pattern[str]] = re.compile(r"^STATUS=(.*)$")
_VERDICT_RE: Final[re.Pattern[str]] = re.compile(r"^VERDICT=(.*)$")
_PASS_VALUES: Final[frozenset[str]] = frozenset(
    {"PASA", "PASS", "READ_ONLY_OK", "SUCCEEDED"}
)
_FAIL_VALUES: Final[frozenset[str]] = frozenset(
    {"NO PASA", "FAIL", "FAILED", "BLOCKED", "BLOQUEADO"}
)
_PROCESS_FAILURE_STATUSES: Final[frozenset[str]] = frozenset(
    {"non_zero_exit", "timeout", "cancelled", "start_failed"}
)


@dataclass(frozen=True, slots=True)
class EmbeddedReport:
    """One complete report block, retaining source text and original values."""

    report_id: str
    raw_text: str
    status: str | None
    verdict: str | None
    status_classification: str | None
    verdict_classification: str | None
    classification: str | None
    ambiguous: bool = False


@dataclass(frozen=True, slots=True)
class EmbeddedReportParse:
    """Parser result; no field in this type grants operational authority."""

    report: EmbeddedReport | None
    marker_seen: bool
    incomplete: bool
    ambiguous: bool = False


def normalize_embedded_verdict(value: str | None) -> str | None:
    """Classify only exact, contract-defined outcome values."""

    if type(value) is not str:
        return None
    normalized = " ".join(value.strip().upper().split())
    if normalized in _PASS_VALUES:
        return REPORT_PASS
    if normalized in _FAIL_VALUES:
        return REPORT_FAIL
    return None


def _single_field(
    lines: list[str], pattern: re.Pattern[str]
) -> tuple[str | None, bool]:
    values: list[str] = []
    for line in lines:
        match = pattern.fullmatch(line)
        if match is not None:
            values.append(match.group(1).strip())
    if not values:
        return None, False
    # Keep the first textual value for diagnostics, but never treat repeated
    # fields as authoritative evidence. Equal repetitions are ambiguous too.
    return (values[0] if values[0] else None), len(values) > 1


def _make_report(report_id: str, raw_text: str, body_text: str) -> EmbeddedReport:
    body_lines = body_text.splitlines()
    status, duplicate_status = _single_field(body_lines, _STATUS_RE)
    verdict, duplicate_verdict = _single_field(body_lines, _VERDICT_RE)
    ambiguous = duplicate_status or duplicate_verdict
    status_classification = normalize_embedded_verdict(status)
    verdict_classification = normalize_embedded_verdict(verdict)
    classification: str | None
    if ambiguous:
        classification = None
    elif (
        status_classification is not None
        and verdict_classification is not None
        and status_classification != verdict_classification
    ):
        classification = None
    else:
        classification = verdict_classification or status_classification
    return EmbeddedReport(
        report_id=report_id,
        raw_text=raw_text,
        status=status,
        verdict=verdict,
        status_classification=status_classification,
        verdict_classification=verdict_classification,
        classification=classification,
        ambiguous=ambiguous,
    )


def parse_embedded_report(stdout: str) -> EmbeddedReportParse:
    """Parse complete report markers from stdout only.

    This function intentionally receives agent stdout, not prompt or request
    data. It never consults stderr, executes report text, or assigns process or
    Coordinator authority. Unbalanced markers make the result incomplete even
    if another block in the same stream happened to be complete.
    """

    if type(stdout) is not str:
        raise TypeError("OpenCode stdout must be text")

    lines = stdout.splitlines(keepends=True)
    marker_seen = False
    incomplete = False
    open_id: str | None = None
    open_start = 0
    complete: list[EmbeddedReport] = []

    for index, line_with_ending in enumerate(lines):
        line = line_with_ending.rstrip("\r\n")
        begin_match = _BEGIN_RE.fullmatch(line)
        end_match = _END_RE.fullmatch(line)
        if begin_match is not None:
            marker_seen = True
            if open_id is not None:
                incomplete = True
            else:
                open_id = begin_match.group(1)
                open_start = index
            continue
        if end_match is None:
            continue
        marker_seen = True
        if open_id is None or end_match.group(1) != open_id:
            incomplete = True
            continue
        raw_text = "".join(lines[open_start : index + 1])
        body_text = "".join(lines[open_start + 1 : index])
        complete.append(_make_report(open_id, raw_text, body_text))
        open_id = None

    if open_id is not None:
        incomplete = True
    ambiguous = len(complete) > 1 or any(report.ambiguous for report in complete)
    if incomplete:
        return EmbeddedReportParse(
            report=None,
            marker_seen=marker_seen,
            incomplete=True,
            ambiguous=ambiguous,
        )
    if not complete:
        return EmbeddedReportParse(
            report=None,
            marker_seen=marker_seen,
            incomplete=False,
            ambiguous=False,
        )
    if len(complete) > 1:
        return EmbeddedReportParse(
            report=None,
            marker_seen=True,
            incomplete=False,
            ambiguous=True,
        )
    return EmbeddedReportParse(
        report=complete[0],
        marker_seen=True,
        incomplete=False,
        ambiguous=complete[0].ambiguous,
    )


def result_consistency(
    *,
    process_status: str | None,
    process_exit_code: int | None,
    parsed: EmbeddedReportParse,
) -> str:
    """Compare process completion with explicit embedded evidence."""

    if parsed.incomplete:
        return INCOMPLETE_EMBEDDED_REPORT
    report = parsed.report
    if report is None:
        if parsed.ambiguous:
            return AMBIGUOUS_EMBEDDED_REPORT
        return NO_EMBEDDED_REPORT
    if parsed.ambiguous or report.ambiguous:
        return AMBIGUOUS_EMBEDDED_REPORT
    if report.classification not in {REPORT_PASS, REPORT_FAIL}:
        return EMBEDDED_REPORT_UNCLASSIFIED

    process_passed = (
        process_exit_code == 0
        and process_status not in _PROCESS_FAILURE_STATUSES
    )
    if report.classification == REPORT_PASS:
        return PROCESS_AND_REPORT_PASS if process_passed else PROCESS_FAIL_REPORT_PASS
    return PROCESS_PASS_REPORT_FAIL if process_passed else PROCESS_AND_REPORT_FAIL


def conflict_diagnostic(consistency: str) -> str | None:
    """Return a human diagnostic without changing the technical verdict."""

    if consistency == PROCESS_FAIL_REPORT_PASS:
        return (
            "Process failed, but the embedded task report declared PASS. "
            "Manual review required."
        )
    if consistency == PROCESS_PASS_REPORT_FAIL:
        return (
            "Process completed, but the embedded task report declared FAIL. "
            "Manual review required."
        )
    return None


__all__ = [
    "AMBIGUOUS_EMBEDDED_REPORT",
    "EMBEDDED_REPORT_UNCLASSIFIED",
    "EmbeddedReport",
    "EmbeddedReportParse",
    "INCOMPLETE_EMBEDDED_REPORT",
    "NO_EMBEDDED_REPORT",
    "PROCESS_AND_REPORT_FAIL",
    "PROCESS_AND_REPORT_PASS",
    "PROCESS_FAIL_REPORT_PASS",
    "PROCESS_PASS_REPORT_FAIL",
    "REPORT_FAIL",
    "REPORT_PASS",
    "conflict_diagnostic",
    "normalize_embedded_verdict",
    "parse_embedded_report",
    "result_consistency",
]
