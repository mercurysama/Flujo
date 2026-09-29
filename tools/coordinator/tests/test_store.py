from __future__ import annotations

import sqlite3

from flow_coordinator.domain import ProjectBinding, TaskState
from flow_coordinator.executor import FakeExecutor
from flow_coordinator.store import SQLiteCoordinatorStore

from support import CoordinatorTestCase


class SQLiteStoreTest(CoordinatorTestCase):
    def test_schema_contains_every_required_operational_table(self) -> None:
        self.assertTrue(
            {
                "schema_migrations",
                "task_specs",
                "task_runs",
                "contexts",
                "dependencies",
                "transition_events",
                "evidence",
                "checkpoints",
                "resource_attempts",
                "coordinator_resources",
                "global_lock",
                "project_bindings",
            }.issubset(set(self.store.table_names()))
        )
        self.assertEqual(self.store.schema_version(), 1)

    def test_state_persists_after_coordinator_restart(self) -> None:
        spec, run = self.create_task("persistent")
        self.store.bind_project(
            ProjectBinding(
                project_id=spec.project_id,
                repository_id=spec.repository_id,
                workspace_path="/isolated/project-a",
                context_id=spec.context_id,
            )
        )
        reopened = SQLiteCoordinatorStore(self.database)
        self.assertEqual(reopened.get_task_spec(spec.task_id), spec)
        self.assertEqual(reopened.get_run(run.run_id).state, TaskState.ASSIGNED)
        self.assertEqual(
            reopened.get_project_binding(spec.project_id).workspace_path,
            "/isolated/project-a",
        )

    def test_evidence_and_events_are_append_only(self) -> None:
        _, run = self.create_task("immutable")
        lease = self.service.start(run.run_id, owner_id="worker")
        evidence = self.store.append_evidence(
            run.run_id, "command", {"exit_code": 0}, lease
        )
        with self.assertRaises(sqlite3.IntegrityError):
            with self.store.transaction(immediate=True) as connection:
                connection.execute(
                    "UPDATE evidence SET kind = 'changed' WHERE evidence_id = ?",
                    (evidence.evidence_id,),
                )
        event_id = self.store.list_events(run.run_id)[0].event_id
        with self.assertRaises(sqlite3.IntegrityError):
            with self.store.transaction(immediate=True) as connection:
                connection.execute(
                    "DELETE FROM transition_events WHERE event_id = ?", (event_id,)
                )

    def test_checkpoints_resume_without_repeating_confirmed_steps(self) -> None:
        _, run = self.create_task("recover")
        lease = self.service.start(run.run_id, owner_id="worker")
        executor = FakeExecutor(self.store)
        calls: list[str] = []
        steps = (
            ("inspect", lambda: calls.append("inspect")),
            ("edit", lambda: calls.append("edit")),
        )
        self.assertEqual(executor.execute_steps(run.run_id, lease, steps), ("inspect", "edit"))
        self.assertEqual(executor.execute_steps(run.run_id, lease, steps), ())
        self.assertEqual(calls, ["inspect", "edit"])
        checkpoint = self.store.latest_checkpoint(run.run_id)
        self.assertEqual(checkpoint.payload["confirmed_steps"], ["inspect", "edit"])

    def test_checkpoint_is_immutable_and_recoverable_after_reopen(self) -> None:
        _, run = self.create_task("checkpoint")
        lease = self.service.start(run.run_id, owner_id="worker")
        checkpoint = self.store.append_checkpoint(
            run.run_id, {"confirmed_steps": ["one"]}, lease
        )
        reopened = SQLiteCoordinatorStore(self.database)
        self.assertEqual(
            reopened.latest_checkpoint(run.run_id).digest,
            checkpoint.digest,
        )
        with self.assertRaises(sqlite3.IntegrityError):
            with reopened.transaction(immediate=True) as connection:
                connection.execute(
                    "UPDATE checkpoints SET payload_json = '{}' WHERE checkpoint_id = ?",
                    (checkpoint.checkpoint_id,),
                )

    def test_projects_with_same_task_shape_remain_isolated(self) -> None:
        spec_a, run_a = self.create_task("alpha", project_id="project-a")
        spec_b, run_b = self.create_task("beta", project_id="project-b")
        self.assertNotEqual(spec_a.context_id, spec_b.context_id)
        self.assertNotEqual(run_a.run_id, run_b.run_id)
        self.assertEqual(self.store.get_context(spec_a.context_id).project_id, "project-a")
        self.assertEqual(self.store.get_context(spec_b.context_id).project_id, "project-b")


if __name__ == "__main__":
    import unittest

    unittest.main()
