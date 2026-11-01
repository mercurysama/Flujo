# Potok 6A — deferred requests between machines

2026-11-01. Contract: machine A (manual clock) requests a transition of machine B (physics clock) from A's Update callback. This must enqueue; B changes only on its own next tick, with Update(old), Exit(old), Enter(new) and delayed Update(new). A recursive tick called inside A's callback must be ignored. Unknown machine and foreign target must be rejected with existing diagnostics without adding queued items. Authored graph stays immutable; old APIs stay intact. This micro-lot adds one isolated headless test before any engine correction. Reason payload, cyclical chains and UI remain for later phase-6 work.

## 6A verification and recovery (2026-11-01)

- **Contract:** `f288301c68852fe8e82ac55bffd2a2b0377ca4ad`.
- **Test-only commit:** `d44968843f4c324c33b5aa3a2d12b4339dc807ff` introduces `tests/runtime/flow_fsm_cross_machine_request_test.gd/.tscn`. **Workflow commit:** `738584a568ecf360590bb9bd31b3416b8fa63d67` adds the independent focal to `.github/workflows/flujo-fsm.yml`.
- [GitHub Actions 41354940595](https://github.com/mercurysama/Flujo/actions/runs/41354940595) **SUCCESS** for 6A plus all earlier FSM and model/Ready/navigation regression steps.
- Source A (MANUAL) issues direct request targeting B (PHYSICS) from A's Update listener. The request is accepted and retained through further A ticks. An attempted nested PHYSICS tick is ignored. On B's first matching tick, the target commits Update(old) → Exit(old) → Enter(new), and Update(new) waits for another B tick. Foreign state IDs and unknown machine IDs are rejected without queue mutation. A remains unchanged.
- **Engine runtime unchanged.** This is characterization of already present behavior, not a claim that the entire phase 6 is implemented. No serialized model, UI or Android changes.
- **Next micro-lot 6B:** define/test cross-machine commands originating in Enter/Exit observers and their delivery ordering, without adding reason/payload fields until a separate typed contract is approved. Later 6C can address chain-local saturation/cycle policy and multi-controller isolation.
- **Recovery:** resume from the 6A evidence above and this document. Do not infer Phase 5 Tok/UI completion from green 6A CI.

## 6B — Cross-machine Enter/Exit callback contract (2026-11-01)

- A and B are different machines on MANUAL and PHYSICS clocks within one controller. After start, A is directly moved from A0 to A1. On A0 Exit a listener requests B1; on A1 Enter another listener requests B2. Both admissions return true and preserve FIFO order. Attempts to invoke B's tick recursively from the callbacks do nothing.
- Neither B target can execute during A's clock. B's first PHYSICS tick consumes the two requests, commits B0 → B1 exactly once (FIFO), and defers the new state's Update.
- During B0 Exit and B1 Enter, callback requests targeting A2 and A1 respectively are queued for A's next MANUAL tick. No reentrant A transition or second B transition occurs. The valid A2 direct request wins before the self-target A1 request, and the self request is harmlessly consumed.
- Preserve authored graph resources, stable IDs, existing queue limit and lifecycle signals. This lot tests existing APIs only. No direct request reason/payload, budget redesign, multi-controller API or UI changes.
- Acceptance: dedicated headless 6B test with targeted CI plus existing regression matrix; modify the engine only if a concrete failure is demonstrated.

## 6B — Verified Enter/Exit cross-machine deferral (2026-11-01)

- **Contract commit:** `23b3c915607f6bd5a00cb16a8dd3e0751222e90d`. **Focal test commit:** `e936c392d4b38851ec6722904cfa4b0c7ebc7b98` adds `tests/runtime/flow_fsm_cross_machine_lifecycle_test.gd/.tscn`. **CI wiring:** `84e8fc218e9a03407206823a39ba225670563c0e`.
- [GitHub Actions 41356265134](https://github.com/mercurysama/Flujo/actions/runs/41356265134) **SUCCESS**, including the dedicated `Potok-6B cross-machine lifecycle focal` and all prior regression steps.
- Test observes requests from A0 Exit and A1 Enter toward B1 then B2, both admitted and queued. B remains unchanged during A tick. On B's matching clock, the first target B1 wins FIFO, then B0 Exit and B1 Enter enqueue two requests back to A. These cannot execute recursively and commit on A's subsequent clock; the first valid A2 request wins over later same-state A1. Queue drains without duplicate transitions; authored graph remains valid.
- **No runtime/model production changes**. Existing controller-local queue and synchronous signal callbacks already honor the lifecycle boundary. This is evidence for 6B only, not for chain/cycle saturation or phase 6 completion.
- **Next micro-lot 6C:** define and test cyclic cross-machine ping-pong and saturation/chain budget behavior. Do not modify shared budget without a reproducible failing focal and explicit contract. UI/Android and Condition Tok payload integration remain outside this lot.
- **Recovery:** resume from CI 41356265134 and the docs checkpoint, inspect latest HEAD, preserve the test and distinct commits.

## 6C-1 — Bounded cyclic delivery characterization (2026-11-01)

**Scope:** characterize finite A → B → A request chains and burst rejection without silently redefining cross-tick chain identity. The approved phase-6 plan calls for chain-local saturation diagnostics, but the existing runtime currently has no chain identifier or full per-chain budget; those require a separate explicit policy and must not be reported as completed by this focal.

- In one controller, machine A (MANUAL) and B (PHYSICS), each with two alternating states, request one transition in the other machine from `state_entered` when a real transition commits.
- Initial A request triggers A → B → A on successive explicit matching clocks. Each clock commits at most one transition, and recursive calls made by observers are ignored. The other-clock queue remains intact; state IDs, not names, route requests.
- Test terminates the cyclic producer after a finite number of commits to ensure deterministic, repeatable behavior and queue drainage. No source edits or run-time graph mutations.
- Fill the pending queue with 256 events destined for B, check that A's request is rejected with `queue_full` without mutation, and that a subsequent B tick drains the burst, freeing capacity. This is a controller-level admission budget, **not** yet a chain-local execution budget.
- Preserve unrelated machine behavior and all previous CI regression tests.
- **Decision gate for 6C-2:** specify chain identity/provenance and per-tick budget plus affected-chain cancellation without discarding unrelated work; add a separate RED test before any production changes. A long-running but bounded one-transition-per-tick cycle is legitimate unless such a policy explicitly identifies it as saturated.

## 6C-2 — Verified chain-local hop limit (2026-11-01)

- **Contract:** `27fc4eda2df870dc84eb946c1c294f5c03b0b21b`; **RED test and CI:** `dbf00cc72626054d90ec165e3219cf7d672b4d46`, `1c767018fcd03426576009dc0e7e3e620d3fe473`, `f49181a87d071e173f49a5ce595696956dd79a16` ([Actions 41357182605](https://github.com/mercurysama/Flujo/actions/runs/41357182605) FAIL, expected).
- **Runtime correction:** `612f57bf23cf47e3723f8e3f031300eed4fe454f` ([Actions 41357280685](https://github.com/mercurysama/Flujo/actions/runs/41357280685) **SUCCESS** across all existing tests).
- Introduces per-controller lineage IDs; synchronous transition callbacks inherit a chain with an eight-commit hop limit. A ninth-hop enqueue is rejected with `chain_budget_exceeded`, pending descendants of the affected chain are filtered, and an unrelated request remains eligible.
- **Not finished:** independent event-chain/multiple-sibling tests, per-tick CPU budget, all phase-6 direct-request payload/reason work, Potok editor and manual Android verification. See [6C-2 result](fsm_phase6_6c2_result.md) and [contract](fsm_phase6_6c2_chain_budget_contract.md).
- **Next 6D:** test event-sourced lineages and sibling cancellation; keep commits small and preserve the phase-5 Tok/UI debt.

## 6D — Event lineage, sibling cancellation and controller isolation (2026-11-01)

- **Contract commit:** `435dd379c04669bcf11594ed94d9a89c45de43cc`, `docs/fsm_phase6_6d_contract.md`.
- **Test:** `19da090c52fa591c364396375aac809b5a1b4c5d`, scene `2644fb16129bf298f5ba43984dbda1288c73b79c`, isolated workflow focal `4c0c37d3ecc5fb6b044f653462ce788425dbf7e6`.
- [GitHub Actions 41357686834](https://github.com/mercurysama/Flujo/actions/runs/41357686834) **SUCCESS**, including 6D and every preceding Potok/model/Ready/navigation regression step.
- **Verified:** graph-defined event transitions carry inherited lineage across A↔B clock ticks; an event generated within Enter is delivered on its matching clock, budget is enforced after hop eight, and exactly one ninth-hop direct request is rejected with `chain_budget_exceeded`. A sibling request queued on the seventh hop is removed when its lineage saturates, while an independently seeded request to the same third machine remains queued and later commits. A second controller sharing the identical authored `FlowGraph` starts its own independent root, changes state, and does not change the first controller's state.
- **Production runtime unchanged.** No graph schema, snapshots, editor or public API changes. These are behavioral characterization assertions, not evidence of a general per-tick CPU budget.
- **Next micro-lot 6E:** audit the remaining phase-6 scope: explicit reason/payload for direct requests and per-tick processing budget, plus chain-failure fault injection. Separate contractual decision before writing engine code. Potok Condition Tok UI integration and manual Android review remain pending.

## 6E — Phase 6 gap audit and planning gate (2026-11-01)

- Full numbered 7-point acceptance matrix: [6E audit](fsm_phase6_6e_audit.md). Documentation-only commit `a3ae38b0004b4d466d1d3a9a9fad1e8d497da4d1`.
- Pre-audit baseline `499711314c1e11465c0c59fb528eb1f8e95f3a8d` passed [Actions 41357770163](https://github.com/mercurysama/Flujo/actions/runs/41357770163); 6D focal passed [Actions 41357686834](https://github.com/mercurysama/Flujo/actions/runs/41357686834).
- Stable-ID directed cross-machine scheduling, callback deferral, eight-hop chain isolation and earlier FSM regression matrix are automated-pass. No engine change in this audit.
- **Not closed:** typed reason/payload metadata on direct requests; per-tick work budget distinct from 256 admission cap and eight-hop lineage limit; negative target-disable/scene-tree permutations and release/manual validation.
- **Next independent lot 6F-1:** contract-first direct-request reason/payload semantics, preserve two-argument API and original `transition_committed` signal; RED test, minimal GREEN, regression CI. Then 6G per-tick budget, 6H negative/fault tests. Phase-5 Tok/UI and phase-7 Android review remain separate.

## 6F-1 — Typed direct request metadata accepted (2026-11-01)

- **Contract:** `f8630d20f5fd6a2947ad45fbd77e376cce36c617`. **RED test and CI:** `9dac7cefb3140a642d92299a18c9dee7fe6b1393` + `87726b0f8ae3208b5d3855f706800b09b496f426` + workflow `c935d757799ed0f34656c6b4f886b071e550d290` ([Actions 41359653289](https://github.com/mercurysama/Flujo/actions/runs/41359653289) FAIL, expected).
- **Production GREEN:** `d0e670af2af8dd5f86009d83f7bb5b7e214e2f89` ([Actions 41359760201](https://github.com/mercurysama/Flujo/actions/runs/41359760201) **SUCCESS** all regressions).
- Existing `request_transition(machine_id,target_state_id)` now optionally takes `reason: StringName` and validated `payload: Dictionary`; old callers and four-argument `transition_committed` remain compatible. A new `direct_transition_committed` signal delivers detached metadata only for committed direct requests.
- Rejection `invalid_reason` for reason beyond 128 characters; `invalid_payload` for unsafe/unbounded data. FIFO, cross-clock scheduling, lineage and graph immutability remain verified. See [6F-1 result](fsm_phase6_6f1_result.md) and [contract](fsm_phase6_6f1_direct_request_contract.md).
- **Next 6G:** separate per-tick processing budget and fairness contract/test. This is not equivalent to global 256 queue cap or eight-hop lineage guard; Potok UI/Android and Condition Tok binding remain pending.

## 6G — Bounded per-machine packet work, no starvation (2026-11-01)

- **Contract:** `76057049fcb0b5d80e08919cecf363754ca147b0`. **RED focal / CI:** `387ffded2840665a706040d94592abb37d0d087f` + scene `2299c301229580582b1a04dd16727e4c8d640b72` + workflow `84ef9bdc6e8ca56350f97cf2c7ddc8b92ab2b796` ([Actions 41360868794](https://github.com/mercurysama/Flujo/actions/runs/41360868794) FAIL expected).
- **Runtime GREEN:** `c22ef8fd2693b2356948bfb6b3363ecdaea1b707`; compatibility adjustments only to 5G `36095a4e024a3e85fbe453d9fbc6f43aebf9efab` and 5C `46f4f82fee34d0e24efb2d7b8d35cc8fd8c3eb00`. [Actions 41361104238](https://github.com/mercurysama/Flujo/actions/runs/41361104238) **SUCCESS** for all workflow tests.
- Every matching machine receives a separate 32-packet per-tick direct/event work budget. Surplus is retained in admission FIFO ahead of callback-generated packets, including cross-clock items in the shared 256-entry capacity reservation. `work_budget_deferred(machine_id,count)` reports backpressure, not rejection. Other machines still advance on their matching clock. 5G and 5C now assert eight-cycle lossless drainage of the original 256 unmatched packets; 6C-1 contained no burst-drain check and did not need modification.
- **Boundary:** packet budget is not CPU milliseconds, a global limit across every machine, or the eight-hop chain budget. Current-batch direct/event priority is preserved; requests in later batches remain invisible to this tick's arbitration. See [6G result](fsm_phase6_6g_result.md) and [contract](fsm_phase6_6g_work_budget_contract.md).
- **Next micro-lot 6H:** negative/fault-injection matrix, disabled machine/scene order, stop mid-transition and final phase-6 runtime acceptance audit. Condition Tok/UI/Android remain pending.
