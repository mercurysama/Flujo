# Potok 5G — Runtime admission diagnostics (2026-11-01)

**Scope:** request/event **admission** rejection only. No changes to dispatch, graph schema, scheduling, or the validator's authored-model diagnostics.

## Contract

Add `request_rejected(machine_id: String, kind: StringName, code: StringName)` to the controller-local `FlowFSMRuntime`. One synchronous signal per refused call to `request_transition` or `emit_event`; preserve the public `bool` result. Codes are stable `StringName` literals:
- `not_running` — runtime is stopped.
- `queue_full` — admitted requests plus reserved cross-clock carryover reach `MAX_PENDING_REQUESTS`.
- `invalid_machine` — machine not active/unknown/disabled.
- `invalid_target` — target missing, foreign or disabled (direct requests only).
- `invalid_event_name` — event name is empty/whitespace.
- `invalid_payload` — event payload fails existing `FlowFSMDataValidator.valid_dictionary`.

**Precedence:** runtime not running, malformed name, missing/disabled machine, invalid target or payload, then capacity. This makes rejection diagnostics stable even at capacity. No signal on accepted admission and no signal for an accepted but unmatched event consumed normally. Do not expose, inspect or mutate payloads through diagnostics. Rejecting via a connected diagnostic listener may enqueue new items; a refused request must never get enqueued retroactively. Cross-clock callback admission uses the previously reserved count (5C). Diagnostics are notification-only, not a new error history service or instance logging spam.

**Coverage:** reasons per case, exact capacity, cross-clock callback overflow, signal count, unchanged bool semantics, and all earlier Potok tests. Follow RED test, GREEN runtime, evidence/docs as three discrete commits. Do not claim this solves phase-6 chain isolation or UI diagnostics.
