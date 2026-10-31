# Flujo Chips Step 2C-B.1 — Expression Editor Usability + Persistence

## Scope

This correction keeps the Step 2C-B semantic model and operator catalog intact
while making the Expression draft usable in the neutral review harness. It does
not add `$`, NodePropertyRef, nesting, parsing, runtime evaluation, StringName
Expression operands, or new operators.

## Draft editor contract

- Selecting `Variable` rebuilds the operand row immediately and exposes
  `Choose variable`; no unrelated control change or polling is required.
- A missing VariableRef keeps its authored draft state, previews as `<missing>`,
  and prevents Confirm. Selecting a variable stores only its stable `variable_id`
  and derives the declared type from the graph variable.
- Literal `int`, `float`, and `String` operands expose a focused `LineEdit`.
  Bool exposes a `CheckButton` labelled True/False. Valid edits update the
  detached draft and preview immediately; incompatible type changes use the
  typed default, while non-type UI changes preserve the current value.
- String preview uses quotes and treats Unicode, whitespace, `@`, `#`, `$`, and
  backslash as content of the popup control, not Akis triggers.
- Existing Expression Toks open with a deep detached draft containing the full
  operator, operand order, VariableRef IDs, literal types, and literal values.
  Confirm replaces the source through one document Undo action; Cancel is
  history-free.

## Harness persistence

The neutral harness exposes **Save Expression Fixture**, **Reload Saved
Expression**, and **Reset Saved Expression**. Save writes a controlled review
resource below `.godot/flujo_tests/expression_harness/` for both the document and
its fixture graph. Reload uses `ResourceLoader` with cache ignored and rebuilds
the EXPRESSION tab from those resources. This is review-harness state, not a
production save path.

The round-trip must preserve segment ID, slot ID/kind, Expression source ID,
operator ID, operand order, Literal type/value, VariableRef source ID and
variable ID; preview is regenerated from the reloaded model and graph.

## Acceptance evidence

The model focal performs a real `ResourceSaver.save()` → `ResourceLoader.load()`
round-trip for `Count + 1`. The editor focal covers reactive controls, typed
literal editing, variable selection, `Count + 1`, `Health > 0`,
`Enabled AND Visible`, `Message + "!"`, existing-Tok editing, cancellation, and
Undo/Redo. Manual review remains required for visible layout, focus, keyboard
navigation, and harness close/reopen.
