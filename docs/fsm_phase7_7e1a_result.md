# Potok 7E-1A — Authored FSM save/reopen automated result

**Date:** 2026-11-01 local / 2026-11-02 UTC. **Branch:** `feature/fsm-runtime-flow-flusso`.
**Recovery baseline:** `16a1d3034fbcaff7a4180e7d897884fc3da5f83e`, [CI 41382577892](https://github.com/mercurysama/Flujo/actions/runs/41382577892) SUCCESS.
**Implementation HEAD:** `96322e705475c3fd80e944935136332a28f0785a`.
**CI on implementation HEAD:** [Actions 41389274900](https://github.com/mercurysama/Flujo/actions/runs/41389274900), **COMPLETED SUCCESS**, 2026-11-02 04:36 UTC.
**Result:** AUTOMATED PASS for focused persistence + all configured CI regression steps; human/manual acceptance PENDING.

## Scope delivered

1. `tests/model/flow_fsm_authored_scene_roundtrip_test.gd` creates a normal scene-owned `PVController` with a schema-3 `FlowGraph`, two ordered states and an event transition; packs/saves a `.tscn`, reopens and instantiates it, compares graph/machine/state/edge/phase-block IDs, initial and target references, Enter/Update/Exit order and block content, metadata and graph validation.
2. `.github/workflows/flujo-fsm.yml` adds the focused Godot 4.7.2 headless test command:
   `timeout --signal=TERM --kill-after=5s 45s ./Godot_v4.7.2-stable_linux.x86_64 --headless --path . --script tests/model/flow_fsm_authored_scene_roundtrip_test.gd`
3. `docs/fsm_phase7_7e1a_contract.md` freezes the focused acceptance; `docs/fsm_phase7_microblocks.md` subdivides remaining 7E into recoverable lots. No production source, runtime scheduler, schema or `demo/main.tscn` changed.

## Verification and limits

- **PASS:** new "Potok-7E1A authored scene persistence focal" CI step; model, Ready, navigation, Potok 7A–7D and earlier configured FSM regression steps on implementation HEAD; catalog validator and editor load included in same successful workflow.
- **NOT RUN:** standalone local `$flujo-baseline` / `$flujo-prove` invocation, Fedora Godot commands and `git diff --check` (no local Godot or checkout in this GitHub-only session). Existing remote baseline and full green CI provide independent evidence, not a substitute for the formal skill gates. **Do not mark full `$flujo-prove` PASA.**
- **PENDING HUMAN:** actual Inspector→Fluo authoring journey, keyboard/focus/Revertir and Android portrait/landscape touch, scrolling, closure and rotation.
- **NOT TESTED IN THIS LOT:** command edits with Undo/Redo, Condition Tok `#` / typed payload operands, multi-scene re-saves, programmatic saved-scene mutations or independent runtime restoration.
- **Scope audit:** four changed files in implementation commit; one isolated test fixture cleaned from `res://.godot/flujo_tests/`; no `main` integration.

## Why this approach

Reuse the project's existing `PackedScene` / `ResourceSaver` persistence convention instead of introducing a parallel serialization format. A separate small regression isolates authored identity/phase-order failures without touching production behavior. Rejected alternative: changing the schema or FSM runtime to satisfy a UI acceptance test; neither is justified by current evidence.

## Next recovery

1. Read this result, the 7E map and the prior 7D results; fetch the **current** branch HEAD and Actions state, rather than assuming the implementation SHA remains latest.
2. **7E-1B:** freeze a narrow contract for validated editor commands, repeated Undo/Redo, save/reopen and stable IDs; add focused editor regression in a separate commit; follow baseline/CI proof. If too big, divide into `7E-1B1` and `7E-1B2`.
3. Continue 7E-1C Tok source roundtrip, 7E-1D repeated scene cycles, 7E-2 focus, 7E-3 layout and 7E-4 manual matrix. Do not audit away unfinished phase-7 items.
4. Once 7E acceptance is recorded, audit existing phases 8/9 against contracts before new implementation.

Todo es Flujo; todo fluye. 🌊
