# Flujo — Lot 08: complex structured values

## Scope

Lot 08 extends Akis with structured and semantic value sources without turning
Literal into a generic Variant container.

Implemented first-class source families:

- Array
- Dictionary
- ResourceRef
- Enum
- Bitfield

These families participate in schema validation, dedicated Tok projection,
editing, duplication, persistence and runtime resolution.

## Core boundary

Complex values are **not** stored as FlowLiteralValueSource.

Literal remains the scalar/basic boundary established in earlier lots.

New source kinds:

- `array`
- `dictionary`
- `resource_ref`
- `enum`
- `bitfield`

Shared Variant vocabulary now also exposes:

- `TYPE_ARRAY`
- `TYPE_DICTIONARY`

`TYPE_OBJECT` remains reference-only. No generic Object literal is introduced.

## Array

Persistent source:

`FlowArrayValueSource`

Tok:

`FlowArraySegment`

Produced type:

`TYPE_ARRAY`

An Array owns an ordered `Array[FlowValueSource]`.

Runtime recursively resolves every child through:

`FlowValueSource.resolve(context) -> FlowValueResult`

Therefore the model can preserve nested semantic sources such as:

- Literal
- VariableRef
- Operation
- Condition
- NodeRef / NodePropertyRef
- ResourceRef
- Enum / Bitfield
- Array / Dictionary

A child failure is propagated as a structured result instead of silently
flattening the source tree.

## Dictionary

Persistent source:

`FlowDictionaryValueSource`

Entry resource:

`FlowDictionaryEntry`

Tok:

`FlowDictionarySegment`

Produced type:

`TYPE_DICTIONARY`

Lot-08 Dictionary keys are deliberately **String-only**.

Each entry owns:

- stable `entry_id`
- String key
- FlowValueSource value

Keys are trimmed for semantic validation and runtime materialization. Empty or
duplicate normalized keys are invalid.

This MVP intentionally avoids arbitrary Variant dictionary keys so equality,
hashability and serialized identity remain deterministic.

## ResourceRef

Persistent source:

`FlowResourceRefValueSource`

Tok:

`FlowResourceRefSegment`

Produced type:

`TYPE_OBJECT`

ResourceRef is a project-resource reference, not an Object literal.

It persists:

- `resource_path`
- `resource_type_hint`

The path may reference any loadable project Resource under `res://`; the editor
is not limited to `.tres/.res`.

Runtime uses ResourceLoader and validates the expected class. Type matching
supports both native Resource classes and scripted `class_name` inheritance
through the associated Script chain.

An unbound ResourceRef placeholder is structurally valid and emits a warning,
but cannot resolve until a path is selected.

ResourceRef editing follows schema **reference** policy, analogous to NodeRef.

## Enum

Persistent source:

`FlowEnumValueSource`

Tok:

`FlowEnumSegment`

Produced runtime type:

`TYPE_INT`

Enum preserves:

- semantic enum name
- ordered option names
- explicit integer values
- selected integer value
- `has_selection`

Option names and values must be unique.

There is deliberately **no implicit selection**. An enum containing an option
whose value is `0` still remains unset until the user explicitly chooses an
option.

Example preview:

`Direction.Right`

Runtime result remains the declared integer value.

## Bitfield

Persistent source:

`FlowBitfieldValueSource`

Tok:

`FlowBitfieldSegment`

Produced runtime type:

`TYPE_INT`

Bitfield preserves:

- semantic bitfield name
- named flags
- integer flag values
- selected mask

Flag values must be positive, unique powers of two. This prevents overlapping
authored flag definitions.

Example preview:

`Permissions.Read | Write`

Runtime resolves to the integer mask.

## Structured editing

Reusable editor:

`FlowComplexValueEditor`

Akis toolbar entry:

`+ Structured`

The menu is schema-derived and only exposes source kinds/value types accepted at
the current semantic caret.

Available top-level choices:

- Array
- Dictionary
- Resource
- Enum
- Bitfield

### FLEXIBLE / HYBRID

`+ Structured` inserts a new source in an allowed variadic zone.

### FIXED

A FIXED complex slot is created by its schema/factory initial source and edited
in place.

This avoids pretending a generic insertion action is a FIXED-slot replacement.

## Collection editor MVP

The model accepts arbitrary nested FlowValueSources.

For direct creation inside Array/Dictionary, the Lot-08 editor currently
provides:

