# Flujo Project Memory / Handoff

Updated: 2026-10-29

This is the durable repository handoff for future chats and maintainers.

## Current validated preview checkpoint

- Repository: `mercurysama/Flujo`.
- Active UI branch: `feature/block-builder-fprint-dogfood`.
- Validated functional checkpoint: `cd7e969c38193d718c948262107d1f7a45ca8083`.
- Frozen code backup: `backup/fluo-preview-1-2026-10-27`.
- Preview package: `Flujo-0.1.0-fluo-preview.1`.
- Godot target: 4.7.2 stable.
- License: MIT.

## Vocabulary

- **Inspector**: Godot Inspector.
- **Fluo**: complete contextual sliding drawer.
- **Flow**: left internal panel containing blocks of the selected container.
- **Flusso**: right selected-block configuration panel.
- **Legacy Flujo dock**: production mounting is retired; `vp_flujo_dock.gd` remains only for isolated compatibility coverage.
- **Akis (candidate glossary term)**: the complete structured field/document
  formed by text plus embedded elements.
- **Tok (candidate glossary term)**: one embedded structured unit inside an
  Akis, such as a Literal Tok or Variable Tok; Expression Tok and
  Node/Property Tok remain future concepts.

Do not rename internal VP/PV classes merely to match presentation terminology.
The Akis/Tok terms are conceptual only in this phase; internal APIs such as
`FlowChipFieldEditor`, `FlowChipSegment`, and `FlowChipControl` remain unchanged.

## Inspector → Fluo contract

1. No duplicate Blocks section belongs in Inspector.
2. Double-click or Enter on an existing supported container row opens Fluo for its stable ID.
3. Flow is visible; Flusso starts closed.
4. Flow focuses the first block, or the first Add-block button when empty.
5. Double-click or Enter on a Flow block opens Flusso.
6. Closing Flusso returns real keyboard focus to the same selected Flow block after rebuild.
7. The whole drawer can be placed left/right.

## Keyboard map

- Up/Down: native Flow ItemList movement.
- Ctrl+PageUp/PageDown: circular Flow block movement by stable ID.
- Plain PageUp/PageDown: movement between containers in the current Inspector view; Inspector visible selection redraws to the same stable ID while keyboard focus remains in Flow.
- Alt+PageUp/PageDown: cycle Flusso controls.
- Alt+Shift+PageUp/PageDown: reverse Alt traversal.
- Escape: close Flusso first, then Fluo.
- Enter on a selected Flow block: same activation as double-click.

## Flusso editing semantics

- Supported configuration changes are immediate/live.
- Closing Flusso is neither commit nor cancel.
- **Revertir** restores the persistent configuration snapshot captured when the current Flusso session opened and keeps Flusso open.
- Structural destructive actions such as Delete remain separate actions.
- Changing container closes stale Flusso options.

## Important implementation files

- `addons/vp_flujo/editor/fluo_drawer.gd`
- `addons/vp_flujo/editor/flow_ready_process_editor.gd`
- `addons/vp_flujo/editor/flow_graph_inspector_property.gd`
- `addons/vp_flujo/editor/pv_controller_inspector_plugin.gd`
- `addons/vp_flujo/plugin.gd`
- `tests/editor/flow_process_timer_editor_test.gd`
- `tests/editor/fluo_drawer_test.gd`
- `tests/editor/fluo_drawer_integration_test.gd`

## Manual validation state

Desktop interaction was repeatedly exercised and approved during implementation.

On 2026-10-27 the full-project preview opened under Godot on Android. The maintainer supplied visual evidence showing Fluo mounted over the Godot editor, Flow and Flusso rendered, Revertir and close controls visible, and Flow block rows visible. This confirms Android project load and drawer rendering only; it does not certify the complete Android interaction matrix.

## Android preview matrix still required

