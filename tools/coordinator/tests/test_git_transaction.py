from __future__ import annotations

import subprocess
from dataclasses import replace
from datetime import UTC, datetime, timedelta
from pathlib import Path

from flow_coordinator.domain import TaskState
from flow_coordinator.git_transaction import (
    AmbiguousRepositoryError,
    CommitManifestMismatchError,
    CommitOwnershipError,
    CommitParentMismatchError,
    GitAcceptancePhase,
    GitAcceptanceWorkflow,
    MutationBoundaryError,
    ProtectedPathError,
    TransactionalGitAdapter,
    UnauthorizedPathError,
    UnexpectedHeadError,
)
from flow_coordinator.store import FencingTokenError, LeaseExpiredError

from support import CoordinatorTestCase, make_spec


REPOSITORY_ROOT = Path(__file__).resolve().parents[3]


class PlannedInterruption(RuntimeError):
    pass


class MutableGitAcceptanceTest(CoordinatorTestCase):
    def _git(self, *arguments: str) -> str:
        result = subprocess.run(
            ("git", *arguments),
            cwd=self.repository,
            check=True,
            capture_output=True,
            text=True,
        )
        return result.stdout.rstrip("\n")

    def setUp(self) -> None:
        super().setUp()
        self.repository = self.root / "repository"
        self.repository.mkdir()
        self._git("init", "--initial-branch=feature/git-task")
        self._git("config", "user.name", "Coordinator Fixture")
        self._git("config", "user.email", "coordinator@example.invalid")
        (self.repository / "src").mkdir()
        (self.repository / "demo").mkdir()
        (self.repository / "src/change.py").write_text("value = 1\n", encoding="utf-8")
        (self.repository / "demo/main.tscn").write_text("[gd_scene]\n", encoding="utf-8")
        (self.repository / "export_presets.cfg").write_text("[preset.0]\n", encoding="utf-8")
        self._git("add", "--", "src/change.py", "demo/main.tscn", "export_presets.cfg")
        self._git("commit", "-m", "fixture base")
        self.base_sha = self._git("rev-parse", "HEAD")
        self.adapter = TransactionalGitAdapter(
            self.repository, authorized_root=self.root
        )
        self.workflow = GitAcceptanceWorkflow(self.store)

    def _prepare_review(self, task_id: str = "git-task", **start_options: object):
        spec = replace(
            make_spec(task_id),
            branch="feature/git-task",
            base_sha=self.base_sha,
        )
        run = self.service.create_task(spec, {"repository": str(self.repository)})
        lease = self.service.start(run.run_id, owner_id="git-worker", **start_options)
        (self.repository / "src/change.py").write_text("value = 2\n", encoding="utf-8")
        self.service.complete_execution(
            run.run_id,
            lease,
            now=start_options.get("now"),
        )
        return spec, run, lease

    @staticmethod
    def _interrupt_at(target: GitAcceptancePhase):
        def hook(phase: GitAcceptancePhase) -> None:
            if phase is target:
                raise PlannedInterruption(phase.value)

        return hook

    def _accept(self, run_id: str, lease, **options: object):
        return self.workflow.accept(
            run_id,
            lease,
            self.adapter,
            staged_paths=("src/change.py",),
            microaudit={"passed": True, "scope": "fixture"},
            **options,
        )

    def _commit_count(self) -> int:
        return int(self._git("rev-list", "--count", f"{self.base_sha}..HEAD"))

    def test_acceptance_stages_only_authorized_path_and_commits_exactly_once(self) -> None:
        spec, run, lease = self._prepare_review()
        accepted, commit_sha = self._accept(run.run_id, lease)
        self.assertEqual(accepted.state, TaskState.DONE)
        self.assertEqual(commit_sha, self._git("rev-parse", "HEAD"))
        self.assertEqual(self._commit_count(), 1)
        self.assertEqual(self._git("diff", "--cached", "--name-only"), "")
        self.assertEqual(
            self._git("show", "--format=", "--name-only", "HEAD"),
            "src/change.py",
        )
        body = self._git("show", "-s", "--format=%B", "HEAD")
        self.assertIn(f"Coordinator-Task-ID: {spec.task_id}", body)
        self.assertIn(f"Coordinator-Run-ID: {run.run_id}", body)
        evidence = self.store.list_evidence(run.run_id)
        staging = next(item for item in evidence if item.kind == "selective_staging")
        commit = next(item for item in evidence if item.kind == "local_commit")
        self.assertEqual(staging.payload["paths"], ["src/change.py"])
        self.assertEqual(commit.payload["sha"], commit_sha)
        self.assertEqual(commit.payload["manifest"], staging.payload["manifest"])

    def test_recovery_before_staging_does_not_repeat_confirmed_review(self) -> None:
        _, run, lease = self._prepare_review()
        with self.assertRaises(PlannedInterruption):
            self._accept(
                run.run_id,
                lease,
                progress_hook=self._interrupt_at(GitAcceptancePhase.REVIEW_VERIFIED),
            )
        self.assertEqual(self._git("diff", "--cached", "--name-only"), "")
        self.assertEqual(len(self.store.list_evidence(run.run_id)), 1)
        accepted, _ = self._accept(run.run_id, lease)
        self.assertEqual(accepted.state, TaskState.DONE)
        self.assertEqual(self._commit_count(), 1)
        self.assertEqual(
            [item.kind for item in self.store.list_evidence(run.run_id)].count("microaudit"),
            1,
        )

    def test_recovery_with_existing_staging_reuses_exact_manifest(self) -> None:
        _, run, lease = self._prepare_review()
        with self.assertRaises(PlannedInterruption):
            self._accept(
                run.run_id,
                lease,
                progress_hook=self._interrupt_at(GitAcceptancePhase.STAGED),
            )
        staged_before = self._git("diff", "--cached", "--binary", "--full-index")
        self.assertIn("src/change.py", staged_before)
        accepted, _ = self._accept(run.run_id, lease)
        self.assertEqual(accepted.state, TaskState.DONE)
        self.assertEqual(self._commit_count(), 1)
        self.assertEqual(
            [item.kind for item in self.store.list_evidence(run.run_id)].count(
                "selective_staging"
            ),
            1,
        )

    def test_confirmed_staging_is_not_repeated_when_index_disappears(self) -> None:
        _, run, lease = self._prepare_review()
        with self.assertRaises(PlannedInterruption):
            self._accept(
                run.run_id,
                lease,
                progress_hook=self._interrupt_at(GitAcceptancePhase.STAGED),
            )
        self._git("reset", "--mixed", "HEAD")
        with self.assertRaisesRegex(
            CommitManifestMismatchError, "no longer present"
        ):
            self._accept(run.run_id, lease)
        self.assertEqual(self._git("diff", "--cached", "--name-only"), "")
        self.assertEqual(self.store.get_run(run.run_id).state, TaskState.REVIEW)

    def test_recovery_after_commit_before_sha_registration_reuses_commit(self) -> None:
        _, run, lease = self._prepare_review()
        with self.assertRaises(PlannedInterruption):
            self._accept(
                run.run_id,
                lease,
                progress_hook=self._interrupt_at(GitAcceptancePhase.COMMIT_CREATED),
            )
        created_sha = self._git("rev-parse", "HEAD")
        self.assertEqual(self._commit_count(), 1)
        self.assertNotIn(
            "local_commit", [item.kind for item in self.store.list_evidence(run.run_id)]
        )
        accepted, recovered_sha = self._accept(run.run_id, lease)
        self.assertEqual(accepted.state, TaskState.DONE)
        self.assertEqual(recovered_sha, created_sha)
        self.assertEqual(self._commit_count(), 1)

    def test_recovery_after_sha_registration_detects_existing_record(self) -> None:
        _, run, lease = self._prepare_review()
        with self.assertRaises(PlannedInterruption):
            self._accept(
                run.run_id,
                lease,
                progress_hook=self._interrupt_at(GitAcceptancePhase.COMMIT_RECORDED),
            )
        created_sha = self._git("rev-parse", "HEAD")
        self.assertEqual(
            [item.kind for item in self.store.list_evidence(run.run_id)].count(
                "local_commit"
            ),
            1,
        )
        accepted, recovered_sha = self._accept(run.run_id, lease)
        self.assertEqual(accepted.state, TaskState.DONE)
        self.assertEqual(recovered_sha, created_sha)
        self.assertEqual(self._commit_count(), 1)
        self.assertEqual(
            [item.kind for item in self.store.list_evidence(run.run_id)].count(
                "local_commit"
            ),
            1,
        )

    def test_protected_path_is_rejected_without_staging(self) -> None:
        _, run, lease = self._prepare_review()
        (self.repository / "demo/main.tscn").write_text("changed\n", encoding="utf-8")
        with self.assertRaises(ProtectedPathError):
            self.workflow.accept(
                run.run_id,
                lease,
                self.adapter,
                staged_paths=("demo/main.tscn",),
                microaudit={"passed": True},
            )
        self.assertEqual(self._git("diff", "--cached", "--name-only"), "")
        self.assertEqual(self.store.get_run(run.run_id).state, TaskState.REVIEW)

    def test_unauthorized_path_is_rejected_without_staging(self) -> None:
        _, run, lease = self._prepare_review()
        (self.repository / "other.txt").write_text("other\n", encoding="utf-8")
        with self.assertRaises(UnauthorizedPathError):
            self.workflow.accept(
                run.run_id,
                lease,
                self.adapter,
                staged_paths=("other.txt",),
                microaudit={"passed": True},
            )
        self.assertEqual(self._git("diff", "--cached", "--name-only"), "")

    def test_unrelated_worktree_change_is_rejected_as_ambiguous(self) -> None:
        _, run, lease = self._prepare_review()
        (self.repository / "other.txt").write_text("other\n", encoding="utf-8")
        with self.assertRaises(AmbiguousRepositoryError):
            self._accept(run.run_id, lease)
        self.assertEqual(self._git("diff", "--cached", "--name-only"), "")

    def test_foreign_index_content_is_preserved_and_rejected(self) -> None:
        _, run, lease = self._prepare_review()
        (self.repository / "other.txt").write_text("other\n", encoding="utf-8")
        self._git("add", "--", "other.txt")
        with self.assertRaises(AmbiguousRepositoryError):
            self._accept(run.run_id, lease)
        self.assertEqual(self._git("diff", "--cached", "--name-only"), "other.txt")
        self.assertEqual(self.store.get_run(run.run_id).state, TaskState.REVIEW)

    def test_unexpected_head_is_rejected(self) -> None:
        _, run, lease = self._prepare_review()
        self._git("add", "--", "src/change.py")
        self._git("commit", "-m", "unexpected external commit")
        with self.assertRaises(UnexpectedHeadError):
            self._accept(run.run_id, lease)
        self.assertEqual(self.store.get_run(run.run_id).state, TaskState.REVIEW)

    def test_existing_commit_for_another_task_run_is_rejected(self) -> None:
        spec, run, lease = self._prepare_review()
        with self.assertRaises(PlannedInterruption):
            self._accept(
                run.run_id,
                lease,
                progress_hook=self._interrupt_at(GitAcceptancePhase.STAGED),
            )
        self._git(
            "commit",
            "-m",
            spec.commit_message,
            "-m",
            f"Coordinator-Task-ID: {spec.task_id}\nCoordinator-Run-ID: other-run",
        )
        with self.assertRaises(CommitOwnershipError):
            self._accept(run.run_id, lease)
        self.assertEqual(self._commit_count(), 1)
        self.assertEqual(self.store.get_run(run.run_id).state, TaskState.REVIEW)

    def test_matching_trailers_with_unexpected_parent_are_rejected(self) -> None:
        spec, run, lease = self._prepare_review()
        with self.assertRaises(PlannedInterruption):
            self._accept(
                run.run_id,
                lease,
                progress_hook=self._interrupt_at(GitAcceptancePhase.STAGED),
            )
        self._git("commit", "-m", "intermediate")
        (self.repository / "src/change.py").write_text("value = 3\n", encoding="utf-8")
        self._git("add", "--", "src/change.py")
        self._git(
            "commit",
            "-m",
            spec.commit_message,
            "-m",
            f"Coordinator-Task-ID: {spec.task_id}\nCoordinator-Run-ID: {run.run_id}",
        )
        with self.assertRaises(CommitParentMismatchError):
            self._accept(run.run_id, lease)
        self.assertEqual(self.store.get_run(run.run_id).state, TaskState.REVIEW)

    def test_obsolete_fencing_token_prevents_all_git_mutation(self) -> None:
        _, run, old_lease = self._prepare_review()
        self.service.locks.release(old_lease)
        current_lease = self.service.locks.acquire("new-owner", run.run_id)
        before = self._git("status", "--porcelain=v1")
        with self.assertRaises(FencingTokenError):
            self._accept(run.run_id, old_lease)
        self.assertEqual(self._git("status", "--porcelain=v1"), before)
        self.service.locks.release(current_lease)

    def test_expired_lease_prevents_all_git_mutation(self) -> None:
        start = datetime(2026, 1, 1, tzinfo=UTC)
        _, run, lease = self._prepare_review(
            "expired", lease_seconds=1, now=start
        )
        before = self._git("status", "--porcelain=v1")
        with self.assertRaises(LeaseExpiredError):
            self._accept(run.run_id, lease, now=start + timedelta(seconds=2))
        self.assertEqual(self._git("status", "--porcelain=v1"), before)
        self.assertEqual(self.store.get_run(run.run_id).state, TaskState.REVIEW)

    def test_real_flujo_repository_cannot_cross_fixture_mutation_boundary(self) -> None:
        before_head = subprocess.run(
            ("git", "rev-parse", "HEAD"),
            cwd=REPOSITORY_ROOT,
            check=True,
            capture_output=True,
            text=True,
        ).stdout
        before_status = subprocess.run(
            ("git", "status", "--porcelain=v1", "--untracked-files=all"),
            cwd=REPOSITORY_ROOT,
            check=True,
            capture_output=True,
            text=True,
        ).stdout
        with self.assertRaises(MutationBoundaryError):
            TransactionalGitAdapter(REPOSITORY_ROOT, authorized_root=self.root)
        after_head = subprocess.run(
            ("git", "rev-parse", "HEAD"),
            cwd=REPOSITORY_ROOT,
            check=True,
            capture_output=True,
            text=True,
        ).stdout
        after_status = subprocess.run(
            ("git", "status", "--porcelain=v1", "--untracked-files=all"),
            cwd=REPOSITORY_ROOT,
            check=True,
            capture_output=True,
            text=True,
        ).stdout
        self.assertEqual(after_head, before_head)
        self.assertEqual(after_status, before_status)


if __name__ == "__main__":
    import unittest

    unittest.main()
