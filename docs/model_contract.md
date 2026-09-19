# Flujo Model Technical Contract

## Purpose and scope

This document defines the Flujo core-model contract for Godot 4.7.2: responsibilities, identity, persistence, dependencies, and the scoped Ready execution delivery below.

The proposed class, instance, attribute, reference, encapsulation, inheritance, and future method-execution architecture is specified separately in the [Flujo Object Model contract](flow_object_model_contract.md). It requires schema 5 and is not implemented or authorized for implementation.

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

**Migration:** `FlowGraphMigrator.migrate_schema_1_to_2()` atomically creates a new schema 2 graph from a validated schema 1 graph. It preserves the graph ID and valid process, state, and block IDs without sharing mutable resources with the source. Processes and states preserve the positions from `containers`; states are grouped in a new machine named `Migrated States`. `FlowGraphMigrator.migrate_schema_2_to_3()` atomically creates a new schema 3 graph from a validated schema 2 graph. It preserves the graph ID and all schema 2 IDs, references, order, and `null` positions through deep copies, then creates one empty constructor with a new ID and an empty methods collection.

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

### FlowMethodCallBlock

**Base:** `FlowBlock`.

**Responsibility:** persist a schema 3 method-call reference without execution behavior.

**Persistent target:** `method_id: String` is the only target identity and must resolve to a `FlowMethodDefinition` in the same `FlowGraph`. Empty, missing, and wrong-type IDs are preserved and diagnosed deterministically. Names, indexes, direct resource references, `Callable`, `Node`, and `NodePath` are not target identities.

**Placement:** constructor, method, process, and state block collections in schema 3. Schema 1 and schema 2 reject the type.

**Duplication:** preserves the concrete block type, generates a new block ID, and remaps `method_id` only after the graph-wide old-ID → new-ID map is complete. Unknown references remain unchanged.

**Execution boundary:** CMRUN-001–006 in the [Constructor and Methods contract](constructor_methods_contract.md) add authoring and execution only from Processes and Timers. Calls stored elsewhere remain valid persistent data but are skipped at runtime. Arguments, return values, recursion, cycle detection and bindings remain deferred under `ARGRET-001` through `ARGRET-012`.

### FlowMethodReturnDefinition

**Base:** `Resource`.

**Responsibility:** persist the one optional typed return declaration owned by a schema 3 `FlowMethodDefinition`; it does not provide a runtime value, assignment, or return block.

**Minimum data:** stable internal ID, visible `display_name`, and `value_type` directly typed as `FlowVariableDefinition.ValueType`. `null` in `FlowMethodDefinition.return_definition` means no return, so no duplicate enum or sentinel value exists.

**Validation and duplication:** its identity is in the schema 3 graph-wide resource and ID registries. Empty IDs, duplicate IDs, and repeated resource instances produce the existing deterministic identity diagnostics at `methods[i].return_definition` without modifying the graph. Deep graph duplication gives it a new ID through the sole old-ID → new-ID map and retains independent metadata.

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

**Responsibility:** migrate a `FlowGraph` through explicit, independent schema 1→2 or 2→3 steps without modifying the source. Each migration validates the source before constructing the candidate and validates the candidate before returning success.

### FlowGraphInspectorPresenter

**Base:** `RefCounted`.

**Responsibility:** produce a deterministic, read-only `FlowGraph` representation for the Inspector interface. It belongs to the editor, includes schema version, active source, ordered sections, indexes, names, types, internal IDs, and diagnostics, and does not modify the graph.

### PVController

**Base:** `Node`.

**Responsibility:** act as the Flujo facade for a scene.

**Model:** owns the exported `flow_graph` property of type `FlowGraph`. Each new controller receives its own default graph.

**Execution:** the controller runs enabled schema 3 Constructor blocks once immediately before its once-only Ready pass, outside editor hint and subject to `visual_program_enabled`, then starts its Timers. `FlowReadyExecutor` shares the starter-block handlers and allows one level of method calls from Ready/Timer containers. `FlowRuntimeOutput` preserves its existing signals and adds contextual entry, method and call IDs. The graph stays read-only; parameters, returns and nested method calls remain deferred.

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

