# Potok 7E-2B1 — Native Potok form focus traversal and modal Escape priority

**Date:** 2026-11-01 local / 2026-11-02 UTC. **Branch:** `feature/fsm-runtime-flow-flusso`. **Baseline:** `554ccb508bc9ee38a9306a292683b03aaed45811`; [CI 41395812326](https://github.com/mercurysama/Flujo/actions/runs/41395812326) SUCCESS (50 steps).

## Why split the approved 7E-2B scope

Fluo Preview 1 already has an actual Flusso **block** panel with session-opening snapshot, immediate edits, `Revertir`, and Escape hierarchy for Ready/Process. Potok schema-3 machine/state/edge properties currently render as native scalar forms **inside the same Fluo Flow view**; those forms do not expose the block `BlockOptionsPanel` or a Potok session snapshot. Claims that Ready `Revertir` already supports Potok are incorrect. Keep the existing Ready contract intact. Split 7E-2B into:
- **7E-2B1 (this contract):** Potok Alt+Page control focus traversal and safe two-level Escape when a Potok Condition Tok or delete confirmation is open; distinguish native Potok form from Ready Flusso. Automated focal and full regression.
- **7E-2B2 (next):** plan/implement a bounded Potok live property session with `Revertir`, exact snapshot/UndoRedo semantics and explicit close/focus behavior; do not silently reuse `restore_ready_block_snapshot` for FSM properties. This is a separate behavioral change with its own contract.

## 7E-2B1 acceptance

1. Preserve Inspector → existing Fluo → Flow schema-3 FSM selection. In a valid scene with a machine, two states and one authored edge, the Potok Machine, State and Transition scalar controls are focusable, selected by stable IDs, and do not mutate on keyboard traversal.
2. `Alt+PageUp/PageDown` traverse **visible, enabled native Potok scalar controls** in stable UI order (machine → state → transition), circularly. `Alt+Shift+PageUp/PageDown` reverses traversal. From Flow state list, forward starts at first available scalar and backward starts at last. Nested SpinBox focus must count as its parent. The existing Ready block-specific Alt navigation continues to win when its real Flusso is open. Do not steal keys when focus is outside Fluo.
3. `Escape` closes the **visible Potok Condition Tok popup first**, without confirming its detached draft or closing Fluo; after cleanup the Flow state list may regain focus. A second Escape closes Fluo and requests Inspector machine-list focus. Similarly Escape cancels the **visible Potok delete ConfirmationDialog** before Fluo, without invoking delete/committing an Undo action. Stale popup contexts remain protected by prior 7D-1/7C-2B guards.
4. Existing Ready Flusso close, Revertir, live edit and focus semantics remain unchanged. Existing global Fluo overlay Escape (no modal) stays intact. No duplicate Inspector list, F4, runtime, schema, model, `demo/main.tscn`, or `main` changes.
5. Verify Godot 4.7.2 `--headless --editor --path . --script` focal, existing `FLUJO-BHV-FLUO-NAV-001`, `FLUJO-BHV-FLUO-EDIT-001`, `FLUJO-BHV-FLUO-DRAWER-001`, FSM 7B/7C/7D/7E focals, model/Ready baselines, editor load, catalog validator and whitespace gate.

## Method, safety and evidence

Read `tools/agent_skills/flujo-baseline/SKILL.md`, `tools/agent_skills/flujo-prove/SKILL.md`, `tools/agent_skills/flujo-fluo-maintenance/SKILL.md`, `AGENTS.md`, `docs/constitution.md`, `docs/current_iteration.md`, `docs/development_workflow.md`, `docs/project_memory.md`, `docs/fluo_preview_01.md`, 7B/7C-1/7D-1/7E-2A contracts and behavior catalog. Existing CI 41395812326 passes 50 steps. GitHub-only API cannot run these local versioned Skills or inspect user's Fedora worktree, so `READY`/`PASA` not claimed; manual visible focus and Android touch pending. Honor two-failure limit per resource, never mask a failing focal by weakening assertions.

Implement a **new focal first** (red on current production for missing Potok key/modal policy), then the smallest existing editor-only changes needed; keep the test and behavior commits distinct. Record both red and green evidence and any cleanup warnings.

**Next:** 7E-2B2 Potok-specific Revertir, then 7E-2C cross-context Undo/Redo focus recovery.

Todo es Flujo; todo fluye. 🌊
