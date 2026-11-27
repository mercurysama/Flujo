"""Plain prompt and versioned TOML-frontmatter Gota envelopes."""

from __future__ import annotations

import re
import tomllib
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Mapping

from flow_coordinator import GOTA_PROTOCOL, GotaRequest
from flow_coordinator.domain import TaskSpec

from .routing import GotaPromptHeader, parse_gota_prompt


class PromptEnvelopeError(ValueError):
    """A prompt cannot be safely represented for the selected action."""


_SHA_RE = re.compile(r"[0-9a-f]{40}")
_FRONTMATTER_MARKER = "+++"
_MUTABLE_FIELDS = frozenset(
    {
        "version",
        "task_id",
        "title",
        "project_id",
        "repository_id",
        "workspace",
        "branch",
        "base_sha",
        "context_id",
        "allowed_paths",
        "protected_paths",
        "acceptance_criteria",
        "commit_message",
        "attempt",
        "template_id",
        "coordinator_run_id",
    }
)


@dataclass(frozen=True, slots=True)
class PromptEnvelope:
    original: str
    assignment: str
    structured: bool
    metadata: Mapping[str, Any]
    prompt_header: GotaPromptHeader | None = None

    @classmethod
    def parse(cls, prompt: str) -> "PromptEnvelope":
        if type(prompt) is not str:
            raise PromptEnvelopeError("Prompt must be text")
        if not prompt.strip():
            raise PromptEnvelopeError("Clipboard prompt is empty")
        try:
            parsed_prompt = parse_gota_prompt(prompt)
        except ValueError as error:
            raise PromptEnvelopeError(str(error)) from error
        body = parsed_prompt.body
        if not body.strip():
            raise PromptEnvelopeError("Prompt body is empty after the Gota header")
        if not body.startswith(_FRONTMATTER_MARKER + "\n"):
            return cls(prompt, body, False, {}, parsed_prompt.header)

        lines = body.splitlines(keepends=True)
        if not lines or lines[0].rstrip("\r\n") != _FRONTMATTER_MARKER:
            return cls(prompt, body, False, {}, parsed_prompt.header)
        closing_index: int | None = None
        for index in range(1, len(lines)):
            if lines[index].rstrip("\r\n") == _FRONTMATTER_MARKER:
                closing_index = index
                break
        if closing_index is None:
            raise PromptEnvelopeError("TOML frontmatter has no closing +++ marker")
        header = "".join(lines[1:closing_index])
        assignment = "".join(lines[closing_index + 1 :])
        try:
            metadata = tomllib.loads(header)
        except tomllib.TOMLDecodeError as error:
            raise PromptEnvelopeError(f"Invalid TOML frontmatter: {error}") from error
        if type(metadata) is not dict:
            raise PromptEnvelopeError("TOML frontmatter must be a table")
        unknown = sorted(set(metadata) - _MUTABLE_FIELDS)
        if unknown:
            raise PromptEnvelopeError(
                f"Unsupported envelope field(s): {', '.join(unknown)}"
            )
        version = metadata.get("version")
        if type(version) is not int or version != 1:
            raise PromptEnvelopeError("Prompt envelope version must be integer 1")
        if not assignment.strip():
            raise PromptEnvelopeError("Structured prompt assignment is empty")
        return cls(prompt, assignment, True, metadata, parsed_prompt.header)

    @property
    def prompt_sha256(self) -> str:
        import hashlib

        return hashlib.sha256(self.original.encode("utf-8")).hexdigest()

    @property
    def template_id(self) -> str | None:
        value = self.metadata.get("template_id")
        return value if type(value) is str and value.strip() else None

    def require_mutable_fields(self) -> None:
        if not self.structured:
            raise PromptEnvelopeError(
                "Mutable Gota actions require a version 1 TOML envelope; plain text is read-only"
            )
        required = (
            "task_id",
            "title",
            "project_id",
            "repository_id",
            "workspace",
            "branch",
            "base_sha",
            "context_id",
            "allowed_paths",
            "protected_paths",
            "acceptance_criteria",
            "commit_message",
            "attempt",
        )
        missing = [field for field in required if field not in self.metadata]
        if missing:
            raise PromptEnvelopeError(
                "Mutable envelope is missing: " + ", ".join(missing)
            )
        if self.metadata["attempt"] != 1 or type(self.metadata["attempt"]) is not int:
            raise PromptEnvelopeError("A new mutable task must declare attempt = 1")
        for field in (
            "task_id",
            "title",
            "project_id",
            "repository_id",
            "workspace",
            "branch",
            "base_sha",
            "context_id",
            "commit_message",
        ):
            if type(self.metadata[field]) is not str or not self.metadata[field].strip():
                raise PromptEnvelopeError(f"Envelope field {field!r} must be non-empty text")
        workspace = Path(self.metadata["workspace"])
        if not workspace.is_absolute():
            raise PromptEnvelopeError("Envelope workspace must be an absolute path")
        if _SHA_RE.fullmatch(self.metadata["base_sha"]) is None:
            raise PromptEnvelopeError("Envelope base_sha must be a lowercase 40-character SHA")
        for field in ("allowed_paths", "protected_paths", "acceptance_criteria"):
            value = self.metadata[field]
            if type(value) is not list or any(
                type(item) is not str or not item.strip() for item in value
            ):
                raise PromptEnvelopeError(f"Envelope field {field!r} must be a list of text")
        if not self.metadata["allowed_paths"]:
            raise PromptEnvelopeError("Mutable envelope requires at least one allowed path")
        overlap = set(self.metadata["allowed_paths"]) & set(self.metadata["protected_paths"])
        if overlap:
            raise PromptEnvelopeError(
                "Allowed and protected paths overlap: " + ", ".join(sorted(overlap))
            )
        for path in (*self.metadata["allowed_paths"], *self.metadata["protected_paths"]):
            path_object = Path(path)
            if path_object.is_absolute() or ".." in path_object.parts:
                raise PromptEnvelopeError(f"Envelope path is not repository-relative: {path}")

    def to_task_spec(self, objective: str) -> TaskSpec:
        self.require_mutable_fields()
        spec = TaskSpec(
            task_id=self.metadata["task_id"],
            title=self.metadata["title"],
            objective=objective,
            project_id=self.metadata["project_id"],
            repository_id=self.metadata["repository_id"],
            branch=self.metadata["branch"],
            base_sha=self.metadata["base_sha"],
            context_id=self.metadata["context_id"],
            allowed_paths=tuple(self.metadata["allowed_paths"]),
            protected_paths=tuple(self.metadata["protected_paths"]),
            required_resources=(),
            acceptance_criteria=tuple(self.metadata["acceptance_criteria"]),
            commit_message=self.metadata["commit_message"],
        )
        try:
            spec.validate()
        except ValueError as error:
            raise PromptEnvelopeError(f"Invalid Coordinator task scope: {error}") from error
        return spec

    def to_gota_request(self, run_id: str, objective: str) -> GotaRequest:
        self.require_mutable_fields()
        workspace = Path(self.metadata["workspace"]).resolve()
        request = GotaRequest(
            protocol=GOTA_PROTOCOL,
            request_id=f"{run_id}:1:worker",
            task_id=self.metadata["task_id"],
            run_id=run_id,
            attempt=1,
            phase="worker",
            objective=objective,
            acceptance_criteria=tuple(self.metadata["acceptance_criteria"]),
            workspace=str(workspace),
            branch=self.metadata["branch"],
            base_sha=self.metadata["base_sha"],
            allowed_paths=tuple(self.metadata["allowed_paths"]),
            protected_paths=tuple(self.metadata["protected_paths"]),
        )
        return request

    def context_payload(self, composition: Mapping[str, Any]) -> dict[str, Any]:
        return {
            "schema": "flow.coordinator/tui-context/v1",
            "prompt": self.original,
            "assignment": self.assignment,
            "structured": self.structured,
            "gota_header": (
                {
                    "model": self.prompt_header.model,
                    "variant": self.prompt_header.variant,
                    "role": self.prompt_header.role,
                    "agent": self.prompt_header.agent,
                }
                if self.prompt_header is not None and self.prompt_header.present
                else None
            ),
            "envelope": dict(self.metadata),
            "prompt_composition": dict(composition),
        }
