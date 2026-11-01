# Flujo FSM — Iteration journal / Skill learning

**Iteration:** FSM-01 / remote branch `feature/fsm-runtime-flow-flusso`  
**Start:** 2026-11-01  
**Status:** IN PROGRESS. No FSM runtime/UI test pass is claimed.  
**Origin:** `feature/block-builder-fprint-dogfood` @ `5cf7c4d5a3e1a1e292036ff5da393433c8c54e8c`.

## Objective and scope

Implement the FSM plan in [fsm_implementation_plan.md](fsm_implementation_plan.md) while preserving portable runtime/editor separation, schema compatibility, FlowGraph immutability and per-PVController runtime isolation. Keep user-facing UI in the existing Inspector → Fluo → Flow / Flusso workflow. This journal is the source for later enrichment of the Flujo skill; describe reproducible lessons, not unverified impressions.

## Baseline already inspected (code review, not test execution)

- `FlowStateMachineDefinition`: stable identity, enabled flag, ordered states, `initial_state_id`, lookup and deep duplication.
- `FlowStateDefinition`: inherited block container, legacy `is_initial` (schema 1 only).
- `FlowGraphValidator`: per-machine initial-state integrity and stable identity validation.
- `FlowReadyExecutor`: Ready, Timer and legacy supported constructor paths in schema 3/4, with `FlowNavigationDecision` and per-execution budgets.
- `PVController`: existing per-instance output, context and timer runtime; schema 5 stores have a separate, non-executable contract.
- Fluo: Inspector container activation, Flow selection, Flusso editing, live persistence and Revertir, keyboard navigation, panel-side switching. Do not duplicate Inspector Blocks.

## Engineering decisions to preserve

1. A machine with one state is a complete executable definition; an empty machine can only be edited.
2. Serialized definitions must never store the runtime active state.
3. Dynamic states live in the controller instance and do not mutate `FlowGraph`.
4. Persistent references are stable IDs, not names, array indices, NodePaths or references to live Nodes.
5. Transitions must be queued and non-reentrant with deterministic conflict order and bounded work.
6. A model/schema extension requires explicit migration and round-trip tests before promotion.
7. New blocks use the existing generic SDK/catalog/Fluo path; avoid container-specific duplicate block classes.
8. Changes to existing behavior require `$flujo-baseline` before production edits, `$flujo-prove` before committing and manual approval of visible UI. A missing test is **not** a PASS.

## Achievements and evidence

| Item | Outcome | Evidence |
|---|---|---|
| Isolated development branch | CREATED | `feature/fsm-runtime-flow-flusso` |
| Implementation plan | ADDED | `docs/fsm_implementation_plan.md` |
| UI requirements review | REVIEWED | `README.md`, `docs/current_iteration.md`, `docs/fluo_preview_01.md` |
| FSM execution | NOT YET VALIDATED | No new executable milestone claimed |
| Desktop / Android manual review | PENDING FINAL GATE | Separate acceptance lists required |

## Obstacles and safeguards

- The current work environment cannot resolve github.com through the container's Git client and has no detected Godot/Flatpak binary. GitHub connector reads/writes work, but **local headless Godot execution is not available here**. Any verification not actually run must remain pending. Never fabricate a successful command or approval.
- The baseline branch contains schema 5 stores that are not covered by Ready/Timer execution. Do not silently enable them when implementing FSM.
- `FlowStateDefinition.blocks` currently carries ordered blocks; any `enter/exit` additions need a defined compatibility policy.
- Changing Inspector/Fluo UI requires manual verification for focus and Android/touch; headless tests cannot substitute for that evidence.

## Next work and handoff

1. Freeze the first numbered runtime/specification decisions and establish remote test evidence.
2. Implement the smallest independently auditable FSM runtime slice after the baseline gate.
3. Add transitions, events, multiple machines, dynamic state registry, persistence, UI and debug incrementally.
4. After the branch implementation and automated evidence, download it on Fedora for one grouped human validation matrix.
5. At each milestone append **observed** behavior, exact files/commands, pass/fail or not-run status, regressions, causes, fixes and reusable Skill rules here. Include only available engineering-flow metrics.

**Skill takeaway:** require explicit FSM separation between authored definitions, instance-local scheduler, serializable snapshots, and the editor; keep all acceptance evidence labeled automatic/manual/unrun.

Todo es Flujo; todo fluye. 🌊

## 2026-11-01 — Node-panel drag/drop authoring recipe

