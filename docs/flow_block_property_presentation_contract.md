# FlowBlock Property Presentation Contract

## Status and scope

This document is the D4-A contract delivery for the generic FlowBlock property
boundary.

- **D4-A status:** complete.
- **D4-B status:** descriptor implementation complete in the runtime/model layer.
- **D4-C status:** renderer implementation complete with automatic PASS evidence and
  approved manual visual Flusso review.
- **Production renderer:** implemented by D4-C in the editor host.
- **Runtime Game Debug Panel:** not implemented by this delivery. Its future
  requirement is recorded as an architectural constraint below.
- **Control-flow blocks:** `IF`, `While`, `Do` / `Do While`, and `For` remain
  future custom blocks and are not created or implemented here.
- **Manifest and graph schemas:** no fields, schema versions, or migrations are
  added by this contract.

This contract refines `BLKECO-008`, `BLKECO-009`, `BLKECO-018`, and
`BLKECO-019` in [Flujo Block Ecosystem Contract](block_ecosystem_contract.md).
It preserves the D3 owned-property boundary and the model/runtime separation in
the [Flujo Model Technical Contract](model_contract.md).

The contract freezes architecture and terminology only. The D4-B and D4-C
implementation records below describe the approved implementation against this
boundary; this document does not authorize the future `flujo-block-builder`
functional delivery or any package generation.

## Architectural boundary

The reusable boundary is a data projection, not an editor widget API:

```text
FlowBlock instance/resource
        │
        ├─ Godot property reflection (model truth)
        └─ optional validated block-property presentation metadata
                         │
             generic property description
                         │
          consumer-specific adapter and policy
                ┌────────┴────────┐
                │                 │
             Flusso          future Game Debug Panel
       editor authoring       runtime inspection/editing
```

The property-description layer must not depend on:

- `EditorInterface`;
- `EditorPlugin`;
- `EditorUndoRedoManager`;
- `FlowEditorBlockAuthoringContext`;
- editor docks, Inspector properties, or editor `Control` nodes.

The layer describes a property and its safe presentation intent. It does not
create controls, apply editor undo, save scenes, execute callbacks, or decide
whether a runtime target is authorized for debugging.

### D4-A requirement labels

The following labels are stable references for the D4-A contract and future
implementation evidence.

| Label | Frozen requirement |
| --- | --- |
| `D4A-PROP-001` | Model reflection is authoritative for property existence, type, usage, hints, current value, and persistence eligibility. |
| `D4A-PROP-002` | Generic authoring exposes only the approved reflected property set and never arbitrary `Object`/`Resource` state. |
| `D4A-PROP-003` | A descriptor is UI-independent and contains no editor API or executable callback. |
| `D4A-PROP-004` | Optional presentation metadata can refine safe presentation only; it cannot create or retype a model property. |
| `D4A-PROP-005` | The v1 type set is `bool`, `int`, `float`, `String`, and `StringName`, with only compatible standard Godot hints. |
| `D4A-PROP-006` | Generic property ordering is deterministic and independent of container type. |
| `D4A-PROP-007` | Flusso owns a property only after an active editable control renders and registers it. |
| `D4A-PROP-008` | Editor authoring and runtime debug mutation are separate state and persistence contracts. |
| `D4A-PROP-009` | Invalid metadata produces deterministic diagnostics and a reflection fallback without changing the model. |
| `D4A-PROP-010` | The shared description path is reusable from runtime code without Godot editor APIs. |

## 1. Source of truth

### 1.1 FlowBlock and Godot reflection

The `FlowBlock` script and the live model instance remain authoritative.

1. A property exists for generic discovery only when the reflected property list
   reports it on the selected `FlowBlock` instance and the eligibility rules in
   this contract accept it.
2. The reflected `PropertyInfo.type` is the model type. Metadata may not replace
   it with another type or coerce it into another type.
