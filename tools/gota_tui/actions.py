"""Declarative action registry for the production Gota TUI."""

from __future__ import annotations

import tomllib
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Mapping


class ActionRegistryError(ValueError):
    """Raised when action configuration is invalid or ambiguous."""


KNOWN_BACKENDS = frozenset(
    {
        "gota-task",
        "opencode-direct",
        "opencode-readonly",
        "gota-review",
        "git-audit",
        "production-validation",
        "coordinator-tests",
        "diagnostics",
        "recovery-readonly",
        "coordinator-status",
        "history",
    }
)
KNOWN_PROMPT_SOURCES = frozenset({"", "clipboard"})
KNOWN_CONFIRMATION_MODES = frozenset({"explicit", "selection"})


@dataclass(frozen=True, slots=True)
class ActionDefinition:
    """One explicitly allowed user action."""

    id: str
    label: str
    backend: str
    mutable: bool
    requires_prompt: bool
    prompt_source: str
    requires_confirmation: bool
    confirmation_mode: str
    agent: str
    model: str
    variant: str
    template: str
    description: str

    @classmethod
    def from_mapping(cls, value: Mapping[str, Any]) -> "ActionDefinition":
        required_text = (
            "id",
            "label",
            "backend",
            "agent",
            "model",
            "variant",
            "template",
            "description",
        )
        for field in required_text:
            if type(value.get(field)) is not str:
                raise ActionRegistryError(f"Action field {field!r} must be a string")

        prompt_source = value.get("prompt_source", "")
        if type(prompt_source) is not str:
            raise ActionRegistryError("Action field 'prompt_source' must be a string")
        confirmation_mode = value.get("confirmation_mode", "explicit")
        if type(confirmation_mode) is not str:
            raise ActionRegistryError("Action field 'confirmation_mode' must be a string")

        for field in ("mutable", "requires_prompt", "requires_confirmation"):
            if type(value.get(field)) is not bool:
                raise ActionRegistryError(f"Action field {field!r} must be boolean")

        action = cls(
            id=value["id"],
            label=value["label"],
            backend=value["backend"],
            mutable=value["mutable"],
            requires_prompt=value["requires_prompt"],
            prompt_source=prompt_source,
            requires_confirmation=value["requires_confirmation"],
            confirmation_mode=confirmation_mode,
            agent=value["agent"],
            model=value["model"],
            variant=value["variant"],
            template=value["template"],
            description=value["description"],
        )
        action.validate()
        return action

    def validate(self) -> None:
        for field in ("id", "label", "description"):
            if not getattr(self, field).strip():
                raise ActionRegistryError(f"Action {field!r} cannot be blank")
        if any(character.isspace() for character in self.id):
            raise ActionRegistryError(f"Action id contains whitespace: {self.id!r}")
        if self.backend not in KNOWN_BACKENDS:
            raise ActionRegistryError(
                f"Action {self.id!r} uses unknown backend {self.backend!r}"
            )
        if self.prompt_source not in KNOWN_PROMPT_SOURCES:
            raise ActionRegistryError(
                f"Action {self.id!r} uses unknown prompt source {self.prompt_source!r}"
            )
        if self.confirmation_mode not in KNOWN_CONFIRMATION_MODES:
            raise ActionRegistryError(
                f"Action {self.id!r} uses unknown confirmation mode "
                f"{self.confirmation_mode!r}"
            )
        if self.requires_prompt and not self.prompt_source:
            raise ActionRegistryError(
                f"Prompt action {self.id!r} requires a prompt source"
            )
        if not self.requires_prompt and self.prompt_source:
            raise ActionRegistryError(
                f"Action {self.id!r} cannot define a prompt source without requiring a prompt"
            )
        if self.confirmation_mode == "selection":
            if not self.requires_confirmation:
                raise ActionRegistryError(
                    f"Selection-confirmed action {self.id!r} must require confirmation"
                )
            if self.mutable:
                raise ActionRegistryError(
                    f"Mutable action {self.id!r} cannot use selection confirmation"
                )
        elif self.requires_confirmation is False and self.confirmation_mode != "explicit":
            raise ActionRegistryError(
                f"Non-confirming action {self.id!r} must use explicit confirmation mode"
            )
        if self.backend in {"gota-task", "gota-review"} and not self.mutable:
            raise ActionRegistryError(
                f"Coordinator Gota action {self.id!r} must be marked mutable"
            )
        if self.backend in {"gota-task", "gota-review"} and not self.requires_confirmation:
            raise ActionRegistryError(
                f"Coordinator Gota action {self.id!r} must require confirmation"
            )
        if self.mutable and not self.requires_confirmation:
            raise ActionRegistryError(
                f"Mutable action {self.id!r} must require confirmation"
            )
        if self.mutable and not self.requires_prompt:
            raise ActionRegistryError(
                f"Mutable action {self.id!r} must require a prompt"
            )
        if self.backend in {"gota-task", "gota-review"}:
            if not self.agent.strip() or not self.model.strip() or not self.variant.strip():
                raise ActionRegistryError(
                    f"OpenCode action {self.id!r} requires agent, model, and variant"
                )
        if self.backend in {"opencode-direct", "opencode-readonly"}:
            if self.mutable:
                raise ActionRegistryError(
                    f"Read-only OpenCode action {self.id!r} cannot be a Coordinator task"
                )
            if not self.agent.strip() or not self.model.strip() or not self.variant.strip():
                raise ActionRegistryError(
                    f"OpenCode action {self.id!r} requires agent, model, and variant"
                )
        if self.backend == "opencode-readonly" and not self.requires_confirmation:
            raise ActionRegistryError(
                f"Read-only OpenCode audit {self.id!r} must require confirmation"
            )
        if self.backend == "opencode-readonly" and not self.requires_prompt:
            raise ActionRegistryError(
                f"Read-only OpenCode audit {self.id!r} must require a prompt"
            )
        if self.backend in {
            "gota-task",
            "gota-review",
            "git-audit",
            "opencode-direct",
            "opencode-readonly",
        }:
            if not self.template.strip():
                if self.backend not in {"opencode-direct", "opencode-readonly"}:
                    raise ActionRegistryError(
                        f"Prompt action {self.id!r} requires a template"
                    )


