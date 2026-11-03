# Potok 8D2-B3A1 — Deterministic replay contract and minimal scenario

**Date:** 2026-11-02 (America/Mexico_City). **Branch:** `feature/fsm-runtime-flow-flusso`. **Baseline HEAD:** `deba501bfacbb6a72f67895f2acda4a530adcc17`. **Baseline CI:** [41582684417](https://github.com/mercurysama/Flujo/actions/runs/41582684417) **SUCCESS**, historic 94/94. **Status:** SPECIFIED / NOT RUN; this document does not establish a new test PASS.

## Scope and existing contract

This microblock defines the experiment for deterministic behavior under `FLU-FSM-001`, `FLU-FSM-002`, and `FLU-FSM-003`, without changing `FlowGraph`, runtime semantics or `FLU-FSM-004` snapshots. Two independent `PVController` instances share one authored `FlowGraph` definition containing **two MANUAL machines**, while each controller owns its own mutable `FlowFSMRuntime`. IDs for authored machines/states are obtained once from the shared graph; dynamic alias IDs, when introduced in B3A4, are supplied explicitly and consistently, not compared as independently generated random IDs.

Existing tests to reuse rather than duplicate: `tests/runtime/flow_fsm_dynamic_pending_multimachine_test.tscn` (8C2 FIFO/purge and multi-machine isolation), `tests/runtime/flow_fsm_lifetime_reset_matrix_test.tscn` (8D2-B1A reset), and relevant 6A/6B/6G coordination and negative-routing focal cases. Baselines are historical CI evidence, not locally rerun in this planning-only checkpoint.

## B3A1 minimal executable contract (next implementation step)

1. Build a valid schema 3 authored graph with two distinct MANUAL FSMs, each with `Idle` and `Target` authored states; record and reuse stable IDs for each controller.
2. Create two real `PVController` nodes sharing that exact graph, await lifecycle initialization, and assert distinct running runtimes with identical initial active state IDs for both machines.
3. Attach per-runtime signal listeners collecting **ordered** `transition_committed` traces, including `machine_id`, `from_state_id`, `to_state_id`, and `trigger_id`; do not infer order from a dictionary.
4. Submit the **same explicit sequence** independently to each runtime: one direct change to `Target` of machine A, one direct change to `Target` of machine B, then one MANUAL tick with the same delta. Compare API acceptance, pending counts before/after, full ordered commit traces and active state IDs. Require the expected transitions (not merely equality of two empty traces).
5. Verify no mutation of `FlowGraph` authored machine/state arrays and no sharing of mutable runtime objects. Cleanly stop/free both controllers.
6. Register test `.gd` + `.tscn`, a new behavior catalog entry initially `not_run`, and an **unconditional** bounded CI gate; obtain Godot 4.7.2 CI and proportionate regressions before changing any behavior entry to `passing`.

**Negative/edge bounds:** no expectations about random alias IDs; avoid asserting uncontracted callback ordering; do not introduce unbounded recursion, timers or editor APIs. An unexpected RED is a characterization result and requires diagnosis; never alter production code or weaken assertions automatically.

## Subsequent independent microblocks

- **8D2-B3A2:** ordered cross-machine commit traces and machine iteration, with more than one requested transition and explicit expected sequence.
- **8D2-B3A3:** identical event/direct request interleaving, FIFO consumption, bounded budgets, no reentrancy; verify both independent queues.
- **8D2-B3A4:** reset/restart and dynamic aliases with **explicit** stable IDs, ensuring isolation and equivalent replay traces without mutating authored graph.
- **8D2-B3A5:** full regression, documentation, baseline-vs-new evidence, and checkpoint for 8D2-B3B.

## Governance and recovery

Preserve `main`, Ready/Timer, `demo/main.tscn`, schemas, snapshots, UI and all sibling branches. Existing 25 manual tests (15 Fedora, 10 Android) remain PENDING. Repository versions of `flujo-baseline` and `flujo-prove` were **read**, **not formally invoked**; local Godot/focal testing **NOT RUN** in this documentation-only microblock. Next action is B3A1 test-only implementation and new CI evidence, not claiming B3A1 tested. Engineering metrics beyond stated GitHub evidence: not measured.

*Todo es Flujo; todo fluye.* 🌊
