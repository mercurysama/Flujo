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

## 2026-11-01 — Potok 6D green checkpoint

- Contract `435dd379c04669bcf11594ed94d9a89c45de43cc`, tests `19da090c52fa591c364396375aac809b5a1b4c5d` + `2644fb16129bf298f5ba43984dbda1288c73b79c`, CI focal `4c0c37d3ecc5fb6b044f653462ce788425dbf7e6`.
- [Actions 41357686834](https://github.com/mercurysama/Flujo/actions/runs/41357686834) SUCCESS. Event-driven A↔B lineage, ninth-hop rejection, sibling cancellation, unrelated request preservation, and isolated second PVController verified. Runtime code unchanged.
- Next: phase-6 gap audit (6E), then narrow reason/payload and per-tick budget tests. No manual/Android or phase-5 Tok visual acceptance inferred.

## 2026-11-01 — Potok 6E phase-6 gap audit

- [6E audit](fsm_phase6_6e_audit.md) commit `a3ae38b0004b4d466d1d3a9a9fad1e8d497da4d1`; pre-audit HEAD `499711314c1e11465c0c59fb528eb1f8e95f3a8d` [CI 41357770163](https://github.com/mercurysama/Flujo/actions/runs/41357770163) SUCCESS. This lot modified documentation only.
- Accepted: runtime cross-machine IDs, deterministic queues and callback deferral, finite A↔B chains, 8-hop lineage and independent roots (6A–6D). Unfinished: direct-request typed reason/payload, per-tick work budget, negative machine disable/invalidation permutations, human Android testing.
- Next lot: 6F-1 define backwards-compatible optional request metadata and observable consumption/commit without altering existing four-argument `transition_committed`, then RED/GREEN CI. Phase 5 Condition Tok UI remains pending.

## 2026-11-01 — Potok 6F-1 green recovery

- Contract `f8630d20f5fd6a2947ad45fbd77e376cce36c617`; RED test `9dac7cefb3140a642d92299a18c9dee7fe6b1393` + scene `87726b0f8ae3208b5d3855f706800b09b496f426`, workflow `c935d757799ed0f34656c6b4f886b071e550d290` ([CI 41359653289](https://github.com/mercurysama/Flujo/actions/runs/41359653289) FAIL).
- Runtime GREEN `d0e670af2af8dd5f86009d83f7bb5b7e214e2f89`; [CI 41359760201](https://github.com/mercurysama/Flujo/actions/runs/41359760201) SUCCESS all regressions.
- Direct `request_transition` accepts optional `reason: StringName`, `payload: Dictionary`, validates, deep-copies and reports only on committed direct transitions via new signal. Old two-argument API and `transition_committed` preserved; denied metadata emits stable diagnostics; callbacks defer. See `docs/fsm_phase6_6f1_result.md`.
- Next 6G per-tick work budget/fairness, then 6H negative testing. Do not claim full phase 6, Tok UI or manual Android acceptance.

## 2026-11-01 — Potok 6G per-machine packet budget green

- Contract `76057049fcb0b5d80e08919cecf363754ca147b0`, RED test `387ffded2840665a706040d94592abb37d0d087f`, scene `2299c301229580582b1a04dd16727e4c8d640b72`, CI focal `84ef9bdc6e8ca56350f97cf2c7ddc8b92ab2b796` ([Actions 41360868794](https://github.com/mercurysama/Flujo/actions/runs/41360868794) FAIL expected).
- Engine `c22ef8fd2693b2356948bfb6b3363ecdaea1b707`, updated 5G `36095a4e024a3e85fbe453d9fbc6f43aebf9efab` and 5C `46f4f82fee34d0e24efb2d7b8d35cc8fd8c3eb00` drain assertions, [Actions 41361104238](https://github.com/mercurysama/Flujo/actions/runs/41361104238) SUCCESS all tests.
- Per-machine 32-packet tick processing with fair independent machines, precise carryover reservation and `work_budget_deferred` telemetry; not a CPU-time or all-machine total budget. See `docs/fsm_phase6_6g_result.md`.
- Resume next at 6H fault-injection tests and phase-6 acceptance; do not close phase-5 Condition Tok and Potok Android UI work.

## 2026-11-01 — Potok 6H final runtime acceptance recovery

- Contract `1cf700c783f4e38bbb2eb0db45788d8eb39d26cd`; tests `5857efa96e728de08aabbb22656b53f3d449f875`, `94b8a942e793adac9e762cddacb4ce2094ee3e23`, `efe478c3517fcc9bfff1fde7001292aa946299f8`, `58832cf2792b3b17bd010612e1ed1a1b757bbea2`; workflow `28ea30ceb7441ed90e3aa1d6612e009494c0da66`.
- [CI 41363216050](https://github.com/mercurysama/Flujo/actions/runs/41363216050) FAIL for nested-stop lifecycle duplicates (6H-1 green); runtime `_stopping` fix `e494bcf39d27aa1ab25b6c31688ceb1287a98887` produced full [CI 41363328505](https://github.com/mercurysama/Flujo/actions/runs/41363328505) SUCCESS.
- See `docs/fsm_phase6_6h_result.md` and `docs/fsm_phase6_final_audit.md`. FLU-FSM-002 core multi-machine runtime is automated-pass, **not** global CPU-budget guarantee, complete fault fuzzing, phase-5 Tok integration or Potok UI/Android release validation.
- Resume at 7A authoring contract for Potok UI with explicit Tok payload/condition dependencies, or a separately scoped 6I global-work-SLA lot if necessary. Preserve red/green commits and the GitHub workflow as recovery evidence.

## 2026-11-01 — Potok 7A read-only UI projection green recovery

- Contract `6c44d8614f03269fe9575ef813148c6827aa3440` in `docs/fsm_phase7_7a_contract.md`; RED test `7c55954c76a3585bfb85cefb4e408d172d429c8d`, scene `b5f71ca2a7b2ac04786ddad7b9180321a598db4f`, CI `6467f163e5a6c1aa58bb1db0d3aeaa40ce55b9d2`. [CI 41364627238](https://github.com/mercurysama/Flujo/actions/runs/41364627238) FAIL as expected.
- GREEN editor-only `FlowFSMEditorProjection` `1afd8e3a90f02e73fbcfd0fc21a60e99f54dcf60`; [CI 41364696760](https://github.com/mercurysama/Flujo/actions/runs/41364696760) SUCCESS all regressions.
- Projection owns no graph state; returns stable IDs, machine/state order, true initial ID, three phase block IDs and typed transition metadata, Empty draft as inert placeholder. Same names do not confuse machine selection. No runtime or schema changes.
- Recovery through `docs/fsm_phase7_7a_result.md` and `docs/fsm_phase7_microblocks.md`. **Next lot 7B:** wire Inspector machine activation via existing Fluo/Flow shell and stable-ID list navigation; then 7C property editing, 7D Tok bridge, 7E keyboard/touch/manual Android.
- Do not assert that 7A provided interactive FSM UI or closed phase-5 Tok binding or Android acceptance. Human tests remain batched for final review.

## 2026-11-01 — Potok 7B Fluo navigation green checkpoint

- Contract `70360ab9069e0d34f90088118966c834505ea57d`; test `e902c52a2de9f25192d8fa05a087471958743ceb`, workflow `7c4fa7ec9ddd1b0be64f589f8f5c45c0619ea3df`, RED [41365606656](https://github.com/mercurysama/Flujo/actions/runs/41365606656).
- Inspector stable-ID activation `d9f5eb66f7cad98e1754a7a121dfb71747451cf5`, Fluo state hierarchy `1bbfb56dc735c242ca70e2729f58dd04f442b1be`, keyboard/Escape focus `ba8fb88caecb0001b9f2e780a2bf808bb89ce2f9`, reorder/removed-controller test `1956397ce8cda4d74ea1153afae389611518222c`. [Full CI 41365966187](https://github.com/mercurysama/Flujo/actions/runs/41365966187) SUCCESS.
- Existing Fluo and Flow view, state list, initial marker and Enter/Update/Exit presentation are read-only. Current editor focus, machine-ID synchronization and unchanged Ready paths proven by automated editor focal. Human Android UI acceptance remains batched.
- Resume using `docs/fsm_phase7_7b_result.md` and `docs/fsm_phase7_microblocks.md`. Next 7C-1 small property-editing commands/Flusso, then 7C-2 transitions and deletion, 7D Condition Tok/payload bridge and 7E manual/persistence checks; no full phase-7 closure yet.

## 2026-11-01 — Potok 7C-1 validated Flusso scalar forms and Undo/Redo

- Contract `92eb751db2d115144f71da8a05f4c8d8bd6e4c05`; RED test `70d5189ba3a9c01569bdc07cac6c2be0048f0c5b`, workflow `436ae51cee8ab871e973c98277a0d534e11aebc0`; expected [RED CI 41368002884](https://github.com/mercurysama/Flujo/actions/runs/41368002884).
- Commands `d4e69b297ac34c524ac08b1870b7d5035535bbd3`, Flusso editor `816e2a1115c4b68dcccb8bb36e5734ed59f61d36`, guard-test `5f7c38566d46495040c8aa46ea873948962ab29d`, enhanced UI test `5089266f20c1ec568692922fa3e75ee5cf4953ca`. [GREEN CI 41368408164](https://github.com/mercurysama/Flujo/actions/runs/41368408164) all FSM/model/editor regressions.
- Machine fields name/enabled/autostart/tick/note/initial ID; state fields name/enabled/note. Detached candidate validation, exact ID ownership and `EditorUndoRedoManager` single-action edits. Native Flusso widgets, texts committed via Enter (not on typing); unchanged legacy state `is_initial`. Current initial state cannot be disabled.
- Read `docs/fsm_phase7_7c1_result.md` before **7C-2A** transition metadata authoring and **7C-2B** structural state/edge commands. Condition Tok/event payload integration and Android manual QA not complete.

## 2026-11-01 — Potok 7C-2A transition metadata and Flusso green recovery

- Contract `1096d5a02e59dbd074c9fbd0c579d61cbf28ec3d`; RED test `c3b90c37c11d1f1ced595a7b73ecbb9a3a2cb7b5`, workflow `0f67d70fee29a1f54855a539a2299da0fddf9730`, [CI 41371010519](https://github.com/mercurysama/Flujo/actions/runs/41371010519) expected failure.
- Safe commands `35e787da9e24cdc50b55ddf60f5aca1a41438b8a`; Flow edge list `a86134f7fcd00ee9737e7d9fd8b49f75cd4b0e38`; Flusso controls `ecc12fc1379a786accb3d3d3147eacacf11db079`; expanded UI test `8013dc53cdbe49bad976f1f804205c0ac6fde5d4`, feedback `e7f1a97cbbb6ad748d56a77cec965c4f71c46fbf`, final negative UI regression `40a9b70075f3a73cf53293b34ac08063e5047a4c`. [Full CI 41371757005](https://github.com/mercurysama/Flujo/actions/runs/41371757005) SUCCESS.
- Existing transition metadata edits by stable IDs validated on detached graph candidate, committed via Undo/Redo. Invalid foreign targets, blank event or missing Bool source blocked; UI shows trigger rejection feedback and Empty state draft. No graph or runtime changes.
- Resume from `docs/fsm_phase7_7c2a_result.md` and `docs/fsm_phase7_microblocks.md`; **next 7C-2B** structure/dependency/Cancel, 7D Condition Tok and event payload binding, 7E persistence/Android visual QA. Preserve small RED/GREEN commits and delay manual reviews until consolidated acceptance.

## 2026-11-01 — Potok 7C-2B structural Flow editor green recovery

- Contract `d46a9482d3fb90e2abfcb3f887a12b08e5058f50`; RED `0ba60a18fcbd33c57f004cf706c991b81a73494a`, workflow `ae9f04cbabad9eaffe58023f794548d625e7f817` [Actions 41373165948](https://github.com/mercurysama/Flujo/actions/runs/41373165948) FAIL as expected. UI focal `f165f75164897ccf8464fd6110f34a616e6cf340` with workflow `c27b56c5b377f8f18103b614354bbc4cdcc62d92`.
- State commands `682c36e304372d7d3f0e88665775a5d36def31be`, transition commands `1df74115e2e02aea8c352393607c23b594011002`, Flow actions `0b8b0163cee7ca665af31581d8e9b72106ade628`, safe confirmation `8d60f953384903ee802d393356b8c045ec8b2f8f`, final first-selection improvement `69b67bdf0bf6a614bd8c4770b40c31250d788902`, final test `ae90066bcefdf63d8154d71f52287f06c35929a3`. [Full GREEN CI 41374189278](https://github.com/mercurysama/Flujo/actions/runs/41374189278).
- Add/duplicate/move/delete states and transitions; new IDs and self-loop remap on duplication; initial-state atomic repair; reject deletion with any surviving inbound edges (including disabled), true Cancel/close/stale-selection guards and single-action Undo/Redo. None of these mutations come from the read-only `FlowFSMEditorProjection`.
- Read `docs/fsm_phase7_7c2b_result.md`, `docs/fsm_phase7_7c2b_contract.md` and `docs/fsm_phase7_microblocks.md` before **7D** Tok `#` and typed payload expression UI. 7E saved scene and final Android human QA not yet done.

## 2026-11-01 — Potok 7D Condition Tok and event-payload binding recovery

- **7D-1 visual Tok # bridge:** contract `34d047109a6235c6ec62d3bd9ad97d1f2521aea6`, RED test `e61ac400d09bc26deb792d98cdd6b0b8e700ea4b`, UI `6f1161692994a99044aa0195ad8621cd718d5cf5`, test fix `18e6333f8b2c38ad79d30533ecda5645b433b0bf`. [GREEN CI 41381250681](https://github.com/mercurysama/Flujo/actions/runs/41381250681), documentation `docs/fsm_phase7_7d1_result.md`.
- **7D-2 event field typed condition operand:** contract `106354de39cdea1cfdaf7870c3be9814005dbc7e`, source `086a1a00a249ce947a60b8c6d0b797c2eddf0ddf`, context `b483f3f549ca62eeb3e3c6bd985638346c6c995f`, model `ba590913cbd9781d27e0af4611271e9dfd290b8d`, runtime `2dfb9a22f89a1567a554bf6468e8b5705a1ae941`, Tok UI `67b636cec08e6357531f58f5a731d7b72e0b8d58` and Potok context `ad5c1127db045ef82254dab4223cdae23e627535`, final test `3a7c92f6e71d3d2072c9e1d7d01557b254be0762`. [Full CI 41382298522](https://github.com/mercurysama/Flujo/actions/runs/41382298522) SUCCESS. Documentation `docs/fsm_phase7_7d2_result.md`.
- Condition Tok # now edits via detached popup + validated Undo/Redo. Typed event payload source holds only event name, field and exact type, not packet values. An unmatched event can feed a fallback condition on that machine's matching clock, never a stale other-machine/controller scope; missing/mismatched types fail. Event edge arbitration still has precedence; event-field values are not accessible in StateEnter/Exit.
- **Next 7E:** saved scene roundtrips, focus/keyboard/touch and consolidated manual Android visual pass. Do not claim full phase 7 release/manual acceptance solely from green headless CI.


## 2026-11-01 — Potok 7E-1A authored scene persistence regression

- Source [7E-1A contract](fsm_phase7_7e1a_contract.md); implementation `96322e705475c3fd80e944935136332a28f0785a`; [Actions 41389274900](https://github.com/mercurysama/Flujo/actions/runs/41389274900) SUCCESS (new focal and existing CI regressions).
- Reused the established normal `PackedScene` / `ResourceSaver` pattern to verify exact persisted graph, machine, ordered state, transition and phase block IDs, initial/target references, block content and valid reopen. No runtime, model schema or editor production change.
- Lesson: separate authored-scene serializability from command Undo/Redo and Condition Tok semantic-payload persistence; these belong in their own fail-localized microblocks 7E-1B and 7E-1C.
- Formal local skill gates, `git diff --check` and manual Android/desktop review NOT RUN here; remote green CI cannot approve them. Next: 7E-1B contract → test → CI → result checkpoint.


## 2026-11-01 — Potok 7E-1B1 skill-guided remote testing

- Contract `docs/fsm_phase7_7e1b1_contract.md`, test `tests/editor/flow_fsm_edited_scene_roundtrip_test.gd`, code commit `5e956b28a9587c3a96617f06ea613bc8b6d4a2f0`, CI gate fix `a0dc7f97ff07470b2ef909d4ab12b68fb13bba84`; [full CI 41390280243](https://github.com/mercurysama/Flujo/actions/runs/41390280243) SUCCESS. Two repeated Undo/Redo cycles plus save/reopen preserve IDs, state order, initial and event target.
- Lesson: `git show --check HEAD` with GitHub Actions default shallow checkout may reinterpret the current commit as a root and report unrelated historical whitespace; first [CI 41390202530](https://github.com/mercurysama/Flujo/actions/runs/41390202530) FAIL in this new gate and skipped the focal. Fix by `fetch-depth: 2`, `git diff --check HEAD^ HEAD`; second CI passed. Do not edit unrelated historical Markdown merely to get green.
- Repo Skills `$flujo-baseline` and `$flujo-prove` can be consulted and their checks followed through GitHub + Actions, **but they cannot be invoked as standalone agent tools** in this session; record procedure-applied vs direct-invocation-not-run, without claiming formal READY/PASA. Manual UI remains separate.
- Next: 7E-1B2 structural/edge command Undo/Redo persistence regression; stay within editor tests and existing commands unless failing evidence identifies a real production defect.