3. Reflected `usage`, `hint`, and `hint_string` are model/presentation facts
   supplied by Godot. A metadata declaration may select only an approved,
   compatible presentation of those facts.
4. The current value is read from the selected instance with the reflected
   property name. A descriptor may carry a value snapshot for a consumer, but it
   is not a second storage location or cache of authority.
5. A default value comes from the script/model construction path (for example an
   exported initializer or `_init()`), never from presentation metadata. A
   descriptor may omit `default_value` when the model cannot provide it without
   an unsafe or ambiguous construction step.
6. A property is persistable only according to the model's storage usage and
   normal Godot resource/scene persistence. Metadata cannot make a non-storage
   property persistent.

The reflected type and the actual current `Variant` value must be compatible.
An unexpected value/type mismatch is a diagnostic and is not repaired by
coercion. The property is not offered as an editable generic field in that
case.

### 1.2 Presentation metadata

Presentation metadata is optional and subordinate to reflection. It may provide
safe presentation intent such as a label, order, group, tooltip, or an approved
generic presentation kind. It may not:

- declare a property not present on the `FlowBlock`;
- declare a default or current value;
- change `PropertyInfo.type`, storage, usage, hint semantics, or persistence;
- introduce a nested property path or an object graph traversal;
- provide a setter, callback, expression, `Callable`, script, scene, resource
  loader, or arbitrary code.

When metadata is absent, the reflected property remains fully usable when it
meets the generic rules. Absence of metadata is not an error.

## 2. Eligible properties

Generic **editor authoring** uses the following fail-closed eligibility rule. A
candidate must be a direct property of the selected `FlowBlock` and must have
all of the following:

- the Godot 4.7 script-variable marker (`PROPERTY_USAGE_SCRIPT_VARIABLE`);
- `PROPERTY_USAGE_STORAGE`, because authoring edits must represent persistent
  model data;
- `PROPERTY_USAGE_EDITOR`, because the script explicitly exposes it to an
  authoring surface;
- a supported v1 model type, or a supported read-only representation as defined
  in section 7.

The candidate is rejected when it has an internal/no-editor usage flag, is a
property category/group marker rather than a value, is the native `script`
property, or has a private/internal name beginning with `_`. A property that is
only `@export_storage` is not a generic authoring candidate merely because it is
serializable. Runtime-only values and arbitrary properties inherited from
`Object`/`Resource` are not candidates merely because `get_property_list()` can
see them.

This rule includes normal exported script fields such as an external block's
`message`. It does not expose `_internal_id`, storage-only references, runtime
state, nodes, resources, or editor internals.

### 2.1 Read-only concepts

If a reflected candidate has a supported type but carries a Godot read-only
usage flag, its descriptor may be included with `editable = false` for safe
inspection. A read-only descriptor is never registered as Flusso-owned and is
never written by generic authoring. A future runtime consumer may choose to
display it without introducing a write path.

### 2.2 Explicit built-in controls

The following are the current pre-D4 explicit Flusso properties:

- `display_name`;
- `enabled`;
- `text` for the existing Print control;
- `method_id` for the existing Call Method control.

They remain owned by their existing explicit controls when those controls are
actually rendered. The generic property surface must exclude an actively
explicitly-owned name before rendering generic fields, so a reflected property
cannot produce a duplicate control. `method_id` is storage-only and therefore
does not become generic solely through reflection; its existing explicit method
selector remains an editor concern.

The rule is not that these names are globally owned by Flusso. A property on a
`FlowBlock` is not thereby Flusso-owned. Ownership is established per active
surface and per selected block only after a control is rendered and registered.

`user_note` is not part of the current explicit ownership set. If a future D4-B
generic surface renders it under the ordinary eligibility and type rules, that
rendered control owns it for that Flusso session. If it is not rendered, it is
untouched.

No property is eligible for a generic control merely because its name resembles
one of these fields, and no future `IF`, `While`, `Do`, `Do While`, or `For`
branch is permitted.

## 3. Generic property descriptor

