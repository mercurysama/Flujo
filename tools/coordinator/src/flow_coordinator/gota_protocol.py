"""Machine-readable ``flujo.gota/v1`` protocol types and parser.

The JSON Schemas enforce JSON-local structure, required fields, enums, and
SHA formats. Python validation remains responsible for cross-field invariants
such as ``request_id == run_id + ':' + attempt + ':' + phase`` because this
contract does not use non-standard JSON Schema extensions.
"""

from __future__ import annotations

import json
import math
from dataclasses import dataclass
from decimal import Decimal, InvalidOperation
from enum import StrEnum
from typing import Any, Mapping, NoReturn, TypeVar


GOTA_PROTOCOL = "flujo.gota/v1"
GOTA_RESULT_BEGIN = "FLUJO_GOTA_RESULT_V1_BEGIN"
GOTA_RESULT_END = "FLUJO_GOTA_RESULT_V1_END"
_INVALID_FRAMING_SEPARATORS = (
    "\v",
    "\f",
    "\x1c",
    "\x1d",
    "\x1e",
    "\x85",
    "\u2028",
    "\u2029",
)


class GotaPhase(StrEnum):
    WORKER = "worker"
    REVIEW = "review"


class GotaMessage(StrEnum):
    WORKER_RESULT = "worker.result"
    REVIEW_RESULT = "review.result"


class WorkerResultStatus(StrEnum):
    READY_FOR_REVIEW = "READY_FOR_REVIEW"


class ReviewDecision(StrEnum):
    PASSED = "PASSED"
    CORRECTION_REQUIRED = "CORRECTION_REQUIRED"
    HUMAN_REVIEW_REQUIRED = "HUMAN_REVIEW_REQUIRED"
    BLOCKED = "BLOCKED"


class GotaProtocolErrorCode(StrEnum):
    START_DELIMITER_MISSING = "START_DELIMITER_MISSING"
    END_DELIMITER_MISSING = "END_DELIMITER_MISSING"
    MULTIPLE_PAYLOADS = "MULTIPLE_PAYLOADS"
    DELIMITER_ORDER_INVALID = "DELIMITER_ORDER_INVALID"
    INVALID_FRAMING = "INVALID_FRAMING"
    INVALID_JSON = "INVALID_JSON"
    INVALID_PAYLOAD = "INVALID_PAYLOAD"
    MISSING_FIELD = "MISSING_FIELD"
    UNEXPECTED_FIELD = "UNEXPECTED_FIELD"
    UNKNOWN_PROTOCOL = "UNKNOWN_PROTOCOL"
    UNKNOWN_MESSAGE = "UNKNOWN_MESSAGE"
    UNKNOWN_RESULT = "UNKNOWN_RESULT"
    UNKNOWN_DECISION = "UNKNOWN_DECISION"
    INVALID_FIELD = "INVALID_FIELD"
    INVALID_ATTEMPT = "INVALID_ATTEMPT"
    INVALID_PHASE = "INVALID_PHASE"
    INVALID_REQUEST_ID = "INVALID_REQUEST_ID"
    INVALID_SHA = "INVALID_SHA"


class GotaProtocolError(ValueError):
    """Deterministic, typed validation failure for the Gota protocol."""

    def __init__(self, code: GotaProtocolErrorCode, detail: str) -> None:
        self.code = code
        self.detail = detail
        super().__init__(f"{code.value}: {detail}")


def _fail(code: GotaProtocolErrorCode, detail: str) -> NoReturn:
    raise GotaProtocolError(code, detail)


def _object(value: Any) -> Mapping[str, Any]:
    if type(value) is not dict or any(type(key) is not str for key in value):
        _fail(GotaProtocolErrorCode.INVALID_PAYLOAD, "Payload must be a JSON object")
    return value


def _check_keys(
    payload: Mapping[str, Any],
    required: set[str],
    optional: set[str] | None = None,
) -> None:
    optional = optional or set()
    missing = sorted(required - set(payload))
    if missing:
        _fail(
            GotaProtocolErrorCode.MISSING_FIELD,
            f"Missing required field(s): {', '.join(missing)}",
        )
    unexpected = sorted(set(payload) - required - optional)
    if unexpected:
        _fail(
            GotaProtocolErrorCode.UNEXPECTED_FIELD,
            f"Unexpected field(s): {', '.join(unexpected)}",
        )


