# Flujo — Lot 07: Node / Object Tok

## Scope

Lot 07 gives the Scene family a second semantic result:

- `$Node` — the live scene Node itself.
- `$Node.property` — one typed property on that Node.

The same `$` trigger is intentionally shared. The active Akis schema decides
which semantic path is valid.

This lot does **not** turn Object into a generic Literal type.

## NodeRef value source

Persistent source:

`FlowNodeRefValueSource`

Tok projection:

`FlowNodeRefSegment`

Produced Variant.Type:

`TYPE_OBJECT`

The resolved Object is constrained to a live Godot `Node`. A NodeRef stores:

- `requirement_id`
- scene-root-relative `node_path`
- `node_name_hint`
- `node_class_hint`

Preview:

`$Target`

NodeRef is a reference source, not serialized object state.

## Object boundary

`TYPE_OBJECT` is added to the shared type-display vocabulary, but
`FlowLiteralValueSource.is_allowed_type(TYPE_OBJECT)` remains false.

Therefore:

- there is no Object literal;
- no Node instance is serialized inside Akis;
- no Resource is implicitly accepted as a Node;
- runtime always resolves the current scene object through context.

This keeps Object identity separate from Literal values.

## Runtime resolution

`FlowNodeRefValueSource.resolve(context)` requires
`FlowValueResolutionContext`.

Resolution order uses the existing Scene contract:

1. Requirement binding, when `requirement_id` is present and bound.
2. scene-root-relative `node_path` fallback.

Resolution succeeds only when:

- the Node exists;
- its runtime class satisfies `node_class_hint`.

The result is:

`FlowValueResult.ok(node, TYPE_OBJECT)`

Structured failures cover:

- unbound locator;
- missing scene context;
- missing Node;
- missing Requirement;
- incompatible class.

## Required Node placeholders

A block may require a Node before the user has selected one.

The schema can therefore use:

`FlowNodeRefValueSource.placeholder(&"Node")`

An unbound placeholder is **structurally valid** but runtime-unresolved.

It:

- has a real source_id;
- produces TYPE_OBJECT;
- renders as `$Node`;
- can be materialized by FlowChipFieldFactory;
- emits a warning that no locator is bound;
- fails resolve() with CODE_NODE_REF_LOCATOR_MISSING until repaired.

This avoids using null as hidden semantic meaning and lets required block inputs
exist visibly from the first Inspector render.

## $ authoring behavior

Typing unescaped `$` or dropping a Scene Node begins one scene-reference
request.

### Node-only slot

Schema:

- accepts TYPE_OBJECT;
- accepts SOURCE_KIND_NODE_REF.

Selecting a scene node inserts `$Target` directly.

No property selector is shown.

### Property-only slot

Schema accepts NODE_PROPERTY_REF and compatible basic Variant types.

The existing Lot-04 behavior remains:

1. select Node;
2. choose compatible property;
3. insert `$Target.position`, etc.

### Node-or-Property slot

If the field accepts both NodeRef and NodePropertyRef, Flujo displays:

- **Use Node**
- **Choose Property**
- Cancel

This is explicit semantic disambiguation; Flujo never guesses whether the user
wanted the object or one of its properties.

The Property option appears only when the active field/slot accepts at least one
currently supported property Variant type. A TYPE_OBJECT-only field therefore
does not offer an empty property path.

## Scene Node panel and drag/drop

The Scene Nodes panel remains the common source for:

- `$Node`
- `$Node.property`

Its hint now describes both semantics.

Drag/drop works through the existing Akis forwarding boundary. The destination
schema, not the dragged payload, determines whether the Node becomes a NodeRef,
a NodePropertyRef, or triggers the chooser.

## Requirement promotion

Direct children of the active PVController may be promoted to the existing
Schema-4/5 Requirement model.

For NodeRef:

- an existing Requirement binding is reused;
- otherwise a direct child can create one Requirement plus scene-local binding;
- descendant nodes retain their relative NodePath fallback under the current
  Requirement contract.

Requirement creation remains a separate undoable action before Tok insertion.

## Editing and identity

Double-click / Enter on a Node Tok opens Scene Nodes to choose a replacement.

Changing:

`$Player -> $Enemy`

preserves:

- segment_id;
- source_id;
- slot_id / slot_kind.

Only the external scene locator, name/class hints and Requirement binding change.

NodeRef editability follows **reference policy**:

- schema `allow_reference_change`;
- slot `allow_reference_change`.

It does not incorrectly depend on Literal/content-edit policy.

NodePropertyRef editing was also hardened to preserve its source_id when its
selected property/reference changes.

## Validation and schema contract

NodeRef is first-class in:

- FlowChipFieldFactory;
- FlowStructuredDocumentValidator;
- FlowChipFieldValidator;
- FIXED / FLEXIBLE / HYBRID compatibility;
- type/source-kind locking;
- details panel;
- runtime resolution refresh;
- ResourceSaver / ResourceLoader.

A block that needs a Node declares:

- accepted value type: `TYPE_OBJECT`;
- accepted source kind: `SOURCE_KIND_NODE_REF`.

This opens Node semantics only for that slot. It does not globally enable Object
values.

## Inspector details

Selecting a Node Tok exposes:

- preview;
- result type: Object (Node);
- expected/runtime class hint;
- Requirement ID or NodePath;
- **Change Node**.

Unresolved required placeholders are visually invalid when scene context is
available and remain repairable from the same Tok.

## Composition boundary

Lot 07 intentionally does not add NodeRef as an operand to Condition or
Operation.

Current operator/comparison catalogs have no Object signatures, so allowing it
would only create invalid choices.

Future Object-aware semantics may add explicit operations such as identity/null
checks or Node-specific consumers, but only through declared signatures.

Node properties whose Variant.Type is TYPE_OBJECT also remain outside the
current property selector; Object/Resource expansion is a later lot.

## Manual review harness

The Structured Document Harness adds:

### SCENE NODE

A required FIXED Node slot initialized as unresolved `$Node`.

Review:

- unresolved appearance;
- Enter / double-click;
- select a Node;
- `$Node` preview;
- change reference;
- Undo/Redo.

### SCENE REF

A flexible field accepting both:

- NodeRef / TYPE_OBJECT;
- NodePropertyRef / Vector2.

Review:

1. type `$`;
2. select a Node2D;
3. verify **Use Node / Choose Property** chooser;
4. test both branches.

### SCENE PROPERTY

Retained as the property-only regression fixture.

## Focal evidence

Added:

- `tests/model/flow_node_ref_lot_07_test.gd`
- `tests/model/flow_node_ref_lot_07_test.tscn`
- `tests/editor/flow_node_ref_lot_07_editor_test.gd`

Model focal covers:

- Object-not-Literal boundary;
- required unbound Node placeholder;
- factory creation;
- NodePath runtime resolution;
- Requirement-first resolution;
- missing context/node/class diagnostics;
- graph Requirement validation;
- deep duplication;
- persistence.

Editor focal covers:

- Node-only direct insertion;
- direct-child Requirement promotion;
- Node/Property chooser;
- property-only regression;
- required FIXED placeholder repair;
- segment_id/source_id preservation;
- Undo/Redo.

As in prior lots, the repository currently has no GitHub workflow that executes
the Godot editor/model focal tests. Godot 4.7.2 execution remains the formal
PASS gate.