The editor uses `FlowGraphInspectorPresenter` to display the `flow_graph` of a `PVController` without modifying resources. In schema 1 it shows `Containers`; in schema 2 it shows `Processes`, `Variables`, and `State Machines`. Each position remains represented in the model, and `null` positions are shown as `Empty`. Schema 2 row labels and tooltips show only visible names or `Empty`; internal IDs remain editor metadata used for selection and commands, not user-facing text.

`PVControllerInspectorPlugin` and `FlowGraphInspectorProperty` belong to the editor and are registered from the main plugin. Rows are selectable only within the interface; they do not write to the model. `FlowGraphValidator` diagnostics are shown without changing the graph.

## Implemented undo/redo Inspector editing

`FlowGraphEditorCommands` belongs exclusively to the editor and receives an `EditorUndoRedoManager` from the main plugin. Every modification is registered before it runs as an atomic action with do and undo operations; the model is not modified beforehand.

When a `PVController` has no graph, the Inspector can assign a new `FlowGraph` with `schema_version = 2` through an action. For a valid schema 1 graph, it can run `FlowGraphMigrator` and replace the reference only with a valid candidate; undo restores the exact original instance and redo restores the same migrated candidate.

In a schema 2 graph without mixed sources, the Inspector can add `FlowProcess`, `FlowVariableDefinition`, and `FlowStateMachineDefinition`, rename by internal ID, move a position, and explicitly remove one selected entry by its internal ID. Removal compacts only that removed entry; unrelated deliberate `null` positions remain. Actions use active-collection snapshots and the edited `PVController` as their undo/redo context, so resources, IDs, ordering, positions, and native scene dirty-state transitions are restored by undo or redo. Before removal, an isolated candidate is validated: if it leaves invalid references, the action is rejected, does not enter history, and its diagnostics are shown in the Inspector.

Runtime resources involved in this presentation also execute in `@tool` mode so Godot can instantiate them inside the Inspector, but they do not import or reference editor APIs.

## Implemented migration from schema 1 to schema 2

`FlowGraphMigrator` accepts only a schema 1 source that passes `FlowGraphValidator`. Any source error diagnostic prevents migration and is retained in `FlowGraphMigrationResult`. The candidate is constructed separately, validated, and exposed only when it has no errors.

`FlowProcess` resources are copied deeply to `processes`, preserving the size, ordering, and indexes of `containers`; positions that do not contain processes remain `null`. `FlowStateDefinition` resources are copied deeply to a single `Migrated States` machine whose state array preserves the same indexes and positions. The machine is not created when there are no states and receives a new ID when it is created.

If exactly one state has `is_initial`, the migrated machine selects it; if none do, it selects the first non-null state; more than one produces an error diagnostic. Unknown `FlowBlockContainer` types, missing references, and any other source structural invalidity prevent migration without changing the source.

## Implemented schema 3 structural foundation

`FlowGraph.SCHEMA_VERSION_3` reuses the ordered schema 2 `processes`, `variables`, and `state_machines` collections, requires exactly one `FlowConstructorDefinition`, and adds ordered `methods`. Its legacy `containers` collection must be empty. Schema 1 and schema 2 sources remain unchanged and are never synchronized with schema 3.

`FlowConstructorDefinition` is a specialized `FlowBlockContainer`. It inherits persistent identity, display name, activation, user note, and an ordered nullable block collection without duplicating those properties, and it owns an additional ordered nullable collection of `FlowDependencyDefinition` resources. A dependency stores its stable ID, display metadata, `required_class_name: StringName`, and `required` flag only; it stores no node, node path, or scene reference. The structural validator applies the same block identity and instance rules used by other block containers, requires a non-empty dependency class name, and deliberately defers class resolution, inheritance, and `PVController` bindings. Declarations may name built-in or project global `Node` subclasses, and future resolution will allow derived instances for base declarations.

`FlowMethodDefinition` is a `FlowBlockContainer` with ordered nullable blocks, `FlowMethodParameterDefinition` resources, and one nullable `FlowMethodReturnDefinition`. Its absent return definition represents no return. Method, dependency, and parameter names are non-empty after trimming and unique in their own exact, case-sensitive namespaces. IDs and resource instances, including a present return definition, are globally unique throughout the graph, and validation remains deterministic and read-only.

`FlowVariableDefinition.ValueType` remains the single canonical value-type enum. Parameters reuse it directly without inheriting variable scope, ownership, binding, persistence, or runtime-value behavior. Its existing public members, numeric values, serialized property name, and variable API are unchanged.