def _non_empty_string(value: Any, field: str) -> str:
    if type(value) is not str or not value.strip():
        _fail(
            GotaProtocolErrorCode.INVALID_FIELD,
            f"Field '{field}' must be a non-empty string",
        )
    return value


def _attempt(value: Any) -> int:
    if type(value) is int:
        normalized = value
    elif type(value) is Decimal:
        if not _decimal_is_finite(value) or value != value.to_integral_value():
            _fail(
                GotaProtocolErrorCode.INVALID_ATTEMPT,
                "Field 'attempt' must be a positive integer",
            )
        normalized = int(value)
    else:
        _fail(
            GotaProtocolErrorCode.INVALID_ATTEMPT,
            "Field 'attempt' must be a positive integer",
        )
    if normalized < 1:
        _fail(
            GotaProtocolErrorCode.INVALID_ATTEMPT,
            "Field 'attempt' must be a positive integer",
        )
    return normalized


def _phase(value: Any) -> GotaPhase:
    if type(value) is GotaPhase:
        return value
    if type(value) is not str:
        _fail(
            GotaProtocolErrorCode.INVALID_PHASE,
            "Field 'phase' must be 'worker' or 'review'",
        )
    try:
        return GotaPhase(value)
    except ValueError:
        _fail(
            GotaProtocolErrorCode.INVALID_PHASE,
            f"Unknown phase: {value}",
        )


def _protocol(value: Any) -> str:
    if type(value) is not str or value != GOTA_PROTOCOL:
        _fail(
            GotaProtocolErrorCode.UNKNOWN_PROTOCOL,
            f"Unsupported protocol: {value}",
        )
    return GOTA_PROTOCOL


def _message(value: Any, expected: GotaMessage) -> str:
    if type(value) is not str or value != expected.value:
        _fail(
            GotaProtocolErrorCode.UNKNOWN_MESSAGE,
            f"Expected message: {expected.value}",
        )
    return expected.value


def _sha(value: Any, field: str) -> str:
    if type(value) is not str or len(value) != 40:
        _fail(
            GotaProtocolErrorCode.INVALID_SHA,
            f"Field '{field}' must contain a 40-character hexadecimal SHA",
        )
    if any(character not in "0123456789abcdef" for character in value):
        _fail(
            GotaProtocolErrorCode.INVALID_SHA,
            f"Field '{field}' must contain a 40-character hexadecimal SHA",
        )
    return value


def _strings(value: Any, field: str) -> tuple[str, ...]:
    if type(value) not in (list, tuple):
        _fail(
            GotaProtocolErrorCode.INVALID_FIELD,
            f"Field '{field}' must be an array of strings",
        )
    result: list[str] = []
    for item in value:
        result.append(_non_empty_string(item, field))
    return tuple(result)


def _paths(value: Any, field: str) -> tuple[str, ...]:
    """Validate path-shaped fields without changing their authored order."""

    return _strings(value, field)


def _findings(value: Any, field: str) -> tuple[GotaFinding, ...]:
    if type(value) not in (list, tuple):
        _fail(
            GotaProtocolErrorCode.INVALID_FIELD,
            f"Field '{field}' must be an array of finding objects",
        )
    result: list[GotaFinding] = []
    for item in value:
        if type(item) is GotaFinding:
            result.append(item)
        else:
            result.append(GotaFinding.from_payload(_object(item)))
    return tuple(result)


def _evidence(value: Any, field: str) -> tuple[Mapping[str, Any], ...]:
    if type(value) not in (list, tuple):
        _fail(
            GotaProtocolErrorCode.INVALID_FIELD,
            f"Field '{field}' must be an array of objects",
        )
    result: list[Mapping[str, Any]] = []
    for item in value:
        item_object = _object(item)
        result.append(dict(item_object))
    return tuple(result)


def _checkpoint(value: Any) -> GotaCheckpoint:
    if type(value) is GotaCheckpoint:
        return value
    return GotaCheckpoint.from_payload(_object(value))


