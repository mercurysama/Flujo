# Flujo Chips Step 2C-A.1 — Tok editability and semantic caret restoration

## Scope

Step 2C-A.1 is the policy and interaction correction immediately before the
next trigger family is specified. It makes Variable Toks explicitly editable
or immutable through the generic chip-field policy, keeps required presence
independent from mutation and deletion, and restores text focus/caret by
segment identity when an active `@` insertion or Variable Tok edit is
cancelled. It does not activate `#` or `$`.

The implementation remains generic editor/model infrastructure. It does not
know FPrint, For, If, Process, Timer, package types, expressions, nodes, or
property paths.

## Policy axes

`FlowChipFieldSchema` and `FlowChipSlotDefinition` expose independent policy
axes:

- `required` / effective minimum controls presence.
- `editable` controls whether an existing occurrence can be edited.
- `allow_delete` controls deletion, with a required occurrence never
  deletable even when an older/default definition leaves this flag enabled.
- `allow_type_change` and the effective accepted value-type set determine the
  type lock; a single accepted type is a lock, not an immutable-value flag.
- `allow_source_kind_change` and the effective accepted source-kind set
  determine the source-kind lock; a single accepted source kind is a lock, not
  an immutable occurrence.
- Content and VariableRef binding changes remain separate operations. A
  required Tok may therefore be editable while undeletable, and a Tok may be
  source/type locked while its permitted content or binding remains editable.

Field policy is the fallback for flexible content; a slot policy is more
specific when a slot is present. No editor path infers mutability from
`required`, `allow_delete`, a display name, an array index, or a descriptor's
display text.

## Variable Tok editing

- A VariableRef is selected by the generic `FlowChipControl` on click.
- Double-click or Enter opens the same schema/slot-filtered
  `FlowVariableSelector` used by `@`.
- The selector carries stable variable IDs, current binding, accepted types,
  source kinds, and lock context; it never edits a visible name as identity.
- Replacing a binding preserves the Variable Tok `segment_id`, `slot_id`, its
  document location, and the VariableRef `source_id`; it changes only
  `variable_id` and the declared type in one owning-document Undo/Redo action.
- An immutable Tok or a locked axis remains selectable and reports contextual
  feedback without creating history.
- Cancelling Variable Tok editing creates no model operation and returns focus
  to the same Tok by stable segment ID.

## Semantic insertion anchor and cancellation

While a selector is open, the editor retains a
`FlowChipSemanticInsertionAnchor` containing the text segment ID, local
codepoint offset, and nearest non-null semantic neighbors. It is transient
editor state, not persistent document data.

- Selecting a variable removes only the pending trigger and inserts/replaces
  through the existing source boundary.
- Cancelling removes the pending trigger without an undo action, restores the
  exact surrounding text, and restores the native `TextEdit` focus and caret
  at the semantic anchor, even after a visual rebuild or popup focus change.
- The same focus rule applies to selector cancellation during Variable Tok
  editing: the Tok remains selected and focused.
- Stable IDs are resolved before any fallback to semantic neighbors; array
  positions are never treated as identity.

## Literal and deferred trigger behavior

Only the already-approved active escapes are normalized: `\@` becomes a
literal `@`, and `\\` becomes one literal backslash. An unescaped `@` remains
the VariableRef trigger. `#` and `$` remain ordinary literal text and do not
open a selector or create history outside the native text edit.

`+ Value` remains a temporary harness/debug insertion path. It is not a
production package-specific authoring surface and is not expanded by this
step.

## Acceptance evidence

Automatic evidence is:

- `tests/editor/flow_chip_field_editor_step_2c_a_test.gd` for the existing
  2C-A trigger/selector regression;
- `tests/editor/flow_chip_field_editor_step_2c_a_1_test.gd` for policy axes,
  click/double-click/Enter editing, stable IDs, lock feedback, cancellation,
  semantic caret/focus restoration, escapes, and history;
- `tests/editor/flow_fprint_dogfood_editor_test.gd` and
  `docs/fprint_kinder_k5_contract.md` for the corrected escaped-`@` literal
  expectation;
- `tests/model/flow_variable_ref_step_2c_a_test.tscn` and the proportionate
  model/editor regressions.

Manual review remains required for the neutral harness: immutable and locked
Tok presentation, click/double-click/keyboard activation, popup cancellation,
caret/focus return after insertion cancellation, Undo/Redo, and literal
`#/$` text. `demo/main.tscn` is protected and is not part of this step.

## Traceability

- `2C-A.1-POLICY-001` → `FlowChipFieldSchema`,
  `FlowChipSlotDefinition`, effective-policy helpers, and the focal policy
  tests.
- `2C-A.1-TOK-002` → `FlowChipControl`, `FlowVariableSelector`, and
  `FlowChipFieldEditor` click/double-click/Enter editing with stable IDs and
  owning-document history.
- `2C-A.1-CARET-003` → `FlowChipSemanticInsertionAnchor`, cancellation paths,
  native focus/caret assertions, and escape/#/$ tests.
- `2C-A.1-FPRINT-004` → the K5 FPrint test/contract correction using `\@` for
  literal `@` while retaining literal `#/$`.
