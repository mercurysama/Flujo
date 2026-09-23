"""Minimal local CLI for storage inspection and core fixtures."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any

from .domain import TaskSpec
from .lock import GlobalLockManager
from .store import SQLiteCoordinatorStore


DEFAULT_DATABASE = Path.home() / ".local/state/flow-coordinator/coordinator.sqlite3"


def _task_spec_from_json(payload: dict[str, Any]) -> TaskSpec:
    return TaskSpec(
        task_id=payload["task_id"],
        title=payload["title"],
        objective=payload["objective"],
        project_id=payload["project_id"],
        repository_id=payload["repository_id"],
        branch=payload["branch"],
        base_sha=payload["base_sha"],
        context_id=payload["context_id"],
        allowed_paths=tuple(payload.get("allowed_paths", ())),
        protected_paths=tuple(payload.get("protected_paths", ())),
        required_resources=tuple(payload.get("required_resources", ())),
        acceptance_criteria=tuple(payload.get("acceptance_criteria", ())),
        commit_message=payload["commit_message"],
    )


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(prog="flow-coordinator")
    parser.add_argument("--db", type=Path, default=DEFAULT_DATABASE)
    subcommands = parser.add_subparsers(dest="command", required=True)
    subcommands.add_parser("init")
    subcommands.add_parser("status")
    create = subcommands.add_parser("create-spec")
    create.add_argument("json_file", type=Path)
    subcommands.add_parser("list-tasks")
    events = subcommands.add_parser("events")
    events.add_argument("--run-id")
    subcommands.add_parser("lock")
    subcommands.add_parser("resources")
    return parser


def main(arguments: list[str] | None = None) -> int:
    options = build_parser().parse_args(arguments)
    store = SQLiteCoordinatorStore(options.db)
    output: Any
    if options.command == "init":
        output = {"database": str(options.db), "schema_version": store.schema_version()}
    elif options.command == "status":
        output = {
            "schema_version": store.schema_version(),
            "task_count": len(store.list_task_specs()),
            "run_count": len(store.list_runs()),
            "lock": GlobalLockManager(store).inspect(),
        }
    elif options.command == "create-spec":
        payload = json.loads(options.json_file.read_text(encoding="utf-8"))
        spec = _task_spec_from_json(payload)
        store.create_task_spec(spec)
        output = {"created": spec.task_id}
    elif options.command == "list-tasks":
        output = [
            {
                "task_id": spec.task_id,
                "project_id": spec.project_id,
                "branch": spec.branch,
            }
            for spec in store.list_task_specs()
        ]
    elif options.command == "events":
        output = [
            {
                "event_id": event.event_id,
                "run_id": event.run_id,
                "from": event.from_state.value if event.from_state else None,
                "to": event.to_state.value,
                "reason": event.reason,
            }
            for event in store.list_events(options.run_id)
        ]
    elif options.command == "lock":
        output = GlobalLockManager(store).inspect()
    elif options.command == "resources":
        output = [
            {
                "resource_id": resource.resource_id,
                "cooldown_required": resource.cooldown_required,
                "minimum_seconds": resource.minimum_seconds,
                "state": resource.state.value if resource.state else None,
                "not_before": (
                    resource.not_before.isoformat() if resource.not_before else None
                ),
            }
            for resource in store.list_resources()
        ]
    else:
        raise AssertionError(options.command)
    print(json.dumps(output, indent=2, sort_keys=True, default=str))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
