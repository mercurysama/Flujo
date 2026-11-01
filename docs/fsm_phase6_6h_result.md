# Potok 6H — Negative routing and shutdown reentrancy, RED/GREEN checkpoint

**Date:** 2026-11-01. **Branch:** `feature/fsm-runtime-flow-flusso`.

**Contract:** `1cf700c783f4e38bbb2eb0db45788d8eb39d26cd`; [6H contract](fsm_phase6_6h_contract.md).

### Test-only implementation

- Negative routing/scene order focal `5857efa96e728de08aabbb22656b53f3d449f875`, scene `94b8a942e793adac9e762cddacb4ce2094ee3e23`.
- Reentrant shutdown focal `efe478c3517fcc9bfff1fde7001292aa946299f8`, scene `58832cf2792b3b17bd010612e1ed1a1b757bbea2`.
- Separate CI steps `28ea30ceb7441ed90e3aa1d6612e009494c0da66`.
- [Actions 41363216050](https://github.com/mercurysama/Flujo/actions/runs/41363216050) **FAIL as expected**: negative routing passed, while shutdown produced duplicate `A1 Exit`, duplicate `machine_stopped` and failed repeated-stop idempotence assertions. The failure was inspected in the job logs; it was not a parser error.

### Runtime correction

- `e494bcf39d27aa1ab25b6c31688ceb1287a98887` adds only a controller-local `_stopping` flag to `FlowFSMRuntime.stop()`, set during shutdown and reset after cleanup. Calls to `stop()` from Exit/Stopped observers while the runtime is already stopping now return immediately.
- **Full GREEN:** [Actions 41363328505](https://github.com/mercurysama/Flujo/actions/runs/41363328505) **SUCCESS**: 6H-1, 6H-2, all earlier Potok FSM tests and the model/Ready/navigation and other regressions.

### Verified

1. Enabled but `auto_start=false`, disabled and unknown machines reject **direct and event** admissions with `invalid_machine`. A state ID belonging to a different machine is `invalid_target`. Exactly one diagnostic per refused call; neither controller queue is mutated.
2. Two controllers share the same authored `FlowGraph` safely. Scene-tree sibling reordering does not alter identity-based routing or either controller's active states; requests in one controller cannot transition the other.
3. A direct transition's committed callback may request `stop()`; the call defers to the end of the current tick, clears cross-clock pending requests, exits each active state exactly once, and emits one `machine_stopped` per machine.
4. A `state_exited` callback emitted by the shutdown itself may call `stop()` again without nested shutdown, duplicate lifecycle notifications or corruption. A second independent controller remains live.
5. `FlowGraph` stays read-only. No schema, user-facing API, serialization, editor or Android changes.

### Scope / recovery

This tests disabled/unstarted destinations, **not** deletion of an authored machine at runtime (there is no supported operation for that). The shutdown guard does not newly specify callback-generated requests during the teardown window; they are cleared when stopping. There is still no hard wall-clock CPU/instruction budget or global cross-machine count per frame, only the 6G per-machine packet budget, 5C global queue cap and 6C-2 lineage-hop limit.

Next: read the separate phase-6 acceptance audit and make a conscious decision on any remaining global budget or negative fault-injection expansion before moving to editor-facing Potok work. Phase-5 Condition Tok #, event-payload-to-expression and phase-7 UI/Android work are not completed by this micro-lot.

**Recovery:** use runtime commit `e494bcf39d27aa1ab25b6c31688ceb1287a98887` and successful CI `41363328505` as verified pre-documentation baseline.

Todo es Flujo; todo fluye. 🌊