def _validate_request_id(
    request_id: str, run_id: str, attempt: int, phase: GotaPhase
) -> None:
    expected = f"{run_id}:{attempt}:{phase.value}"
    if type(request_id) is not str or request_id != expected:
        _fail(
            GotaProtocolErrorCode.INVALID_REQUEST_ID,
            "request_id must equal run_id:attempt:phase",
        )


def _reject_non_finite_json_constant(value: str) -> NoReturn:
    _fail(
        GotaProtocolErrorCode.INVALID_JSON,
        f"Non-finite JSON constant is not allowed: {value}",
    )


def _decimal_is_finite(value: Decimal) -> bool:
    if not value.is_finite():
        return False
    try:
        return math.isfinite(float(value))
    except (OverflowError, ValueError):
        return False


def _parse_finite_json_float(value: str) -> Decimal:
    try:
        parsed = Decimal(value)
    except InvalidOperation:
        _fail(
            GotaProtocolErrorCode.INVALID_JSON,
            f"Invalid JSON number: {value}",
        )
    if not _decimal_is_finite(parsed):
        _fail(
            GotaProtocolErrorCode.INVALID_JSON,
            f"JSON number is not finite: {value}",
        )
    return parsed


def _reject_duplicate_json_keys(
    pairs: list[tuple[str, Any]],
) -> dict[str, Any]:
    object_value: dict[str, Any] = {}
    for key, value in pairs:
        if key in object_value:
            _fail(
                GotaProtocolErrorCode.INVALID_JSON,
                f"Duplicate JSON object key: {key}",
            )
        object_value[key] = value
    return object_value


def _validate_json_domain(
    value: Any,
    path: str = "$",
    active_containers: set[int] | None = None,
) -> None:
    """Reject non-JSON values before protocol-specific field validation."""

    if value is None or isinstance(value, (str, bool, int)):
        return
    if isinstance(value, float):
        if not math.isfinite(value):
            _fail(
                GotaProtocolErrorCode.INVALID_PAYLOAD,
                f"Non-finite JSON number at {path}",
            )
        return
    if isinstance(value, Decimal):
        if not _decimal_is_finite(value):
            _fail(
                GotaProtocolErrorCode.INVALID_PAYLOAD,
                f"Non-finite JSON number at {path}",
            )
        return

    if active_containers is None:
        active_containers = set()
    if isinstance(value, Mapping):
        container_id = id(value)
        if container_id in active_containers:
            _fail(
                GotaProtocolErrorCode.INVALID_PAYLOAD,
                f"Cyclic JSON value at {path}",
            )
        active_containers.add(container_id)
        try:
            for key, nested_value in value.items():
                if not isinstance(key, str):
                    _fail(
                        GotaProtocolErrorCode.INVALID_PAYLOAD,
                        f"JSON object key at {path} must be a string",
                    )
                _validate_json_domain(
                    nested_value,
                    f"{path}.{key}",
                    active_containers,
                )
        finally:
            active_containers.remove(container_id)
        return
    if isinstance(value, (list, tuple)):
        container_id = id(value)
        if container_id in active_containers:
            _fail(
                GotaProtocolErrorCode.INVALID_PAYLOAD,
                f"Cyclic JSON value at {path}",
            )
        active_containers.add(container_id)
        try:
            for index, nested_value in enumerate(value):
                _validate_json_domain(
                    nested_value,
                    f"{path}[{index}]",
                    active_containers,
                )
        finally:
            active_containers.remove(container_id)
        return

    _fail(
        GotaProtocolErrorCode.INVALID_PAYLOAD,
        f"Value at {path} is not valid JSON: {type(value).__name__}",
    )


EnumValue = TypeVar("EnumValue", bound=StrEnum)


def _enum_value(
    value: Any,
    enum_type: type[EnumValue],
    code: GotaProtocolErrorCode,
    field: str,
) -> EnumValue:
    if type(value) is enum_type:
        return value
    if type(value) is not str:
        _fail(code, f"Field '{field}' contains an unknown value")
    try:
        return enum_type(value)
    except ValueError:
        _fail(code, f"Unknown {field}: {value}")


