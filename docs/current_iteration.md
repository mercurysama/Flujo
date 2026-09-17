# Current Iteration

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
- Dependency bindings, general runtime state, and execution beyond the scoped Ready starter blocks.
- Inspector and visual authoring workflow for constructor and methods.
- Enumerators, nullable values, persistent object references, and value-source resources; these require an approved schema 4 contract and migration.

### Not implemented by Iteration 6

This iteration has not introduced argument bindings, return blocks or runtime return values, value-source connections, cycle detection, an executor, scene bindings, method-call execution, runtime mutation, or editor interface for schema 3 declarations.

### Current delivery

- Delivery 7 is implemented: the editor-only Flow interaction coordinator specified by `TVAR-016` now provides explicit `GODOT`, `FLOW`, and `GAME` states, an editor-configurable F4 default, and an equivalent dock button. It uses only weak focus references and the exact selected `PVController`, suspends editing during actual game execution, and does not change persistent data, schemas, runtime execution, or the existing local variable-editor workflows. Automated coverage is complete; the required manual visual review remains pending.
- Ready starter delivery on `feature/processes-ready-runtime`: schema 3 reuses the existing Processes and block model; only Ready, configurable Print, and fixed Everything Flows are implemented. Output is console text plus a structured runtime signal; there is no on-screen presentation or debugger transport. Schema 2 remains migration coverage only. See `READY-001`–`READY-008` in the [model contract](model_contract.md). Automated verification is complete; manual visual acceptance remains pending. No export or performance work belongs to this delivery.

### Next delivery

Complete the manual Fedora review for Ready authoring and execution, then audit any resulting correction separately before publication through GitHub Desktop. The Constructor and Methods contract continues to govern deferred argument bindings, return blocks, value sources, cycle validation, method execution, and schema 3 Constructor or Method authoring. The friendly user guide requires separate approval.

Update this file after each approved Iteration 7 delivery so it remains a brief, factual handoff.

Todo es Flujo; todo fluye. 🌊
