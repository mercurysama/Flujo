# Iteration 1 — Plugin Foundation

## Objective

Provide a valid Godot project with an `@tool` plugin, a registered `PVController` node, a side dock that responds to the active scene, and an object-oriented architecture that separates responsibilities.

## Acceptance criteria

- Godot recognizes `addons/vp_flujo/plugin.cfg`.
- `PVController` appears in the **Add Node** dialog.
- The `VPFlujo` dock opens when the scene contains at least one `PVController`.
- The dock closes when the scene contains none.
- A class derived from `PVController` is also recognized.
- The view, scene analysis, and plugin coordination are in separate classes.
- Disabling the plugin removes the dock without leaving active connections.

## Manual test

1. Import the project in Godot 4.7.2 and open `demo/main.tscn`.
2. Confirm that there are no GDScript parser errors.
3. Confirm that the `VPFlujo` dock displays “PVController detected”.
4. Temporarily remove `PVController` and confirm that the dock closes.
5. Add a `PVController` node through the node dialog and confirm that the dock opens again.
6. Temporarily create a class that inherits from `PVController` and confirm that it also activates the dock.
7. Use `Ctrl+S`, close and reopen the scene, and verify persistence.

## Prompt for ChatGPT/Codex in VS Code

```text
Review iteration 1 of the VPFlujo project for Godot 4.7.2 using object-oriented programming. Analyze project.godot, addons/vp_flujo/plugin.cfg, all scripts under addons/vp_flujo/editor, addons/vp_flujo/runtime/pv_controller.gd, demo/main.tscn, and docs/arquitectura_poo.md. Verify: GDScript syntax, encapsulation, single responsibility, composition, dependencies between classes, the _enter_tree/_exit_tree lifecycle, global PVController registration, recognition of derived classes, signal connections and disconnections, and safe removal of the EditorDock. Do not add the data model or execution yet. If you find a problem, apply the smallest change and explain how to validate it manually in Godot.
```

## Next iteration

Create the serializable `PVProgram → PVProcess → PVRoutine → PVBlock` model with `Resource` classes, names, ordering, and initially empty block lists.
