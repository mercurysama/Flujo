# Potok 6F-1 — Typed direct transition request envelope

**Date:** 2026-11-01. **Branch:** `feature/fsm-runtime-flow-flusso`. **Baseline:** `32d6984a3e6d719bd6e2f192a5e370c0c97dbbfa`.

## Public API and transport

- Extend the existing `request_transition(machine_id: String, target_state_id: String)` API with optional trailing `reason: StringName = &""` and `payload: Dictionary = {}`. Existing two-argument callers and `change_state(machine_id,state_id)` remain valid.
- `reason` is explicit, optional, human-authored metadata, not an identity or internal chain ID; it is never used for conflict priority or resolution. Limit `String(reason).length()` to 128 characters; reject an oversized reason with `request_rejected(machine_id,&"direct",&"invalid_reason")` and return false, without queue mutation. Blank reason is valid.
- Validate payload via existing `FlowFSMDataValidator.valid_dictionary` (bounded JSON-safe tree), reject malformed payload with stable `invalid_payload` code without queue mutation. Preserve existing `not_running`, `invalid_machine`, `invalid_target`, `queue_full`, and `chain_budget_exceeded` diagnostics. Validate reason and payload after target validation and before queue-capacity check, so invalid metadata is not mistaken for saturation.
- Deep-copy accepted payload into the pending direct request. No caller mutation can affect the queued envelope. Metadata stays inside the instance-local request and does not modify/serialize authored graph resources, dynamic-state records or snapshots. The 256-item cap, cross-clock carryover, direct-request FIFO and chain-hop lineage remain unchanged.
- Preserve the existing **four-argument** signal `transition_committed(machine_id,from_state_id,to_state_id,trigger_id)` byte-for-byte. Add `direct_transition_committed(machine_id: String, from_state_id: String, to_state_id: String, reason: StringName, payload: Dictionary)` emitted **only after** a direct request actually commits, immediately after the existing signal and while the commit lineage context is active. Each emission passes a new deep copy of the stored payload. This per-emission snapshot does not imply independent copies per signal listener; listeners may copy it again.
- No new metadata signal for a stale/unmatched/losing/no-op direct request; it is consumed according to existing arbitration. No metadata signal on event or condition transitions. No implicit cross-controller routing.
- A callback that emits a further request from either signal is still deferred and inherits the current chain identity and hop budget.

## Acceptance / recovery

Test legacy two-parameter direct requests, validated nested metadata and deep copy before/after delivery, rejected unsafe/oversized payload and reason with exact diagnostics, FIFO competing directs, other-clock deferral, correct old/new signal order and single emission, and no signal for a self-target request. Preserve existing 5A–6D regression matrix. Stage contract → RED focal and CI → minimal GREEN runtime → evidence and handoff, with separate commits.

**Excluded:** direct request payload binding to Condition Tok or blocks, persisted metadata, UI, Android acceptance and the separate 6G per-tick work-budget decision.

Todo es Flujo; todo fluye. 🌊
