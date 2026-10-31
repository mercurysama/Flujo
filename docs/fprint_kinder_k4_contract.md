# FPrint Kínder K4 — Generic Chip Editor Contract

## Scope

K4 introduces the first editor-only visual representation for the reusable
`FlowChipSegment` contract. It does not migrate FPrint Guardería, change
`demo/main.tscn`, add a parser, or add runtime/editor coupling.

## Frozen boundaries

- `FlowChipControl` is the only reusable chip widget. It consumes
  `FlowChipSegment → FlowChipTypeDescriptor → label/tooltip/style role` and
  has no FPrint or literal-subtype branch.
- `FlowStructuredDocumentEditor` renders the ordered document as real text
  controls and real `FlowChipControl` children. `null` segment positions are
  preserved in the model and ignored visually.
- `+ Value` is the only K4 chip creation path. It creates an int literal with
  value `0`, inserts it after the current segment boundary, and records the
  operation in the owning `EditorUndoRedoManager` history.
- Variant editing is descriptor/contract-driven for bool, int, float, String,
  and StringName. A type change supplies the descriptor default; it never
  silently converts the old value.
- Selection, deletion, and insertion identify segments by `segment_id`.
- Tooltip text is assembled from `FlowChipTooltipData`; field names are not
  authored in `FlowChipControl`.
- Styling is editor Theme-derived. K4 consumes the `literal` semantic role;
  variable, expression, and node-property roles remain future mappings.
- The manual harness is an editor-only review surface. It is not an FPrint
  migration and does not create a second Revertir/snapshot system.

## Evidence

- Automatic focal: `tests/editor/flow_structured_document_editor_test.tscn`.
- Manual harness: plugin menu **Project → Tools → Open Structured Document
  Harness** (or open `tests/editor/flow_structured_document_editor_harness.tscn`
  in the editor).
- Protected file: `demo/main.tscn`; its K4 baseline checksum must remain
  unchanged.

K4 remains pending human visual approval until the manual checklist in the
delivery report is completed.
