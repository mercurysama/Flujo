# Potok 6C-2 — Chain lineage saturation, RED/GREEN checkpoint

**Date:** 2026-11-01. **Branch:** `feature/fsm-runtime-flow-flusso`.

**Scope:** Bound transition chains inherited through synchronous transition callbacks; do not stop unrelated machines or controllers, alter graph schema, or substitute this for the separate 256-entry queue limit.

**Contract commit:** `27fc4eda2df870dc84eb946c1c294f5c03b0b21b` — `docs/fsm_phase6_6c2_chain_budget_contract.md`. The runtime introduces a per-controller lineage ID and `MAX_CHAIN_HOPS = 8`. An external admitted request/event starts its own lineage; a new request/event emitted from a transition's Exit/Enter/committed callbacks inherits it, with the next hop number. A condition-initiated transition starts a lineage for its descendants. After the eighth committed hop, another inherited enqueue returns `false`, emits `request_rejected(...,&"chain_budget_exceeded")` and blocks further pending descendants of that lineage. Unrelated requests remain queued and functional. No user-facing model ID or serialized format change.

**RED test:** `dbf00cc72626054d90ec165e3219cf7d672b4d46` adds `tests/runtime/flow_fsm_chain_budget_test.gd`, scene commit `1c767018fcd03426576009dc0e7e3e620d3fe473`, CI step `f49181a87d071e173f49a5ce595696956dd79a16`. [GitHub Actions 41357182605](https://github.com/mercurysama/Flujo/actions/runs/41357182605) **FAIL**, as intended, because the original code had no lineage cap. The new test seeds an independent third-machine request and an alternating A → B → A cycle.

**GREEN runtime:** commit `612f57bf23cf47e3723f8e3f031300eed4fe454f` changes `FlowFSMRuntime` only. It adds controller-local lineage metadata to queued requests, carries the selected lineage during transition lifecycle callbacks, and filters blocked lineage packets while preserving others. It extends existing `request_rejected` with `chain_budget_exceeded`. [GitHub Actions 41357280685](https://github.com/mercurysama/Flujo/actions/runs/41357280685) **SUCCESS** for 6C-2 and all existing Godot 4.7.2 FSM, model, Ready and navigation regression steps.

**Verified by focal:** eight committed alternating cross-clock transitions; exactly one ninth-hop rejection diagnostic; saturation leaves only the independent third-machine request queued; further A/B ticks cannot resurrect the stopped lineage; the unrelated root commits on its matching clock; authored graph stays unchanged.

**Scope limits:** This does *not* implement time-based/per-tick CPU budgets, globally identify causal relations outside synchronous lifecycle callbacks, guarantee all event-provenance cases have separate focals, or provide Potok editor UI and full Android acceptance. It is a deterministic **chain-hop bound**, not the completion of all phase-6 criteria. The phase-5 Condition Tok visual binding is still pending.

**Next micro-lot 6D:** independently characterize event-callback lineage, saturation with multiple siblings, and per-controller isolation, then audit phase-6 plan's separate reason/payload for direct requests and per-tick budgets. Do not silently mark phase 6 complete based on this green test.

**Recovery:** read this file, `docs/fsm_phase6_microblocks.md`, `docs/fsm_phase6_6c2_chain_budget_contract.md` and the CI runs above before adding code. Preserve separate contract, failing-test, implementation and evidence commits. Todo es Flujo; todo fluye. 🌊
