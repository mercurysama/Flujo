# Potok 7E-1B2 — Structural FSM Undo/Redo and saved-scene persistence

**Date:** 2026-11-01 local / 2026-11-02 UTC. **Branch:** `feature/fsm-runtime-flow-flusso`. **Baseline HEAD:** `9784930890fa6542e5922010a41fb289254ce57b` and [CI 41390491468](https://github.com/mercurysama/Flujo/actions/runs/41390491468), SUCCESS.

## Narrow acceptance contract

Completes the remaining **7E-1B2** segment of the original phase-7 item 9 (saved scene/identities/repeated UndoRedo), cross-referenced to 7C-2B structural authoring; follows [7E-1B1](fsm_phase7_7e1b1_result.md), which already tests scalar edits, state reorder and saved scenes.

1. Create a valid schema-3 scene-owned `PVController` with one machine, states A and B, one Enter phase block owned by A, an A self-loop and an A-to-B event transition. Record all graph/machine/state/phase/edge IDs.
2. Use **only existing `FlowGraphEditorCommands`** in `--headless --editor` to duplicate A (new stable state, phase block and transition IDs; remap duplicated self-loop), add C, move C, add/duplicate/move/delete C-owned event transitions, change the surviving edge target through the existing validated metadata command, and delete initial state A (with atomic initial-state repair). Reject deleting B while incoming edges exist, without mutating B.
3. Execute **two complete reverse Undo and forward Redo cycles** on the actual editor history, checking exact initial state ID, ordered state/transition IDs, duplicated nested IDs, edge targets, phase block ownership and `FlowGraphValidator` after each full cycle. No ID regeneration in Redo.
4. `PackedScene.pack` / `ResourceSaver.save` the final edited scene into the ignored `res://.godot/flujo_tests/` directory, free original scene, `ResourceLoader.CACHE_MODE_IGNORE` reload and instantiate it. Check exact authored order, stable IDs, target references and copied Enter phase block, graph validation; remove **only** this test-owned file.
5. Add a dedicated Godot 4.7.2 Actions focal, retain all existing checks and the last-commit `git diff --check HEAD^ HEAD` gate. Document observed CI success/failure and recovery.

## Invariants and exclusions

- **No** modifications to production, model/schema, runtime, Fluo UI, `main`, `demo/main.tscn`, existing tests or catalog assertions; this is new combined regression coverage for already-approved 7C-2B behavior and 7E persistence.
- State identity and references are always internal IDs, never display names or array positions. Duplicating a state preserves order, allocates new IDs, remaps its self-loop and preserves its external target. Deleting the initial state must pick first enabled survivor; incoming dependencies must not be silently rewritten.
- Retain 7E-1C typed Tok/payload serialization, 7E-1D multi-scene cycles, 7E-2/3 focus/layout, 7E-4 human Android/desktop visual acceptance as **PENDING**, not implied by this test.
- Scope evidence: `FLUJO-BHV-FOCUS-001`, `FLUJO-BHV-FLUO-EDIT-001`, `FLUJO-BHV-DELETE-001`; [existing 7C-2B focal](../tests/editor/flow_fsm_structural_commands_test.gd) and existing Fluo Cancel focal must remain green.

## Repository Skill gates

Before authoring: instructions in `tools/agent_skills/flujo-baseline/SKILL.md`, `AGENTS.md`, `docs/constitution.md`, `docs/development_workflow.md`, `docs/current_iteration.md`, `docs/behavior_catalog.json`, and applicable contracts consulted. Current remote baseline CI 41390491468 SUCCESS, including catalog validator, editor load, 7C-2B, 7E-1B1 and model/Ready/Fluo regressions. GitHub connector cannot invoke `$flujo-baseline` as a standalone agent or inspect Fedora's working tree, so formal READY is **not claimed**.

After authoring, apply `$flujo-prove` instructions by auditing scope/diff, CI focal+regressions, actual completion and whitespace gate; report direct Skill unavailable and manual UI separately. If CI fails, do not claim acceptance. No need for a separate Block Builder Skill (outside requested scope).

**Next after green CI:** 7E-1C Condition Tok and typed event source save/reopen; prior to closing 7E, audit original nine phase-7 requirements for hidden gaps.

Todo es Flujo; todo fluye. 🌊
