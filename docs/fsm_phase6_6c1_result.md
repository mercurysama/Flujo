# Potok 6C-1 — bounded cross-machine cycle checkpoint

2026-11-01. Branch: `feature/fsm-runtime-flow-flusso`.

**Contract:** `9a1abd2468f3e3955a39b9f7deeeb1f6d2723850` in `docs/fsm_phase6_microblocks.md`.
**Test:** `f0bbfd62758b7136b3d489d0783717c1dc6a3add`, scene `c93a77b1926bf175cff46d8e03593bb45d359db5`.
**CI wiring:** `8c40c796f776c9d2f3d357bde229bb9bde85cc5f`.
**Result:** [Actions 41356684490](https://github.com/mercurysama/Flujo/actions/runs/41356684490) **SUCCESS**: 6C-1 focal and prior regressions.

The 6C-1 test executes a finite, repeatable A (MANUAL) → B (PHYSICS) → A → B sequence through state-enter callbacks. Requests remain deferred; a recursive B tick is ignored; only one transition occurs on each matching tick. The queue returns to zero and authored graph validation stays unchanged. **No production engine change**.

**Important boundary:** this focal does not prove chain-specific cancellation, a budget carried across multiple ticks, or independent preservation of unrelated chains. The already passing 5C `flow_fsm_queue_capacity_test` covers 256-entry global capacity, rejection and recovery, including cross-clock carryover, and remains a separate regression in this full CI. A long-lived cyclic chain may continue across ticks; no chain-local saturation policy has been introduced.

**Next 6C-2:** define explicit chain provenance, a bounded per-tick/chain budget, `request_rejected` or new chain diagnostic semantics, and cancellation of only the saturated chain. Test RED against the current implementation before introducing any change. Do not call the overall phase 6 complete, nor conflate global queue admission with a chain budget. The Potok UI and Condition Tok integration remain pending.

**Recovery:** latest code-free test checkpoint `8c40c796f776c9d2f3d357bde229bb9bde85cc5f`; compare this green CI before the next narrow lot. Todo es Flujo; todo fluye. 🌊