class ActionRegistry:
    """Validated, immutable-by-convention collection of actions."""

    def __init__(self, actions: tuple[ActionDefinition, ...], *, version: int = 1) -> None:
        if version != 1:
            raise ActionRegistryError(f"Unsupported action registry version: {version}")
        ids = [action.id for action in actions]
        if len(ids) != len(set(ids)):
            raise ActionRegistryError("Action IDs must be unique")
        self.version = version
        self.actions = actions
        self._by_id = {action.id: action for action in actions}

    @classmethod
    def load(cls, path: str | Path) -> "ActionRegistry":
        registry_path = Path(path)
        try:
            with registry_path.open("rb") as file:
                payload = tomllib.load(file)
        except (OSError, tomllib.TOMLDecodeError) as error:
            raise ActionRegistryError(
                f"Cannot load action registry {registry_path}: {error}"
            ) from error
        return cls.from_mapping(payload)

    @classmethod
    def from_mapping(cls, payload: Mapping[str, Any]) -> "ActionRegistry":
        version = payload.get("version")
        if type(version) is not int:
            raise ActionRegistryError("Action registry version must be an integer")
        raw_actions = payload.get("actions")
        if type(raw_actions) is not list or not raw_actions:
            raise ActionRegistryError("Action registry must contain actions")
        actions: list[ActionDefinition] = []
        for index, raw_action in enumerate(raw_actions):
            if not isinstance(raw_action, Mapping):
                raise ActionRegistryError(f"Action at index {index} must be a table")
            actions.append(ActionDefinition.from_mapping(raw_action))
        return cls(tuple(actions), version=version)

    @classmethod
    def default(cls, base_directory: str | Path | None = None) -> "ActionRegistry":
        base = Path(base_directory) if base_directory is not None else Path(__file__).parent
        return cls.load(base / "actions.toml")

    def get(self, action_id: str) -> ActionDefinition:
        try:
            return self._by_id[action_id]
        except KeyError as error:
            raise ActionRegistryError(f"Unknown action: {action_id}") from error

    def __iter__(self):
        return iter(self.actions)

    def __len__(self) -> int:
        return len(self.actions)
