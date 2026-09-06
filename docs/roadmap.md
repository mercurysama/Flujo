# Flujo Roadmap

## Project vision

Flujo is a visual programming plugin for Godot that keeps persistent program definitions portable, deterministic, and separate from editor tools and per-instance runtime state. Its long-term goal is to make readable visual game logic practical without making shared `FlowGraph` definitions mutable during execution.

## Completed milestones

- **Iteration 1 — Plugin Foundation:** established the Godot plugin, `PVController`, and scene-aware dock foundation.
- **Iteration 5 — Typed Inspector Containers:** delivered schema 2 typed collections, deterministic validation, atomic schema 1→2 migration, Inspector presentation and editing with undo/redo, dock visibility rules, and PackedScene persistence regression coverage. See the [Iteration 5 postmortem](iteration_05.md).

## Current milestone: Iteration 6 — Constructor and Reusable Methods

Iteration 6 has completed the schema 3 structural foundation: constructor and method definitions, typed parameters, deterministic validation, deep duplication, PackedScene persistence coverage, and atomic schema 2→3 migration. The current status is maintained in [Current Iteration](current_iteration.md). Remaining planned work is:

1. Method-call references and cycle validation.
2. Inspector editing with undo/redo.
3. Per-`PVController` runtime state design.

The [Constructor and Methods contract](constructor_methods_contract.md) distinguishes implemented schema 3 structure from deferred method calls, arguments, cycles, bindings, `FlowRuntimeState`, execution, and editor workflow.

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
