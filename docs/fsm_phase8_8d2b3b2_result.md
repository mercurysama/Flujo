# Potok 8D2-B3B2 — Global snapshot restore callbacks and stale queue

**Date:** 2026-11-03 (America/Mexico_City). **Branch:** `feature/fsm-runtime-flow-flusso`. **Technical status:** PASS complete Godot 4.7.2 CI. **Human acceptance:** PENDING.

- Source test commit [`4bc3f73`](https://github.com/mercurysama/Flujo/commit/4bc3f735ec669eadec5643da4491bbba65032814), mandatory focal `tests/runtime/flow_fsm_restore_callback_queue_test.tscn`, catalog behavior `FLUJO-BHV-POTOK-RESTORE-CALLBACK-QUEUE-010`.
- [Actions 41591954025](https://github.com/mercurysama/Flujo/actions/runs/41591954025) **completed SUCCESS**, including new focal and all required previous regression gates. Earlier B3B1 also succeeded [41590902774](https://github.com/mercurysama/Flujo/actions/runs/41590902774).
- Two independent PVControllers share a graph with two MANUAL machines. Owner exports target-state snapshot, moves back to initial states and queues one direct and one event packet while peer queues its own direct packet.
- Successful owner `restore_snapshot()` emits exactly `Exit(A), Exit(B), Enter(A), Enter(B)` with no `transition_committed`; clears owner stale queue; recovers saved active states and portable snapshot; does not consume or callback peer queue. Later ticking peer affects only peer.
- Important difference: `reset()` is per-machine `Exit(A), Enter(A), Exit(B), Enter(B)` while `restore_snapshot()` uses global Exit phase then global Enter phase.
- Catalog promoted `not_run` → `passing` **after** CI. No runtime, snapshot codec, model schema, editor, `main` or demo changes. Local Godot **NOT RUN**, formal repo Skills **NOT INVOKED**, 25 manual checks pending.

**Next:** B3B3 in-tick reentrancy and isolation, test commit `7dd735d`; B3B4 checkpoint, then 8D2-C audit, and 8E. B3B3 is NOT PASS until its own full CI succeeds.

*Todo es Flujo; todo fluye.* 🌊
