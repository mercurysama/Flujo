---
name: flujo-block-builder
description: Plan and, only after explicit maintainer approval, author distributable custom FlowBlocks through the public Block SDK without patching Flujo core.
---

# Flujo block builder

## Purpose and boundary

`flujo-block-builder` is optional authoring automation over the public Block SDK.
It is not the Block SDK, a runtime service, a package loader, a registry, or a
replacement for manual authoring.

Manual GDScript, JSON and ordinary project files remain a first-class, equivalent
authoring path. Anything produced through this Skill must remain understandable,
editable and reproducible by a developer who does not have the Skill installed.
Removing the Skill must not make an existing package unloadable or unmaintainable.
Generated packages must not depend on the Skill, conversation state, temporary
paths, absolute filesystem paths, hidden metadata, editor-only singleton state or
an undocumented registration step.

This v1 is a planning-gated authoring workflow. A request for a block never
authorizes immediate file generation. The Skill produces a specification, plan
and validation plan first, then waits for explicit maintainer approval.

```text
Manual authoring ──────┐
                       ├── public Block SDK ──> Flujo
flujo-block-builder ───┘
```

## Protected architecture

### Container-agnostic block contract

A `FlowBlock` is independent from the container that hosts it. The same block
must preserve its behavior when placed in:

- `Process`;
- `Timer`;
- `State Machine`;
- a future `IF`;
- a future `While`;
- a future `Do` / `Do While`;
- a future `For`;
- any other future compatible `FlowBlock` container.

The container controls when and how its sequence executes. The block owns its
own behavior contract. Never generate container-specific variants such as
`ProcessMyBlock`, `TimerMyBlock` or `IfMyBlock`, unless a separately approved
SDK contract introduces a genuinely different semantic type.

### One block, one package

The canonical distributable unit is one block per package:

```text
res://flow_packages/<package_id>/
├── manifest.json
└── block.gd
```

The manifest remains `manifest_version = 1` and uses only its approved fields:
`manifest_version`, `package_id`, `blocks`, and each descriptor's `type_id`,
`script` and `display_name`. The canonical builder output contains exactly one
block descriptor. Historical multi-descriptor manifests remain a compatibility
concern of the loader, not a builder output format.

The optional presentation sidecar is `block_property_presentation.json`, as
defined by the public D4 property-presentation contract. It is data-only,
package-relative, and never replaces the script/model as the source of truth.
Do not invent or add `provenance.json`, dependencies, permissions, signatures,
checksums or other sidecars until their respective contracts are approved.
Additional files require a current approved contract; tests may live in the
repository's normal test/fixture locations when the plan requires them.

### Current public SDK boundary

Reuse the existing public infrastructure; do not rebuild it inside the Skill:

- `FlowBlock` persistent identity, `display_name`, `enabled`, `user_note`,
  `validate_structure(context)`, `remap_internal_references(id_map)` and
  `get_navigation_decision(context)`;
- `FlowOutputBlock` for output blocks;
- `FlowId`, polymorphic block persistence, graph validation and duplication;
- `FlowNavigationDecision` / `FlowNavigationContext` and generic
  `CONTINUE`, `JUMP` and `STOP` execution;
- external manifest v1 loading, script validation, editor catalog and factory;
- the generic authoring context, catalog-driven Add path, Undo/Redo,
  persistence and generic runtime available in the current D3 architecture.

The runtime executor consumes generic contracts. It must not branch on a custom
concrete block type, package ID or the Skill.

Official Mercury blocks and external/user blocks use this same public SDK path.
Official status must not grant a privileged package route, private registry
entry, executor branch, or editor capability. `FlowBlockRegistry` remains the
compatibility path for the existing integrated blocks during the transition and
is not changed by this Skill.

### Generic D4 v1 property contract

D4-A/B/C now provide a runtime-safe, descriptor-driven generic property path.
The script/model remains authoritative for property existence, reflected type,
current/default values and persistence. The optional
`block_property_presentation.json` sidecar may refine only safe presentation:
label, order, group, tooltip, and a compatible generic presentation kind.

The supported generic scalar types are `bool`, `int`, `float`, `String`, and
`StringName`. The supported reflected hints are compatible `range`, `enum`, and
multiline text. The generic Flusso host renders eligible descriptors without
package-owned editor controls or arbitrary editor scripts. Flusso ownership is
registered only for controls that were actually rendered and are editable;
`Revertir` restores the active-session snapshot of that owned set only.
Unsupported, read-only, hidden, unrendered, or diagnostic-only properties are
not owned. The descriptor layer is reusable from runtime-safe code and does not
grant runtime debug authorization; a future Game Debug Panel has a separate
live-state-only policy and persistence contract.