The descriptor is a conceptual, UI-independent value object. D4-A does not
freeze a particular GDScript class or serialization API, but a v1 implementation
must provide the following information without importing editor APIs.

| Information | Requiredness | Authority/meaning |
| --- | --- | --- |
| `property_name` | required | Direct reflected `StringName`; the only model lookup key. |
| `model_type` | required | Reflected `Variant.Type`; never metadata-defined. |
| `usage` | required | Reflected usage flags needed to distinguish editor/storage/read-only state. |
| `hint` and `hint_string` | required when present | Reflected Godot hint data, validated before it influences presentation. |
| `editable` | required | Derived capability; false for read-only or rejected write paths. It is not an authorization policy. |
| `current_value` | optional snapshot | Value read from the supplied live instance when safely available. |
| `default_value` | optional snapshot | Model-provided default only; absent when not deterministically available. |
| `label` | optional | Validated metadata label, otherwise a consumer fallback from the property name. |
| `order` | optional | Validated metadata ordering value. Missing is a normal state. |
| `group` | optional | Validated metadata grouping label. |
| `tooltip` | optional | Validated metadata help text. |
| `presentation_kind` | required effective result | One approved generic kind derived from reflection and compatible metadata. It is not a widget class or scene path. |
| presentation source | optional diagnostic context | Whether the effective intent came from reflection, sidecar metadata, or both. This is presentation provenance only, not package provenance. |

The descriptor result also carries deterministic diagnostics for rejected
properties or metadata. It does not carry a `Control`, `Callable`, setter
callback, `EditorUndoRedoManager`, `EditorInterface`, package script, scene
path, or arbitrary resource.

The descriptor describes a supplied object; it does not own that object and does
not serialize its current value. A consumer-specific read/write adapter remains
responsible for using the descriptor safely.

## 4. Metadata terminology and file decision

### 4.1 Chosen terminology

The frozen term is **block property presentation metadata**. The optional sidecar
file is:

```text
res://flow_packages/<package_id>/block_property_presentation.json
```

It is optional, package-relative, data-only metadata for the canonical one-block
package profile. It is not part of `manifest_version = 1`, and its absence must
not prevent discovery, creation, persistence, or runtime execution of a valid
block.

The name deliberately describes the reusable boundary rather than an editor
implementation. The same validated presentation information may later be
consumed by the runtime Game Debug Panel when the sidecar is available and the
export policy includes it. Reflection-only descriptor construction remains the
fallback and is required for safe reuse.

### 4.2 Alternatives considered

- **`editor_schema.json` — rejected as the D4 name.** It implies that the data is
  editor-only and couples a future runtime debugger to an editor surface. It is
  retained only as historical terminology in earlier D0/D1 planning records.
- **`property_schema.json` — rejected.** “Schema” suggests model shape,
  migration, and source-of-truth authority, while this file is only a
  presentation projection.
- **Package-owned editor widgets/scripts — rejected.** They would introduce a
  second executable extension mechanism, require editor APIs, and make runtime
  reuse unsafe.
- **Reflection only — rejected as the complete contract.** Reflection provides
  technical truth but cannot consistently express a safe label, ordering, group,
  tooltip, or approved presentation preference.
- **Metadata only — rejected.** Metadata alone can drift from the actual script,
  invent fields, and misrepresent persistence or type.

### 4.3 Minimal v1 sidecar shape

D4-A freezes the boundary and the safe field vocabulary, not localization or a
general-purpose schema language. The initial sidecar shape is:

```json
{
  "format_version": 1,
  "block_type_id": "hello_message",
  "properties": [
    {
      "property": "message",
      "label": "Message",
      "order": 10,
      "group": "Output",
      "tooltip": "Text emitted by this block.",
      "presentation": "multiline"
    }
  ]
}
```

The top-level `block_type_id` must match the canonical package block identity.
The allowed v1 declaration fields are `property`, `label`, `order`, `group`,
`tooltip`, and `presentation`. `presentation` is limited to:

