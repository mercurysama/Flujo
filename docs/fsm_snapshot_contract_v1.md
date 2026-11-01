# FLU-FSM-004 — Versioned snapshot and restore contract

**Scope:** save / restore FSM instance state without introducing any mutable data into FlowGraph.

## Lifetimes

- EPHEMERAL: live until explicit FSM reset or instance teardown; never included in snapshots.
- SESSION: survives FSM reset but is removed on instance teardown; not included in persistent snapshots.
- PERSISTENT: survives FSM reset and is eligible for portable, versioned snapshots.
- When a nonpersistent alias is active at snapshot time, record that machine's valid authored initial-state ID as its recovery state. The snapshot never fabricates a reference to an unsaved alias.

## Format and validation

- JSON object: format_version=1, graph_id, schema_version, machines ordered by graph, dynamic_states ordered by machine registration.
- Each machine stores machine_id and active_state_id; each saved alias stores machine_id, runtime_id, template_state_id, lifetime=PERSISTENT and detached JSON-safe data.
- The codec accepts only supported formats, exact known graph/schema IDs, valid active machine membership, unique valid IDs, known enabled templates, and active IDs resolved against authored or saved persistent states.
- Reject unsupported versions, missing state references, invalid types, live Objects/Callables, excessive nesting, over-budget entries and corrupt text without changing any running state.
- Snapshot validation must not create editor classes or execute blocks. The restored candidate is built off to the side and committed only after all checks pass.

## Runtime and disk lifecycle

- restore_snapshot performs Exit of old active states, swaps detached runtime state in one commit, clears pending requests, then performs Enter exactly once per restored active state.
- Save and restore are forbidden inside a reentrant FSM tick; operations report bool or fail without publication.
- save_to_file accepts user:// paths ending in .json, verifies temporary output, retains a backup when replacing a previous snapshot and uses a rename/recovery path; restore_from_file validates before applying.
- Relative, traversal, res:// and absolute paths are rejected; runtime never serializes arbitrary Nodes, Resources or executable scripts.
- Per-instance snapshots do not mutate another controller even when both share FlowGraph.

## Verification

Test success, user:// round trip, snapshot JSON safety, EPHEMERAL/SESSION omission, PERSISTENT alias restoration, bad format, missing ID, corruption and per-controller isolation. No manual UI approval is inferred from headless success.

Todo es Flujo; todo fluye. 🌊