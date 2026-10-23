"""Redaction helpers for untrusted subprocess output and diagnostics."""

from __future__ import annotations

import json
import os
import re
from collections.abc import Iterable, Mapping
from pathlib import Path
from typing import Any


_SENSITIVE_FIELD = re.compile(
    r"(?:token|api[_ -]?key|access[_ -]?token|refresh[_ -]?token|"
    r"id[_ -]?token|secret|password|credential|authorization|auth)",
    re.IGNORECASE,
)
_SENSITIVE_ASSIGNMENT = re.compile(
    r"(?P<prefix>\b(?:authorization|proxy-authorization|api[_ -]?key|"
    r"access[_ -]?token|refresh[_ -]?token|id[_ -]?token|client[_ -]?secret|"
    r"secret|password|credential)\b\s*[:=]\s*(?:bearer\s+)?)"
    r"(?P<value>[^\s,;}\]\"']{8,})",
    re.IGNORECASE,
)
_SENSITIVE_JSON = re.compile(
    r'(?P<prefix>"(?:token|api[_ -]?key|access[_ -]?token|refresh[_ -]?token|'
    r'id[_ -]?token|secret|password|credential|authorization|auth)"\s*:\s*")'
    r'(?P<value>[^"\\]{8,})(?P<suffix>")',
    re.IGNORECASE,
)
_BEARER = re.compile(
    r"(?P<prefix>\bBearer\s+)(?P<value>[A-Za-z0-9._~+/=-]{8,})",
    re.IGNORECASE,
)
_URL_CREDENTIAL = re.compile(
    r"(?P<prefix>://[^\s/:@]+:)(?P<value>[^\s/@]{8,})(?P<suffix>@)",
)


def _iter_sensitive_values(value: Any, path: str = "") -> Iterable[str]:
    if isinstance(value, Mapping):
        for key, child in value.items():
            child_path = f"{path}.{key}" if path else str(key)
            if _SENSITIVE_FIELD.search(str(key)) and isinstance(child, str):
                yield child
            else:
                yield from _iter_sensitive_values(child, child_path)
    elif isinstance(value, list):
        for index, child in enumerate(value):
            yield from _iter_sensitive_values(child, f"{path}[{index}]")


def _candidate_service_files(roots: Iterable[str | Path]) -> tuple[Path, ...]:
    candidates: list[Path] = []
    configured = os.environ.get("OPENCODE_CONFIG_DIR", "").strip()
    if configured:
        candidates.append(Path(configured) / "service.json")
    for root in roots:
        path = Path(root)
        candidates.append(path / ".opencode" / "service.json")
        if path.name == "opencode":
            candidates.append(path / "service.json")
    return tuple(dict.fromkeys(candidates))


def _load_service_secrets(roots: Iterable[str | Path]) -> Iterable[str]:
    for path in _candidate_service_files(roots):
        try:
            payload = json.loads(path.read_text(encoding="utf-8"))
        except (OSError, UnicodeError, json.JSONDecodeError):
            continue
        yield from _iter_sensitive_values(payload)


def _environment_secrets() -> Iterable[str]:
    for name, value in os.environ.items():
        if _SENSITIVE_FIELD.search(name):
            yield value


class SensitiveOutputRedactor:
    """Redact known local credentials and common credential syntax.

    The original subprocess result remains available to protocol parsing. Only
    observation and durable diagnostic boundaries use this redactor.
    """

    def __init__(self, roots: Iterable[str | Path] = ()) -> None:
        values = set(
            value
            for value in (*_load_service_secrets(roots), *_environment_secrets())
            if isinstance(value, str) and len(value) >= 8
        )
        self._known_values = tuple(sorted(values, key=len, reverse=True))

    def redact(self, text: str) -> str:
        if type(text) is not str:
            raise TypeError("Sensitive output must be text")
        redacted = text
        for value in self._known_values:
            redacted = redacted.replace(value, "[REDACTED]")
        redacted = _SENSITIVE_JSON.sub(
            lambda match: f'{match.group("prefix")}[REDACTED]{match.group("suffix")}',
            redacted,
        )
        redacted = _SENSITIVE_ASSIGNMENT.sub(
            lambda match: f'{match.group("prefix")}[REDACTED]',
            redacted,
        )
        redacted = _BEARER.sub(
            lambda match: f'{match.group("prefix")}[REDACTED]',
            redacted,
        )
        return _URL_CREDENTIAL.sub(
            lambda match: f'{match.group("prefix")}[REDACTED]{match.group("suffix")}',
            redacted,
        )


def redact_sensitive_text(
    text: str, *, roots: Iterable[str | Path] = ()
) -> str:
    """Redact text without requiring callers to retain a redactor instance."""

    return SensitiveOutputRedactor(roots).redact(text)


def redact_sensitive_data(value: Any, *, roots: Iterable[str | Path] = ()) -> Any:
    """Redact string leaves in JSON-like diagnostic data."""

    redactor = SensitiveOutputRedactor(roots)

    def visit(item: Any) -> Any:
        if isinstance(item, str):
            return redactor.redact(item)
        if isinstance(item, Mapping):
            return {key: visit(child) for key, child in item.items()}
        if isinstance(item, list):
            return [visit(child) for child in item]
        if isinstance(item, tuple):
            return tuple(visit(child) for child in item)
        return item

    return visit(value)


__all__ = [
    "SensitiveOutputRedactor",
    "redact_sensitive_data",
    "redact_sensitive_text",
]