@dataclass(frozen=True, slots=True)
class GotaFinding:
    id: str
    severity: str
    description: str
    path: str | None = None
    required_change: str | None = None

    def __post_init__(self) -> None:
        _non_empty_string(self.id, "id")
        _non_empty_string(self.severity, "severity")
        _non_empty_string(self.description, "description")
        if self.path is not None:
            _non_empty_string(self.path, "path")
        if self.required_change is not None:
            _non_empty_string(self.required_change, "required_change")

    @classmethod
    def from_payload(cls, payload: Mapping[str, Any]) -> GotaFinding:
        payload = _object(payload)
        _check_keys(
            payload,
            {"id", "severity", "description"},
            {"path", "required_change"},
        )
        if "path" in payload and payload["path"] is None:
            _fail(
                GotaProtocolErrorCode.INVALID_FIELD,
                "Field 'path' must be a non-empty string when present",
            )
        if "required_change" in payload and payload["required_change"] is None:
            _fail(
                GotaProtocolErrorCode.INVALID_FIELD,
                "Field 'required_change' must be a non-empty string when present",
            )
        return cls(
            id=payload["id"],
            severity=payload["severity"],
            description=payload["description"],
            path=payload.get("path"),
            required_change=payload.get("required_change"),
        )

    def to_payload(self) -> dict[str, str]:
        payload: dict[str, str] = {
            "id": self.id,
            "severity": self.severity,
            "description": self.description,
        }
        if self.path is not None:
            payload["path"] = self.path
        if self.required_change is not None:
            payload["required_change"] = self.required_change
        return payload


@dataclass(frozen=True, slots=True)
class GotaCheckpoint:
    completed_steps: tuple[str, ...]
    remaining_phase: str

    def __post_init__(self) -> None:
        object.__setattr__(
            self,
            "completed_steps",
            _strings(self.completed_steps, "completed_steps"),
        )
        _non_empty_string(self.remaining_phase, "remaining_phase")

    @classmethod
    def from_payload(cls, payload: Mapping[str, Any]) -> GotaCheckpoint:
        payload = _object(payload)
        _check_keys(payload, {"completed_steps", "remaining_phase"})
        return cls(
            completed_steps=payload["completed_steps"],
            remaining_phase=payload["remaining_phase"],
        )

    def to_payload(self) -> dict[str, Any]:
        return {
            "completed_steps": list(self.completed_steps),
            "remaining_phase": self.remaining_phase,
        }


