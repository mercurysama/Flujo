# Potok 7E-1D — Repeated scene roundtrips and independent instance runtime

**Date:** 2026-11-01 local / 2026-11-02 UTC. **Branch:** `feature/fsm-runtime-flow-flusso`. **Baseline:** `b2446056cc6d3afbe8cc2ceafa000b0fe81a1f66`; [GitHub Actions 41394055961](https://github.com/mercurysama/Flujo/actions/runs/41394055961), SUCCESS (48 steps).

## Requirement and ownership

Original phase-7 item 9 requires stable persisted machine/state/edge IDs and correct save/reopen semantics after authoring. This final 7E-1 persistence slice follows 7E-1A, 7E-1B1/1B2 and 7E-1C. It must **not** require new IDs when Godot instantiates a saved scene.

**Important ownership distinction:** the authored `FlowGraph` is an immutable definition and the same `PackedScene` may share its resource between multiple instances. That is not leakage by itself. Every `PVController` instead owns its own `FlowFSMRuntime` and `FlowValueResolutionContext`; runtime activation, queued events, ephemeral event packets and variable values must remain instance-local.

## Microblock acceptance

1. Create a scene-owned schema-3 controller with one MANUAL-ticked machine, two ordered states (Idle, Active), authored Enter/Update/Exit phase blocks, and a stable-ID EVENT edge Idle→Active. Record graph/machine/state/block/transition identities, phase order/content, initial and target IDs. Graph validates.
2. Pack/save the scene to a test-owned `.tscn` (first save). Free the source, reload with `ResourceLoader.CACHE_MODE_IGNORE`, instantiate and confirm exact authored IDs/order/content. Repack **that reopened instance** and save to a distinct test-owned `.tscn` (second save); release it, reload again without cache, instantiate **two copies**. Both must retain exactly the original authored IDs, references, phase contents and valid graphs.
3. Add both second-generation copies to the live SceneTree. Confirm separate `PVController` instances with running, distinct `FlowFSMRuntime` and `FlowValueResolutionContext` objects; shared authored `FlowGraph` identity and immutable definition remain unchanged. Ensure test does not assert distinct authored resource objects as a false requirement.
4. Write transient variable and per-machine-scoped event packet to instance A only; they must be absent in B. Queue and deliver a MANUAL-clock `emit_event` to A; A transitions to Active but B remains Idle and has no pending event. Stop A; B must keep running and independently transition after its own event. Verify graph identity, structure, original IDs and no serialized runtime state after both actions.
5. Cleanup exactly the two test-owned files under ignored `res://.godot/flujo_tests/`. Add a dedicated Godot 4.7.2 headless focal to `.github/workflows/flujo-fsm.yml`, preserving existing 7E and 7D/7C, full model/runtime/editor/catalog/Git whitespace gates.

## Scope and safety

**Tests, workflow and docs only.** No production `addons/`, schema, runtime scheduler, controller or Fluo editor changes; no `demo/main.tscn`, no `main`. No inferred UI/touch/keyboard human acceptance. Do not mutate shared authored resources or invent per-instance new persistent IDs.

**Relevant existing evidence:** [7E-1A](fsm_phase7_7e1a_result.md) proves one authored save, [7E-1B1](fsm_phase7_7e1b1_result.md)/[7E-1B2](fsm_phase7_7e1b2_result.md) prove editor Undo/Redo persisted edits, [7E-1C](fsm_phase7_7e1c_result.md) proves ephemeral event packets stay out of `.tscn`. `tests/runtime/flow_fsm_runtime_test.gd` and `tests/runtime/flow_fsm_event_payload_condition_test.gd` already show controller-local execution/context, but not independent controllers instantiated after a **second scene save/reopen**. Existing catalog adjacent invariants: `FLUJO-BHV-FLUO-EDIT-001`, `FLUJO-BHV-BLOCK-EXTERNAL-PERSIST-001`; preserve their assertions.

## Skill-guided verification

Consult versioned `$flujo-baseline` and `$flujo-prove` instructions in `tools/agent_skills/`, `AGENTS.md`, Constitution, development workflow and model contract. Baseline HEAD `b2446056cc6d3afbe8cc2ceafa000b0fe81a1f66` has full successful CI. Direct standalone agent Skill invocation and local Git index/user worktree inspection are unavailable in this GitHub-connector environment. Do not report formal `READY` or `PASA` without those checks; use actual CI evidence and separately declare pending manual review.

**Next after 7E-1D:** 7E-2A FSM keyboard/selection behavior in a separate focused microblock. Leave 7E-4 desktop+Android manual acceptance and the phase-7 phase-block Add closure audit explicitly pending.

Todo es Flujo; todo fluye. 🌊
