# FSM phase 4 — audit / micro-batch 4B

**Date:** 2026-11-01. **Branch:** `feature/fsm-runtime-flow-flusso`. **Scope:** only FLU-FSM-001 lifecycle acceptance and its independent characterization tests.

## Baseline and audit findings

- The preceding FSM-001 focal confirms the basic single-state Enter → manual Update → disable Exit path and separate PVControllers.
- Current runtime provides `start`, bounded `tick`, `stop`, `reset`, active-state query and signals. `PVController` connects FSM ticking to Godot `_process` and `_physics_process`.
- The original FSM-001 test did **not** assert reset/Exit→Enter, repeated single-state ticks, disable→enable recovery, idempotent stop or Exit during scene teardown. The new **4B** focal characterizes these public behaviors without changing the FSM engine.
- **Now automatically proved by 4C:** real SceneTree pause/unpause, PROCESS/PHYSICS scheduling and callback-requested deferred stop. **Still not covered exhaustively:** arbitrary nested synchronous signal mutations, fault injection/error paths and any external human/Android acceptance.

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

**4B evidence:** [GitHub Actions 41346215618](https://github.com/mercurysama/Flujo/actions/runs/41346215618) — completed **SUCCESS** including the new lifecycle edge focal and existing regressions.

**4C evidence:** [GitHub Actions 41346334448](https://github.com/mercurysama/Flujo/actions/runs/41346334448) — completed **SUCCESS** including the new real-clocks/pause focal, 4B focal and existing regressions.

**Assessment:** **Phase 4 core runtime = AUTOMATED ACCEPTANCE PASSED**, not overall release acceptance. Remaining formal gate is grouped human review and optional negative/error-boundary hardening; don't attribute UI or Android acceptance to headless success.

**Next micro-lot:** phase 5 targeted gaps (event delivery, invalid transition diagnostics) without large cross-phase refactors. Preserve this file as a recovery marker; see the FSM roadmap for phase numbering.

**Skill lesson:** tests that assert `manual tick` do not prove the engine's scheduling, pause, or signal-reentrancy behavior. Preserve independent acceptance matrices.