- `auto` or omission;
- `multiline` for `String` only;
- `range` only when the reflected property already has a valid compatible range
  hint;
- `enum` only when the reflected property already has a valid compatible enum
  hint.

Metadata cannot supply range limits, enum values, defaults, or type
conversions. Godot's reflected `hint_string` remains authoritative for those
semantics. A future sidecar format or localization contract requires a separate
approval.

## 5. Metadata authority and trust boundary

Presentation metadata may control only these safe aspects:

- display label;
- deterministic order;
- grouping label;
- tooltip/help text;
- an approved generic presentation kind subject to reflection compatibility.

It must not:

- execute code or callbacks;
- load scripts, scenes, resources, or arbitrary paths;
- provide custom `Control` classes or editor scripts;
- mutate a model property during discovery or descriptor construction;
- create a model property;
- change a property type, usage, default, persistence, or runtime behavior;
- grant runtime debug permissions;
- alter package provenance or authenticity claims.

External packages are already code/resources and remain a separate trust
boundary. D4 v1 must not add a second arbitrary code-execution mechanism through
JSON. A package needing a custom widget or executable presentation extension is
outside this contract and must be classified as an SDK extension/core change,
not silently added as a block-specific branch.

## 6. Deterministic ordering and grouping

Ordering applies to the generic descriptor list after explicit host controls
have been removed from it.

1. A valid integer `order` sorts before fields without an explicit order.
2. Explicit orders sort in ascending numeric order.
3. Equal explicit orders use the ordinal property name as the tie-breaker.
4. Fields without a valid order use the ordinal property name.
5. A missing order and a malformed order are not equivalent diagnostics, but both
   use the deterministic unordered fallback; malformed order is reported.
6. `label` and `group` never become tie-breakers, because they are presentation
   text and may change without changing property identity.
7. Group headers follow the resulting property sequence. A group label does not
   reorder properties; if a group is non-contiguous after ordering, its rendered
   sections follow the same deterministic sequence.

When metadata is absent, all eligible generic properties therefore sort by
ordinal property name. Partial metadata does not depend on JSON object key order
or the incidental order of `get_property_list()`.

Explicit built-in controls retain their existing host order. Generic fields are
then inserted according to the rules above. A metadata order value cannot move a
common Block Name, Enabled, Print text, or Method selector control into a
different host-owned slot.

## 7. Supported v1 property types and hints

The minimum safe generic v1 set is:

| Model type | Base presentation | Supported reflected hint behavior |
| --- | --- | --- |
| `bool` | Boolean control | No additional hint is required. |
| `int` | Integer numeric control | Valid `PROPERTY_HINT_RANGE` may produce a constrained numeric presentation; valid `PROPERTY_HINT_ENUM` may produce an enum presentation. |
| `float` | Floating-point numeric control | Valid `PROPERTY_HINT_RANGE` may produce a constrained numeric presentation. |
| `String` | Single-line text control | `PROPERTY_HINT_MULTILINE_TEXT` or compatible approved metadata may produce multiline text; valid reflected enum hints may be used only when Godot reports them for the property. |
| `StringName` | StringName-preserving text control | The consumer must write a `StringName`, not silently change the model to `String`; multiline and metadata-supplied enum semantics are not v1 defaults. |

The supported standard hint subset is therefore:

- `PROPERTY_HINT_RANGE` for `int` and `float`, using only validated reflected
  range data;
- `PROPERTY_HINT_ENUM` for a compatible reflected `int` or `String` property,
  using only validated reflected enum data;
- `PROPERTY_HINT_MULTILINE_TEXT` for `String`.

An invalid or incompatible standard hint produces a diagnostic and falls back
to the base scalar presentation when the base type is otherwise supported. It
does not invent constraints or change the model type.

