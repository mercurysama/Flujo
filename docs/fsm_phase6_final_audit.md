# Potok — Phase 6 final automated runtime acceptance audit

**Date:** 2026-11-01. **Branch:** `feature/fsm-runtime-flow-flusso`. **Pre-audit engine HEAD:** `e494bcf39d27aa1ab25b6c31688ceb1287a98887`. **CI:** [41363328505](https://github.com/mercurysama/Flujo/actions/runs/41363328505) — **SUCCESS**, including the 6H negative-routing and shutdown tests. This document does not alter runtime code or its tests.

## Seven-item acceptance map to `docs/fsm_implementation_plan.md`

| Original phase-6 item | Status | Basis / exact boundary |
|---|---|---|
| 1. Registry by machine ID scoped to `PVController` | **FUNCTIONAL PASS / structural adaptation** | `_active[machine_id]` and `_find_machine` in controller-local `FlowFSMRuntime`; 6D and 6H prove isolation and scene-tree order independence. A separate object-per-machine runtime registry was not needed for observed behavior and was not added. |
| 2. Cross-machine direct requests and events with IDs and reason/payload | **PASS for runtime API** | 6A/6B target by ID; 5F typed event payload; 6F-1 optional reason and JSON-safe payload on direct commands, copied and emitted via separate commit metadata signal. Cross-controller broadcast intentionally not implicit. |
| 3. Deterministic queue, authored machine order, FIFO and callback deferral | **PASS** | 5A/5D and 6A/6B characterize ordering and nonrecursive Update/Enter/Exit; distinct clock routing preserved under 6G 32-packet windows. |
| 4. Budgets and saturation diagnostic/cancellation of affected chain | **PASS for bounded packet and causal chain contracts / hard CPU bound NOT IMPLEMENTED** | 256 pending queue + `queue_full` (5C/5G), 32 delivered packets per active machine per tick + `work_budget_deferred` (6G), one transition per machine tick, eight inherited chain hops + `chain_budget_exceeded` and sibling cancellation (6C-2/6D). No millisecond/instruction budget, nor fixed global per-frame work bound across an arbitrary number of active machines. |
| 5. A requests B, order independence, invalid or removed machine rejection | **PASS for supported APIs / removal qualification** | 6A and 6H prove A→B, controller node reordering, unknown/disabled/unstarted rejection without side effects. Deleting an authored machine resource during runtime is not an exposed operation and is not simulated by mutating shared graph definitions. |
| 6. Reentrancy from lifecycle callbacks | **PASS** | 6B requests from Enter/Exit defer; 6H-2 stop during commit defers and recursively requested stop in shutdown Exit becomes idempotent. |
| 7. A→B→A cycles, bursts, equal priority, multiple machines | **PASS for deterministic headless regression scenarios** | 5C/5D/5E, 6C-1/2, 6D/6G/6H. This is not randomized fuzzing, load benchmarking or exhaustive malicious resource mutation. |

## Explicit acceptance decision

**FLU-FSM-002 runtime acceptance criterion (multiple machines communicate deterministically using stable IDs, without recursion): PASS — AUTOMATED.** The accepted runtime contract includes bounded packet processing, typed metadata, isolation and safeguarded shutdown.

**Full phase-6 engineering work: ACCEPTED WITH DOCUMENTED LIMITS, not unconditional closure of all initially proposed safety ambitions.** A hard global per-tick CPU/time ceiling, unsupported machine-definition deletion while running, and broader fault-injection/fuzz testing remain separately scoped if required. They must not be represented as implemented. The original topology proposal for one runtime object per machine was implemented instead as one coordinator runtime per `PVController` with machine-ID keyed state.

**Release/UI readiness: NOT APPROVED.** Phase-5 Condition Tok `#` authoring, event-payload binding to expressions/Tok, Potok editor Flow/Flusso visual authoring, and manual Godot/Android checks remain open.

## Recovery and next small lot

- Historic regression evidence: 6F-1 [41359760201](https://github.com/mercurysama/Flujo/actions/runs/41359760201); 6G [41361104238](https://github.com/mercurysama/Flujo/actions/runs/41361104238); 6H RED [41363216050](https://github.com/mercurysama/Flujo/actions/runs/41363216050) and GREEN [41363328505](https://github.com/mercurysama/Flujo/actions/runs/41363328505).
- Review `docs/fsm_phase6_6h_result.md`, `docs/fsm_phase6_6g_result.md`, `docs/fsm_phase6_6f1_result.md` and `docs/fsm_phase5_final_audit.md`.
- **Recommended next micro-lot 7A:** UI-first contract for Potok machine/state editor integration in Flow/Flusso, with explicit dependency checklist for Condition Tok `#` editing and payload-to-expression binding; do not touch schema or mix Android acceptance with initial UI scaffolding. Alternatively, if release requires stronger safety SLA, open a separate 6I global tick-budget design/benchmark lot before 7A. Obtain scope decision based on product needs, not an unsupported claim of full CPU budget.
- This documentation audit changes no engine code; last engine-passing commit remains `e494bcf39d27aa1ab25b6c31688ceb1287a98887`. After audit commits, check latest HEAD and CI before any further modifications.

Todo es Flujo; todo fluye. 🌊
