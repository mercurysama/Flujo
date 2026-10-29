# Current Iteration

## Active UI delivery — Fluo Preview 1

- **Branch:** `feature/fluo-drawer-poc`.
- **Validated functional checkpoint:** `cd7e969c38193d718c948262107d1f7a45ca8083`.
- **Frozen code backup:** `backup/fluo-preview-1-2026-10-27` at the same checkpoint.
- **Preview package:** `Flujo-0.1.0-fluo-preview.1`; `plugin.cfg` remains `0.1.0`.
- **Naming:** Fluo = complete sliding drawer; Flow = left block panel; Flusso = right selected-block configuration panel; Inspector = Godot Inspector.
- **Inspector rule:** no duplicate Blocks list belongs in the Inspector. Existing container rows such as `Processes → Flujo`, `Flujo 1`, Timers, Constructor, or Methods are the entry points.
- **Open rule:** double-click or Enter on an existing Inspector container opens Fluo with Flow visible and Flusso initially closed. Flow focuses the first existing block, or the first Add-block button when empty.
- **Block rule:** double-click or Enter on a Flow block opens Flusso. Closing Flusso returns real keyboard focus to the same selected Flow block after rebuild.
- **Persistence rule:** Flusso configuration changes are live/immediate; Escape only closes. Revertir restores the persistent configuration snapshot captured when that Flusso session opened.
- **Keyboard:** Up/Down uses native Flow list movement; Ctrl+PageUp/PageDown cycles Flow blocks; plain PageUp/PageDown cycles the current Inspector container view and synchronizes the Inspector's visible selection while keyboard focus stays in Flow; Alt+PageUp/PageDown cycles Flusso controls and Shift reverses that Alt direction.
- **Drawer:** side switch moves the complete Fluo drawer left/right. First Escape closes Flusso when open; the next Escape closes Fluo.
- **Legacy surface:** the visible `Flujo` dock and `Open Fluo (POC)` path remain temporarily for validation only.
- **Manual evidence:** desktop interaction was repeatedly approved during implementation. On 2026-10-27 the full-project preview opened under Godot on Android and visibly rendered Fluo, Flow and Flusso. This is load/render evidence, not a claim that the full Android interaction matrix is complete.
- **Automation evidence:** the final focal editor/regression run on 2026-10-28 passed; known editor-layout and teardown diagnostics remain recorded separately.

Read [Project memory / handoff](project_memory.md) and [Fluo Preview 1](fluo_preview_01.md) before continuing this branch.

Custom-block SDK research and the recovered requirements for `flujo-block-builder` are consolidated in [Custom Block SDK and Block Builder Skill Research](custom_block_sdk_research.md). The research confirms the external manifest/catalog/factory/hooks foundation and the normal Flow/Fluo external Add integration are implemented; D4-A, D4-B and the D4-C generic Flusso renderer are complete, with the D4-C manual Flusso review approved. The canonical contract has no technical D4-D delivery or D4-D A–E acceptance matrix; the historical `D4-D NEXT` wording is retired, not a pending implementation task. D5 is the next eligible ecosystem delivery.

## D0 — Block ecosystem contract

The reconciled block ecosystem roadmap is documented in [Flujo Block Ecosystem Plan](flujo_block_ecosystem_plan.md), and the maintainer-approved architectural boundary is frozen in [Flujo Block Ecosystem Contract](block_ecosystem_contract.md).

D0 is documentation/governance only. It fixes the D0–D9 implementation order, one distributable block per package, manual authoring as a first-class path, `flujo-block-builder` as optional automation, Theme/Motion ownership in the Fluo host, generic Flow/Flusso integration requirements, declared provenance separated from cryptographic authenticity, and gradual compatibility-first migration of official blocks to independent Mercury packages. Functional implementation begins only in later numbered deliveries.

## D1 — Manual Block SDK profile

D1 is specified by [Manual Block SDK Profile Contract](manual_block_sdk_contract.md). It proves the one-block-per-package manual authoring profile over the existing manifest loader, script validator, editor catalog and external factory without modifying `addons/vp_flujo/`, connecting the normal Flow Add path, or claiming generic Flusso support.