The v1 renderer must not automatically include `Color`, vectors, arrays,
dictionaries, `Object`, `Resource`, `Node`, `NodePath`, `Callable`, arbitrary
references, nested objects, expressions, or custom resources. An unsupported
type is skipped from the generic editable surface with a deterministic
`unsupported_property_type` diagnostic. It is not given an invented widget and
does not become Flusso-owned.

The same skip rule applies when a supported descriptor cannot safely read or
validate its current value. The model remains unchanged.

## 8. Ownership, editor authoring, and Revertir

### 8.1 Ownership registration

The active Flusso surface maintains an owned-property set for the selected block.
The set is populated only after a control is actually rendered and is able to
edit the property through the editor command boundary.

- Existing explicit controls register their existing properties as they do today.
- A future generic control registers its descriptor property name only after it
  is successfully rendered as editable.
- Read-only descriptors, skipped properties, diagnostics, and merely discovered
  properties are not owned.
- If an explicit and generic candidate collide, the explicit control wins, the
  generic duplicate is not rendered, and the collision is diagnosable.

This preserves the rule:

> A property existing on a FlowBlock does not imply that Flusso owns it.

### 8.2 Editor authoring semantics

An editable generic field changes persistent authoring state immediately through
the current editor/model command boundary. The editor adapter, not the shared
descriptor layer, integrates `EditorUndoRedoManager`, controller dirty state,
scene persistence, and the existing live-edit merge behavior.

The model setter must be guarded by the descriptor's reflected property name and
type. Generic presentation code must not call unrestricted `set()` on a name
that was not accepted by the current descriptor and ownership session.

### 8.3 Revertir

When a Flusso session opens, its snapshot contains exactly the current values of
the properties that the active surface owns. It does not snapshot every value in
`get_property_list()`.

Revertir:

- restores only those owned property names;
- routes the restoration through the existing editor undo/model command boundary;
- keeps Flusso open under the current Preview 1 semantics;
- preserves the selected block/resource and stable identity;
- leaves unknown, unsupported, read-only, or unrendered properties untouched;
- records a deterministic diagnostic and skips a value if the owned property is
  no longer present or writable instead of creating it.

An editor save/reopen test must prove that owned authoring edits persist through
the supported `ResourceSaver`/`PackedScene` path and that unowned properties are
not changed by Revertir.

### 8.4 Runtime debug distinction

Flusso ownership and Revertir are editor-authoring semantics. They do not become
runtime debugger semantics by reusing a descriptor. A runtime debug edit has no
implicit editor undo, Revertir snapshot, scene save, package rewrite, source
`.gd` update, or write-back to the original project resource.

## 9. Container independence

The descriptor is built from the selected `FlowBlock`, not from its host
container. It must produce the same property description and generic ordering
for the same block whether the block is hosted by:

- `Process`;
- `Timer`;
- `State Machine`;
- a future `IF`;
- a future `While`;
- a future `Do` / `Do While`;
- a future `For`; or
- another compatible `FlowBlock` container.

The container controls sequence timing and execution context. It does not change
the block's property contract. A future block with supported exported fields
uses this same description/rendering path and does not require a
`ProcessMyBlock`, `TimerMyBlock`, `IfMyBlock`, or central concrete-type branch.

If a future property truly needs container context, that is a separately
approved capability contract. D4-A does not smuggle context into generic
property semantics.

## 10. Runtime-safe reuse boundary

The following parts are intentionally reusable from portable runtime code:

- reflection of a supplied `FlowBlock`/`Object` property list;
- the authoring-safe candidate filter and any future explicitly named runtime
  policy filter;
- type, usage, hint, and current-value validation;
- parsing and validation of the data-only sidecar;
- descriptor construction;
- deterministic ordering and diagnostics.

The following remain consumer-side and are not dependencies of that layer:

- Godot editor APIs and editor `Control` creation;
- Flusso layout, focus, keyboard policy, Theme, Motion, and scroll behavior;
- `EditorUndoRedoManager` and `FlowEditorBlockAuthoringContext`;
- scene/package saving and editor dirty-state integration;
- runtime debug activation, access policy, pause policy, transport, and write-back.

