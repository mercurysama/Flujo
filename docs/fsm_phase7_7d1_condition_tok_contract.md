# Potok 7D-1 — Condition Tok # editor bridge in Flusso

Date 2026-11-01; branch `feature/fsm-runtime-flow-flusso`; code baseline `3e2d5e70df1d9b02db71d22b540c625bfc656c11`.

## Scope
Connect **existing** `FlowConditionEditor` to an existing transition's `condition: FlowConditionValueSource` through `FlowGraphInspectorProperty`. This is a visual authoring bridge for the Bool Condition Tok `#`, not a new string evaluator, serialized graph field or runtime path. Existing generic `FlowConditionEditor` owns source/literal/variable operands, comparisons, AND/OR and NOT, and its own validation/Cancel semantics. Use its `open_for_condition(initial,graph,anchor,context)` API. The popup always edits `duplicate_with_new_id()` or an empty draft, never the original condition.

- The selected transition's Flusso shows `PotokTransitionConditionEdit` **Edit Condition #** even when trigger is EVENT: this prepares a valid Bool source for a later switch to CONDITION. Show an authored preview, if present, via `FlowConditionValueSource.get_preview(graph)`, otherwise explicit empty status. Non-`FlowConditionValueSource` Bool condition sources remain intact until a user deliberately confirms a new Condition Tok (no implicit conversion).
- Opening does not mutate the original graph or create an Undo history entry. Cancel, Escape, X/close and `popup_hide` discard the draft without calling `set_fsm_transition_property`. A valid Confirm uses the pre-existing, validated, atomic `set_fsm_transition_property(...,&"condition", source)` and one `EditorUndoRedoManager` action; do **not** automatically toggle EVENT to CONDITION. Rejected confirms keep the previous source.
- The callback commits only if the original `PVController`, machine ID, state ID and transition ID are all still current. Changing selection/controller, closing Fluo, or selecting a different transition invalidates the pending popup and closes it without writes. Re-check controller and model ownership on confirm. Keep popups outside the rebuildable `_content` tree.
- Source IDs from the detached draft must not equal those on the replaced source; Undo restores the exact original instance/IDs, Redo restores the accepted snapshot and preserves source/edge IDs. Variable references require an existing `FlowGraph` variable with matching declared type, and graph validator must pass.
- Add a dedicated headless Godot editor focal and CI step; ensure the full 7C-2B/7C-2A/6H/Ready regression matrix passes. No manual visual/touch/Android claims.

## Separated 7D-2 dependency
Typed event-payload-to-expression binding is **not** an automatic property of the `event_consumed` signal. The existing runtime chooses a matching EVENT edge directly, while CONDITION edges resolve only during fallback with the controller's variable resolution context. Before any change, specify whether payload is visible during event-triggered Enter/Exit, or a persisted machine-local event snapshot, and how JSON-safe numeric/string/bool types and missing keys behave. No silent ambient last-event or stale cross-controller access. 7D-2 must have a contract, RED, minimal GREEN and CI independently. The combined Potok 7D remains partial until both sublots are accepted.

Todo es Flujo; todo fluye. 🌊
