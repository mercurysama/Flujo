# Potok 8D2-B3A4 — Deterministic dynamic reset replay

**Date:** 2026-11-03 (America/Mexico_City). **Branch:** `feature/fsm-runtime-flow-flusso`. **Technical status:** PASS automated CI. **Manual acceptance:** PENDING.

## Scope and traceability

- `FLU-FSM-003` reset/isolated dynamic state lifetime; authored graph `FLU-FSM-001` and FIFO `FLU-FSM-002` invariants unchanged.
- Characterization scene `tests/runtime/flow_fsm_dual_controller_dynamic_reset_test.tscn` and script `.gd`, catalog `FLUJO-BHV-POTOK-DETERMINISM-RESET-008`, required gate `Potok-8D2B3A4 deterministic dual-controller dynamic reset focal` in `.github/workflows/flujo-fsm.yml`.
- First commit `ce2f8b517bace5e1487ba8d36e11d09f243af939` [Actions 41589653144](https://github.com/mercurysama/Flujo/actions/runs/41589653144) **FAIL**, one new-test assertion only. Test incorrectly expected all machine Exits to precede all machine Enters.
- Existing `FlowFSMRuntime.reset()` contract actually processes each authored machine sequentially: `Exit(A), Enter(A), Exit(B), Enter(B)`. This matches existing 8D2-B1A characterization and is **not** evidence of a production runtime defect.
- Test-only fix `fb6c1340b4fd91b590216e3528f47e8bcdede503` corrects expected per-machine order without weakening callback count, isolation, queue or lifetime assertions. [Actions 41589766004](https://github.com/mercurysama/Flujo/actions/runs/41589766004) **completed SUCCESS**, full Godot 4.7.2 suite and new mandatory focal.
- Two independent `PVController` runtimes share immutable authored graph, register identical explicit (not random) alias IDs in their own registries, and replay the same activation, mixed queues, independent resets and post-reset persistent activation. `EPHEMERAL` removed; `PERSISTENT` retains ID and detached data; no stale queued commands or callbacks leak between controllers.

## Limits and recovery

No production, codec, snapshot version, Ready/Timer, editor, `demo/main.tscn` or `main` edits. Skills `flujo-baseline`/`flujo-prove` read but **not formally invoked**; local Godot **NOT RUN**. All **25 manual checks** (15 Fedora, 10 Android) remain pending. Other engineering metrics: not measured.

**Next:** 8D2-B3A5 audit of deterministic multi-instance replay B3A1–B3A4, then 8D2-B3B bounded reset/restore callback characterization. Do not close 8D2-C or 8E implicitly.

*Todo es Flujo; todo fluye.* 🌊
