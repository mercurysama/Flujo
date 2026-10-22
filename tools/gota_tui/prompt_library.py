"""Versioned prompt-template support."""

from __future__ import annotations

import hashlib
import tomllib
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Mapping


class PromptTemplateError(ValueError):
    """Raised when a prompt template is missing or malformed."""


@dataclass(frozen=True, slots=True)
class PromptTemplate:
    id: str
    version: int
    body: str


@dataclass(frozen=True, slots=True)
class PromptComposition:
    template_id: str
    template_version: int
    template_body: str
    assignment: str
    combined: str
    sha256: str


class PromptLibrary:
    def __init__(self, templates: tuple[PromptTemplate, ...]) -> None:
        ids = [template.id for template in templates]
        if len(ids) != len(set(ids)):
            raise PromptTemplateError("Prompt template IDs must be unique")
        self.templates = templates
        self._by_id = {template.id: template for template in templates}

    @classmethod
    def load(cls, directory: str | Path) -> "PromptLibrary":
        root = Path(directory)
        templates: list[PromptTemplate] = []
        try:
            paths = sorted(root.glob("*.toml"))
        except OSError as error:
            raise PromptTemplateError(f"Cannot inspect prompt library {root}: {error}") from error
        if not paths:
            raise PromptTemplateError(f"Prompt library is empty: {root}")
        for path in paths:
            try:
                with path.open("rb") as file:
                    payload = tomllib.load(file)
            except (OSError, tomllib.TOMLDecodeError) as error:
                raise PromptTemplateError(f"Cannot load prompt template {path}: {error}") from error
            templates.append(cls._template_from_mapping(payload, path))
        return cls(tuple(templates))

    @staticmethod
    def _template_from_mapping(
        payload: Mapping[str, Any], path: Path
    ) -> PromptTemplate:
        if type(payload.get("version")) is not int:
            raise PromptTemplateError(f"Template {path} version must be an integer")
        if type(payload.get("id")) is not str or not payload["id"].strip():
            raise PromptTemplateError(f"Template {path} id must be non-empty")
        if type(payload.get("body")) is not str or not payload["body"].strip():
            raise PromptTemplateError(f"Template {path} body must be non-empty")
        if payload["version"] < 1:
            raise PromptTemplateError(f"Template {path} version must be positive")
        return PromptTemplate(payload["id"], payload["version"], payload["body"])

    @classmethod
    def default(cls, base_directory: str | Path | None = None) -> "PromptLibrary":
        base = Path(base_directory) if base_directory is not None else Path(__file__).parent / "prompts"
        return cls.load(base)

    def get(self, template_id: str) -> PromptTemplate:
        try:
            return self._by_id[template_id]
        except KeyError as error:
            raise PromptTemplateError(f"Unknown prompt template: {template_id}") from error

    def compose(self, template_id: str, assignment: str) -> PromptComposition:
        if type(assignment) is not str or not assignment.strip():
            raise PromptTemplateError("Prompt assignment cannot be empty")
        template = self.get(template_id)
        combined = (
            f"TEMPLATE_ID={template.id}\n"
            f"TEMPLATE_VERSION={template.version}\n"
            "TEMPLATE_BEGIN\n"
            f"{template.body.rstrip()}\n"
            "TEMPLATE_END\n"
            "ASSIGNMENT_BEGIN\n"
            f"{assignment}"
            "\nASSIGNMENT_END"
        )
        digest = hashlib.sha256(combined.encode("utf-8")).hexdigest()
        return PromptComposition(
            template_id=template.id,
            template_version=template.version,
            template_body=template.body,
            assignment=assignment,
            combined=combined,
            sha256=digest,
        )
