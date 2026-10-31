# Flujo Chips Step 2B — Continuous Text Input + Complete Literal Insertion Contract

## Scope

Step 2B improves the reusable editor-side `FlowChipFieldEditor` from the Step
2A inline surface. It fixes continuous text editing and makes the public
literal insertion path expose every supported literal type. It does not add a
new value-source kind, parser, runtime block editor, or package-specific UI.

## Continuous text and native input

- Typing in a text segment is one continuous native `TextEdit` operation. The
  active `TextEdit` instance is not destroyed or recreated from its
  `text_changed` callback.
- Focus, caret position, and native selection remain owned by the active text
  control while text changes. Model/document notifications are incremental;
  a visual rebuild is only a fallback when the existing control cannot be
  updated in place.
- Godot's native text input remains authoritative for printable characters,
  Unicode, IME composition, and paste. The editor never reconstructs entered
  text from `InputEventKey.keycode` or applies ASCII/Latin-1 conversion.
- Spanish accents and inverted punctuation, `ñ`, umlauts, Japanese, Korean,
  emoji, multiline text, and pasted text remain exact literal content.

## Literal insertion

- Pressing `+ Value` opens one reusable literal-type selector. The selector
  offers the compatible subset of `Bool`, `Int`, `Float`, `String`, and
  `StringName`.
- Literal insertion uses these safe defaults: `false`, `0`, `0.0`, `""`, and
  `StringName()` respectively. It inserts one `FlowLiteralValueSegment` at
  the semantic caret position and preserves the existing segment IDs.
- FIXED fields keep their schema-generated chips and do not expose the
  additional-value selector. Required chip type controls are shown only when
  the schema permits more than one type.
- FLEXIBLE fields use their variadic slot and field-level accepted types.
  HYBRID fields use the variadic zone only and intersect field and slot
  accepted literal types before presenting the selector. A rejected type is
  never created first and diagnosed later.
- When `+ Value` has no insertable literal option, its feedback distinguishes
  the schema-derived cause: `Maximum chip count reached (N).`, `A chip cannot
  be inserted at this position.`, or `No compatible literal type is available
  here.`. The editor does not add block- or fixture-specific limits.
- Existing Variant.Type editing remains available for chips when the schema
  permits it; changing type uses the descriptor default without implicit
  conversion.

## Caret, String, StringName, and history

- After insertion, focus returns to the following text position so typing can
  continue immediately. A later insertion uses the current caret rather than
  a stale segment boundary.
- String and StringName value controls accept continuous native `LineEdit`
  input, including Unicode. `StringName` retains its declared Variant.Type.
- `StringName` remains a normal supported literal in this step; it may become
  an advanced/contextual option in a later delivery.
- Text/value changes use the owning `EditorUndoRedoManager` with reasonable
  merge behavior; accidental per-character surface reconstruction does not
  create independent destructive visual operations. Structural insertion,
  deletion, type changes, and value edits remain undoable and redoable with
  stable IDs.

## Review and exclusions

The neutral Tools-menu harness continues to expose FIXED, FLEXIBLE, and
HYBRID. Automatic evidence is
`tests/editor/flow_chip_field_editor_step_2b_test.gd`; the manual review
surface is `tests/editor/flow_structured_document_editor_harness.tscn`.
`demo/main.tscn` is protected and is not part of this delivery.

Step 2B explicitly does not implement `@`, `#`, `$` triggers,
`VariableRef`, `Expression`, `NodePropertyRef`, an Auxiliary Node Panel, drag
and drop, runtime-live tooltips, For/FPrint blocks, or final color/polish work.

The future literal escape convention `\@` → `@`, `\#` → `#`, `\$` → `$`, and
`\\` → `\` remains documented only and is not implemented by Step 2B.1.

## Builder Lesson Candidate

> La cantidad mínima/máxima de chips y los tipos/sources permitidos forman parte del `FlowChipFieldSchema` del bloque. La UI genérica debe consultar ese contrato y no implementar límites privados.