The future runtime debugger may use the same descriptor data and sidecar when
available, but `editable = true` is only a safe generic type/write capability;
it is not a runtime authorization grant. The runtime debugger must supply a
live target and an explicit access policy. Its exact eligibility policy may be
more restrictive than editor authoring, but it may not bypass the descriptor's
type, safety, or metadata rules.

The descriptor layer must be loadable in an exported game where the required
block script and optional sidecar are present. It must not require
`EditorInterface`, `EditorPlugin`, editor docks, or editor-only undo classes.

## 11. Future Flujo Game Debug Panel — record only

Flujo plans a Debug Panel inside the running game's window with this conceptual
flow:

```text
containers
    → blocks
        → selected block
            → generic runtime property inspector/editor
```

The panel must use the same FlowBlock/property description contract wherever
possible and must not require Godot editor APIs. Initial runtime debug changes
affect only the live execution target. They do not imply:

- saving the scene;
- rewriting a package;
- updating a source script;
- modifying the original project resource on disk;
- synchronizing changes back to Flusso;
- using Flusso Revertir or editor Undo/Redo.

`Apply Runtime Changes to Scene` is explicitly out of scope and requires a
separate approved contract. The panel's UX, activation mechanism, export policy,
security/access policy, pause behavior, live-state ownership, transport, and
write-back semantics are future work. D4-A adds no panel, debug UI, transport,
autoload, permission system, or runtime editor mode.

## 12. Invalid metadata and deterministic fallback

Invalid presentation metadata must never corrupt a `FlowBlock` model. The
metadata reader is read-only and applies these rules:

| Condition | Diagnostic/fallback |
| --- | --- |
| Sidecar absent | Normal; use reflection-only descriptors. |
| Invalid JSON, unsupported `format_version`, wrong top-level types, unknown top-level keys, or block identity mismatch | Emit a document diagnostic; ignore the entire sidecar and use reflection-only descriptors. |
| Unknown property declaration | Emit a property diagnostic; ignore that declaration; keep valid declarations. |
| Property is reflected but ineligible for generic authoring | Emit a diagnostic when explicitly named by metadata; ignore that declaration. |
| Duplicate property declarations | Emit one deterministic duplicate diagnostic for the property and ignore all declarations for that property. |
| Invalid declaration field type or unsupported declaration field | Emit a declaration diagnostic; ignore that declaration or field according to the field-level fallback below. |
| Malformed `order` | Emit a diagnostic; ignore the order and use the unordered deterministic fallback. |
| Malformed/empty `group`, invalid label, or invalid tooltip | Emit a diagnostic; ignore that presentation value and use its consumer fallback. |
| Requested `presentation` incompatible with reflected type/hint | Emit a diagnostic; ignore the requested kind and use the reflected/base scalar presentation. |
| Invalid reflected range/enum/multiline hint | Emit a diagnostic; fall back to the supported base scalar presentation when possible. |
| Unsupported reflected property type | Emit `unsupported_property_type`; omit the property from the generic editable list. |
| Current value is incompatible with the reflected type | Emit a type/value diagnostic; omit the property from generic editing. |
| Explicit/generic ownership collision | Emit a collision diagnostic; preserve the explicit control and omit the generic duplicate. |

Diagnostics are ordered deterministically: document-level diagnostics first,
then declaration array index, then property name, then diagnostic code. A
fallback is always observable in diagnostics; invalid metadata is not silently
rewritten or used to repair the model.

The model is never written during discovery, metadata validation, ordering,
descriptor creation, or fallback. A malformed sidecar cannot create a property,
change a type/default, delete a value, or alter persistence.

## 13. D4-B/D4-C evidence record

D4-B and D4-C provide evidence for the following matrix. The rows describe the
accepted D4 v1 boundary; capabilities outside it remain future work and are not
silently implied by the renderer.

