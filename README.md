# Flujo

> Experimental pre-alpha software. Features and file formats may change during development.

Flujo is an MIT-licensed visual programming plugin for Godot. It is designed to build game logic through readable containers and blocks while keeping runtime execution separate from editor tools.

## Current features

- Editor plugin located in `addons/vp_flujo/`.
- `PVController` node with a typed `FlowGraph` model.
- Stable internal identifiers for graphs, containers, states, processes, and blocks.
- Flujo dock integrated into the Godot editor.
- F4 adds a `PVController` to the selected node.
- F4 opens or closes the Flujo dock when the selected node already contains a controller.
- Controller creation supports Godot's undo and redo history.
- Model smoke test for identifiers, duplication, types, and independent graph instances.

The visual block editor, runtime executor, debugger, user packages, and localization system are still under development.

## Requirements

- Godot 4.7.2 stable.

## Installation

1. Copy `addons/vp_flujo/` into the `addons/` directory of a Godot project.
2. Open the project with Godot 4.7.2 stable.
3. Go to **Project > Project Settings > Plugins**.
4. Enable the plugin named **Flujo**.
5. Select a node and press F4 to add Flujo.
6. Press F4 again to open or close the Flujo dock.
7. Save the scene normally with Ctrl+S.

## Model smoke test

1. Open `tests/model/flow_model_smoke_test.tscn`.
2. Press F6 to run the current scene.
3. Confirm that the output contains:

   `[Flujo] Model smoke test passed`

## Project structure

- `addons/vp_flujo/editor/`: editor-only plugin and dock code.
- `addons/vp_flujo/runtime/`: portable runtime code and data model.
- `demo/`: demonstration scene.
- `tests/`: model and integration tests.
- `docs/`: architecture and model documentation.

## Documentation

- [Object-oriented architecture](docs/arquitectura_poo.md)
- [Model contract](docs/model_contract.md)
- [Iteration 1 notes](docs/iteracion_01.md)

## AI-assisted development

Flujo is developed with assistance from ChatGPT and OpenAI Codex for planning, code generation, review, and testing. Every change is reviewed and validated by the project maintainer before being included in a release.

## License

Flujo is distributed under the [MIT License](LICENSE).
