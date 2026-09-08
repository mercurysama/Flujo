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
- Next, cover persistence and duplication for every canonical type.
- Add schema 3 variable Inspector editing with scene-context undo/redo and basic keyboard accessibility.
- Translate remaining public Spanish text and comments, retain a friendly English pre-alpha warning, and add a separate user guide after the interface is implemented.

### Deliberately pending

- Implementation of the remaining `ARGRET` contract: argument bindings, value-source validation, return blocks, and incomplete-return-path validation.
- Recursion and call-cycle validation.
- Dependency bindings, runtime state, and runtime execution.
- Inspector and visual authoring workflow for constructor and methods.
- Enumerators, nullable values, persistent object references, and value-source resources; these require an approved schema 4 contract and migration.

### Not implemented by Iteration 6

This iteration has not introduced argument bindings, return blocks or runtime return values, value-source connections, cycle detection, an executor, scene bindings, method-call execution, runtime mutation, or editor interface for schema 3 declarations.

### Next delivery

Begin Delivery 3 of the [Typed Variables contract](typed_variables_contract.md): extend persistence and duplication evidence for every canonical type, default, ID reference, order, and `null` position. The Constructor and Methods contract continues to govern deferred argument bindings, return blocks, value sources, cycle validation, runtime state, execution, and schema 3 Constructor or Method authoring.

Update this file after each approved Iteration 7 delivery so it remains a brief, factual handoff.

Todo es Flujo; todo fluye. 🌊
