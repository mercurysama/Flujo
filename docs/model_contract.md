# Flujo Model Technical Contract

## Purpose and scope

This document defines the implemented Flujo core-model contract for Godot 4.7.2. It establishes its responsibilities, identity, persistence, and dependencies. It does not define the executor or graphical-interface implementation yet.

## General principles

- `FlowGraph` is the persistent root of each visual program and starts with `schema_version = 1`.
- The editor may depend on runtime classes. Runtime must never depend on editor-only classes or APIs.
- The implementation uses portable GDScript and only APIs available in exported games when code belongs to runtime.
- User-created graphs and blocks are stored under `res://flow/`.
- Installed packages are stored under `res://flow_packages/<package_id>/`.
- No graph, block, package, or other user content is stored inside `res://addons/vp_flujo/`.

## Persistent identity

Every persistent element has a stable internal ID independent of its visible name, resource path, index, or position in a collection.

- `FlowId` centralizes the generation of random 32-character IDs through `FlowId.create()` and does not depend on the editor.
- Internal IDs are stored in hidden, serializable properties through `@export_storage`.
- Renaming an element does not change its ID.
- Moving an element does not change its ID.
- Reordering an element does not change its ID.
- Duplicating an element generates a new ID for the copy and for every contained persistent element that is also duplicated.

## Model classes

### FlowId

**Base:** `RefCounted`.

**Responsibility:** centrally generate random 32-character IDs without depending on editor APIs.

### FlowGraph

**Base:** `Resource`.

**Responsibility:** represent the persistent root of a visual program.

**Minimum data:**

- Stable internal ID.
- `CURRENT_SCHEMA_VERSION = 1` and `schema_version`, whose initial value is `1`, reserved for future migrations.
- Schema 1 uses only the ordered `Array[FlowBlockContainer]` collection named `containers`, which also preserves `null` positions.
- The available schema 2 representation uses only the ordered, typed collections `processes`, `variables`, and `state_machines`, which also preserve `null` positions.
- The two representations are not synchronized. Schema 1 rejects every schema 2 collection with a length greater than zero, and schema 2 rejects `containers` with a length greater than zero, even if they contain only `null` positions.

**Duplication:** requires a graph that has passed validation. It creates another `FlowGraph` and generates new IDs for the graph and every resource in the active representation while preserving ordering and `null` positions. The schema 2 copy uses one original-ID-to-new-ID map to remap `owner_container_id`, `global_variable_id`, and `initial_state_id`; unresolved references are preserved for diagnostics.

**Migration:** `FlowGraphMigrator.migrate_schema_1_to_2()` atomically creates a new schema 2 graph from a validated schema 1 graph. It preserves the graph ID and valid process, state, and block IDs without sharing mutable resources with the source. Processes and states preserve the positions from `containers`; states are grouped in a new machine named `Migrated States`.

**Scene sharing:** `FlowGraph` is a program definition that can be shared by instances of a `PackedScene` and remains immutable during execution. Per-instance mutable state and values belong to a future runtime context owned by each `PVController`.

**Allowed dependencies:** it may depend on persistent model types and portable runtime utilities. It does not depend on the editor or an executor.

### FlowBlockContainer

**Base:** `Resource`.

**Responsibility:** serve as a persistent polymorphic base class and group an ordered sequence of blocks within a graph.

**Minimum data:**

- Stable internal ID.
- Visible name independent of the ID.
- Activation through `enabled`.
- User note through `user_note`.
- Ordered `Array[FlowBlock]` collection that also preserves `null` positions.

**Duplication:** preserves the derived container type, generates a new ID for it, and duplicates its blocks with new IDs while preserving ordering and `null` positions.

**Allowed dependencies:** it may depend on `FlowBlock` and portable runtime data types. It does not depend on scene nodes, editor classes, or graphical controls.

### FlowBlock

**Base:** `Resource`.

**Responsibility:** represent a persistent block with identity, visible name, activation, and user note.

**Minimum data:**

- Stable internal ID.
- Visible name through `display_name`.
- Activation through `enabled`.
- User note through `user_note`.

**Duplication:** preserves persistent data and receives a new ID.

**Allowed dependencies:** uses only the model contract and portable runtime APIs. It does not depend on editor classes or the graphical interface.

### FlowProcess

**Base:** `FlowBlockContainer`.

**Responsibility:** persistently represent one of the supported process entry points.

**Process type:** `ProcessType` permits only `READY`, `PROCESS`, `PHYSICS_PROCESS`, `INPUT`, and `UNHANDLED_INPUT`.