The canonical D1 fixture lives under `tests/fixtures/manual_block_sdk/` and is test evidence rather than an installed user package. D1 did not include presentation metadata; the later D4-A contract now names the optional sidecar `block_property_presentation.json`. `provenance.json` remains intentionally outside D1.

## D2 — Theme + Motion contract

D2-A is specified by [Fluo Theme + Motion Contract](fluo_theme_motion_contract.md). It freezes the editor-side ownership, Container/layout boundary, focus/input rules, transition state semantics and offset-transform safety requirements before any functional Motion refactor.

D2-A changes documentation only and runs the current Fluo baseline. D2-B may modify production only after the required `$flujo-baseline` gate is explicitly invoked for this scope.

### D2 completion — Theme + Motion Foundation

- D0 is complete.
- D1 is complete.
- D2-A is complete.
- D2-B1 is complete, including the Godot 4.7 offset-transform characterization.
- D2-B2 is complete, including the host-owned Theme boundary and Motion foundation.
- The desktop manual review is complete: `Desktop manual review PASS — maintainer approval 🙆‍♀️ — 2026-10-27`.

The Theme + Motion foundation now exists without visible animation polish. D8 remains responsible for final Motion visual/polish work; D2 does not add visible Motion.

The host architecture is:

```text
FluoDrawer
├── Backdrop
└── DrawerMotionShell
    └── DrawerPanel
```

Backdrop and DrawerMotionShell are siblings. `DrawerMotionShell` is the single Motion boundary and `DrawerPanel` remains inside it. D2 validates `visual_only=false` for the interactive shell, keeps Theme ownership in the host/editor, installs no global Theme, uses a synchronous state machine, provides a reduced-motion policy boundary, and uses no Tween or animation path. Flow, Flusso, and ScrollContainer content remain under their logical Container/layout ownership; Backdrop is not transformed.

The desktop evidence covered open/close, X, exterior click, Escape hierarchy, Flow focus, Flusso return focus, Page/Ctrl+Page/Alt+Page navigation, left/right switching, long scroll, equivalent visual appearance, and absence of visible Motion. Android is not approved by this review.

## D3 — External catalog in the real Add row — D3 COMPLETE

### D3 closure record

**Status:** `D3 COMPLETE` — automated A–E PASS, manual desktop review PASS, and `$flujo-prove` PASS.

D3 closure: `D3 COMPLETE — PROVE PASS — READY FOR D4`.

D3 is the generic external-authoring and persistence/runtime delivery. Its architecture is:

- **Phase A — editor-only authoring composition:** `FlowEditorBlockAuthoringContext`, `FlowEditorBlockCreationResult`, integrated plus external catalog/factory composition, the canonical production package root, and an injectable fixture root for tests.
- **Phase B — generic Add command:** `FlowGraphEditorCommands.add_ready_block_by_authoring_id(...)`; integrated blocks remain registry-backed, external blocks use the external factory, failures are atomic, Undo/Redo reuses the same block and FlowId, and the creation path is independent of the compatible host container.
- **Phase C — catalog-driven Add UI:** `FlowReadyProcessEditor` enumerates generic catalog entries rather than concrete external types; button identity is `authoring_id`; UI and commands share one authoring context; Add Call Method remains separate.
- **Phase D — pre-D4 generic Flusso compatibility:** external blocks use the common selection/activation path; no external-specific UI is added; `message` is intentionally hidden; Flusso-owned properties are `display_name`, `enabled`, `text`, and `method_id`; Revertir snapshots only properties owned by rendered controls, leaving unknown exported external properties untouched. A property on `FlowBlock` is not thereby Flusso-owned. Reflection and presentation metadata belong to D4; their reusable contract is now D4-A.
- **Phase E — persistence/runtime:** external blocks survive PackedScene save/reload with the same FlowId, script path, exported data, order and process identity; runtime consumes the persisted `FlowBlock` through the generic executor without editor authoring context, catalog, manifest or factory, fallback, or substitution.

Automated D3 evidence is recorded as A–E PASS. The required focal paths are the authoring-context, external command Add, catalog-driven editor, owned-property Revertir, persistence/runtime, manual SDK profile, and the existing runtime/editor regressions listed in the behavior catalog.

### D3 manual desktop review

