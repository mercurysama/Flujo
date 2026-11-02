# Potok 7E-2C — UndoRedo stable-ID selection and semantic focus restoration

**Date:** 2026-11-02. **Branch:** `feature/fsm-runtime-flow-flusso`. **Outcome:** AUTOMATED PASS; manual visible keyboard/focus and Android approval PENDING.

## Exact checkpoints and regression evidence

- Initial baseline `cc46244540a3c24edefcc6092146e0a122f06c14`; [GitHub Actions 41398682792](https://github.com/mercurysama/Flujo/actions/runs/41398682792) **SUCCESS (56/56)**. Existing 7E-2B2 machine/state/edge Revertir and Ready/Fluo navigation were passing.
- Frozen specification `docs/fsm_phase7_7e2c_contract.md`, commit `e3461a79b9abef581f44aa66f1de348cb5bc2c49`; [CI 41399149130](https://github.com/mercurysama/Flujo/actions/runs/41399149130) **SUCCESS**.
- Test-first `b31c41672dec5845127dd1705fd176bc4fd3d4f5`; [RED CI 41399398547](https://github.com/mercurysama/Flujo/actions/runs/41399398547) **FAILED as an expected characterization**. The complete headless test parsed/executed and found lost actual focus after live edit, two Undo/Redo cycles, edge list selection/edit and missing focus fallback after deletion; IDs and model changed as expected. Prior checks passed through the new focal; later workflow steps were not run. This is **not** a successful CI.
- Editor-only focus fix `3f5286c721d1c2e39df2b4d4ca238b3e6a4144cc`. [**Full CI 41399683013**](https://github.com/mercurysama/Flujo/actions/runs/41399683013) **COMPLETED SUCCESS (57/57 successful steps)** on this exact fix. Explicit marker `[Flujo] Potok 7E-2C UndoRedo focus, selection and stale callbacks passed`, plus `Potok 7E-2B2 Revertir atomic FSM sessions passed`, `Potok 7E-2B1 Alt and modal Escape passed`, `Flusso owned-property Revertir test passed`, `Fluo drawer integration test passed` and remaining FSM/Ready/model/validator/whitespace tests.

## Behavior and implementation

1. `tests/editor/flow_fsm_undo_focus_recovery_test.gd` creates a valid machine with three states (two equal display names), two authored event transitions, and a real `FluoDrawer` → `FlowGraphInspectorProperty` editor instance. It checks Inspector machine ID, Flow state ID and transition ID rather than labels/row position.
2. Native State Name live edit, then **two repeated Undo/Redo cycles**, each replace the underlying editor UI; the test verifies actual focus on the **new** `PotokStateName` control, exact same stable selected IDs and correct persistent scalar values. Transition list selection, Transition Note edit, Undo and Redo similarly retain a live `PotokTransitionList`/`PotokTransitionNote` focus and exact edge ID.
3. The test emits a stale signal from an old transition form while selecting a different state: no edit is permitted on the new state or previously authored edge. Deleting the second selected edge via the **real confirmation dialog** falls back to the surviving edge's ID and a live Flow State list; Undo restores the exact deleted edge without selecting a stale row, and Redo deletes it again without losing focus.
4. When a foreign editor `LineEdit` owns focus, Undo and external refresh cannot steal it. After Fluo is closed, further history callbacks cannot reopen it or restore invisible/detached focus. Graph validates and all authored machine/state IDs remain stable.
5. `addons/vp_flujo/editor/flow_graph_inspector_property.gd` adds a **transient semantic focus descriptor**: current Potok control name plus controller WeakRef and selected machine/state/edge IDs, captured before a deferred UI rebuild; no Control object is retained. After render a generation-guarded callback resolves the **new** live control by name; if the state/edge changed, it falls back to a live Flow State list; if Fluo closed/controller/machine changed or a foreign control took focus, it does nothing. Explicit navigation's `_flow_entry_focus_pending` retains priority. Successful structural deletion requests the safe Flow fallback.
6. `.github/workflows/flujo-fsm.yml` adds one bounded Godot 4.7.2 headless `--editor --script` focal. **Implementation diff** compared with contract commit: 63 added lines in the existing Inspector editor, ~299-line new focal, 3 CI YAML lines; no modifications to persistent model, runtime, `FluoDrawer`, Ready Revertir, prior tests/catalog, `demo/main.tscn`, `main` or release artifacts.

## Verification limits and Skills

- New headless focal is successful with normal process exit, and full GitHub Actions job finished SUCCESS. Existing Godot editor shutdown RID/ObjectDB warnings and deliberate invalid-JSON negative-test diagnostics can be emitted in the broader workflow; do not describe stderr as entirely clean.
- **`$flujo-baseline`**: followed repository procedures remotely (AGENTS, Constitution, current iteration, workflow, Fluo preview, preceding phase-7 contracts, behavior catalog, green 56-step baseline). **Formal READY not claimed** because direct Skill execution and local Fedora staged/unstaged/untracked Git inspection were unavailable.
- **`$flujo-prove`**: remotely reviewed the committed diff scope, test-first RED and restored GREEN, 57-step CI with validator/whitespace/editor/Ready/Fluo and FSM regressions. **Formal PASA not claimed** without native Skill, local worktree/process audit and physical GUI review.
- **`$flujo-fluo-maintenance`**: applied focus ownership, stable selection and no-duplicate Inspector rules as guidance; not invoked as autonomous Skill. The CI tests simulate editor controls and key-handler behavior, **not** a real Fedora physical keyboard, visually observed ring/selection or Android touch focus. Those remain PENDING.

## Handoff

**7E-2A, 7E-2B1, 7E-2B2 and 7E-2C have automated evidence.** This does not close phase 7's original end-to-end UI authoring journey or manual review.

**Next on 🙆🏻: 7E-3A**, real Fluo ScrollContainer/overflow/long settings/editor resize measurements and layout guards; split further if necessary. Then 7E-3B focus/context cleanup, 7E-4A/B desktop+Android manual matrix and original one-state→two-state Enter/Update/Exit Add-block visual authoring acceptance. No merge to `main`.

Todo es Flujo; todo fluye. 🌊
