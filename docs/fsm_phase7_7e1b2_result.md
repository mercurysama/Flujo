# Potok 7E-1B2 — Structural Undo/Redo + saved-scene persistence result

**Date:** 2026-11-01 local / 2026-11-02 UTC. **Branch:** `feature/fsm-runtime-flow-flusso`. **Status:** **AUTOMATED PASS**, visual approval pending.

## Recoverable chain and CI

- Pre-task HEAD `9784930890fa6542e5922010a41fb289254ce57b`, [CI 41390491468](https://github.com/mercurysama/Flujo/actions/runs/41390491468) **SUCCESS** (46 steps).
- Frozen task contract `839c490aafede1b1e69f20fb517b2ef4afa4c681`, [CI 41392438210](https://github.com/mercurysama/Flujo/actions/runs/41392438210) **SUCCESS**.
- Focused test + workflow commit `4984b6c39b0062676e99b268b31a8528daf99aac`.
- [Full GitHub Actions **41392544536**](https://github.com/mercurysama/Flujo/actions/runs/41392544536) **COMPLETED SUCCESS**, **47 steps successful**, including `Potok-7E1B2 structural UndoRedo scene roundtrip focal`, editor load, behavior catalog validator, whitespace gate, previous 7E-1B1/1A, 7C-2B and prior Potok/Ready/model/Fluo regressions.

## Implemented and validated

1. New `tests/editor/flow_fsm_structural_scene_roundtrip_test.gd` (Godot 4.7.2 `--headless --editor --path . --script`) creates scene-owned schema-3 `PVController` with a two-state FSM, phase Enter block, A self-loop and A → B event edge.
2. Calls existing `FlowGraphEditorCommands` for ten atomic accepted actions: duplicate state A, add state C, move C, add edge, duplicate edge, move edge, delete original edge, add another edge, set its target to B, then delete initial state A. Unsafe delete of referenced B is explicitly rejected. Duplicate A creates distinct nested block and edge IDs, remaps its self-loop and retains target B; deleting A repairs the initial ID to first enabled survivor.
3. Two complete sets of ten Undo calls followed by ten Redo calls restore exact original/final authored state and edge order, initial/target IDs, original and duplicated phase/transition IDs; `FlowGraphValidator` succeeds after each full cycle.
4. Packs, saves and reloads the scene in the ignored fixture directory `res://.godot/flujo_tests/` with `ResourceLoader.CACHE_MODE_IGNORE` after freeing the original; validates exact reopened machine, graph, state, nested phase and edge IDs, target references and copied Enter content; deletes only its own fixture.
5. Adds one isolated focal to `.github/workflows/flujo-fsm.yml`, retaining the other CI steps including scoped `git diff --check HEAD^ HEAD`. No production files under `addons/`, runtime, schema, editor UI, prior test assertions or `demo/main.tscn` changed.

## Applying repository Skills: actual vs unavailable

- Read the versioned `tools/agent_skills/flujo-baseline/SKILL.md` and `tools/agent_skills/flujo-prove/SKILL.md` directly from GitHub, plus `AGENTS.md`, Constitution, current iteration, workflow, prior 7C-2B and 7E contracts and behavior catalog. Relevant IDs: `FLUJO-BHV-FOCUS-001`, `FLUJO-BHV-FLUO-EDIT-001`, `FLUJO-BHV-DELETE-001`. Catalogued baseline and relevant Potok focal success on exact pre-task HEAD were verified in [CI 41390491468](https://github.com/mercurysama/Flujo/actions/runs/41390491468).
- **`$flujo-baseline` = remote procedure followed; direct Skill invocation NOT AVAILABLE**, so no formal `READY`. GitHub API does not expose Fedora's index/working tree, and there was no standalone local Godot executor in this session.
- **`$flujo-prove` = remote checks applied; direct Skill invocation NOT AVAILABLE**, so no formal `PASA`. Confirmed scoped test/workflow changes, preserved existing assertions, green full CI (focal+regressions+validator+editor-load+Git whitespace gate) and normal job termination. Full local working-tree, processes, protected user files and manual acceptance were not audited.
- `$flujo-fluo-maintenance` boundaries remain unchanged. `$flujo-block-builder` is irrelevant here. Passing headless tests does **not** certify desktop GUI keyboard/focus or Android portrait/landscape touch behavior.

## Scope decision and next microblock

- Technical decision: reuse validated 7C-2B editor commands and Godot `PackedScene` serialization rather than add ad hoc resource rewrites or modify the FSM runtime. Protected invariants: schema 3, machine/state/edge/phase stable IDs, no orphaned targets, author order, atomic undo, no changes to `main`.
- Known exclusions: Condition Tok typed operand serialization (7E-1C), multi-scene independent instance cycles (7E-1D), Inspector→Fluo visual focus and keyboard UI (7E-2), layout/context restoration (7E-3), consolidated desktop and Android manual acceptance (7E-4). The full original nine phase-7 items still require a closure audit, including adding blocks to phases visually.
- **Next on 🙆🏻: 7E-1C**, inspect current HEAD and CI; create a narrow contract for nested Bool Condition Tok `#` and typed event-field source serialization without ephemeral packet values. Implement a focused persisted scene test and independent successful CI. Do not merge `main`.

Todo es Flujo; todo fluye. 🌊
