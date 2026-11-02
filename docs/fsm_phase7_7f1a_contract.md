# Potok 7F-1A — Add commands by FSM phase (frozen scope)

**Date:** 2026-11-02. **Branch:** `feature/fsm-runtime-flow-flusso`. **Green baseline:** `7678bff96587851863671914f92a327b670f25cf`, [CI 41408095389](https://github.com/mercurysama/Flujo/actions/runs/41408095389) **SUCCESS (59 steps)**. **Parent audit:** [7E-4B](fsm_phase7_7e4b_gap_audit.md), 25 human cases PENDING.

## Single narrow operation

Add a block from the **existing integrated/external editor authoring catalog** into exactly one authored state phase, identified exclusively by `controller + machine_id + state_id + phase`, where `phase` is the strict canonical StringName `&"enter"`, `&"update"` or `&"exit"`. Public API:

```gdscript
func add_fsm_phase_block_by_authoring_id(
    controller: PVController, machine_id: String, state_id: String,
    phase: StringName, authoring_id: String
) -> String
```

Successful call returns the new block's stable ID, performs **one** `EditorUndoRedoManager` action owned by `PVController`, and appends the resource to exactly one target list:
- `enter` → `FlowStateDefinition.enter_blocks`
- `update` → inherited `FlowBlockContainer.blocks`
- `exit` → `FlowStateDefinition.exit_blocks`.

The *same existing* `_create_authoring_block(authoring_id)` and `_first_available_block_display_name(target,block)` policy as Ready is reused; there is **no direct `add_ready_block` call** and no new factory, schema or runtime behavior.

## Required invariants / focal RED → GREEN

1. If controller is stale/null, graph is not editable schema-3, machine or state does not belong to that graph/machine, phase is anything other than the exact supported values, authoring ID is empty/unknown/stale, or catalog factory rejects creation, return `""`, create **zero Undo actions**, mutate nothing, do not fall back to a different type. Validate owner and phase **before** asking the catalog to instantiate.
2. Preserve existing array order, deliberate null slots and all existing block objects/IDs. A successful append adds a *fresh* ID; a second Add chooses a stable unique visible name **within the selected phase**, without renaming other phases or resources.
3. Build a detached candidate (`FlowStateDefinition.duplicate(false)`, `FlowStateMachineDefinition.duplicate(false)`, `_fsm_structure_candidate`) and validate **before writing** the real resource, using the same no-new-errors policy as existing FSM commands. A rejected candidate yields no undo step and leaves every original field untouched.
4. Do/Undo/Redo replace **only that phase property** on the original state Resource, preserving machine/state instances, IDs, sibling phases, transition identities and graph order. Undo removes just the new block; Redo restores the exact same FlowBlock instance and ID, without calling the catalog again. Notify editor and refresh graph diagnostics through existing command paths. Event authoring and runtime unaffected.
5. Test real `FlowGraphEditorCommands` and `EditorUndoRedoManager` with valid machine/state, deliberately placed null slot, an unmodified sibling state, two consecutive Add operations, repeated Undo/Redo, invalid IDs/phase, stale authoring catalog entry, and integrated **plus external** (`tests/fixtures/manual_block_sdk`) authoring ID; before adding production code, run test-first to document missing API.
6. Wire exactly one timeout-bounded Godot 4.7.2 `--headless --editor --path . --script tests/editor/flow_fsm_phase_add_commands_test.gd` to the unchanged 59-step CI; preserve existing `flow_external_block_command_add_test.gd`, Ready UI, FSM structural, 7E persistence and validator tests.

## Explicitly deferred

No phase UI buttons or selecting/configuring phase blocks in this lot (7F-1B/1C1); no Move/Duplicate/Delete/transfer across phases (7F-1C2), no end-to-end UI persist (7F-1D); no Android manual approval (7F-2). Do not change `addons/vp_flujo/runtime/`, `FlowGraph`/persistent schema, `FluoDrawer`, `main`, demo, package manifest or existing tests/catalog assertions.

## Governance

Read `AGENTS.md`, Constitution, current iteration, workflow, model contract, catalog, `docs/fsm_phase7_microblocks.md`, audit 7E-4B, Ready authoring context code, `flow_graph_editor_commands.gd`, 7C structural and external Add test. Repo procedures `$flujo-baseline`, `$flujo-prove`, `$flujo-fluo-maintenance` followed remotely, not executable as standalone Skills here; no formal READY/PASA or local Fedora worktree audit. User's 🙆🏻 authorizes this independently versioned lot, not merging or release.

**Next after green checkpoint:** 7F-1B UI Add per phase, separate contract/test. Manual review 25/25 PENDING.

*Todo es Flujo; todo fluye.* 🌊
