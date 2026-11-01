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
