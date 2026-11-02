# Potok 7C-1 — Atomic machine/state properties in Flusso

Date: 2026-11-01. Branch `feature/fsm-runtime-flow-flusso`. Baseline `122c801d3224e8995522fee32972bba88ae11610`.

## One narrow authoring contract

- Reuse the existing Fluo-owned `FlowGraphInspectorProperty`, `FlowGraphEditorCommands` and `EditorUndoRedoManager`; **no separate editor model**, serialized schema or runtime change.
- Explicit machine fields: `display_name: String`, `enabled: bool`, `auto_start: bool`, `tick_mode: TickMode`, `user_note: String`, `initial_state_id: String`. Explicit state fields: `display_name: String`, `enabled: bool`, `user_note: String`. The legacy `FlowStateDefinition.is_initial` is not editable: only the owning machine's `initial_state_id` selects the initial state.
- Names must contain nonwhitespace characters; notes are plain strings. `tick_mode` must be an exact enum member; an `initial_state_id` must identify an **enabled** state owned by the same machine; empty initial ID is allowed **only when the machine has no states**. No changing stable IDs or state ownership.
- The command resolves machine and state by stable IDs. It constructs a **detached candidate graph** with shallow duplicate machine/state resources, then validates with `FlowGraphValidator` before a commit; no live graph mutation during validation. If candidate introduces a new ERROR relative to baseline, reject without action, notify `_last_diagnostics`. Unchanged values, wrong types, missing IDs and unsupported fields are no-ops. If the baseline contains unrelated diagnostics, preserve existing errors; new candidate errors must not be introduced.
- For an accepted change, call `EditorUndoRedoManager.create_action(... controller ...)` and `add_do_method/add_undo_method` on the original model resource, with `controller.notify_property_list_changed()`, refresh diagnostics and `changed` signal. Undo/redo must restore exact value and IDs; no graph replacement or model copy assigned on commit.
- In Fluo Potok Flow keep the state list and three read-only phase rows from 7B, and render a **Flusso** machine property section and a selected-state section with native, keyboard-accessible controls. Commit text only on explicit `text_submitted` (Enter), never on each keystroke or implicit focus exit; bool/enum inputs commit on explicit toggle/change. Initial-state selector uses stable IDs in item metadata. Controls display the authoritative model value after rebuild; no changes when the user cancels a pending text edit by Escape. Name/note drafts must be separate from model until commit.
- Selection remains stable by IDs through Undo/Redo and reorder, and changing controllers clears pending buffers. Existing Ready editor, Navigator, Inspector State Machines list and Escape behavior must remain intact.

## Acceptance

A headless editor focal verifies legitimate scalar machine/state edits, invalid enum and foreign/disabled initial-state rejection, no-op/unknown property rejection, Undo/Redo for machine and state, live Flusso control wiring, and authoring graph validity. Add a separate CI step. Contract → failing test → minimal commands → Flusso controls → all regression checks → checkpoint docs.

**Not in 7C-1:** state creation/deletion/reordering, transitions, dependency-aware deletion, phase block edits, Condition Tok `#`, payload binding or human Android visual review. Follow-on 7C-2/7D/7E separate.
