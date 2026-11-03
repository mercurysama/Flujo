# Potok 8D2-B3A5 — Determinism multi-instance evidence audit

**Date:** 2026-11-03 (America/Mexico_City). **Branch:** `feature/fsm-runtime-flow-flusso`. **Scope:** `8D2-B3A` only. **Result:** **PASS technical CI characterization / documentary audit**; no new production code or test required by this checkpoint. This does **not** close all of 8D2, phase 8 or phase 9.

## Requirements-to-evidence trace

| Microblock | Verified behavior | Test scene / catalog ID | Commit(s) and GitHub Actions |
| --- | --- | --- | --- |
| B3A1 | Two independent controllers, two MANUAL machines, identical direct admission, exact ordered commits, no shared mutable queue and unchanged authored graph | `tests/runtime/flow_fsm_deterministic_dual_controller_test.tscn` / `FLUJO-BHV-POTOK-DETERMINISM-005` | `845f68f`; [41584361713](https://github.com/mercurysama/Flujo/actions/runs/41584361713) **SUCCESS** |
| B3A2 | Reverse cross-machine request admission in two consecutive waves, deterministic authored A→B transition order, equal four-commit traces and independent tick scheduling | `tests/runtime/flow_fsm_two_wave_order_replay_test.tscn` / `FLUJO-BHV-POTOK-DETERMINISM-ORDER-006` | `fcc5d1d`; [41584784409](https://github.com/mercurysama/Flujo/actions/runs/41584784409) **SUCCESS** |
| B3A3 | 34 FIFO A events, one B transition event, per-machine budget 32 and deferred carryover, event emitted inside callback, nested tick guard, identical traces and queues | `tests/runtime/flow_fsm_dual_controller_event_budget_test.tscn` / `FLUJO-BHV-POTOK-DETERMINISM-EVENT-BUDGET-007` | `4c73329`; [41588927428](https://github.com/mercurysama/Flujo/actions/runs/41588927428) **SUCCESS** |
| B3A4 | Explicit shared alias ID values in independent controller-local registries, EPHEMERAL/PERSISTENT activation, per-machine reset Exit→Enter, queue isolation, survivor data and replay | `tests/runtime/flow_fsm_dual_controller_dynamic_reset_test.tscn` / `FLUJO-BHV-POTOK-DETERMINISM-RESET-008` | `ce2f8b5` [41589653144](https://github.com/mercurysama/Flujo/actions/runs/41589653144) **FAIL** (incorrect test order); `fb6c134` [41589766004](https://github.com/mercurysama/Flujo/actions/runs/41589766004) **SUCCESS** |

**Contract links:** `docs/fsm_runtime_contract_v1.md` (`FLU-FSM-001`), `docs/fsm_transition_contract_v1.md` (`FLU-FSM-002`), `docs/fsm_dynamic_contract_v1.md` (`FLU-FSM-003`), and snapshot boundary `docs/fsm_snapshot_contract_v1.md` (`FLU-FSM-004` remains separate). All four behaviors now have `passing` entries in `docs/behavior_catalog.json` and unconditional focal gates in `.github/workflows/flujo-fsm.yml`.

## Audit result and limits

- **Characterized:** reproducible ordered direct commits; A/B machine order; multiwave equivalence; per-machine bounded FIFO and callback delivery; safe non-reentrant tick; per-controller dynamic registry/queue isolation across reset; correct EPHEMERAL removal and PERSISTENT retention; explicit valid IDs rather than comparisons of random IDs; no authored `FlowGraph` mutation.
- **Historical RED preserved:** first B3A4 CI failed on the fixture expectation that resets perform all Exits before all Enters. Runtime actually processes per-machine Exit→Enter; fix was test-only, no removed scenarios or weakened assertions.
- **No production changes** in B3A1–B3A4; focused tests, catalog, docs, workflow only. No new bug requiring architectural, schema or runtime modification was demonstrated.
- **Not covered here:** full callback reentrancy/rollback interactions during `reset()` and `restore_snapshot()` (B3B), cross-phase audit B3C/8E, `restore_from_file` phase 9, debugger phase 10, release phase 11, and all manual/editor acceptance checks. No claim of sandbox safety against hostile GDScript.
- Repository skills `flujo-baseline` and `flujo-prove` were *read*, **not formally invoked**. Remote Godot 4.7.2 Actions provides the listed automated evidence; local Godot **NOT RUN**. Human Fedora 15 + Android 10 = **25 pending**. Timing/other engineering metrics not measured.

## Next recoverable step: 8D2-B3B1

First **audit** existing `reset()` / `restore_snapshot()` and tests before creating any new fixture. Subdivide:

1. **B3B1:** bounded characterization of reset callbacks and queued requests; compare exact per-machine Exit→Enter and rejection of nested reset while guarded; no unbounded recursion.
2. **B3B2:** restore callbacks and pending packet clearing; observe global Exit phase then Enter phase and avoid conflating it with reset's per-machine behavior.
3. **B3B3:** lifecycle mutation attempts during tick and controller/machine isolation, with strictly bounded callbacks and explicit stop on risky hangs.
4. **B3B4:** regression, catalog and written evidence checkpoint; proceed to 8D2-C only after all critical requirements are supported.

Use `tests/runtime/flow_fsm_lifetime_reset_matrix_test.tscn` (B1A), `tests/runtime/flow_fsm_snapshot_preflight_atomicity_test.tscn` (B2B), `tests/runtime/flow_fsm_reentrant_stop_test.tscn` (6H2), and the four B3A focal scenes as baselines. Never modify production to accommodate wrong test expectations. Each test addition needs a behavior entry initially `not_run`, a mandatory bounded gate, and independent commit/CI before declaring PASS.

**Recovery baseline:** last confirmed production-equivalent focal commit `fb6c1340b4fd91b590216e3528f47e8bcdede503`; documentation checkpoint `c0e85e5995b5c2cd0c6e3312e4b3dc48f7e39997`. This document audits earlier verified CI and is not itself fresh Godot test evidence.

*Todo es Flujo; todo fluye.* 🌊
