# Potok 7C-1 — Flusso machine/state scalar editing, RED/GREEN checkpoint

**Date:** 2026-11-01 (CI jobs reported UTC on 2026-11-02). **Branch:** `feature/fsm-runtime-flow-flusso`.

## Scope

Extend the **existing** Fluo-owned Flow/Flusso property editor from 7B. Do not create a separate graph, new schema or runtime path. Machine properties: `display_name`, `enabled`, `auto_start`, `tick_mode`, `user_note`, `initial_state_id`. State properties: `display_name`, `enabled`, `user_note`. The legacy state `is_initial` remains read-only. A machine's initial state is identified exclusively by an enabled, owned state ID.

## Work and evidence

- **Contract:** `92eb751db2d115144f71da8a05f4c8d8bd6e4c05` in [7C-1 contract](fsm_phase7_7c1_contract.md); explicit Enter-only text commit clarified in `31a08ec008e748c33763b4814c39cc540dcc66e1`.
- **RED focal:** `70d5189ba3a9c01569bdc07cac6c2be0048f0c5b` creates `tests/editor/flow_fsm_flusso_scalar_test.gd`; workflow `436ae51cee8ab871e973c98277a0d534e11aebc0` adds `Potok-7C1 Flusso scalar and undo redo focal`. [Actions 41368002884](https://github.com/mercurysama/Flujo/actions/runs/41368002884) **FAIL** before the commands and form existed.
- **Candidate/UndoRedo commands:** `d4e69b297ac34c524ac08b1870b7d5035535bbd3` adds `FlowGraphEditorCommands.set_fsm_machine_property` and `set_fsm_state_property`. Each resolves by stable IDs, validates exact supported property names/types, builds a detached shallow-copy candidate machine/state graph, compares new ERROR diagnostics against the baseline, and only then commits a single `EditorUndoRedoManager` action on the original resource. A changed resource notifies the controller, refreshes diagnostics and emits `changed`. No candidate copy is written to live graph.
- **Flusso controls:** `816e2a1115c4b68dcccb8bb36e5734ed59f61d36` adds `PotokMachineProperties` and `PotokStateProperties` panels to the existing `FlowGraphInspectorProperty`. Native LineEdit, CheckBox and OptionButton controls expose name, note, enabled, auto-start, tick mode and owned initial-state ID. Text commits explicitly on Enter, not per-keystroke or implicit focus loss; Escape from Fluo without submission does not alter the original resource.
- **Focused test correction:** `5f7c38566d46495040c8aa46ea873948962ab29d` formalizes that disabling the *currently initial* state must be rejected. Earlier post-implementation test [41368222443](https://github.com/mercurysama/Flujo/actions/runs/41368222443) failed because its fixture attempted that forbidden edit, so the test now changes the initial-state ID first. [Actions 41368268066](https://github.com/mercurysama/Flujo/actions/runs/41368268066) **SUCCESS** for the complete regression matrix.
- **Expanded UI test:** `5089266f20c1ec568692922fa3e75ee5cf4953ca` additionally checks Flusso tick selection, initial state selector, machine note and state name, along with scalar rejection, Undo/Redo and state toggle. [Actions 41368408164](https://github.com/mercurysama/Flujo/actions/runs/41368408164) **SUCCESS** for new 7C-1 and existing 7B/7A plus all prior FSM/model/Ready/navigation regression steps.

## Acceptance and boundaries

The automated editor focal proves: invalid enums, foreign initial IDs, empty names, unknown IDs and unsupported fields are rejected without graph mutation; legitimate properties produce undoable actions; undo/redo restores the original property and stable IDs. Selecting or toggling through native Flusso forms invokes the same validated commands. A selected initial state cannot be disabled until a different enabled initial state is selected. Machine and state display changes rebuild the existing stable-ID Flow view. **No runtime or serialization changes**.

This is **not** confirmation of manually operated editor controls, native Android usability, actual save/reopen scene roundtrips, complete state lifecycle authoring, transition forms or Condition Tok/payload expression integration. The test uses the headless Godot 4.7.2 editor scripting harness.

## Next microblocks / recovery

- **7C-2A:** transition authoring with ID-based source/target, validated event/condition trigger metadata, priority and atomic Undo/Redo; define deletion dependencies and cancel policy before editing edges. Keep existing `FlowFSMEditorProjection` and Potok state selection.
- **7C-2B:** add/duplicate/reorder/delete states and transitions with initial-state repair and reference checks, real Cancel confirmation, and undoable structural commands.
- **7D:** Condition Tok `#` authoring and typed event-payload binding from outstanding phase-5 work.
- **7E:** keyboard/touch, focus, save/reopen persistence and final human Android review.

**Recovery:** last source/test checkpoint `5089266f20c1ec568692922fa3e75ee5cf4953ca`, full green [CI 41368408164](https://github.com/mercurysama/Flujo/actions/runs/41368408164), this docs checkpoint. Check branch HEAD and current CI before next lot; do not silently close phase 7.

Todo es Flujo; todo fluye. 🌊
