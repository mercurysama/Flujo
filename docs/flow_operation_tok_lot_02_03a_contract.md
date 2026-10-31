# Flujo — Lot 02 + 03A: Operation Tok, value resolution and Godot basic types

## Status

Implementation target: `feature/block-builder-fprint-dogfood`.

This delivery establishes the public Operation Tok boundary and extends the
shared Literal/ValueSource type system. It does not implement SceneTree access,
`$`, NodePropertyRef, call frames, attributes, collections, Resources, or null.

## Akis trigger vocabulary

- `@` — Variable/Memory family.
- `#` — Condition Tok.
- `~` — Operation Tok.
- `$` — reserved for the future Scene/Property family.

Active escapes include `\@`, `\#`, `\~`, and `\\`. The dollar sign remains
literal in this delivery.

## Operation Tok

Public model:

- `FlowOperationValueSource`
- `FlowOperationSegment`
- `FlowOperationOperatorCatalog`
- `FlowOperationEditor`

The older `FlowExpression*` resources remain loadable and are not migrated or
deleted. New arithmetic authoring belongs to Operation Tok.

The MVP operator catalog is exact and non-coercing:

| Operator | Signatures |
|---|---|
| `add` | int+int, float+float, Vector2+Vector2, Vector3+Vector3 |
| `subtract` | int-int, float-float, Vector2-Vector2, Vector3-Vector3 |
| `multiply` | int*int, float*float |
| `divide` | int/int → int, float/float → float |
| `modulo` | int%int |
| `concat` | String+String |

There is no implicit int/float promotion and no bool/int coercion in Operation
Tok. Bool/int compatibility remains local to Condition equality.

Integer division truncates toward zero. Division and modulo by zero return
structured `FlowValueResult.fail(...)` diagnostics instead of crashing.

## Value resolution

`FlowValueResolutionContext` is an ephemeral `RefCounted` boundary. It owns a
graph reference plus runtime variable-value overrides; runtime data is not
written into persistent definitions.

`FlowVariableRefValueSource.resolve()` accepts either this context or the
legacy `FlowGraph` path. A context runtime value wins when present and must
match the exact declared `Variant.Type`. The legacy graph-only path continues
to read the authored/default variable value for compatibility.

Literal, VariableRef, Operation and Condition therefore share:

`FlowValueSource.resolve(context) -> FlowValueResult`

## Operation editor

A new Operation draft has no semantic defaults:

- operator: `Select operation...`
- each operand: `Select source...`
- Literal type: `Select type...`
- Variable type is derived from `FlowGraph.variables` and appears only after a
  real variable is selected.

Confirm remains disabled until the operator, both sources, values/references and
schema compatibility are valid. Existing Operation Toks reopen with persisted
content. Insert/edit is routed through the owning Akis history.

## Godot basic Literal types

In addition to bool, int, float, String and StringName, the shared Literal
boundary now accepts:

- Vector2
- Vector2i
- Vector3
- Vector3i
- Color
- NodePath

The generic Literal Tok editor provides component controls for vectors,
ColorPickerButton for Color, and text authoring for NodePath. These values remain
native Variants through ResourceSaver/ResourceLoader; they are not serialized
through display text.

Operation MVP consumes Vector2/Vector3 only for exact add/subtract signatures.
The other new literal types are transport/editor support for future consumers,
especially the `$` Scene/Property family.

## Persistence and identity

Operation persistence preserves:

- segment_id
- slot_id / slot_kind
- source_id
- operator_id
- ordered operand sources
- operand source IDs
- variable_id
- literal Variant.Type and native value

Deep duplication creates new owned source IDs while external variable IDs remain
references.

## Focal evidence

Added:

- `tests/model/flow_operation_lot_02_03a_test.gd`
- `tests/model/flow_operation_lot_02_03a_test.tscn`
- `tests/editor/flow_operation_lot_02_editor_test.gd`

The model focal covers exact signatures, arithmetic, zero failures, String
concatenation, runtime variable overrides, Vector2/Vector3 operations, all 03A
literal types, deep duplication and ResourceSaver/Loader round-trips.

The editor focal covers `~`, `\~`, reserved literal `$`, no-default drafts,
Confirm, insertion, slot metadata, existing-Tok editing and Akis Undo/Redo.

GitHub currently has no workflow in `.github/workflows` for running these Godot
editor/model tests remotely, so test execution remains a separate Godot gate;
the files and focal scenes are committed with the implementation.