`D3 manual desktop review: PASS`

Environment: `Godot 4.7.2 stable Flathub`

Observed: Manual Output was available through production package discovery in Process and Timer; it could be added and selected; Enter/double activation opened Flusso with generic controls; `message` was not rendered; Block Name/Enabled and Revertir worked; multiple external instances, Delete, Undo/Redo, separate Add Call Method, and built-ins all remained available. The known `SplitContainer dragger_index` visual diagnostic is recorded separately. This review does not claim visual FlowId inspection; FlowId persistence/identity is automated-test evidence.

D3 does not include Android/touch manual acceptance unless explicitly performed. D4-A is complete, D4-B provides the runtime-safe metadata/reflection descriptor boundary, and D4-C provides the complete generic Flusso property renderer with approved manual visual evidence. D4 is complete at the defined A/B/C boundary; no D4-D scope is approved.

## Continuity checkpoint — initial `flujo-block-builder` (2026-10-28)

This checkpoint records the initial Builder Skill after D3. It does **not** start
D4, create a custom block, or authorize IF/While/Do/For implementation.

| Milestone | Status | Current boundary |
| --- | --- | --- |
| D0 | **COMPLETE** | Block ecosystem contract and governance frozen. |
| D1 | **COMPLETE** | Manual one-block-per-package SDK profile proven. |
| D2 | **COMPLETE** | Theme/Motion host boundary and foundation proven. |
| D3 | **COMPLETE** | Generic Add, external Undo/Redo, owned-property boundary, persistence/runtime and container-independent creation path proven; manual desktop review and `$flujo-prove` passed. |
| D4-A | **COMPLETE** | Reusable generic property/presentation architecture is frozen and accepted as the D4 boundary. |
| D4-B | **COMPLETE** | Runtime-safe reflection, validated sidecar metadata and deterministic generic property descriptors are implemented; no UI or ownership registration. |
| D4-C | **COMPLETE — MANUAL PASS** | Descriptor-driven generic Flusso controls, live editing, ownership, diagnostics, Process/Timer equivalence and Revertir are accepted by manual review. |
| D4-D | **NOT DEFINED** | The canonical contract defines no delivery, requirements, dependencies, or A–E acceptance matrix. A future D4-D requires a new numbered specification and approval. |

The Builder run was `RUN_ID=159c0dbf-1f91-49ad-af20-58b75b2aab24`. Its actual
output ended with `FLUJO-BLOCK-BUILDER V1 SKILL READY — NO BLOCK GENERATED`.
The created artifact is only
`tools/agent_skills/flujo-block-builder/SKILL.md`; its checks reported
`git diff --check` PASS, the behavior-catalog validator PASS, and the model smoke
marker `[Flujo] Model mist test passed`. The headless editor load exited normally
with the known `dragger_index` diagnostic and planned-shutdown
`Scan thread aborted...` warning. The initial and final run inventories show no
custom block package, no Builder-created production edit, and no commit.

The governing architecture is:

- The Skill automates the public Block SDK; **the Skill is not the SDK**.
- Manual GDScript, JSON and ordinary readable package files remain first-class and equivalent.
- One distributable block is one package under `res://flow_packages/<package_id>/`.
- Generated packages have no Builder runtime dependency and must remain manually maintainable.
- Every request uses the mandatory planning gate in `tools/agent_skills/flujo-block-builder/SKILL.md`: recover context → classify capability → specify → plan implementation → plan validation → human review → `🙆🏻` explicit approval → build/validate/test/manual review as applicable.
- Capability classifications are mixed when needed: A = SDK-supported now; B = SDK-supported but authoring-limited; C = SDK extension required; D = core-only capability. C/D requests stop with an explained plan and approval; the Builder never silently patches Flujo core.
- A `FlowBlock` is container-agnostic. Do not create `ProcessMyBlock`, `TimerMyBlock` or `IfMyBlock` variants; compatible containers control sequence timing while the block preserves its own behavior.
- IF, While, Do / Do While and For are future custom blocks that must eventually use this public Builder workflow, not private control-flow creation paths. IF remains unimplemented; While/Do/For have no sufficiently complete approved specifications and must not be invented.
- Theme, Motion, focus, layout and standard interaction remain owned by the Fluo host/editor, never by a package.

