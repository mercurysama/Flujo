# Potok 7B — Inspector to Fluo state navigation, RED/GREEN checkpoint

**Date:** 2026-11-01 (CI timestamp UTC 2026-11-02). **Branch:** `feature/fsm-runtime-flow-flusso`.

**Contract:** `70360ab9069e0d34f90088118966c834505ea57d`, [7B navigation contract](fsm_phase7_7b_contract.md). Existing `State Machines` Inspector selection must activate the already mounted `FluoDrawer` via the normal `PVControllerInspectorPlugin` and `plugin.gd` relay, using the stable machine ID, not a translated name or a second Inspector list.

**RED test:** `e902c52a2de9f25192d8fa05a087471958743ceb`, `tests/editor/flow_fsm_fluo_navigation_test.gd`, workflow step `7c4fa7ec9ddd1b0be64f589f8f5c45c0619ea3df`. [GitHub Actions 41365606656](https://github.com/mercurysama/Flujo/actions/runs/41365606656) **FAIL** as expected: no Potok tree and no `navigate_potok_machine` method existed. The test uses Godot's headless editor script environment, rather than claiming native UI/touch review.

**Implementation checkpoints:**
- `d9f5eb66f7cad98e1754a7a121dfb71747451cf5`: extend Inspector native item activation to `Collection.STATE_MACHINES`, using the existing `schema_3_container_activated` and selected-controller routing. Old process/variable routes remain unchanged.
- `1bbfb56dc735c242ca70e2729f58dd04f442b1be`: render `FlowFSMEditorProjection` in the Fluo-owned `FlowGraphInspectorProperty` with a `PotokStateList`, machine header, initial state marker and a read-only `PotokStatePhases` Enter/Update/Exit hierarchy. The explicit `Empty` row is inert. State selection, next/previous state and next/previous machine retain stable IDs and avoid scene-tree lookups. Existing Inspector selection synchronization signal is reused.
- `ba8fb88caecb0001b9f2e780a2bf808bb89ce2f9`: route Ctrl+PageUp/PageDown to Potok states and plain PageUp/PageDown to Potok machines only when the Ready/Process handler doesn't apply; Escape closes Potok Fluo and requests Inspector-row focus through the established relay.
- `1956397ce8cda4d74ea1153afae389611518222c`: strengthen editor focal for reorder-by-ID stability and controller removal clearing stale views.

**Full GREEN:** [GitHub Actions 41365966187](https://github.com/mercurysama/Flujo/actions/runs/41365966187) **SUCCESS**, 7B and all previous headless FSM/model/Ready/navigation checks. The earlier implementation-only run [41365831482](https://github.com/mercurysama/Flujo/actions/runs/41365831482) also succeeded.

## Accepted scope

Inspector `State Machines` Enter/native double-click uses the preexisting activation relay; Fluo shows authored state names and three read-only phase headings in authored order. Changing machine selection preserves stable IDs; selecting another state and navigating among machines does not mutate the graph. Empty draft is a view placeholder. Escape focus return is tested by the emitted Inspector-row focus request (not a physical keyboard session). A Ready process still opens its original `ReadyProcessEditor` and never displays the Potok state list. Removing the controller clears stale Potok contents. No runtime/schema or authored resource changes.

**Not yet implemented:** live state/phase block editing, machine/state property forms in Flusso, add/delete/reorder/duplicate state/transition Undo/Redo, real dependency-aware deletion confirmation, Condition Tok `#` and event-payload-to-expression adapter, persistence roundtrip or Android human acceptance. The row relay and shortcut behavior have editor automated coverage, not manual UI certification.

**Next micro-lot 7C-1:** define and implement narrow *machine/state property editing* commands with candidate validation and atomic `EditorUndoRedoManager`; **do not** attempt all transitions, condition editing and deletion in one commit. Maintain the existing Flow tree and Flusso property patterns. Then 7C-2 transitions and dependency-aware deletion, 7D Tok bindings, 7E keyboard/touch/save-load acceptance.

**Recovery:** contract `70360ab9069e0d34f90088118966c834505ea57d`, final test `1956397ce8cda4d74ea1153afae389611518222c`, full CI `41365966187`; inspect latest HEAD and preserve the green baseline before the next lot. Todo es Flujo; todo fluye. 🌊
