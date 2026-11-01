# FSM-5A — Event ordering and deferred delivery

**Date:** 2026-11-01. **Scope:** one independent phase-5 micro-lot, tests only.

## Why this first

The existing `flow_fsm_transitions_test.gd` already verifies direct requests, event versus condition precedence, duplicate IDs, and cross-clock delivery. It does not independently distinguish **same-priority declaration order**, **no-match consumption**, **rejecting malformed/unknown events without mutation**, **destination Update deferral**, or **events emitted from synchronous Update listeners**.

## Change

- `tests/runtime/flow_fsm_event_order_test.gd/.tscn` adds these public acceptance cases without changing the engine.
- `.github/workflows/flujo-fsm.yml` runs it in a dedicated bounded step.
- The test uses a temporary change to authored edge priority to create a high-priority case, then restores it. This is a **test fixture** operation, never a runtime feature; no assertion should infer live authoring is supported.

## Recovery

- **Last pre-lot accepted checkpoint:** `0eb4cf40600ceaec3221565f589a50bd588c079a` (phase 4 audit).
- **5A first action:** read the GitHub Actions run for the commit that introduced this test. A green run is evidence for this focal only.
- **Next micro-lot 5B:** isolate condition sources (false/true/invalid type) and self-transitions with deterministic no-op behavior; add diagnostics only on a demonstrated deficit.
- Preserve separate manual review status. Do not merge implementation of several phase-5/6 tasks in a single commit.
