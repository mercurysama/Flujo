# Declarative Constructor Contract

## Status and scope

The schema 4 persistent foundation is implemented: requirement definitions, structural validation, deep duplication, explicit 3→4 and chained 2→3→4 migration, and controller-owned serialized bindings. The rest of this contract remains planned. Apply Constructor, node creation, scene binding resolution, runtime verification, and the declarative editor are not implemented. Schema 3 keeps its existing executable `FlowConstructorDefinition` behavior intact: its enabled blocks run once before Ready. No schema 3 resource is silently reinterpreted as declarative.

The current executor and Timer scheduler still accept only schema 3. Schema 4 is data-only in this delivery: neither legacy Constructor blocks nor Ready/Timers execute. Mandatory-requirement gating described below is future behavior, not a completed runtime feature.

The schema 4 Constructor describes required scene components for the object controlled by a `PVController`. It does not execute general blocks, create scene nodes automatically, or replace Godot's native `_init`.

## DCON-001 — Explicit schema boundary and migration

Schema 4 introduces the declarative Constructor. A migration must follow the explicit, atomic chain:

`schema 2 → schema 3 → schema 4`

Each step validates its source, builds an independent candidate, preserves valid IDs, references, order, and deliberate `null` positions, and leaves the source unchanged on success or failure.

Schema 3 Constructor blocks and dependencies are retained intact in schema 4 as legacy payload. They are inert in schema 4 and are never executed or applied as requirements. Migration requires explicit user confirmation when that legacy payload is non-empty. It must not infer node names, bindings, or component requirements from existing display names.

Implemented APIs are `FlowGraphMigrator.migrate_schema_3_to_4(source, confirm_legacy_payload = false)` and `migrate_schema_2_to_4(source)`. The latter invokes the existing 2→3 step and then 3→4, exposing only the final successful candidate. Confirmation covers non-empty `blocks` or `dependencies`, including deliberate null-only arrays. Their original fields remain the sole stored legacy payload; `constructor.requirements` starts empty. Deep migration includes externally stored subresources without renewing IDs.

## DCON-002 — Constructed object and placement

The constructed object is the direct parent of the `PVController`. A required component is a direct child of that parent and therefore a sibling of the controller. The controller itself cannot satisfy a component requirement.

A controller without a valid parent has no constructed object. Applying its Constructor must fail deterministically without modifying the scene or graph.

## DCON-003 — Persistent requirement definition

`FlowRequiredNodeDefinition` is an implemented persistent resource with:

- an internal ID generated through `FlowId`;
- a visible `display_name`, `enabled` flag, and user note;
- `required_class_name: StringName`;
- `expected_node_name: StringName`;
- a `required` flag; and
- an ordered nullable collection reserved for future required-property definitions.

The requirement ID is its sole persistent identity. The display name, expected node name, collection position, and locator are not identity. The first vertical delivery permits an empty required-property collection only; it does not define property values, resources, `Node` references, `NodePath` values, `Object`, or `Callable` requirements.

Future property definitions require their own approved contract, stable IDs, deterministic validation, and typed value representation before a non-empty property collection may be authored.

The implemented `constructor.requirements: Array[FlowRequiredNodeDefinition]` accepts ordered `null` positions in schema 4. Schemas 1–3 reject a non-empty requirements collection. `required_properties: Array[Resource]` is a storage-only reservation: any non-empty array, including `[null]`, is invalid; no property resource class or value semantics is implemented. Requirement display names must be non-empty but need not be unique; IDs remain their identity. Expected node names must be non-empty valid single node names. Required classes must exist in `ClassDB`, derive from `Node`, and be instantiable; validation never instantiates them.

Requirements participate in the existing graph-wide identity registry and duplication map. Graph and isolated-constructor duplication preserve type, metadata, order, null slots, and deep independence while renewing requirement IDs. Schema 4 retains structural validation and duplication of its legacy blocks, dependencies, methods, and typed collections.

