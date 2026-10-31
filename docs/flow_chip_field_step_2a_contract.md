# Flujo Chips Step 2A — Inline Chip Field Contract

## Scope

Step 2A defines the first reusable visual editor for a schema-backed
`FlowStructuredDocument`. The editor is editor-only and is not a block editor.
It must work without knowing FPrint, For, If, Process, or any other concrete
block.

## Public editor boundary

- `FlowChipFieldEditor` consumes one `FlowChipFieldSchema` and one
  `FlowStructuredDocument`.
- `FlowStructuredDocumentEditor` remains a compatibility name for callers that
  already consume the structured-document editor; it delegates to the generic
  field editor.
- `FlowChipControl` is the only visual chip widget. It consumes the generic
  `FlowChipSegment` descriptor, label, tooltip data, and semantic style role.
- Future source insertion enters through
  `insert_value_source_at_caret(source)`; the editor does not know the
  SceneTree or a node/property picker.

## Inline and caret invariants

- Text and chip controls share one ordered inline flow. Text is edited by real
  `TextEdit` controls, so the caret is a character position rather than a
  segment index.
- Inserting inside a text segment preserves the original text segment before
  the caret, inserts one semantic chip, and creates the following text segment.
  Undo restores the exact previous text and segment arrangement.
- Text is literal: whitespace, multiline content, Unicode, `@`, `#`, and `$`
  are preserved without trigger parsing.
- Chip navigation and deletion operate on the complete `segment_id`; a chip
  label can never be edited as ordinary text.

## Schema interaction

- FIXED fields may be initialized from `FlowChipFieldFactory`. Required chips
  obey their slot `allow_delete` and `allow_reorder` rules.
- FLEXIBLE and HYBRID fields insert and remove only through their declared
  limits and accepted source/type rules. A rejected max-count operation leaves
  the model unchanged and emits visible feedback.
- Validation is read-only. Existing invalid data is displayed with a minimal
  diagnostic; the editor never repairs, deletes, coerces, or normalizes it.

## Editing and history

Literal values support `bool`, `int`, `float`, `String`, and `StringName`.
Changing type uses the descriptor default and never implicitly converts the
old value. Text edits, value edits, type changes, insertion, deletion, and
allowed movement are recorded through the owning `EditorUndoRedoManager`.
Segment IDs, slot IDs, and source identity are retained by undo/redo where the
runtime model provides that identity.

## Review boundary

The neutral harness exposes FIXED, FLEXIBLE, and HYBRID fixtures from the Godot
editor Tools menu. Automatic tests cover model/UI round trips and keyboard
boundaries; visual approval remains a human gate. Step 2B is not part of this
contract.

## Explicitly deferred

Triggers (`@`, `#`, `$`), `VariableRef`, `Expression`, `NodePropertyRef`, live
runtime tooltip values, Auxiliary Node Panel, drag and drop, real For/If/
Process blocks, FPrint integration, and Prefix/Suffix cleanup.
