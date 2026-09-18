# Declarative Constructor Contract

## Status and scope

This is an approved design contract for a future schema 4 delivery. It is not implemented. Schema 3 keeps its existing executable `FlowConstructorDefinition` behavior intact: its enabled blocks run once before Ready. No schema 3 resource is silently reinterpreted as declarative.

The schema 4 Constructor describes required scene components for the object controlled by a `PVController`. It does not execute general blocks, create scene nodes automatically, or replace Godot's native `_init`.

## DCON-001 — Explicit schema boundary and migration

Schema 4 introduces the declarative Constructor. A migration must follow the explicit, atomic chain:

`schema 2 → schema 3 → schema 4`

Each step validates its source, builds an independent candidate, preserves valid IDs, references, order, and deliberate `null` positions, and leaves the source unchanged on success or failure.

Schema 3 Constructor blocks and dependencies are retained intact in schema 4 as legacy payload. They are inert in schema 4 and are never executed or applied as requirements. Migration requires explicit user confirmation when that legacy payload is non-empty. It must not infer node names, bindings, or component requirements from existing display names.

## DCON-002 — Constructed object and placement

The constructed object is the direct parent of the `PVController`. A required component is a direct child of that parent and therefore a sibling of the controller. The controller itself cannot satisfy a component requirement.

A controller without a valid parent has no constructed object. Applying its Constructor must fail deterministically without modifying the scene or graph.

## DCON-003 — Persistent requirement definition

`FlowRequiredNodeDefinition` is a future persistent resource with:

- an internal ID generated through `FlowId`;
- a visible `display_name`, `enabled` flag, and user note;
- `required_class_name: StringName`;
- `expected_node_name: StringName`;
- a `required` flag; and
- an ordered nullable collection reserved for future required-property definitions.

The requirement ID is its sole persistent identity. The display name, expected node name, collection position, and locator are not identity. The first vertical delivery permits an empty required-property collection only; it does not define property values, resources, `Node` references, `NodePath` values, `Object`, or `Callable` requirements.

Future property definitions require their own approved contract, stable IDs, deterministic validation, and typed value representation before a non-empty property collection may be authored.

## DCON-004 — Controller-owned bindings

Bindings belong to each `PVController`, not to the shareable `FlowGraph`. A binding maps:

`requirement_id → NodePath relative to the constructed object`

`requirement_id` identifies the requirement; the relative `NodePath` is only a scene-local locator. A graph never stores a direct `Node`, mutable scene reference, controller reference, or locator as requirement identity.

Bindings must be validated against the controller's current graph and constructed object. A stale, cross-graph, missing, or out-of-scope binding remains preserved for deterministic diagnostics; it is never silently redirected by name.

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

Traceability: DCON-001–012 → this contract → future model, editor, runtime, persistence, and lifecycle regressions → the commits listed above.

Everything is Flow; everything flows. 🌊
