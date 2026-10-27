# Flujo Project Memory / Handoff

Updated: 2026-10-27

This is the durable repository handoff for future chats and maintainers.

## Current validated preview checkpoint

- Repository: `mercurysama/Flujo`.
- Active UI branch: `feature/fluo-drawer-poc`.
- Validated functional checkpoint: `cd7e969c38193d718c948262107d1f7a45ca8083`.
- Frozen code backup: `backup/fluo-preview-1-2026-10-27`.
- Preview package: `Flujo-0.1.0-fluo-preview.1`.
- Godot target: 4.7.2 stable.
- License: MIT.

## Vocabulary

- **Inspector**: Godot Inspector.
- **Fluo**: complete contextual sliding drawer.
- **Flow**: left internal panel containing blocks of the selected container.
- **Flusso**: right selected-block configuration panel.
- **Legacy Flujo dock**: older visible fallback retained temporarily.

Do not rename internal VP/PV classes merely to match presentation terminology.

## Inspector → Fluo contract

1. No duplicate Blocks section belongs in Inspector.
2. Double-click or Enter on an existing supported container row opens Fluo for its stable ID.
3. Flow is visible; Flusso starts closed.
4. Flow focuses the first block, or the first Add-block button when empty.
5. Double-click or Enter on a Flow block opens Flusso.
6. Closing Flusso returns real keyboard focus to the same selected Flow block after rebuild.
7. The whole drawer can be placed left/right.

## Keyboard map

- Up/Down: native Flow ItemList movement.
- Ctrl+PageUp/PageDown: circular Flow block movement by stable ID.
- Plain PageUp/PageDown: movement between containers in the current Inspector view; Inspector visible selection redraws to the same stable ID while keyboard focus remains in Flow.
- Alt+PageUp/PageDown: cycle Flusso controls.
- Alt+Shift+PageUp/PageDown: reverse Alt traversal.
- Escape: close Flusso first, then Fluo.
- Enter on a selected Flow block: same activation as double-click.

## Flusso editing semantics

- Supported configuration changes are immediate/live.
- Closing Flusso is neither commit nor cancel.
- **Revertir** restores the persistent configuration snapshot captured when the current Flusso session opened and keeps Flusso open.
- Structural destructive actions such as Delete remain separate actions.
- Changing container closes stale Flusso options.

## Important implementation files

- `addons/vp_flujo/editor/fluo_drawer.gd`
- `addons/vp_flujo/editor/flow_ready_process_editor.gd`
- `addons/vp_flujo/editor/flow_graph_inspector_property.gd`
- `addons/vp_flujo/editor/pv_controller_inspector_plugin.gd`
- `addons/vp_flujo/plugin.gd`
- `tests/editor/flow_process_timer_editor_test.gd`
- `tests/editor/fluo_drawer_test.gd`
- `tests/editor/fluo_drawer_integration_test.gd`

## Manual validation state

Desktop interaction was repeatedly exercised and approved during implementation.

On 2026-10-27 the full-project preview opened under Godot on Android. The maintainer supplied visual evidence showing Fluo mounted over the Godot editor, Flow and Flusso rendered, Revertir and close controls visible, and Flow block rows visible. This confirms Android project load and drawer rendering only; it does not certify the complete Android interaction matrix.

## Android preview matrix still required

- portrait and landscape;
- touch target sizes;
- long-panel scrolling;
- double-tap activation;
- keyboard shortcuts when available;
- focus restoration after closing Flusso;
- repeated PageUp/PageDown and Ctrl+PageUp/PageDown;
- drawer left/right placement;
- final panel proportions and readability.

## Temporary legacy UI

The visible `Flujo` dock and `Open Fluo (POC)` route remain intentionally available until explicit preview acceptance. After acceptance, hide/remove the visible fallback while preserving reusable editor/model code that is still needed.

## Themes + Motion

Themes + Motion is required before the first stable release, after functional preview acceptance and manual proportion tuning. Godot 4.7 offset transforms must not desynchronize Container layout, focus, hitboxes, mouse filtering, or touch interaction.

## Packaging

- **Addon Preview**: `addons/vp_flujo/` + README + LICENSE.
- **Full Project Preview**: complete project for Android/editor validation.

The Addon Preview intentionally omits `project.godot`, demo, tests and tools. The Fluo implementation file is `addons/vp_flujo/editor/fluo_drawer.gd`; there is no new standalone `flujo.gd`.

## Next maintenance sequence

1. Complete Android interaction validation.
2. Fix preview issues in small batches.
3. Run affected focal tests and manual checks; never infer passes.
4. After explicit acceptance, hide/remove the legacy dock/POC surface.
5. Tune panel proportions from device evidence.
6. Implement and validate Themes + Motion.
7. Define first stable release criteria.

Todo es Flujo; todo fluye. 🌊
