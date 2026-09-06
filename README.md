# Flujo

> Experimental pre-alpha software. Features and file formats may change during development.

Flujo is an MIT-licensed visual programming plugin for Godot. It is designed to build game logic through readable definitions and blocks while keeping portable runtime code separate from editor tools.

## Current status

### Implemented

- An editor plugin under `addons/vp_flujo/` and the `PVController` scene facade.
- Stable internal IDs, deterministic validation, deep duplication, and explicit schema 1→2 and schema 2→3 migrations for `FlowGraph` definitions.
- Schema 2 typed collections: `processes`, `variables`, and `state_machines`, including deliberate `null` positions and ID-based references.
- Schema 3 structural declarations: one `FlowConstructorDefinition` as a `FlowBlockContainer`, ordered dependencies and blocks, reusable methods, and typed parameters.
- Persistent and validated `FlowMethodCallBlock` references for schema 3 containers, with ID-based targets and order-independent duplication remapping.
- A read-only and undoable Inspector workflow for the supported schema 2 collections.
- Selection-based Flujo dock visibility and F4 controller support.
- Model, editor, and PackedScene persistence regressions.

### Current work

Iteration 6 has implemented the schema 3 structural model, its atomic migration, constructor container foundation, and persistent method-call references. Arguments, returns, call-cycle detection, runtime execution, and editor authoring remain pending. See the [current iteration](docs/current_iteration.md).

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
- [Flujo Constitution](docs/constitution.md)
- [Development workflow](docs/development_workflow.md)
- [Engineering flow metrics](docs/engineering_metrics.md)
- [Current iteration](docs/current_iteration.md)
- [Model contract](docs/model_contract.md)
- [Schema 2 migration contract](docs/flow_graph_v2_migration.md)
- [Constructor and Methods contract](docs/constructor_methods_contract.md)
- [Iteration 1 notes](docs/iteracion_01.md)
- [Iteration 5 postmortem](docs/iteration_05.md)
- [Roadmap](docs/roadmap.md)

## AI-assisted development

Flujo is developed with assistance from ChatGPT and Codex for planning, code generation, review, and testing. Flujo does not depend on either tool or provider. Every change requires validator and test evidence plus authorized human review before integration or release.

## License

Flujo is distributed under the [MIT License](LICENSE).
