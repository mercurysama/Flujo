# Flujo Roadmap

## Project vision

Flujo is a visual programming plugin for Godot that keeps persistent program definitions portable, deterministic, and separate from editor tools and per-instance runtime state. Its long-term goal is to make readable visual game logic practical without making shared `FlowGraph` definitions mutable during execution.

## Completed milestones

- **Iteration 1 — Plugin Foundation:** established the Godot plugin, `PVController`, and scene-aware dock foundation.
- **Iteration 5 — Typed Inspector Containers:** delivered schema 2 typed collections, deterministic validation, atomic schema 1→2 migration, Inspector presentation and editing with undo/redo, dock visibility rules, and PackedScene persistence regression coverage. See the [Iteration 5 postmortem](iteration_05.md).
- **Iteration 6 — Constructor and Reusable Methods:** delivered the schema 3 structural foundation, atomic schema 2→3 migration, constructor dependencies, reusable methods, typed parameters, optional typed return declarations, persistent method-call references, deterministic validation, deep duplication, persistence coverage, and schema 2 Inspector stabilization. See the [Iteration 6 postmortem](iteration_06.md).

## Active planning

**Iteration 7 — Typed Variables** is in contract planning. Its [Typed Variables contract](typed_variables_contract.md) preserves the existing seven-type variable taxonomy, defines compatibility-preserving validation and persistence/duplication coverage, and plans schema 3 variable Inspector authoring with keyboard accessibility. It does not introduce a runtime executor or schema 4.

The remaining planned work is:

1. Iteration 7 deliveries: typed-variable validation, persistence/duplication coverage, schema 3 variable Inspector editing, keyboard review, English public text, and a post-interface user guide.
2. Argument bindings, value sources, return blocks and value transport, conversions, and call-cycle validation.
3. Schema 3 Constructor and Method Inspector editing with undo/redo.
4. Per-`PVController` runtime state design.

The [Typed Variables contract](typed_variables_contract.md) distinguishes Iteration 7 work from future schema 4 requirements for enumerators, nullable typed values, persistent object references, and value-source resources. The [Constructor and Methods contract](constructor_methods_contract.md) distinguishes implemented schema 3 structure, method-call references, and optional return declarations from deferred argument bindings, value sources, return blocks, conversions, cycles, `FlowRuntimeState`, execution, and editor workflow.

## Future milestones

- Visual block authoring.
- Runtime executor.
- Debugging and observability.
- Templates and packages.
- Persistence and inherited-scene customization.
- Multiplatform validation.
- A **Bajo Teotihuacán** vertical slice as the beta acceptance project.

## Beta entry criteria

Before beta, Flujo should have a validated authoring flow for its supported definitions, a portable runtime executor, deterministic diagnostics, undoable editor changes, persistence coverage, an explicit shared-definition/per-instance-state boundary, and repeatable headless and manual validation on supported platforms. The Bajo Teotihuacán vertical slice should exercise those capabilities as an acceptance project.

## Planning note

This roadmap is not a commitment to fixed scope or ordering. Priorities, sequence, and scope may change after audits, validation results, and implementation discoveries.

Todo es Flujo; todo fluye. 🌊
