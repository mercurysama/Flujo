# Flow task coordinator

This directory contains the local, language-independent core of the
Multiproject Coordinator v1. It is a standalone Python package and has no
dependency on Godot or the Flujo plugin.

## `flujo.gota/v1` contract boundary

Gota result framing recognizes `FLUJO_GOTA_RESULT_V1_BEGIN` and
`FLUJO_GOTA_RESULT_V1_END` only when each token is the complete content of a
line. One complete payload may have free text before and after it. The Python
parser accepts only strict JSON and rejects non-finite constants such as
`NaN`, `Infinity`, and `-Infinity`.

The versioned JSON Schemas validate JSON-local structure: required fields,
non-blank strings, integer attempts, SHA formats, and protocol enums. The
Python protocol models own semantic invariants that standard JSON Schema
cannot express portably, including the relationship between `request_id`,
`run_id`, `attempt`, and `phase`. No non-standard schema extension or new
validation dependency is used for that boundary.

`flow_coordinator.Checkpoint` remains the historical persistent checkpoint.
The Gota protocol type is available only as the explicit `GotaCheckpoint`
name; it is not exported through a generic `Checkpoint` alias.

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

The original Git inspection adapter remains read-only. Mutable acceptance is
isolated behind `TransactionalGitAdapter`, which requires an explicit
authorized root, stages only the task's exact allowlist, records a staging
manifest, and creates one local commit with task/run trailers. Recovery reuses
a matching commit rather than creating a duplicate. The integration suite uses
only temporary fixture repositories; the Flujo repository is inspected only
through its read-only boundary. Push and merge are intentionally unavailable.

Run the isolated tests from the repository root:

```sh
PYTHONPATH=tools/coordinator/src python3 -m unittest discover -s tools/coordinator/tests -v
```

Inspect an isolated store:

```sh
PYTHONPATH=tools/coordinator/src python3 -m flow_coordinator.cli --db /tmp/coordinator.sqlite3 init
PYTHONPATH=tools/coordinator/src python3 -m flow_coordinator.cli --db /tmp/coordinator.sqlite3 status
```
