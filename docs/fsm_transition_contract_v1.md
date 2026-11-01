# FLU-FSM-002 — Deterministic transition protocol

**Scope:** graph-defined directed transitions, instance-local queued requests, Condition Tok evaluation, event triggers and multiple concurrently active state machines.  
**Base:** FSM-001 passed [CI #41334646026](https://github.com/mercurysama/Flujo/actions/runs/41334646026). Model extension passed [CI #41334985294](https://github.com/mercurysama/Flujo/actions/runs/41334985294) after an isolated migrator correction.  
**Status:** specification for implementation on `feature/fsm-runtime-flow-flusso`.

## Determinism and execution order

1. Each `FlowStateDefinition.transitions` is ordered. Its edges have stable IDs, same-machine `target_state_id`, trigger `CONDITION` or `EVENT`, signed integer `priority`, `enabled` and optional `condition` or `event_name`.
2. Only a valid `FlowValueSource` producing a bool can drive a conditional edge. Evaluate through existing `FlowValueResolutionContext` each matching tick; do not cache compiled conditions or rewrite resources.
3. `request_transition(machine_id, target_state_id)` queues an explicit transition (not necessarily an authored edge). Invalid IDs, wrong-machine targets, disabled states or overflow are rejected without side effects. `emit_event(machine_id,event_name)` queues a named event; no matching edge is a normal no-op, not a graph mutation.
4. Max pending requests: 256 per controller. Engine tick snapshots requests **before** Update; requests raised during Update/Enter/Exit defer to the next tick.
5. A matching clock executes Update first. Then exactly one candidate per machine may commit, ordered: direct requests FIFO, matching event triggers by higher priority and authored index, then true conditions by higher priority and authored index. A candidate targeting the active state is a no-op. Skip stale/invalid candidates; never loop transitions in one tick.
6. Transition commit sequence is Exit(old) → set active ID → Enter(new). New state's Update happens only in the next matching tick. Cross-machine requests remain queued until the target machine's own clock ticks.
7. Per-controller queues and state live only in `FlowFSMRuntime`. `FlowGraph` and nested resources remain immutable in games. No reentrant tick, no repeated Entry/Exit, no unbounded transition cycles.
8. Schema 3/4 only in this milestone, per FSM-001. Schema 5 runtime is not implicitly enabled.
9. Stop clears pending requests and exits each active machine exactly once. Controller disable and scene exit clear instance-only runtime. No hidden persistence or editor writes.
10. Headless tests must cover priority/order, direct/event/condition, missing state rejection, deferred requests, multiple machines, no shared instance state, and old Ready/Timer/navigation regressions. Manual UI verification remains a separate phase.

**Implementation boundary:** Core scheduler here; persisted editor tooling, dynamic states, snapshots and debug panel are later milestones.

Todo es Flujo; todo fluye. 🌊
