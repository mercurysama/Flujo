# Potok 7E-1C — Nested Bool Condition Tok and typed event-source persistence

**Date:** 2026-11-01 local / 2026-11-02 UTC. **Branch:** `feature/fsm-runtime-flow-flusso`. **Baseline:** `36e054a4f0f1460b1938e9424e685f7faa14a6bc`, [CI 41392726688](https://github.com/mercurysama/Flujo/actions/runs/41392726688) SUCCESS (47 steps).

## Scoped acceptance

The original phase-7 save/reopen contract must preserve Condition Tok `#` **authored semantic data**, separate from the per-tick event packets which are **never persisted**. This closes the 7E-1C portion of 7E, not the full manual UX acceptance.

1. Reuse schema-3 `FlowGraph`, scene-owned `PVController`, one machine, two states, one event transition initially. Through existing `FlowGraphEditorCommands.set_fsm_transition_property`, author a full valid Bool `FlowConditionValueSource` and change the transition's trigger to CONDITION. Ensure both changes are accepted as atomic editor actions, undo/redo once, and preserve original/current source identities.
2. The Bool source has four `FlowConditionComparison` rows, three AND connectors, an outer NOT flag, and typed `FlowEventPayloadValueSource` operand sources covering **INT, BOOL, FLOAT, STRING** with exact `event_name`, `field_name`, `value_type`, stable `source_id`, exact operator IDs, literal typed source IDs and values. Save/reopen must preserve all row order, comparison IDs, connector order, negation, operand types, names, source IDs and the transition target/ID.
3. Record a deep-copied event packet containing all four fields plus a unique **private sentinel** inside `FlowValueResolutionContext`, not the graph. During the scope the condition resolves under its Bool semantics; after ending scope, resolution fails with no ambient packet. Save the scene while the runtime context is active, ensure the actual `.tscn` text **does not contain the private sentinel**, reload with `ResourceLoader.CACHE_MODE_IGNORE` and instantiate. The reopened condition cannot resolve without a *new* packet; with a fresh correctly scoped packet it must resolve with the exact same authored semantics. Confirm a deliberate type mismatch still fails.
4. Execute one new isolated Godot 4.7.2 CI focal and retain all 7D-1/7D-2/7E-1A/7E-1B1/7E-1B2, model, Ready, navigation, governance, editor load and whitespace checks. Clean only the named test-owned scene file under `res://.godot/flujo_tests/`.

## Explicit boundaries

No changes to `addons/` production sources, Flow schema, runtime event semantics, global Tok popup, Fluo UI, `demo/main.tscn` or `main`. Do not serialize packet values, infer types, coerce types, persist machine tick state or let the scene incorporate `FlowValueResolutionContext`. Runtime context must remain separate and ephemeral.

This is a headless authoring/persistence test, **not** visual proof of the `#` popup, keyboard focus or Android touch. It does not change EVENT-first arbitration or the fallback-only condition semantics specified by 7D-2. After 7E-1C, continue 7E-1D and then 7E-2 through 7E-4. Audit remaining original phase-7 gaps before closing phase 7.

## Skill-guided gates and recovery

- Read `tools/agent_skills/flujo-baseline/SKILL.md` and `tools/agent_skills/flujo-prove/SKILL.md`, `AGENTS.md`, Constitution, development workflow, relevant 7D-1/7D-2 contracts, behavior catalog and approved 7E evidence. No direct invocation of the versioned agent Skills or Fedora Git working-tree audit is available via this GitHub connector; do not claim formal READY/PASA.
- Verify before test changes: [full baseline 41392726688](https://github.com/mercurysama/Flujo/actions/runs/41392726688) SUCCESS on `36e054a4f0f1460b1938e9424e685f7faa14a6bc`. Existing 7D editor and runtime focal tests cover acceptance/cancel/typed event diagnostics; 7E scene tests cover stable IDs. Catalog IDs `FLUJO-BHV-FLUO-EDIT-001`, `FLUJO-BHV-FOCUS-001` and persistent sources are adjacent boundaries; do not weaken assertions.
- Deliver test and CI in a separate commit; preserve original prior tests. Record actual job exit status, logs if red, whitespace gate and human review limits in `docs/fsm_phase7_7e1c_result.md` before next recovery.

Todo es Flujo; todo fluye. 🌊
