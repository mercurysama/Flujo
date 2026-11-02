# Potok 7E-1D — Two scene saves and independent runtime instances

**Date:** 2026-11-01 local / 2026-11-02 UTC. **Branch:** `feature/fsm-runtime-flow-flusso`. **Result:** AUTOMATED PASS, manual GUI/Android acceptance pending.

## Chain of recovery and executable evidence

- Baseline checkpoint `b2446056cc6d3afbe8cc2ceafa000b0fe81a1f66`, [CI 41394055961](https://github.com/mercurysama/Flujo/actions/runs/41394055961) **SUCCESS** with 48 steps.
- Frozen 7E-1D contract `c4e7d129f79babe26d3a464718137146e2dd3b33`, [CI 41394473898](https://github.com/mercurysama/Flujo/actions/runs/41394473898) **SUCCESS**.
- New isolated test plus CI wiring `7b1e53b8f6cc84669aed254e70cf8e14aeac07cd`, [GitHub Actions 41394604235](https://github.com/mercurysama/Flujo/actions/runs/41394604235) **COMPLETED SUCCESS**, **49 successful workflow steps**, zero failed. The focal `Potok-7E1D repeated scene and instance isolation focal` and the previous 7E/7D/7C, FSM runtime, Ready/navigation/model, editor load, behavior catalog validator and `git diff --check HEAD^ HEAD` checks passed. Commands are from workflow configuration; all steps completed with normal success exit.

## What was implemented and proved

1. New headless `tests/model/flow_fsm_double_roundtrip_instance_isolation_test.gd` creates a schema-3 scene-owned `PVController` with MANUAL-ticked machine, Idle→Active EVENT edge, ordered Enter/Update/Exit authored blocks, initial ID and stable state/edge/block IDs.
2. Save first real `.tscn`; free original; reload and instantiate without cache; verify exact IDs, authored ordering, names, phase content, event target, priority and graph validity. Repack **the reopened scene** as a distinct second `.tscn`; free intermediate, reopen second with `ResourceLoader.CACHE_MODE_IGNORE`, instantiate two copies and verify identical authored model IDs/structure in both. Do not generate replacement internal IDs just because of scene instantiation.
3. Add both instances to SceneTree; each `PVController` starts a **different `FlowFSMRuntime`** while both begin in the authored Idle state. `get_value_resolution_context()` yields distinct per-controller contexts. A transient variable and event packet written to the first are absent from the second, and ending the first packet scope erases it.
4. Queue and deliver a MANUAL-clock event in the first instance only: the first transitions to Active, while the second remains Idle with no queued event. Disabling the first controller stops only its runtime; the second keeps running and can independently transition with its own event. Original authored graph identity, phase ordering, references and validation remain unchanged throughout.
5. Clean only the two owned ignored fixture files under `res://.godot/flujo_tests/`. Add one isolated focal in `.github/workflows/flujo-fsm.yml`. No production `addons/`, schema, runtime engine, GUI, existing tests, behavior catalog expectations, `main` or demo changes.

## Architectural distinction

A `PackedScene` may share the **authored definition Resource** between its instances; this is expected, not a leak of transient runtime state. The contract requires that runtime instances and `FlowValueResolutionContext` remain separate. The test intentionally does **not** assert resource-object inequality, rewrite authored IDs or mutate the graph to simulate local state. This protects portability and avoids unnecessary production changes.

## Skills and verification limits

- Followed the **versioned `$flujo-baseline` procedure remotely** by reading its repository instructions, `AGENTS.md`, Constitution, workflow, active plan/contract and earlier accepted persistence/runtime tests and checking the green baseline [CI 41394055961](https://github.com/mercurysama/Flujo/actions/runs/41394055961). Adjacent catalog boundaries include `FLUJO-BHV-BLOCK-EXTERNAL-PERSIST-001`, `FLUJO-BHV-FLUO-EDIT-001` and existing FSM runtime/context regression. No standalone Skill runner or local Fedora working-tree audit is accessible: **formal READY not claimed**.
- Followed **`$flujo-prove` remote verification procedure** with narrow two-file implementation scope, retained earlier tests, full 49-step green regression, catalog validator and whitespace gate. No standalone Skill invocation, complete local Git index/process inspection, or human visual/touch check was performed: **formal PASA not claimed**.
- Desktop Inspector→Fluo authoring, selection/focus, keyboard shortcuts, Android portrait/landscape touch/scroll and full one-state→two-state authoring journey still require separate coverage and human approval. Do not confuse earlier Android load/render with acceptance.

## Continuity

**7E-1 persistence series 1A, 1B1, 1B2, 1C and 1D now has automated green evidence.** Do not mark phase 7 finished. **Next on 🙆🏻: 7E-2A** — microcontract for Enter/double-click, Up/Down, PageUp/PageDown and Ctrl variants, stable-ID selection and foreign-editor shortcut preservation; measure headless focus/projection where possible. 7E-2B/2C, 7E-3A/3B, 7E-4A/4B and the original phase-block Add authoring gap remain pending. No merge into `main`.

Todo es Flujo; todo fluye. 🌊
