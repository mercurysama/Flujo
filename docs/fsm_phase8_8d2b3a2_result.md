# Potok 8D2-B3A2 — Ordered two-wave deterministic replay

**Date:** 2026-11-02 (America/Mexico_City). **Branch:** `feature/fsm-runtime-flow-flusso`. **Technical status:** PASS in Godot 4.7.2 GitHub CI.

- Test-only implementation: `fcc5d1d7240cb30a3fa0dcbbcc406db9c236b412`. Scene `tests/runtime/flow_fsm_two_wave_order_replay_test.tscn`; script `.gd`; mandatory GitHub Actions workflow gate.
- [Actions 41584784409](https://github.com/mercurysama/Flujo/actions/runs/41584784409): **completed SUCCESS**, including new focal and existing suite. Subsequent [Actions 41584864583](https://github.com/mercurysama/Flujo/actions/runs/41584864583) also **completed SUCCESS** at B3A1 documentation checkpoint `d629c80`.
- Behavior ID `FLUJO-BHV-POTOK-DETERMINISM-ORDER-006`: two real controllers, each sharing a graph with two MANUAL machines of three authored states. Two direct waves queue machine B before machine A. Despite input ordering, commits follow authored A→B machine order per wave; both instances produce the same four exact commit signatures, end in state 2 of both machines and drain their own queues without affecting the peer. Authored graph remains unchanged.
- Catalog `not_run` → `passing` **only after** remote CI completion. No production, snapshot codec, UI or schema changes.
- Local Godot and formal invocation of repository Skills: **NOT RUN** (documentation read only). Human acceptance: **0/25**, 15 Fedora + 10 Android pending. Timing and other engineering metrics: not measured.

**Next:** 8D2-B3A3 deterministic event admission/consumption, bounded per-machine work and non-reentrant callback delivery across two controllers, in independent test-only microblocks. B3A4/A5 and 8D2 overall remain pending.

*Todo es Flujo; todo fluye.* 🌊
