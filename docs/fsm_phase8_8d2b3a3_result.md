# Potok 8D2-B3A3 — Event replay, queue budget and callback guard

**Date:** 2026-11-02 (America/Mexico_City). **Branch:** `feature/fsm-runtime-flow-flusso`. **Status:** PASS automated CI; human acceptance PENDING.

- Focal: `tests/runtime/flow_fsm_dual_controller_event_budget_test.gd` and `.tscn`, behavior `FLUJO-BHV-POTOK-DETERMINISM-EVENT-BUDGET-007`, mandatory gate in `.github/workflows/flujo-fsm.yml`.
- Source commit `4c733296a491fbe02455095fb81229b3a560d896`; [GitHub Actions 41588927428](https://github.com/mercurysama/Flujo/actions/runs/41588927428) **completed SUCCESS** under Godot 4.7.2. Full previous regressions passed.
- Two independent controllers with two MANUAL machines receive 34 FIFO events on A and a matched event on B. Per-machine budget 32, cross-machine fairness, ordered deferred delivery, single callback-generated event, nested tick guard, equal traces, and read-only authored graph are covered. Identical inputs produce matching output across controllers.
- Catalog marked `passing` after CI, never before. No changes to production, snapshots, model schema, Ready/Timer, UI, main or demonstration scene.
- Local Godot NOT RUN; repository Skills read, not formally invoked. 25 Fedora/Android manual checks still PENDING. Time/other engineering metrics not measured.

**Next:** B3A4 reset and isolation with explicit equal runtime alias IDs; B3A5 full regression/checkpoint, then B3B.

*Todo es Flujo; todo fluye.* 🌊