Capabilities outside this D4 v1 boundary remain visible in the planning gate:
runtime/model support may be `A` while authoring is `B`, or a reusable extension
may be `C`; a change to shared Flujo semantics is `D`. The Skill must never
silently patch the core to hide such a classification.

## Future first dogfood: FPrint

`FPrint` is the planned first future dogfood block for the functional Builder,
distinct from legacy `Print`. Its package identity, behavior and configuration
are intentionally unfrozen. Do not create an FPrint package from this Skill until
the complete per-block workflow has produced a specification, implementation
plan and validation plan, received explicit `🙆🏻` approval, and classified every
material capability as A, B, C or D. A C/D classification stops for the smallest
approved public SDK or core plan. No FPrint package exists in the current
checkpoint.

### Package and core boundaries

- Do not register an external block manually in `FlowBlockRegistry`.
- Do not add package-specific branches to Flow, Flusso, the runtime, the
  executor or persistence.
- Do not write package code inside `addons/vp_flujo/`.
- Do not silently patch `addons/vp_flujo` when a requested capability is missing.
- Runtime block scripts use portable Godot APIs and never depend on editor APIs.
- Use the narrowest existing public base class; do not invent a base class to
  avoid a capability classification.
- Use static typing and inherited stable IDs. Display names, indexes and paths
  are never persistent identity or reference targets.
- Do not use a global `class_name` unless a future approved contract requires it.

The legacy `Print`, `Custom Hello`, and `Everything Flows` blocks remain in place
for compatibility and reference purposes. `Add Call Method` keeps its current
editor category and route; it is not treated as an ordinary catalog block by
this checkpoint. Do not modify or discontinue these blocks, and do not change
`FlowBlockRegistry` as part of a Builder request.

### Theme, Motion and editor ownership

Custom blocks do not own standard host presentation or interaction motion. Do
not generate focus, open/close or selection animations, standard field styling,
drawer controls, focus management or package-specific Flusso UI. Theme, Motion,
layout, input policy and standard interaction remain owned by the Fluo host.

The Skill must never make a package depend on an editor-only control or on the
Skill being present at runtime.

### Safety against core patching

Reject this pattern explicitly:

```text
requested custom block
→ missing capability
→ silently edit addons/vp_flujo core
```

The required response is:

```text
requested custom block
→ classify the gap as C or D
→ explain the missing SDK/core capability
→ propose the smallest public extension plan
→ STOP for maintainer approval
```

## Control-flow policy

`IF`, `While`, `Do` / `Do While` and `For` are custom blocks. When eventually
requested, each must use this same `flujo-block-builder` planning and approval
workflow as an ordinary custom block. They do not receive private core creation
paths and they are not implemented by this v1.

### Recovered IF concept — historical planning context only

The previously designed IF concept is recorded for future planning, not as an
implementation authorization. Its historical conceptual fields were:

```text
condition
true_target_block_id
false_target_block_id
```

The concept uses stable references to TRUE and FALSE destinations, generic Flow
navigation, `FlowNavigationDecision.JUMP`, structural validation of destination
references, and `remap_internal_references(id_map)` during duplication. An IF
block would return a generic navigation decision; it would not move the executor
cursor itself.

The executor must remain generic and must never contain `if block is
FlowIfBlock`, an equivalent concrete IF branch, or a package-specific dispatch
path. Any future IF specification must resolve its own invalid/empty-target
behavior during its planning gate. IF remains **not implemented**.

### While / Do / For remain unspecified

No sufficiently complete approved historical specification is available for
`While`, `Do` / `Do While` or `For`. The Skill must not invent their fields,
body representation, termination rules, navigation semantics or persistence
contract. Each request must stop at the planning gate until its own contract is
approved.

Do not decide in this Skill whether future loop bodies use nested containers,
target ranges, explicit start/end IDs or another structure. That decision belongs
to the future block's specification. Future control-flow blocks must nevertheless
use the generic SDK mechanisms—navigation decisions, stable IDs, structural
validation, reference remapping and container-agnostic child blocks—once their
contracts are approved.

## Mandatory per-block planning gate

Every block request, including an apparently simple output block, follows all
phases below. Do not create a package, manifest, script, fixture or test for the
requested block before the approval gate.

The complete order is:

```text
USER REQUEST
    ↓
RECOVER EXISTING CONTEXT
    ↓
CAPABILITY CLASSIFICATION
    ↓
BLOCK SPECIFICATION
    ↓
IMPLEMENTATION PLAN
    ↓
VALIDATION PLAN
    ↓
HUMAN REVIEW
    ↓
🙆🏻 EXPLICIT APPROVAL
    ↓
BUILD → VALIDATE → TEST
    ↓
MANUAL REVIEW WHEN REQUIRED
```

