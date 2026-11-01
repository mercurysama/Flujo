# Potok 6G — Per-machine, per-clock request work budget

**2026-11-01 · Branch:** `feature/fsm-runtime-flow-flusso`; baseline `b8dfbb20b7bd31cff7e48f7c985a1ef71a513765`.

## Precise work unit

- Add `const MAX_REQUESTS_PER_MACHINE_TICK: int = 32` in `FlowFSMRuntime`. **One processed packet** means one accepted, previously queued `direct` or `event` entry selected for delivery/arbitration on a *matching machine clock*, whether it matches a transition or not. This is a packet-delivery work budget, not wall-clock milliseconds, internal edge comparison count, authored StateUpdate block instructions, or an upper bound on total machine updates.
- At tick start snapshot `_pending_requests` once. Traverse snapshot in global admission order; reserve *up to 32* requests separately for **each** active machine whose `tick_mode` matches this tick. Everything else is deferred: packets for other clocks and **same-clock surplus**. Invalid/stopped-machine packets are discarded as in the existing scheduler.
- Each active machine still gets exactly one StateUpdate each matching tick and may commit **at most one transition**. The chosen batch retains existing direct FIFO, event priority/arrival/authored tie-breaking and condition fallback. If a packet falls past its machine's 32-packet window, its selection is deferred until a later tick; no event notification or transition occurs before then.
- Surplus remains in the pending queue **ahead of requests enqueued by synchronous callbacks**. The `_inflight_reserved` capacity reserve must count all deferred entries, including same-clock surplus, so callbacks cannot overfill the 256-entry total capacity. Carryover across other clocks retains relative admission order within each machine; unrelated machines with the same clock get their own independent 32-packet window and cannot be starved by one noisy machine.
- Add public signal `work_budget_deferred(machine_id: String, deferred_count: int)`, emitted at most once for a matching machine each tick with **only the count of its same-clock surplus**, after StateUpdate and before event consumption. A deferred packet is **not rejected**; do not emit `request_rejected` for it, and do not drop its lineage. This is backpressure telemetry, not a chain-cancellation diagnostic.
- Existing global `MAX_PENDING_REQUESTS=256` and `queue_full` remain admission rules; existing lineage `MAX_CHAIN_HOPS=8` and `chain_budget_exceeded` still reject/cancel only saturated causal chains. A request accepted before the tick must not vanish merely because its clock budget is exhausted.
- **Intentional compatibility change:** previous capacity focal (5C) assumed one PHYSICS tick drained 256 unmatched events. After this contract, eight PHYSICS ticks are required (32 each); update that test's specific drain assertion, preserving every original overflow, cross-clock reserve, and admitted-callback check. Likewise adjust 6C-1's unmatched-burst drain expectation. Other tests must remain unchanged unless a separately verified deficit appears.
- No schema, serialized packet, UI or public request API change. No promise of CPU timing guarantees, fair selection between **lineages within a single machine** (machine FIFO remains authoritative), or chain-local execution time budget.

## Acceptance

1. Machine A with 40 FIFO unmatched events processes only events 1–32 on its first MANUAL tick, and 33–40 on its second; a callback-generated event queues behind them and cannot run in its originating tick.
2. Machine B, also MANUAL, has one accepted event and an authored transition; B consumes and commits it on the *first* tick even while A is flooded. Other-clock machine C stays untouched until PHYSICS tick.
3. `work_budget_deferred(A,8)` fires once on the first tick, none on the second. Pending sizes reflect retention exactly, and existing `event_consumed` signals fire once per delivered event in machine FIFO order.
4. The 256-packet capacity and `_inflight_reserved` protection remain valid with retained same-clock and cross-clock packets; old direct/event/lineage behavior and all Godot headless regressions pass with the two explicitly updated burst-drain assertions.
5. Run contract → RED focal + workflow → minimal runtime correction → adjust two pre-existing tests to new contract → full GREEN CI → docs checkpoint. Keep each stage separately recoverable.

**Next:** Potok 6H negative tests and final phase-6 runtime acceptance audit; Condition Tok authoring and Android visual acceptance remain separate.

Todo es Flujo; todo fluye. 🌊
