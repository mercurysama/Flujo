# Potok 7F-1B — Native per-phase Flow Add actions and stable block selection

**Date:** 2026-11-02. **Branch:** `feature/fsm-runtime-flow-flusso`. **Status:** AUTOMATED PASS; still **not** visual phase-7 approval.

## Exact checkpoints and tests

- Prior green checkpoint `887593e3348c728a186e6afc8cded8db083279b8`, [CI 41409492088](https://github.com/mercurysama/Flujo/actions/runs/41409492088) **SUCCESS 60/60**.
- Contract `731a8037afc1840516306b2ecb32fbdbe7247318`, [CI 41410787296](https://github.com/mercurysama/Flujo/actions/runs/41410787296) **SUCCESS 60/60**. [Frozen spec](fsm_phase7_7f1b_contract.md).
- New focal and workflow `3fb9b1e849e0f405d15dd18a7ad17b9c4ab0cb33`: [**before-fix CI 41410970019**](https://github.com/mercurysama/Flujo/actions/runs/41410970019) **FAILURE**. The focal emitted three **intended missing native lists/authoring actions** assertions (Enter/Update/Exit), but its first version then dereferenced absent UI, causing a **GDScript runtime error and 100-second timeout (exit 124)**. This is **not** a clean isolated RED or a PASS; it established the missing UI, and the test harness was guarded before green validation.
- Editor implementation + safe test-first guard `8912287441d352339a4b93aaa7675fdf3967a932`; [**CI 41411425281**](https://github.com/mercurysama/Flujo/actions/runs/41411425281) **COMPLETED SUCCESS, all 61/61 successful workflow steps, zero failed**. Explicit markers include `[Flujo] Potok 7F-1B native three-phase Add and Flow selection passed`, `[Flujo] Potok 7F-1A per-phase catalog Add and UndoRedo passed`, `[Flujo] Potok 7E-2C UndoRedo focus, selection and stale callbacks passed`, and `[Flujo] Fluo drawer integration test passed`. Existing Ready, keyboard, state/transition structural, Revertir, Tok, scene roundtrip and runtime suites stayed green.

## Editor behavior

- In **the one existing `FluoFlowEditor`**, `_render_potok_state_phases` now shows native `ItemList` and catalog **Add** action row for each selected state's `Enter`, `Update`, `Exit`. Labels `PotokPhaseEnter` etc. remain for compatibility. Named lists `PotokPhaseEnterBlocksList`, `PotokPhaseUpdateBlocksList`, `PotokPhaseExitBlocksList`; matching `PotokPhase*AddActions` `HFlowContainer` widgets respond to narrow layouts. Each button is a native focusable `Button`, has an accessible `Add <catalog display name>` text, preserves `authoring_id` and phase metadata, and routes to the **7F-1A strict owner/phase command**.
- The catalog snapshot comes from `_authoring_context.get_entries()`, the same editor-only context as Ready, with integrated IDs (Print, Everything Flows, Custom Hello) and the external/package authoring IDs supported by the context. Buttons bind exact controller weak reference and stable machine/state IDs; a stale button from another selection cannot author blocks.
- Real block rows carry persistent resource ID metadata; **deliberate null slots and empty phase placeholders are disabled rows**, not editable phantom blocks. A totally empty machine produces no phase Add buttons until a real state is authored. No duplicate Inspector Blocks list or second Fluo.
- On successful Add, the selected phase and new block ID are stored as *transient editor selection*, not model data. The deferred UI rebuild reselects the fresh block by ID and restores actual keyboard focus to the **new native phase ItemList**, guarded by generation/controller/machine/state/selected resource and foreign editor focus ownership. Clicking a valid existing block row updates selection without editing the graph. Undo of a removed selected resource clears its selection, and Redo restores the same block/ID without creating a phantom selection.
- State or machine navigation clears the transient selected-phase ID and pending focus request, preserving existing Potok state focus, machine Inspector sync, left/right Drawer placement and Ready Process/Timer routing. No block Flusso property editor or phase structural actions in this lot.

## Measured scope and limits

- One new focal `tests/editor/flow_fsm_phase_add_ui_test.gd` (test guard hardened after expected missing UI), one 3-line CI step, one frozen contract, and editor-only change to `addons/vp_flujo/editor/flow_graph_inspector_property.gd` (161 additions/8 removals in comparison). **No** changes to `FlowGraphEditorCommands` 7F-1A, runtime, schema, catalog validator/assertions, existing focal suites, `FluoDrawer`, demo, release or `main`.
- The headless test mounted a real `FluoDrawer`, injected the external `tests/fixtures/manual_block_sdk` catalog and checked 4 Add actions per phase, null and empty placeholders, integrated Enter/Update and external Exit creation, ID/list focus, Undo/Redo resource identity, sibling-state isolation, stale button context, no empty-machine Add and untouched Ready Process. This proves simulated editor controls, **not** actual Fedora key delivery or Android touch/portrait.
- Versioned procedures `$flujo-baseline`, `$flujo-prove`, `$flujo-fluo-maintenance` consulted and applied remotely; not run as autonomous local Skills and no local Fedora staged/untracked/worktree audit. **No formal READY/PASA claim**. Previous 15 Fedora and 10 Android manual tests remain **25/25 PENDING**; specifically F03/A10 not PASS because block property editing/movement and full journey are incomplete.

## Next microblocks

**7F-1C1:** open actual selected phase block's property Flusso (Enter/double click) with correct owner, live editing, focus return, Cancel/Escape/Revertir and no unintended effects. **7F-1C2:** move, duplicate, delete across exact phase lists with validation and UndoRedo. **7F-1D:** end-to-end Inspector→Fluo→one/two states→all three Add/edit→transition→save/reopen→runtime. **7F-2:** human review matrix and explicit acceptance. Phase 7 remains open until those gates are met.

*Todo es Flujo; todo fluye.* 🌊
