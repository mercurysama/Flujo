# Potok phase 7E-1A — Authored scene persistence contract

Date: 2026-11-01. Branch: `feature/fsm-runtime-flow-flusso`.
Requirement trace: original phase-7 item **9**, FSM-R25 and T25; preserves items 1–8 without changing them. This is a focused first slice of 7E, not phase-7 acceptance.

## Scope and acceptance

- Save a normal `.tscn` containing a scene-owned `PVController` with an embedded schema-3 `FlowGraph`, a machine, two authored states, ordered Enter/Update/Exit blocks and one EVENT transition.
- Reopen through `ResourceLoader` and instantiate: graph/machine/state/transition/phase-block stable IDs, state/phase order, initial-state reference, event target, trigger, priority and representative block content **must match exactly**.
- The reopened graph must pass `FlowGraphValidator`; a failure yields a nonzero test exit. Clean only the test-owned path under `res://.godot/flujo_tests/`.
- No schema migration, runtime/editor production code, reusable component, `demo/main.tscn`, Android interaction or `main` change.
- A headless PASS covers serialization only, not Fluo UI authoring, repeated Undo/Redo, Condition Tok roundtrip or manual touch/focus acceptance.

## Dependencies and evidence

- Baseline checkpoint `16a1d3034fbcaff7a4180e7d897884fc3da5f83e`, [CI 41382577892](https://github.com/mercurysama/Flujo/actions/runs/41382577892) SUCCESS before changes.
- Existing `tests/model/flow_graph_persistence_regression.gd` establishes the same PackedScene/ResourceSaver pattern for prior model schemas; phase-7 T25 needs a specific authored-FSM regression.
- Test: `tests/model/flow_fsm_authored_scene_roundtrip_test.gd`.
- CI: `.github/workflows/flujo-fsm.yml`, step "Potok-7E1A authored scene persistence focal".
- Constraints: `docs/constitution.md`, `docs/model_contract.md`, `docs/development_workflow.md`, `AGENTS.md`.

## Next

7E-1B: exercise authored edit commands and repeated Undo/Redo **before** save/reopen; 7E-1C: Condition Tok and typed event-field sources; then keyboard, layout and human acceptance according to `docs/fsm_phase7_microblocks.md`.

No passing result is claimed until the new CI completes. Todo es Flujo; todo fluye. 🌊
