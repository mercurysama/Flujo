# Current Iteration

## Iteration 6 — Constructor and Reusable Methods

- **Branch:** `feature/iteracion-06-constructor-metodos`.
- **Primary environment:** Fedora with Godot 4.7.2. Windows remains a supported compatible platform; no Windows-specific workflow is required.

### Implemented

- Schema 3 persistent structure, deterministic validation, deep duplication, and PackedScene persistence coverage.
- Atomic schema 2 → 3 migration that preserves validated schema 2 data and creates an empty constructor and methods collection.
- `FlowConstructorDefinition` as a specialized `FlowBlockContainer`, including inherited blocks and ordered nullable dependencies.
- Reusable method definitions and typed parameter declarations as persistent structural data.
- Persistent `FlowMethodCallBlock` references from constructor, method, process, and state containers, with deterministic schema/reference validation and order-independent duplication remapping.
- Optional typed `FlowMethodReturnDefinition` declarations with global identity validation, deep duplication, and ResourceSaver/PackedScene persistence.

### Pending

- Implementation of the remaining `ARGRET` contract: argument bindings, value-source validation, return blocks, and incomplete-return-path validation.
- Recursion and call-cycle validation.
- Dependency bindings, runtime state, and runtime execution.
- Inspector and visual authoring workflow for constructor and methods.

### Outside this step

This iteration has not introduced argument bindings, return blocks or runtime return values, value-source connections, cycle detection, an executor, scene bindings, method-call execution, runtime mutation, or editor interface for schema 3 declarations.

### Next step

Implement argument bindings and return blocks without adding execution, recursion, runtime state, visual connections, or editor authoring.

Update this file after each integrated commit so it remains a brief, factual handoff.

Everything is Flow; everything flows. 🌊