The current handoff at this checkpoint was D4 next, before the subsequent D4-A
contract-only delivery. The protected `demo/main.tscn` change remains untouched.
The checkpoint itself is documentation and Skill memory only; no full Godot suite
was required for that prior scope beyond the repository-governed checks recorded
above.

## D4-A — Generic Block Property / Presentation Contract — COMPLETE

D4-A is documentation-only and is specified by [FlowBlock Property Presentation Contract](flow_block_property_presentation_contract.md).
It freezes a reusable, UI-independent descriptor boundary built from limited
Godot property reflection plus optional data-only
`block_property_presentation.json` metadata. The model/script remains
authoritative for property existence, type, current/default values, and
persistence. The contract defines eligible properties, supported scalar types
and standard hints, deterministic ordering, invalid-metadata fallback,
Flusso-owned-property registration, Revertir snapshots, container independence,
and runtime-safe reuse.

The terminology deliberately replaces the historical `editor_schema.json`
proposal because the same safe presentation description may later serve the
runtime Game Debug Panel. The future panel is an architectural constraint, not a
D4-A implementation. It must not require editor APIs, and its initial edits are
live-runtime-only without implicit scene/package/source write-back.

Production generic rendering is implemented by D4-C from the D4-B descriptor
layer. No custom block or `IF`/`While`/`Do`/`For` implementation is authorized by
this contract.

## D4-C — Generic Flusso renderer — COMPLETE — MANUAL PASS

D4-C implements the descriptor-driven Flusso surface authorized by D4-A and D4-B.
`FlowEditorBlockAuthoringContext.describe_block_properties()` resolves optional
package-relative presentation metadata through the reusable runtime catalog; the
editor does not parse metadata itself. `FlowReadyProcessEditor` creates common
controls from descriptor `presentation_kind`, excludes actively explicit built-ins
to prevent duplicates, presents diagnostics, and registers Flusso ownership only
after an editable generic control is created. Live edits use the descriptor-
validated `FlowGraphEditorCommands.set_ready_property_descriptor_live()` boundary,
preserving the existing undo/live-edit path. Session snapshots and Revertir cover
only the rendered owned set.

The focal test `tests/editor/flow_generic_flusso_property_editor_test.gd` covers
bool, int, float, String, StringName, range, enum, multiline, labels, order,
groups, tooltips, diagnostics, live editing, ownership, Revertir, built-in collision
protection, and Process/Timer equivalence. The behavior entry is
`FLUJO-BHV-FLUO-GENERIC-PROPERTY-001`. Proportionate persistence/runtime and
editor regressions also pass. No schema, manifest, runtime execution, custom block,
control-flow block, or protected `demo/main.tscn` change is part of D4-C.

Manual visual review is complete for the rendered Flusso field surface, multiline
editing, labels/tooltips, keyboard focus, scrolling, Theme presentation,
empty/diagnostic states, save/reopen interaction and navigation. Android/touch
acceptance remains a separate Preview 1 gate.

### D4-C closure record

`D4-C COMPLETE — MANUAL FLUSSO REVIEW PASS`

Environment: `Godot 4.7.2 stable Flathub`; human approval: `🙆‍♀️`.

- **Process PASS; Timer PASS; container independence PASS:** `manual_output:output` was available in the Add row and the same generic configuration worked in both containers.
- **Generic property controls PASS:** Boolean, String multiline, enum selector, ranged int, plain String, ranged float, StringName and User Note multiline rendered and edited correctly; presentation labels, deterministic order, groups and headings were visible.
- **Live editing PASS; Revertir PASS:** edits were live, close/reopen preserved the edited state, and Revertir restored the session snapshot.
- **Multiple instances PASS:** Descriptor Output instances remained independent; no duplicate Block Name, Block Enabled or other explicit built-in controls appeared.
- **Flow/Flusso behavior PASS:** scrolling, navigation and selection remained functional; no package-specific visual branch was observed.
- **Console evidence:** real Add, Edit and Revertir operations were observed for Descriptor Output in Process and Timer.
- The only visible engine diagnostic was the known `scene/gui/split_container.cpp:124 - Index dragger_index = 2 is out of bounds`, classified as non-blocking. The `unsupported_property_type` diagnostic is intentional fixture/contract behavior for the D4 v1 scalar boundary; supported types were not expanded and diagnostic presentation was not redesigned.

