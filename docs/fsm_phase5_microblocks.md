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

## FSM-5B — Typed conditions and self-transition no-op (2026-11-01)

**Baseline before 5B:** `f9e4cf90a0a560cb2efb96e193b9c067b38da89b`. **Test commit:** `ef856654ecefcd3a6760ab68a4881e928c288cfa`.

- Added `tests/runtime/flow_fsm_conditions_test.gd` and its scene, with an independent CI step.
- Authored conditions: a high-priority `false` edge is skipped, a higher-priority true **self edge** is ignored, and a lower-priority `true` edge reaches a different state with exactly one Exit/Enter. The destination's Update is deferred until the following tick.
- Direct requests to the active state are consumed as no-op, without a transition commit or repeated Exit/Enter.
- `FlowGraphValidator` rejects a non-Boolean `FlowValueSource` and an absent condition with `CODE_FSM_CONDITION_INVALID`. Invalid definitions cannot start a `PVController` FSM.
- **Automated evidence:** [CI 41349532108](https://github.com/mercurysama/Flujo/actions/runs/41349532108), dedicated `FSM-5B conditions and self-transition focal` **SUCCESS**. Remaining overall-workflow status must be checked independently.
- **No engine changes.** The new automated test characterizes the already implemented contract.
- **Next 5C micro-lot:** separate FIFO/overflow/priority under multiple pending events; if existing behavior fails, add a minimal runtime fix in a distinct commit and rerun the focal.
- **Manual release verification:** remains pending, independent of automated evidence.

## FSM-5C — Bounded cross-clock event queue (2026-11-01)

**Start HEAD:** `4f255e367fae83c676db4fc1c17998ca805d831b`. **Scope:** isolate simultaneous requests, per-controller queue capacity and reentrant acceptance in a single auditable micro-lot.

**RED (reproducible regression):** commit `70082beb8d81234c037a050f2370f29156ead2f3` added `tests/runtime/flow_fsm_queue_capacity_test.gd/.tscn` and the independent bounded `FSM-5C cross-clock capacity focal` workflow step. [GitHub Actions 41350741548](https://github.com/mercurysama/Flujo/actions/runs/41350741548): **FAIL** specifically on the 5C focal; this is preserved diagnostic history.

**Root cause:** `tick()` snapshots existing pending requests into `incoming` and empties `_pending_requests` before calling Update. With 256 incoming events addressed to a different machine clock, a synchronous Update callback could receive `true` from `emit_event` despite the final queue being full. The final `leftovers.slice(0, MAX_PENDING_REQUESTS)` silently discarded that accepted request.

**GREEN (focused production correction):** commit `81ed1de668e64a62ba49db08551c3f398aa81865` reserves capacity for cross-clock incoming items **before** Update. Both `emit_event` and `request_transition` include `_inflight_reserved` in their admission check. A full cross-clock queue causes callback admission to return `false`, not promise a request that will be dropped. Once the other clock drains events, callbacks may enqueue new requests for the next tick. Clearing reserved count at the end of each matching tick restores the normal bound. [GitHub Actions 41350821319](https://github.com/mercurysama/Flujo/actions/runs/41350821319): **SUCCESS** across the full FSM workflow and existing regressions.

**Covered:** exact 256 capacity; 257th event and direct command rejected; wrong-clock carryover retained intact; full-queue callback explicitly rejected; consumed events free capacity; accepted callback deferred one tick and delivered exactly once; FSM base regressions unchanged.

**Not asserted:** full gameplay UI/Android, all combinations of many machines or fault-injected shutdown; no manual approval inferred.

**Next micro-lot 5D:** isolate multi-event priority versus FIFO arrival, multiple clocks and request budget under callbacks without changing shared queue semantics unless a failing focal proves a defect. Later phase 6 addresses multi-machine communication comprehensively.

**Recovery:** checkout `feature/fsm-runtime-flow-flusso`, inspect `docs/fsm_phase5_microblocks.md`, compare last CI against this checkpoint; add one focal before any new engine change. Keep RED/GREEN commits separate and preserve the CI failure as evidence.

## FSM-5D — Multi-event priority/FIFO arbitration (2026-11-01)

**Checkpoint before test:** `0eaff0836f1fd01ea0b4569a4bf876bc3aabd29a`.

- **Test commit:** `c5673a2068d2cd0bf9d07c8be7c4cf62c7584963`. New isolated `tests/runtime/flow_fsm_multi_event_arbitration_test.gd/.tscn` and bounded GitHub Actions focal.
- **Verified:** an event arriving earlier at low priority loses to an event arriving later at high priority; losing events on the same matching clock are consumed after exactly one committed transition; the other clock's event remains queued until its own tick.
- **Ties:** two different event names with equal priority resolve by the earlier request's arrival order (even if its matching authored edge appears later).
- **Explicit commands:** requests have precedence over events even when events arrived first; two direct requests resolve FIFO.
- **Deferred callbacks:** a direct request emitted during an Update observer cannot replace the already selected request; it is delivered on the next matching tick.
- **Graph:** test confirms the authored graph remains structurally valid after execution.
- **Evidence:** [GitHub Actions 41351135946](https://github.com/mercurysama/Flujo/actions/runs/41351135946) **SUCCESS**, including 5D and existing model, Ready, navigation, FSM 001–004 and 5A–5C regressions.
- **Scope:** tests and CI only; no production runtime modification. No Android or manual UI approval implied.
- **Next micro-lot:** phase 5 audit of remaining acceptance gaps before calling the phase complete. Specifically inspect ignored self events, disabled targets, conditional ties, and whether any machine-to-machine behavior should remain in phase 6.

**Recovery:** use this file and latest CI run to resume. Next task remains one limited change with dedicated test, followed by a separate commit if production correction is necessary.
