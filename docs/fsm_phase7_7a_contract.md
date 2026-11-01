# Potok 7A — Inspector → Fluo → Flow/Flusso authoring interface contract

**Date:** 2026-11-01. **Branch:** `feature/fsm-runtime-flow-flusso`. **Pre-7A HEAD:** `3631fa6bd620f16d9fb931b32ee1e6e5aceae903`.

## Confirmed editor integration boundaries

- **Inspector entry exists.** `FlowGraphInspectorPresenter._present_state_machines` already renders one **State Machines** section. `FlowGraphEditorCommands.Collection.STATE_MACHINES` supplies add/rename/move/delete operations. Do not create a redundant list of `Blocks` in the Inspector or a separate copy of the authored graph.
- **Fluo is the existing shell.** `FluoDrawer` owns a `FlowGraphInspectorProperty` view and opens an existing container through stable-ID selection. `VPFlujoDock` uses that same view in dock mode. Future Potok navigation must reuse the selected `PVController` and the current Fluo focus/Escape hierarchy.
- **Flow is the hierarchy.** On activating a selected State Machine (Enter or double-click), show a machine heading and its states in authored order. The chosen initial state is determined by `FlowStateMachineDefinition.initial_state_id` (do **not** duplicate it using the legacy `FlowStateDefinition.is_initial`). Empty states show an explicit `Empty` draft, not an implicit saved state. A selected state's phases are `Enter`, `Update` (`blocks`) and `Exit`, each with its own ordered block IDs.
- **Flusso is property editing.** Machine name/enabled/note/initial state and state name/enabled/note/transitions/trigger/priority belong to Flusso. Reuse the existing generic block property editor and Condition Tok editor only after a separate validated adapter; never bypass `FlowChipFieldSchema`, popup Cancel semantics, or Undo/Redo.
- **Stable identities and read-only projection.** No resource mutation or ID generation while browsing. A 7A projection can be pure data, containing only IDs, names, booleans, enums and ordered rows. It must not contain live Resource/Node references or save its output into `FlowGraph`. The stable IDs are the only bridge for later editor commands, not translated display names.

## Implementation slice 7A — projection and contract, not interactive editor yet

Add `FlowFSMEditorProjection` as an editor-only `@tool RefCounted` pure presenter. `present(graph,machine_id)` returns `{found, machine, states, empty, diagnostics}`; `machine` carries stable machine ID, display name, tick mode, enabled, auto-start, initial ID; each state carries its ID, enabled/name/note, is_initial derived from machine.initial_state_id, ordered `phases` block rows (Enter/Update/Exit) and `transitions` rows (ID, name, enabled, target ID, trigger, priority, event_name, condition_present). Include a clear `Empty` entry only for an existing machine with no authored states. Missing machine IDs return `found=false` and no draft mutation. A `null` state/transition/block becomes a read-only `Empty` row with blank ID (no invented resource).

A new headless focal must prove stable IDs and order, initial-state flag correctness, complete three-phase projection, transition trigger/priority, missing ID, empty draft, unchanged graph serialization and absence of Resource references in the result. Gate with CI alongside the established Godot 4.7.2 FSM suite. Keep the engine runtime and graph schema unchanged.

## Explicit follow-on lots and safety gates

- **7B:** wire State Machines activation from Inspector/Flow to Fluo with stable IDs, focus/Escape restoration, and a Flow state list. Do not redefine `fluo_block_open_requested` or treat machine IDs as process IDs.
- **7C:** Flusso machine/state/transition property forms and atomic Undo/Redo; prevalidate graph candidates, do not silently remove cross-references. Use confirmation with real Cancel.
- **7D:** Condition Tok `#` editor bridge and payload-to-expression context contract; those are **still open phase-5 integration debts**, not covered by a read-only projection.
- **7E:** keyboard navigation and regression plus save/reload IDs; Android portrait/landscape touch/scroll/manual acceptance are later QA gates, not proven by CI headless.

**7A acceptance:** contract + read-only projection + headless test PASS, no visual shell claim. Resume by reading this file, `docs/fsm_phase6_final_audit.md`, `FlowGraphInspectorProperty`, `FluoDrawer`, and `FlowGraphEditorCommands`. Do not mark full phase 7 complete.

Todo es Flujo; todo fluye. 🌊