The temporary `flow_packages/manual_output/` package was removed after review;
the canonical fixture under `tests/fixtures/` remains. The D4-C review is closed
by the Major Increment Checkpoint below.

## Major Increment Checkpoint — D4-C / D5 boundary — 2026-10-29

### D4-D audit result

The canonical [Flujo Block Ecosystem Contract](block_ecosystem_contract.md)
defines D4-A, D4-B and D4-C, then proceeds directly to D5. It contains no
technical D4-D scope, requirement set, dependency list, or A–E acceptance
matrix. Therefore D4 is complete at D4-C; `D4-D NEXT` is a stale continuity
label, not an authorized task. If a future delivery is called D4-D, it must
first receive its own numbered specification, plan, acceptance matrix and
maintainer approval.

### D5 definition

D5 means a **functional `flujo-block-builder v1`**, not merely the planning
Skill. The functional delivery must generate and validate an ordinary,
one-block package through the public SDK, produce deterministic and manually
reproducible files, reject unsupported or invalid requests through the A/B/C/D
capability gate, and prove the package through Flow Add, Flusso, persistence
and runtime without a Builder runtime dependency or a silent Flujo-core patch.
The current `tools/agent_skills/flujo-block-builder/SKILL.md` is planning-ready
only; no Builder-generated package exists and D5 is not complete.

`FPrint` is the planned first future dogfood block for this workflow and is
distinct from legacy `Print`. Its package ID, type ID, visible behavior and
configuration are intentionally **not frozen**. Before any FPrint files are
created, its request must pass the complete planning gate and classify runtime,
persistence, Flow Add and Flusso capabilities as A, B, C or D. A C/D result
stops for an approved public extension/core plan.

### Compatibility decisions protected by this checkpoint

- Official Mercury blocks and external/user blocks use the same public SDK and
  package contract; official status does not create a private route.
- Legacy `Print`, `Custom Hello` and `Everything Flows` remain available and
  unchanged for compatibility/reference. `Add Call Method` remains a separate
  editorial category and route. `FlowBlockRegistry` is not changed here.
- The canonical future distribution profile is one block per package, while
  the manifest v1 loader remains compatible with historical multi-descriptor
  manifests. No graph schema or manifest v1 field is added by this checkpoint.
- Official-block migration remains gradual and compatibility-first; persisted
  script paths, IDs, scenes and supported projects require an explicit shim or
  migration before any later migration removes the integrated route.

## Iteration 7 planning — Typed Variables

- **Latest completed iteration:** Iteration 6 — Constructor and Reusable Methods.
- **Integration:** `06d759cf3c53bae95fbf2c022873cbef4d7db94e` on 2026-09-07T22:01:55-06:00. See the [Iteration 6 postmortem](iteration_06.md).
- **Primary environment:** Fedora with Godot 4.7.2. Windows remains a supported compatible platform; no Windows-specific workflow is required.
- **Approved planning contract:** [Typed Variables contract](typed_variables_contract.md). Implementation begins only through its numbered deliveries.

### Implemented

- Schema 3 persistent structure, deterministic validation, deep duplication, and PackedScene persistence coverage.
- Atomic schema 2 → 3 migration that preserves validated schema 2 data and creates an empty constructor and methods collection.
- `FlowConstructorDefinition` as a specialized `FlowBlockContainer`, including inherited blocks and ordered nullable dependencies.
- Reusable method definitions and typed parameter declarations as persistent structural data.
- Persistent `FlowMethodCallBlock` references from constructor, method, process, and state containers, with deterministic schema/reference validation and order-independent duplication remapping.
- Optional typed `FlowMethodReturnDefinition` declarations with global identity validation, deep duplication, and ResourceSaver/PackedScene persistence.

### Iteration 7 scope

