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

## FSM-5E — Phase 5 end audit / self-event mismatch (2026-11-01)

**Start HEAD:** `5192185e63f6fff20a1334d9c12f240289967920`. The audit compared the numbered phase-5 checklist against `docs/fsm_transition_contract_v1.md`, runtime, validator and the 5A–5D tests. Do **not** infer full phase closure from the green automated suite.

**RED:** `a6b75ee44c4a6bdefda32a2a1a4c193c68ab7fab` — adds `tests/runtime/flow_fsm_self_event_test.gd/.tscn`, with two higher-priority unusable edges (one self, one disabled destination) and one lower-priority usable target. [CI 41351598674](https://github.com/mercurysama/Flujo/actions/runs/41351598674) **FAILED** on the new focal. Root cause: the EVENT selector admitted self-target edges as arbitration winners, unlike the CONDITION selector, and `tick()` then discarded the winner as a no-op, shadowing a valid lower-priority candidate.

**GREEN:** `e08c6772b42423ae7a337ec83ff0a3eb055fba18` — one minimal check in `FlowFSMRuntime._pick_request` skips event edges targeting the currently active state; existing disabled-target rejection remains unchanged. [CI 41351659685](https://github.com/mercurysama/Flujo/actions/runs/41351659685) **SUCCESS** for 5E and all existing FSM/Ready/navigation/model regressions. No schema, UI or public API change.

### Explicit phase-5 acceptance audit

| Topic | Status / evidence |
|---|---|
| Stable transition ID, same-machine target, trigger, priority, enable flag | Implemented, model/validator and original FSM-002 focal |
| Condition bool evaluation after Update | Implemented, original 002 and 5B focals |
| Event emission/consumption, single transition per tick | Implemented, 5A/5D/5E focals |
| Direct queue deferral, FIFO, event priority/declaration order | Implemented, 5A/5D focals |
| Atomic Exit→active ID→Enter and next-tick Update | Implemented, original 002, 5A and 5B focals |
| Invalid target, non-bool condition, malformed event name | Model/runtime rejection in existing validator, 5A/5B; broader negative matrix still useful |
| Self event target and disabled edge fallback | **Corrected and verified in 5E** |
| **Typed event payload and declared event scope** | **NOT IMPLEMENTED**; `emit_event(machine_id,event_name)` carries no payload |
| **Runtime saturation and failure diagnostic policy** | **PARTIAL**; bounded queue returns false but does not expose a dedicated failure diagnostic for overflow |
| **Condition Tok # authoring surface** | **NOT IMPLEMENTED IN FSM UI**; underlying bool sources supported |
| **Full human/Android visual acceptance** | **NOT RUN** |

**Decision:** phase 5's bounded deterministic, payload-free transition kernel is automated-pass, but **do not mark all nine numbered phase-5 steps complete**. The contract originally narrowed `emit_event` to a name and no payload. The broader numbered plan explicitly asks for typed payload/scope and stable diagnostics. These are separately implementable follow-ups, with cross-machine payload API naturally shared with phase 6. Do not silently weaken the numbered plan to claim closure.

**Next small lot 5F:** define typed event payload and scope as a narrow, public contract *before* implementation, then implement one small part with its own tests/commit. If maintainer prefers moving those API decisions to phase 6, record that explicit scope decision; do not assume approval.

**Recovery:** current branch `feature/fsm-runtime-flow-flusso`, baseline `e08c6772b42423ae7a337ec83ff0a3eb055fba18` with passing CI above. Preserve historical red run, tests, exact fix commit and checklist. Do not begin large UI-FSM or multi-machine refactors as a side effect of closing phase 5.

## Potok / FSM-5F-1 — Typed event payload admission (2026-11-01)

**Public name:** **Potok**, the user-facing name for the State Machine system, selected from the project's multilingual flow glossary. Technical classes and stable serialized names remain unchanged; no FSM editor UI is renamed in this lot.

**Contract-first checkpoint:** `20bd97957ec57ff36f914aa88aa49ea3d19ca255` adds [fsm_5f_event_envelope_contract.md](fsm_5f_event_envelope_contract.md). Scope: machine-ID-directed events, validated JSON-safe `Dictionary` payload, queue isolation and deep copying; no new schema and no public consumer yet.

**RED:** `b4367d69558379400d37da13d7715db26e28a89c` adds `tests/runtime/flow_fsm_event_envelope_test.gd/.tscn` and an isolated CI focal. [Actions 41352181305](https://github.com/mercurysama/Flujo/actions/runs/41352181305) **FAIL**, expected before the optional-argument API existed.

**GREEN:** `f27edb2fb7ec2b64cd14387e8804d0b79ee71efd` updates only `FlowFSMRuntime.emit_event` with optional `payload: Dictionary = {}`, reuses `FlowFSMDataValidator.valid_dictionary`, rejects unsafe/non-JSON/oversized inputs and deep-copies accepted envelopes into the controller-local queue. No registry, graph, storage format or source mutation. [Actions 41352245217](https://github.com/mercurysama/Flujo/actions/runs/41352245217) **SUCCESS** including the focal and all existing FSM/Ready/navigation/model regressions.

**Verified:** existing two-argument event calls remain functional; nested payload is detached; Node/non-string keys/oversized data rejected without queue mutation; valid payload event matches and is consumed; missing machine rejected.

**Pending:** verified public delivery of payload to a handler, typed event consumption/condition binding and runtime diagnostics; event scope remains single-machine only. The name Potok remains documentation-only until the UI-FSM phase. **Phase 5 is not formally complete** and visual/Android acceptance is not claimed.

**Next small lot:** 5F-2 define how a consumed payload becomes available to an observer or compatible Tok at a deterministic tick boundary, independently of cross-machine authoring (phase 6). Maintain RED/GREEN separation and one narrow tested change per commit.

**Recovery:** last runtime-code checkpoint `f27edb2fb7ec2b64cd14387e8804d0b79ee71efd`, then this docs commit. Read `docs/fsm_5f_event_envelope_contract.md` and latest CI run. Do not rename class APIs as a cosmetic consequence of Potok.
