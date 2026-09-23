# Flow task coordinator

This directory contains the local, language-independent core of the
Multiproject Coordinator v1. It is a standalone Python package and has no
dependency on Godot or the Flujo plugin.

The operational store is SQLite. The future default location is
`~/.local/state/flow-coordinator/coordinator.sqlite3`; tests always pass an
isolated temporary database explicitly.

Official task states are:

- `🌊 ASSIGNED`
- `🛠 RUNNING`
- `👀 REVIEW`
- `🙆🏻 DONE`
- `🙅🏻 NOT_COMPLETED`
- `⛔ BLOCKED`
- `❌ CANCELLED`

`❤️‍🔥 COOLDOWN` belongs only to a coordinator resource. It is activated only
when a run actually used a resource whose policy requires cooldown. It never
changes the state of a task run.

The Git adapter in this delivery is read-only. Commit acceptance is exercised
through `FakeCommitter`; the coordinator cannot stage or commit a real
repository.

Run the isolated tests from the repository root:

```sh
PYTHONPATH=tools/coordinator/src python3 -m unittest discover -s tools/coordinator/tests -v
```

Inspect an isolated store:

```sh
PYTHONPATH=tools/coordinator/src python3 -m flow_coordinator.cli --db /tmp/coordinator.sqlite3 init
PYTHONPATH=tools/coordinator/src python3 -m flow_coordinator.cli --db /tmp/coordinator.sqlite3 status
```
