# FSM phase 4 — audit / micro-batch 4B

**Date:** 2026-11-01. **Branch:** `feature/fsm-runtime-flow-flusso`. **Scope:** only FLU-FSM-001 lifecycle acceptance and its independent characterization tests.

## Baseline and audit findings

- The preceding FSM-001 focal confirms the basic single-state Enter → manual Update → disable Exit path and separate PVControllers.
- Current runtime provides `start`, bounded `tick`, `stop`, `reset`, active-state query and signals. `PVController` connects FSM ticking to Godot `_process` and `_physics_process`.
- The original FSM-001 test did **not** assert reset/Exit→Enter, repeated single-state ticks, disable→enable recovery, idempotent stop or Exit during scene teardown. The new **4B** focal characterizes these public behaviors without changing the FSM engine.
- **Not automatically proved:** pause/unpause with real SceneTree ticks, PROCESS/PHYSICS scheduling, synchronous signal reentrancy, error paths and external human/Android review. Do not mark the entire phase 4 formally closed from a green core test.

## Micro-lot 4B

Added `tests/runtime/flow_fsm_lifecycle_edge_test.gd` and `.tscn`. CI runs this focal with a timeout and preserves the earlier regressions. The test records both output messages and runtime signals to expose sequencing differences.

| Check | Evidence |
|---|---|
| Single-state update repeats without transitions | 4B focal |
| Reset exits and re-enters in order | 4B focal |
| Manual tick delta and update signals | 4B focal |
| Disable stops, no duplicate Exit | 4B focal |
| Re-enable initializes new runtime + Enter | 4B focal |
| Scene teardown final Exit | 4B focal |
| Real pause/physics clock, signal reentrancy, failure diagnostics | **Pending separate 4C focal** |

## Continuity

**Next micro-lot 4C:** isolate real Godot pause/process/physics integration and synchronous signal callbacks. Only after recorded CI evidence decide whether a small implementation fix is necessary; do not blindly refactor the FSM engine. Track failures in this file and in `docs/fsm_iteration_01_learning.md`.

**Skill lesson:** tests that assert `manual tick` do not prove the engine's scheduling, pause, or signal-reentrancy behavior. Preserve independent acceptance matrices.
