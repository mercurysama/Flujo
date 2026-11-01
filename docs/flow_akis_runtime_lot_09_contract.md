# Flujo — Lot 09: Akis, Blocks and Runtime Integration

## Scope

Lot 09 connects the Akis/Tok value language to executable Flujo runtime paths.

The integration is deliberately generic:

- Akis can resolve as runtime text or one typed value.
- Blocks can resolve any owned FlowStructuredDocument property.
- Output blocks receive runtime value context.
- Navigation blocks receive the same runtime value context.
- FlowGraph validates block-owned Akis without concrete block branches.
- Graph Variables now support Array, Dictionary and Resource defaults.
- Per-controller runtime Variable overrides remain transient and never mutate the shared FlowGraph.

No editor dependency is introduced into runtime.

## Runtime Akis resolution

Runtime bridge:

`FlowStructuredDocumentResolver`

### Text mode

`resolve_text(document, context)`

Text segments are concatenated with resolved Tok values.

Example:

`Hola [@Name]`

may resolve to:

`Hola Mercury`

Formatting rules remain deterministic:

- String/StringName -> text
- bool -> true/false
- Node -> node name
- Resource -> resource path when available, otherwise class
- other Variant values -> Godot textual representation

A Tok resolution failure returns diagnostics instead of inserting invented text.

### Typed mode

`resolve_value(document, context)`

A typed Akis value requires:

- exactly one Tok;
- no non-whitespace runtime text.

The produced Variant and Variant.Type are returned directly through
`FlowValueResult`.

This allows Array, Dictionary, bool, int, float, Node, Resource and other
declared Tok results to reach a block without String coercion.

`FlowStructuredDocumentRenderer.render()` now delegates to the runtime resolver
and accepts an optional `FlowValueResolutionContext`.

## Generic block contract

`FlowBlock` now exposes:

`resolve_structured_property_text(property_name, context)`

`resolve_structured_property_value(property_name, context)`

A custom block can therefore declare an exported `FlowStructuredDocument`
property and resolve it without requiring a new executor branch.

This keeps the block SDK extensible: the runtime understands Akis, not
package-specific block types.

## Output blocks

`FlowOutputBlock` adds:

`resolve_output_message(context) -> FlowValueResult`

Legacy output blocks use their existing `get_output_message()` String through
the default implementation.

The runtime output contract requires a successful `TYPE_STRING` result.

## Print integration

`FlowPrintBlock` now owns:

- legacy `text: String`
- optional `content: FlowStructuredDocument`

Runtime behavior:

1. if `content == null`, Print uses legacy `text`;
2. otherwise Print resolves `content` through Akis runtime text resolution.

This preserves old projects while allowing Print content such as:

- text + VariableRef;
- text + Operation;
- text + NodePropertyRef;
- complex VariableRef rendered as text;
- other runtime-resolvable Toks.

Flusso already recognizes exported `FlowStructuredDocument` properties, so
Print's `content` uses the existing embedded Akis authoring surface rather than
a Print-specific editor.

## Executor integration

`FlowReadyExecutor` creates or reuses one
`FlowValueResolutionContext` and passes it through the full block pass.

Output execution calls the context-aware output contract.

A failed output value:

- emits a runtime warning;
- skips that output write;
- does not stop later valid blocks.

An output block that returns a non-String value is rejected by the output
contract.

No Print-specific branch was added to the executor.

## Navigation integration

`FlowNavigationContext` now carries:

`value_resolution_context`

Therefore current or future navigation blocks may evaluate their own Akis
Condition/value properties from `get_navigation_decision()` without adding
IF/JUMP/Loop-specific branches to `FlowReadyExecutor`.

The executor remains responsible for traversal; the block remains responsible
for its semantic decision.

## Generic block Akis validation

`FlowGraphValidator` now inspects block properties generically.

Every property whose runtime value is a `FlowStructuredDocument` is validated
with the active graph.

Nested diagnostics are prefixed with the owning path, for example:

`processes[0].blocks[2].content.segments[1]...`

This applies to built-in and package blocks equally.

An invalid block-owned Akis document marks that block path invalid; the executor
can skip the bad block while later blocks continue.

## Complex graph Variables

`FlowVariableDefinition.ValueType` now includes:

- ARRAY
- DICTIONARY
- RESOURCE

Mappings:

- ARRAY -> TYPE_ARRAY / FlowArrayValueSource
- DICTIONARY -> TYPE_DICTIONARY / FlowDictionaryValueSource
- RESOURCE -> TYPE_OBJECT / FlowResourceRefValueSource

Complex defaults are owned through:

`complex_value_source: FlowValueSource`

Scalar Variables retain their existing dedicated scalar fields.

A complex Variable must have an exact source-kind/type match.

