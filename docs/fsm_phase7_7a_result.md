# Potok 7A — Read-only editor projection, RED/GREEN checkpoint

**Date:** 2026-11-01. **Branch:** `feature/fsm-runtime-flow-flusso`.

**Scope:** Author a precise Inspector → Fluo → Flow/Flusso UI boundary and a pure, editor-only view model for state-machine navigation. This micro-lot does **not** visually add or connect a state editor, change graph schema, or write authored resources.

**Contract:** `6c44d8614f03269fe9575ef813148c6827aa3440`; [7A UI design contract](fsm_phase7_7a_contract.md) maps existing UI architecture: Inspector already exposes **State Machines** via `FlowGraphInspectorPresenter`, `FluoDrawer` reuses `FlowGraphInspectorProperty`, and `FlowGraphEditorCommands.Collection.STATE_MACHINES` already handles machine-level collection operations. No duplicate Inspector `Blocks` list.

**RED focal:** `7c55954c76a3585bfb85cefb4e408d172d429c8d` adds `tests/editor/flow_fsm_editor_projection_test.gd`, scene `b5f71ca2a7b2ac04786ddad7b9180321a598db4f`, workflow `6467f163e5a6c1aa58bb1db0d3aeaa40ce55b9d2`. [GitHub Actions 41364627238](https://github.com/mercurysama/Flujo/actions/runs/41364627238) **FAIL expected**, because the projection script did not exist.

**GREEN implementation:** `1afd8e3a90f02e73fbcfd0fc21a60e99f54dcf60` adds `addons/vp_flujo/editor/flow_fsm_editor_projection.gd` (`@tool FlowFSMEditorProjection`). `present(graph,machine_id)` creates a detached dictionary with `found`, `machine`, `states`, `empty`, `diagnostics`; stable machine/state/transition/block IDs and names; enabled, tick mode, notes; initial ID; three ordered phase lists; event/condition trigger, priority and target ID. Existing machine with no states produces a read-only **Empty** placeholder with blank ID. Missing IDs produce `found=false`. Selection uses IDs, not display names.

**Full GREEN:** [GitHub Actions 41364696760](https://github.com/mercurysama/Flujo/actions/runs/41364696760) **SUCCESS** for 7A focal and all earlier FSM/model/Ready/navigation regressions.

### Verified invariants

- Selecting by machine ID is deterministic even when other machines share its display name.
- Authored state and transition order, three phase block IDs, initial state via `machine.initial_state_id` (ignoring legacy `state.is_initial`), enum trigger and signed priority are faithfully projected.
- The result contains no `Resource` or `Node` references; repeated projection gives identical plain data and graph validation still succeeds without ID or state changes.
- An empty machine draft is **not** an automatically inserted authored state. Missing ID is inert.
- No old UI shell or runtime API edits, graph serialization/schema changes, or visual/Android acceptance claims.

### Next lot 7B

Wire the selected `Collection.STATE_MACHINES` item into existing `FluoDrawer` through stable machine ID, keeping the Inspector list as the entry point. Add a navigable **Flow** state list derived from `FlowFSMEditorProjection` and restore focus on Escape or back. Reuse `FlowGraphInspectorProperty` and existing Undo/Redo context, not a second editor graph. Plan the Flusso property editor and Condition Tok bridge separately; **phase-5 Tok binding** and **phase-7 full UI/Android tests** remain outstanding.

**Recovery:** pre-code 7A contract `6c44d8614f03269fe9575ef813148c6827aa3440`, RED CI `41364627238`, GREEN code `1afd8e3a90f02e73fbcfd0fc21a60e99f54dcf60` and full CI `41364696760`. This document-only checkpoint does not extend UI acceptance.

Todo es Flujo; todo fluye. 🌊
