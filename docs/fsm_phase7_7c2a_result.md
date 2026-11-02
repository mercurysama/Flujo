# Potok 7C-2A — Existing transition metadata in Flusso, RED/GREEN checkpoint

**Date:** 2026-11-01 (GitHub CI timestamps UTC 2026-11-02). **Branch:** `feature/fsm-runtime-flow-flusso`.

## Scoped result

**7C-2A AUTOMATED PASS:** an existing transition owned by an authored state can be selected by immutable `transition_id` and edited inside the existing Fluo-owned Flow/Flusso editor. The supported scalar fields are `display_name`, `enabled`, `user_note`, `priority`, `target_state_id`, `trigger` and `event_name`; a validated Bool `FlowValueSource` may be assigned to `condition` **through the command API**, but there is **no visual Condition Tok editor** in this lot.

The command `FlowGraphEditorCommands.set_fsm_transition_property(controller,machine_id,state_id,transition_id,property_name,value)` rejects unknown/wrongly owned edges, blank names, foreign-machine targets, invalid trigger modes, wrong types, non-Bool condition sources and blank active EVENT names. Switching to CONDITION requires an already configured valid Bool source; switching to EVENT requires a nonempty event name. Neither switching direction silently manufactures or deletes the other trigger's data. Edited candidate edge/state/machine resources are detached copies for validation before one atomic `EditorUndoRedoManager` action changes the original resource. Stable authored IDs, order and graph schema remain unchanged.

Flusso now displays `PotokTransitionList` and `PotokTransitionProperties` beneath the selected state's existing fields and Enter/Update/Exit phases. Native LineEdit (Enter commit), CheckBox, SpinBox and OptionButton controls edit name, enabled, integer priority, target by stable state ID, trigger, event and note. A read-only condition status refers to the future Tok editor. When an unavailable trigger is attempted, the selector reverts to the authored value and `PotokTransitionFeedback` explains the missing Bool condition or event name. A state without transitions has an inert **Empty** row and no edit form. Machine/state/controller changes reset stale transition selection.

## Evidence and commits

- **Contract:** `1096d5a02e59dbd074c9fbd0c579d61cbf28ec3d` in [7C-2A contract](fsm_phase7_7c2a_contract.md).
- **RED focal:** `c3b90c37c11d1f1ced595a7b73ecbb9a3a2cb7b5` creates `tests/editor/flow_fsm_transition_metadata_test.gd`, CI step `0f67d70fee29a1f54855a539a2299da0fddf9730`. [GitHub Actions 41371010519](https://github.com/mercurysama/Flujo/actions/runs/41371010519) **FAIL expected**, missing transition command.
- **Minimal command:** `35e787da9e24cdc50b55ddf60f5aca1a41438b8a`. Intermediate [CI 41371091135](https://github.com/mercurysama/Flujo/actions/runs/41371091135) **FAIL expected**, command tests passed but Flusso controls not yet present.
- **Fluo UI:** `a86134f7fcd00ee9737e7d9fd8b49f75cd4b0e38` adds stable-ID selection; `ecc12fc1379a786accb3d3d3147eacacf11db079` adds native property controls. [CI 41371324785](https://github.com/mercurysama/Flujo/actions/runs/41371324785) **SUCCESS** across existing regression matrix.
- **Expanded controls and negative-path coverage:** `8013dc53cdbe49bad976f1f804205c0ac6fde5d4` adds native event/trigger/target/Undo/Empty assertions; `e7f1a97cbbb6ad748d56a77cec965c4f71c46fbf` adds explicit trigger-rejection feedback; `40a9b70075f3a73cf53293b34ac08063e5047a4c` tests that failed trigger selection leaves authored values intact and displays the refusal reason.
- **Full GREEN baseline:** [GitHub Actions 41371757005](https://github.com/mercurysama/Flujo/actions/runs/41371757005) **COMPLETED SUCCESS**, with the complete 7C-2A editor focal and all earlier FSM/model/Ready/navigation regressions. No production FSM runtime modifications in this lot.

## Remaining work / recovery

**7C-2B next:** add/duplicate/reorder/delete states and transitions through validated structural commands, stable-ID dependency checks, initial-state repair and a confirmation dialog with true **Cancel** before destructive edits. Each action must be reversible and not silently orphan edge targets. Keep that contract and its RED/GREEN evidence independent of 7C-2A.

**7D:** Condition Tok `#` authoring, Bool expression editing and typed event-payload-to-expression bindings (open phase-5 debt); do not interpret the 7C-2A condition status label as completed Tok integration.

**7E:** save/reopen roundtrip, input and focus, Android visual/touch acceptance deferred to the consolidated human QA pass.

**Recovery checkpoint:** latest implementation and test commit `40a9b70075f3a73cf53293b34ac08063e5047a4c`, full green Actions `41371757005`, then this docs checkpoint. Recheck branch HEAD and CI before starting 7C-2B. No full phase-7 release claim.

Todo es Flujo; todo fluye. 🌊
