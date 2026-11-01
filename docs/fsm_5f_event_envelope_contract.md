# FSM-5F — Potok named, typed event envelope (increment 5F-1)

**2026-11-01 · Status: scoped implementation approved by maintainer's continuation instruction; not a claim of complete phase 5.**

## Public identity

**Potok** names the user-facing State Machine feature. The word evokes a flowing current: behavior moves between authored states as event and condition rules are satisfied. Do not rename `FlowStateMachineDefinition`, `FlowFSMRuntime`, serialized IDs, scene paths, or Graph schema. Keep **Fluo/Flow/Flusso**, **Akis** and **Tok** ownership unchanged. Potok is UI/documentation naming for future UI-FSM work; this contract does not change editor labels yet.

## 5F-1 — Machine-scoped validated payload admission

- Retain `emit_event(machine_id: String, event_name: StringName)` compatibility by adding an **optional trailing** `payload: Dictionary = {}` argument. Existing two-argument callers remain valid.
- Scope is a **single exact machine ID inside one PVController**; no broadcast, cross-controller routing, implicit target resolution, or scene node object references.
- Accept only a `Dictionary` satisfying the **existing** `FlowFSMDataValidator.valid_dictionary` contract (JSON-safe scalar, arrays/dictionaries with string keys, bounded depth, count and byte size). No new sanitizer or payload format.
- Failed validation, unknown machine, empty event name, or full queue **returns false without enqueuing**. Valid accepted payload is deeply copied into the pending event packet; later caller mutation cannot change the delivered envelope. A unique copy is kept per event.
- Pending event packets live only in the controller-local runtime queue, disappear on consume/stop, and are **not** serialized to `FlowGraph`, dynamic-state templates or snapshots. Keep the existing cap (256, including in-flight reserved events).
- This is an **envelope admission milestone**: the existing dispatcher still matches `event_name` and chooses a graph-defined edge. It does **not** yet feed payload fields into condition Toks or public observers, and it must not silently promise that feature.
- A future 5F-2 contract may expose copied payload at the approved delivery boundary and specify binding to typed expressions, consumption events and error diagnostics. Phase 6 may extend only explicit cross-machine delivery, never introduce implicit broadcast.

## 5F-1 acceptance

1. Existing two-parameter event call and all prior FSM tests pass unchanged.
2. Valid nested JSON-safe dictionary accepted and copied before the queued event is processed.
3. Invalid payload (Object/Node, Callable, unsupported value, excessive size/depth, non-string dictionary key) rejected with no queue mutation.
4. Two controller instances cannot share the event packet; no graph mutation.
5. Full queue rejects payload events without weakening 5C reserved-capacity fix.
6. The matching event still causes exactly one state transition and is consumed on the matching tick.
7. Headless focal + standard FSM CI succeed; manual Android/editor review remains independent.

## Small independent recovery blocks

- **5F-1A:** freeze this contract and Potok naming in documentation (no engine mutation).
- **5F-1B:** add tests and CI only; record RED if unimplemented API fails.
- **5F-1C:** smallest runtime change adding the optional copied payload; rerun all regressions.
- **5F-1D:** record exact GitHub Actions evidence and any remaining gaps for next chat.

These lots do not implement a Potok UI or declare the complete numbered phase 5 finished.

Todo es Flujo; todo fluye. 🌊

## 5F-2 — Deterministic event consumption observation (approved micro-lot)

- Add the portable runtime signal `event_consumed(machine_id: String, event_name: StringName, payload: Dictionary)` on `FlowFSMRuntime`. This is a public notification **not** an authoring mutation, interpreter, or state-transition trigger.
- At the matching machine clock's tick, execute that state's **Update** first, then emit the signal **once for each previously queued event** addressed to this machine, in admission FIFO order, **before** transition arbitration. A missing authored edge still consumes the event and emits the notification.
- The signal reports *consumption/receipt*, **not** a successfully chosen transition. Any event that loses arbitration is nevertheless consumed, observed once and never replayed. Listeners can inspect validated JSON-safe payload values. Delivery never targets a disabled/unstarted machine.
- Each signal emission passes a **deep copy** of the stored envelope. A listener may mutate its copy without corrupting the queue or changing the edge selected in that tick. Other listeners sharing the same signal call should treat the argument as transient and make their own copy before mutation; per-listener copy isolation is not guaranteed.
- Observers who call `emit_event`, `request_transition` or `tick` synchronously cannot force another transition in the same tick: new requests remain deferred and recursive ticks are ignored.
- Other-clock events remain queued and unobserved until their machine's own clock. No event survives on an already stopped runtime.
- This micro-lot does not bind payloads to Toks, expose them as variables/conditions, alter schema or serialization, or route across PVControllers. Those are separate authoring/phase-6 decisions.
- Focused checks: FIFO notifications, deep copy, matched and unmatched events, other-clock deferral, callback-generated events, unchanged event arbitration and existing full FSM regression. Manual acceptance remains independent.

**Recovery substeps:** 5F-2A this contract; 5F-2B focused test and CI (expected RED); 5F-2C minimal signal/emission code; 5F-2D evidence and continuity log.