| Evidence item | Required proof |
| --- | --- |
| External `message` | A generic external block's exported `message` appears without a package/type branch in Flusso. |
| Scalar types | Independent bool, int, float, String, and StringName fields read, edit, preserve exact model types, and display current/default values where available. |
| Standard hints | Valid reflected range, enum, and multiline hints use the approved generic presentations; malformed/incompatible hints fall back deterministically. |
| Ordering | No metadata, full metadata, partial metadata, tied orders, and built-in explicit fields produce the same deterministic order in repeated editor/runtime descriptor construction. |
| Metadata fallback | Invalid JSON/schema, unknown properties, duplicates, invalid order/group, and incompatible presentations produce diagnostics and leave the model unchanged. |
| Unsupported types | Complex/unsupported types are skipped with a diagnostic and never receive an invented widget. |
| Ownership | Only controls actually rendered and registered enter the Flusso owned-property set; no duplicate built-in controls appear. |
| Revertir | Revertir restores exactly the owned values, leaves unknown/unrendered values untouched, remains undoable, and keeps Flusso open. |
| Persistence | Owned editor edits survive the supported save/reopen paths; descriptor metadata does not replace persisted model values. |
| Multiple instances | Two instances of the same block have independent current values and independent Flusso snapshots. |
| No concrete branches | Static/review evidence shows no package/type-specific Flusso renderer branch for generic fields and no new control-flow block implementation. |
| Runtime separation | The shared descriptor/metadata code has no editor API dependency; runtime construction works without an editor; live debug mutation does not save project assets. |
| Container independence | The same block description and generic presentation work from Process, Timer, State Machine, and a compatible future-container fixture without container-specific property code. |
| Security boundary | Metadata cannot execute code, load arbitrary UI, mutate the model during discovery, or install package-owned widgets/scripts. |

The future test plan should include model/runtime descriptor tests, editor
ownership/Revertir tests, persistence/runtime tests, and a static dependency
review. Visible Flusso changes also require manual review of empty state, long
labels/tooltips, multiline editing, keyboard focus, rebuilds, save/reopen, and
selection changes. Runtime-panel UX review is separate and remains future work.

## 14. Scope, risks, and protected invariants

### Explicitly out of scope for D4-A

- production reflection code or descriptor classes;
- production metadata loading or validation;
- generic editor controls or renderer branches;
- the Game Debug Panel or debug transport;
- runtime mutation implementation;
- `IF`, `While`, `Do`, `Do While`, or `For` blocks;
- `flujo-block-builder` generation;
- provenance, authenticity, installation, package recovery, or lifecycle work;
- arbitrary widgets, scripts, scenes, callbacks, expressions, or complex v1
  property types;
- graph schema changes, manifest v1 changes, or migrations;
- changes to `demo/main.tscn`.

### Protected invariants

- `FlowBlock` remains independent from its hosting container.
- Runtime code never depends on editor APIs.
- The model/script remains authoritative for property existence, type, default,
  current value, and persistence.
- Stable IDs, order, deliberate `null` positions, schemas, and persistence
  semantics remain unchanged.
- A property is owned by Flusso only when its editable control is rendered and
  registered.
- Revertir snapshots exactly the active owned set and leaves unknown/unrendered
  properties untouched.
- Runtime debug editing is live-state-only by default and is not editor
  authoring write-back.
- External package metadata remains data-only and cannot introduce arbitrary
  code execution.

### Risks and limitations

- Godot property hints can be malformed or more expressive than the v1 renderer;
  the contract intentionally falls back instead of guessing.
- Some defaults are not available as a portable reflection fact; the descriptor
  may omit them rather than instantiate arbitrary objects.
- The runtime debugger's access, pause, export, and write-back policy is not
  decided here.
- Localization of package-provided labels/tooltips is not frozen here.
- Complex values remain unsupported until a separate safe type contract exists.

## 15. Traceability and D4-A evidence boundary

