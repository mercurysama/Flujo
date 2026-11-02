# Potok 7E-2B2 — Per-resource Revertir of machine, state and transition scalars

**Date:** 2026-11-02. **Branch:** `feature/fsm-runtime-flow-flusso`. **Baseline:** `ac0d003971ec1d40c2b771ae63e844e3980dea37`, [CI 41396996333](https://github.com/mercurysama/Flujo/actions/runs/41396996333) SUCCESS (55/55).

## Independent authoring session

Revertir for Ready/Process blocks already works, but Potok Machine/State/Transition scalar forms are **not** those block options. Add one `Revertir` control to each visible native Potok scalar form, without introducing a duplicate Inspector Blocks list or a new Fluo hierarchy. The FSM session captures its *own* supported scalar fields at entry: **Machine** `display_name`, `enabled`, `auto_start`, `tick_mode`, `user_note`, `initial_state_id`; **State** `display_name`, `enabled`, `user_note`; **Transition** `display_name`, `enabled`, `priority`, `target_state_id`, `trigger`, `event_name`, `user_note`. Condition Tok source is separate and not silently rolled back.

1. Snapshot capture is keyed by actual `PVController`, `FlowGraph`, target `Resource` object and stable machine/state/edge IDs. Machine session starts when a machine form is shown; state session starts for the selected state; edge session starts for selected edge. Ordinary UI rebuilds after live edits or Undo/Redo must retain the opening snapshot. Switching target/resource, changing controller or graph, or closing Fluo ends the affected session; returning later captures a **new** opening snapshot. No snapshot data belongs to the persisted graph.
2. Existing scalar edits continue to apply immediately using approved validated `FlowGraphEditorCommands`. Revertir restores **all supported scalar fields for exactly one selected resource** to that session's opening snapshot, but only if the *complete candidate* is valid; reject a stale ID, missing/deleted target, wrong field set or type, or newly invalid dependency without changing any field or adding an Undo step. Do not silently restore unrelated machine/state/edge properties.
3. For successful multi-field revert, create exactly **one** nonmerged UndoRedo action attached to the same `PVController`: Undo restores the pre-revert edited fields; Redo restores snapshot values. Stable IDs, authored order, nested Condition Tok resources, and cross-field consistency are unchanged. No-op Revertir adds no history.
4. Keep Revertir's snapshot constant throughout its open session. Multiple edits followed by Revertir again restore that same opening value; a fresh session after switching away and back uses current values as its new baseline. Closing Fluo/Escape remains **close without rollback**. Cancel/decline/delete dialogs and late callbacks on stale UI do not revert or commit inadvertently.
5. Test real Fluo controls (machine/state/edge), live change + Revertir, no-op, Undo/Redo of multi-field change and stale-context rejection; test command guard directly for invalid candidate. Add a new 4.7.2 headless editor CI focal; retain the existing 55-step CI and Fluo ProcessTimer/Ready Revertir/Drawer regressions.

## Safety

Limit changes to `addons/vp_flujo/editor/flow_graph_editor_commands.gd` and `addons/vp_flujo/editor/flow_graph_inspector_property.gd`, a dedicated focal, one CI step and scoped docs. No schema/runtime/model/source migrations; no change to `FluoDrawer` unless real focal forces it; no `main`, `demo/main.tscn`, release or user local files. Adopt existing `_fsm_candidate_accepted` detached-candidate validation and UndoRedo with original target identity. Keep all previous accepted UI contracts; only headless claims until human desktop/Android review.

## Skill guidance

Versioned `$flujo-baseline`, `$flujo-prove`, `$flujo-fluo-maintenance` instructions consulted, along with AGENTS, Constitution, current iteration, workflow, project memory, Fluo preview, 7C-1/7C-2A/7E-2B1 contracts and behavior catalog (`FLUJO-BHV-FLUO-EDIT-001`, `FLUJO-BHV-FLUO-NAV-001`, `FLUJO-BHV-FOCUS-001`). Baseline [CI 41396996333](https://github.com/mercurysama/Flujo/actions/runs/41396996333) passed 55 configured steps. The GitHub connector cannot directly invoke local repository Skills or inspect Fedora's Git worktree; formal `READY`/`PASA` is not claimed. Physical keyboard, visual focus and Android acceptance remain PENDING.

**Next:** 7E-2C Undo/Redo focus/selection recovery across Inspector → Fluo → Flow; 7E-3 layout, 7E-4 manual matrix and phase Add-block journey remain open.

Todo es Flujo; todo fluye. 🌊
