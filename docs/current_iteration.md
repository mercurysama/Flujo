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
- **Automation evidence:** focal editor tests were extended for Fluo behaviors, but this handoff does not claim a fresh automated run after the final UI checkpoint.

Read [Project memory / handoff](project_memory.md) and [Fluo Preview 1](fluo_preview_01.md) before continuing this branch.

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

For `feature/fluo-drawer-poc`, complete the Android preview acceptance matrix: portrait/landscape, touch targets, scrolling, double-tap activation, keyboard behavior, focus restoration, Page navigation and drawer side placement. After that approval, hide/remove the temporary legacy visible Flujo dock and obsolete POC entry surface, then tune panel proportions from device evidence. Themes + Motion using Godot 4.7 offset transforms is required before the first stable release and must not desynchronize visual position from Containers, focus, hitboxes, or mouse filtering.

Constructor/Methods, Typed Variables, schema 4/5 and runtime work remain governed by their existing contracts; Fluo preview hardening must not silently expand those scopes. The friendly user guide remains a separately approved follow-up.

Update this file after each approved Iteration 7 delivery so it remains a brief, factual handoff.

Todo es Flujo; todo fluye. 🌊
