# Potok 6F-1 — Typed direct-request metadata checkpoint

**Date:** 2026-11-01. **Branch:** `feature/fsm-runtime-flow-flusso`.

**Contract:** `f8630d20f5fd6a2947ad45fbd77e376cce36c617`, `docs/fsm_phase6_6f1_direct_request_contract.md`. The direct request API retains its two required arguments and adds optional `reason: StringName = &""` and JSON-safe `payload: Dictionary = {}`. A reason over 128 characters reports `invalid_reason`; unsafe/non-JSON/oversized dictionaries report `invalid_payload`; rejected requests never enter the queue.

**RED evidence:** test `9dac7cefb3140a642d92299a18c9dee7fe6b1393`, scene `87726b0f8ae3208b5d3855f706800b09b496f426`, focal workflow `c935d757799ed0f34656c6b4f886b071e550d290`. [Actions 41359653289](https://github.com/mercurysama/Flujo/actions/runs/41359653289) **FAIL** on the new 6F-1 focal before runtime implementation.

**GREEN implementation:** runtime-only commit `d0e670af2af8dd5f86009d83f7bb5b7e214e2f89`. [Actions 41359760201](https://github.com/mercurysama/Flujo/actions/runs/41359760201) **SUCCESS** across the new 6F-1 test plus all existing FSM, model, Ready and navigation regression steps.

### Verified behavior

- `request_transition(machine_id,target_state_id,reason=&"",payload={})` validates metadata before capacity; accepted dictionary is deeply copied into the controller-local queue.
- Matching-clock direct FIFO remains unchanged. A losing direct request is consumed without emitting a metadata notification; a self-target is a no-op with no commit notification.
- Existing `transition_committed(machine_id,from,to,trigger)` four-argument signal remains intact; **after** it, only an actually committed direct request emits the new `direct_transition_committed(machine_id,from,to,reason,payload)` with a detached payload copy.
- Old two-argument direct requests still work; their new notification uses an empty reason and empty payload.
- A callback from the new metadata signal can enqueue another request but cannot execute it recursively. The current transition lineage still applies.
- No graph/serialization/schema changes; no payload delivery into Condition Tok or blocks is implied.

### Boundaries and next step

**6F-1 accepted by automated tests, not a claim of phase-6 or release completion.** Direct reason is metadata only, never a priority or stable machine ID. The delivery copy is per signal emission, not per individual listener. UI/Android acceptance remains pending.

**Next micro-lot 6G:** contract-first per-tick processing budget, surplus retention and fairness between unrelated machine chains. Distinguish this from the existing 256 pending cap and 8-hop causal lineage limit; use RED/GREEN focal and separate commits. Follow with 6H fault-injection and remaining phase-6 audit, without silently closing phase-5 Condition Tok authoring debt.

**Recovery:** runtime checkpoint `d0e670af2af8dd5f86009d83f7bb5b7e214e2f89`, full green CI `41359760201`, then this documentation checkpoint. Read the above contract, 6E audit and this file before further code changes.

Todo es Flujo; todo fluye. 🌊
