from __future__ import annotations

import tempfile
import unittest
from pathlib import Path

from flow_coordinator.domain import TaskSpec
from flow_coordinator.service import CoordinatorService
from flow_coordinator.store import SQLiteCoordinatorStore


def make_spec(
    task_id: str,
    *,
    project_id: str = "project-a",
    required_resources: tuple[str, ...] = (),
    allowed_paths: tuple[str, ...] = ("src/change.py",),
) -> TaskSpec:
    return TaskSpec(
        task_id=task_id,
        title=f"Task {task_id}",
        objective="Exercise the local coordinator core",
        project_id=project_id,
        repository_id=f"repo-{project_id}",
        branch=f"feature/{task_id}",
        base_sha="a" * 40,
        context_id=f"context-{task_id}",
        allowed_paths=allowed_paths,
        protected_paths=("demo/main.tscn", "export_presets.cfg"),
        required_resources=required_resources,
        acceptance_criteria=("All focal checks pass",),
        commit_message=f"test: complete {task_id}",
    )


class CoordinatorTestCase(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary_directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary_directory.cleanup)
        self.root = Path(self.temporary_directory.name)
        self.database = self.root / "coordinator.sqlite3"
        self.store = SQLiteCoordinatorStore(self.database)
        self.service = CoordinatorService(self.store)

    def create_task(self, task_id: str, **kwargs: object):
        spec = make_spec(task_id, **kwargs)
        run = self.service.create_task(
            spec,
            {"workspace": f"/temporary/{spec.project_id}", "task": task_id},
        )
        return spec, run
