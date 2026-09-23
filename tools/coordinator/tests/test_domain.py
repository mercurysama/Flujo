from __future__ import annotations

import json
import unittest
from pathlib import Path

from flow_coordinator.domain import ResourceState, TaskState
from flow_coordinator.state_machine import (
    VALID_TRANSITIONS,
    InvalidTransitionError,
    validate_transition,
)

from support import make_spec


class DomainStateMachineTest(unittest.TestCase):
    def test_every_declared_transition_is_valid(self) -> None:
        for from_state, destinations in VALID_TRANSITIONS.items():
            with self.subTest(from_state=from_state):
                for to_state in destinations:
                    validate_transition(from_state, to_state)

    def test_every_undeclared_transition_is_rejected(self) -> None:
        for from_state in TaskState:
            for to_state in TaskState:
                if to_state in VALID_TRANSITIONS[from_state]:
                    continue
                with self.subTest(from_state=from_state, to_state=to_state):
                    with self.assertRaises(InvalidTransitionError):
                        validate_transition(from_state, to_state)

    def test_terminal_states_have_no_outgoing_transitions(self) -> None:
        self.assertTrue(TaskState.DONE.terminal)
        self.assertTrue(TaskState.CANCELLED.terminal)
        self.assertEqual(VALID_TRANSITIONS[TaskState.DONE], frozenset())
        self.assertEqual(VALID_TRANSITIONS[TaskState.CANCELLED], frozenset())
        for state in TaskState:
            if state not in {TaskState.DONE, TaskState.CANCELLED}:
                self.assertFalse(state.terminal)

    def test_official_symbols_are_exact_and_cooldown_is_not_a_task_state(self) -> None:
        self.assertEqual(
            {state.value: state.symbol for state in TaskState},
            {
                "ASSIGNED": "🌊",
                "RUNNING": "🛠",
                "REVIEW": "👀",
                "DONE": "🙆🏻",
                "NOT_COMPLETED": "🙅🏻",
                "BLOCKED": "⛔",
                "CANCELLED": "❌",
            },
        )
        self.assertEqual(ResourceState.COOLDOWN.symbol, "❤️‍🔥")
        self.assertNotIn("COOLDOWN", {state.value for state in TaskState})

    def test_task_spec_rejects_protected_allowed_overlap(self) -> None:
        spec = make_spec("overlap", allowed_paths=("demo/main.tscn",))
        with self.assertRaisesRegex(ValueError, "both allowed and protected"):
            spec.validate()

    def test_task_spec_rejects_non_relative_paths(self) -> None:
        spec = make_spec("absolute", allowed_paths=("/tmp/change.py",))
        with self.assertRaisesRegex(ValueError, "repository-relative"):
            spec.validate()

    def test_versioned_json_schemas_are_valid_and_have_unique_ids(self) -> None:
        schema_directory = Path(__file__).resolve().parents[1] / "schemas"
        schemas = [
            json.loads(path.read_text(encoding="utf-8"))
            for path in sorted(schema_directory.glob("*.schema.json"))
        ]
        self.assertEqual(len(schemas), 4)
        identifiers = [schema["$id"] for schema in schemas]
        self.assertEqual(len(identifiers), len(set(identifiers)))
        self.assertTrue(all(identifier.endswith("/v1") for identifier in identifiers))

    def test_coordinator_package_has_no_godot_or_plugin_dependency(self) -> None:
        source_directory = Path(__file__).resolve().parents[1] / "src/flow_coordinator"
        source = "\n".join(
            path.read_text(encoding="utf-8")
            for path in sorted(source_directory.glob("*.py"))
        ).lower()
        self.assertNotIn("addons/vp_flujo", source)
        self.assertNotIn("import godot", source)


if __name__ == "__main__":
    unittest.main()
