# Potok 6G — Per-machine tick work budget, RED/GREEN checkpoint

**Date:** 2026-11-01. **Branch:** `feature/fsm-runtime-flow-flusso`.

**Contract:** `76057049fcb0b5d80e08919cecf363754ca147b0`, `docs/fsm_phase6_6g_work_budget_contract.md`. A `FlowFSMRuntime` matching-clock tick may deliver no more than `MAX_REQUESTS_PER_MACHINE_TICK = 32` previously admitted direct/event packets **per active machine**. Additional packets are retained, not rejected. Other machines receive their own independent budget and cannot be starved by the flooded machine. `work_budget_deferred(machine_id,deferred_count)` notifies once per affected matching-clock machine per tick, after its Update and before event consumption; it does not mean the packet was rejected.

**RED focal:** test `387ffded2840665a706040d94592abb37d0d087f`, scene `2299c301229580582b1a04dd16727e4c8d640b72`, workflow `84ef9bdc6e8ca56350f97cf2c7ddc8b92ab2b796`. [GitHub Actions 41360868794](https://github.com/mercurysama/Flujo/actions/runs/41360868794) **FAIL**, expected because the runtime did not yet have the budget or signal.

**GREEN runtime:** `c22ef8fd2693b2356948bfb6b3363ecdaea1b707`. The scheduler partitions the snapshot in original admission order into deliverable (max 32 for each matching-clock machine) and carryover (other clock plus same-clock surplus). Both carryover classes count toward `_inflight_reserved`, so callback-generated commands cannot overfill the 256-packet queue. The selected direct/event packet retains its causal lineage; the old priority rules apply among packets in the current batch. Every machine still executes Update once and commits at most one transition per matching tick.

**Compatibility adjustments:** `36095a4e024a3e85fbe453d9fbc6f43aebf9efab` updates 5G admission diagnostic expectations; `46f4f82fee34d0e24efb2d7b8d35cc8fd8c3eb00` updates 5C cross-clock capacity expectations. Both retain their original saturation assertions and now explicitly verify 256 events drain over eight 32-packet PHYSICS ticks without loss. The earlier 6C-1 cyclic characterization test did *not* actually contain a burst-drain assertion and therefore required no modification; its original test remains intact.

**Full GREEN:** [GitHub Actions 41361104238](https://github.com/mercurysama/Flujo/actions/runs/41361104238) **SUCCESS**, including 6G, the adjusted 5G/5C tests, all 6A–6F-1 Potok focals, model/Ready/navigation baselines and other workflow regressions.

## Directly verified

- First MANUAL tick delivers A's first 32 of 40 unmatched FIFO events; the remaining eight plus its callback-created event wait until the next MANUAL tick.
- Independent MANUAL machine B consumes its event and commits its authored transition on the first tick despite A's flood. An unrelated PHYSICS packet waits for its own clock.
- Exactly one `work_budget_deferred(A,8)` notification occurs; none after the retained work drains. Accepted packet counts stay exact and no old or callback-created events disappear.
- Prior 256-entry queue admission and `queue_full` diagnostics remain enforced even with retained same-clock packets. Eight-hop chain policy is still separate and unchanged.
- No authored FlowGraph/model schema, serialization, public request signature, snapshot, or UI changes.

## Limits / handoff

This is a **per-machine packet-delivery budget**, not a time-based CPU/instruction budget or a hard global cap across an arbitrary number of machines. Each machine's queued packets are processed in FIFO *batches*. A direct request located beyond the current 32-item batch may be selected only in a later tick; condition fallback examines the current batch, not future packets. Do not claim exact global priority across not-yet-processed packets. A strict cross-machine total work/CPU budget and adverse condition-under-backlog tests should be assessed separately if required for phase-6 final acceptance.

**Next micro-lot 6H:** negative/fault-injection and scene-tree permutation tests, then phase-6 acceptance audit. Phase-5 Condition Tok authoring, event payload-to-expression binding, editor Potok UI and human Android review still await later dedicated work.

**Recovery:** implementation `c22ef8fd2693b2356948bfb6b3363ecdaea1b707`, compatibility tests `36095a4e024a3e85fbe453d9fbc6f43aebf9efab` and `46f4f82fee34d0e24efb2d7b8d35cc8fd8c3eb00`, full CI `41361104238`. Respect the separate RED and GREEN commits.

Todo es Flujo; todo fluye. 🌊
