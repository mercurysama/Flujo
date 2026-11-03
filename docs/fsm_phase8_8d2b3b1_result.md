# Potok 8D2-B3B1 — Bounded reset callbacks and queue isolation

**Date:** 2026-11-03 (America/Mexico_City). **Branch:** `feature/fsm-runtime-flow-flusso`. **Result:** PASS technical CI, manual acceptance pending.

- Focal `tests/runtime/flow_fsm_reset_callback_guard_test.tscn` / `.gd`; behavior `FLUJO-BHV-POTOK-RESET-CALLBACK-GUARD-009`; required gate in `.github/workflows/flujo-fsm.yml`.
- Commit [`74f755e`](https://github.com/mercurysama/Flujo/commit/74f755e11f1932b7fcb1cc4fad2c1d2a625fdfba), [Actions 41590902774](https://github.com/mercurysama/Flujo/actions/runs/41590902774) **completed SUCCESS**, Godot 4.7.2 full required suite.
- Calling `reset()` inside `state_updated` during a tick returns false; two legitimate queued direct transitions complete in machine order. A later successful outside-tick reset sends precisely `Exit(A), Enter(A), Exit(B), Enter(B)`, produces no transition commits, and drops owner-only stale direct/event packets. The sibling queue and callbacks stay untouched until its independent tick. Authored graph is unchanged.
- Catalog marked `passing` only after full CI. No production code, editor, snapshot codec or schema changes.
- Local Godot and formally invoked repository Skills: **NOT RUN**. Manual acceptance **0/25** (15 Fedora, 10 Android), deferred. No performance metrics measured.

**Next:** 8D2-B3B2 characterizes successful snapshot restore lifecycle and pending queue clearing. Note: `restore_snapshot()` is not an `reset()` analogue: it emits the Exit phase over **all machines** before the Enter phase over **all machines**.

*Todo es Flujo; todo fluye.* 🌊
