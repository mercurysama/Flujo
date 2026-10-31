# FPrint Kínder K5 — Structured Document Package Integration Contract

## Scope

K5 integrates the already reusable `FlowStructuredDocument`, generic structured
document renderer/editor, and public Generic Typed Chip System into the ordinary
`mercury.fprint` package path. K5 preserves the closed FPrint Guardería surface
and does not declare functional `flujo-block-builder v1` or FPrint v1 complete.

The package remains an ordinary user-created package under
`res://flow_packages/mercury.fprint/`. It does not install a package runtime
dependency, parser, private chip type, private editor, registry entry, graph
schema, or manifest v1 field.

## Capability gate

The request is classified per the Builder A/B/C/D gate before implementation:

| Area | Classification | K5 decision |
| --- | --- | --- |
| FPrint package field and output contract | A — SDK-supported now | Add one ordinary exported `FlowStructuredDocument` property and keep the existing public `FlowOutputBlock` contract. |
| Process runtime, ResourceSaver and PackedScene persistence | A — SDK-supported now | Reuse the existing polymorphic block, resource and generic executor paths. |
| Generic Flusso descriptor and editor for a structured-document resource | C — SDK extension required | Extend the reusable runtime-safe descriptor and host renderer once, without identifying FPrint or any concrete chip subtype. |
| FPrint-specific control-flow, parser, or private editor | D — core-only / out of scope | Do not implement or silently patch Flujo core. |

The C requirement is satisfied only by a public, reusable structured-document
presentation kind. No package-specific branch is an acceptable substitute.

## Frozen behavior

- `prefix`, `message`, and `suffix` remain exported and persistable.
- `document` is an optional exported `FlowStructuredDocument`, defaulting to
  `null`.
- When `document == null`, output remains exactly
  `prefix + message + suffix`.
- When `document != null`, the rendered document replaces `message`, so output
  is `prefix + rendered_document + suffix`.
- An invalid present document produces the renderer's explicit empty text
  result; K5 does not repair or silently fall back to `message`.
- The generic Flusso surface shows `Enable Structured Document` for a null
  document. It does not auto-convert legacy `message` content.
- A present document uses `FlowStructuredDocumentEditor`, `FlowChipControl`,
  and the public `FlowChipSegment`/descriptor contract. FPrint does not own a
  visual chip widget or a second structured editor.
- Structured-document edits are live and use the owning `PVController` editor
  undo history. Revertir restores the session-opening document snapshot with
  segment IDs, order, values, Unicode, multiline text, and deliberate null
  positions intact.
- In native text input, literal `@` is authored as `\@` because unescaped `@`
  is the generic VariableRef trigger; `#` and `$` remain literal in this
  delivery.
- The existing Guardería behavior, public authoring ID, manifest v1 shape,
  graph schema, legacy `message` field, and protected `demo/main.tscn` remain
  unchanged.

## Acceptance evidence

Automatic evidence must cover:

1. descriptor discovery of a null and present structured-document property;
2. Flow Add and generic Flusso rendering without a FPrint-specific editor;
3. enabling a document, editing text and typed values, insertion/deletion,
   Undo/Redo, and session Revertir;
4. exact legacy and structured Process output;
5. FlowGraph ResourceSaver and PackedScene persistence, including segment
   classes, IDs, order, values, Variant.Type, and null positions;
6. runtime/editor boundary audits and preservation of the K4 focal test.

Manual evidence remains separate and must inspect the real Flusso surface for
the empty enable state, the rendered document/chip, selection, tooltip,
multiline and Unicode text, escaped-`@` plus literal `#/$` handling,
Undo/Redo, Revertir, save/reopen, and independent FPrint instances.

## Builder Lesson Candidates

- A package that needs optional structured content should declare the public
  document property and consume the generic descriptor/editor path; it should
  not convert legacy text implicitly.
- A package that needs mixed text and typed values should use the public
  `FlowStructuredDocument` and Generic Typed Chip System; it should not create
  `FPrintChip`, a subtype-specific chip, or a private editor.
- A package's runtime output should consume the reusable renderer and preserve
  its legacy scalar field as an explicit compatibility path.

## Protected boundary

K5 does not migrate existing FPrint data, add a parser, introduce Variables,
Expressions, `VariableRef`, `NodePropertyRef`, new chip types, Timer or State
Machine claims, or functional Builder v1. The K5 delivery may update the
behavior catalog and iteration handoff, but must not update the Builder Skill
without independently verified reusable evidence.