- portrait and landscape;
- touch target sizes;
- long-panel scrolling;
- double-tap activation;
- keyboard shortcuts when available;
- focus restoration after closing Flusso;
- repeated PageUp/PageDown and Ctrl+PageUp/PageDown;
- drawer left/right placement;
- final panel proportions and readability.

## Legacy UI compatibility boundary

The plugin no longer mounts the visible `Flujo` dock or registers the `Open Fluo
(POC)` route. Fluo is the primary F4, menu, and Inspector surface. The shared
`vp_flujo_dock.gd` implementation remains in the repository only for isolated
compatibility coverage; it is not a production-mounted editor surface.

## Themes + Motion

Themes + Motion is required before the first stable release, after functional preview acceptance and manual proportion tuning. Godot 4.7 offset transforms must not desynchronize Container layout, focus, hitboxes, mouse filtering, or touch interaction.

## Packaging

- **Addon Preview**: `addons/vp_flujo/` + README + LICENSE.
- **Full Project Preview**: complete project for Android/editor validation.

The Addon Preview intentionally omits `project.godot`, demo, tests and tools. The Fluo implementation file is `addons/vp_flujo/editor/fluo_drawer.gd`; there is no new standalone `flujo.gd`.

## Custom block SDK research

The recovered and audited BLOCK SDK research is documented in [Custom Block SDK and Block Builder Skill Research](custom_block_sdk_research.md). Future custom-block or `flujo-block-builder` work must read it before changing the SDK. The initial planning-gated Builder Skill now lives at `tools/agent_skills/flujo-block-builder/SKILL.md`.

## Block ecosystem D0

The reconciled roadmap is [Flujo Block Ecosystem Plan](flujo_block_ecosystem_plan.md), and the approved architectural boundary is [Flujo Block Ecosystem Contract](block_ecosystem_contract.md).

Durable decisions:
- one distributable block = one independent package under `res://flow_packages/<package_id>/`;
- official Mercury and user/community blocks converge on the same public package contract;
- manual GDScript/JSON authoring is first-class and `flujo-block-builder` remains optional automation;
- Inspector → Fluo → Flow → Flusso remains the single authoring path;
- Flow must consume the generic external catalog/factory instead of adding concrete-type branches;
- Flusso uses the reusable reflection plus approved declarative presentation metadata boundary defined in [FlowBlock Property Presentation Contract](flow_block_property_presentation_contract.md); D4-C now consumes that boundary through generic host-owned controls.
- Theme and Motion belong to the Fluo host, not individual packages;
- provenance is declared metadata and must distinguish author from publisher; it is not cryptographic authenticity;
- the current integrated registry is transitional for distributable official blocks; migration to Mercury packages is gradual and compatibility-first;
- The standard external-block path is proven by D3, but IF remains unimplemented and deferred to its own specification, plan, explicit approval and test cycle.

Implementation order is D0 contract → D1 manual SDK profile → D2 minimum Theme + Motion contract → D3 external Flow Add → D4-A property/presentation contract → D4-B runtime-safe property descriptors → D4-C generic Flusso renderer → D5 `flujo-block-builder v1` → D6 first standard external block → D7 package lifecycle → D8 Theme + Motion polish → D9 gradual official-block migration. D4-A, D4-B and D4-C are complete with approved D4-C manual Flusso evidence. The canonical contract has no technical D4-D delivery or D4-D A–E acceptance matrix; the historical label is not a pending task. The FPrint Guardería slice is closed after its manual pass, while the functional Builder v1 remains incomplete. The initial Builder Skill does not make D5 complete.

### D1 manual SDK profile

The manual package profile is specified in [Manual Block SDK Profile Contract](manual_block_sdk_contract.md). D1 reuses the existing loader/validator/catalog/factory and proves a handwritten one-block package through deterministic discovery, factory creation, duplication, ResourceSaver and PackedScene persistence. It does not yet provide normal Flow Add or generic Flusso authoring.

### D2 Theme + Motion boundary

