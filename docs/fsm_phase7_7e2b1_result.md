# Potok 7E-2B1 — Potok Alt scalar focus and modal Escape priority

**Date:** 2026-11-01 local / 2026-11-02 UTC. **Branch:** `feature/fsm-runtime-flow-flusso`. **Result:** AUTOMATED PASS; human desktop/Android acceptance PENDING.

## Evidence and recovery chain

- Baseline checkpoint `554ccb508bc9ee38a9306a292683b03aaed45811`; [CI 41395812326](https://github.com/mercurysama/Flujo/actions/runs/41395812326) **SUCCESS**, 50 steps.
- Narrow 7E-2B1 contract `888027ad7d847f2169b5de0c0ef782c9d0c558a2`; [CI 41396241043](https://github.com/mercurysama/Flujo/actions/runs/41396241043) SUCCESS, 50 steps.
- Test first `ffaede4aef1251efb4b33d91d195b800fbb4e0d3`; [**RED CI 41396344559**](https://github.com/mercurysama/Flujo/actions/runs/41396344559) **FAILED, expected characterization failures only**: missing Alt movement to Potok scalar controls, first Escape closing Fluo instead of condition/delete popup, lost Flow focus after modal close. Godot script parsed/ran, prior whitespace/catalog/editor steps passed; the test ended with exit code 1 and prevented later steps from running. This is not a green baseline and is retained as evidence of the pre-fix behavior.
- Small fix in existing editor-only files at `2b7673862d0a50e8233abba168ef0bb4b27444ab`; [CI 41396486742](https://github.com/mercurysama/Flujo/actions/runs/41396486742) **SUCCESS, 51 steps** including the same unchanged 7E-2B1 focal.
- Skill-required Fluo focal expansion at `cb9d34de80b8e712531f5b89d69d824613b03795` (YAML only). [**Full CI 41396669545**](https://github.com/mercurysama/Flujo/actions/runs/41396669545) **COMPLETED SUCCESS, 55 of 55 steps**; exit 0 across all steps, including all previous FSM/Ready/model/navigation, catalog validator and Git whitespace check.
- Explicit passing markers in the final job log:
  - `[Flujo] Process and Timer editor focal passed`
  - `[Flujo] Flusso owned-property Revertir test passed`
  - `[Flujo] Fluo drawer test passed`
  - `[Flujo] Fluo drawer integration test passed`
  - `[Flujo] Potok 7E-2B1 Alt and modal Escape passed`

## Exactly what changed

1. New `tests/editor/flow_fsm_potok_flusso_escape_test.gd` drives actual `FluoDrawer._input(InputEventKey)` and the Potok machine/state/transition controls, with valid schema-3 FSM and stable source IDs. It asserts Alt+PageDown forward, Alt+Shift+PageDown reverse, Alt+PageUp backward wrap, and no keyboard theft from a foreign editor control.
2. `addons/vp_flujo/editor/flow_graph_inspector_property.gd` adds `cycle_potok_option_focus(direction)`: ordered native scalar controls from `PotokMachineProperties`, `PotokStateProperties`, `PotokTransitionProperties`; ignores absent/invisible/unfocusable/disabled buttons, recognizes nested focus owners such as SpinBox internal editor, wraps; focus movement is read-only. Adds `close_potok_transient_dialog()` to cancel only a visible owned Condition Tok or delete ConfirmationDialog and return focus to `PotokStateList` without calling editor commands.
3. `addons/vp_flujo/editor/fluo_drawer.gd` routes Escape to Potok popup/confirmation **before** block details and drawer close, then follows existing close behavior; Alt shortcuts try existing Ready Flusso option navigation **before** Potok scalar focus, preserving Ready priority. Unsupported Ctrl+Alt+Page is not captured. When no modal is open, Escape retains the original global-overlay close and Inspector focus relay.
4. `.github/workflows/flujo-fsm.yml` adds new Potok 7E-2B1 focal and, in a separate CI commit, explicit tests `flow_process_timer_editor_test.gd`, `flow_revert_owned_properties_editor_test.gd`, `fluo_drawer_test.gd`, and `fluo_drawer_integration_test.gd`. These all extend `SceneTree` and use Godot 4.7.2 headless editor invocation, with individual timeout boundaries. Previous steps/assertions remain unchanged.

**Implementation scope diff from contract commit to CI commit:** `addons/vp_flujo/editor/fluo_drawer.gd` (9 inserted lines), `addons/vp_flujo/editor/flow_graph_inspector_property.gd` (52 inserted lines), one added test (~235 lines), and 15 added CI YAML lines. No `FlowGraph` or FSM runtime/editor model changes, no schema, `demo/main.tscn`, old catalog assertions, `main` modifications, merges or releases.

## Important semantic boundary: Potok vs Ready Flusso

- Existing Ready/Process **block** `BlockOptionsPanel` already captures a selected `FlowBlock` owned-property session snapshot, edits immediately, supports `Revertir`, and closes with Escape without rollback. Existing tests explicitly confirmed it still works (markers above).
- Potok FSM machine/state/transition scalar forms display Flusso headings within the existing Flow view, **but do not use the block options snapshot**. This microblock does not claim that Potok supports Revertir or has a separately closing machine/state/edge Flusso session. That work requires a scope-specific `7E-2B2` contract with ID/context-bound snapshots and validated UndoRedo; do **not** apply Ready's `restore_ready_block_snapshot` to state-machine resources.
- Condition Tok and delete confirmation are **temporary modal actions**, not Flusso property Revertir. Escaping them cancels their draft/confirmation, does not execute a transition/state deletion or commit the popup's draft.
- Headless `_input` invocation plus real focus owner tests do not certify native physical key dispatch, popup OS window stacking, Android soft/hardware keyboard or touch: those remain human review.

## Skill-guided checks and stderr limitations

- Read versioned `tools/agent_skills/flujo-baseline/SKILL.md`, `flujo-prove/SKILL.md`, `flujo-fluo-maintenance/SKILL.md`, `AGENTS.md`, Constitution/current iteration/project memory/Fluo preview, 7B/7C/7D/7E contracts and behavior catalog. Scope maps to `FLUJO-BHV-FLUO-NAV-001`, `FLUJO-BHV-FLUO-EDIT-001`, `FLUJO-BHV-FLUO-DRAWER-001`, `FLUJO-BHV-FLUO-OPEN-001`, `FLUJO-BHV-FOCUS-001`. The baseline 50-step CI succeeded on the exact pre-change HEAD.
- **`$flujo-baseline`: remote checks applied, direct Skill invocation not available; formal READY NOT CLAIMED.** GitHub connector cannot inspect Fedora's staged/unstaged/untracked state or run a local agent Skill.
- **`$flujo-prove`: remote checks applied, direct Skill invocation not available; formal PASA NOT CLAIMED.** Reviewed production/test/CI scope, one intentionally red characterization and green targeted/full CI, and latest-commit whitespace, model/Ready/Fluo regressions. No human visual approval or full local worktree/process audit.
- **`$flujo-fluo-maintenance`: applied architectural/shortcut and focus rules**; not directly callable as installed executable.
- Headless editor shutdown may log RID/ObjectDB resource-leak warnings even with successful normal process termination, already observed in pre-change baseline. The expected negative FSM snapshot parser test logs deliberate invalid-JSON errors. Neither is silently labeled a clean stderr result. No new unhandled `SCRIPT ERROR` in the 7E-2B1 passing focal.

## Next independent step

**7E-2B2 — Potok live property Revertir session**, after confirming current HEAD and successful CI. Need an explicit specification for captured machine/state/edge supported scalar fields, opened/closed session boundary, selection changes and stale IDs, safe Revertir action using existing validated editor commands and UndoRedo (ideally one action for a multi-field revert), immediate live-edit persistence on close, Escape boundary, focus restoration and no extra Inspector list. Keep scope separate from already functional Ready Revertir. Then 7E-2C cross-context UndoRedo focus and 7E-3/4 manual layout/touch checks.

**Metrics from evidence:** 1 expected red CI run, 2 subsequent successful implementation/coverage CI runs (51 then 55 steps), 4 added Fluo regression entries, 2 editor source files changed; human measurement not performed. **No merge to `main`.**

Todo es Flujo; todo fluye. 🌊
