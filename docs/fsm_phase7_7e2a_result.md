# Potok 7E-2A — Fluo FSM keyboard routing and stable-ID focus result

**Date:** 2026-11-01 local / 2026-11-02 UTC. **Branch:** `feature/fsm-runtime-flow-flusso`. **State:** AUTOMATED PASS, desktop/Android human keyboard acceptance pending.

## Recovery checkpoints and observable evidence

- Pre-task baseline `c89d6d44fac1dd43ed09213b788c4295ce0ef162`, [CI 41394826608](https://github.com/mercurysama/Flujo/actions/runs/41394826608) **SUCCESS** (49 steps).
- Frozen spec `docs/fsm_phase7_7e2a_contract.md`, commit `8acbb823e260440aecdc19cde847231e772596a6`, [CI 41395355247](https://github.com/mercurysama/Flujo/actions/runs/41395355247) **SUCCESS**.
- Test and workflow implementation `9a7b6358b3a3351e13332683e7321a75ec3c9e9c`. [**GitHub Actions 41395513992**](https://github.com/mercurysama/Flujo/actions/runs/41395513992) **COMPLETED SUCCESS, all 50 workflow steps succeeded**. Focused test prints `[Flujo] Potok 7E-2A keyboard machine/state selection and focus passed` and has a successful termination. Workflow includes latest-commit whitespace check, Godot 4.7.2, behavior catalog validator, editor load, model/Ready/navigation baselines, 7B and 7C/7D/7E persistence/runtime focals.

## Implemented scope

1. New `tests/editor/flow_fsm_keyboard_navigation_test.gd` uses the existing `FluoDrawer` and `FlowGraphInspectorProperty` with a live editor host and schema-3 fixture. It verifies the native Inspector activation relay with stable machine ID and opens the same Fluo surface, not a duplicate Inspector list or legacy dock.
2. The FSM has three states (two with equal visible names) plus a separate empty machine. Native `ItemList.item_selected` signals, used by Up/Down, change the selected **internal ID** and restore focus after the Flow UI rebuild. `Ctrl+PageDown` and `Ctrl+PageUp` follow authored state order cyclically without switching machine or mutating `FlowGraph`; after externally reordering the authored fixture, selected ID still maps to the correct new row.
3. The existing `FluoDrawer._input` route is exercised with actual `InputEventKey` objects: plain PageUp/PageDown changes machine by stable ID and emits `schema_3_container_navigation_changed` for Inspector synchronization; it does not enter sibling Process routes or create states in an Empty machine. Flow list focus is regained after navigation.
4. Plain PageDown from a focused Potok `LineEdit` leaves the text buffer/focus and selection intact. `Ctrl+PageDown` still advances state and restores Flow keyboard focus. Unsupported Ctrl+Alt+PageDown does not change FSM selection. When a foreign editor control owns focus, plain/Ctrl Page events do not steal it or redirect FSM selection.
5. The test also verifies unchanged initial-state ID, graph validity, authored state IDs/order after deliberate fixture reorder, and no process changes. `.github/workflows/flujo-fsm.yml` adds one bounded `--headless --editor --path . --script` focal. **Only two implementation paths changed:** the new test and CI YAML. No production `addons/`, schema/runtime, F4, live Inspector/Fluo source, existing tests, catalog assertions, demo or `main` changed.

## Diagnostics separated from success

- The new focal passed and the GitHub job finished SUCCESS; no `SCRIPT ERROR` messages were found in the job log.
- Godot 4.7.2's headless editor shutdown **did log RID/ObjectDB resource leak messages** after the passing marker, also present in the **previous baseline** CI 41394826608's headless editor tests. These are not silently classified as clean shutdown diagnostics. The job nevertheless returned successful termination; the original GUI/engine resource cleanup remains an independent investigation if it becomes an acceptance blocker.
- The existing negative FSM snapshot test deliberately parses malformed JSON and logs an `ERROR: Parse JSON failed` while asserting safe rejection; this is unrelated to 7E-2A and not a new passing claim about malformed input.
- Physical key press dispatch to native Up/Down ItemList and real Inspector repaint, editor-global shortcut conflicts, accessibility/focus under desktop UI and Android hardware keyboard/touch remain for **manual inspection**. The test emits the public ItemList selection signal and calls the existing drawer key handler, not a physical device event.

## Applying Flujo repository Skills

- **`$flujo-baseline` — procedures consulted/applied remotely; not directly invoked:** read versioned Skill, `AGENTS.md`, Constitution/workflow, `docs/current_iteration.md`, `docs/project_memory.md`, `docs/fluo_preview_01.md`, original 7B contract and catalog; verified the exact pre-task full green CI and mapped `FLUJO-BHV-FOCUS-001`, `FLUJO-BHV-FLUO-OPEN-001`, `FLUJO-BHV-FLUO-NAV-001`, `FLUJO-BHV-FLUO-EDIT-001`. No local working-tree/index access; **formal READY not claimed**.
- **`$flujo-prove` — procedures consulted/applied remotely; not directly invoked:** audited intended scope against two-file Git comparison; existing scenarios/assertions untouched; required new focal and all 50 configured CI steps passed, including validator, editor and whitespace. No standalone Skill executor, human visual review or complete local process/worktree audit; **formal PASA not claimed**.
- **`$flujo-fluo-maintenance` — contextual instructions applied:** kept Inspector/Flow/Flusso focus boundaries and shortcut vocabulary; the existing overlay-global Escape close behavior intentionally **unchanged**, with its deeper hierarchy deferred to 7E-2B. `$flujo-block-builder` not relevant.

## Decision and handoff

Reused existing keyboard/selection routing rather than replacing Fluo architecture or adding a second Inspector list. Focused headless assertions exposed **no production code defect within this 7E-2A scope**; therefore did not change the editor. Relevant alternative (globally changing Escape behavior) was rejected because it risks breaking previously accepted Fluo overlay tests and belongs to the later Escape-specific review.

**Next on 🙆🏻: 7E-2B**, a separate Flusso focus/Revertir/Escape/Alt traversal contract and focal test. **Still pending:** 7E-2C repeated Undo/Redo focus recovery; 7E-3 layout/context; 7E-4 desktop+Android manual matrix; original phase-7 Enter/Update/Exit block-add visual authoring closure audit. Do not merge to `main`.

Todo es Flujo; todo fluye. 🌊
