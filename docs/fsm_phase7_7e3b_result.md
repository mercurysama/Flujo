# Potok 7E-3B — Fluo controller/scene context lifetime

**Date:** 2026-11-02. **Branch:** `feature/fsm-runtime-flow-flusso`. **Result:** AUTOMATED PASS (59 steps); manual desktop/Android UI and true editor scene-switch acceptance PENDING.

## Exact recovery and evidence

- Prior verified HEAD `3b333a41d4afc8d1ac53f54bc36913ff73d74205`, [CI 41403125429](https://github.com/mercurysama/Flujo/actions/runs/41403125429) **SUCCESS (58 steps)**.
- Frozen contract `decc47054f915676e6b9455bf59d78f7f7ba357c`, [CI 41403694905](https://github.com/mercurysama/Flujo/actions/runs/41403694905) **SUCCESS (58 steps)**.
- New test/CI commit `3af7cc149b7b1a0436b192e4774c1bd7c5b53c35`. [RED CI 41403809934](https://github.com/mercurysama/Flujo/actions/runs/41403809934) **EXPECTED FAILURE**. The script parsed and executed; four failed assertions confirmed open Fluo after different-controller selection, real controller `tree_exited`, a stale `refresh_controller()`, and null scene/controller selection. Prior tests through the focal passed; later steps were not executed. Errors in the focal caused exit 1, not a green baseline.
- Minimal drawer lifecycle fix `9240aa06651bc600d18bfb99d06f3ec0b8b2e73f`. [**CI 41403989846**](https://github.com/mercurysama/Flujo/actions/runs/41403989846) **COMPLETED SUCCESS, all 59 workflow steps**, with `[Flujo] Potok 7E-3B scene/controller context restoration passed`, `[Flujo] Fluo drawer integration test passed`, `[Flujo] Process and Timer editor focal passed`, and `[Flujo] Potok 7E-3A native scroll, overflow and resize passed`. All existing FSM model/runtime/7D/7E, Ready, Fluo Revertir, navigation, behavior catalog validator, editor load and whitespace checks remained green.

## Implementation and preserved invariants

- `tests/editor/flow_fsm_drawer_context_recovery_test.gd` uses the **actual `FluoDrawer`** and two independent scene-tree `PVController` nodes with schema-3 machine and Ready Process definitions. It validates distinct stable authored IDs/graphs, native external focus, normal close, side placement, same-controller machine→Process route, different-controller context, real `tree_exited` after removing the selected node from its parent, stale refresh, reattachment and null context, and a clean re-open.
- `addons/vp_flujo/editor/fluo_drawer.gd`: within `set_controller`, when the owner actually changes and Fluo is open, clear the old focus reference and perform a **forced close before rebinding** to the new controller. This clears modal editors, temporary sessions and prior Flow selections through existing teardown. The new context is retained but **not automatically opened**; explicit Inspector activation remains required. Repeated same-controller selection is still a no-op.
- In `_on_controller_tree_exited`, similarly close the open overlay without restoring an old Inspector focus target before clearing the controller binding. This prevents an orphaned open Fluo after a scene node is detached and ensures late `refresh_controller` never resurrects old fields.
- **Normal user close is unchanged:** valid previous focus is restored using the existing weak reference; left/right placement persists even after forced teardown. Native Potok state IDs, machine IDs and Ready Process IDs are never rewritten. A same-controller Process/Timer switch does not close Fluo or create a second Inspector Blocks list.
- Change review from baseline through fix: one new `docs/fsm_phase7_7e3b_contract.md`, one new focal test, three workflow lines, and **ten inserted production lines** in `FluoDrawer` with no deletions. No `FlowGraph`/runtime/schema, `plugin.gd`, `main`, demo, release or other plugin files changed.

## Verification limitations and Skills

- This headless test exercises **the real drawer controller-change and tree-exit boundaries**, **not** an actual user's open Godot scene tab switching or native Inspector repaint: the main plugin already routes `scene_changed`, `node_removed`, and selection changes through `_set_controller`, but its end-to-end host UI must still be manually observed. The outside-focus button models a valid Inspector-like focus target. Human Fedora and Android focus, scene switching, gestures and touch behavior remain **PENDING**. Existing Godot headless shutdown RID/ObjectDB leak warnings are separate from the successful job exit.
- Consulted and followed versioned `$flujo-baseline`, `$flujo-prove` and `$flujo-fluo-maintenance` as **GitHub-based procedures**, checking `AGENTS.md`, Constitution/current iteration, workflow/project memory, Fluo preview, relevant catalog IDs (`FLUJO-BHV-FLUO-OPEN-001`, `FLUJO-BHV-FLUO-NAV-001`, `FLUJO-BHV-FLUO-DRAWER-001`, `FLUJO-BHV-FOCUS-001`), red/green CI, exact diff and previous Fluo/Ready FSM regressions. **Standalone repository Skill runner and Fedora local working-tree/index audit unavailable**; formal READY/PASA not claimed.
- No other changes, merge or release were authorized. The single red run was preserved as before-fix evidence, not suppressed or weakened.

## Handoff

**Next on 🙆🏻: 7E-4A**, write a reproducible human review matrix for desktop Godot 4.7.2 on Fedora and Godot Android portrait/landscape, including Inspector→Fluo, focus, Revertir, Tok, scrolling, controller unload and state transitions; leave every unobserved manual result as PENDING. Then 7E-4B consolidate manual evidence and audit the original phase-7 one-state to two-state Enter/Update/Exit phase Add-block authoring workflow. A CI PASS alone cannot close phase 7.

Todo es Flujo; todo fluye. 🌊
