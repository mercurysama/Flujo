# Current Iteration

## Iteration 6 — Constructor and Reusable Methods

- **Branch:** `feature/iteracion-06-constructor-metodos`.
- **Last integrated commit:** `331ca8958879173ba151c076755e92fb68b74e04` — `refactor: make Flow constructor a block container`.
- **Primary environment:** Fedora with Godot 4.7.2. Windows remains a supported compatible platform; no Windows-specific workflow is required.

### Implemented

- Schema 3 persistent structure, deterministic validation, deep duplication, and PackedScene persistence coverage.
- Atomic schema 2 → 3 migration that preserves validated schema 2 data and creates an empty constructor and methods collection.
- `FlowConstructorDefinition` as a specialized `FlowBlockContainer`, including inherited blocks and ordered nullable dependencies.
- Reusable method definitions and typed parameter declarations as persistent structural data.

### Pending

- `FlowMethodCallBlock` references.
- Arguments, parameter-binding validation, recursion and call-cycle validation.
- Dependency bindings, runtime state, and runtime execution.
- Inspector and visual authoring workflow for constructor and methods.

### Outside this step

This iteration has not introduced an executor, scene bindings, method-call execution, runtime mutation, or editor interface for schema 3 declarations.

### Next step

Specify and implement the persistent `FlowMethodCallBlock` reference foundation before arguments, cycles, runtime behavior, or editor authoring.

Update this file after each integrated commit so it remains a brief, factual handoff.

Everything is Flow; everything flows. 🌊
