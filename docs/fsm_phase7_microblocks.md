# Potok Phase 7 — Visual authoring microblocks

**Date:** 2026-11-01. **Branch:** `feature/fsm-runtime-flow-flusso`. **Authority:** original `docs/fsm_implementation_plan.md` phase 7 (nine items), stage contracts and focused regression evidence. The passed phase-6 runtime must not be casually modified by UI scaffolding.

## 7A — Contract and pure view model: AUTOMATED PASS

- [7A contract](fsm_phase7_7a_contract.md), [RED/GREEN result](fsm_phase7_7a_result.md).
- Inspector **State Machines** already exists; Fluo and dock share `FlowGraphInspectorProperty`. Added editor-only `FlowFSMEditorProjection` to represent machine, authored states, phase block lists and transition properties by stable ID with no mutation.
- RED [Actions 41364627238](https://github.com/mercurysama/Flujo/actions/runs/41364627238); GREEN [Actions 41364696760](https://github.com/mercurysama/Flujo/actions/runs/41364696760) includes older FSM regressions.
- **Not interactive yet:** no machine activation wired to Fluo, no new Flow state editor, no Flusso property form, no Undo/Redo for state edits, no Condition Tok bridge.

## 7B — Navigate from existing machine list to Fluo Flow hierarchy

- First define activation and focus/keyboard contract. Use `FlowGraphEditorCommands.Collection.STATE_MACHINES`, actual `PVController`, stable machine IDs, `FluoDrawer` and `FlowGraphInspectorProperty` only.
- Connect Enter/double-click on machine row, show selected machine heading and authored state list (or `Empty`); present initial marker and selected state's Enter/Update/Exit phase names from `FlowFSMEditorProjection`.
- Test selection stability on reorder, Escape/back returns to originating machine row, no duplicate `Blocks` in Inspector, missing controller recovery and persistence of existing process/variable Fluo flows.
- No model mutation, no state creation, no conditions UI; headless editor focal + full regression CI.

## 7C — Flusso machine/state/transition forms and atomic commands

- Add/rename/reorder/duplicate/delete with graph candidate validation and `EditorUndoRedoManager`. Machine/state properties, initial-state ID, transition event/condition/priority. Deletion dependency preview and true Cancel. Persist/reopen and verify IDs.
- Make internal resources immutable until commit; authored graph validation must be green. Do not implement unsafe resource surgery in view callbacks.

## 7D — Condition Tok # and typed event payload adapters

- Resolve phase-5 debt explicitly, integrating `FlowConditionEditor` / `FlowChipFieldSchema` with Potok condition properties and later typed event-payload expression context. Test Cancel, Escape, roundtrip and invalid Bool sources without graph mutation.

## 7E — Input, touch and final acceptance

- Keyboard focus tree (Enter, arrows, PageUp/PageDown, Ctrl/Alt variations), zoom/scroll and Fluo Escape hierarchy; Android portrait/landscape touch and focus tests manually at end as requested.
- Save scene/reopen IDs, block phase order, condition tokens, transition persistence and repeated Undo/Redo cycles. Automated editor CI is not equivalent to human visual acceptance.

**Next approved micro-lot on 🙆🏻: 7B.** Recheck latest HEAD, preserve 7A baseline, write a narrow activation contract before implementation.

Todo es Flujo; todo fluye. 🌊

## 7B — Existing Inspector → Fluo machine navigation: AUTOMATED PASS

- Contract `70360ab9069e0d34f90088118966c834505ea57d`, editor focal `e902c52a2de9f25192d8fa05a087471958743ceb`, CI `7c4fa7ec9ddd1b0be64f589f8f5c45c0619ea3df`. [RED 41365606656](https://github.com/mercurysama/Flujo/actions/runs/41365606656) expected.
- Native State Machines activation via existing `PVControllerInspectorPlugin` and `FluoDrawer.open_container`: `d9f5eb66f7cad98e1754a7a121dfb71747451cf5`; Flow state tree/Enter-Update-Exit projection `1bbfb56dc735c242ca70e2729f58dd04f442b1be`; Escape/keyboard routing `ba8fb88caecb0001b9f2e780a2bf808bb89ce2f9`; reorder/controller-removal focal `1956397ce8cda4d74ea1153afae389611518222c`.
- [Full GREEN 41365966187](https://github.com/mercurysama/Flujo/actions/runs/41365966187) includes all prior Potok/runtime regressions. [7B result](fsm_phase7_7b_result.md) explains exact acceptance.
- No new Inspector list, no authored graph mutation, existing Ready editor remains operational. **Not yet editable:** Flusso state/machine fields, phase blocks, transitions, Undo/Redo, Condition Tok, or Android.
- **Next 7C-1:** one recoverable lot for machine/state scalar property commands and Flusso integration. Follow with 7C-2 transition editing and dependency-aware actions, 7D Tok condition/payload authoring, 7E keyboard/touch/persistence verification.
