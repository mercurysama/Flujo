# Potok 7F-1A — Catalog Add into authored FSM phases

**Date:** 2026-11-02. **Branch:** `feature/fsm-runtime-flow-flusso`. **Outcome:** AUTOMATED PASS; phase authoring UI and Fedora/Android manual acceptance still PENDING.

## Recoverable RED → GREEN

- Prior checkpoint `7678bff96587851863671914f92a327b670f25cf`, [CI 41408095389](https://github.com/mercurysama/Flujo/actions/runs/41408095389) **SUCCESS 59/59**.
- Frozen contract `9f4867ad9a8926875da46804ac26d48c741860e9`, [CI 41408725071](https://github.com/mercurysama/Flujo/actions/runs/41408725071) **SUCCESS 59/59**; [contract](fsm_phase7_7f1a_contract.md).
- Test-first `da2fbbe858670aa9890da8ce5e145fcf95ed82f6`, [CI 41408895454](https://github.com/mercurysama/Flujo/actions/runs/41408895454) **expected RED**: new focal compiled/executed, reported missing `add_fsm_phase_block_by_authoring_id` and exited 1; existing baseline before that focal passed. Do not label this run as green.
- Minimal editor command commit `8e31559c71e4eedd3f23d3e869cec7b950a932b4`, [**CI 41409041578**](https://github.com/mercurysama/Flujo/actions/runs/41409041578) **COMPLETED SUCCESS 60/60**, zero failed; markers include `[Flujo] Potok 7F-1A per-phase catalog Add and UndoRedo passed`, Process/Timer Ready, Fluo Drawer integration and 7C2B structural commands. All other existing FSM/editor/model/runtime/catalog/whitespace tests remained green.

## Command and proof

- `addons/vp_flujo/editor/flow_graph_editor_commands.gd`: `add_fsm_phase_block_by_authoring_id(controller, machine_id, state_id, phase, authoring_id) -> String` strictly maps `&"enter"` to `enter_blocks`, `&"update"` to inherited `blocks`, and `&"exit"` to `exit_blocks`. It resolves exact machine/state ownership and editable schema 3 before invoking the existing authoring catalog; rejects invalid phase/owner/ID without fallback or history writes.
- Reuses existing integrated/external factory `_create_authoring_block` and per-target-array naming `_first_available_block_display_name`. Does **not** call `add_ready_block`: Ready Process `blocks` is a different ownership context.
- Detached state/machine candidate via `duplicate(false)` and `_fsm_structure_candidate` validates before any live mutation. Exactly one UndoRedo action writes **only** the selected array, emits change/diagnostics, keeps all earlier block objects/IDs, order and deliberate null positions. Undo restores previous array; Redo reinstates the same new resource/ID without factory calls; adjacent phases/states/Ready remain untouched.
- `tests/editor/flow_fsm_phase_add_commands_test.gd`: real EditorUndoRedoManager, injected counting catalog with `tests/fixtures/manual_block_sdk` external ID, integrated Print, separate sibling and other machine, deliberate null, existing Update, Ready Process; checks wrong owner/phase and stale authoring ID, no-op Undo history, phase-local unique names, independent Enter/Update/Exit Add, Undo/Redo resource/ID stability and graph diagnostics. One timeout-bounded headless Godot 4.7.2 CI step added.
- Exact implementation diff versus prior checkpoint: contract, new focal, 3 workflow lines and 76 added lines in existing editor commands; **no runtime, schema, FluoDrawer, Potok UI, catalog assertions, existing test modifications, main, demo or release**.

## Remaining gates and handoff

The API is ready for **7F-1B**, adding per-phase `Add` controls inside native Potok Flow using the existing catalog and separate UI tests. `_render_potok_state_phases` still draws only labels; Flusso block editing (7F-1C1), structural move/delete (7F-1C2), end-to-end UI save/runtime (7F-1D), and **25/25 manual tests PENDING** (7F-2) are not closed.

Repository `$flujo-baseline`, `$flujo-prove` and `$flujo-fluo-maintenance` procedures read/applied through GitHub baseline and CI; not invoked as standalone local Skills, no local Fedora worktree audit or formal READY/PASA, no physical Android/desktop review.

*Todo es Flujo; todo fluye.* 🌊