[Fluo Theme + Motion Contract](fluo_theme_motion_contract.md) defines the pre-block-builder presentation boundary: Containers retain logical layout; Motion belongs to the Fluo host; blocks never own editor animation or focus; offset transforms require separate hitbox/input evidence; native scrolling and the Preview 1 keyboard/close hierarchy remain protected. Final durations, easing and decorative polish remain D8 work.

### D2 Theme + Motion foundation — verified 2026-10-27

- Theme and Motion are host-owned; blocks do not control standard editor animations.
- `DrawerMotionShell` is the Motion boundary. Flow, Flusso, and `ScrollContainer` content receive no direct Motion transforms, and Backdrop is not transformed.
- Godot 4.7 offset transforms were characterized; interactive Fluo uses `visual_only=false`.
- Motion reset is centralized and state is editor-only/ephemeral: `CLOSED`, `OPENING`, `OPEN`, `SWITCHING_SIDE`, and `CLOSING`.
- A reduced-motion policy boundary exists; D2 uses synchronous transitions and adds no visible Motion or Tween.
- Desktop manual review passed with maintainer approval 🙆‍♀️ on 2026-10-27. Android is not validated.
- Final visual Motion polish remains D8 work.

### D3 external Add and persistence/runtime — D3 COMPLETE

**Status:** `D3 COMPLETE` — automated A–E PASS, manual desktop review PASS, and `$flujo-prove` PASS. No prove run identifier was emitted.

D3 closure: `D3 COMPLETE — PROVE PASS — READY FOR D4`.

The final architecture is:

- **A:** editor-only `FlowEditorBlockAuthoringContext` + `FlowEditorBlockCreationResult`, composing integrated and external catalog/factory entries; production uses the canonical package root and tests inject a fixture root.
- **B:** `FlowGraphEditorCommands.add_ready_block_by_authoring_id(...)` keeps integrated creation registry-backed, routes external creation through the factory, fails atomically, reuses the same created block/FlowId on Undo/Redo, and remains independent of the compatible host container.
- **C:** `FlowReadyProcessEditor` drives Add buttons from generic catalog entries identified by `authoring_id`, sharing the authoring context with commands; Add Call Method remains separate.
- **D:** external blocks use the common Fluo/Flusso selection path without external-specific UI. `message` remains intentionally hidden before D4. Flusso owns only `display_name`, `enabled`, `text`, and `method_id`; Revertir snapshots only rendered/owned properties, and unknown external exports remain untouched. A FlowBlock property is not automatically Flusso-owned.
- **E:** PackedScene persistence and generic runtime preserve the external FlowId, script path, exported data, order and process identity. Runtime requires no editor authoring context, catalog, manifest or factory and performs no fallback/substitution.

Evidence: automated D3 A–E PASS; `D3 manual desktop review: PASS` in `Godot 4.7.2 stable Flathub`. The manual review records Add in Process/Timer, selection/activation, generic Flusso, hidden `message`, generic property editing/Revertir, multiple instances, Delete, Undo/Redo, Add Call Method separation, and built-in availability. It does not claim visual FlowId inspection; that identity/persistence evidence is automated. Android/touch manual acceptance remains outside D3. D4-A is complete, D4-B provides the runtime-safe metadata/reflection descriptor boundary, and D4-C is complete with approved manual Flusso evidence. D4 is complete at the defined A/B/C boundary; no D4-D scope is approved.

## Continuity checkpoint — initial `flujo-block-builder` (2026-10-28)

This is the durable handoff after the initial creation of the Builder Skill. It is
documentation and project memory only: at that checkpoint D4 had **not** started,
no custom block has
been created, and IF, While, Do / Do While and For have not been implemented.

### Worktree and protected state

