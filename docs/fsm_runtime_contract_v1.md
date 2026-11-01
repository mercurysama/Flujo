# Flujo FSM runtime contract — FLU-FSM-001 (implementation boundary)

**Date:** 2026-11-01  
**Status:** approved implementation scope in isolated branch; automated and human acceptance are separate.  
**Source:** [full FSM plan](fsm_implementation_plan.md).  
**Target:** Godot 4.7.2, portable GDScript.

## Milestone 001 — one-state executable machine

1. Preserve `FlowGraph.state_machines`, machine IDs, `initial_state_id` and the existing `FlowStateDefinition.blocks` collection. Existing `blocks` unambiguously means the **Update** phase.
2. Add optional `enter_blocks` and `exit_blocks` ordered, typed collections to `FlowStateDefinition`. An old saved state without them loads empty phases. No automatic rewriting of existing `blocks`.
3. Add optional machine `tick_mode` (**PROCESS**, **PHYSICS**, **MANUAL**) and `auto_start` with compatible defaults. Run supported schema 3/4 only; schema 5 remains out of scope until its separate executor contract is approved.
4. Keep authored graph resources read-only in games. Each `PVController` owns a distinct `FlowFSMRuntime` instance with a map `machine_id → active_state_id`. Never store active state in a Resource.
5. Start an enabled valid machine at its own nonempty initial-state ID and execute Enter exactly once; update only on its selected tick; execute Exit once on stop/reset. A one-state machine needs no transition. Empty machines stay editable but cannot run.
6. Invoke blocks through the existing generic `FlowReadyExecutor._execute_blocks` contract, with distinct `StateEnter`, `StateUpdate`, `StateExit` output entry labels. Keep existing Ready/Timer behavior unchanged.
7. Preserve IDs, order and deliberate `null` positions for all three block phases in deep copy and save/load. Validate extra phase blocks with the existing read-only validator.
8. A disabled controller or disabled machine must not continue update; cleanup is isolated per instance. Use a bounded executor and do not reenter tick.
9. No new persistent schema number: the added phase and mode fields are optional additive fields with explicit defaults and legacy `blocks` semantics. Regression tests must prove old scenes still load and code does not mutate shared definitions.
10. Manual and automated results are not interchangeable. Use `$flujo-baseline` and `$flujo-prove` and maintain the historical failing preflight runs; automated GitHub Actions is the remote evidence source.

## Deferred follow-on contracts (must not be reported complete at milestone 001)

- FLU-FSM-002: typed transitions, stable destination IDs, Condition Tok bool evaluation, FIFO queued event requests, deterministic priority and multi-machine cross-requests.
- FLU-FSM-003: instance-only dynamic states, removal safety and quotas.
- FLU-FSM-004: save/load of portable snapshots, EPHEMERAL/SESSION/PERSISTENT lifespan.
- UI-FSM: Inspector → Fluo → Flow/Flusso state-phase-transition authoring, typed chips, Undo/Redo, focus and Android touch.
- DEBUG-FSM: runtime inspection, trace and diagnostics without authoring side effects.

## Traceability

| ID | Model/runtime files | Planned tests |
|---|---|---|
| FSM-R01/02/03 | `flow_state_machine_definition.gd`, `flow_fsm_runtime.gd` | `tests/runtime/flow_fsm_runtime_test.tscn` |
| FSM-R04 | `flow_graph.gd`, `flow_state_definition.gd` | model duplication + persistence focal |
| FSM-R05/06/07 | `pv_controller.gd`, `flow_fsm_runtime.gd` | same graph / two controller instances |
| FSM-R08 | existing `flow_ready_executor.gd` | Ready, Timer, navigation baselines |

**Completion requires the new FSM tests, all affected regressions, and the later grouped human review.**

Todo es Flujo; todo fluye. 🌊