Schema 3 duplication deeply copies the constructor, its blocks and dependencies, methods, parameters, optional return definitions, method-call blocks, and schema 2 collections with one old-ID-to-new-ID map, preserving concrete types, order, and `null` positions. Method-call references are remapped after the map is complete, so calls may target methods declared later in collection order. Unknown method references remain unchanged. Argument bindings and controller bindings do not exist in this foundation.

Schema 3 validation builds the complete method-ID index before checking method calls and includes optional return definitions in the global identity registry. Calls are accepted in constructor, method, process, and state blocks. Empty, missing, and wrong-type targets produce deterministic diagnostics without modifying the graph. Schema 1 and schema 2 reject method-call blocks and do not acquire method-return definitions implicitly. Direct and indirect recursion are not rejected because call-cycle validation remains deferred.

## Implemented migration from schema 2 to schema 3

`FlowGraphMigrator.migrate_schema_2_to_3()` accepts only a schema 2 source that passes `FlowGraphValidator`. It validates the source before creating a separate candidate and validates that candidate before returning it; any diagnostic error leaves `migrated_graph` null and never modifies the source.

The candidate keeps the source graph ID and deeply copies `processes`, `variables`, and `state_machines`, including nested blocks and states. All valid IDs, references, order, and deliberate `null` positions are preserved. It has schema version 3, no legacy containers, exactly one newly generated `FlowConstructorDefinition` with empty `blocks` and `dependencies`, and an empty `methods` collection. The migration creates no bindings, calls, arguments, runtime state, Inspector integration, or executor behavior.


## Implemented schema 4 persistent foundation

`SCHEMA_VERSION_4` adds ordered nullable `FlowConstructorDefinition.requirements` without changing schemas 1–3. `FlowRequiredNodeDefinition` stores a stable ID, visible name, enabled flag, note, required built-in Node class, expected node name, and Required flag. Its reserved `required_properties` array must be empty. Schema 4 retains Constructor `blocks` and `dependencies` as inert legacy data, with their original fields, types, IDs, order, and null positions. It retains all other schema 3 structural data and ID-based references.

Requirement IDs use the existing global validation registry and duplication map. `migrate_schema_3_to_4(source, confirm_legacy_payload = false)` validates before and after a deep copy, preserves IDs and references, and rejects non-empty legacy blocks or dependencies without confirmation. `migrate_schema_2_to_4(source)` chains 2→3→4 and returns only a successful final candidate. Neither path modifies the source or converts dependencies into requirements.

`PVController.requirement_bindings` stores an independent `Dictionary[String, NodePath]` per controller, with locators relative to the constructed object. It is not part of graph duplication. Structural binding validation checks IDs and locator shape without resolving scene nodes. ResourceSaver and PackedScene coverage is in `tests/model/flow_schema_4_foundation_test.gd`. The executor and Timer scheduler remain restricted to schema 3; schema 4 authoring, Apply Constructor, node creation, binding resolution, and runtime verification are deferred. See the [Declarative Constructor contract](declarative_constructor_contract.md).

## Planned contract — not implemented yet
The requirements in this section are future design decisions. They do not describe features available in the current implementation.

The planned contract for further schema 2 evolution is defined in [`flow_graph_v2_migration.md`](flow_graph_v2_migration.md). Its portions not covered by the implemented migration remain prior design.

The schema 3 contract in [`constructor_methods_contract.md`](constructor_methods_contract.md) defines the implemented method-call foundation and planned arguments, returns, and call-cycle work. The remaining schema 4 scene application and runtime-verification design is defined in [`declarative_constructor_contract.md`](declarative_constructor_contract.md), separately from its implemented persistent foundation above.

### Execution and temporary state
### Deferred schema 3 work

- `PVController` dependency bindings and class-resolution/inheritance checks.
- `FlowRuntimeState` and execution beyond the two Ready starter blocks.
- Method-call argument bindings, return blocks and values, argument validation, and call-cycle validation.
- Constructor dependencies, method parameters/returns, and execution beyond CMRUN-001–006.

### Planned method arguments and returns

`ARGRET-001`, `ARGRET-002`, and the return-definition portions of `ARGRET-008` and `ARGRET-009` are implemented. The remaining requirements in [`constructor_methods_contract.md`](constructor_methods_contract.md) define future parameter-ID argument bindings, a shared value-source abstraction, return blocks, compatibility validation, and order-independent reference remapping. They deliberately do not define concrete value-source fields, runtime execution, implicit conversion, visual connections, Inspector authoring, recursion or call-cycle validation, or multiple returns.


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

