from __future__ import annotations

import subprocess
import tempfile
import unittest
from collections.abc import Callable
from pathlib import Path
from typing import Any

from flow_coordinator import (
    GOTA_PROTOCOL,
    GotaCycleFailure,
    GotaCheckpoint,
    GotaRequest,
    GotaReviewCycle,
    GotaReviewResult,
    GotaWorkerResult,
    OpenCodeRunResult,
    OpenCodeRunStatus,
    ReviewDecision,
    WorkerResultStatus,
)
from flow_coordinator.git_adapter import GitSnapshot, ReadOnlyGitAdapter


CycleStep = Callable[[str, str], OpenCodeRunResult]


class FakeRunner:
    def __init__(self, steps: list[CycleStep]) -> None:
        self.steps = list(steps)
        self.calls: list[dict[str, Any]] = []

    def run(
        self,
        *,
        agent: str,
        prompt: str,
        cwd: str | Path,
        timeout: float,
    ) -> OpenCodeRunResult:
        self.calls.append(
            {
                "agent": agent,
                "prompt": prompt,
                "cwd": Path(cwd),
                "timeout": timeout,
            }
        )
        if not self.steps:
            raise AssertionError("Reviewer was invoked more times than expected")
        return self.steps.pop(0)(agent, prompt)


class GotaReviewCycleTest(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary_directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary_directory.cleanup)
        self.root = Path(self.temporary_directory.name)
        self.repository = self.root / "repository"
        self.repository.mkdir()
        self._git("init", "--initial-branch=feature/gota-cycle")
        self._git("config", "user.name", "Gota Cycle Test")
        self._git("config", "user.email", "gota-cycle@example.invalid")
        (self.repository / "src").mkdir()
        (self.repository / "src/change.py").write_text(
            "value = 'base'\n", encoding="utf-8"
        )
        (self.repository / "README.md").write_text("base\n", encoding="utf-8")
        self._git("add", "--", "src/change.py", "README.md")
        self._git("commit", "-m", "fixture base")
        self.base_sha = self._git("rev-parse", "HEAD")

    def _git(self, *arguments: str) -> str:
        result = subprocess.run(
            ("git", *arguments),
            cwd=self.repository,
            check=True,
            capture_output=True,
            text=True,
        )
        return result.stdout.rstrip("\n")

    def _request(self) -> GotaRequest:
        return GotaRequest(
            protocol=GOTA_PROTOCOL,
            request_id="run-cycle:1:worker",
            task_id="task-cycle",
            run_id="run-cycle",
            attempt=1,
            phase="worker",
            objective="Implement one local cycle",
            acceptance_criteria=("The cycle is independently verified",),
            workspace=str(self.repository),
            branch="feature/gota-cycle",
            base_sha=self.base_sha,
            allowed_paths=("README.md", "src/change.py"),
            protected_paths=("protected.txt",),
        )

    def _worker_payload(
        self,
        commit_sha: str,
        changed_paths: tuple[str, ...] = ("src/change.py",),
    ) -> GotaWorkerResult:
        return GotaWorkerResult(
            protocol=GOTA_PROTOCOL,
            message="worker.result",
            request_id="run-cycle:1:worker",
            task_id="task-cycle",
            run_id="run-cycle",
            attempt=1,
            result=WorkerResultStatus.READY_FOR_REVIEW,
            commit_sha=commit_sha,
            changed_paths=changed_paths,
            evidence=({"kind": "test", "passed": True},),
            checkpoint=GotaCheckpoint(
                completed_steps=("implementation",), remaining_phase="review"
            ),
        )

    def _review_payload(
        self,
        commit_sha: str,
        decision: ReviewDecision = ReviewDecision.PASSED,
    ) -> GotaReviewResult:
        return GotaReviewResult(
            protocol=GOTA_PROTOCOL,
            message="review.result",
            request_id="run-cycle:1:review",
            task_id="task-cycle",
            run_id="run-cycle",
            attempt=1,
            reviewed_commit_sha=commit_sha,
            decision=decision,
            findings=(),
            evidence=({"kind": "audit", "passed": True},),
        )

    def _execution(
        self,
        *,
        payload: GotaWorkerResult | GotaReviewResult | None = None,
        status: OpenCodeRunStatus = OpenCodeRunStatus.SUCCEEDED,
        exit_code: int | None = None,
        error: str | None = None,
    ) -> OpenCodeRunResult:
        return OpenCodeRunResult(
            status=status,
            argv=("fake-opencode",),
            cwd=str(self.repository),
            stdout="",
            stderr="",
            exit_code=(
                exit_code
                if exit_code is not None
                else 0
                if status is OpenCodeRunStatus.SUCCEEDED
                else 1
            ),
            timed_out=status is OpenCodeRunStatus.TIMEOUT,
            payload=payload,
            error=error,
        )

    def _worker_commit_step(
        self,
        state: dict[str, str],
        *,
        files: tuple[str, ...] = ("src/change.py",),
    ) -> CycleStep:
        def step(_agent: str, _prompt: str) -> OpenCodeRunResult:
            for path in files:
                (self.repository / path).write_text("worker\n", encoding="utf-8")
            self._git("add", "--", *files)
            self._git("commit", "-m", "worker change")
            state["commit_sha"] = self._git("rev-parse", "HEAD")
            return self._execution(
                payload=self._worker_payload(
                    state["commit_sha"], tuple(reversed(files))
                )
            )

        return step

    def _valid_cycle(
        self,
        decision: ReviewDecision = ReviewDecision.PASSED,
        reviewer_step: CycleStep | None = None,
    ) -> tuple[Any, FakeRunner, dict[str, str]]:
        state: dict[str, str] = {}

        def review(_agent: str, _prompt: str) -> OpenCodeRunResult:
            return self._execution(
                payload=self._review_payload(state["commit_sha"], decision)
            )

        runner = FakeRunner([self._worker_commit_step(state), reviewer_step or review])
        result = GotaReviewCycle(self.repository, runner=runner).run(
            self._request(), timeout=3
        )
        return result, runner, state

    def test_worker_commit_is_verified_before_reviewer_passes(self) -> None:
        result, runner, state = self._valid_cycle()

        self.assertTrue(result.valid)
        self.assertEqual(result.decision, ReviewDecision.PASSED)
        self.assertEqual(result.base_sha, self.base_sha)
        self.assertEqual(result.verified_commit_sha, state["commit_sha"])
        self.assertEqual(result.verified_changed_paths, ("src/change.py",))
        self.assertEqual([call["agent"] for call in runner.calls], [
            "gota-worker",
            "gota-reviewer",
        ])
        self.assertEqual(self._git("rev-parse", "HEAD"), state["commit_sha"])
        self.assertEqual(self._git("status", "--porcelain=v1"), "")

    def test_reviewer_correction_required_is_a_valid_cycle_decision(self) -> None:
        result, _, _ = self._valid_cycle(ReviewDecision.CORRECTION_REQUIRED)

        self.assertTrue(result.valid)
        self.assertEqual(result.decision, ReviewDecision.CORRECTION_REQUIRED)

    def test_reviewer_human_review_required_is_a_valid_cycle_decision(self) -> None:
        result, _, _ = self._valid_cycle(ReviewDecision.HUMAN_REVIEW_REQUIRED)

        self.assertTrue(result.valid)
        self.assertEqual(result.decision, ReviewDecision.HUMAN_REVIEW_REQUIRED)

    def test_reviewer_blocked_is_a_valid_cycle_decision(self) -> None:
        result, _, _ = self._valid_cycle(ReviewDecision.BLOCKED)

        self.assertTrue(result.valid)
        self.assertEqual(result.decision, ReviewDecision.BLOCKED)

    def test_worker_timeout_never_invokes_reviewer(self) -> None:
        runner = FakeRunner(
            [
                lambda _agent, _prompt: self._execution(
                    status=OpenCodeRunStatus.TIMEOUT, error="timeout"
                ),
            ]
        )
        result = GotaReviewCycle(self.repository, runner=runner).run(
            self._request(), timeout=3
        )

        self.assertFalse(result.valid)
        self.assertEqual(result.failure, GotaCycleFailure.WORKER_TIMEOUT)
        self.assertIsNone(result.reviewer_execution)
        self.assertEqual(len(runner.calls), 1)

    def test_worker_succeeded_with_nonzero_exit_never_invokes_reviewer(self) -> None:
        runner = FakeRunner(
            [
                lambda _agent, _prompt: self._execution(
                    payload=self._worker_payload(self.base_sha),
                    exit_code=7,
                ),
            ]
        )
        result = GotaReviewCycle(self.repository, runner=runner).run(
            self._request(), timeout=3
        )

        self.assertFalse(result.valid)
        self.assertEqual(result.failure, GotaCycleFailure.WORKER_NON_ZERO_EXIT)
        self.assertIsNone(result.reviewer_execution)
        self.assertIsNone(result.decision)
        self.assertEqual(len(runner.calls), 1)

    def test_worker_invalid_payload_never_invokes_reviewer(self) -> None:
        runner = FakeRunner(
            [
                lambda _agent, _prompt: self._execution(
                    status=OpenCodeRunStatus.INVALID_PAYLOAD,
                    error="INVALID_JSON",
                ),
            ]
        )
        result = GotaReviewCycle(self.repository, runner=runner).run(
            self._request(), timeout=3
        )

        self.assertEqual(result.failure, GotaCycleFailure.WORKER_INVALID_PAYLOAD)
        self.assertIsNone(result.reviewer_execution)
        self.assertEqual(len(runner.calls), 1)

    def test_worker_declared_nonexistent_commit_never_invokes_reviewer(self) -> None:
        payload = self._worker_payload("f" * 40)
        runner = FakeRunner(
            [lambda _agent, _prompt: self._execution(payload=payload)]
        )
        result = GotaReviewCycle(self.repository, runner=runner).run(
            self._request(), timeout=3
        )

        self.assertEqual(result.failure, GotaCycleFailure.WORKER_COMMIT_NOT_FOUND)
        self.assertIsNone(result.reviewer_execution)

    def test_worker_declared_sha_must_equal_head(self) -> None:
        state: dict[str, str] = {}

        def worker(_agent: str, _prompt: str) -> OpenCodeRunResult:
            (self.repository / "src/change.py").write_text("worker\n", encoding="utf-8")
            self._git("add", "--", "src/change.py")
            self._git("commit", "-m", "worker change")
            state["head"] = self._git("rev-parse", "HEAD")
            return self._execution(
                payload=self._worker_payload(self.base_sha)
            )

        runner = FakeRunner([worker])
        result = GotaReviewCycle(self.repository, runner=runner).run(
            self._request(), timeout=3
        )

        self.assertEqual(result.failure, GotaCycleFailure.WORKER_HEAD_MISMATCH)
        self.assertEqual(result.verified_commit_sha, None)
        self.assertEqual(len(runner.calls), 1)

    def test_worker_dirty_worktree_never_invokes_reviewer(self) -> None:
        def worker(_agent: str, _prompt: str) -> OpenCodeRunResult:
            (self.repository / "src/change.py").write_text("dirty\n", encoding="utf-8")
            return self._execution(payload=self._worker_payload(self.base_sha))

        runner = FakeRunner([worker])
        result = GotaReviewCycle(self.repository, runner=runner).run(
            self._request(), timeout=3
        )

        self.assertEqual(result.failure, GotaCycleFailure.WORKER_WORKTREE_DIRTY)
        self.assertIsNone(result.reviewer_execution)

    def test_worker_branch_change_never_invokes_reviewer(self) -> None:
        def worker(_agent: str, _prompt: str) -> OpenCodeRunResult:
            self._git("checkout", "-b", "worker-changed-branch")
            return self._execution(payload=self._worker_payload(self.base_sha))

        runner = FakeRunner([worker])
        result = GotaReviewCycle(self.repository, runner=runner).run(
            self._request(), timeout=3
        )

        self.assertEqual(result.failure, GotaCycleFailure.WORKER_BRANCH_CHANGED)
        self.assertIsNone(result.reviewer_execution)

    def test_worker_multiple_commits_never_invokes_reviewer(self) -> None:
        state: dict[str, str] = {}

        def worker(_agent: str, _prompt: str) -> OpenCodeRunResult:
            (self.repository / "src/change.py").write_text("first\n", encoding="utf-8")
            self._git("add", "--", "src/change.py")
            self._git("commit", "-m", "first worker change")
            (self.repository / "README.md").write_text("second\n", encoding="utf-8")
            self._git("add", "--", "README.md")
            self._git("commit", "-m", "second worker change")
            state["head"] = self._git("rev-parse", "HEAD")
            return self._execution(
                payload=self._worker_payload(
                    state["head"], ("README.md", "src/change.py")
                )
            )

        runner = FakeRunner([worker])
        result = GotaReviewCycle(self.repository, runner=runner).run(
            self._request(), timeout=3
        )

        self.assertEqual(result.failure, GotaCycleFailure.WORKER_MULTIPLE_COMMITS)
        self.assertIsNone(result.reviewer_execution)

    def test_worker_changed_paths_must_match_independent_diff(self) -> None:
        state: dict[str, str] = {}

        def worker(_agent: str, _prompt: str) -> OpenCodeRunResult:
            (self.repository / "src/change.py").write_text("worker\n", encoding="utf-8")
            self._git("add", "--", "src/change.py")
            self._git("commit", "-m", "worker change")
            state["head"] = self._git("rev-parse", "HEAD")
            return self._execution(
                payload=self._worker_payload(state["head"], ("README.md",))
            )

        runner = FakeRunner([worker])
        result = GotaReviewCycle(self.repository, runner=runner).run(
            self._request(), timeout=3
        )

        self.assertEqual(
            result.failure, GotaCycleFailure.WORKER_CHANGED_PATHS_MISMATCH
        )
        self.assertEqual(result.verified_changed_paths, ("src/change.py",))
        self.assertIsNone(result.reviewer_execution)

    def test_reviewer_receives_exact_verified_commit_and_identity(self) -> None:
        result, runner, state = self._valid_cycle()
        reviewer_call = runner.calls[1]
        prompt = reviewer_call["prompt"]

        self.assertTrue(result.valid)
        self.assertEqual(reviewer_call["agent"], "gota-reviewer")
        self.assertIn(self.base_sha, prompt)
        self.assertIn(state["commit_sha"], prompt)
        self.assertIn("task-cycle", prompt)
        self.assertIn("run-cycle", prompt)
        self.assertIn("run-cycle:1:review", prompt)
        self.assertIn("Do not modify files", prompt)

    def test_reviewer_invalid_payload_does_not_invent_a_decision(self) -> None:
        def reviewer(_agent: str, _prompt: str) -> OpenCodeRunResult:
            return self._execution(
                status=OpenCodeRunStatus.INVALID_PAYLOAD,
                error="MISSING_FIELD",
            )

        result, _, _ = self._valid_cycle(reviewer_step=reviewer)

        self.assertFalse(result.valid)
        self.assertEqual(result.failure, GotaCycleFailure.REVIEWER_INVALID_PAYLOAD)
        self.assertIsNone(result.review_result)
        self.assertIsNone(result.decision)

    def test_reviewer_passed_with_wrong_commit_hides_decision(self) -> None:
        result, _, state = self._valid_cycle(
            reviewer_step=lambda _agent, _prompt: self._execution(
                payload=self._review_payload(self.base_sha)
            )
        )

        self.assertFalse(result.valid)
        self.assertEqual(result.failure, GotaCycleFailure.REVIEWER_COMMIT_MISMATCH)
        self.assertEqual(result.review_result.decision, ReviewDecision.PASSED)
        self.assertEqual(result.verified_commit_sha, state["commit_sha"])
        self.assertIsNone(result.decision)

    def test_reviewer_head_mutation_invalidates_even_a_passed_review(self) -> None:
        def reviewer(_agent: str, _prompt: str) -> OpenCodeRunResult:
            (self.repository / "README.md").write_text("reviewer\n", encoding="utf-8")
            self._git("add", "--", "README.md")
            self._git("commit", "-m", "forbidden reviewer commit")
            return self._execution(
                payload=self._review_payload(self._git("rev-parse", "HEAD~1"))
            )

        result, _, state = self._valid_cycle(reviewer_step=reviewer)

        self.assertFalse(result.valid)
        self.assertEqual(result.failure, GotaCycleFailure.REVIEWER_HEAD_CHANGED)
        self.assertEqual(result.verified_commit_sha, state["commit_sha"])

    def test_reviewer_dirty_worktree_invalidates_even_a_passed_review(self) -> None:
        def reviewer(_agent: str, _prompt: str) -> OpenCodeRunResult:
            (self.repository / "reviewer.txt").write_text("dirty\n", encoding="utf-8")
            return self._execution(
                payload=self._review_payload(self._git("rev-parse", "HEAD"))
            )

        result, _, _ = self._valid_cycle(reviewer_step=reviewer)

        self.assertFalse(result.valid)
        self.assertEqual(result.failure, GotaCycleFailure.REVIEWER_WORKTREE_DIRTY)

    def test_reviewer_branch_mutation_invalidates_the_cycle(self) -> None:
        def reviewer(_agent: str, _prompt: str) -> OpenCodeRunResult:
            self._git("checkout", "-b", "reviewer-changed-branch")
            return self._execution(
                payload=self._review_payload(self._git("rev-parse", "HEAD"))
            )

        result, _, _ = self._valid_cycle(reviewer_step=reviewer)

        self.assertFalse(result.valid)
        self.assertEqual(result.failure, GotaCycleFailure.REVIEWER_BRANCH_CHANGED)

    def test_reviewer_tag_mutation_invalidates_the_cycle(self) -> None:
        def reviewer(_agent: str, _prompt: str) -> OpenCodeRunResult:
            self._git("tag", "reviewer-side-effect")
            return self._execution(
                payload=self._review_payload(self._git("rev-parse", "HEAD"))
            )

        result, _, _ = self._valid_cycle(reviewer_step=reviewer)

        self.assertFalse(result.valid)
        self.assertEqual(result.failure, GotaCycleFailure.REVIEWER_REFS_CHANGED)
        self.assertIsNone(result.decision)
        self.assertEqual(self._git("tag", "--list", "reviewer-side-effect"), "reviewer-side-effect")

    def test_reviewer_secondary_branch_ref_mutation_invalidates_the_cycle(self) -> None:
        def reviewer(_agent: str, _prompt: str) -> OpenCodeRunResult:
            self._git("branch", "reviewer-secondary")
            self._git("update-ref", "refs/heads/reviewer-secondary", self.base_sha)
            return self._execution(
                payload=self._review_payload(self._git("rev-parse", "HEAD"))
            )

        result, _, _ = self._valid_cycle(reviewer_step=reviewer)

        self.assertFalse(result.valid)
        self.assertEqual(result.failure, GotaCycleFailure.REVIEWER_REFS_CHANGED)
        self.assertIsNone(result.decision)
        self.assertEqual(
            self._git("show-ref", "--verify", "refs/heads/reviewer-secondary").split()[0],
            self.base_sha,
        )

    def test_reviewer_symbolic_ref_target_mutation_invalidates_the_cycle(self) -> None:
        self._git("update-ref", "refs/heads/main", self.base_sha)
        self._git("update-ref", "refs/heads/reviewer-secondary", self.base_sha)
        self._git(
            "symbolic-ref", "refs/heads/reviewer-alias", "refs/heads/main"
        )
        snapshots: list[GitSnapshot] = []

        def reviewer(_agent: str, _prompt: str) -> OpenCodeRunResult:
            snapshots.append(ReadOnlyGitAdapter(self.repository).snapshot())
            self._git(
                "symbolic-ref",
                "refs/heads/reviewer-alias",
                "refs/heads/reviewer-secondary",
            )
            snapshots.append(ReadOnlyGitAdapter(self.repository).snapshot())
            return self._execution(
                payload=self._review_payload(self._git("rev-parse", "HEAD"))
            )

        result, _, _ = self._valid_cycle(reviewer_step=reviewer)

        self.assertNotEqual(snapshots[0], snapshots[1])
        self.assertEqual(
            next(
                ref
                for ref in snapshots[0].refs
                if ref[0] == "refs/heads/reviewer-alias"
            ),
            ("refs/heads/reviewer-alias", self.base_sha, "refs/heads/main"),
        )
        self.assertEqual(
            next(
                ref
                for ref in snapshots[1].refs
                if ref[0] == "refs/heads/reviewer-alias"
            ),
            (
                "refs/heads/reviewer-alias",
                self.base_sha,
                "refs/heads/reviewer-secondary",
            ),
        )
        self.assertFalse(result.valid)
        self.assertEqual(result.failure, GotaCycleFailure.REVIEWER_REFS_CHANGED)
        self.assertIsNone(result.decision)

    def test_reviewer_succeeded_with_nonzero_exit_invalidates_the_cycle(self) -> None:
        def reviewer(_agent: str, _prompt: str) -> OpenCodeRunResult:
            return self._execution(
                payload=self._review_payload(self._git("rev-parse", "HEAD")),
                exit_code=7,
            )

        result, _, _ = self._valid_cycle(reviewer_step=reviewer)

        self.assertFalse(result.valid)
        self.assertEqual(result.failure, GotaCycleFailure.REVIEWER_NON_ZERO_EXIT)
        self.assertIsNone(result.decision)

    def test_cycle_does_not_create_task_run_or_sqlite_state(self) -> None:
        result, _, _ = self._valid_cycle()

        self.assertTrue(result.valid)
        self.assertEqual(list(self.root.glob("*.sqlite3")), [])
        self.assertEqual(list(self.repository.glob("*.sqlite3")), [])


if __name__ == "__main__":
    unittest.main()
