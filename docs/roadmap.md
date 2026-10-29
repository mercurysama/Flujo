# Flujo Roadmap

## Project vision

Flujo is a visual programming plugin for Godot that keeps persistent program definitions portable, deterministic, and separate from editor tools and per-instance runtime state. Its long-term goal is to make readable visual game logic practical without making shared `FlowGraph` definitions mutable during execution.

## Completed milestones

- **Iteration 1 — Plugin Foundation:** established the Godot plugin, `PVController`, and scene-aware dock foundation.
- **Iteration 5 — Typed Inspector Containers:** delivered schema 2 typed collections, deterministic validation, atomic schema 1→2 migration, Inspector presentation and editing with undo/redo, dock visibility rules, and PackedScene persistence regression coverage. See the [Iteration 5 postmortem](iteration_05.md).
- **Iteration 6 — Constructor and Reusable Methods:** delivered the schema 3 structural foundation, atomic schema 2→3 migration, constructor dependencies, reusable methods, typed parameters, optional typed return declarations, persistent method-call references, deterministic validation, deep duplication, persistence coverage, and schema 2 Inspector stabilization. See the [Iteration 6 postmortem](iteration_06.md).
- **Fluo Preview 1 — Contextual authoring drawer:** validated the experimental Inspector → Fluo path with Flow block navigation, Flusso configuration, immediate edits, Revertir, focus restoration, Page navigation synchronized with the Inspector, explicit close controls, and Android render/load confirmation. The exact code checkpoint is `cd7e969c38193d718c948262107d1f7a45ca8083`; the legacy dock remains temporarily visible until preview acceptance.

## Active planning

**Fluo Preview 1 hardening** is the current UI focus on `feature/fluo-drawer-poc`. The preview is functionally usable and has been manually exercised on desktop; Android has confirmed project load and drawer rendering. Before the first stable release, complete the Android interaction matrix, hide/remove the temporary legacy visible dock and obsolete POC entry surface after acceptance, tune panel proportions from device evidence, and complete Themes + Motion validation using Godot 4.7 offset transforms without breaking Containers, focus, hitboxes, or mouse filtering.

The block ecosystem has reached the D4-C Major Increment Checkpoint on this
branch. The canonical ecosystem contract defines D0 through D4-A/B/C and then D5;
the `D4-D` label found in older handoffs has no separate technical scope or
acceptance gate. It is recorded as a deferred placeholder, not an implementation
task. D5 remains future work: its functional completion requires the
planning-gated Builder to generate and validate an ordinary package through the
public SDK. The planned first dogfood block is `FPrint`, distinct from legacy
`Print`, with an intentionally unfrozen specification.

**Iteration 7 — Typed Variables** is in contract planning. Its [Typed Variables contract](typed_variables_contract.md) preserves the existing seven-type variable taxonomy, defines compatibility-preserving validation and persistence/duplication coverage, and plans schema 3 variable Inspector authoring with keyboard accessibility. It does not introduce a runtime executor or schema 4.

The remaining planned work is:

1. Fluo Preview hardening: Android portrait/landscape, touch targets, scroll, double-tap, keyboard navigation, focus recovery, and panel proportions.
2. Remove or hide the temporary legacy visible Flujo dock and obsolete POC entry points only after the Inspector → Fluo path is accepted.
3. Themes + Motion before the first stable release, including careful Godot 4.7 offset-transform validation against Containers, focus and hitboxes.
4. Iteration 7 follow-ups: typed-variable validation/persistence maintenance, schema 3 variable authoring refinements, keyboard review, English public text, and the deferred user guide.
5. Argument bindings, value sources, return blocks and value transport, conversions, and call-cycle validation.
6. Schema 3 Constructor and Method authoring expansion with undo/redo.
7. Per-`PVController` runtime state design.

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
