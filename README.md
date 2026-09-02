# Flujo

> Experimental pre-alpha software. Features and file formats may change during development.

Flujo is an MIT-licensed visual programming plugin for Godot. It is designed to build game logic through readable definitions and blocks while keeping portable runtime code separate from editor tools.

## Current status

### Implemented

- An editor plugin under `addons/vp_flujo/` and the `PVController` scene facade.
- Stable internal IDs, deterministic validation, deep duplication, and explicit schema 1→2 migration for `FlowGraph` definitions.
- Schema 2 typed collections: `processes`, `variables`, and `state_machines`, including deliberate `null` positions and ID-based references.
- A read-only and undoable Inspector workflow for the supported schema 2 collections.
- Selection-based Flujo dock visibility and F4 controller support.
- Model, editor, and PackedScene persistence regressions.

### Current work

Iteration 6 defines the architecture for schema 3 Constructor declarations and reusable methods. The contract is complete; the schema, runtime behavior, and editor workflow are not implemented yet.

### Planned

Visual block authoring, a runtime executor, debugging, packages, inherited-scene customization, and per-instance runtime state remain future work.

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

- `addons/vp_flujo/editor/`: editor-only plugin, Inspector, and dock code.
- `addons/vp_flujo/runtime/`: portable runtime code and persistent model definitions.
- `demo/`: demonstration scene.
- `tests/`: model, editor, and persistence tests.
- `docs/`: architecture, contracts, roadmap, and iteration documentation.

## Documentation

- [Object-oriented architecture](docs/arquitectura_poo.md)
- [Model contract](docs/model_contract.md)
- [Schema 2 migration contract](docs/flow_graph_v2_migration.md)
- [Constructor and Methods contract](docs/constructor_methods_contract.md)
- [Iteration 1 notes](docs/iteracion_01.md)
- [Iteration 5 postmortem](docs/iteration_05.md)
- [Roadmap](docs/roadmap.md)

## AI-assisted development

Flujo is developed with assistance from ChatGPT and OpenAI Codex for planning, code generation, review, and testing. Every change is reviewed and validated by the project maintainer before being included in a release.

## License

Flujo is distributed under the [MIT License](LICENSE).