### Phase 1 — Request normalization

Recover available conversation and project context before asking questions. Do
not ask the maintainer to repeat information that is already known. Determine:

- desired behavior;
- user-facing name;
- likely `package_id` and `type_id` identity;
- inputs and configuration;
- outputs and side effects;
- persistence needs;
- navigation needs;
- references to other `FlowBlock` instances;
- runtime requirements;
- Flow/Flusso/editor requirements;
- duplication and reference-remapping requirements.

Resolve a small ambiguity from project context only when the choice is safe and
reversible; record the assumption in the plan. Ask for clarification when the
ambiguity could change semantics, persistence, identity, safety or scope.

### Phase 2 — Capability gate

Classify every materially different capability before proposing implementation:

#### A — SDK-supported now

The requested behavior can be implemented completely with the current public
SDK and current authoring surface.

#### B — SDK-supported but authoring-limited

Runtime, model and persistence are supported, but one or more requested fields
or actions cannot yet be represented through current generic Flow/Flusso. The
block may still be valid, but the limitation must be visible in the plan. A
typical pre-D4 exported configuration field is `B` for visual authoring even if
its runtime behavior is `A`.

#### C — SDK extension required

The block needs a reusable generic public capability that the SDK does not
provide. Stop at planning. Identify the smallest SDK extension, its public
contract, affected boundaries and validation needed. Do not patch Flujo core
silently and do not generate a workaround package.

#### D — Core-only capability

The requested behavior fundamentally changes shared Flujo model, execution,
container or editor semantics. Stop and explain why it belongs in Flujo core
rather than a normal custom package. Do not disguise a core modification as a
package.

Report mixed classifications explicitly instead of collapsing them:

```text
Runtime behavior: A
Persistence: A
Flow Add: A
Flusso visual authoring: B
```

If any requested aspect is `C` or `D`, the Skill remains in planning and returns
the proposed extension/core plan for approval. The request never becomes a
silent core patch.

### Phase 3 — Block specification

Before implementation, provide a concise specification containing the sections
that materially apply:

- proposed block name;
- proposed `package_id`;
- proposed `type_id`;
- proposed `display_name`;
- narrowest public SDK base class;
- functional responsibility;
- configuration and persistent state;
- persistence behavior;
- runtime behavior;
- navigation behavior;
- reference and remapping behavior;
- validation rules and deterministic diagnostics;
- duplication behavior;
- Flow/Flusso authoring expectations;
- explicit container-agnostic statement;
- known SDK and D4 limitations.

Do not turn an assumption or historical design into an approved contract by
omitting its uncertainty.

### Phase 4 — Implementation plan

Then provide a concrete, reviewable build plan that identifies:

- every file to create and why it is necessary;
- every file to modify and why it is necessary, if any;
- the expected one-block package structure;
- public SDK hooks used;
- expected focused tests;
- expected manual validation;
- risk and capability-gap areas;
- explicit non-goals.

For a normal external package, prefer only:

```text
res://flow_packages/<package_id>/
├── manifest.json
└── block.gd
```

Do not propose registry edits, executor branches, package-specific Flusso
controls, schema changes, migration code or unapproved sidecars as routine
builder output. If a separate SDK/core extension is needed, list it as a
stopped proposal rather than including it in the block package.

### Phase 5 — Validation plan

Before approval, state how the result will be verified. Select only checks that
the current infrastructure can actually perform. Depending on the block, the
plan may include:

- manifest loading and deterministic package discovery;
- script validation and base-class validation;
- editor catalog discovery and external factory creation;
- Add through the normal Flow UI;
- multiple independent instances and unique `FlowId` values;
- duplication and internal-reference remapping;
- `validate_structure(context)` diagnostics;
- persistence save/reload and concrete script preservation;
- generic runtime execution;
- generic `CONTINUE`, `JUMP` or `STOP` behavior;
- Undo/Redo and atomic failure behavior;
- current Flusso compatibility, with D4 gaps stated honestly;
- behavior in more than one compatible container;
- manual desktop/editor review when visible interaction changes.

Do not claim a test, visual review or authoring capability that the current
infrastructure cannot perform. Keep automated evidence, manual evidence and
historical catalog status separate.

### Human approval gate

After the specification, implementation plan and validation plan are presented,
stop. Clearly state that the Skill is waiting for explicit maintainer approval,
for example `🙆🏻` or an equivalent unambiguous authorization.

No block files may be created before that approval. A request to “describe,”
“prepare” or “plan” a block is not approval to build it.

### After approval

