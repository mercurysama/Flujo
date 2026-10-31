# FPrint Kínder — Chip Core Step 1B Contract

## Scope

Step 1B extends the runtime-safe Generic Typed Chip System with schema-driven
field instances and read-only validation. It follows Step 1A and deliberately
does not implement the definitive inline editor, caret, visual chip polish,
block execution, or an FPrint/For/If/Process block.

## Public runtime boundary

- `FlowChipFieldSchema` declares the expected field shape.
- `FlowChipFieldFactory` creates a new `FlowStructuredDocument` from that
  declaration without editor APIs or execution knowledge.
- `FlowChipFieldValidator` compares schema expectations with an existing
  document and returns deterministic `FlowDiagnostic` values without mutation.
- `FlowChipFieldTemplatePart` is schema-only data. Text parts become real
  `FlowTextSegment` resources; slot parts resolve by `slot_id`, never by array
  index or display label.
- `FlowChipSlotDefinition.initial_value_source` is a runtime-safe source
  prototype. The factory duplicates it for independent source identities. A
  literal factory result remains a `FlowLiteralValueSegment`, whose
  `value_type/value` fields remain the sole persistent legacy truth.

## Shape rules

- `FIXED` generates required slots and explicit optional defaults in declared
  order. A non-repeatable slot cannot exceed one instance.
- `FLEXIBLE` declares field-level minimum/maximum, accepted Variant types and
  source kinds. The factory creates only the minimum; a zero minimum starts
  empty.
- `HYBRID` combines named fixed slots with one repeatable variadic zone. The
  zone has its own semantic `slot_id` and chips mark the zone with
  `FlowChipSegment.SLOT_KIND_VARIADIC`; each occurrence still has its own
  `segment_id` and source identity.
- Documentation/runtime text is preserved as literal text segments. A
  `DISABLED` field produces no free-text segments; validation diagnoses any
  non-empty `FlowTextSegment` already present instead of deleting it.
- The ordered segment array remains the visual/semantic order. Associations
  are resolved by slot identity and zone kind, not position alone.

## Persistence and duplication

Schemas and generated documents are independently `ResourceSaver`-safe.
Reload preserves schema mode/text mode, slot declarations, limits, accepted
types/source kinds, template parts, segment order/IDs, slot associations and
literal values/types. Deep document duplication creates new segment IDs and new
source IDs where a source is a persisted identity, retains `slot_id` and
ordering, and does not share mutable resources with the original.

## Acceptance evidence

The focal automatic test is
`tests/model/flow_chip_core_step_1b_test.tscn`. It covers neutral FIXED,
FLEXIBLE, and HYBRID fixtures, missing/duplicate/type/order/count failures,
text policy, ResourceSaver round-trips, deterministic read-only diagnostics,
and independent duplication. Existing Step 1A, K1/K2, K3, K4 and FPrint
regressions remain separate evidence.

## Builder Lesson Candidates

> Los bloques con estructura FIXED deben generar automáticamente sus chips obligatorios desde `FlowChipFieldSchema`.

> Los schemas FLEXIBLE e HYBRID deben declarar límites y tipos permitidos; los bloques no deben implementar esas reglas mediante lógica privada.

> La validación de chips debe comparar schema contra documento mediante contratos públicos y diagnostics read-only.

> Cada bloque que utilice chips debe declarar un `FlowChipFieldSchema` reusable en lugar de implementar reglas privadas de cantidad, orden, tipos y obligatoriedad.

> Los valores ejecutables de chips deben expresarse mediante `FlowValueSource`, no mediante widgets o texto visible.
