# Potok 7E-1B1 — Edited FSM scene roundtrip and repeated Undo/Redo

**Date:** 2026-11-01 local. **Branch:** `feature/fsm-runtime-flow-flusso`.
**Checkpoint:** `165992706fbde431ce878611137dc519128b42c2`. **Requirement:** original phase 7 item 9 / FSM-R25 / T25, with item 5 atomically undoable commands. Complements 7E-1A and 7C-1 / 7C-2B, does not replace either.

## Approved narrow scope

Test-only extension. Reuse existing `FlowGraphEditorCommands` and `EditorUndoRedoManager`; do not edit production, persistent model, runtime or `demo/main.tscn`.

1. Build valid schema-3 `FlowGraph` inside scene-owned `PVController`, a machine with three ordered states and a stable-ID EVENT edge pointing to another owned state.
2. From the existing editor commands, rename one state, move another state by one authored slot, and rename the machine. Confirm initial/target references use stable IDs, not names/positions.
3. Undo the three actions in reverse order; redo all three in order. Repeat the full undo/redo cycle twice and assert that names/order, machine/state/transition IDs and references restore exactly. Rejected unknown-state edit does not mutate the graph.
4. Save as a real PackedScene `.tscn` under the existing ignored test-owned `res://.godot/flujo_tests/`, release the live scene, reload without resource cache and instantiate; compare final edited name, authored order, IDs and edge reference exactly. Reopened graph passes `FlowGraphValidator`. Clean only the owned fixture file.
5. Wire one separate `--headless --editor --script tests/editor/flow_fsm_edited_scene_roundtrip_test.gd` step into `.github/workflows/flujo-fsm.yml`. Run full prior FSM/Ready/model/navigation regression suite in GitHub Actions.

## Safety and exclusions

- No manual UI acceptance inferred. No Condition Tok payload semantic roundtrip (7E-1C); no structural create/duplicate/delete save test (7E-1B2); no Android claims.
- Do not modify graph and editor resources outside validated commands. No new IDs on Undo or Redo, no changes to schema version or runtime. No extra serialized packets.
- Validator, editor-load, focal, `git diff --check HEAD^ HEAD` and existing regression steps are remote verification, not a runnable standalone Skill executor.
- Each commit gets its own CI evidence. Any unexplained red test blocks further dependent work.

## Baseline gate (skill-guided)

Read `tools/agent_skills/flujo-baseline/SKILL.md`, `AGENTS.md`, Constitution, development workflow, model and 7C/7E contracts, behavior catalog. At `165992706fbde431ce878611137dc519128b42c2`, [CI 41389506373](https://github.com/mercurysama/Flujo/actions/runs/41389506373) completed SUCCESS for model, Ready, navigation, catalog validator, editor load, 7C-1 scalar, 7C-2B structural, 7E-1A saved-scene tests. Relevant catalog: `FLUJO-BHV-FOCUS-001`, `FLUJO-BHV-FLUO-EDIT-001`, `FLUJO-BHV-DELETE-001`; none of their test assertions are weakened. GitHub API cannot show the developer's uncommitted working tree or run an agent Skill in this session. **Baseline proof is remote/partial, not a formal `$flujo-baseline READY` result.**

## Next microblock

7E-1B2 structural/transition command history and reopened scene; then 7E-1C Tok source persistence. Track CI, exact SHAs, limitations and `$flujo-prove` applicability in `docs/fsm_phase7_7e1b1_result.md`.

Todo es Flujo; todo fluye. 🌊
