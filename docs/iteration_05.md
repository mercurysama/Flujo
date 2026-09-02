# Iteration 5 — Closeout and Postmortem

## References

- Integration PR: [#6](https://github.com/mercurysama/Flujo/pull/6).
- Integration commit: `1948f868cba3388c8c0d5444f0f2578672c343c9`.

## Planned objectives and achieved results

The iteration was intended to introduce typed containers editable through the Inspector while preserving runtime/editor separation and `FlowGraph` schema 1 compatibility.

The following results were achieved:

- Added the ordered schema 2 collections: `processes`, `variables`, and `state_machines`.
- Preserved ordering, `null` positions, internal IDs, and ID-based references.
- Implemented `FlowVariableDefinition`, `FlowStateMachineDefinition`, structured diagnostics, and deterministic validation.
- Implemented atomic migration from schema 1 to schema 2 without modifying the source.
- Added a read-only Inspector presentation followed by limited undoable editing.
- Registered the InspectorPlugin correctly and centralized dock visibility based on selection.
- Verified persistence of a schema 2 `FlowGraph` inside a `PackedScene`.
- Closed schema-source and `initial_state_id` invariants before integration.

## Model, validation, and migration

Schema 1 retains `containers` as its only source of truth. Schema 2 uses only the typed collections. Incompatible collections are rejected even when they contain only `null` positions.

Deep duplication generates new IDs and uses a single `old-ID → new-ID` map to remap references. Validation does not modify the model and detects invalid or repeated IDs, repeated instances, invalid variable references, incompatible schema sources, and invalid initial states.

`FlowGraphMigrator` validates the source before building a candidate. Migration preserves valid graph, process, state, and block IDs; it creates a `Migrated States` machine with a new ID when states exist. `FlowStateDefinition.is_initial` remains only as schema 1 legacy data used to choose the initial state during migration. In schema 2, `FlowStateMachineDefinition.initial_state_id` is the source of truth.

## Inspector, undo/redo, and dock

The Inspector deterministically presents the schema, active source, indexes, types, names, IDs, empty positions, and diagnostics. It can create a schema 2 graph, migrate a valid schema 1 graph, and edit active collections of processes, variables, and state machines through atomic `EditorUndoRedoManager` actions.

Create, migrate, add, rename, move, and remove actions have symmetric do/undo operations. Removals that break references are rejected before entering history. Inspector refresh is deferred and coalesced to avoid rebuilding controls during a button signal and to prevent duplicate rows.

The dock retains its future role as the block editor. Its visibility is determined through one path: selecting a `PVController` or an ancestor that contains one shows it; multiple or unrelated selection hides it; an empty selection uses the scene root as a fallback.

## Persistence and per-instance state

The persistence regression saves and reloads a real `PackedScene`, releases the initial model before loading, and checks schema, IDs, types, ordering, `null`, values, and references. Temporary files are created under `res://.godot/flujo_tests/` and removed at the end.

`FlowGraph` represents a program definition that can be shared by scene instances. It does not use `resource_local_to_scene`, and the test does not mutate the shared graph. Per-instance mutable state and values belong to a future `PVController` runtime context.

## Explicitly deferred scope

- Graph Constructor and special nodes.
- Reusable methods.
- Block editing and internal state editing.
- Executor, debugger, and runtime-state persistence.
- Additional UI outside the Inspector and the future dock block editor.
- Shaders and execution changes.
- Explicit graph customization in inherited scenes.

## Tests performed

### Automated

- `git diff --check`.
- Headless editor load with Godot 4.7.2.
- `tests/model/flow_model_smoke_test.tscn`.
- `tests/editor/flow_graph_editor_commands_test.gd` with a real `EditorUndoRedoManager`.
- `tests/model/flow_graph_persistence_regression.gd`.
- Runtime → editor dependency and temporary-trace absence audits.

### Manual

- A null `flow_graph` Inspector, schema 2 creation, and undo/redo.
- Presentation of processes, variables, and state machines; additions, selection, and visual refresh.
- Dock visibility for a controller, an ancestor, unrelated selection, empty selection, and multiple selection.
- Visual persistence of the test scene and later removal of its manual artifacts.

## Problems found and causes

- **Cloud history divergence and compaction:** required recovering changes through verified paths and validating their differences before integration.
- **Remote-work latency and recovery:** long tasks had greater latency and more recovery points than local work.
- **Godot executable outside PATH:** verification had to use a confirmed absolute path.
- **Inspector not initially replaced:** intercepting the `flow_graph` property required checking type, hint, usage, and the `_parse_property()` return value.
- **Missing initial callback:** Godot did not guarantee an initial `_update_property()` call, so the interface had to initialize from `_ready()`.
- **Rebuild during the button signal:** destroying the visual tree inside `pressed` prevented reliable updates; deferred, coalesced rebuilding resolved it.
- **Manual-test artifacts:** local demo scene changes and artifacts needed explicit review and discard before synchronization.
- **Shared Resource versus per-instance state confusion:** sharing `FlowGraph` was clarified as correct; mutable state will move to the future runtime context.
- **Incomplete schema-source and `initial_state_id` validation:** the audit found cases that could accept incompatible sources or invalid initial references; diagnostics and regressions were added before integration.

## What worked well

- Small, scoped changes at each step.
- Stop conditions for branches, divergence, unexpected changes, or failed tests.
- Visual tests complemented by automated regressions.
- Independent audits before integration and synchronization.
- Direct-advance and state verification before each merge or push.

## What should improve

- Add GitHub CI for headless load, smoke test, editor test, and persistence regression.
- Unify test execution into one reproducible command that locates Godot and collects exit codes.
- Maintain a permanent visual checklist for the Inspector, dock, undo/redo, and test scenes.
- Reduce remote work for long tasks that require many visual iterations.
- Keep focused audits with evidence by file, path, and associated test.
- Design the next cycle with `FlowGraph` immutability and per-instance runtime context separated from the start.

## Outstanding risks and debt

- Define explicit graph customization in inherited scenes without confusing it with normal instances.
- Design Constructor and reusable methods without breaking ID-based references.
- Implement blocks and execution while preserving runtime/editor separation.
- Persist and release future per-instance runtime state safely.
- Run multiplatform tests before considering the workflow stable.

## Acceptance criteria met

- Schema 2 collections, their invariants, and their migration are validated.
- The Inspector shows and edits permitted collections without runtime editor dependencies.
- Undo/redo preserves instances, IDs, ordering, and `null` positions.
- The dock responds consistently to selection.
- `FlowGraph` persists as a shareable definition and is not used as execution state.
- The automated and manual tests described above passed before integration.

## Recommendation for the next cycle

Start the cycle by designing and testing one `FlowRuntimeState` per `PVController` instance while keeping `FlowGraph` read-only. Before introducing blocks or execution, agree on that context’s contract, lifetime boundaries, ID-based references, and multiplatform testing strategy.