- Preserve the existing seven-member `FlowVariableDefinition.ValueType` taxonomy and its typed defaults without changing numeric serialization values.
- Delivery 2 implemented: deterministic validation rejects out-of-range `Scope`, `Binding`, and shared `ValueType` metadata while preserving invalid values and existing schema 2/3 compatibility.
- Delivery 3 implemented: smoke, `ResourceSaver`, and `PackedScene` regressions cover every canonical typed field through schema 2/schema 3 duplication and schema 2 to 3 migration, preserving IDs, references, order, `null` positions, and independent copies.
- Delivery 4 implemented: the Godot Inspector owns schema 3 Variable structure—ordered nullable list, stable-ID selection, add, move, and confirmed delete—while the Flujo panel edits only the selected variable's typed options. A plugin-owned editor-only coordinator relays the active `PVController` and selection without persisting UI state. Stable-ID selection remains correct when keyboard focus naturally remains elsewhere; popup close and undo/redo do not force focus. A stronger unfocused-selection shade is deferred as a visual improvement. It preserves inactive typed values, nullable collection positions, schema 1/schema 2 behavior, and invalid enum metadata until an explicit replacement.
- Delivery 5 implemented: editor regressions cover keyboard entry to an unselected schema 3 Variables list, arrow-key row selection, native Tab/Shift+Tab focus traversal, Enter/Escape behavior, Ctrl+Enter for multiline String and Note fields, `OptionButton`, COLOR, and Delete confirmation. Public plugin metadata, controls, dialogs, tooltips, undo/redo labels, and mechanically translatable plugin comments are English. Semantic stable-ID selection remains independent from keyboard focus. Automated evidence is complete; manual visual approval remains pending.
- Temporary user-experience debt: schema 3 creation currently follows `Create FlowGraph → migrate schema 2 → migrate schema 3`. This is not the intended final creation workflow and requires a separately approved design.
- A friendly separate user guide is deliberately deferred to a separately approved follow-up; it is not implemented by Delivery 5.

### Deliberately pending

- Implementation of the remaining `ARGRET` contract: argument bindings, value-source validation, return blocks, and incomplete-return-path validation.
- Recursion and call-cycle validation.
- Dependency bindings, general runtime state, and execution beyond the scoped Constructor, Ready, Timer and one-level method starter paths.
- Constructor dependency authoring and method parameter/return authoring.
- Enumerators, nullable values, persistent object references, and value-source resources; these require an approved schema 4 contract and migration.

### Not implemented by Iteration 6

This iteration has not introduced argument bindings, return blocks or runtime return values, value-source connections, cycle detection, an executor, scene bindings, method-call execution, runtime mutation, or editor interface for schema 3 declarations.

### Current delivery

- Schema 5 runtime attribute stores now include catalog-backed inherited layouts, controller-owned INSTANCE values, declaring-class CLASS routing within the active `SceneTree`, and requester visibility checks with the symmetric PRIVATE name exception. Focused coverage verifies three-level base-to-derived layout, stable-ID collisions, access, exact types, nullability, readonly/const rejection, reset, scene continuity and deterministic teardown; general model, persistence, schema 3 runtime and editor regressions pass. Schema 5 remains excluded from executable block paths. Call frames, accessors, UI, and Apply Constructor remain pending. See FOBJ-001/002/003/005/009 in the [Flujo Object Model contract](flow_object_model_contract.md).

- Declarative Constructor persistent foundation on `feature/declarative-constructor`: schema 4 requirements, deterministic structural validation, deep duplication, confirmed 3→4 migration and the public 2→3→4 chain are implemented, with ResourceSaver/PackedScene focal coverage and passing general regressions. Controller-owned relative binding dictionaries remain independent across controllers and scene instances sharing one graph. Constructor blocks/dependencies are preserved as inert legacy data. Schemas 1–3 retain their behavior; the executor still accepts only schema 3. Apply Constructor, scene-node creation, declarative UI, binding resolution and runtime verification remain pending under the [Declarative Constructor contract](declarative_constructor_contract.md).

- Schema 5 object-model foundation on `feature/declarative-constructor`: the existing graph ID is class identity; portable UID/path catalog entries, single-inheritance validation, INSTANCE/CLASS attribute definitions, typed reference resources, ordered method outputs, deep duplication and atomic 4→5 / 2→3→4→5 migration are implemented. Existing Variables and controller bindings remain separate and unchanged. Initial runtime attribute stores are described above; call frames, accessors, overloads, polymorphic execution, schema 5 execution, editor authoring and Apply Constructor remain pending under the [Flujo Object Model contract](flow_object_model_contract.md).

