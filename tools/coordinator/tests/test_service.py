from __future__ import annotations

from datetime import UTC, datetime, timedelta

from flow_coordinator.commit_policy import CommitPolicyError, FakeCommitter
from flow_coordinator.domain import ResourceState, TaskState
from flow_coordinator.service import ResourceCooldownError
from flow_coordinator.store import AcceptanceEvidenceError, UnsatisfiedDependencyError

from support import CoordinatorTestCase, make_spec


class CoordinatorServiceTest(CoordinatorTestCase):
    def _finish(self, run_id: str, owner: str = "worker") -> str:
        lease = self.service.start(run_id, owner_id=owner)
        self.service.complete_execution(run_id, lease)
        accepted, commit_sha = self.service.accept_review(
            run_id,
            lease,
            committer=FakeCommitter(),
            staged_paths=("src/change.py",),
            microaudit={"passed": True, "scope": "verified"},
        )
        self.assertEqual(accepted.state, TaskState.DONE)
        return commit_sha

    def test_acceptance_requires_microaudit_and_records_one_fake_commit(self) -> None:
        _, run = self.create_task("accepted")
        lease = self.service.start(run.run_id, owner_id="worker")
        self.service.complete_execution(run.run_id, lease)
        committer = FakeCommitter()
        with self.assertRaisesRegex(ValueError, "Microaudit"):
            self.service.accept_review(
                run.run_id,
                lease,
                committer=committer,
                staged_paths=("src/change.py",),
                microaudit={"passed": False},
            )
        accepted, commit_sha = self.service.accept_review(
            run.run_id,
            lease,
            committer=committer,
            staged_paths=("src/change.py",),
            microaudit={"passed": True},
        )
        self.assertEqual(accepted.state, TaskState.DONE)
        self.assertEqual(len(committer.commits), 1)
        self.assertEqual(committer.commits[0]["sha"], commit_sha)
        self.assertEqual(
            [evidence.kind for evidence in self.store.list_evidence(run.run_id)],
            ["microaudit", "selective_staging", "local_commit"],
        )

    def test_low_level_done_transition_cannot_bypass_commit_policy(self) -> None:
        _, run = self.create_task("cannot-bypass")
        lease = self.service.start(run.run_id, owner_id="worker")
        self.service.complete_execution(run.run_id, lease)
        with self.assertRaisesRegex(AcceptanceEvidenceError, "microaudit"):
            self.store.transition_run(
                run.run_id,
                TaskState.DONE,
                lease,
                actor="worker",
                reason="attempted_bypass",
            )
        self.assertEqual(self.store.get_run(run.run_id).state, TaskState.REVIEW)

    def test_fake_commit_policy_rejects_protected_or_unauthorized_paths(self) -> None:
        _, run = self.create_task("protected")
        lease = self.service.start(run.run_id, owner_id="worker")
        self.service.complete_execution(run.run_id, lease)
        with self.assertRaises(CommitPolicyError):
            self.service.accept_review(
                run.run_id,
                lease,
                committer=FakeCommitter(),
                staged_paths=("demo/main.tscn",),
                microaudit={"passed": True},
            )
        self.assertEqual(self.store.get_run(run.run_id).state, TaskState.REVIEW)

    def test_first_failure_and_authorized_retry(self) -> None:
        _, run = self.create_task("retry")
        lease = self.service.start(run.run_id, owner_id="worker-a")
        attempt, failed = self.service.fail(
            run.run_id,
            lease,
            resource_id="compiler",
            details={"exit_code": 1},
        )
        self.assertEqual(attempt, 1)
        self.assertEqual(failed.state, TaskState.NOT_COMPLETED)
        retried = self.service.authorize_retry(
            run.run_id,
            owner_id="reviewer",
            authorization="retry approved",
        )
        self.assertEqual(retried.state, TaskState.ASSIGNED)

    def test_second_failure_for_same_resource_blocks_even_with_new_executor(self) -> None:
        _, run = self.create_task("two-failures")
        first_lease = self.service.start(run.run_id, owner_id="executor-a")
        self.service.fail(
            run.run_id,
            first_lease,
            resource_id="shared-gpu",
            details={"command": "first"},
        )
        self.service.authorize_retry(
            run.run_id,
            owner_id="reviewer",
            authorization="second attempt authorized",
        )
        second_lease = self.service.start(run.run_id, owner_id="executor-b")
        attempt, failed = self.service.fail(
            run.run_id,
            second_lease,
            resource_id="shared-gpu",
            details={"command": "equivalent-second"},
        )
        self.assertEqual(attempt, 2)
        self.assertEqual(failed.state, TaskState.BLOCKED)
        self.assertEqual(self.store.attempt_count(run.run_id, "shared-gpu"), 2)

    def test_unsatisfied_dependency_prevents_start(self) -> None:
        dependency_spec = make_spec("dependency", project_id="project-a")
        dependent_spec = make_spec("dependent", project_id="project-b")
        self.service.create_task(dependency_spec, {"project": "a"})
        dependent = self.service.create_task(
            dependent_spec, {"project": "b"}, dependencies=("dependency",)
        )
        with self.assertRaises(UnsatisfiedDependencyError):
            self.service.start(dependent.run_id, owner_id="worker")

    def test_done_dependency_allows_cross_project_start(self) -> None:
        dependency_spec = make_spec("dependency", project_id="project-a")
        dependency = self.service.create_task(dependency_spec, {"project": "a"})
        self._finish(dependency.run_id)
        dependent_spec = make_spec("dependent", project_id="project-b")
        dependent = self.service.create_task(
            dependent_spec, {"project": "b"}, dependencies=("dependency",)
        )
        lease = self.service.start(dependent.run_id, owner_id="worker-b")
        self.assertEqual(self.store.get_run(dependent.run_id).state, TaskState.RUNNING)
        self.service.locks.release(lease)

    def test_global_exclusion_rejects_a_second_mutable_task(self) -> None:
        _, first = self.create_task("first")
        _, second = self.create_task("second")
        first_lease = self.service.start(first.run_id, owner_id="worker-a")
        with self.assertRaises(Exception) as caught:
            self.service.start(second.run_id, owner_id="worker-b")
        self.assertIn("lock", str(caught.exception).lower())
        self.service.locks.release(first_lease)

    def test_cooldown_activates_only_for_actually_used_configured_resource(self) -> None:
        start = datetime(2026, 1, 1, tzinfo=UTC)
        self.store.register_resource("gpu", cooldown_required=True, minimum_seconds=30)
        _, unused = self.create_task("unused-gpu", required_resources=("gpu",))
        unused_lease = self.service.start(unused.run_id, owner_id="worker-a", now=start)
        self.service.complete_execution(unused.run_id, unused_lease, used_resources=(), now=start)
        self.assertIsNone(self.store.get_resource("gpu").state)
        self.service.accept_review(
            unused.run_id,
            unused_lease,
            committer=FakeCommitter(),
            staged_paths=("src/change.py",),
            microaudit={"passed": True},
            now=start,
        )

        _, used = self.create_task("used-gpu", required_resources=("gpu",))
        used_lease = self.service.start(used.run_id, owner_id="worker-b", now=start)
        self.service.complete_execution(
            used.run_id, used_lease, used_resources=("gpu",), now=start
        )
        self.assertEqual(self.store.get_run(used.run_id).state, TaskState.REVIEW)
        resource = self.store.get_resource("gpu")
        self.assertEqual(resource.state, ResourceState.COOLDOWN)
        self.assertEqual(resource.not_before, start + timedelta(seconds=30))
        self.service.accept_review(
            used.run_id,
            used_lease,
            committer=FakeCommitter(),
            staged_paths=("src/change.py",),
            microaudit={"passed": True},
            now=start,
        )
        self.assertEqual(self.store.get_run(used.run_id).state, TaskState.DONE)

        _, blocked = self.create_task("blocked-gpu", required_resources=("gpu",))
        with self.assertRaises(ResourceCooldownError):
            self.service.start(
                blocked.run_id,
                owner_id="worker-c",
                now=start + timedelta(seconds=10),
            )

        _, unrelated = self.create_task("cpu-only")
        unrelated_lease = self.service.start(
            unrelated.run_id,
            owner_id="worker-d",
            now=start + timedelta(seconds=10),
        )
        self.assertEqual(self.store.get_run(unrelated.run_id).state, TaskState.RUNNING)
        self.service.locks.release(unrelated_lease, now=start + timedelta(seconds=10))
        self.assertTrue(
            self.store.resource_available("gpu", now=start + timedelta(seconds=31))
        )
        self.assertEqual(self.store.get_run(used.run_id).state, TaskState.DONE)

    def test_failure_can_activate_cooldown_without_changing_failure_state(self) -> None:
        start = datetime(2026, 1, 1, tzinfo=UTC)
        self.store.register_resource("gpu", cooldown_required=True, minimum_seconds=5)
        _, run = self.create_task("gpu-failure", required_resources=("gpu",))
        lease = self.service.start(run.run_id, owner_id="worker", now=start)
        _, failed = self.service.fail(
            run.run_id,
            lease,
            resource_id="render-step",
            details={"exit_code": 1},
            used_resources=("gpu",),
            now=start,
        )
        self.assertEqual(failed.state, TaskState.NOT_COMPLETED)
        self.assertEqual(self.store.get_resource("gpu").state, ResourceState.COOLDOWN)

    def test_cancellation_activates_only_a_resource_that_was_used(self) -> None:
        start = datetime(2026, 1, 1, tzinfo=UTC)
        self.store.register_resource("gpu", cooldown_required=True, minimum_seconds=5)
        _, run = self.create_task("cancelled", required_resources=("gpu",))
        lease = self.service.start(run.run_id, owner_id="worker", now=start)
        cancelled = self.service.cancel(
            run.run_id, lease, used_resources=("gpu",), now=start
        )
        self.assertEqual(cancelled.state, TaskState.CANCELLED)
        self.assertEqual(self.store.get_resource("gpu").state, ResourceState.COOLDOWN)


if __name__ == "__main__":
    import unittest

    unittest.main()