**Visible name:** starts as `_ready`, but `display_name` remains renameable and independent of `process_type`. Changing the process type does not automatically change the visible name.

**Duplication:** preserves the `FlowProcess` type and generates new IDs through inherited duplication.

### FlowStateDefinition

**Base:** `FlowBlockContainer`.

**Responsibility:** represent the persistent definition of a state in a future state machine.

**Legacy initial-state data:** `is_initial` is retained only as schema 1 legacy data used to choose the initial state during schema 1→2 migration. It is not the source of truth in schema 2.

**Duplication:** preserves the `FlowStateDefinition` type, the `is_initial` value, and generates new IDs through inherited duplication.

### FlowGraphMigrationResult

**Base:** `RefCounted`.

**Responsibility:** represent a migration attempt with the migrated graph, when available, and ordered diagnostics from the source, transformation, or candidate.

### FlowGraphMigrator

**Base:** `RefCounted`.

**Responsibility:** migrate a schema 1 `FlowGraph` to an independent schema 2 copy without modifying the source. Migration validates the source before constructing the candidate and validates the candidate before returning success.

### FlowGraphInspectorPresenter

**Base:** `RefCounted`.

**Responsibility:** produce a deterministic, read-only `FlowGraph` representation for the Inspector interface. It belongs to the editor, includes schema version, active source, ordered sections, indexes, names, types, internal IDs, and diagnostics, and does not modify the graph.

### PVController

**Base:** `Node`.

**Responsibility:** act as the Flujo facade for a scene.

**Model:** owns the exported `flow_graph` property of type `FlowGraph`. Each new controller receives its own default graph.

**Execution:** not implemented yet.

## References and ordering

The ordering of `FlowGraph.containers` and `FlowBlockContainer.blocks` is preserved during duplication. `null` positions are also preserved and are neither removed nor compacted.

IDs do not depend on an index or position in these collections. The copy receives new IDs for the graph, containers, and blocks.

## Implemented schema 1 and schema 2 validation

`FlowGraphValidator` validates the model without modifying it and returns a `FlowValidationResult` with structured `FlowDiagnostic` diagnostics. Each diagnostic contains a stable code, severity, message, element path, and related ID. The result can report whether errors exist.

Current validation detects null graphs, unsupported schema versions, empty IDs, IDs whose length is not 32 characters, non-hexadecimal or duplicate IDs, repeated resource instances, and container types that cannot migrate under the schema 2 planned contract. It also detects simultaneous use of `containers` and schema 2 collections. It traverses the graph, its active collections, state machines, and blocks deterministically; it accepts `null` positions without diagnostics.

In schema 2, `owner_container_id` must resolve to a `FlowProcess` or `FlowStateDefinition` belonging to the same graph, and `global_variable_id` must resolve to a `GLOBAL` variable belonging to the same graph. Missing references or references to a disallowed type or scope are preserved and produce a diagnostic.

For every schema 2 `FlowStateMachineDefinition`, `initial_state_id` is the source of truth for the initial state: it must be empty when no non-null states exist and, when states exist, it must point to a non-null state in that same machine. Missing or invalid values are preserved and produce a diagnostic.

The validator belongs to runtime, uses only portable APIs, and does not depend on the editor.

## Implemented Inspector presentation

The editor uses `FlowGraphInspectorPresenter` to display the `flow_graph` of a `PVController` without modifying resources. In schema 1 it shows `Containers`; in schema 2 it shows `Processes`, `Variables`, and `State Machines`. Each position retains its index, and `null` positions are shown as `Empty`. Internal IDs are shown as stable metadata, while `display_name` is presentation text only.

`PVControllerInspectorPlugin` and `FlowGraphInspectorProperty` belong to the editor and are registered from the main plugin. Rows are selectable only within the interface; they do not write to the model. `FlowGraphValidator` diagnostics are shown without changing the graph.

## Implemented undo/redo Inspector editing

`FlowGraphEditorCommands` belongs exclusively to the editor and receives an `EditorUndoRedoManager` from the main plugin. Every modification is registered before it runs as an atomic action with do and undo operations; the model is not modified beforehand.

When a `PVController` has no graph, the Inspector can assign a new `FlowGraph` with `schema_version = 2` through an action. For a valid schema 1 graph, it can run `FlowGraphMigrator` and replace the reference only with a valid candidate; undo restores the exact original instance and redo restores the same migrated candidate.

