# FSM-5A — Event ordering and deferred delivery

**Date:** 2026-11-01. **Scope:** one independent phase-5 micro-lot, tests only.

## Why this first

The existing `flow_fsm_transitions_test.gd` already verifies direct requests, event versus condition precedence, duplicate IDs, and cross-clock delivery. It does not independently distinguish **same-priority declaration order**, **no-match consumption**, **rejecting malformed/unknown events without mutation**, **destination Update deferral**, or **events emitted from synchronous Update listeners**.

## Change

- `tests/runtime/flow_fsm_event_order_test.gd/.tscn` adds these public acceptance cases without changing the engine.
- `.github/workflows/flujo-fsm.yml` runs it in a dedicated bounded step.
- The test declares two independent matching event families at construction time: equal-priority declaration-order edges and different-priority edges. No authored resource is modified during gameplay.

## Recovery

- **Last pre-lot accepted checkpoint:** `0eb4cf40600ceaec3221565f589a50bd588c079a` (phase 4 audit).
- **5A first action:** read the GitHub Actions run for the commit that introduced this test. A green run is evidence for this focal only.
- **Next micro-lot 5B:** isolate condition sources (false/true/invalid type) and self-transitions with deterministic no-op behavior; add diagnostics only on a demonstrated deficit.
- Preserve separate manual review status. Do not merge implementation of several phase-5/6 tasks in a single commit.

## Verification and commit checkpoints

- `deeb975cfed457f5011c1a137cdcc2e7f11ddf3c`: initial 5A test and CI wiring — [GitHub Actions 41347838123](https://github.com/mercurysama/Flujo/actions/runs/41347838123) **SUCCESS**.
- `e724a6cfc9062d07f97af3588102a63d893d0fc6`: isolated fixture correction to avoid mutating authored priorities at runtime — [GitHub Actions 41347899663](https://github.com/mercurysama/Flujo/actions/runs/41347899663) `FSM-5A event ordering focal` **SUCCESS** (entire workflow may still be finalizing).
- The phase-5 engine was **not** changed in this lot; this is focused behavior characterization plus a reusable regression.
