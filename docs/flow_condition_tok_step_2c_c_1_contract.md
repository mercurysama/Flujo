# Flujo Chips Step 2C-C.1 — Condition Tok semantic model

## Scope

This contract prepares the semantic model for the later comparison-row UI. It
does not implement the C.2 multi-row editor, `+ Add condition`, a popup redesign,
or any final visual sketch.

The trigger meaning is now:

- `#` = **Condition Tok**.
- `~` = reserved candidate for a future **Operation Tok**; it is not active.

Expression/add remains a legacy/transitional source. It is not converted to
Operation Tok by this delivery.

## Persistent model

`FlowConditionValueSource` extends `FlowValueSource` and persists its own
`source_id`, ordered `comparisons`, and positional `connectors`. Every
`FlowConditionComparison` persists a stable `comparison_id`, `operator_id`,
`left_source`, and `right_source`. The initial operand boundary accepts only
`FlowLiteralValueSource` and `FlowVariableRefValueSource`.

`connectors.size() == comparisons.size() - 1` whenever there is more than one
comparison (and is zero for one comparison). Connectors do not need IDs.

`FlowConditionSegment` is the generic chip projection and owns no duplicate
condition data: its inherited `value_source` is the `FlowConditionValueSource`.

## Operators and type signatures

The independent `FlowConditionOperatorCatalog` exposes:

- `equal` → `==`
- `not_equal` → `!=`
- `greater_than` → `>`
- `less_than` → `<`
- `greater_or_equal` → `>=`
- `less_or_equal` → `<=`
- connectors `and` and `or`

The exact signatures are:

- `int` with `int` for all six comparisons;
- `float` with `float` for all six comparisons;
- `String` with `String` only for equality/desigualdad;
- `bool` with `bool` only for equality/desigualdad;
- `bool` with `int`, and `int` with `bool`, only for equality/desigualdad.

There is no implicit `int`/`float` promotion, String ordering, or boolean
ordering. Bool/int equality maps `true` to `1` and `false` to `0`; any other
integer is simply unequal, not an error. `not_equal` inverts equality.

## Type, validity, and resolution

`FlowConditionValueSource.get_value_type()` always returns `TYPE_BOOL`, even
when validation fails. Validity is independent from produced type.

Validation checks IDs, comparisons, operators, operands, exact signatures,
connector values/count, and graph-owned VariableRefs. VariableRef metadata is
only a persisted compatibility projection: `FlowGraph.variables` is the sole
authoritative type/name source and mismatches are diagnosed without repair.

`FlowValueResult` is an ephemeral `RefCounted` result with `success`, `value`,
`value_type`, and structured `diagnostic`, plus `ok()` and `fail()` factories.
`FlowValueSource.resolve(context)` is the future runtime boundary. Literal
resolution is implemented; a FlowGraph context can resolve a VariableRef to
its authored default. Live runtime state and a parallel executor remain
deferred. Invalid conditions fail resolution while retaining `TYPE_BOOL`.

## Preview and precedence

Preview is derived, never persisted. It shows the current graph variable name,
`<missing>` for an unresolved reference, and quoted String literals. Examples:

```text
Health > 0
Enabled == true
Health > 0 AND Lives > 0
Message != "hola"
```

`AND` has conventional precedence over `OR`; no groups, nesting, or NOT exist
yet. Thus `A AND B OR C` is `(A AND B) OR C`, and `A OR B AND C` is
`A OR (B AND C)`.

## Duplication and persistence

Condition duplication deep-copies the source, comparisons, operands, and
connector array. Copied source IDs and comparison IDs are fresh; external
VariableRef `variable_id` bindings remain unchanged. ResourceSaver/Loader
round-trips preserve source/comparison IDs, operator and connector order,
literal type/value, and VariableRef source/variable IDs. Preview and produced
type are derived.

## Compatibility and boundaries

The new `SOURCE_KIND_CONDITION` is additive and supported by the generic chip
factory, descriptor/tooltip projection, structured-document validation, and
existing persistence boundary. Expression classes and tests remain intact.
No schema migration, Operation Tok, runtime live-value system, or C.2 UI is
introduced.
