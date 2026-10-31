# Flujo Chips Step 2C-A — `@` Variable Reference Contract

## Scope

Step 2C-A adds the first contextual value source to the reusable
`FlowChipFieldEditor`: a graph-owned `VariableRef` selected through an `@`
trigger. It is generic editor/model infrastructure and does not know FPrint,
For, If, Process, Timer, or any package-specific block.

## Persistent VariableRef boundary

- `FlowVariableRefValueSource` stores only its own stable `source_id`, the
  referenced `variable_id`, and the authored `declared_value_type`.
- `FlowGraph.variables` is the sole source of variable definitions. The editor
  does not create or maintain a parallel variable database.
- A variable display name is resolved from the active graph for labels and
  tooltips. Renaming a variable therefore changes presentation without
  changing the reference identity.
- The source does not store a visible name, collection index, `Node`,
  `NodePath`, or runtime value. Runtime value resolution remains deferred.
- `FlowVariableRefSegment` is rendered by the existing `FlowChipControl` and
  keeps `segment_id`, `slot_id`, and source identity through persistence,
  duplication, Undo, and Redo according to the runtime model contract.

## Trigger and selector

- Typing an unescaped `@` in a native text caret opens one reusable
  `FlowVariableSelector` popup.
- The selector reads graph variables and filters them by the field schema,
  variadic slot schema, declared type, and `variable_ref` source kind before
  display.
- Search receives focus when the popup opens. Arrow Up/Down moves the visible
  selection without requiring a mouse click; Enter confirms that selection and
  Escape cancels. Mouse and touch-capable item activation use the same stable
  variable ID selection signal.
- Selecting a variable removes the pending trigger and inserts one
  `FlowVariableRefSegment` at the semantic caret. Focus returns to the text
  position after the inserted chip.
- Cancelling the popup removes the pending trigger without creating a model
  operation. `#` and `$` remain literal and unactivated in this step.

## Variable Tok editing

- A VariableRef is selected by the generic `FlowChipControl`. Its contextual
  editor reports Source, Name, Variable ID, and Declared Type; the ID is not a
  directly editable label.
- Double-clicking a Variable Tok, or pressing Enter while it is selected, opens
  the same `FlowVariableSelector` used by `@`. The selector receives the active
  schema, slot/zone, accepted value types, accepted source kinds, and current
  variable ID, so replacement and insertion share one filtered popup.
- Choosing another definition preserves `segment_id`, `slot_id`, location, and
  the VariableRef `source_id`; it changes `variable_id` and declared type in one
  owning-document Undo/Redo action. Cancelling restores focus to the selected
  Tok and creates no operation.
- A missing reference remains unresolved and invalid. The same edit action can
  repair it only after the user explicitly chooses a valid graph variable.

## Schema behavior

- FLEXIBLE fields insert a VariableRef into their declared variadic zone,
  respecting field and slot type/source filters and maximum counts.
- HYBRID fields insert a VariableRef only in their declared variadic zone;
  required named chips remain governed by their fixed slot policy.
- FIXED fields do not add a chip. When the trigger is adjacent to a compatible
  generated fixed chip, selection replaces that chip's source while preserving
  its `segment_id`, `slot_id`, and slot kind.
- An incompatible position, source kind, type, or count leaves the document
  unchanged and emits generic schema-derived feedback.

## Escape and validation rules

- Only these active escape pairs are normalized during native text input:
  `\@` becomes literal `@`, and `\\` becomes literal `\`.
- An escaped `@` never opens the selector. The document parser remains unaware
  of `#`, `$`, expressions, and all deferred source kinds.
- Validation is read-only. With an optional active `FlowGraph`, a missing
  `variable_id` or a declared-type mismatch produces a structured diagnostic;
  the authored source is preserved and the visual chip is marked invalid.
- Without a graph context, structural source validation still runs while
  graph-resolution diagnostics remain deferred.

## Review and exclusions

Automatic evidence is:

- `tests/model/flow_variable_ref_step_2c_a_test.tscn`
- `tests/editor/flow_chip_field_editor_step_2c_a_test.gd`

The neutral harness remains `tests/editor/flow_structured_document_editor_harness.tscn`
and receives graph-owned review variables for manual inspection. Manual Godot
review is required before this delivery is accepted.

Step 2C-A explicitly does not implement `#`, `$`, Expression,
NodePropertyRef, drag/drop, an Auxiliary Node Panel, runtime variable values,
FPrint migration, For/FPrint blocks, or changes to `demo/main.tscn`.

The policy and cancellation correction is specified separately by [Step
2C-A.1 — Tok editability and semantic caret restoration](flow_chip_field_step_2c_a_1_contract.md).
That follow-up remains within the `@` boundary and must complete before a
future `#` or `$` trigger specification is started.

## Traceability

`2C-A-VAR-001` maps the stable source/segment model to
`flow_variable_ref_value_source.gd`, `flow_variable_ref_segment.gd`, the
structured validators, and the model focal test. `2C-A-EDITOR-001` maps the
trigger, selector, schema filtering, caret insertion, fixed replacement,
escape, resolution, and Undo/Redo behavior to `flow_chip_field_editor.gd`,
`flow_variable_selector.gd`, `FlowChipControl`, and the editor focal test.
