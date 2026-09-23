from __future__ import annotations

from flow_coordinator.dependency_graph import (
    DependencyCycleError,
    MissingDependencyError,
    validate_dependency_graph,
)

from support import CoordinatorTestCase, make_spec


class DependencyGraphTest(CoordinatorTestCase):
    def test_valid_dag_has_dependency_first_order(self) -> None:
        order = validate_dependency_graph(
            {"design", "implement", "prove"},
            {"implement": ("design",), "prove": ("implement",)},
        )
        self.assertLess(order.index("design"), order.index("implement"))
        self.assertLess(order.index("implement"), order.index("prove"))

    def test_missing_dependency_is_rejected(self) -> None:
        with self.assertRaisesRegex(MissingDependencyError, "missing task"):
            validate_dependency_graph({"task"}, {"task": ("unknown",)})

    def test_cycle_is_rejected_deterministically(self) -> None:
        with self.assertRaisesRegex(DependencyCycleError, "a -> b -> a"):
            validate_dependency_graph({"a", "b"}, {"a": ("b",), "b": ("a",)})

    def test_cross_project_dependency_keeps_contexts_isolated(self) -> None:
        spec_a = make_spec("task-a", project_id="project-a")
        spec_b = make_spec("task-b", project_id="project-b")
        self.service.create_task(spec_a, {"secret": "only-a"})
        self.service.create_task(spec_b, {"secret": "only-b"})
        self.store.add_dependency("task-b", "task-a")
        self.assertEqual(self.store.list_dependencies("task-b"), ("task-a",))
        self.assertEqual(self.store.get_context(spec_a.context_id).payload["secret"], "only-a")
        self.assertEqual(self.store.get_context(spec_b.context_id).payload["secret"], "only-b")

    def test_store_rejects_cycle_without_persisting_it(self) -> None:
        self.create_task("a")
        self.create_task("b")
        self.store.add_dependency("a", "b")
        with self.assertRaises(DependencyCycleError):
            self.store.add_dependency("b", "a")
        self.assertEqual(self.store.list_dependencies("a"), ("b",))
        self.assertEqual(self.store.list_dependencies("b"), ())


if __name__ == "__main__":
    import unittest

    unittest.main()