- scalar bool/int/float/String
- nested Array
- nested Dictionary

Existing other semantic child sources remain preserved and previewable. Nested
complex children can be reopened recursively.

A newly added scalar starts at:

`[Select type...]`

No scalar type/value is invented.

Expanding direct child-source creation to every Akis source family can reuse the
same source picker in a later UX pass without changing the persisted model.

## Resource editor

ResourceRef exposes:

- expected Resource class
- `res://` path
- project file browser

Confirm requires a selected path. Runtime remains the authoritative check that
the path is loadable and the Resource type is compatible.

## Enum / Bitfield editor

Enum editor exposes named integer options plus an explicit selected-option menu.

Bitfield editor exposes named power-of-two flags plus Enabled toggles.

Invalid/incomplete definitions keep Confirm disabled.

## Akis integration

Complex sources are first-class in:

- FlowChipFieldFactory
- FlowStructuredDocumentValidator
- FlowChipFieldValidator
- dedicated Tok classes
- FIXED/FLEXIBLE/HYBRID schema compatibility
- details panel
- `Edit Structured Value`
- Undo/Redo
- ResourceSaver / ResourceLoader

Editing an existing complex Tok preserves:

- segment_id
- source_id
- slot_id / slot_kind

Deep duplication renews owned collection/source/entry identities while external
references such as variable_id remain stable.

## Nested graph references

FlowValueSource now provides a graph-aware validation hook.

Array and Dictionary recursively invoke this hook for every child.

VariableRef now implements the same hook directly, so a missing/mistyped
variable is diagnosed even when deeply nested inside a collection.

Existing composite/reference sources continue to use their own graph validation.

## Shared previews

`FlowValueSourcePreview` renders semantic child previews without flattening
them into persistent text.

Collection preview dispatch avoids a direct Array/Dictionary class dependency
cycle, allowing recursive collections without cyclic parser coupling.

## VariableDefinition boundary

Lot 08 does **not** extend `FlowVariableDefinition.ValueType` or its Inspector
storage to Array/Dictionary/Resource.

That work touches variable definition storage, Inspector controls, commands and
runtime state together and is intentionally deferred to **Lot 09**, where
complex values will be integrated with real blocks/runtime.

This does not make complex sources second-class in Akis: they are already valid
schema values, nested sources and runtime-resolvable Toks. It only postpones
persistent graph-variable storage for those types until the runtime integration
lot can implement it coherently.

Enum/Bitfield are semantic int sources; existing int variables remain usable as
ordinary VariableRefs but do not automatically acquire enum/flag metadata.

## Scene-property boundary

Godot int properties carrying PROPERTY_HINT_ENUM or PROPERTY_HINT_FLAGS remain
NodePropertyRefs in this lot. Their live property semantics are preserved, but
they are not automatically converted into authored Enum/Bitfield constants.

Likewise Object-valued scene properties remain outside the basic
NodePropertyRef property picker until a later Object/Resource property expansion
is deliberately designed.

## Harness fixtures

The Structured Document Harness now includes:

- STRUCTURED — FLEXIBLE insertion surface for all five families
- ARRAY
- DICTIONARY
- RESOURCE
- ENUM
- BITFIELD

Existing scene/condition/operation fixtures remain available.

## Focal evidence

Added:

- `tests/model/flow_complex_values_lot_08_test.gd`
- `tests/model/flow_complex_values_lot_08_test.tscn`
- `tests/editor/flow_complex_values_lot_08_editor_test.gd`

Model focal covers:

- recursive Array/Dictionary resolution
- nested VariableRef and Operation
- normalized Dictionary keys
- ResourceSaver/ResourceLoader ResourceRef resolution
- Resource type mismatch
- unbound Resource warning
- explicit Enum selection
- Bitfield power-of-two rules
- factory projection for all five Tok types
- deep duplication
- complex-document persistence

Editor focal covers:

- schema-filtered `+ Structured`
- Array insertion
- fixed complex editing
- segment_id/source_id preservation
- Undo/Redo
- no-default collection scalar typing
- explicit Enum selection
- Resource path requirement

## Verification gate

The focal sources are committed but have not been executed in a real Godot
4.7.2 editor in this GitHub-only session.

The repository still has no configured GitHub workflow that runs these Godot
editor/model tests.

Therefore Lot 08 may be considered **implemented, pending the formal Godot
execution gate**, not formally PASS.