**Achieved:** documented a detailed reuse-first, skill-guided authoring recipe at [recipe_node_drag_drop_custom_blocks.md](recipe_node_drag_drop_custom_blocks.md) and linked it from the existing block-builder skill as a **planning reference only**. It distinguishes the already implemented Scene Node → NodeRef payload/slot flow from the unimplemented scene-node → discovered block insertion flow.

**Challenge:** manifest v1 has a frozen whitelist of fields and D4 supports a limited generic scalar surface; a node-class compatibility descriptor and deterministic destination-phase binding are not existing public SDK capabilities. Do not claim the proposal is already supported or sneak its fields into manifest v1.

**Next iteration:** maintainer review of the proposed C-class SDK extension; test a single node-class family and the same distributable block in Process, Timer and each State Machine phase; verify Undo/Redo, focus, cancel, persistence and Android separately. Apply actual evidence to the skill after the first approved dogfood.

**Reusable skill lesson:** treat scene-node drag/drop as authoring composition, not as a new block type or per-container runtime implementation.

## 2026-11-01 — Phase 4 audit and recovery checkpoint

- **4B:** added `tests/runtime/flow_fsm_lifecycle_edge_test.gd/.tscn`: repeated Update on a single state, reset Exit→Enter, delta, signal order, disable→enable, idempotent stop, Exit on scene teardown. [CI 41346215618](https://github.com/mercurysama/Flujo/actions/runs/41346215618): **PASS**.
- **4C:** added `tests/runtime/flow_fsm_engine_clocks_test.gd/.tscn`: live PROCESS/PHYSICS scheduling, SceneTree pause/resume, stop deferred from Update callback, no duplicate Exit. [CI 41346334448](https://github.com/mercurysama/Flujo/actions/runs/41346334448): **PASS**.
- **Result:** phase 4 runtime contract has focused automated evidence; no production runtime changes were needed. This does not certify Android, human visual behavior, exhaustive error injection or every possible reentrant callback.
- **Next:** move to phase 5 micro-lots, retaining separate automated and manual gate status. The case sequence and URLs are indexed in [fsm_phase4_audit.md](fsm_phase4_audit.md).
- **Skill lesson:** a green one-state test only proves its tested clock; a separate real-clock/paused-tree focal is required to substantiate engine-level lifecycle behavior.

## 2026-11-01 — Phase 5A event arbitration checkpoint

- Added `tests/runtime/flow_fsm_event_order_test.gd/.tscn` and independent CI step; covers event rejection/no-match consumption, same-priority authored tie break, higher-priority resolution, Update→Exit→Enter order, deferred destination Update, and events raised from synchronous Update observers.
- The first pass [CI 41347838123](https://github.com/mercurysama/Flujo/actions/runs/41347838123) was green. Test fixture subsequently refined to define priorities before gameplay; targeted step for [CI 41347899663](https://github.com/mercurysama/Flujo/actions/runs/41347899663) also passed.
- Engine unchanged; tests characterize previously unasserted scenarios. Do not claim phase 5 overall completion. Next **5B**: condition false/true/type errors and self transitions; **5C**: request overflow and multievent edge conflicts.
- Recovery plan: read `docs/fsm_phase5_microblocks.md` and resume after the last commit; preserve strict separation of tests and fixes and maintain one micro-lot per commit.

## 2026-11-01 — Phase 5B recovery checkpoint

- Commit `ef856654ecefcd3a6760ab68a4881e928c288cfa`: focused conditions/self no-op regression `flow_fsm_conditions_test.gd/.tscn` and an isolated workflow step.
- [CI 41349532108](https://github.com/mercurysama/Flujo/actions/runs/41349532108): focused 5B step passed. Detailed assertions: false/true priority including self edge, one commit, next-tick Update, invalid int/null condition rejection, startup refusal.
- No FSM runtime code changed. Resume with `docs/fsm_phase5_microblocks.md` section **FSM-5B**, then implement **5C** separately.
- Learned: type-invalid authored conditions should fail before runtime creation; self-target requests are consumed without reentering the same state.

## 2026-11-01 — FSM-5C RED/GREEN checkpoint

- Reproduced full cross-clock queue callback admission bug with `tests/runtime/flow_fsm_queue_capacity_test.gd/.tscn` and CI [41350741548](https://github.com/mercurysama/Flujo/actions/runs/41350741548) (FAIL). Test commit `70082beb8d81234c037a050f2370f29156ead2f3`.
- Fixed in separate runtime-only commit `81ed1de668e64a62ba49db08551c3f398aa81865`: reserve inflight queue capacity for requests of nonmatching clock, reject overflow during synchronous Update instead of accepting then dropping. CI [41350821319](https://github.com/mercurysama/Flujo/actions/runs/41350821319) **SUCCESS** including all existing baselines.
- Lesson: pending request size alone is **not** the full capacity in an active tick; include in-flight carryover for deferred multi-clock delivery. Preserve failing diagnostic run for root-cause traceability.
- Next: 5D multiple event arbitration; detailed history in [fsm_phase5_microblocks.md](fsm_phase5_microblocks.md). No human Android approval claimed.

## 2026-11-01 — Phase 5D recovery checkpoint

- Commit `c5673a2068d2cd0bf9d07c8be7c4cf62c7584963`: multi-event arbitration test and dedicated CI focal; [CI 41351135946](https://github.com/mercurysama/Flujo/actions/runs/41351135946) **SUCCESS**.
- Priority overrides arrival across distinct events; equal-priority ties use FIFO arrival, direct requests preempt events and are FIFO, other-clock pending events survive; callback requests defer to following tick.
- No runtime code changes. Next: phase 5 gap audit, then phase 6 multi-machine integration in independently recoverable lots. See `docs/fsm_phase5_microblocks.md`.

## 2026-11-01 — Phase 5E audit and red/green recovery

- **Failing characterization:** test/CI commit `a6b75ee44c4a6bdefda32a2a1a4c193c68ab7fab`, [Actions 41351598674](https://github.com/mercurysama/Flujo/actions/runs/41351598674) FAIL. Self-target event stole arbitration from usable lower-priority edge, though conditional self edges were already ignored.
- **Minimal fix:** `e08c6772b42423ae7a337ec83ff0a3eb055fba18` skips self-target event candidates in `_pick_request`. [Actions 41351659685](https://github.com/mercurysama/Flujo/actions/runs/41351659685) SUCCESS with all existing focal/regression suites.
- **Open before full phase 5 acceptance:** typed event payload and explicit event scope (current `emit_event` carries only `StringName`); saturation diagnostics; FSM Condition Tok # editor (separate UI-FSM). Do not conflate the narrower approved runtime protocol with the broader nine-point plan. See [phase5 microblocks](fsm_phase5_microblocks.md).
- **Next:** 5F contract-first scoped payload behavior (one small commit per step). Reuse public data validator, not a parallel serialization format; avoid multi-machine phase 6 scope until specifically specified.

## 2026-11-01 — Potok naming and FSM-5F-1 checkpoint

- User-facing name **Potok** chosen from the established multilingual flow glossary. Fluo/Flow/Flusso and Akis/Tok unchanged. Existing `FlowFSMRuntime` and `FlowStateMachineDefinition` identifiers frozen.
- Specification `20bd97957ec57ff36f914aa88aa49ea3d19ca255` → red focal `b4367d69558379400d37da13d7715db26e28a89c` ([CI 41352181305](https://github.com/mercurysama/Flujo/actions/runs/41352181305) failed as expected) → minimal runtime `f27edb2fb7ec2b64cd14387e8804d0b79ee71efd` ([CI 41352245217](https://github.com/mercurysama/Flujo/actions/runs/41352245217) SUCCESS).
- `emit_event(machine_id,event_name,payload={})` validates existing JSON-safe bounded dictionary and takes an independent deep copy. No visible payload binding to Akis/Toks yet; do not claim that consumers can read event payloads.
- Continue at `docs/fsm_phase5_microblocks.md` section 5F-1, then 5F-2 delivery/consumer contract and specific focal. Android/manual validation remains at grouped final stage.

## 2026-11-01 — Potok 5F-2 consumption observer checkpoint

- Contract `de7e4b0de954afd615a1a649534943b9e7d2032d`; test `14dae4b143a106003a762950fb97c20402943aaf` ([CI 41352804834](https://github.com/mercurysama/Flujo/actions/runs/41352804834) FAIL); runtime `59eaa042af38562872c532f15178340c9a7bf91e` ([CI 41352843883](https://github.com/mercurysama/Flujo/actions/runs/41352843883) SUCCESS).
- Added `event_consumed(machine_id,event_name,payload)` read-only signal for each incoming event addressed to current clock, after Update and before arbitration. Payload deep copied on emission; no mutation of source graph or controller state. Unmatched events still notify observers. Callback requests remain queued for next tick.
- Not yet a Condition Tok binding or per-listener immutable object, and no cross-controller event broadcasting. Resume through `docs/fsm_phase5_microblocks.md` 5F-2 and consider isolated queue error diagnostics 5G.

## 2026-11-01 — Potok 5G admission diagnostics checkpoint

- Contract `be370f3a92f92beab30ca27b88ab49d64daa2010`; test commit `a82ecfe6700042949c19e948a685ddfc37789d30` ([CI 41353542099](https://github.com/mercurysama/Flujo/actions/runs/41353542099) FAIL); runtime commit `ad65cfde37f55635b28dd5b66f944b993a68f411` ([CI 41353576853](https://github.com/mercurysama/Flujo/actions/runs/41353576853) SUCCESS).
- Admission now emits `request_rejected(machine_id,kind,code)` with stable reasons while returning the original bool; refusal never enqueues anything. Covers invalid event, missing machine/target, invalid payload, full queue including in-flight carryover, stopped runtime.
- Resume through `docs/fsm_phase5_microblocks.md` 5G. Do not claim visual/Android approval or typed payload binding to Tok. Phase 6 remains separate.

## 2026-11-01 — Potok phase 5 final audit / phase 6 entry

- **Audit commit:** `a561b00ee468519918750085a9c1a1c11c5989c9`, document `docs/fsm_phase5_final_audit.md`. Pre-audit code baseline `7cfce77474a6b44da2e0ad4e58cab37d1cbb704a` passed full [CI 41353678703](https://github.com/mercurysama/Flujo/actions/runs/41353678703).
- **Decision:** phase 5 deterministic kernel and scoped payload observer receive **automated acceptance**, not full nine-item feature closure. Potok Condition Tok `#` editor authoring and typed payload-to-Tok binding remain missing. Admission diagnostics are present but broader fault-injection handling is not.
- **Approved next engineering direction:** proceed in separately committed phase-6 micro-lots, beginning 6A contract and headless focal for a machine requesting a transition in another machine's clock. Do **not** call the feature release-ready or claim Android/manual FSM review.
- Keep prior RED/GREEN and all source contracts intact. The audit changes no runtime/model code.

## 2026-11-01 — Potok 6A green checkpoint

- Contract commit `f288301c68852fe8e82ac55bffd2a2b0377ca4ad`; test `d44968843f4c324c33b5aa3a2d12b4339dc807ff`; workflow `738584a568ecf360590bb9bd31b3416b8fa63d67`. [CI 41354940595](https://github.com/mercurysama/Flujo/actions/runs/41354940595) **SUCCESS**.
- A's Update callback requests B state transition; the request waits until B's own PHYSICS clock and cannot execute in recursive tick. Transition atomic; source unchanged. Unknown machine and foreign target fail without mutation.
- No runtime patch needed. Next independent lot 6B: Enter/Exit cross-machine deferral. Potok phase 5 Tok authoring pending.

## 2026-11-01 — Potok 6B green recovery

- Contract `23b3c915607f6bd5a00cb16a8dd3e0751222e90d`, test `e936c392d4b38851ec6722904cfa4b0c7ebc7b98`, workflow `84e8fc218e9a03407206823a39ba225670563c0e`. [GitHub Actions 41356265134](https://github.com/mercurysama/Flujo/actions/runs/41356265134) SUCCESS.
- Cross-machine commands from Enter/Exit observers defer to target clock and obey FIFO, including callbacks in both directions; reentrant tick ignored. No engine code changed.
- Next 6C: contract-first cyclic chaining / budget saturation independent of unimplemented visual Potok/Tok authoring.

## 2026-11-01 — Potok 6C-2 chain budget RED/GREEN recovery

- Contract `27fc4eda2df870dc84eb946c1c294f5c03b0b21b`; failing test/CI `dbf00cc72626054d90ec165e3219cf7d672b4d46`, `1c767018fcd03426576009dc0e7e3e620d3fe473`, `f49181a87d071e173f49a5ce595696956dd79a16` ([CI 41357182605](https://github.com/mercurysama/Flujo/actions/runs/41357182605) FAIL).
- Runtime fix `612f57bf23cf47e3723f8e3f031300eed4fe454f`; [CI 41357280685](https://github.com/mercurysama/Flujo/actions/runs/41357280685) SUCCESS including all prior tests.
- Instance-local lineage carried through direct/event requests and transition callbacks; max eight committed hops in inherited chain; ninth-hop rejection `chain_budget_exceeded` suppresses chain descendants while preserving an independent root. No schema/UI change.
- Resume via `docs/fsm_phase6_6c2_result.md`, then 6D event lineage/sibling/multiple-controller test. Per-tick CPU budget, direct request reason/payload, Potok UI and Android manual testing are not done.
