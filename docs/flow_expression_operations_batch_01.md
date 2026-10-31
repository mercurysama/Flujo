# Flujo — Operations batch 01 (2026-10-31)

## Scope

Extends the existing structural `FlowExpressionValueSource` operator catalog,
without replacing it, parsing textual code, adding nesting, creating a `~`
trigger, or implementing runtime evaluation. The existing Condition Tok remains
separate. The Expression popup derives its choices from the catalog.

## Operator IDs and exact type signatures

- Existing: `add` (`int,int -> int`; `float,float -> float`; `String,String -> String`),
  `greater_than`, `equal`, `and` are unchanged.
- `subtract`: `int,int -> int`; `float,float -> float`.
- `multiply`: `int,int -> int`; `float,float -> float`.
- `divide`: `int,int -> int`; `float,float -> float`, consistent with Godot's
  integer division semantics. Division-by-zero execution guards are deferred
  because this phase does not execute expressions.
- `modulo`: `int,int -> int` only.
- `concat`: `String,String -> String` only. Explicit concatenation uses the same
  `+` symbol as existing `add` for String operands; their persisted operator IDs
  are distinct.

No implicit `int`/`float` promotion or String coercion. All signatures accept
exactly two literal/variable-ref operands; nested expressions remain deferred.

## Fixed regression

`FlowConditionEditor._on_connector_selected` must receive the selection index
first and its bound connector index second. A two-row Condition must update its
connector, preview and Confirm state immediately when AND/OR is selected,
without inserting a third row.

## Tests

- `tests/model/flow_expression_step_2c_b_test.tscn`: signatures, invalid mixes,
  preview, source/document validation, legacy regressions, persistence.
- `tests/editor/flow_expression_editor_usability_focal_test.gd`: dynamic operator menu.
- `tests/editor/flow_condition_editor_step_2c_c_2_test.gd`: immediate AND/OR
  selection and existing C.2 regression suite.

This is a code patch proposal: test execution in the complete Godot checkout is
required before acceptance. The existing Step 2C-B contract describes that
historical delivery and is not retroactively rewritten.