@dataclass(frozen=True, slots=True)
class GotaRequest:
    protocol: str
    request_id: str
    task_id: str
    run_id: str
    attempt: int
    phase: GotaPhase | str
    objective: str
    acceptance_criteria: tuple[str, ...]
    workspace: str
    branch: str
    base_sha: str
    allowed_paths: tuple[str, ...]
    protected_paths: tuple[str, ...]
    previous_findings: tuple[GotaFinding, ...] = ()

    def __post_init__(self) -> None:
        _protocol(self.protocol)
        request_id = _non_empty_string(self.request_id, "request_id")
        task_id = _non_empty_string(self.task_id, "task_id")
        run_id = _non_empty_string(self.run_id, "run_id")
        attempt = _attempt(self.attempt)
        phase = _phase(self.phase)
        _non_empty_string(self.objective, "objective")
        object.__setattr__(
            self,
            "acceptance_criteria",
            _strings(self.acceptance_criteria, "acceptance_criteria"),
        )
        _non_empty_string(self.workspace, "workspace")
        _non_empty_string(self.branch, "branch")
        _sha(self.base_sha, "base_sha")
        object.__setattr__(
            self,
            "allowed_paths",
            _paths(self.allowed_paths, "allowed_paths"),
        )
        object.__setattr__(
            self,
            "protected_paths",
            _paths(self.protected_paths, "protected_paths"),
        )
        object.__setattr__(
            self,
            "previous_findings",
            _findings(self.previous_findings, "previous_findings"),
        )
        object.__setattr__(self, "phase", phase)
        _validate_request_id(request_id, run_id, attempt, phase)
        object.__setattr__(self, "request_id", request_id)
        object.__setattr__(self, "task_id", task_id)
        object.__setattr__(self, "run_id", run_id)
        object.__setattr__(self, "attempt", attempt)

    @classmethod
    def from_payload(cls, payload: Mapping[str, Any]) -> GotaRequest:
        payload = _object(payload)
        _check_keys(
            payload,
            {
                "protocol",
                "request_id",
                "task_id",
                "run_id",
                "attempt",
                "phase",
                "objective",
                "acceptance_criteria",
                "workspace",
                "branch",
                "base_sha",
                "allowed_paths",
                "protected_paths",
            },
            {"previous_findings"},
        )
        return cls(
            protocol=payload["protocol"],
            request_id=payload["request_id"],
            task_id=payload["task_id"],
            run_id=payload["run_id"],
            attempt=payload["attempt"],
            phase=payload["phase"],
            objective=payload["objective"],
            acceptance_criteria=payload["acceptance_criteria"],
            workspace=payload["workspace"],
            branch=payload["branch"],
            base_sha=payload["base_sha"],
            allowed_paths=payload["allowed_paths"],
            protected_paths=payload["protected_paths"],
            previous_findings=payload.get("previous_findings", ()),
        )

    def to_payload(self) -> dict[str, Any]:
        payload: dict[str, Any] = {
            "protocol": self.protocol,
            "request_id": self.request_id,
            "task_id": self.task_id,
            "run_id": self.run_id,
            "attempt": self.attempt,
            "phase": self.phase.value,
            "objective": self.objective,
            "acceptance_criteria": list(self.acceptance_criteria),
            "workspace": self.workspace,
            "branch": self.branch,
            "base_sha": self.base_sha,
            "allowed_paths": list(self.allowed_paths),
            "protected_paths": list(self.protected_paths),
        }
        if self.previous_findings:
            payload["previous_findings"] = [
                finding.to_payload() for finding in self.previous_findings
            ]
        return payload


@dataclass(frozen=True, slots=True)
class GotaWorkerResult:
    protocol: str
    message: str
    request_id: str
    task_id: str
    run_id: str
    attempt: int
    result: WorkerResultStatus | str
    commit_sha: str
    changed_paths: tuple[str, ...]
    evidence: tuple[Mapping[str, Any], ...]
    checkpoint: GotaCheckpoint

    def __post_init__(self) -> None:
        _protocol(self.protocol)
        _message(self.message, GotaMessage.WORKER_RESULT)
        request_id = _non_empty_string(self.request_id, "request_id")
        task_id = _non_empty_string(self.task_id, "task_id")
        run_id = _non_empty_string(self.run_id, "run_id")
        attempt = _attempt(self.attempt)
        result = _enum_value(
            self.result,
            WorkerResultStatus,
            GotaProtocolErrorCode.UNKNOWN_RESULT,
            "result",
        )
        _sha(self.commit_sha, "commit_sha")
        object.__setattr__(
            self,
            "changed_paths",
            _paths(self.changed_paths, "changed_paths"),
        )
        object.__setattr__(
            self,
            "evidence",
            _evidence(self.evidence, "evidence"),
        )
        object.__setattr__(self, "checkpoint", _checkpoint(self.checkpoint))
        object.__setattr__(self, "result", result)
        object.__setattr__(self, "request_id", request_id)
        object.__setattr__(self, "task_id", task_id)
        object.__setattr__(self, "run_id", run_id)
        object.__setattr__(self, "attempt", attempt)
        _validate_request_id(request_id, run_id, attempt, GotaPhase.WORKER)

    @classmethod
    def from_payload(cls, payload: Mapping[str, Any]) -> GotaWorkerResult:
        payload = _object(payload)
        _check_keys(
            payload,
            {
                "protocol",
                "message",
                "request_id",
                "task_id",
                "run_id",
                "attempt",
                "result",
                "commit_sha",
                "changed_paths",
                "evidence",
                "checkpoint",
            },
        )
        return cls(
            protocol=payload["protocol"],
            message=payload["message"],
            request_id=payload["request_id"],
            task_id=payload["task_id"],
            run_id=payload["run_id"],
            attempt=payload["attempt"],
            result=payload["result"],
            commit_sha=payload["commit_sha"],
            changed_paths=payload["changed_paths"],
            evidence=payload["evidence"],
            checkpoint=payload["checkpoint"],
        )

    @property
    def phase(self) -> GotaPhase:
        return GotaPhase.WORKER

    def to_payload(self) -> dict[str, Any]:
        return {
            "protocol": self.protocol,
            "message": self.message,
            "request_id": self.request_id,
            "task_id": self.task_id,
            "run_id": self.run_id,
            "attempt": self.attempt,
            "result": self.result.value,
            "commit_sha": self.commit_sha,
            "changed_paths": list(self.changed_paths),
            "evidence": [dict(item) for item in self.evidence],
            "checkpoint": self.checkpoint.to_payload(),
        }