| Requirement | D4-A artifact | D4-B+ evidence | D4-A status |
| --- | --- | --- | --- |
| `D4A-PROP-001`–`D4A-PROP-010` | This contract, sections 1–14 | `tests/model/flow_block_property_descriptor_test.tscn` and `tests/editor/flow_generic_flusso_property_editor_test.gd` for the D4-B descriptor and D4-C renderer layers | Contracted; descriptor, automatic renderer and manual Flusso evidence pass |
| D3 ownership/Revertir preservation | `docs/current_iteration.md`, `docs/project_memory.md`, and this contract section 8 | Existing D3 focal evidence plus future generic ownership tests | Preserved; no production change |
| Runtime/editor separation | This contract sections 10–11 | Static dependency review and runtime descriptor test | Contracted; panel not implemented |
| Metadata terminology | `block_property_presentation.json` decision in section 4 and parent roadmap updates | Future sidecar validator | Frozen; no sidecar created |

D4-A itself changes documentation only. D4-B adds the runtime/model descriptor
implementation recorded in the next section. D4-C adds the editor-only controls,
live authoring boundary, ownership registration and session Revertir behavior
recorded below; neither delivery adds runtime debug mutation or a Game Debug Panel.

## 16. D4-B implementation record

D4-B implements the reusable projection described by this contract through
`FlowBlockPropertyDescriptor`, `FlowBlockPropertyPresentationLoader`, and
`FlowBlockPropertyCatalog` under `addons/vp_flujo/runtime/model/`. The focal
`tests/model/flow_block_property_descriptor_test.tscn` proves the supported scalar
types, standard hints, default labels, explicit-host classification, deterministic
ordering, partial/invalid metadata fallback, eligibility filtering, unsupported
types, container independence, package-relative sidecar discovery, and a runtime
construction/static dependency audit. The implementation never edits the supplied
block and does not register Flusso ownership. D4-C is the renderer delivery
recorded in the next section.

## 17. D4-C renderer implementation record

D4-C implements the approved editor adapter in
`addons/vp_flujo/editor/flow_ready_process_editor.gd`. The authoring context
delegates descriptor resolution to `FlowBlockPropertyCatalog` and does not parse
presentation JSON. Common controls are selected from descriptor
`presentation_kind`; explicit built-in controls are excluded before generic
rendering so existing Block Name, Enabled, Print text and Method controls are not
duplicated. Labels, order, groups, tooltips, multiline fields, enum/range hints
and diagnostics are consumed as data from the descriptor.

Generic edits cross the descriptor-validated
`FlowGraphEditorCommands.set_ready_property_descriptor_live()` boundary and reuse
the existing live undo infrastructure. Ownership is registered only after an
editable generic control is created successfully. The existing inspector-property
session snapshot and Revertir action restore only the active rendered owned set;
unknown, unsupported, read-only, hidden and diagnostic-only properties remain
untouched. The same descriptor path is used for Process and Timer containers.

The focal `tests/editor/flow_generic_flusso_property_editor_test.gd` covers the
supported scalar controls, range/enum/multiline presentation, labels, ordering,
groups, tooltips, diagnostics, live edits, ownership, Revertir, built-in collision
protection and Process/Timer equivalence. The behavior catalog entry is
`FLUJO-BHV-FLUO-GENERIC-PROPERTY-001`; proportionate persistence/runtime and
editor regressions are recorded in the current iteration handoff. Automatic
evidence passes. Manual visual review was approved for the visible Flusso
surface, focus, keyboard traversal, scrolling, Theme presentation and
save/reopen interaction. No schema, manifest, runtime code, custom block or
control-flow block is introduced.

The D4 v1 generic property/editor boundary is therefore closed at D4-C. The
shared descriptor layer remains reusable by a future runtime Game Debug Panel,
but that panel, runtime authorization, write-back and complex/custom widgets are
not implemented by D4.

Everything is Flow; everything flows. 🌊
