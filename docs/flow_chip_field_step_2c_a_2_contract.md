# Flujo Chips Step 2C-A.2 — Unified document history shortcuts

## Scope

Step 2C-A.2 freezes the keyboard history boundary for the generic
`FlowChipFieldEditor` introduced by Steps 2A through 2C-A.1. The editor's
owning Akis history is the only public document history for text edits, literal
Tok edits, Variable Tok replacement, and structural document operations.

This step does not add a trigger family. `#` and `$` remain literal text, and
Expression, NodePropertyRef, drag/drop, runtime value resolution, FPrint
migration, and changes to `demo/main.tscn` remain out of scope.

## Unified shortcut boundary

- `Ctrl+Z` requests exactly one undo from the history selected for the
  configured owning document context.
- `Ctrl+Shift+Z` and `Ctrl+Y` request exactly one redo from that same history.
- The shortcut is captured by `FlowChipFieldEditor._input()` before the focused
  native `TextEdit` or `LineEdit` GUI phase, and the viewport event is marked
  handled after the Akis operation succeeds.
- `FlowChipTextEdit`, `FlowChipLineEdit`, `FlowChipControl`, and native value
  boundaries may accept the already-routed shortcut, but never execute a
  second undo or redo and never call a nonexistent native `super._gui_input()`
  implementation.
- Native controls remain native for typing, paste, IME, selection, caret,
  navigation, and multiline editing. Their local history is not the public
  document history of the composite editor.

## Chronology and state

- Text edits, Tok edits, VariableRef binding changes, insertion, deletion, and
  movement share one chronological owning-document history.
- Undo and redo restore the authored document state and preserve stable
  segment/source identities, text content, selection policy, and the semantic
  caret/focus anchor where the existing editor contract requires it.
- A redo stack remains available after an undo until a new document operation
  is intentionally committed. Repeated shortcuts continue through the same
  history and do not fall back to a native child history.
- Selector cancellation and other no-op/cancellation paths remain history-free.
- The focal test waits for the editor layout initialization to finish before
  creating history actions; startup teardown/layout work must not be mistaken
  for a document shortcut result.

## Acceptance evidence

Automatic evidence is:

- `tests/editor/flow_chip_field_editor_step_2c_a_2_test.gd` for required
  literal history and mixed text/VariableRef chronology;
- `tests/editor/flow_chip_field_editor_history_shortcut_cycle_test.gd` for the
  minimal repeated shortcut cycle used while isolating startup timing;
- the existing Step 2C-A.1, Step 2C-A, K5, model, runtime, and editor
  regressions listed in the behavior catalog.

Manual review remains required for the neutral harness: native TextEdit and
LineEdit editing, Literal Tok and Variable Tok focus, mixed history, repeated
Undo/Redo, cancellation, and caret/focus restoration. The protected
`demo/main.tscn` is not part of this step.

## Traceability

`2C-A.2-HISTORY-001` maps the owning history lookup, shortcut routing, native
boundary acceptance, and mixed chronology to
`flow_chip_field_editor.gd`, `flow_chip_text_edit.gd`,
`flow_chip_line_edit.gd`, `flow_chip_control.gd`, and the editor focal tests.
