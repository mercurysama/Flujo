# Flujo — Lot 05: composed value sources

## Scope

Lot 05 connects the existing Akis value-source families without introducing
recursive expressions yet.

Condition and Operation operands can now use:

- Literal
- VariableRef
- NodePropertyRef

The following remain outside this lot:

- Operation as an operand of another Operation
- Operation as a nested Condition operand
- nested Conditions
- NOT
- explicit grouping / parenthesized precedence
- Object / Resource / Array / Dictionary values

Those belong to the following composition/nesting lot.

## Runtime composition

Both Condition and Operation already resolve each operand through:

`FlowValueSource.resolve(context) -> FlowValueResult`

Lot 05 extends their accepted operand kinds to NodePropertyRef, so scene
properties participate in the same runtime boundary as variables and literals.

Examples:

- `$Target.z_index > 0`
- `$Target.visible == true`
- `$Target.position + Vector2(1, 2)`

Node properties are re-read on every resolution. There is no snapshot copy of
the scene value.

Exact type rules remain unchanged:

- Condition uses its existing comparison signatures.
- Operation uses its existing exact operator signatures.
- NodePropertyRef does not grant implicit int/float promotion.
- bool/int compatibility remains limited to Condition equality/inequality.

## Validation and preview

Condition and Operation now:

- structurally accept NodePropertyRef operands;
- validate Requirement IDs against the active FlowGraph when present;
- propagate NodePropertyRef runtime diagnostics;
- preserve exact property Variant.Type;
- render nested previews using `$Node.property`.

A property whose type is not part of the selected operator/comparison signature
cannot make the parent Tok valid.

## Nested authoring UX

Condition Editor and Operation Editor expose the same source menu:

1. Select source...
2. Variable
3. Literal
4. Node Property

No source is selected by default.

### Variable

Variable continues to use the existing Flow variable selector. Its type is
derived and read-only.

### Literal

Literal continues to expose an explicit type/value editor. No type is silently
selected.

### Node Property

Selecting Node Property:

1. opens the shared Scene Node panel;
2. the user chooses or drags a scene node;
3. `FlowNodePropertySelector` shows only properties whose exact Variant.Type is
   compatible with the current operand position;
4. selecting the property creates a NodePropertyRef draft;
5. the operand displays `$Node.property` plus a read-only derived type badge.

The reusable editor boundary is:

`FlowNodePropertyOperandPicker`

It owns no persistent Requirement mutations.

## Cancel behavior

Nested NodeProperty selection is draft-only while Condition/Operation is open.

Cancelling the parent popup:

- clears the Scene Node panel request target;
- closes any nested property selector;
- creates no Requirement;
- creates no Akis history action.

This keeps Condition/Operation Cancel side-effect free.

## Requirement promotion

When the complete parent Condition/Operation is finally confirmed by
`FlowChipFieldEditor`, nested scene sources are traversed.

For every nested NodePropertyRef:

- an existing Requirement binding is reused when possible;
- a direct child of the active PVController may be promoted to the existing
  Schema-4/5 Requirement model;
- descendant nodes retain their relative NodePath fallback under the current
  Lot-04 contract.

Requirement creation remains a separate undoable action immediately before the
parent Tok action, using the same Akis history owner.

## Production scene context

`FlowChipFieldEditor.configure(...)` now recognizes a PVController action
owner and automatically derives:

- active FlowGraph
- active PVController
- edited scene root

Therefore structured Akis documents instantiated by block editors receive the
same scene context as the manual harness without requiring every caller to wire
it separately.

Explicit `set_variable_graph()` and `set_scene_context()` APIs remain
available for harnesses and specialized hosts.

## Identity and persistence

A NodePropertyRef nested inside Condition/Operation remains a normal owned
ValueSource.

Deep duplication:

- renews owned source IDs;
- preserves Requirement identity;
- preserves NodePath/property/type semantics.

ResourceSaver/ResourceLoader persist nested NodePropertyRef resources inside
their parent Condition/Operation without flattening them into text.

## Manual review harness

The Structured Document Harness now includes:

- CONDITION — Variable / Literal / Node Property operands
- OPERATION — Variable / Literal / Node Property operands
- SCENE PROPERTY — standalone `$` authoring
- EXPRESSION — legacy compatibility

Suggested manual checks:

- Condition: `$Node.z_index > 0`
- Condition: `$Node.visible == true`
- Operation: `$Node.position + Vector2(...)`
- switching a source from Variable/Literal to Node Property
- Cancel during node/property selection
- edit an existing composed Tok
- Undo/Redo parent Tok plus auto Requirement

## Focal evidence

Added:

- `tests/model/flow_composed_sources_lot_05_test.gd`
- `tests/model/flow_composed_sources_lot_05_test.tscn`
- `tests/editor/flow_composed_sources_lot_05_editor_test.gd`

The model focal covers live Condition/Operation resolution, exact signature
enforcement, nested preview, duplication and persistence.

The editor focal covers the reusable property picker, exact compatible-property
filtering, Node Property source presence in both parent editors, derived type
badges and Confirm readiness.

As in Lots 02–04, these Godot focal sources are committed but the repository
still has no GitHub workflow that executes Godot. A real Godot 4.7.2 run remains
the formal execution gate.
