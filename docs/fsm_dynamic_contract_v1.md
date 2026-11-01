# FLU-FSM-003 — Runtime-only dynamic-state registry

**Date:** 2026-11-01. Scope: registration, lookup, change and removal of state aliases from authored templates. No FlowGraph schema change.

## Contracts

- A dynamic state has a valid generated 32-character runtime ID, a same-machine template state ID, a lifespan (EPHEMERAL, SESSION, PERSISTENT), and a cloned JSON-safe data dictionary.
- Per-controller registries remain private; never append dynamic states to FlowStateMachineDefinition.states.
- Registration requires a running instance, valid template, collision-free runtime ID and a quota of 128 dynamic states per machine.
- APIs has_state, request_transition and change_state accept both authored and dynamic IDs. Template supplies Enter/Update/Exit and authored transitions.
- Removing an active dynamic state requires an explicit distinct valid fallback outside a tick. Transition exits old and enters fallback before registry removal.
- Removing an inactive alias purges pending direct requests that target it. An active removal attempted during a tick fails without mutation.
- get_dynamic_state_data gives a deep copy. Data writes validate allowed scalar/Array/Dictionary types, size and nesting, rejecting live Godot Objects and Callables.
- EPHEMERAL is not serializable; SESSION lasts until controller teardown; PERSISTENT is eligible for later explicit snapshots. No snapshot is claimed by this step.
- On stop, all dynamic states are cleared. Controller instances never share their registries even with a shared graph.
- Tests must cover ID uniqueness, foreign templates, mutation independence, active fallback, queued requests, and controller isolation.

**Deferred:** serializable snapshots, disk I/O, UI, and debugger.

Todo es Flujo; todo fluye. 🌊