- Worktree: repository root for this checkout; the machine-local filesystem path is intentionally omitted.
- Branch: `feature/fluo-drawer-poc`.
- HEAD at this checkpoint: `58ca3ae50226351804e32234713e0b3e37f68767`.
- `demo/main.tscn` is a pre-existing protected change; its checkpoint SHA-256 is `83fca704524af87eacf7a85a39335c3b26ac7c051451bb4d6818fd9161304210` and it remained unchanged.
- No commit, push, merge, rebase or PR is authorized for this handoff.

### Historical D0–D4 status at the Builder checkpoint

The following table records the status at that earlier checkpoint; the current
closure is recorded in the D4 section below.

| Phase | Status | Handoff |
| --- | --- | --- |
| D0 | **COMPLETE** | Ecosystem contract, roadmap and governance are frozen. |
| D1 | **COMPLETE** | Manual one-block-per-package SDK profile is proven over the public foundation. |
| D2 | **COMPLETE** | Host-owned Theme/Motion boundary and foundation are proven; final polish remains D8. |
| D3 | **COMPLETE** | Editor authoring context, generic external catalog/factory composition, authoring IDs, generic Add commands, catalog-driven Flow Add UI, external Undo/Redo, Flusso-owned-property boundary, external persistence, generic runtime execution, container-independent creation, manual desktop review and `$flujo-prove` are complete. |
| D4-A | **CONTRACT READY** | Reusable generic property/presentation architecture is frozen; no production renderer. |
| D4-B | **COMPLETE** | Runtime-safe reflection, validated sidecar metadata and deterministic descriptors are implemented; no UI or ownership registration. |
| D4-C | **AUTOMATIC PASS — READY FOR MANUAL REVIEW** | Descriptor-driven generic Flusso controls were implemented; manual visual review was pending at that checkpoint. |

### Builder run and current status

The source run was `RUN_ID=159c0dbf-1f91-49ad-af20-58b75b2aab24`, recorded in
a machine-local coordinator run record; its absolute filesystem path is
intentionally omitted from this portable handoff.
The wrapper reported `PROCESS_EXIT_CODE=0` with
`RESULT_CONSISTENCY=NO_EMBEDDED_REPORT`, so the result was verified from the
actual output and final repository state rather than the exit code alone:

- `tools/agent_skills/flujo-block-builder/SKILL.md` exists and is the only file in its new Skill directory.
- The Builder output reported `git diff --check`, the behavior-catalog validator and model smoke checks as PASS; the model marker was `[Flujo] Model mist test passed`.
- The headless editor load exited normally. Its known diagnostics were `dragger_index = 2 is out of bounds` and `Scan thread aborted...` during planned shutdown; they are warnings/engine diagnostics, not a reported Builder creation failure.
- The run's initial/final inventories show the existing D0–D3 files and protected `demo/main.tscn` preserved, only the new Skill added by the Builder run, no custom block generated, and no commit.

The Builder is therefore **initial planning Skill ready**, not an end-to-end D5
block generator. Its core principle is: **the Skill automates the public Block
SDK; the Skill is not the SDK**. Manual authoring remains first-class and
equivalent; one distributable block is one package; package files are ordinary,
readable and maintainable without the Skill; and no generated package depends on
the Skill at runtime.

### Required Builder workflow

Every custom block request, including a simple block, must follow:

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
BUILD
    ↓
VALIDATE
    ↓
TEST
    ↓
