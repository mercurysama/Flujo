"""Deterministic dependency DAG validation."""

from __future__ import annotations

from collections.abc import Iterable, Mapping


class DependencyError(ValueError):
    pass


class MissingDependencyError(DependencyError):
    pass


class DependencyCycleError(DependencyError):
    pass


def validate_dependency_graph(
    task_ids: Iterable[str], dependencies: Mapping[str, Iterable[str]]
) -> tuple[str, ...]:
    nodes = set(task_ids)
    adjacency: dict[str, tuple[str, ...]] = {}
    for task_id in sorted(nodes):
        requested = tuple(sorted(set(dependencies.get(task_id, ()))))
        for dependency_id in requested:
            if dependency_id not in nodes:
                raise MissingDependencyError(
                    f"Task {task_id} depends on missing task {dependency_id}"
                )
        adjacency[task_id] = requested

    colors: dict[str, int] = {node: 0 for node in nodes}
    order: list[str] = []

    def visit(node: str, path: tuple[str, ...]) -> None:
        color = colors[node]
        if color == 2:
            return
        if color == 1:
            cycle_start = path.index(node) if node in path else 0
            cycle = (*path[cycle_start:], node)
            raise DependencyCycleError("Dependency cycle: " + " -> ".join(cycle))
        colors[node] = 1
        for dependency_id in adjacency[node]:
            visit(dependency_id, (*path, node))
        colors[node] = 2
        order.append(node)

    for node in sorted(nodes):
        visit(node, ())
    return tuple(order)
