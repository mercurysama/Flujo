# Potok 7C-2B — Structural state and transition authoring, RED/GREEN checkpoint

**Date:** 2026-11-01 (GitHub Actions timestamps UTC 2026-11-02). **Branch:** `feature/fsm-runtime-flow-flusso`.

**Outcome: AUTOMATED PASS.** Both dedicated Godot 4.7.2 headless-editor tests and the complete previous FSM, model, Ready, navigation, 7A–7C-2A regressions passed in [GitHub Actions 41374189278](https://github.com/mercurysama/Flujo/actions/runs/41374189278). This is not human visual/Android validation.

## Contract and code

- Contract `d46a9482d3fb90e2abfcb3f887a12b08e5058f50` in [7C-2B contract](fsm_phase7_7c2b_contract.md).
- Structural commands test `0ba60a18fcbd33c57f004cf706c991b81a73494a`; workflow step `ae9f04cbabad9eaffe58023f794548d625e7f817`. [RED 41373165948](https://github.com/mercurysama/Flujo/actions/runs/41373165948): the requested state and transition structural commands were absent.
- State operations `682c36e304372d7d3f0e88665775a5d36def31be`: add, duplicate, move and delete via stable machine/state IDs. Duplicated state, phase blocks and edge IDs are fresh; outgoing self-loop retargets the duplicated state. Removing a state with **any inbound transition from a survivor**, including disabled edges, is rejected. Deleting an initial state selects the earliest enabled survivor, or clears the initial ID if it was the last state.
- Edge operations `1df74115e2e02aea8c352393607c23b594011002`: add EVENT edge with explicit starter event name `event` and valid self-target, duplicate/move/delete only existing edges of their owning state. Validation never mutates the live graph before commit; each action uses `EditorUndoRedoManager`, and Undo/Redo restores exact original identities and order.
- Model test fixture ordering was corrected separately in `25bd6d96e675d73066d6b7ed9d067fc25f11e1a5` and `34b35692163e64817eeec38816985c41405b92a8` (the original B state was at position 1 after a state move and redo). The improved test `56600e9152673835b2e4e6029cb4d396f458fe4a` also verifies that disabled incoming edges block unsafe state deletion.
- Fluo editor test `f165f75164897ccf8464fd6110f34a616e6cf340`, separate CI step `c27b56c5b377f8f18103b614354bbc4cdcc62d92`. UI work: structural action slots and cancellation context `bf8d49eedbebfffa732fe59232399da2f6f670c1`, native Flow state/edge action buttons `0b8b0163cee7ca665af31581d8e9b72106ade628`, dependency-aware confirmation with true **Cancel** `8d60f953384903ee802d393356b8c045ec8b2f8f`.
- Extra UI negative-path test `b4c31610130a425068687c6c16b4404a4bcd3663` verifies that both Cancel and window-close discard pending deletion, and a confirmation does not delete a stale state after selection changes. First-selection button state fixed in `69b67bdf0bf6a614bd8c4770b40c31250d788902`, then verified with `ae90066bcefdf63d8154d71f52287f06c35929a3`. [Full GREEN 41374189278](https://github.com/mercurysama/Flujo/actions/runs/41374189278).

## Accepted behavior

Inside the existing Inspector → Fluo → Flow/Flusso hierarchy, Potok users now have add/duplicate/move-up/move-down/delete controls for states and for transitions. These use the selected IDs, not display labels. New or duplicated entities become selected, and undo/redo preserves the saved IDs. A state with incoming edges shows an explanation instead of a misleading destructive dialog. Deleting an otherwise safe state/edge requires a dedicated `ConfirmationDialog` and the explicit **Delete** confirmation; merely opening it never edits the graph. Cancel, window-close and switching selected state before confirmation cannot perform deletion. Deleting the initial state and Undo/Redo update its reference atomically, without silently altering surviving transitions.

The model/test contract supports a true Empty state machine: first added state is its initial state, and deleting its last state makes the initial ID empty. Transition creation seeds a valid EVENT self-loop with name `event` so it can be authored further through 7C-2A controls. The view model does not create real Resources; structural changes occur only through commands.

## Remaining work and handoff

**7D next:** Condition Tok `#` visual authoring for Bool transitions; connect event payload metadata to typed expression sources. Reuse FlowConditionEditor and existing chip schemas, ensure Cancel/Escape never commits, and test resource roundtrips with Undo/Redo before claiming working input. Existing 7C-2A Bool condition source command is not a visual Tok editor.

**7E later:** full keyboard/touch/scroll, scene save/reopen, manual visual Godot and Android tests. Human review is intentionally batched. Global per-frame CPU-time guarantees and unrelated phase-6 hard SLA were not added. No FSM runtime, graph schema, or serialized version changed in 7C-2B.

**Recovery:** read this file, `docs/fsm_phase7_7c2b_contract.md`, and `docs/fsm_phase7_microblocks.md`. Last code/test commit `ae90066bcefdf63d8154d71f52287f06c35929a3` passed full [CI 41374189278](https://github.com/mercurysama/Flujo/actions/runs/41374189278). Subsequent doc-only commits may have new CI runs; do not misattribute them to the tested code if still pending.

Todo es Flujo; todo fluye. 🌊
