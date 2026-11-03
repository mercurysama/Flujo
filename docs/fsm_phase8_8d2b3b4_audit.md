# Potok 8D2-B3B4 — Reset/restore callback and reentrancy audit

**Date:** 2026-11-03 (America/Mexico_City). **Branch:** `feature/fsm-runtime-flow-flusso`. **Outcome:** **PASS technical characterization and documentary audit B3B1–B3B3**. This audit introduces no additional test and does not claim a new CI run as evidence. **8D2-C, 8E and human acceptance remain open.**

## Evidence matrix

| Scope | Contract and result | Required test / catalog | GitHub Actions |
| --- | --- | --- | --- |
| **B3B1** | `reset()` from a `StateUpdate` callback **returns false** during tick; a later outside-tick reset emits **Exit(A)→Enter(A)→Exit(B)→Enter(B)**, no extraneous commits and clears *only owner* pending direct/event queue | `tests/runtime/flow_fsm_reset_callback_guard_test.tscn`, `FLUJO-BHV-POTOK-RESET-CALLBACK-GUARD-009`, commit `74f755e` | [41590902774](https://github.com/mercurysama/Flujo/actions/runs/41590902774) **SUCCESS** |
| **B3B2** | Successful `restore_snapshot()` emits **Exit(A)→Exit(B)→Enter(A)→Enter(B)**, drops owner stale direct/event packets; saved active state IDs and portable snapshot restored; second controller untouched | `tests/runtime/flow_fsm_restore_callback_queue_test.tscn`, `FLUJO-BHV-POTOK-RESTORE-CALLBACK-QUEUE-010`, commit `4bc3f73` | [41591954025](https://github.com/mercurysama/Flujo/actions/runs/41591954025) **SUCCESS** |
| **B3B3** | From `state_updated` and `transition_committed`, in-tick reset/restore returns false and reentrant tick does nothing; callback-generated event deferred and dropped by subsequent valid outside-tick restore; peer still isolated | `tests/runtime/flow_fsm_reset_restore_reentrant_guard_test.tscn`, `FLUJO-BHV-POTOK-RESET-RESTORE-REENTRANCY-011`, commit `7dd735d` | [41592345621](https://github.com/mercurysama/Flujo/actions/runs/41592345621) **SUCCESS** |

## Cross-contract and governance review

- `FlowFSMRuntime.reset()` processes Exit→Enter **per authored machine**; `restore_snapshot()` processes **all Exits then all Enters**, since publishing new snapshot state is a global boundary. They are intentionally different contracts. The historical fixture error in B3A4 [41589653144](https://github.com/mercurysama/Flujo/actions/runs/41589653144) was corrected test-only in `fb6c134`, with [41589766004](https://github.com/mercurysama/Flujo/actions/runs/41589766004) SUCCESS; it does not indicate a production defect.
- `_in_tick` lifecycle guard, bounded callback signal sequence, FIFO delivery of deferred event and independent `PVController` queues are characterized without changing `FlowGraph`, `FlowFSMRuntime` or `FlowFSMSnapshotCodec`. Existing negative snapshot preflight B2B and deterministic B3A1–B3A4 focals stay in mandatory CI.
- Each test has an automatic behavior-catalog entry marked `passing` **only after** remote CI and a mandatory bounded 70-second Godot 4.7.2 workflow step. The complete B3B group of three focals plus all earlier regression gates has verified successful runs.
- Technical result covers **these bounded scenarios only**. It does not establish arbitrary malicious callback safety, all event permutations, visual behavior, mobile acceptance or performance characteristics; no measurements were made. CI evidence is not equivalent to local Fedora/Android manual acceptance.
- Repository Skills documentation may guide work but formal execution was not performed. Local Godot **NOT RUN**; 25 human checks (15 Fedora, 10 Android) deferred.

## Next microblock: 8D2-C1 technical traceability audit

1. Inventory `8D2-A`, `8D2-B1A/B1B`, `8D2-B2A/B2B`, `8D2-B3A1–A5`, `8D2-B3B1–B4` against `FLU-FSM-003`, snapshot `FLU-FSM-004`, behavior catalog IDs, mandatory scenes/gates, commits and CI evidence.
2. Verify persisted/dynamic lifetime boundaries and export/restore fallback semantics without re-opening phase 9; separate **verified** from deferred/unsupported.
3. If traceability is complete, close 8D2-C as a **documentary technical audit only**, then prepare 8E. Do not change `main`, edit production code, merge, or mark manual acceptance complete.

**Current checkpoint:** B3B3 source `7dd735d` [SUCCESS CI 41592345621](https://github.com/mercurysama/Flujo/actions/runs/41592345621). B3B2 docs commit `514e111` [SUCCESS CI 41592430879](https://github.com/mercurysama/Flujo/actions/runs/41592430879). New B3B4 documentation revision should run CI separately and not be called PASS until GitHub finishes.

*Todo es Flujo; todo fluye.* 🌊
