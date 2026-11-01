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
