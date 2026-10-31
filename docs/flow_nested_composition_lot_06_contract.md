# Flujo — Lot 06: nested composition, grouping and NOT

## Scope

Lot 06 extends Akis composition from sibling source families into a small
expression tree while keeping the Inspector/Akis surface readable.

Implemented:

- Operation as an operand of another Operation.
- Operation as an operand of Condition.
- Explicit grouped previews for every nested Operation.
- NOT for the complete Condition result.
- Recursive runtime resolution, validation, duplication and persistence.
- Recursive Operation authoring with a visual depth guard.

Still deferred:

- Condition as an operand of Condition.
- arbitrary boolean grouping trees;
- unary arithmetic operators;
- generic Object / Resource / Array / Dictionary values;
- implicit numeric promotion.

## Nested Operation semantics

`FlowOperationValueSource` now accepts these operand source kinds:

- Literal
- VariableRef
- NodePropertyRef
- Operation

The operator catalog itself is unchanged. Exact signatures still determine the
result type.

Examples:

- `(2 + 3) * 4`
- `Health + (Damage * 2)`
- `($Player.z_index + 2) * 4`
- `$Player.position + (OffsetA + OffsetB)`

Every nested Operation preview is surrounded by parentheses. Flujo intentionally
does not attempt to remove "unnecessary" parentheses: the preview mirrors the
semantic tree rather than relying on a reader to remember operator precedence.

Runtime evaluation already occurs recursively through
`FlowValueSource.resolve(context)`, so nested Operations reuse the same
`FlowValueResult` failure propagation as top-level Operations.

## Operation inside Condition

Condition operands now accept:

- Literal
- VariableRef
- NodePropertyRef
- Operation

Examples:

- `(Health + Armor) > Damage`
- `($Enemy.z_index + 2) >= Threshold`

The produced type of the nested Operation must match an exact Condition
comparison signature. A nested Operation does not bypass the existing strict
type rules.

## NOT

`FlowConditionValueSource` now persists:

`negated: bool`

NOT applies to the final combined Condition result, after all comparison rows
and AND/OR connector precedence have been evaluated.

Example:

`NOT (($Target.z_index + 2) > 10)`

The preview always renders the complete negated expression as:

`NOT (<condition>)`

This makes the scope of NOT explicit.

## Editor UX

### Operation Editor

The source selector now contains:

1. Select source...
2. Variable
3. Literal
4. Node Property
5. Operation

Choosing Operation creates an empty nested Operation draft and opens another
Operation Editor.

A nested operand displays:

- a button with grouped preview, e.g. `(2 + 3)`;
- a read-only produced-type badge.

The editor allows recursive authoring to
`MAX_EDITOR_NESTING_DEPTH = 6`. At the depth limit the Operation source option
remains visible but disabled. Existing authored resources remain model data; the
limit is an editor UX guard, not a hidden coercion rule.

### Condition Editor

The Condition operand selector also contains Operation.

A nested Operation is edited with the same Operation Editor and displays its
grouped preview plus produced type.

Condition Editor now includes:

`NOT — negate entire condition`

The checkbox is optional state, not a required semantic selector. New Conditions
remain non-negated unless the user explicitly enables NOT.

## Scene composition

Nested Operations can continue to contain NodePropertyRef operands.

At final parent Tok confirmation, `FlowChipFieldEditor` recursively traverses
Condition and Operation trees and applies the existing Requirement promotion
rules to every nested NodePropertyRef.

Cancelling an unfinished parent or nested popup does not create the parent Tok.

## Identity, duplication and persistence

Nested ValueSources remain owned semantic resources.

Deep duplication recursively renews:

- parent Operation source_id;
- nested Operation source_id;
- nested Literal / VariableRef / NodePropertyRef source IDs.

External Requirement identity is preserved.

ResourceSaver / ResourceLoader preserve:

- nested Operation structure;
- operand order;
- exact Variant.Types;
- Condition `negated`;
- NodePropertyRef locators and Requirement IDs.

## Manual review harness

The existing CONDITION and OPERATION harness tabs now describe nested
composition.

Suggested checks:

- Operation: `(Count + 1) * 2`
- Operation: `Count + (Health * 2)`
- Condition: `(Health + 2) > 10`
- Condition: `NOT ((Health + 2) > 10)`
- Condition using a nested Node Property Operation.
- Cancel a nested Operation and verify the parent draft is unchanged.
- Edit an existing nested Operation.
- Undo/Redo the final parent Tok.

## Focal evidence

Added:

- `tests/model/flow_nested_composition_lot_06_test.gd`
- `tests/model/flow_nested_composition_lot_06_test.tscn`
- `tests/editor/flow_nested_composition_lot_06_editor_test.gd`

The model focal covers:

- recursive arithmetic;
- explicit grouped preview;
- Operation inside Condition;
- NOT runtime semantics;
- live NodeProperty resolution through a nested Operation;
- strict signature preservation;
- deep duplication;
- ResourceSaver/ResourceLoader round-trip.

The editor focal covers:

- Operation source availability;
- nested grouped controls;
- produced-type badges;
- maximum visual nesting depth;
- Operation source availability inside Condition;
- persisted NOT restoration;
- NOT preview and draft mutation.

As in previous lots, the repository still has no GitHub workflow that executes
Godot editor/model focal tests. Godot 4.7.2 execution remains the formal PASS
gate.