RESOURCE remains semantically Resource-only even though Godot represents both
Node and Resource as TYPE_OBJECT. Runtime overrides containing a Node are
rejected for a RESOURCE Variable.

Enum and Bitfield remain semantic int ValueSources from Lot 08. They do not
create separate graph Variable storage types in this lot.

## Variable default resolution

`FlowVariableDefinition.get_default_value_result(context)`

returns the persisted scalar or resolves the owned complex source.

`FlowVariableRefValueSource.resolve(context)` uses this path after checking for
a per-instance runtime override.

Resolution order is therefore:

1. runtime override in FlowValueResolutionContext;
2. persisted FlowVariableDefinition default.

The shared FlowGraph remains read-only at runtime.

## Cycle protection

Complex Variable defaults may contain nested VariableRefs.

`FlowValueResolutionContext` tracks the IDs currently being resolved.

A direct or indirect cycle such as:

`A -> B -> A`

returns:

`CODE_VARIABLE_RESOLUTION_CYCLE`

instead of recursing indefinitely.

## Per-controller runtime state

`PVController` now owns a transient:

`value_resolution_context`

through:

`get_value_resolution_context()`

The context is:

- per controller instance;
- not exported;
- not serialized;
- reused across Ready/Timer execution passes;
- cleared when the controller leaves the tree.

This establishes the runtime storage boundary needed by future assignment/set
blocks without mutating the persisted graph.

Lot 09 does not invent a Variable assignment block because none exists in the
current block catalog. Future setters can use
`FlowValueResolutionContext.set_variable_value()`.

## Variable Inspector

Schema-3 Variable editing now supports:

- Array
- Dictionary
- Resource

Changing a Variable Type to a complex type atomically creates or reuses the
compatible structured source.

Changing back to a scalar type clears the active complex source.

The Inspector displays:

- semantic preview;
- Edit Array / Dictionary / Resource;
- Initialize action for malformed legacy/missing structured state.

Editing reuses `FlowComplexValueEditor`.

Complex Variable edits are Undo/Redo actions and preserve the existing
`source_id`.

## Graph duplication

Complex Variable defaults deep-duplicate their owned source trees.

Nested VariableRef identities are remapped to the duplicated graph's Variable
IDs through:

`FlowValueSourceReferenceRemapper`

The same remapper is applied generically to block-owned Akis documents through
`FlowBlock.remap_internal_references()`.

Therefore a duplicated Print/Akis reference no longer points back to a Variable
owned by the original graph.

Block-owned Akis Resources are deep-copied through each block's
`duplicate_with_new_id()` contract.

## Compatibility

Preserved:

- legacy Print.text;
- existing FlowOutputBlock subclasses;
- existing block property reflection/Flusso;
- existing Variable scalar storage;
- existing graph stable-ID semantics;
- existing runtime/editor dependency boundary.

No migration is forced simply because Print gains an optional Akis property.

## Explicit boundaries

Deferred rather than partially implemented:

- a new Variable-assignment block;
- method arguments/returns execution, which was already deferred;
- automatic conversion of Enum/Bitfield metadata into graph Variable taxonomy;
- generic Object Variable storage — Resource is the only new Object-backed
  graph Variable kind;
- package-specific executor branches.

These can build on the runtime context and generic block resolution contracts
introduced here.

## Focal evidence

Added:

- `tests/model/flow_akis_runtime_lot_09_test.gd`
- `tests/model/flow_akis_runtime_lot_09_test.tscn`
- `tests/runtime/flow_akis_runtime_lot_09_test.gd`
- `tests/runtime/flow_akis_runtime_lot_09_test.tscn`
- `tests/editor/flow_complex_variable_lot_09_editor_test.gd`

Model focal covers:

- text Akis + VariableRef;
- typed one-Tok Akis;
- invalid typed-document shape;
- Array/Dictionary Variable defaults;
- per-instance runtime override;
- Resource Variable rejection of Node runtime overrides;
- recursive Variable cycle rejection;
- complex source duplication;
- nested VariableRef remap inside complex Variables;
- nested VariableRef remap inside block-owned Akis.

Runtime focal covers:

- real Ready execution;
- Print Akis resolution through FlowReadyExecutor;
- complex VariableRef output;
- legacy Print fallback;
- reused per-controller runtime values;
- invalid block Akis diagnostics and skip behavior.

Editor focal covers:

- complex Variable types in Inspector;
- automatic structured default creation;
- shared FlowComplexValueEditor;
- source_id preservation;
- complex-to-scalar source cleanup;
- chronological Undo/Redo across Type and structured-value edits.

## Verification gate

The implementation and focal sources are committed on the feature branch.

This GitHub-only session cannot execute the Godot 4.7.2 editor/runtime focal
scenes, and the repository does not currently provide a GitHub workflow that
runs those Godot tests.

Lot 09 is therefore:

**implemented, pending the formal Godot 4.7.2 execution gate.**