## Ready execution delivery

The following approved requirements govern the first executable path. Implementation and automated verification are present; manual visual review is recorded separately in the current iteration state.

- **READY-001:** reuse schema 3 `FlowGraph.processes`, `FlowProcess.ProcessType.READY`, inherited IDs, names, activation and ordered nullable `blocks`. The existing polymorphic block collection already represents these definitions without reinterpreting stored fields; no schema 4 or implicit migration is needed. New authoring and execution require schema 3. Schema 2 is retained only for migration/compatibility coverage, including the unchanged explicit 2→3 chain.
- **READY-002:** `FlowPrintBlock` adds only a configurable `text: String`; `FlowEverythingFlowsBlock` adds no configuration. Both inherit `FlowBlock` identity and activation. Existing graph duplication and atomic 2→3 migration must preserve subtype, text, ordering and null slots (new IDs for duplication, original IDs for migration).
- **READY-003:** outside editor hint, each `PVController` performs one Ready pass per instance at `_ready()`, gated by `visual_program_enabled`. Re-entry or `request_ready()` does not run a second pass. Disabled programs, processes and blocks emit nothing; no frame/input/state/method execution is added.
- **READY-004:** a portable executor resolves built-in block scripts through a small handler registry, separate from definitions and graph validation. Unsupported or invalid blocks produce a warning and are skipped without stopping later blocks. Graph-level schema/identity errors prevent execution; process/block diagnostics skip the affected path. All persistent resources remain read-only.
- **READY-005:** a single runtime output boundary calls `print()` and emits controller, process ID, block ID and message. Everything Flows emits exactly `Todo es Flujo; todo fluye.`. No debugger transport or game-window presentation is created.
- **READY-006:** the schema 3 Inspector owns only Process creation and stable-ID row selection. The Flujo panel owns Ready configuration and ordered block authoring: Name, Enabled, add Print/Everything Flows, move, confirmed deletion, block Enabled, and Print text. Print uses a subtly contrasting surface derived from the active editor theme while retaining its multiline and Ctrl+Enter/Escape behavior. Commands resolve stable IDs and use the owning controller's scene undo/redo history. Existing schema 1/2 interfaces, variable editing, F4 and native layout remain unchanged.
- **READY-007:** schema 3 focal regressions cover ResourceSaver/PackedScene, deep duplication, execution order, every enable gate, once-only Ready, editor hint, unknown/invalid blocks and structured output. Schema 2 fixtures cover migration only. Export, performance measurement, monitor integration and game-window presentation are outside this delivery.
- **READY-008:** manual Fedora acceptance is to create Ready, add the two blocks, execute with F6, and verify each configured message appears once in order. Automated tests do not claim manual approval.
- **READY-009:** every Ready or Timer block uses the inherited persistent `FlowBlock.display_name` as its optional visible Block Name, independent from subtype and stable ID. `Print` and `Everything Flows` receive independent first-available suffixes within each owning container and subtype; compatible defaults remain visible when an older definition has no explicit name, and duplicate names chosen manually remain valid. The Flujo panel edits the selected block by ID through scene-context Undo/Redo: Enter applies, Escape discards the draft and returns to its selected row, and F2 from that row focuses Block Name with its text selected. F2 is the general block-rename affordance for future containers that expose selected `FlowBlock` editing. Rename actions are labelled `Rename Ready Block` or `Rename Timer Block`; the tooltip documents the same keys. Execution continues to resolve subtype and ID, never the visible name.

Traceability: READY-001/002 map to the existing graph/container model plus `FlowPrintBlock` and `FlowEverythingFlowsBlock`; READY-003/004/005 map to `PVController`, `FlowReadyExecutor`, and `FlowRuntimeOutput`. Their focal evidence is `tests/runtime/flow_ready_runtime_test.tscn`. READY-006/009 map to `FlowGraphEditorCommands`, `FlowGraphInspectorProperty`, `FlowReadyProcessEditor`, and the Process/Timer editor focal plus the Ready authoring case in `tests/editor/flow_graph_editor_commands_test.gd`. READY-007/008 separate automated evidence from manual acceptance. The associated commit is identified by Git history rather than duplicated as a mutable SHA here.

