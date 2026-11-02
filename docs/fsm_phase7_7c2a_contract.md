# Potok 7C-2A — Transition metadata in Flusso (no structural edits)

Date: 2026-11-01. Branch `feature/fsm-runtime-flow-flusso`. Baseline `3beabd432290b5679ce1acba5b02fdc7ae293f11`.

## Scope and graph safety

- Edit only **existing** `FlowStateTransitionDefinition` edges owned by an exact `machine_id` and `source_state_id`, addressed by their stable `transition_id`. No adding/removing/reordering transitions or states (7C-2B); no runtime, schema or serialization changes.
- Allowed scalar properties: `display_name: String` (nonblank), `enabled: bool`, `user_note: String`, `priority: int`, `target_state_id: String` (must refer to a state in the **same** machine, including the source state), `event_name: StringName` (nonblank when current trigger is EVENT), `trigger: int` (only CONDITION or EVENT). Replacing `condition: FlowValueSource` is allowed through the command API only with a valid Bool source; the visual Tok `#` condition editor and event-payload expression adapter are deferred to 7D.
- **Atomic trigger change:** do not silently generate or discard conditions. Switching to EVENT requires an existing nonblank `event_name`; switching to CONDITION requires an existing Bool-typed valid `condition`; otherwise reject with diagnostics and leave original unchanged. The existing condition and event name survive mode switches. Provide UI read-only condition status. No implicit conversion from `true` to a Bool condition or event name invented by the editor.
- Validation is done against a detached candidate graph: duplicate edge → owning state → machine *without changing stable IDs*, replace only the target child path, run existing `FlowGraphValidator` and reject any **new** ERROR versus the baseline; do not mutate actual resources before success. Keep explicit typed/ownership guards even if baseline is already invalid. Use a single `EditorUndoRedoManager` action for do/undo, plus diagnostics and `changed` notification on assignment. A rejected/no-op command creates no history action.
- Fluo Flow continues to select machine and state via stable IDs. Inside the selected state display `PotokTransitionList` (authored order, named IDs) and `PotokTransitionProperties` for the selected edge. Native LineEdit (commit on Enter), CheckBox, SpinBox (integer priority), and OptionButton (target ID and trigger). Condition status is explicit; show a meaningful refusal when the user selects an unavailable trigger. Changing source state, controller or machine clears edge selection. Each failed command rebuilds controls from the model, never leaving a false local value.
- Preserve existing 7A/B/7C-1 navigation, initial-state selection, machine/state scalar forms, event FIFO/priority runtime semantics and Escape. Headless Godot 4.7.2 editor focal + complete GitHub CI required.

## Focused acceptance

1. Existing EVENT edge: change target, priority, event name, enabled, label and note; stable edge ID remains unchanged. Invalid foreign target/unknown edge/blank event/invalid trigger type/condition type leave graph unchanged and do not grow history.
2. A prepared Bool condition edge can toggle EVENT↔CONDITION using stored metadata, with Undo/Redo; an EVENT-only edge cannot switch to CONDITION without a valid Bool source. A prepared but invalid non-Bool source must fail. A valid source candidate may be assigned through command and undone.
3. Flusso selection, controls and native signals call validated commands; changing selected state does not leak edge forms; Edit/Undo/Redo and graph validation pass. No visual Android claim.

## Next

7C-2B creates, duplicates, reorders or deletes states/transitions with dependency repair and true Cancel confirmation. 7D adds Condition Tok `#` authoring and payload-to-expression binding. 7E handles save/reopen and Android human acceptance. This lot must not be described as a full condition editor.

Todo es Flujo; todo fluye. 🌊