Only after explicit approval may the Skill:

1. create the approved one-block package;
2. implement the approved script using the public SDK;
3. run the approved validation plan;
4. run focused tests and proportionate regressions;
5. request manual review when the block affects visible editor behavior.

If implementation reveals a capability gap that invalidates the approved plan,
stop immediately and return to the planning gate. Do not widen scope silently.

## Implementation rules for an approved block

### Base class and ordinary behavior

Select the narrowest existing SDK base class. An output-only block should prefer
`FlowOutputBlock` and a general block should use `FlowBlock` unless an approved
public specialization is required. The script remains portable, instantiable,
statically typed and independent of editor APIs.

Persistent exported properties must be deliberate and serializable. Internal
stable IDs and persistent references use the approved storage/ID contract; names
and indexes are never substituted for references. Validation is deterministic,
read-only and block-local through `validate_structure(context)`.

### Navigation and duplication

Blocks that alter control flow use only the generic navigation contract through
`get_navigation_decision(context)`, preferring `CONTINUE`, `JUMP` and `STOP`.
Persistent targets use stable `FlowId` values. Structural target checks belong in
`validate_structure(context)`. Duplication repair belongs in
`remap_internal_references(id_map)` after the complete old-ID → new-ID map exists.

The executor owns cursor movement, destination resolution and safety limits. A
custom block must not manipulate executor state or require a concrete-type
runtime branch.

### Authoring and presentation

Use the single Inspector → Fluo → Flow → Flusso path. Do not create a duplicate
Inspector block list, a package-owned editor surface, arbitrary editor widgets,
or a custom standard field style. Use the D4 descriptor-driven renderer for the
approved scalar fields. Classify unsupported visual configuration as `B` or `C`,
document the limitation, and do not patch Flusso for one block.

## Compact user-facing response format

Before approval, communicate in this format and then stop:

```text
CAPABILITY
- Runtime: A/B/C/D
- Persistence: A/B/C/D
- Flow Add: A/B/C/D
- Flusso/editor: A/B/C/D

BLOCK SPECIFICATION
- package_id / type_id:
- display_name / base class:
- behavior and state:
- persistence, navigation, references and duplication:
- validation:
- container contract:
- known limitations:

CONSTRUCTION / IMPLEMENTATION PLAN
- files to create:
- files to modify:
- SDK hooks:
- tests and manual review:
- non-goals and risks:

VALIDATION PLAN
- checks that can actually run:
- checks unavailable or deferred:

UNRESOLVED LIMITATIONS
- D4, SDK-extension or core gaps:

STATUS: waiting for explicit maintainer approval (🙆🏻 or equivalent)
```

After approval, report created files, executed checks and their evidence without
claiming unavailable coverage. If the request is `C` or `D`, replace BUILD with
the smallest proposed SDK/core extension plan and remain stopped for approval.

## Future first D5 dogfood

The next-stage decision names `FPrint` as the first real block to be created
formally through this Skill. `FPrint` is distinct from the legacy `Print` block
and is not part of this checkpoint. Its specification is not frozen: text
literal, formatting/composition, variables, values obtained from Godot nodes,
and other sources are only hypotheses until the mandatory planning gate
classifies each capability as A/B/C/D. Do not assume that every proposed source
is currently supported, and do not generate or design FPrint here.

When D5 begins, the first approved FPrint slice should remain deliberately
small and validate:

```text
description → capability classification → planning gate → approval → package
→ discovery → Add → supported Flusso fields → persistence → runtime
```

This is future dogfood, not this Skill-only delivery. Do not dogfood `IF` first,
and do not generate any block merely by installing or reading this Skill.

## Skill self-check

Before declaring this Skill ready, confirm that it explicitly states:

- manual authoring remains equivalent and first-class;
- the Skill is optional tooling, not the SDK or a runtime dependency;
- one distributable block equals one package;
- every block has a mandatory planning gate;
- the A/B/C/D capability gate and mixed classification are explicit;
- explicit human approval is required before block generation;
- the container-agnostic contract is protected;
- `IF`, `While`, `Do` / `Do While` and `For` are custom blocks;
- the historical IF navigation design is retained as planning context only;
- While/Do/For contracts are intentionally unresolved and not invented;
- no registry patching or package-specific Flusso is allowed;
- no package/runtime dependency on the Skill exists;
- missing capabilities cannot cause silent core patching;
- the D4 v1 descriptor-driven scalar boundary, ownership and runtime-safe reuse are explicit;
- future control-flow blocks use generic SDK/navigation mechanisms;
- FPrint is the planned first D5 dogfood block, its specification is unfrozen,
  and it is not generated by this delivery.
