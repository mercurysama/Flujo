from __future__ import annotations

import contextlib
import io
import json
import tempfile
import unittest
from pathlib import Path

from flow_coordinator.cli import main


class CoordinatorCliTest(unittest.TestCase):
    def _invoke(self, *arguments: str) -> object:
        output = io.StringIO()
        with contextlib.redirect_stdout(output):
            exit_code = main(list(arguments))
        self.assertEqual(exit_code, 0)
        return json.loads(output.getvalue())

    def test_init_status_and_inspection_commands_use_explicit_temporary_database(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            database = str(Path(directory) / "coordinator.sqlite3")
            initialized = self._invoke("--db", database, "init")
            self.assertEqual(initialized["schema_version"], 1)
            status = self._invoke("--db", database, "status")
            self.assertEqual(status["task_count"], 0)
            self.assertEqual(self._invoke("--db", database, "list-tasks"), [])
            self.assertEqual(self._invoke("--db", database, "events"), [])
            self.assertEqual(self._invoke("--db", database, "resources"), [])
            self.assertIsNone(self._invoke("--db", database, "lock")["owner_id"])

    def test_create_spec_loads_json_fixture_without_starting_execution(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            database = str(root / "coordinator.sqlite3")
            fixture = root / "task.json"
            fixture.write_text(
                json.dumps(
                    {
                        "task_id": "fixture-task",
                        "title": "Fixture",
                        "objective": "Load a local fixture",
                        "project_id": "project",
                        "repository_id": "repository",
                        "branch": "feature/fixture",
                        "base_sha": "a" * 40,
                        "context_id": "context",
                        "allowed_paths": ["src/file.py"],
                        "protected_paths": ["demo/main.tscn"],
                        "required_resources": [],
                        "acceptance_criteria": ["Loaded"],
                        "commit_message": "test: fixture"
                    }
                ),
                encoding="utf-8",
            )
            created = self._invoke("--db", database, "create-spec", str(fixture))
            self.assertEqual(created["created"], "fixture-task")
            listed = self._invoke("--db", database, "list-tasks")
            self.assertEqual(listed[0]["task_id"], "fixture-task")


if __name__ == "__main__":
    unittest.main()
