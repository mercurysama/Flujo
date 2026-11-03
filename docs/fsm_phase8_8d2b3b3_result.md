# Potok 8D2-B3B3 — Reset/restore in-tick reentrancy isolation

**Date:** 2026-11-03 (America/Mexico_City). **Branch:** `feature/fsm-runtime-flow-flusso`. **Status:** PASS complete Godot 4.7.2 CI; manual checks deferred.

- Test source [`7dd735d`](https://github.com/mercurysama/Flujo/commit/7dd735de16f36e5ceb81690fc106e5b44222d64d): `tests/runtime/flow_fsm_reset_restore_reentrant_guard_test.gd` + scene `.tscn`, mandatory workflow step `Potok-8D2B3B3 reset restore in-tick callback guard focal`, behavior `FLUJO-BHV-POTOK-RESET-RESTORE-REENTRANCY-011`.
- [Actions 41592345621](https://github.com/mercurysama/Flujo/actions/runs/41592345621): **completed SUCCESS** for the focal and full regression. Subsequent [Actions 41592430879](https://github.com/mercurysama/Flujo/actions/runs/41592430879) also **completed SUCCESS** at the earlier B3B2 documentation checkpoint.
- `state_updated` and `transition_committed` deliberately attempt `reset()`, `restore_snapshot()`, and nested `tick()`. Both lifecycle mutations return `false` while the outer tick is active; no nested commits or duplicate lifecycle callbacks occur. An event emitted in Update remains deferred and is discarded by a successful **outside-tick** restore, which emits all Exit callbacks before all Enter callbacks.
- A second `PVController` retains its independent pending request and then commits it on its own clock without modifying the owner's snapshot or authored `FlowGraph`. Scope is bounded (one tick and deterministic callbacks), not an unbounded recursion attack.
- Catalog promoted `not_run` to `passing` only after full successful CI. No production, codec, schema, editor, or demo changes. Local Godot **NOT RUN** and repository Skills **not formally invoked**. Manual 15 Fedora + 10 Android tests **PENDING**.

**Next:** 8D2-B3B4 consolidate callback audit, then 8D2-C requirement→code→test→catalog→CI audit and 8E. B3B3 success alone does not close the whole phase.

*Todo es Flujo; todo fluye.* 🌊