@dataclass(frozen=True, slots=True)
class GotaReviewResult:
    protocol: str
    message: str
    request_id: str
    task_id: str
    run_id: str
    attempt: int
    reviewed_commit_sha: str
    decision: ReviewDecision | str
    findings: tuple[GotaFinding, ...]
    evidence: tuple[Mapping[str, Any], ...]

    def __post_init__(self) -> None:
        _protocol(self.protocol)
        _message(self.message, GotaMessage.REVIEW_RESULT)
        request_id = _non_empty_string(self.request_id, "request_id")
        task_id = _non_empty_string(self.task_id, "task_id")
        run_id = _non_empty_string(self.run_id, "run_id")
        attempt = _attempt(self.attempt)
        _sha(self.reviewed_commit_sha, "reviewed_commit_sha")
        decision = _enum_value(
            self.decision,
            ReviewDecision,
            GotaProtocolErrorCode.UNKNOWN_DECISION,
            "decision",
        )
        object.__setattr__(
            self,
            "findings",
            _findings(self.findings, "findings"),
        )
        object.__setattr__(
            self,
            "evidence",
            _evidence(self.evidence, "evidence"),
        )
        object.__setattr__(self, "decision", decision)
        object.__setattr__(self, "request_id", request_id)
        object.__setattr__(self, "task_id", task_id)
        object.__setattr__(self, "run_id", run_id)
        object.__setattr__(self, "attempt", attempt)
        _validate_request_id(request_id, run_id, attempt, GotaPhase.REVIEW)

    @classmethod
    def from_payload(cls, payload: Mapping[str, Any]) -> GotaReviewResult:
        payload = _object(payload)
        _check_keys(
            payload,
            {
                "protocol",
                "message",
                "request_id",
                "task_id",
                "run_id",
                "attempt",
                "reviewed_commit_sha",
                "decision",
                "findings",
                "evidence",
            },
        )
        return cls(
            protocol=payload["protocol"],
            message=payload["message"],
            request_id=payload["request_id"],
            task_id=payload["task_id"],
            run_id=payload["run_id"],
            attempt=payload["attempt"],
            reviewed_commit_sha=payload["reviewed_commit_sha"],
            decision=payload["decision"],
            findings=payload["findings"],
            evidence=payload["evidence"],
        )

    @property
    def phase(self) -> GotaPhase:
        return GotaPhase.REVIEW

    def to_payload(self) -> dict[str, Any]:
        return {
            "protocol": self.protocol,
            "message": self.message,
            "request_id": self.request_id,
            "task_id": self.task_id,
            "run_id": self.run_id,
            "attempt": self.attempt,
            "reviewed_commit_sha": self.reviewed_commit_sha,
            "decision": self.decision.value,
            "findings": [finding.to_payload() for finding in self.findings],
            "evidence": [dict(item) for item in self.evidence],
        }


def parse_gota_payload(
    payload: Mapping[str, Any],
) -> GotaWorkerResult | GotaReviewResult:
    """Validate one decoded result payload without using surrounding prose."""

    payload = _object(payload)
    _validate_json_domain(payload)
    _check_keys(payload, {"protocol", "message"}, set(payload) - {"protocol", "message"})
    _protocol(payload["protocol"])
    message = payload["message"]
    if type(message) is str and message == GotaMessage.WORKER_RESULT.value:
        return GotaWorkerResult.from_payload(payload)
    if type(message) is str and message == GotaMessage.REVIEW_RESULT.value:
        return GotaReviewResult.from_payload(payload)
    _fail(
        GotaProtocolErrorCode.UNKNOWN_MESSAGE,
        f"Unknown message: {message}",
    )