MANUAL REVIEW WHEN REQUIRED
```

The capability gate is mixed when needed: **A — SDK-supported now; B —
SDK-supported but authoring-limited; C — SDK extension required; D — core-only
capability**. A C/D request must explain the gap, propose the smallest public
extension/core plan and stop for approval. The Builder must never silently patch
Flusso or Flujo core.

### Block and control-flow rules

- A `FlowBlock` is container-agnostic and preserves its behavior in compatible `Process`, `Timer`, `State Machine`, future `IF`, future `While`, future `Do` / `Do While`, future `For`, and other compatible containers. Never create `ProcessMyBlock`, `TimerMyBlock` or `IfMyBlock` variants.
- IF, While, Do / Do While and For are custom blocks. They must eventually be created through `flujo-block-builder` as dogfood users of the public SDK and may not receive private block-creation paths.
- Recovered IF context is historical planning only: `condition`, `true_target_block_id`, `false_target_block_id`; generic `FlowNavigationDecision.JUMP`; structural destination validation; and `remap_internal_references()` on duplication. The executor must never branch on concrete `FlowIfBlock`.
- No sufficiently complete approved specification exists for While, Do / Do While or For. Do not invent fields, body representation, termination rules, navigation semantics or persistence; each requires `SPECIFICATION → PLAN → VALIDATION PLAN → 🙆🏻 → IMPLEMENTATION → TESTS`.
- Theme, Motion, focus, layout, input policy and standard Flusso presentation belong to the Fluo host/editor. Packages provide block behavior and approved data metadata only.

### Validation conventions and next handoff

For this documentation/Skill-only checkpoint, the relevant conventions are
`git diff --check`, the canonical behavior-catalog validator, the headless editor
load, the model smoke marker, and separate manual desktop evidence when visible
editor behavior is involved. A behavior catalog change would require its
validator; this checkpoint does not change `docs/behavior_catalog.json`.

The next phase after this checkpoint was D4. The subsequent D4-A contract-only
delivery froze generic Flusso property description/presentation and the future
runtime-debugger boundary. D4-B implements the runtime/model descriptor layer and
D4-C implements the production generic Flusso renderer. That checkpoint's pending
manual review is superseded by the approved closure recorded below.

## D4-A — Generic Block Property / Presentation Contract — COMPLETE

D4-A is documentation-only and is specified by [FlowBlock Property Presentation Contract](flow_block_property_presentation_contract.md).
It deliberately replaces the historical `editor_schema.json` terminology with
the optional `block_property_presentation.json` sidecar. The shared descriptor
boundary uses limited Godot reflection for model truth and validated data-only
presentation metadata for safe labels, ordering, grouping, tooltips, and approved
generic hints.

The contract freezes the eligible property rule, the v1 scalar type set, invalid
metadata fallback, deterministic ordering, explicit Flusso ownership and
Revertir boundaries, container independence, and a runtime-safe description path
without editor APIs. It records the future Game Debug Panel requirement only;
there is no debug UI, runtime transport, or production renderer in D4-A.

Editor authoring remains persistent and undoable through the existing command
boundaries. Future runtime debug edits initially affect live execution only and
do not imply scene/package/source write-back. D4-C renders only validated
descriptor fields, registers ownership after successful control creation, and
keeps no control-flow block or Builder generation in scope.

## D4-C — Generic Flusso renderer — COMPLETE — MANUAL PASS

D4-C is implemented over the D4-A/D4-B descriptor boundary. The editor authoring
context delegates property description to `FlowBlockPropertyCatalog`; the generic
Flusso renderer consumes descriptor presentation kinds rather than package/type
branches, keeps explicit built-in controls singular, surfaces diagnostics, and
uses the existing live undo boundary for edits. Ownership and Revertir snapshots
are limited to controls that were actually rendered and are editable.

The focal `tests/editor/flow_generic_flusso_property_editor_test.gd` proves the
supported scalar controls and standard hints, metadata labels/order/groups/tooltips,
diagnostics, live editing, ownership, Revertir, built-in collision protection and
Process/Timer equivalence. `FLUJO-BHV-FLUO-GENERIC-PROPERTY-001` records the
behavior. Persistence/runtime, Process/Timer, Fluo drawer and editor-load
regressions are proportionately covered. No schema, runtime execution, custom
block, control-flow block or protected `demo/main.tscn` change is included.

Manual visual review is complete for the actual Flusso surface, multiline editing,
focus, scrolling, Theme presentation, diagnostics, save/reopen and keyboard
interaction. Android/touch acceptance remains a separate Preview 1 gate.

### D4-C closure record

`D4-C COMPLETE — MANUAL FLUSSO REVIEW PASS`

The approved review ran in `Godot 4.7.2 stable Flathub` with human approval
`🙆‍♀️`. Process PASS, Timer PASS, generic property controls PASS, live editing
PASS, Revertir PASS, multiple instances PASS, no duplicate built-ins PASS and
container independence PASS were observed. The same configuration rendered in
both containers; labels, groups, deterministic order, scrolling, navigation,
selection, close/reopen persistence and independent Descriptor Output instances
remained functional. The known `dragger_index = 2 is out of bounds` diagnostic
was the only visible engine diagnostic. The intentional
`unsupported_property_type` fixture diagnostic remains within the D4 v1 scalar
contract and is not an acceptance failure.

| Phase | Current status |
| --- | --- |
| D4-A | **COMPLETE** |
| D4-B | **COMPLETE** |
| D4-C | **COMPLETE — MANUAL PASS** |
| D4-D | **NOT DEFINED** — no approved scope |

The temporary `flow_packages/manual_output/` package was removed; fixtures under
`tests/fixtures/` remain. The D4-C review is closed by the Major Increment
Checkpoint below.

## Major Increment Checkpoint — D4-C / D5 boundary — 2026-10-29

### D4-D audit result

The canonical [Flujo Block Ecosystem Contract](block_ecosystem_contract.md)
defines D4-A, D4-B and D4-C, then proceeds directly to D5. The audit found no
technical D4-D scope, requirement set, dependencies, or D4-D A–E acceptance
matrix. The historical `D4-D NEXT` wording is therefore retired as a stale
continuity placeholder, not treated as a pending delivery. D4 is complete at
D4-C. Any future D4-D requires a new numbered specification, plan, acceptance
matrix and explicit maintainer approval.

### D5 definition and FPrint Guardería status

D5 is the **functional `flujo-block-builder v1`** delivery. The planning Skill
alone is not D5. The approved FPrint Guardería slice generated and validated
the ordinary one-block package through the public SDK, with deterministic
readable files, no Builder runtime dependency, no absolute paths, and no silent
core patch. Its manual Godot review is approved and the slice is closed; this
does not declare functional Builder v1 or FPrint v1 complete.

`FPrint` is distinct from legacy `Print` and is frozen for this slice as
package `mercury.fprint`, type `fprint`, authoring ID `mercury.fprint:fprint`,
with `prefix`, multiline `message`, and `suffix`; runtime output is the exact
composition `prefix + message + suffix`. The package is proven through public
catalog Add, generic Flusso, persistence, duplication and one compatible
`Process` host. Timer, State Machine, and future container behavior is not
claimed by this delivery.

The closure records are:

- `FPRINT GUARDERÍA MANUAL PASS`
- `FPRINT GUARDERÍA CLOSED — EDITOR CLEANUP READY FOR MANUAL REVIEW`

The approved manual review covered visible Add, Prefix/Message/Suffix editing,
live updates, Revertir, independent instances, exact Process execution,
Inspector → Fluo entry, Fluo-primary F4/menu behavior, and active-block
deletion with Flow retained and Flusso closed. The observed FPrint output was
the configured literal `hola mundo!!!\nyo soy FPrint!!!`. The separate Kínder
K3 descriptor delivery is recorded below and does not change this Guardería
boundary.

The Builder planning gate was completed and explicitly approved with `🙆‍♀️`.

### FPrint Kínder — K3 Generic Chip Descriptor — READY

K3 provides reusable runtime semantic projections for structured chip segments:
`FlowChipTypeDescriptor`, `FlowChipTooltipData`, and the common
`FlowChipSegment` descriptor/label/tooltip contract. `FlowLiteralValueSegment`
is the first consumer and keeps `literal_value` identity separate from its
`Literal` display name, with deterministic labels and ordered Type/Value/Variant
tooltip fields for bool, int, float, String, and StringName.

K3 does not add a visual chip, editor controls, colors, events, selection,
FPrint migration, or VariableRef/Expression/NodePropertyRef classes. Its focal
test is `tests/model/flow_chip_descriptor_test.tscn`; K1/K2 structured-document
and Guardería regressions remain independent evidence.

> **Builder Lesson Candidate:** Los bloques que necesiten contenido mixto de
> texto + valores estructurados no deben construir chips privados. Deben
> consumir el Generic Typed Chip System público.

### FPrint Kínder — K4 Generic Chip Visual + FlowStructuredDocumentEditor — MANUAL REVIEW PENDING

K4 adds the editor-only `FlowChipControl`, Theme adapter, and
`FlowStructuredDocumentEditor`. The surface renders ordered text and real
Control chip units, uses `segment_id` selection, exposes `+ Value`, and records
insert/delete/type/value/text operations in the owning
`EditorUndoRedoManager`. The generic runtime contract supplies supported
Variant.Type values and defaults; no FPrint-specific widget, parser, package
migration, or runtime/editor dependency was introduced.

The automatic focal is `tests/editor/flow_structured_document_editor_test.tscn`.
The manual review surface is the editor menu **Project → Tools → Open
Structured Document Harness** or
`tests/editor/flow_structured_document_editor_harness.tscn`. K4 remains open
until the visual/manual checklist is approved.

> **Builder Lesson Candidate:** Los bloques que necesiten edición de contenido
> estructurado deben reutilizar `FlowStructuredDocumentEditor` y el Generic
> Typed Chip Control; no deben crear widgets privados por tipo de bloque.

### FPrint Kínder — K5 Structured Document Package Integration — AUTOMATIC PASS — MANUAL REVIEW PENDING

K5 is bounded by [FPrint Kínder K5 Contract](fprint_kinder_k5_contract.md).
The ordinary `mercury.fprint` package now retains `prefix`, multiline `message`,
and `suffix`, and adds optional `document: FlowStructuredDocument`. A null
document preserves the closed Guardería output; a present document replaces
`message` through `FlowStructuredDocumentRenderer`.

The package uses the public generic descriptor/catalog and host-owned Flusso
renderer. A null value shows the generic **Enable Structured Document** control;
there is no automatic legacy conversion. A present value uses the reusable
`FlowStructuredDocumentEditor` and public `FlowChipControl`/Typed Chip System.
Structured edits are live, owner-scoped to the `PVController` undo history, and
Revertir uses a deep ID-preserving snapshot. Persistent duplication gives nested
segments new IDs; ResourceSaver/PackedScene and the generic Process runtime are
covered separately from the editor surface.

The capability gate records package/runtime/persistence as A, the reusable
structured-document Flusso presentation as the smallest C extension, and
FPrint-specific widgets/parsers/core control-flow as D/out of scope. K5 does
not declare functional `flujo-block-builder v1` or FPrint v1 complete, does not
change graph schema or manifest v1, and does not update the Builder Skill.

Fresh 2026-10-29 focal and proportionate regression evidence passes and is
recorded in the K5 behavior-catalog entries. A visual smoke review observed the
real Inspector → Fluo → Flow → Flusso enable, `+ Value`, typed edit, Undo/Redo,
Revertir, and close path without saving the protected demo scene. Manual
integrated Flusso approval remains pending for the full text/chip
tooltip/selection, keyboard focus, Unicode/multiline/@/#/$, save/reopen, and
independent-instance checklist.

> **Builder Lesson Candidate:** Optional structured content should consume the
> public generic document/renderer/editor path and preserve its legacy scalar
> compatibility field; it should not create a private parser, chip, or editor.

> **Builder Lesson Candidate:** Revert snapshots preserve segment IDs while
> persistent duplication creates new IDs; both semantics must be tested
> explicitly rather than inferred from a shallow resource copy.

### Flujo Chips Core Step 1B — schema, slots, and value sources

Step 1B is a reusable runtime/model boundary, not an FPrint feature. A
`FlowChipFieldSchema` declares FIXED, FLEXIBLE, or HYBRID shape, text policy,
semantic slot definitions, accepted exact types/source kinds, and runtime-safe
initial sources. `FlowChipFieldValidator` compares the schema with an ordered
`FlowStructuredDocument` without repair. `FlowLiteralValueSource` is the only
concrete source in this step; K1/K2 `FlowLiteralValueSegment` remains the
persisted compatibility path through `get_value_source()`.

The neutral focal is `tests/model/flow_chip_core_step_1b_test.tscn`, including
ResourceSaver and deep-duplication evidence. No inline editor, parser, trigger,
block runtime, For/If/Process block, or FPrint integration belongs to Step 1B.

> **Builder Lesson Candidate:** Each block that uses chips declares a reusable
> `FlowChipFieldSchema` rather than private count, order, type, or requiredness
> rules.

> **Builder Lesson Candidate:** Executable chip values use `FlowValueSource`,
> not widgets or visible text.

The implementation worktree is `feature/block-builder-fprint-dogfood` at
`ddbf272cf5d4a38aaf38a18917596e168afd870a` before delivery changes. The
protected `demo/main.tscn` was not edited by this delivery. Its observed
working-tree checksum is `41f9e2ec5d60a869f2232c14c0bcda5213d145f4b1a7fcc508dfc17cd56e4540`,
which differs from the historical declared `83fca704524af87eacf7a85a39335c3b26ac7c051451bb4d6818fd9161304210`;
the discrepancy remains preserved and unresolved.

### Compatibility decisions protected by this checkpoint

- Official Mercury blocks and external/user blocks use the same public SDK and
  package contract; official status grants no private route.
- Legacy `Print`, `Custom Hello` and `Everything Flows` remain available and
  unchanged for compatibility/reference. `Add Call Method` remains a separate
  editorial category and route. `FlowBlockRegistry` remains unchanged.
- The visible legacy dock and `Open Fluo (POC)` route are no longer production
  mounted or registered. `vp_flujo_dock.gd` remains only for isolated
  compatibility coverage; Fluo is the primary F4, menu, and Inspector surface.
- One block per package is the canonical future distribution profile, while the
  manifest v1 loader remains compatible with historical multi-descriptor
  manifests. This checkpoint adds no graph schema or manifest v1 field.
- Official migration is gradual and compatibility-first; persisted script paths,
  IDs, scenes and supported projects require an explicit compatibility shim or
  migration before a later migration removes an integrated route.

### Checkpoint state

- Branch: `feature/block-builder-fprint-dogfood`; repository HEAD remains
  `ddbf272cf5d4a38aaf38a18917596e168afd870a` and delivery changes are
  uncommitted.
- The protected `demo/main.tscn` was not edited by this delivery. The observed
  working-tree checksum is
  `41f9e2ec5d60a869f2232c14c0bcda5213d145f4b1a7fcc508dfc17cd56e4540`,
  differing from the historical declared
  `83fca704524af87eacf7a85a39335c3b26ac7c051451bb4d6818fd9161304210`; both
  the file and discrepancy remain preserved.
- No commit, push, merge, rebase or pull request is part of this checkpoint.

## Next maintenance sequence

1. Keep the closed FPrint Guardería slice bounded; do not claim Builder v1 or
   FPrint v1 complete.
2. K4 is implemented and awaiting manual visual approval; K5 automatic evidence passes but its integrated manual approval remains pending.
3. Complete Android interaction validation.
4. Fix preview issues in small batches.
5. Run affected focal tests and manual checks; never infer passes.
6. Tune panel proportions from device evidence.
7. Implement and validate Themes + Motion polish.
8. Define first stable release criteria.

Todo es Flujo; todo fluye. 🌊
