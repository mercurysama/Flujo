---
name: flujo-fluo-maintenance
description: Maintain or extend the Fluo contextual drawer, Flow block panel, Flusso configuration panel, Inspector synchronization, focus, keyboard navigation, or preview packaging when explicitly invoked as $flujo-fluo-maintenance.
---

# Flujo Fluo maintenance

## Required context

1. Read `AGENTS.md`, `docs/constitution.md`, `docs/current_iteration.md`, `docs/project_memory.md`, `docs/fluo_preview_01.md`, `docs/development_workflow.md`, and affected `FLUJO-BHV-FLUO-*` catalog entries.
2. Record branch, HEAD, working-tree state, protected user files, and exact requested behavior.
3. Invoke `$flujo-baseline` before functional correction/refactor and `$flujo-prove` before committing as required by `AGENTS.md`.

## Vocabulary and architecture

- Inspector = Godot Inspector.
- Fluo = whole drawer.
- Flow = left block panel.
- Flusso = right configuration panel.
- Legacy visible Flujo dock = temporary fallback.
- Never add a duplicate Inspector Blocks list.
- Never rename internal VP/PV classes merely for UI terminology.

## State boundaries

Keep separate: Inspector container stable ID/visible selection; Flow block stable ID/focus; Flusso open state/session snapshot; Fluo drawer visibility/side; persistent model values.

## Preview 1 keyboard contract

- Up/Down: native Flow movement.
- Ctrl+PageUp/PageDown: circular Flow block navigation.
- Plain PageUp/PageDown: Inspector container-view navigation with visible Inspector sync and Flow retaining focus.
- Alt+PageUp/PageDown: Flusso control traversal.
- Alt+Shift+PageUp/PageDown: reverse Alt traversal.
- Enter on Flow block: open Flusso.
- Escape: close Flusso first, then Fluo.

## Editing and focus

- Supported Flusso changes persist immediately.
- Closing is neither commit nor cancel.
- Revertir restores the opening snapshot and keeps Flusso open.
- Delete is separate.
- Opening a container focuses first Flow block or first Add-block button.
- Closing Flusso restores focus to the same selected Flow block after rebuild.
- Never retain focus references to detached controls.

## Verification

Inspect/run the canonical gates and affected focal tests, especially:
- `tests/editor/flow_process_timer_editor_test.gd`
- `tests/editor/fluo_drawer_test.gd`
- `tests/editor/fluo_drawer_integration_test.gd`

Manual Godot review is mandatory for visible selection, focus, drawer placement and shortcuts. Android evidence is separate from desktop evidence.

## Preview maintenance

Keep the legacy dock/POC path until explicit preview acceptance. After acceptance, remove/hide the fallback, tune proportions, then implement Themes + Motion with Godot 4.7 offset transforms and verify Containers, focus, hitboxes, mouse filtering and touch interaction.

## Packaging

Distinguish Addon Preview (`addons/vp_flujo/` + README + LICENSE) from Full Project Preview (complete project). Confirm source commit and critical blob hashes when diagnosing packaging.
