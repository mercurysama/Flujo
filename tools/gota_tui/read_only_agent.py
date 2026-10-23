"""Validation for the canonical OpenCode read-only audit agent."""

from __future__ import annotations

import hashlib
from dataclasses import dataclass
from pathlib import Path


READ_ONLY_AGENT_ID = "gota-auditor"
_REPOSITORY_ROOT = Path(__file__).resolve().parents[2]
CANONICAL_AGENT_PATH = _REPOSITORY_ROOT / ".opencode" / "agents" / f"{READ_ONLY_AGENT_ID}.md"


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
    "READ_ONLY_AGENT_ID",
    "ReadOnlyAgentError",
    "ReadOnlyAgentPolicy",
    "validate_read_only_agent",
]
