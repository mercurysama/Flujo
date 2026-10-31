# Flujo Chips Step 2C-C.2 — Condition Tok UI

## Scope

This delivery adds the editor-only visual authoring surface for the C.1
`FlowConditionValueSource`. It does not add Operation Tok (`~`), `$`, NOT,
groups, nesting, arithmetic, or a runtime live-value system.

## Trigger and compatibility

- An unescaped `#` opens `FlowConditionEditor` and never the legacy Expression
  popup.
- `\#` remains literal text.
- Expression model classes and the direct legacy Expression editor remain
  available for compatibility; Expression is not removed or converted.

## Editor contract

The popup edits a detached draft. A new Condition starts with one empty
comparison row: both sources and the comparison are explicitly unselected.
Each additional row is preceded by one positional AND/OR connector and has a
remove action. The visual order is the persisted `comparisons` order;
drag/reorder is not implemented.

New operand rows begin at `Select source...`; neither Variable nor Literal is
selected automatically. Variable selection first shows `Choose variable...`
without a type badge; after a real graph variable is selected, the read-only
badge is derived from `FlowGraph.variables`. No editable variable type selector
is shown. Selecting a compatible graph variable updates the draft immediately
and preserves that operand's `source_id`. Literal selection first shows
`Select type...`; int, float, bool, and String value controls appear only after
an explicit type choice, with no implicit `0` value.

Operator availability and validity use the C.1 exact signatures. Validation is
immediate. Equality permits bool/int with the C.1 true→1 and false→0 semantics;
ordering does not. String supports only `==` and `!=`. Preview is derived and
uses `<missing>` for unresolved references, quotes String literals, and displays
AND before OR without adding parentheses.

Connectors begin at `Select connector...`; no implicit AND is inserted. Confirm
is enabled only for a valid complete draft and records one structured
document history action. Cancel restores the semantic caret or selected Tok,
does not mutate the document, and does not create history. Existing Condition
Toks open the same editor on Enter/double-click; replacement preserves the
segment identity and document Undo/Redo restores the complete source.

## Schema boundary and review

Condition insertion produces bool and uses the active schema's accepted source,
type, `slot_id`, and `slot_kind` policy for FIXED, FLEXIBLE, and HYBRID fields.
The reusable variable selector supports mouse/touch and Up/Down/Enter/Escape.
The harness exposes a clearly labelled CONDITION fixture with manual cases for
Health > 0, Lives == 1, Enabled == true, Enabled == 1, Message != "hola", and
multiple AND/OR rows. `demo/main.tscn` is protected.
