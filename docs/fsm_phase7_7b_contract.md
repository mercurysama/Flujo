# Potok 7B — Stable-ID Inspector activation and Fluo Flow state navigation

Date: 2026-11-01. Branch `feature/fsm-runtime-flow-flusso`. Baseline `6a8252959faa49fccf0a2045b27c1d9032d025c0`.

## Contract

- Extend the existing schema-3 Inspector `State Machines` ItemList activation path (Enter or native double-click): `FlowGraphInspectorProperty.schema_3_container_activated(controller, STATE_MACHINES, machine_id)` → existing `PVControllerInspectorPlugin` relay → existing `plugin.gd._on_fluo_container_open_requested` → `FluoDrawer.open_container`. No second Inspector row or standalone Potok overlay.
- Use `FlowFSMEditorProjection.present(graph,machine_id)` inside the *existing Fluo-owned* `FlowGraphInspectorProperty`; render named `PotokStateList` and a read-only phase hierarchy `PotokStatePhases` (Enter, Update, Exit). State rows use immutable internal IDs and initial-state badge; Empty is an inert placeholder. No graph/model/schema writes.
- Maintain selected state by ID when graph entries reorder; if selected ID is removed, choose the first existing state or Empty draft. Changing machine/controller clears child-state selection. Do not confuse equal display names.
- In Potok Flow, Up/Down native ItemList selection and Ctrl+PageUp/PageDown step between state IDs; plain PageUp/PageDown navigates **machines** by authored collection order, syncing Inspector selection through existing `schema_3_container_navigation_changed` and not scene-tree order. The process/block paths retain their existing shortcuts.
- Escape from Potok Fluo closes the drawer and requests Inspector list focus for the same machine stable ID, using the established `schema_3_variable_list_focus_requested` relay. Do not consume Escape from an unrelated editor. No new window or duplicate `Blocks` Inspector control.
- If the controller is missing, machine ID stale or graph invalid, renderer shows a brief safe message and emits no mutation; closing or controller swap clears navigation.
- HEADLESS EDITOR ACCEPTANCE: Inspector activation signal contains the correct enum/machine ID and opens the existing Fluo surface; state and three-phase lists reflect authored ordering; navigation sync/escape focus; Empty/missing are inert; original process/variable Fluo regression survives. Drive tests from an editor Script (`--headless --editor --script`) and keep a separate workflow step.
- **Out of scope 7B:** changing machine/state properties, state/transition create/remove/rename, Undo/Redo actions, Condition Tok `#` authoring and payload-to-expression context, Android touch/manual validation; these are independent 7C–7E lots.

Recovery: contract → RED focal → minimal UI implementation → full CI → handoff; do not call 7B complete from a code-only push.
