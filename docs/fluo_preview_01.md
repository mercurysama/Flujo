# Fluo Preview 1

Date: 2026-10-27  
Status: Experimental preview / pre-release candidate  
Validated code checkpoint: `cd7e969c38193d718c948262107d1f7a45ca8083`  
Frozen backup: `backup/fluo-preview-1-2026-10-27`

## Purpose

Validate the contextual authoring path that starts from existing Godot Inspector container rows and opens a sliding editor without duplicating the persistent FlowGraph model.

## Accepted preview behavior

- Inspector container rows open Fluo by double-click or Enter.
- Flow opens with the first block focused, or first Add-block button when empty.
- Flow blocks open Flusso by double-click or Enter.
- Flusso changes apply immediately.
- Revertir restores the opening snapshot for the current Flusso session.
- Escape closes Flusso first and Fluo second.
- Closing Flusso returns focus to the same Flow block.
- Ctrl+PageUp/PageDown cycles Flow blocks.
- Plain PageUp/PageDown cycles containers in the current Inspector view and redraws Inspector selection while keeping keyboard focus in Flow.
- Alt+PageUp/PageDown cycles Flusso controls; Shift reverses the Alt direction.
- Fluo can move left/right.

## Evidence status

Desktop interaction was manually exercised and approved during implementation.

On Android, the full-project preview opened successfully on 2026-10-27 and visibly rendered Fluo, Flow, Flusso, Revertir, close controls and Flow block rows. This is approved load/render evidence only.

Still pending on Android: portrait/landscape, touch targets, long-panel scrolling, double-tap, keyboard shortcuts, focus restoration, repeated navigation and final panel proportions.

Focal automated assertions exist in:
- `tests/editor/flow_process_timer_editor_test.gd`
- `tests/editor/fluo_drawer_test.gd`
- `tests/editor/fluo_drawer_integration_test.gd`

This handoff does not claim a fresh final automated run after the last UI checkpoint.

## Packaging

- Addon: `Flujo-0.1.0-fluo-preview.1.zip`
- Full project: `Flujo-0.1.0-fluo-preview.1-full-project.zip`
- `plugin.cfg` remains `0.1.0`.

## Exit criteria

1. Complete Android interaction matrix.
2. Fix preview-blocking UI/focus issues.
3. Obtain explicit acceptance of Inspector → Fluo.
4. Hide/remove legacy visible dock and obsolete POC path.
5. Tune panel proportions.
6. Complete Themes + Motion validation before stable.

Todo es Flujo; todo fluye. 🌊