def _split_gota_lines(output: str) -> list[str]:
    """Split only on LF after explicitly normalizing CRLF."""

    for separator in _INVALID_FRAMING_SEPARATORS:
        if separator in output:
            _fail(
                GotaProtocolErrorCode.INVALID_FRAMING,
                "Only LF and CRLF are valid framing line endings",
            )
    for index, character in enumerate(output):
        if character == "\r" and (
            index + 1 == len(output) or output[index + 1] != "\n"
        ):
            _fail(
                GotaProtocolErrorCode.INVALID_FRAMING,
                "Only LF and CRLF are valid framing line endings",
            )
    return output.replace("\r\n", "\n").split("\n")


def parse_gota_output(output: str) -> GotaWorkerResult | GotaReviewResult:
    """Extract and validate exactly one delimited result from agent output."""

    if type(output) is not str:
        _fail(GotaProtocolErrorCode.INVALID_PAYLOAD, "Output must be text")
    lines = _split_gota_lines(output)
    begin_lines = [
        index for index, line in enumerate(lines) if line == GOTA_RESULT_BEGIN
    ]
    end_lines = [index for index, line in enumerate(lines) if line == GOTA_RESULT_END]
    if not begin_lines:
        _fail(
            GotaProtocolErrorCode.START_DELIMITER_MISSING,
            "Start delimiter was not found",
        )
    if not end_lines:
        _fail(
            GotaProtocolErrorCode.END_DELIMITER_MISSING,
            "End delimiter was not found",
        )
    if len(begin_lines) != 1 or len(end_lines) != 1:
        _fail(
            GotaProtocolErrorCode.MULTIPLE_PAYLOADS,
            "Exactly one delimited payload is required",
        )

    begin = begin_lines[0]
    end = end_lines[0]
    if end < begin:
        _fail(
            GotaProtocolErrorCode.DELIMITER_ORDER_INVALID,
            "End delimiter must follow start delimiter",
        )
    raw_payload = "\n".join(lines[begin + 1 : end])
    if not raw_payload:
        _fail(
            GotaProtocolErrorCode.INVALID_JSON,
            "Delimited payload is empty",
        )
    if raw_payload[0].isspace() or raw_payload[-1].isspace():
        _fail(
            GotaProtocolErrorCode.INVALID_JSON,
            "Delimited payload must not have leading or trailing whitespace",
        )
    try:
        decoded = json.loads(
            raw_payload,
            parse_constant=_reject_non_finite_json_constant,
            parse_float=_parse_finite_json_float,
            object_pairs_hook=_reject_duplicate_json_keys,
        )
    except GotaProtocolError:
        raise
    except (json.JSONDecodeError, TypeError, ValueError):
        _fail(
            GotaProtocolErrorCode.INVALID_JSON,
            "Delimited payload is not valid JSON",
        )
    if not isinstance(decoded, dict):
        _fail(GotaProtocolErrorCode.INVALID_PAYLOAD, "Payload must be a JSON object")
    return parse_gota_payload(decoded)


# Short aliases keep the public terminology usable without duplicating types.
Finding = GotaFinding
Request = GotaRequest
WorkerResult = GotaWorkerResult
ReviewResult = GotaReviewResult


__all__ = [
    "Finding",
    "GotaCheckpoint",
    "GotaFinding",
    "GotaMessage",
    "GotaPhase",
    "GotaProtocolError",
    "GotaProtocolErrorCode",
    "GotaRequest",
    "GotaReviewResult",
    "GotaWorkerResult",
    "GOTA_PROTOCOL",
    "GOTA_RESULT_BEGIN",
    "GOTA_RESULT_END",
    "ReviewDecision",
    "ReviewResult",
    "Request",
    "WorkerResult",
    "WorkerResultStatus",
    "parse_gota_output",
    "parse_gota_payload",
]