## DCON-004 — Controller-owned bindings

Bindings belong to each `PVController`, not to the shareable `FlowGraph`. A binding maps:

`requirement_id → NodePath relative to the constructed object`

`requirement_id` identifies the requirement; the relative `NodePath` is only a scene-local locator. A graph never stores a direct `Node`, mutable scene reference, controller reference, or locator as requirement identity.

Bindings must be validated against the controller's current graph and constructed object. A stale, cross-graph, missing, or out-of-scope binding remains preserved for deterministic diagnostics; it is never silently redirected by name.

The implemented storage is `PVController.requirement_bindings: Dictionary[String, NodePath]`, hidden from the Inspector. Assignment copies the dictionary so controllers and PackedScene instances do not share mutable binding maps even when they share one graph. Graph duplication neither copies nor remaps these scene bindings.

`FlowGraphValidator.validate_requirement_bindings(graph, bindings)` currently validates only serialized structure: schema 4, a valid unique requirement ID in that graph, and a non-empty relative direct-child locator without subnames. It does not resolve nodes, require bindings for every requirement, check the parent or expected target, or enforce runtime gates. Those scene-dependent checks remain deferred.

## DCON-005 — Existing-node detection

Applying a requirement follows one deterministic order:

1. Validate its existing binding, if present.
2. If it has no binding, search only direct children of the constructed object, excluding the controller itself, for the exact expected name and a compatible class.
3. Adopt exactly one compatible existing child by creating a binding.
4. Create one child only when no matching child exists and preflight has succeeded.

Multiple compatible matches, an occupied expected name with an incompatible class, or an invalid binding are errors. The implementation must not guess, rename an existing node, create a suffixed replacement, or create a duplicate.

## DCON-006 — Explicit, atomic editor application

`Apply Constructor` is an explicit editor action. Selecting a controller, opening a scene, migration, validation, saving, and game startup never mutate a scene automatically.

Before application, the editor performs a full preflight of every requested requirement: controller and parent validity, class availability and instantiability, expected name, binding state, ambiguity, required properties, edited-scene ownership, and editability of the target branch. Any failure prevents the entire action.

The successful operation is one `EditorUndoRedoManager` action whose context is the owning `PVController`. It adds or adopts nodes, sets the correct scene owner, updates bindings, and notifies the existing editor paths. Undo restores the prior nodes and bindings; Redo reapplies them. The action relies on Godot's scene history rather than a parallel dirty-state mechanism or automatic saving.

## DCON-007 — Scene ownership and inherited scenes

Created nodes receive the owner required by the currently edited scene so that they persist through normal Godot saving. The editor must use Godot's editable-scene and editable-instance checks before creating a node.

If the target parent belongs to a non-editable inherited or instanced branch, application reports a deterministic diagnostic and makes no change. It must not modify a source scene, make an instance local automatically, or assign an owner from another scene.

## DCON-008 — Runtime verification only

Runtime never creates, owns persistently, or saves required components. It resolves controller-owned bindings and verifies that valid scene nodes already exist.

An absent or invalid mandatory requirement prevents Ready and Timers for that controller without changing `visual_program_enabled`, the `FlowGraph`, or the scene. An absent optional requirement reports a warning and permits unrelated execution. Runtime resolution is per controller instance and is released with that instance.

## DCON-009 — First vertical delivery

The first planned vertical delivery is limited to **Require Node**:

- built-in, instantiable classes derived from `Node`;
- an enabled requirement with a non-empty expected node name;
- direct-child placement under the constructed object;
- adoption or creation through explicit Apply Constructor;
- controller-owned relative bindings; and
- runtime verification without creation.

Project global classes, property requirements, resources, `CollisionShape2D` configuration, `Sprite2D`, `AnimationPlayer`, nested placement, automatic repair, and conversion of legacy constructor data remain out of scope.

## DCON-010 — Deterministic diagnostics

