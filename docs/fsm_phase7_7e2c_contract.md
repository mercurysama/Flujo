# Potok 7E-2C — Undo/Redo selection and focus restoration

**Date:** 2026-11-02. **Branch:** `feature/fsm-runtime-flow-flusso`. **Baseline HEAD:** `cc46244540a3c24edefcc6092146e0a122f06c14`, [CI 41398682792](https://github.com/mercurysama/Flujo/actions/runs/41398682792) SUCCESS, 56/56 steps.

## Narrow contract

The already accepted Fluo/Flow/Flusso editor uses native Godot controls, stable machine/state/transition IDs and immediate validated UndoRedo commands. Undo/Redo and live edits invoke `FlowGraphInspectorProperty._on_commands_changed()`, which removes/recreates `_content` controls in a deferred rebuild. 7E-2C preserves the *semantic* keyboard focus across those rebuilds, not the old Control object. No persistent model or schema changes.

1. Existing schema-3 Inspector machine selection stays on its stable machine ID. Flow selected state and transition remain on their stable IDs through live edits, two successive Undo/Redo cycles and Revertir; identical visible names do not change identity.
2. If a Potok UI control (state ItemList, transition ItemList, or machine/state/edge native field including Revertir) owns actual focus before a command changes the model, the rebuilt editor restores real keyboard focus to the **new control instance with the same stable semantic name** if still present. Do not retain freed Node references; use a name + generation check, and restore only if the controller and machine match and Fluo is still open.
3. If a selected edge/state was structurally removed, the rebuilt Flow must choose an actual surviving ID, **not a deleted ID or previous row index**; return focus to the appropriate live Flow state list when the prior focused field disappeared. If the last edge was deleted, it must show Empty with no transition fields, not attempt focus on a deleted transition field.
4. Existing rollback/UndoRedo through `FlowGraphEditorCommands` remains atomic; do not create extra actions when restoring focus. Do not mutate the graph when selecting or focusing. A stale callback from a control detached by a rebuild must not edit the new selected resource.
5. If a foreign editor control outside Fluo owns focus, Undo/Redo and external `refresh_controller()` cannot steal it. Explicit Fluo Escape/close and machine switching retain existing prior rules; no focus resurrected after close/controller change, and deferred callbacks guard their generation/ownership.
6. Add an isolated `--headless --editor --path . --script` Godot 4.7.2 focal and preserve all 56 prior workflow steps, especially `flow_fsm_potok_revert_session_test.gd`, `flow_fsm_keyboard_navigation_test.gd`, `flow_fsm_potok_flusso_escape_test.gd`, `flow_fsm_structural_commands_test.gd` and Fluo ProcessTimer/Ready Revertir/Drawer regression.

## Scope and evidence

**Start test-first.** If a focused test exposes the missing behavior, make a small editor-only fix to `addons/vp_flujo/editor/flow_graph_inspector_property.gd`, without runtime, model, schema, `FluoDrawer`, `demo/main.tscn` or `main` changes. Keep contract, test, code and evidence as independently recoverable commits. No simulated physical keyboard or Android acceptance claim: headless focus ownership is measurable, but human desktop focus/shortcut and Android touch testing are separate.

## Skill boundaries

Read `tools/agent_skills/flujo-baseline/SKILL.md`, `flujo-prove/SKILL.md`, `flujo-fluo-maintenance/SKILL.md`, `AGENTS.md`, Constitution, `docs/current_iteration.md`, development workflow, `docs/project_memory.md`, `docs/fluo_preview_01.md`, previous 7E-2A/2B1/2B2 contracts/results and catalog entries including `FLUJO-BHV-FOCUS-001`, `FLUJO-BHV-FLUO-NAV-001`, `FLUJO-BHV-FLUO-EDIT-001`, `FLUJO-BHV-FLUO-DRAWER-001`. Baseline branch CI passed, but repository Skills cannot be invoked as standalone agents via GitHub tools and local Fedora index/worktree cannot be inspected: **do not claim formal READY/PASA**. Manual visible focus approval remains pending.

**Next:** 7E-3A Fluo scrolling/disposition, then 7E-3B context recovery and 7E-4 desktop/Android human review. Original phase-7 phase-block Add authoring review remains open.

Todo es Flujo; todo fluye. 🌊
