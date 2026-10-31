# Flujo Chips Step 2C-B — Expression Tok

## Scope

Step 2C-B adds the generic structured Expression source and the `#` trigger to
the reusable `FlowChipFieldEditor`. An Expression is a value source composed of
one exact operator ID and two operands. It is structural data in this step; no
text parser, AST, runtime evaluation, node-property lookup, drag/drop, `$`
trigger, or FPrint migration is introduced.

The neutral editor harness exposes an Expression fixture. The protected
`demo/main.tscn` is not modified by this delivery.

## Persistent model

- `FlowExpressionValueSource` persists only `operator_id` and ordered
  `operands`, in addition to its inherited stable source ID.
- `FlowExpressionSegment` is the generic Expression Tok projection and keeps
  the normal segment ID, slot ID, and slot kind.
- Operands are only `FlowLiteralValueSource` or
  `FlowVariableRefValueSource`. Nested Expressions are not allowed.
- Duplication creates fresh segment/source/operand IDs while preserving the
  graph variable ID, operator ID, operand order, and slot identity.
- Preview text, result type, tooltip data, and validity are derived from the
  structured source; they are not additional persistent fields.

## Operator catalog and strict typing

The runtime-safe catalog exposes exactly these operator IDs:

| ID | Accepted signatures | Result |
| --- | --- | --- |
| `add` | `int,int`; `float,float`; `String,String` | matching operand type |
| `greater_than` | `int,int`; `float,float` | `bool` |
| `equal` | `int,int`; `float,float`; `bool,bool`; `String,String` | `bool` |
| `and` | `bool,bool` | `bool` |

Signatures are exact. There is no implicit numeric promotion, coercion, or
evaluation in this step. Invalid operator IDs, arity, operand kinds, operand
types, and graph VariableRef bindings remain authored and produce deterministic
diagnostics without repair.

## Schema and editor behavior

- Expression insertion is allowed only when the field/slot accepts the
  `expression` source kind and derived result type.
- Typing an unescaped `#` at the native caret opens the structured Expression
  editor and removes the trigger only after confirmation.
- `\#` is normalized to literal `#` and never opens the editor. `$` remains
  inactive text.
- The popup edits a detached draft. Operator and operand changes are not
  document history actions; Confirm creates one owning-document Akis action.
- Confirm inserts at the semantic caret, preserves the exact prefix/suffix,
  and uses the existing `FlowChipControl` surface. Editing an existing
  Expression Tok preserves its segment ID and slot metadata and creates one
  history action.
- Cancel restores the authored text, semantic caret, and focus without a
  history action. Keyboard focus starts on the operator control and Cancel/
  Confirm are reachable without a mouse.
- Existing unified Undo/Redo remains the sole public document history.

## Acceptance evidence and deferred work

Automatic evidence is `tests/model/flow_expression_step_2c_b_test.tscn` and
`tests/editor/flow_chip_field_editor_step_2c_b_test.gd`, plus the proportionate
chip-field/model/runtime regressions in the behavior catalog. Manual review must
cover the neutral EXPRESSION fixture, popup focus, operator/type filtering,
caret insertion, escaped `#`, `$` literal behavior, cancellation, existing Tok
editing, save/reopen, and Undo/Redo.

Deferred: `$`, NodePropertyRef, nested expressions, textual parsing, runtime
value resolution, drag/drop, FPrint integration, graph schema changes, and
`demo/main.tscn` changes.

## Traceability

`2C-B-MODEL-001` maps to the runtime source/catalog/segment and model focal;
`2C-B-EDITOR-001` maps to trigger, popup, insertion, edit, and history behavior
in `FlowChipFieldEditor` and `FlowExpressionEditor`; the manual acceptance
entry maps to the neutral harness. This delivery is ready for manual review
only after its automatic evidence is rerun successfully; it is not a completion
claim.