Validation and application preserve invalid authored values and report stable code, path, related ID, and order. The minimum diagnostic set includes:

- `required_node_class_missing`;
- `required_node_class_not_node`;
- `required_node_name_empty`;
- `required_node_name_conflict`;
- `required_node_ambiguous`;
- `required_node_binding_invalid`;
- `constructor_parent_missing`;
- `constructor_scene_not_editable`; and
- `required_node_missing`.

Requirement diagnostics use `constructor.requirements[i]` paths. Controller binding diagnostics use the controller binding collection and relate to the preserved requirement ID when available.

Implemented requirement diagnostics run after inherited schema 3 structural validation and before method-call references, in collection order: identity, display name, class, expected node name, then reserved properties. Existing schema 1–3 diagnostic order is unchanged for their existing data. Additional implemented codes are `requirements_incompatible_schema`, `required_node_class_not_instantiable`, `required_node_name_invalid`, `required_properties_unsupported`, `bindings_incompatible_schema`, and `migration_confirmation_required`; empty display names and identity errors reuse existing codes. Binding checks sort requirement-ID keys lexicographically and use `requirement_bindings["<id>"]` paths. Scene-dependent codes in the list above remain planned.

## DCON-011 — Editor accessibility

The Inspector retains the single Constructor structural row. The Flujo dock owns requirement authoring, diagnostics, status, and Apply Constructor.

Requirement lists must retain stable-ID selection, keyboard focus, arrows, Tab, Shift+Tab, Enter, Escape, F2 rename behavior, and confirmed deletion where applicable. Status must include text and must not rely on color alone. Apply Constructor must be reachable by keyboard without adding a global shortcut in the first delivery.

## DCON-012 — Required evidence

The delivery is accepted only with deterministic coverage for:

- schema 2→3→4 migration, source immutability, legacy-payload preservation, and confirmation;
- global identity, validation, duplication, ResourceSaver, and PackedScene persistence;
- adoption without duplication, creation with the correct owner, Undo/Redo, save/reopen, and independent controller bindings;
- absent parent, invalid class, ambiguity, name conflict, stale binding, and non-editable inherited or instanced branches without partial mutation;
- runtime verification that never creates nodes, mandatory gating, optional warnings, and teardown; and
- real editor interaction, keyboard access, diagnostics, selection, focus, and scene dirty/save behavior.

Manual visual review must cover an empty Constructor, an adopted node, a created node, Undo/Redo, save/reopen, inherited and instanced-scene rejection, selection changes, and keyboard navigation.

## Risks and implementation sequence

The principal risks are silent schema reinterpretation, duplicate component creation, incorrect Godot owner assignment, modification of a source scene, stale bindings, and divergent editor/runtime behavior. The design rejects runtime-only construction, automatic scene mutation, raw node references in the graph, and reuse of `display_name` as an implicit node locator because those alternatives violate persistence, sharing, or user-control invariants.

The planned implementation sequence is:

1. `docs: define declarative constructor contract`
2. `feat: add schema 4 constructor requirements`
3. `feat: apply required nodes through scene undo redo`
4. `feat: verify constructed scene requirements at runtime`
5. `test: cover declarative constructor lifecycle`
6. `docs: record declarative constructor delivery`

Foundation traceability: DCON-001 → `FlowGraphMigrator`; DCON-003 → `FlowRequiredNodeDefinition`, `FlowConstructorDefinition`, `FlowGraph`; DCON-004 → `PVController.requirement_bindings`; DCON-010 → `FlowGraphValidator` and `FlowDiagnostic`. Their new automated evidence is `tests/model/flow_schema_4_foundation_test.gd`, covering validation, migration, duplication, ResourceSaver, PackedScene, and binding isolation. Apply, runtime, accessibility, and remaining DCON-012 lifecycle evidence belong to the subsequent planned commits; this foundation does not claim their completion.

Everything is Flow; everything flows. 🌊