- Constructor/Methods vertical delivery on `feature/constructor-methods`: `CMRUN-001`–`CMRUN-006` in the [Constructor and Methods contract](constructor_methods_contract.md) reuse schema 3 unchanged. Inspector order is Constructor → Processes → Timers → State Machines → Methods → Variables; all configuration remains in Flujo. Constructor is unique/non-removable and executes once before Ready in controlled controller startup. Methods have independent names, Enabled and starter blocks; Ready/Timer Call Method blocks resolve stable target IDs and skip invalid targets without stopping later blocks. Existing output signals remain, with additional method/call context. Parameters, returns, recursion, nested calls and bindings remain deferred. Automated focal and general regression evidence is complete; visual validation remains pending.

- Delivery 7 is implemented: the editor-only Flow interaction coordinator specified by `TVAR-016` provides explicit `GODOT`, `FLOW`, and `GAME` states, an editor-configurable F4 default, and an equivalent dock button. In GODOT, F4 reuses a controller below the current hierarchy target or creates exactly one undoable `PVController` below the selected editable node/scene root, then selects it and enters FLOW. It uses weak focus references, suspends editing and controller creation during actual game execution, and does not change schemas, runtime execution, or variable-model data. Automated coverage is complete; the required manual visual review remains pending.
- Ready starter delivery on `feature/processes-ready-runtime`: schema 3 reuses the existing Processes and block model; only Ready, configurable Print, and fixed Everything Flows are implemented. Block names are persistent visible metadata and never runtime dispatch. Output is console text plus a structured runtime signal; there is no on-screen presentation or debugger transport. Schema 2 remains migration coverage only. See `READY-001`–`READY-009` in the [model contract](model_contract.md). Automated verification is complete; manual visual acceptance remains pending. No export or performance work belongs to this delivery.
- Process and Timer authoring delivery on `feature/processes-ready-runtime`: schema 3 keeps one polymorphic Processes collection and presents Timers as a filtered Inspector view. The Inspector orders Processes, Timers, State Machines, then Variables, and owns their Add actions and selection lists; the Flujo panel owns selected Process, Timer, and Variable configuration and structural actions. Each schema 3 collection uses its own `Flujo`, `Flujo 1`, … sequence. Ready and Timer blocks retain independent subtype/container visible-name sequences with compatible Print/Everything Flows defaults, ID-based rename actions, Enter/Escape, and F2 access with complete text selection; Print uses a subtly contrasting theme-derived multiline surface. Runtime dispatch remains based on subtype and ID. Timers remain visually neutral; process-type colors and Page Up/Page Down navigation are deferred. State Machine editing remains deferred. Enabled one-shot or repeating Timers use transient runtime `Timer` nodes and the same ordered Print/Everything Flows executor and output boundary as Ready. Schema 2 remains migration-only and schema 4 is not introduced. See `TIMER-001`–`TIMER-008` and `READY-009` in the [model contract](model_contract.md). Automated verification is complete; manual visual acceptance remains pending.

### Next delivery

For the block ecosystem, D4 is complete at D4-C. D4-D is not defined or
authorized; any future D4-D must be separately specified and approved. D5
remains future work and means the functional Builder, not only its planning
Skill. FPrint is the planned first dogfood block, with its specification still
unfrozen and no package created.
Android/touch acceptance remains outside D4-C and is still governed by the Fluo
Preview 1 hardening sequence: portrait/landscape, touch targets, scrolling,
double-tap activation, keyboard behavior, focus restoration, Page navigation and
drawer side placement. The legacy visible Flujo dock and obsolete POC entry
surface remain governed by their separate acceptance gate.

Constructor/Methods, Typed Variables, schema 4/5 and runtime work remain governed by their existing contracts; Fluo preview hardening must not silently expand those scopes. The friendly user guide remains a separately approved follow-up.

Update this file after each approved Iteration 7 delivery so it remains a brief, factual handoff.

Todo es Flujo; todo fluye. 🌊
