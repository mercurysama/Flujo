# Potok 6H — Negative requests, scene order and shutdown guard

Date: 2026-11-01. Branch: `feature/fsm-runtime-flow-flusso`. Baseline: `1d24807b6ed5119afa76cca70ff256f9b037b72c`.

## 6H-1 — Multi-controller negative routing

Two `PVController` instances can share the same immutable `FlowGraph`; their state/queues are independent, including if their scene-tree sibling positions are swapped. The actual runtime resolves machine IDs from the authored graph, never node position or `display_name`. Within the graph, one MANUAL machine is enabled and auto-starts, one is enabled but `auto_start=false`, and one is disabled. Direct and event requests to the latter two or to unknown machine IDs must return false, emitting exactly one `request_rejected(...,invalid_machine)` each without queue mutations or changes on either controller. A foreign state target on an active machine yields `invalid_target`. An accepted request on controller B cannot make controller A transition. Run explicit clock ticks and verify order-independence.

A machine cannot be deleted from a running authored graph as a supported runtime operation; do not mutate shared resources to fake machine deletion. Dynamic-state removal has its separate tests. No new public registry needed if current behavior passes.

## 6H-2 — Shutdown reentrancy

When a transition observer asks `stop()` during `Enter` or `transition_committed`, stop must be deferred until the current tick ends. Pending cross-clock work is cleared; each active machine receives at most one `state_exited` and `machine_stopped`, and the engine ends with no active states, no queued requests, and `is_running() == false`. If a shutdown `state_exited` observer calls `stop()` again, the second call must be idempotent and not recurse, double-exit or delete the shared graph. A single bounded test listener invokes the recursive call only once to characterize this safely. The unrelated second controller stays live.

Do not infer it is safe to mutate `flow_graph` during callbacks or claim a general exception isolation policy. If the focal fails, minimally guard the active shutdown path; do not rewrite transition scheduling or serialized model.

## Exit criteria

Contract first; independent 6H-1 and 6H-2 headless tests and CI, demonstrate RED before any production correction, green entire regression suite, then produce an honest phase-6 runtime acceptance report. Passing 6H cannot establish a hard CPU-millisecond budget, exhaustive graph fault injection, or Potok visual/Android acceptance. Condition Tok and event-payload expression binding from phase 5 remain tracked independently.
