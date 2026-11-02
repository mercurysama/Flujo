# Potok 7E-1C — Typed Condition Tok scene persistence result

**Date:** 2026-11-01 local / 2026-11-02 UTC. **Branch:** `feature/fsm-runtime-flow-flusso`. **Result:** AUTOMATED PASS; manual acceptance pending.

## Recovery checkpoints and CI

- Prior recovery baseline `36e054a4f0f1460b1938e9424e685f7faa14a6bc`; [CI 41392726688](https://github.com/mercurysama/Flujo/actions/runs/41392726688), **SUCCESS**, 47 steps.
- Frozen contract `docs/fsm_phase7_7e1c_contract.md` at `839b4cc508b3a3b60e6faf4bbff25bbef52d6d61`; [CI 41393719862](https://github.com/mercurysama/Flujo/actions/runs/41393719862) **SUCCESS**.
- Test/workflow implementation `4064115ddd7fbe340934d0b63a33efd8d8305015`. [**Full GitHub Actions 41393859434**](https://github.com/mercurysama/Flujo/actions/runs/41393859434) **COMPLETED SUCCESS, all 48 steps passed**: new focal, 7D condition editor/event source/runtime, 7E-1A/1B1/1B2 saved-scene history tests, 7C editor and FSM/runtime/Ready/model/navigation, editor load, behavior catalog validator and latest-diff whitespace gate. No failing steps were observed.

## Implementation and engineering evidence

- New `tests/editor/flow_fsm_condition_tok_scene_roundtrip_test.gd` builds a two-state schema-3 FSM scene and commits a four-row Bool `FlowConditionValueSource` on an authored transition via existing validated `FlowGraphEditorCommands`. A separate command switches EVENT to CONDITION; two Undo and Redo actions restore original and committed transition/source references without new IDs.
- Comparisons use explicit typed `FlowEventPayloadValueSource` for `hp: INT`, `active: BOOL`, `ratio: FLOAT`, `status: STRING`, each with its own stable source ID, matching typed literal source ID/value, stable comparison ID and exact comparison operator. Three AND connectors and outer NOT preserve structure and expression semantics.
- Saves an actual scene while a `FlowValueResolutionContext` has a named per-machine event packet containing a private `POTOK_PRIVATE_PACKET_NEVER_PERSIST_7E1C` sentinel. The saved `.tscn` text excludes that sentinel. After free and cache-ignoring reload, graph/machine/states/transition and nested Tok/operator/source IDs, connectors, NOT and names/types/values are identical; a fresh context cannot resolve until a new matching event is supplied.
- A fresh packet reproduces the same Bool evaluation, changing a Bool field reverses it under NOT/AND and a deliberately wrong INT field type still produces `event_payload_type_mismatch`. Scope ending removes the data. The graph validates before and after re-open.
- `.github/workflows/flujo-fsm.yml` adds exactly one focal with Godot 4.7.2 `--headless --editor --path . --script`. Test fixture lives in ignored `res://.godot/flujo_tests/` and deletes only its own file. No production `addons/`, runtime, schema, editor UI, existing test or behavior catalog assertions, `demo/main.tscn` or `main` changed.

## Actual application of Flujo Skills

- **`$flujo-baseline` instructions applied remotely**, reading `tools/agent_skills/flujo-baseline/SKILL.md`, `AGENTS.md`, Constitution, workflow, 7D contracts, catalog and previous acceptance, and checking original successful baseline CI (47 steps). Relevant adjacent behavior: `FLUJO-BHV-FLUO-EDIT-001`, `FLUJO-BHV-FOCUS-001`, and existing FSM and external-block persistence tests. No standalone Skill invocation, full local Git index or user worktree inspection occurred. **Formal READY not claimed.**
- **`$flujo-prove` instructions applied remotely** through limited scope/diff review, Godot focal, all existing CI regressions, catalog validator, editor load and Git whitespace checks, with normal workflow termination. The standalone Skill runner and complete local process/working-tree/manual audit were unavailable. **Formal PASA not claimed.**
- `$flujo-fluo-maintenance` interaction bounds remain relevant but Fluo UI production files are untouched; `$flujo-block-builder` not applicable. The headless pass is not human approval of the Condition Tok popup, keyboard, Inspector focus or Android touch.

## Decision, limits and next step

Validated existing model serialization rather than changing runtime event resolution or adding persisted event packets. Exact typed operands and operator/connector/source identities are the contract; actual delivered packet fields are intentionally ephemeral. No evidence of a need to change schema or editor production code appeared.

**Still pending:** 7E-1D repeated second save/reopen and independent scene instances, 7E-2 keyboard/selection/focus, 7E-3 layout/context restoration, 7E-4 consolidated manual desktop/Android matrix, and audit of full original phase-7 visual journey and three phase Add-block paths.

**Next on 🙆🏻: 7E-1D**. Reconfirm branch head and CI; freeze a narrow scene-instance independence contract, implement one focal, preserve all prior regressions and document exact evidence. Do not touch `main`.

Todo es Flujo; todo fluye. 🌊
