# Flujo — Lot 04: Scene / Property family

## Status

Implementation target: `feature/block-builder-fprint-dogfood`.

Lot 04 activates the `$` Akis trigger and introduces a typed bridge from the
edited Godot SceneTree to Flujo ValueSources. It builds on the existing
Schema-4/5 Requirement model instead of creating a parallel node-identity
system.

This lot intentionally does **not** add generic Object, Resource, Array,
Dictionary or null values.

A selected SceneTree Node is therefore an **editor authoring payload**, not a
persisted Node/Object ValueSource. Persistent semantics are the Requirement
binding (when applicable) plus the typed NodePropertyRef. A standalone Node
value Tok belongs to the later Object/Resource expansion.

## Trigger vocabulary

- `@` — Variable / Memory.
- `#` — Condition.
- `~` — Operation.
- `$` — Scene Node → Property.

Active text escapes now include:

- `\@`
- `\#`
- `\~`
- `\$`
- `\\`

Typing an unescaped `$` does not create a semantic default. Akis enters a
pending node-selection state and opens the Scene Node panel.

## Scene Node panel

`FlowSceneNodePanel` is mounted at the editor-base boundary and is independent
from persistent FlowGraph state.

Behavior:

1. It projects the current edited SceneTree.
2. The edited scene root is selectable/draggable too.
3. Each item carries an editor-only payload with:
   - scene-root-relative NodePath
   - node name
   - built-in class name
   - existing Requirement ID when a binding is already known.
4. The panel is placed on the side opposite Fluo.
5. When Fluo switches side, the Node panel follows that relationship.
6. An open panel refreshes after SceneTree/editor context changes.
7. A node can be double-clicked while a `$` request is pending or dragged into
   an Akis field.

Drag/drop is forwarded across the Akis surface, TextEdit controls and existing
Toks, so the drop target is the field rather than an empty-space hit box.

## Property selection

After a node is chosen, `FlowNodePropertySelector` reads
`Node.get_property_list()` and exposes only properties that:

- use one of Flujo's currently supported exact basic Variant types;
- match the active field/slot's accepted Variant types;
- are editor- or storage-visible properties.

The selector has no semantic defaults. Search is textual, Confirm remains
disabled until a real property is selected, and the authored type comes from
Godot property metadata rather than from an editable type selector.

## NodePropertyRef

Persistent source:

`FlowNodePropertyRefValueSource`

Persistent semantic fields:

- `requirement_id`
- `node_path`
- `node_name_hint`
- `property_name`
- `declared_value_type`

Tok projection:

`FlowNodePropertyRefSegment`

Preview form:

`$Node.property`

The source uses exact Variant typing. A resolved property's metadata and its live
value must both match `declared_value_type`.

## Requirement identity and fallback paths

The preferred semantic locator is an existing Schema-4/5 Requirement ID.

A scene-root-relative `node_path` is also persisted as an authoring/repair
fallback. Resolution order is:

1. `PVController.requirement_bindings[requirement_id]`, when available.
2. The persisted scene-root-relative `node_path`.

This lets Requirement-backed references survive scene-local rebinding while
still allowing pre-Requirement graphs and descendant nodes to participate.

When a selected node is a **direct child of the active PVController** and the
graph uses Schema 4 or 5, confirming the property automatically creates or
reuses one `FlowRequiredNodeDefinition` plus the scene-local
`requirement_bindings` entry.

Descendant nodes are not forced into the current direct-child Requirement
contract; they keep the relative NodePath fallback.

## Runtime resolution

`FlowValueResolutionContext` now carries optional scene context:

- `graph`
- `controller`
- `scene_root`
- runtime variable-value overrides

`FlowNodePropertyRefValueSource.resolve(context)` returns
`FlowValueResult` and reports structured diagnostics for:

- missing scene context
- unresolved node
- missing property
- property type mismatch
- invalid/missing Requirement reference

No scene data is written back during resolution.

## Supported property value types

Lot 04 uses the basic value boundary established in Lot 03A:

- bool
- int
- float
- String
- StringName
- Vector2
- Vector2i
- Vector3
- Vector3i
- Color
- NodePath

Object/Resource/container expansion remains a future lot.

## Akis integration

NodePropertyRef participates in:

- FIXED/FLEXIBLE/HYBRID source-kind checks
- exact slot/field value-type checks
- source-kind/type locks
- insertion at the semantic caret
- edit/replacement while preserving segment_id
- tooltips and details panel
- structured-document validation
- ResourceSaver/ResourceLoader persistence
- Akis Undo/Redo

The `$` trigger text is removed only after a confirmed property selection.
Cancel removes the pending trigger and restores the semantic caret.

## Undo / Redo

Auto-binding a new Requirement and inserting the Node Property Tok are two
separate undoable actions, intentionally ordered in the same Akis history:

1. Bind Scene Node Requirement.
2. Insert Node Property.

Therefore one Undo removes the Tok while leaving the reusable Requirement, and a
second Undo removes the auto-created Requirement/binding. Redo restores them in
the same order.

The binder is pinned to the same EditorUndoRedoManager history owner used by the
Akis document to keep this ordering deterministic.

## Persistence and identity

NodeProperty persistence preserves:

- segment_id
- slot_id / slot_kind
- source_id
- requirement_id
- node_path
- node_name_hint
- property_name
- declared Variant.Type

Deep duplication changes owned segment/source IDs and preserves external
Requirement identity plus the authored property locator.

## Review fixture and focal evidence

Added automated focal sources:

- `tests/model/flow_node_property_ref_lot_04_test.gd`
- `tests/model/flow_node_property_ref_lot_04_test.tscn`
- `tests/editor/flow_node_property_lot_04_editor_test.gd`

The model focal covers:

- fallback NodePath resolution
- Requirement-first resolution
- live property reads
- missing property/type/context diagnostics
- graph Requirement validation
- duplication
- ResourceSaver/ResourceLoader round-trip

The editor focal covers:

- exact compatible-property filtering
- `\$`
- `$` pending node state
- node selection → property selector
- direct-child auto Requirement binding
- Tok insertion
- runtime resolution
- ordered two-step Undo/Redo

The Structured Document Harness also includes a **SCENE PROPERTY** fixture for
manual review in a real edited scene.

## Verification gate

The repository currently has no configured GitHub workflow that executes these
Godot editor/model focal tests. The implementation and test sources are
committed, but a real Godot run remains the execution gate before declaring a
formal PASS.
