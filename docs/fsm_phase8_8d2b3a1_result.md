# Potok 8D2-B3A1 — Two-controller deterministic replay

**Date:** 2026-11-02 (America/Mexico_City). **Branch:** `feature/fsm-runtime-flow-flusso`. **Status:** PASS technical CI; acceptance human deferred.

## Verifiable evidence

- Specification: [8D2-B3A1 contract](fsm_phase8_8d2b3a1_contract.md) commit `3528ac9efe8faf3e83000bea1ee552c518e589a6`.
- Characterization: `tests/runtime/flow_fsm_deterministic_dual_controller_test.gd` and `.tscn`; [commit `845f68f`](https://github.com/mercurysama/Flujo/commit/845f68fd583ccb1eef60b3a7ba6f1d282cf73aa5).
- Mandatory focal in `.github/workflows/flujo-fsm.yml` and catalog `FLUJO-BHV-POTOK-DETERMINISM-005`.
- [Godot 4.7.2 Actions 41584361713](https://github.com/mercurysama/Flujo/actions/runs/41584361713): **completed SUCCESS**, including mandatory focal and prior regressions.
- Behavior: two independent PVControllers share the same authored two-machine graph; each receives identical direct commands. Authored machine-order exact commit trace, initial/final IDs, pending queues and graph immutability are verified. One controller's tick never consumes the other's requests.
- Production code / codec / schema / editor changes: **none**. Baseline `deba501b` [CI 41582684417](https://github.com/mercurysama/Flujo/actions/runs/41582684417) SUCCESS.

## Governance and limits

Catalog entry marked `passing` only after the full remote CI PASS. The repo Skills `flujo-baseline` and `flujo-prove` were read as instructions, not formally invoked; local Godot **NOT RUN**. No visual acceptance inferred; 15 Fedora + 10 Android manual checks still PENDING. Time/machine metrics: not measured. This is a characterization with unmodified production, not completion of 8D2 or Phase 9.

**Next:** 8D2-B3A2 ordered two-wave replay (focal committed as `fcc5d1d` and initial catalog status `not_run`), followed by events/budgets in B3A3.

*Todo es Flujo; todo fluye.* 🌊
