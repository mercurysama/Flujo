# Potok 6E — Phase 6 implementation gap audit

**Date:** 2026-11-01. **Branch:** `feature/fsm-runtime-flow-flusso`.
**Verified pre-audit HEAD:** `499711314c1e11465c0c59fb528eb1f8e95f3a8d`.
**Automated baseline:** [GitHub Actions 41357770163](https://github.com/mercurysama/Flujo/actions/runs/41357770163) **SUCCESS** (the same documentation-only revision); isolated 6D implementation-check [41357686834](https://github.com/mercurysama/Flujo/actions/runs/41357686834) **SUCCESS**.

This audit compares the seven numbered steps in `docs/fsm_implementation_plan.md` phase 6 with runtime source, contracts and focal tests. **No production-code or test mutation.**

## Acceptance matrix

| Phase-6 requirement | Status | Evidence / caveat |
|---|---|---|
| 1. Machine registry addressed by stable ID within controller | **FUNCTIONAL / STRUCTURAL PARTIAL** | `FlowFSMRuntime._active` is keyed by machine ID, and `_find_machine` resolves the authored definition by ID. 6A–6D and second-controller isolation verify identity-based addressing. The proposed distinct `machine_id → runtime` object-per-machine structure was **not created**; the coordinator implements equivalent observable behavior, not the precise proposed class topology. |
| 2. Cross-machine `request_transition(target_machine_id,target_state_id,reason/payload)` and `emit_event(target_machine_id,event_id,payload)` | **PARTIAL** | Requests and events are target-machine-ID addressed with Boolean result and validation; event `Dictionary` payload is JSON-safe and copied (5F). **Direct `request_transition` accepts only two arguments; no typed reason/payload envelope or per-request observer yet.** The existing event API is scoped to one runtime, not implicit cross-controller broadcast. |
| 3. Cross-machine queue, deterministic declaration order + FIFO, no nested callback commit | **PASS under existing clock contract** | `tick` walks authored `graph.state_machines` in order, snapshots pending queue, and `_pick_request` uses direct FIFO. 6A/6B and 5D characterize other-clock carryover and deferred Update/Enter/Exit requests. Different clock calls do not run recursively. |
| 4. Per-tick budget for events/requests/transitions, saturation diagnostic and cancel affected chain | **PARTIAL** | 5C global 256 queued + reserved capacity; 5G `queue_full` admission diagnostic; 6C-2 eight **inherited transition hops** per lineage + `chain_budget_exceeded`, with unrelated roots preserved, extended event/sibling tests in 6D. **There is no separate per-tick CPU/work budget or processed-events/requests budget.** A single tick can consume up to the queue cap, so a hop limit must not be misreported as tick budget. |
| 5. A requests B; determinism independent of scene-tree order; removed/disabled machine rejected without side effects | **PARTIAL** | 6A and 6B verify A→B with distinct clocks and stable IDs; 5G invalid-machine rejection. Explicit cross-controller scene-tree permutation and disabled/unstarted target plus deletion/fault injection are not independently tested under 6E. Dynamic state removal exists but is not the same as deleting a machine definition. |
| 6. Reentrancy policy for Exit/Enter | **PASS** | 6B/6C-1 verifies requests made from synchronous lifecycle callbacks are deferred; recursive tick ignored. |
| 7. A→B→A, event bursts, equal priority, multiple machines | **AUTOMATED PASS FOR CHARACTERIZED MATRIX, EXHAUSTIVENESS PARTIAL** | 6C-1 finite cycle, 6C-2 chain hop saturation, 6D event/sibling/cross-controller tests, 5D equal-priority/event ordering and 5C queue burst. Repeated randomized order permutations, heavy fault injection and performance timings are not proven. |

## Scope decision

**Phase 6 deterministic cross-machine runtime: substantial automated coverage, not formally complete.** Requirements 2 and 4 are substantive gaps. Requirements 1/5/7 have architectural or negative-test qualifications. Do not change the original plan's seven checkpoints to claim 100% or release readiness.

**Highest-value independent next lots:**

- **6F-1, typed direct-request envelope contract + focal:** retain the original two-argument `request_transition` API; specify optional trailing `reason: StringName` and `payload: Dictionary` (JSON-safe via `FlowFSMDataValidator`), deep copy, admission rejection `invalid_payload` and delivery/inspection semantics. Reason should be explicit metadata, not a replacement for IDs or internal lineage; do not leak sensitive payload in diagnostics. Determine which public signal carries metadata without breaking existing four-argument `transition_committed` listeners. Agree on signal shape before code. RED test, minimal GREEN code, full regressions in separate commits. Avoid silently broadening the FSM graph schema.
- **6G, per-tick work budget contract + focal:** decide stable units (requests inspected, events delivered, and commits) and the exact policy for surplus. Preserve admitted packets on their original clock, avoid starving independent machines, detect and report specific saturated lineage and avoid silent truncation; ensure `_inflight_reserved` math remains safe. A budget across an entire `tick` is different from both `MAX_PENDING_REQUESTS=256` and `MAX_CHAIN_HOPS=8`. Prove via RED test on concurrent roots before changing the engine.
- **6H, fault-injection/isolation matrix and final runtime acceptance:** disabled/unstarted destinations, target invalidation (without mutating authored resources), scene-tree permutation, equal priorities, repeated multi-machine cycles, stop during callback, and independent-controller checks. Any discovered mismatch gets its own minimal RED/GREEN fix.

## Known adjacent debt (not phase-6 acceptance)

- Phase 5: Condition Tok `#` editing and event-payload-to-expression bindings remain unimplemented.
- Phase 7: Potok UI in Fluo/Flow/Flusso, human UI validation and Godot Android acceptance remain pending.
- `docs/fsm_implementation_plan.md` is an initial proposal with stale “no implementation yet” banner; do not use that banner as an actual status report. This audit and per-lot contracts carry current state.

## Durable handoff

- Current green baseline: `499711314c1e11465c0c59fb528eb1f8e95f3a8d`, [CI 41357770163](https://github.com/mercurysama/Flujo/actions/runs/41357770163).
- Previous 6D test `tests/runtime/flow_fsm_event_lineage_isolation_test.gd/.tscn`, [CI 41357686834](https://github.com/mercurysama/Flujo/actions/runs/41357686834).
- 6C-2 hop limit contract `docs/fsm_phase6_6c2_chain_budget_contract.md`; admission codes in `docs/fsm_5g_diagnostics_contract.md`.
- Next action on 🙆🏻: **implement 6F-1 contract → focused RED → minimal GREEN → CI → docs**; do not add unrelated phase-7 UI.
- Keep this audit documentation-only. Tests/Android are never assumed from a documentation commit.

Todo es Flujo; todo fluye. 🌊
