# Potok — Phase 5 final acceptance audit and Phase 6 handoff

**Date:** 2026-11-01  
**Branch:** `feature/fsm-runtime-flow-flusso`  
**Code baseline:** `7cfce77474a6b44da2e0ad4e58cab37d1cbb704a`  
**Last verified baseline:** [GitHub Actions 41353678703](https://github.com/mercurysama/Flujo/actions/runs/41353678703) — **SUCCESS**.  
**Audit scope:** compare the nine items of `docs/fsm_implementation_plan.md` phase 5 against the runtime and the 5A–5G independent regression matrix. This audit does not change engine code or change the meaning of the original plan.

## Audit matrix

| Phase-5 item | Finding | Evidence / boundary |
|---|---|---|
| 1. Typed transition resource, stable IDs, priority and ordering | **PASS for approved runtime model** | `FlowStateTransitionDefinition` has a stable ID, target, `enabled`, `CONDITION`/`EVENT`, signed `priority`. Explicit `REQUEST` is runtime API rather than serialized edge trigger. |
| 2. Conditions via existing typed value source / Condition Tok # | **PARTIAL** | `FlowValueSource` resolves bool without string eval; `flow_fsm_conditions_test` passes. Condition Tok `#` authoring and binding inside Potok are **not integrated**. |
| 3. Single evaluation after Update before commit | **PASS for deterministic scheduling; partial direct counting** | `_pick_condition` resolves candidates after Update. 5B covers selection and skipped false/self edges; exhaustive evaluation-count instrumentation is not present. |
| 4. Directed typed events with clear emission/reception/consumption | **PASS for single-machine event envelopes** | `emit_event(machine_id,event_name,payload={})` validates/copies a JSON-safe dictionary, and `event_consumed` emits per matching-clock event after Update; 5F-1/2 tests. No payload binding into Toks/conditions; cross-controller broadcast is out of scope. |
| 5. Conflicts: priority and deterministic tie-break, at most one commit | **PASS under approved runtime contract** | 5A, 5D, 5E prove priority, authored-edge order and request FIFO. The runtime contract uses request arrival to resolve ties across separate events; no extra stable-ID tie is necessary for an ordered collection. |
| 6. Queued requests, no recursive Exit/Enter | **PASS** | 5A–5D and 5F-2 show callback-generated requests deferred to the next eligible tick. |
| 7. Exit → active ID → Enter, destination Update later | **PASS** | 5A/5B and original FSM-002 focal verify sequencing, one transition and next-tick Update. |
| 8. Invalid machine/target/condition/event/disabled transition, stable diagnostics | **PASS for admission + authored validation; execution diagnostics deferred** | Model `FlowDiagnostic` handles invalid authored targets, bool conditions and event names. `request_rejected` codes in 5G cover invalid request/event/payload/overflow/stopped runtime; disabled edges skipped. Does not imply full runtime error/fault-injection diagnostics. |
| 9. Tests for direct/true/false/consumed/unmatched/multiple/self | **PASS automated** | Original `flow_fsm_transitions_test`, 5A–5G tests. Human UI/Android acceptance remains **PENDING**. |

## Explicit decision

**Phase 5 kernel: AUTOMATED ACCEPTANCE PASSED** (deterministic state transitions and instance-local machine-directed event envelope with rejection diagnostics).  
**Phase 5 overall nine-item implementation: PARTIAL / NOT FORMALLY CLOSED.** Do not claim total acceptance until Potok Condition Tok `#` integration/binding and later UI acceptance are implemented and reviewed. The data envelope and observer signal are intentionally not an event-payload-to-expression binding.

### Deferred owner map

- **Condition Tok `#` editor authoring, input field integration, and discoverability:** Phase 7 (Potok UI-FSM) after it has an approved contract. Underlying typed bool runtime source already exists. No need to rename internal classes.
- **Binding consumed event payload to typed expressions/Tok or block execution context:** separate pre-UI contract and focal, **not implemented**; decide if it belongs at the end of phase 5 or in Potok runtime/authoring integration before phase 7. Do not assume a listener signal equals a value binding.
- **Cross-machine requests, reason/payload, chain saturation and cycle policies:** Phase 6 FSM-002/B, with separate RED/GREEN micro-lots. Existing 256 pending cap and admission diagnostics are not sufficient proof of chain-local budgets.
- **Complete negative/fault-injection matrix, editor visual/Android acceptance:** dedicated later QA/release gates; do not infer from GitHub Actions success.

## Phase 6 entry criteria and first micro-lot

Phase 6 can **start** on the current green, deterministic Potok runtime because its new cross-machine request queue and registry can be tested independently of UI. This is **permission to begin implementation planning**, not a declaration that phase 5 has fully closed or phase 6 is finished.

Suggested **6A**: contract and focal for cross-machine `request_transition(target_machine_id,target_state_id)` initiated from another machine's Update callback, proving it cannot execute within that callback and that the recipient is processed on its own clock. Avoid changing serialized graph layout; preserve the stable machine-ID addressing and existing event payload contract. Where this behavior already exists, add characterization tests rather than duplicate an API.

## Durable recovery checkpoints

1. The audit's code baseline and [CI 41353678703](https://github.com/mercurysama/Flujo/actions/runs/41353678703) passed before this documentation-only audit.
2. `docs/fsm_phase5_microblocks.md` keeps RED/GREEN commits, regressions and outcomes from 5A–5G.
3. `docs/fsm_5f_event_envelope_contract.md` owns typed packet admission/consumption; `docs/fsm_5g_diagnostics_contract.md` owns rejection reason semantics.
4. Continue from this document for 6A; do not restart or combine phase-6 work with editor UI. A green documentation commit is not an additional engine acceptance test.

Todo es Flujo; todo fluye. 🌊
