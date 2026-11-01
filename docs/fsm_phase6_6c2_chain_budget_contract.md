# Potok 6C-2 — Chain-local transition budget

Date: 2026-11-01. Branch: feature/fsm-runtime-flow-flusso. Status: approved design for a narrow RED/GREEN implementation.

## Bounded lineage

- Each accepted external direct request or event starts an independent controller-local lineage (monotonic runtime integer ID, never serialized). A condition-selected commit also creates a lineage for requests generated in its Exit/Enter/commit callbacks.
- A transition carries its selected request's lineage through synchronous Exit, Enter and transition_committed notifications. Requests/events created in these callbacks inherit the same ID and increment its hop depth. Outside callbacks, enqueue creates a fresh lineage.
- Limit: MAX_CHAIN_HOPS = 8 committed transition hops in a lineage. A hop-8 transition may complete, but attempts to enqueue hop 9 must return false and notify request_rejected(machine_id,kind,chain_budget_exceeded). They must not be queued.
- Saturation cancels only requests from this lineage still pending or in flight. Other independently seeded requests, even to the same machine, remain eligible on their ordinary clock. No system-wide stop, no direct recursive transition.
- Existing global MAX_PENDING_REQUESTS=256 remains a separate admission capacity guard with code queue_full. No payload or serialized schema format changes; public requests remain binary-success APIs.
- A committed request's lineage applies to events as well as direct requests so emitting an event from a transition cannot bypass the budget. Unmatched events consume normally and do not create transition hops.
- If a later independent external request initiates new work, that is a new lineage even if its machine IDs match a previously rejected chain. Bound lineage memory to the current tick and current pending packets; do not retain unlimited historical IDs.

## Acceptance

A finite A(MANUAL) -> B(PHYSICS) -> A ... cycle, generated from state_entered, stops after 8 committed transitions with one chain_budget_exceeded diagnostic, no pending cascade, and remains responsive. An unrelated external request queued before the overflow still commits on its own clock; existing 5A–6C1 tests must stay green. No visual/Android claims or full phase-6 closure.

Recovery: contract commit, independent failing regression commit, minimal runtime fix, CI verification, docs handoff. The separate authored Tok UI debt of phase 5 remains open.