In a schema 2 graph without mixed sources, the Inspector can add `FlowProcess`, `FlowVariableDefinition`, and `FlowStateMachineDefinition`, rename by internal ID, move a position, and remove while preserving the `null` gap. Actions use active-collection snapshots, so resources, IDs, ordering, and positions are restored by undo or redo. Before removal, an isolated candidate is validated: if it leaves invalid references, the action is rejected, does not enter history, and its diagnostics are shown in the Inspector.

Runtime resources involved in this presentation also execute in `@tool` mode so Godot can instantiate them inside the Inspector, but they do not import or reference editor APIs.

## Implemented migration from schema 1 to schema 2

`FlowGraphMigrator` accepts only a schema 1 source that passes `FlowGraphValidator`. Any source error diagnostic prevents migration and is retained in `FlowGraphMigrationResult`. The candidate is constructed separately, validated, and exposed only when it has no errors.

`FlowProcess` resources are copied deeply to `processes`, preserving the size, ordering, and indexes of `containers`; positions that do not contain processes remain `null`. `FlowStateDefinition` resources are copied deeply to a single `Migrated States` machine whose state array preserves the same indexes and positions. The machine is not created when there are no states and receives a new ID when it is created.

If exactly one state has `is_initial`, the migrated machine selects it; if none do, it selects the first non-null state; more than one produces an error diagnostic. Unknown `FlowBlockContainer` types, missing references, and any other source structural invalidity prevent migration without changing the source.

## Planned contract — not implemented yet

The requirements in this section are future design decisions. They do not describe features available in the current implementation.

The planned contract for further schema 2 evolution is defined in [`flow_graph_v2_migration.md`](flow_graph_v2_migration.md). Its portions not covered by the implemented migration remain prior design.

The planned schema 3 contract for Constructor, `PVController` bindings, methods, and calls is defined in [`constructor_methods_contract.md`](constructor_methods_contract.md). It does not describe implemented features yet.

### Execution and temporary state

- During future execution, `FlowGraph` and all its persistent resources will be treated as read-only data.
- `FlowRuntimeState` will be a temporary `RefCounted` class, independent for each controller and execution.
- `FlowRuntimeState` will contain only mutable execution-specific data, will never be serialized inside the graph, and will be released when that execution ends or is discarded.

### Internal references and duplication

- Persistent internal references will use IDs, never visible names or collection indexes or positions.
- Future duplication of structures with references will create a map between original and new IDs and use it to update internal references that point to elements included in the copy.

### Validation

- Validation will reject empty, malformed, or duplicate IDs within the graph identity space.
- Every internal reference must resolve to an existing element of a type allowed by that relationship.
- A missing reference or one that resolves to the wrong type will be an error; it will not be replaced by searching for a visible name or position.

### Versions and migrations

- `schema_version` migrations will run explicitly in ordered steps before using a graph.
- A future version later than the maximum supported version, or an incompatible version, will be rejected in a controlled way without overwriting or saving the resource.
- Migrations will preserve all existing valid IDs and generate new IDs only where the transformation requires them.

### Operations and editor separation

- Model modifications will be expressed as small, deterministic operations with explicit inputs and the information required to undo and redo them.
- The editor may adapt those operations to its undo/redo system without moving editor dependencies into runtime.
- Runtime, including its future loading, validation, migration, and execution components, will not depend on editor-only classes or APIs.

### Future portability

- Model loading, validation, migration, and execution will also work in exported games through portable APIs available on platforms supported by Godot 4.7.2.

## Tests

The `tests/model/flow_model_smoke_test.tscn` scene validates IDs, duplication, preservation of derived types and `null` positions, and that every new `PVController` owns an independent `FlowGraph`.

It can be run manually by opening that scene in Godot and pressing **F6**.

`tests/editor/flow_graph_editor_commands_test.gd` runs in a headless editor and covers creation, migration, renaming, moving, valid and rejected removal, preservation of instances and IDs during undo/redo, presenter refresh, and validation without mixed sources.

## Iteration 5 final audit

The iteration delivers schema 2 typed collections, deterministic validation, explicit schema 1→2 migration, read-only presentation, and undoable Inspector editing. The default `schema_version` remains `1` for legacy resources. Automatic migration, block or internal-state editing, dock or executor changes, and editor dependencies in runtime were not implemented.

## Location and portability

Project-owned content is organized under `res://flow/`. Installed packages use `res://flow_packages/<package_id>/`, where `package_id` is stable and suitable for portable paths. `res://addons/vp_flujo/` is reserved exclusively for plugin-distributed code and resources.

The model does not use absolute paths, operating-system-specific separators, external processes, or editor-only APIs. Its runtime code uses APIs available in exported games on platforms supported by Godot 4.7.2.
