# Potok 6D — Event lineage, sibling cancellation and controller isolation

**Date:** 2026-11-01. **Baseline:** `ede3eb12b8280499c4226428c203ab47d4a7cdaf`.

## Acceptance contract

This micro-lot characterizes the 6C-2 `MAX_CHAIN_HOPS=8` policy using three types of commands without expanding the public API: event-generated descendant, sibling direct request and unrelated external root. Do not reclassify all unrelated callbacks as descendants unless invoked synchronously by a transition's Exit/Enter/commit notification.

1. A MANUAL machine alternates with a PHYSICS machine using graph-defined EVENT edges. An event emitted from the first machine's `state_entered` callback inherits its causal lineage. A consumed event's selected edge carries that lineage through the commit into later callbacks. Eight hops are allowed; ninth is rejected as `event` or `direct` with `chain_budget_exceeded` according to the caller.
2. A sibling command to a PROCESS machine queued at the seventh hop must be removed when the same lineage saturates on hop eight. An independently seeded PROCESS request on that machine remains, and can commit normally.
3. A second `PVController` sharing the same authored `FlowGraph` maintains its own active states, queue and lineage. Saturation in the first must not poison an equivalent external root in the second.
4. At most one transition per matching clock; no recursive tick; event consumption remains FIFO and copied, no authored resource mutation.
5. Test before changing production; green without change means characterization, failing focal requires a small separate RED/GREEN correction.

**Out of scope:** end-to-end Tok bindings, request reason metadata, per-tick CPU budget, persistent chain IDs, cross-controller messaging, UI and Android review. Maintain a separate 6D CI focal and durable checkpoint.
