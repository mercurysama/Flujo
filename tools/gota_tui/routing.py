"""Per-run Gota prompt routing and OpenCode context construction.

The machine-readable header is deliberately parsed only at the beginning of a
prompt.  Once the first non-header line is reached, similarly named text is
ordinary prompt data and is never interpreted as configuration.
"""

from __future__ import annotations

import re
from dataclasses import dataclass
from typing import Final


_HEADER_LINE: Final[re.Pattern[str]] = re.compile(
    r"^GOTA_(MODEL|VARIANT|ROLE|AGENT)=(.*?)(?:\r\n|\n|\r)?$"
)
_MODEL: Final[re.Pattern[str]] = re.compile(r"^[^/\s#]+/[^/\s#]+$")
_VARIANT: Final[re.Pattern[str]] = re.compile(r"^\S+$")


class GotaRoutingError(ValueError):
    """A Gota routing header or resolved OpenCode configuration is invalid."""


@dataclass(frozen=True, slots=True)
class GotaPromptHeader:
    """Values explicitly supplied by an initial Gota header."""

    model: str | None = None
    variant: str | None = None
    role: str | None = None
    agent: str | None = None
    keys: frozenset[str] = frozenset()

    def has(self, key: str) -> bool:
        return key in self.keys

    @property
    def present(self) -> bool:
        return bool(self.keys)


@dataclass(frozen=True, slots=True)
class ParsedGotaPrompt:
    """The raw prompt, its exact post-header body, and parsed header values."""

    raw: str
    body: str
    header: GotaPromptHeader

    @property
    def effective_prompt(self) -> str:
        return inject_role(self.body, self.header.role)


@dataclass(frozen=True, slots=True)
class ExecutionRouting:
    """One immutable, validated OpenCode selection for a prepared run."""

    model: str
    variant: str
    role: str | None
    agent: str
    model_source: str
    variant_source: str
    role_source: str
    agent_source: str
    prompt: ParsedGotaPrompt


def _line_without_ending(line: str) -> str:
    if line.endswith("\r\n"):
        return line[:-2]
    if line.endswith(("\n", "\r")):
        return line[:-1]
    return line


def parse_gota_prompt(prompt: str) -> ParsedGotaPrompt:
    """Parse only a contiguous machine-readable header at prompt offset zero.

    A single blank line after the header is the separator and is removed.  Any
    further blank lines, Markdown, code, Unicode, or header-looking text in the
    body is retained exactly as authored.
    """

    if type(prompt) is not str:
        raise GotaRoutingError("Prompt must be text")

    lines = prompt.splitlines(keepends=True)
    values: dict[str, str] = {}
    index = 0
    while index < len(lines):
        match = _HEADER_LINE.fullmatch(lines[index])
        if match is None:
            break
        key = match.group(1)
        if key in values:
            raise GotaRoutingError(f"Duplicate Gota header field: GOTA_{key}")
        values[key] = match.group(2).strip()
        index += 1

    body_start = sum(len(line) for line in lines[:index])
    if index > 0 and index < len(lines) and _line_without_ending(lines[index]) == "":
        body_start += len(lines[index])

    header = GotaPromptHeader(
        model=values.get("MODEL"),
        variant=values.get("VARIANT"),
        role=values.get("ROLE"),
        agent=values.get("AGENT"),
        keys=frozenset(values),
    )
    return ParsedGotaPrompt(raw=prompt, body=prompt[body_start:], header=header)


def inject_role(body: str, role: str | None) -> str:
    """Add semantic role context without rewriting the original task body."""

    if role is None:
        return body
    return f"ROLE:\n{role}\n\nTASK:\n{body}"


def _non_empty(value: str | None, field: str) -> str:
    if type(value) is not str or not value.strip():
        raise GotaRoutingError(f"{field} must be a non-empty string")
    return value.strip()


def validate_model(value: str | None) -> str:
    model = _non_empty(value, "model")
    if _MODEL.fullmatch(model) is None:
        raise GotaRoutingError(
            f"Invalid OpenCode model {model!r}; expected provider/model"
        )
    return model


def validate_variant(value: str | None) -> str:
    variant = _non_empty(value, "variant")
    if _VARIANT.fullmatch(variant) is None:
        raise GotaRoutingError("variant must not contain whitespace")
    return variant


def validate_agent(value: str | None) -> str:
    return _non_empty(value, "agent")


def validate_role(value: str | None) -> str:
    return _non_empty(value, "role")


def resolve_execution_routing(
    prompt: ParsedGotaPrompt,
    *,
    action_model: str | None,
    action_variant: str | None,
    action_agent: str | None,
    config_model: str | None = None,
    config_variant: str | None = None,
    config_role: str | None = None,
    config_agent: str | None = None,
    legacy_model: str = "openai/gpt-5.6-luna",
    legacy_variant: str = "max",
    legacy_agent: str = "build",
) -> ExecutionRouting:
    """Resolve prompt overrides before config/action defaults and legacy values."""

    header = prompt.header

    if header.has("MODEL"):
        model = validate_model(header.model)
        model_source = "prompt"
    elif config_model is not None:
        model = validate_model(config_model)
        model_source = "config"
    elif action_model:
        model = validate_model(action_model)
        model_source = "config"
    else:
        model = validate_model(legacy_model)
        model_source = "legacy"

    if header.has("VARIANT"):
        variant = validate_variant(header.variant)
        variant_source = "prompt"
    elif config_variant is not None:
        variant = validate_variant(config_variant)
        variant_source = "config"
    elif action_variant:
        variant = validate_variant(action_variant)
        variant_source = "config"
    else:
        variant = validate_variant(legacy_variant)
        variant_source = "legacy"

    if header.has("ROLE"):
        role = validate_role(header.role)
        role_source = "prompt"
    elif config_role is not None:
        role = validate_role(config_role)
        role_source = "config"
    else:
        role = None
        role_source = "legacy"

    if header.has("AGENT"):
        agent = validate_agent(header.agent)
        agent_source = "prompt"
    elif config_agent is not None:
        agent = validate_agent(config_agent)
        agent_source = "config"
    elif action_agent:
        agent = validate_agent(action_agent)
        agent_source = "action"
    else:
        agent = validate_agent(legacy_agent)
        agent_source = "legacy"

    return ExecutionRouting(
        model=model,
        variant=variant,
        role=role,
        agent=agent,
        model_source=model_source,
        variant_source=variant_source,
        role_source=role_source,
        agent_source=agent_source,
        prompt=ParsedGotaPrompt(
            raw=prompt.raw,
            body=prompt.body,
            header=GotaPromptHeader(
                model=header.model,
                variant=header.variant,
                role=role,
                agent=header.agent,
                keys=header.keys,
            ),
        ),
    )


__all__ = [
    "ExecutionRouting",
    "GotaPromptHeader",
    "GotaRoutingError",
    "ParsedGotaPrompt",
    "inject_role",
    "parse_gota_prompt",
    "resolve_execution_routing",
    "validate_agent",
    "validate_model",
    "validate_role",
    "validate_variant",
]