## Process and Timer authoring delivery

The following approved requirements are implemented and covered by automated tests; manual visual review remains pending.

- **TIMER-001:** schema 3 keeps its existing polymorphic `processes` collection. `FlowTimerDefinition` extends `FlowProcess`, adds `interval_seconds: float = 1.0` and `repeat: bool = false`, and uses the appended `ProcessType.TIMER` member without renumbering existing members. This is the sole persistent source; the Inspector's Timers section is a filtered view, never a second collection. Timer definitions require schema 3. Existing schema 2→3 migration and null positions remain unchanged; schema 4 is unnecessary.
- **TIMER-002:** Timer identity, ownership, block duplication and persistence reuse process invariants. Intervals must be finite and strictly positive. Invalid data remains literal and generates deterministic diagnostics; invalid timers never start.
- **TIMER-003:** enabled timers start when a runtime controller enters the tree. Internally owned Godot Timer nodes have no scene owner, never run under editor hint, and stop on program disable or tree exit. One-shot timers execute once; repeating timers execute until stopped. Re-enabling the program does not implicitly restart a stopped timer in this delivery. Definitions remain read-only.
- **TIMER-004:** Ready and Timer share the same block handlers and output boundary. Existing `message_emitted(controller, process_id, block_id, message)` remains compatible; an additional contextual event carries the same fields plus the entry point (`Ready` or `Timer`). No lifecycle blocks, monitor or debugger transport are added.
- **TIMER-005:** schema 3 Inspector owns only collection headings, Add buttons and selection lists for Processes, Timers, Variables, and the pre-existing State Machines collection. Each collection independently assigns new default visible names as `Flujo`, `Flujo 1`, `Flujo 2`, and so on, without renaming existing entries or preventing manually chosen duplicates. All selected Process, Timer, and Variable configuration and Move/Delete actions belong in the Flujo panel. State Machine editing remains deferred. Existing schema 1/2 compatibility remains unchanged.
- **TIMER-006:** Add Process/Timer selects and focuses the Inspector row. Add Print focuses its draft text; Add Everything Flows focuses its block row. Ctrl+Enter commits Print once and returns to that block; Enter inserts a newline and Escape discards the draft. The tooltip documents Ctrl+Enter. Move, Delete and Undo/Redo preserve stable-ID selection; F4 remains unchanged.
- **TIMER-007:** focal tests cover the Inspector relay, panel-only configuration, deliberate focus, grouped process actions, ResourceSaver/PackedScene, ordered output, one-shot/repeat, invalid/disabled timers, cleanup and Ready regression. Timer callbacks can be driven through their public timeout signal for deterministic scheduler tests, with a bounded native one-shot check.
- **TIMER-008:** Timers use neutral presentation. Future process types such as `_ready`, `_process`, and `_physics_process` may receive an approved type-color system, but this delivery adds no process colors and no Page Up/Page Down navigation.

## Tests

The `tests/model/flow_model_smoke_test.tscn` scene validates schemas 1 through 3, IDs, deep duplication, `null` positions, schema source exclusivity, structural persistence, and `FlowVariableDefinition.ValueType` compatibility for variables and method parameters.

It can be run manually by opening that scene in Godot and pressing **F6**.

`tests/editor/flow_graph_editor_commands_test.gd` runs in a headless editor and covers creation, migration, renaming, moving, valid and rejected removal, preservation of instances and IDs during undo/redo, presenter refresh, and validation without mixed sources.

## Iteration 5 final audit

The iteration delivers schema 2 typed collections, deterministic validation, explicit schema 1→2 migration, read-only presentation, and undoable Inspector editing. The default `schema_version` remains `1` for legacy resources. Automatic migration, block or internal-state editing, dock or executor changes, and editor dependencies in runtime were not implemented.

## Location and portability

Project-owned content is organized under `res://flow/`. Installed packages use `res://flow_packages/<package_id>/`, where `package_id` is stable and suitable for portable paths. `res://addons/vp_flujo/` is reserved exclusively for plugin-distributed code and resources.

The model does not use absolute paths, operating-system-specific separators, external processes, or editor-only APIs. Its runtime code uses APIs available in exported games on platforms supported by Godot 4.7.2.

Todo es Flujo; todo fluye. 🌊
