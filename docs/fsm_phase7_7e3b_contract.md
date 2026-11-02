# Potok 7E-3B — Drawer lifecycle, controller/scene context recovery

**Date:** 2026-11-02. **Branch:** `feature/fsm-runtime-flow-flusso`. **Green baseline:** `3b333a41d4afc8d1ac53f54bc36913ff73d74205`, [CI 41403125429](https://github.com/mercurysama/Flujo/actions/runs/41403125429), 58/58 SUCCESS.

## Purpose

Inspector→Fluo→Flow keeps separate lifetimes for Godot scene, `PVController`, authored machine/process selection, current Flow/Flusso session, and left/right drawer presentation. Removing a selected controller or switching the active scene/controller must never leave an open Fluo editing a stale resource; a *normal user close* must continue to restore the previous valid Inspector focus.

## Acceptance boundaries

1. **Normal close:** after opening an existing schema-3 machine with a focused external Inspector-like control, Escape/close restores that valid external control, closes exactly one drawer, preserves current left/right placement, and leaves authored machine/state IDs untouched. Closed Fluo can reopen and focus Flow with the same stable model.
2. **Different controller while Fluo open:** an external selection/context change to a different valid `PVController` closes the old Fluo, cancels transient Condition/Delete/Ready block details/sessions, clears prior selected machine/state/edge IDs, and does **not** steal keyboard focus by restoring the previous scene's Inspector control. The new controller is retained for a subsequent explicit `open_container`; that invocation opens its own correct machine by ID with fresh Flusso. Never copy A's snapshot/Undo context into B.
3. **Controller removed:** actual `tree_exited` of the selected controller closes Fluo and clears owner and selection references, without reopening, accepting stale callbacks, or stealing an unrelated focused editor control. A later replacement controller can be opened independently. Do not equate an unrelated removed node with current controller.
4. **Scene switch / null selection:** the plugin's existing `_set_controller(null)` path and the drawer's `set_controller(null)` must yield a closed surface and blank Flow context with no old model or dangling popup. This is the same context boundary used by `scene_changed` and scene-tree removal signals; tests must not globally alter an actual user's editor scenes.
5. **Process/Timer compatibility:** within the *same* controller, navigating from a machine to its Ready Process/Timer container through existing `open_container` retains Fluo's known open state and correct Process editor, without an unnecessary forced close. Changing to another controller while viewing Ready invokes the same stale-context closure. Left/right placement persists across closes, controller switching and reopening; no duplicate Drawer/Inspector Blocks list.
6. One new Godot 4.7.2 editor headless focal checks the actual `FluoDrawer` and genuine scene-tree controller removal. The existing 58-step CI continues unchanged (new focal added), including `fluo_drawer_test.gd`, `fluo_drawer_integration_test.gd`, `flow_process_timer_editor_test.gd`, `flow_fsm_fluo_navigation_test.gd`, condition/editor/UndoRedo, validator, whitespace and runtime. Headless proves controller/lifecycle invariants, **not** actual desktop/Android scene-switch visual approval.

## Scope and method

Test-first, then fix only a demonstrated editor lifecycle defect in `addons/vp_flujo/editor/fluo_drawer.gd` if possible. No runtime, persistent schema, model IDs, F4/dock architecture, editor plugin refactor, `demo/main.tscn`, `main` or release packaging. No user-scene modification. Keep separate checkpoints and exact red/green CI evidence.

**Skill procedures:** read versioned `$flujo-baseline`, `$flujo-prove`, `$flujo-fluo-maintenance` plus AGENTS, Constitution, current iteration, development workflow, project memory, Fluo preview, phase-7 roadmap and catalog IDs `FLUJO-BHV-FLUO-OPEN-001`, `FLUJO-BHV-FLUO-NAV-001`, `FLUJO-BHV-FLUO-DRAWER-001`, `FLUJO-BHV-FOCUS-001`. Standalone local Skills, Fedora worktree and physical GUI cannot be audited by GitHub connector; do not claim formal READY/PASA or manual visual acceptance.

**Next:** 7E-4A human acceptance scenario instructions, then 7E-4B consolidated matrix. Original one-state/two-state Enter/Update/Exit visual Add-block authoring remains a separate gate.

Todo es Flujo; todo fluye. 🌊
