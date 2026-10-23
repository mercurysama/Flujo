"""Validation for the canonical OpenCode read-only audit agent."""

from __future__ import annotations

import hashlib
import re
from dataclasses import dataclass
from pathlib import Path


READ_ONLY_AGENT_ID = "gota-auditor"
_REPOSITORY_ROOT = Path(__file__).resolve().parents[2]
CANONICAL_AGENT_PATH = _REPOSITORY_ROOT / ".opencode" / "agents" / f"{READ_ONLY_AGENT_ID}.md"
PROTECTED_AUDIT_PATHS = (".opencode/service.json", "**/.opencode/service.json")


class ReadOnlyAgentError(ValueError):
    """The configured audit agent is missing or not strictly read-only."""


@dataclass(frozen=True, slots=True)
class ReadOnlyAgentPolicy:
    agent_id: str
    path: Path
    sha256: str


_REQUIRED_TEXT = (
    'mode: primary',
    'permissions:',
    '  - action: "*"\n    resource: "*"\n    effect: deny',
    '  - action: shell\n    resource: "*"\n    effect: deny',
    '  - action: read\n    resource: "*"\n    effect: allow',
    '  - action: glob\n    resource: "*"\n    effect: allow',
    '  - action: grep\n    resource: "*"\n    effect: allow',
    "Never edit or write files",
    "never create commits, branches, tags",
    "never run mutable Git commands",
    "never invoke subagents or skills",
    "never access an external directory",
    "one read-only operation per shell call",
    "never use `;`, `|`, `&&`, `||`, redirections, subshells, command",
    "do not execute Python, unittest, or any test suite",
    "Never read `.opencode/service.json`",
    "MUTATION_DETECTED",
    "MUTATION_ATTEMPT_DENIED",
    "READONLY_COMMAND_DENIED",
    "SENSITIVE_PATH_BLOCKED",
)


def validate_read_only_agent(agent_id: str) -> ReadOnlyAgentPolicy:
    """Load and verify the exact agent selected by ``audit-opencode``.

    The project already uses Markdown frontmatter for canonical OpenCode V2
    agents. This validator deliberately checks the existing representation as
    text rather than introducing a second YAML parser or permission schema.
    """

    if agent_id != READ_ONLY_AGENT_ID:
        raise ReadOnlyAgentError(
            f"audit-opencode requires canonical agent {READ_ONLY_AGENT_ID!r}, got {agent_id!r}"
        )
    try:
        text = CANONICAL_AGENT_PATH.read_text(encoding="utf-8")
    except (OSError, UnicodeError) as error:
        raise ReadOnlyAgentError(
            f"Cannot read canonical read-only agent {CANONICAL_AGENT_PATH}: {error}"
        ) from error
    normalized = " ".join(text.split())
    missing = [
        fragment
        for fragment in _REQUIRED_TEXT
        if " ".join(fragment.split()) not in normalized
    ]
    shell_allow_resources = re.findall(
        r'- action: shell resource: "([^"]*)" effect: allow', normalized
    )
    if not shell_allow_resources:
        missing.append("at least one explicit read-only Git shell allow rule")
    elif any(
        not resource.startswith("git ")
        or any(character in resource for character in ";|&><`()")
        for resource in shell_allow_resources
    ):
        missing.append("shell allow rules must be Git-only and shell-metacharacter-free")
    read_allow = normalized.find('- action: read resource: "*" effect: allow')
    for protected_path in PROTECTED_AUDIT_PATHS:
        protected_rule = (
            f'- action: read resource: "{protected_path}" effect: deny'
        )
        if normalized.find(protected_rule) <= read_allow:
            missing.append(f"read deny rule for protected path {protected_path!r}")
    if missing:
        raise ReadOnlyAgentError(
            "Canonical read-only agent policy is incomplete: " + "; ".join(missing)
        )
    return ReadOnlyAgentPolicy(
        agent_id=agent_id,
        path=CANONICAL_AGENT_PATH,
        sha256=hashlib.sha256(text.encode("utf-8")).hexdigest(),
    )


__all__ = [
    "CANONICAL_AGENT_PATH",
    "PROTECTED_AUDIT_PATHS",
    "READ_ONLY_AGENT_ID",
    "ReadOnlyAgentError",
    "ReadOnlyAgentPolicy",
    "validate_read_only_agent",
]
