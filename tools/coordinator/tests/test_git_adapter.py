from __future__ import annotations

import subprocess
import tempfile
import unittest
from pathlib import Path

from flow_coordinator.git_adapter import GitReadError, ReadOnlyGitAdapter


REPOSITORY_ROOT = Path(__file__).resolve().parents[3]


def _git(repository: Path, *arguments: str) -> str:
    result = subprocess.run(
        ("git", *arguments),
        cwd=repository,
        check=True,
        capture_output=True,
        text=True,
    )
    return result.stdout.rstrip("\n")


class ReadOnlyGitAdapterTest(unittest.TestCase):
    def test_adapter_reads_temporary_fixture_without_mutating_it(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            repository = Path(directory)
            _git(repository, "init", "--initial-branch=main")
            _git(repository, "config", "user.name", "Coordinator Test")
            _git(repository, "config", "user.email", "coordinator@example.invalid")
            fixture = repository / "fixture.txt"
            fixture.write_text("fixture\n", encoding="utf-8")
            _git(repository, "add", "fixture.txt")
            _git(repository, "commit", "-m", "fixture")
            before = _git(repository, "status", "--porcelain=v1")
            adapter = ReadOnlyGitAdapter(repository)
            snapshot = adapter.snapshot()
            after = _git(repository, "status", "--porcelain=v1")
            self.assertEqual(snapshot.branch, "main")
            self.assertEqual(snapshot.head, _git(repository, "rev-parse", "HEAD"))
            self.assertEqual(before, after)

    def test_adapter_exposes_no_mutating_git_command(self) -> None:
        adapter = ReadOnlyGitAdapter(REPOSITORY_ROOT)
        with self.assertRaisesRegex(GitReadError, "read-only"):
            adapter._run("commit", "-m", "forbidden")

    def test_real_flujo_working_tree_is_identical_after_inspection(self) -> None:
        before_head = _git(REPOSITORY_ROOT, "rev-parse", "HEAD")
        before_status = _git(
            REPOSITORY_ROOT, "status", "--porcelain=v1", "--untracked-files=all"
        )
        snapshot = ReadOnlyGitAdapter(REPOSITORY_ROOT).snapshot()
        after_head = _git(REPOSITORY_ROOT, "rev-parse", "HEAD")
        after_status = _git(
            REPOSITORY_ROOT, "status", "--porcelain=v1", "--untracked-files=all"
        )
        self.assertEqual(snapshot.head, before_head)
        self.assertEqual(after_head, before_head)
        self.assertEqual(after_status, before_status)

    def test_every_database_and_repository_fixture_lives_in_temporary_storage(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            temporary_root = Path(directory).resolve()
            self.assertTrue(str(temporary_root).startswith("/tmp/"))
            self.assertNotEqual(temporary_root, REPOSITORY_ROOT)


if __name__ == "__main__":
    unittest.main()
