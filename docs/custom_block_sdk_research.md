# Custom Block SDK and Block Builder Skill Research

Updated: 2026-10-27  
Scope: research and documentation only; no functional block-SDK code changed by this document.

## Executive conclusion

Flujo already has enough architectural foundation to design a first-party `flujo-block-builder` Skill without inventing a parallel block system.

The Skill must be an accelerator over the public/code-level block contract. It must never become a technical dependency: a developer must be able to create the same block manually in GDScript by following the documented SDK contract.

The current implementation is **not yet a complete end-to-end external authoring path**. External packages can be represented, discovered, validated, combined into an authoring catalog, and instantiated programmatically, and external block subclasses can participate in generic validation, duplication/remapping, persistence and runtime navigation. However, the normal Flow/Fluo Add path still calls the built-in `FlowBlockRegistry`, and Flusso still renders only a small set of block-specific configuration controls. This gap must be known by the Skill and by any first dogfooding block.

## Canonical terminology

Use these terms:

- **Custom block / bloque personalizado**: a `FlowBlock` subclass created by a user or by Flujo development.
- **External block / bloque externo**: a custom block whose script lives in a project package under `res://flow_packages/<package_id>/`.
- **Built-in / integrated block**: a block shipped inside `addons/vp_flujo/` and currently created by `FlowBlockRegistry`.
- **BLOCK SDK**: the common block contract and supporting infrastructure used by both official and user-created blocks.
- **Package**: project-owned external content under `res://flow_packages/<package_id>/`.
- **Incubator model**: develop a candidate block externally first; promotion to an official Flujo library should not require rewriting its implementation.

No prior project evidence establishes “Aura”, “Flow Aura”, “Flujo Aura”, or “flujos aura” as a technical term. Treat those words as non-canonical unless the maintainer explicitly introduces them later.

## Historical decisions recovered from prior work

### Long-term ecosystem decision

The project established early that:

- users must be able to create blocks without modifying the Flujo core;
- official and user-created blocks should converge on the same underlying contract;
- third-party/user content must live outside `addons/vp_flujo/`;
- packages belong under `res://flow_packages/<package_id>/`;
- runtime code must not depend on editor-only APIs;
- block identity uses stable IDs, never display names or array indexes;
- package/block tooling may assist creation, but must not become required to author code manually;
- a validated external block may later be promoted into an official library without rewriting its behavior.

The older planning board expressed this as:

- `FLU-BLK-001`: public custom-block contract;
- `FLU-BLK-002`: discovery/loading from an external folder;
- `FLU-BLK-003`: create one real external block using the same SDK;
- `FLU-BLK-004`: define promotion from incubator to official Flujo library.

### First integrated custom-block proof

The first narrow proof used `FlowCustomHelloBlock` and `FlowOutputBlock`.

Relevant commit history:

- `eb47f8a0d6a0f7605b867125aa248ca98d98cf55` — `feat: add first registry-backed custom block`.
- `f0fb6abbb35015ec812d9456e3a5f2880d04599e` — `feat: add generic block navigation`.

This proved that a new concrete `FlowBlock` subtype can:

- have a distinct script type;
- receive a stable internal ID;
- persist in `Array[FlowBlock]`;
- survive ResourceSaver/PackedScene persistence;
- duplicate with a new ID;
- execute through generic runtime boundaries without a block-specific executor branch.

It deliberately did **not** establish the external package SDK.

### External package SDK foundation

The next sequence converted the research proposal into generic infrastructure:

- `e9e2334d9538e9823d40f7d4fed52c1c1ed4c152` — external manifest data.
- `85c3e9092dc75139fc1853b04a77bdb3f4019821` — read-only manifest loader.
- `f3f44b7ea2b7cbf64bae6569e7b960fa3d9fc5f4` — external block script validation.
- `bd3a5d9701171125c35c1333f3d3c66ca9bdba86` — combined editor block catalog.
- `d95dbe33958d63868e0eacd8aa79e9f9521f1d5d` — external block factory.
- `36df48c4b7885c0cd8023185e145a6d053d61bf5` — generic external block validation/remap hooks.
- `0b8a0732f029f0e0c074b36515a76c1cc1af3495` — stronger proof that the base hooks remain no-op.

These commits are ancestors of the current Flujo work even though the historical feature branch is no longer available remotely.

## Current implemented SDK surface

### 1. Base block contract

`FlowBlock` is a persistent `Resource` with:

- hidden stable `_internal_id`;
- `display_name`;
- `enabled`;
- `user_note`;
- `validate_structure(context)` extension hook;
- `remap_internal_references(id_map)` extension hook;
- `get_navigation_decision(context)`, defaulting to CONTINUE;
- `duplicate_with_new_id()`.

The base validation/remap hooks are intentional no-ops.

### 2. Generic runtime navigation

`FlowNavigationDecision` supports:

- `CONTINUE`;
- `JUMP` to a stable block ID;
- `STOP`.

`FlowNavigationContext` supplies ephemeral execution context including the current container and block ID.

`FlowReadyExecutor` owns cursor movement and target resolution. A custom control block should return a navigation decision; it should not manipulate the executor cursor directly.

The runtime navigation regression proves stable-ID jump, stop, invalid target handling, duplicate-ID rejection and a 1024-step loop budget.

### 3. Manifest v1

The implemented external manifest is JSON:

`res://flow_packages/<package_id>/manifest.json`

Current v1 fields:

```json
{
  "manifest_version": 1,
  "package_id": "example_package",
  "blocks": [
    {
      "type_id": "example",
      "script": "blocks/example_block.gd",
      "display_name": "Example"
    }
  ]
}
```

The manifest contract intentionally remains minimal. It does not yet model marketplace metadata, dependencies, permissions, per-block versions, hot reload, signatures or runtime configuration.

### 4. Namespaced authoring identity

External authoring IDs use:

`package_id:type_id`

This is authoring/catalog identity only. It is not the persistent instance ID of a block. Every created block still receives its own `FlowId`.

### 5. Manifest discovery

`FlowPackageManifestLoader`:

- scans `res://flow_packages`;
- processes package directories in sorted order;
- requires `manifest.json`;
- parses JSON with `FileAccess` + `JSON`;
- requires manifest version 1;
- requires the manifest `package_id` to match the directory;
- preserves manifest block order;
- rejects duplicate `type_id`;
- rejects escaping/absolute script paths;
- emits structured deterministic diagnostics;
- allows valid packages to survive invalid siblings.

It discovers metadata only. It does not instantiate external blocks.

### 6. Script validation

`FlowExternalBlockScriptValidator`:

- confirms the script file exists;
- loads the resource without relying on a retained cache instance;
- requires the resource to be a `Script`;
- requires `can_instantiate()`;
- walks `get_base_script()` until the canonical `FlowBlock` script is found;
- accepts valid descriptors in authored order;
- diagnoses invalid siblings without stopping later descriptors;
- does not instantiate or register the block.

### 7. Combined authoring catalog

`FlowEditorBlockCatalog` combines:

1. built-in `FlowBlockRegistry` entries first, in stable order;
2. validated external descriptors afterward, by package/discovery order.

External catalog entries retain:

- `authoring_id = package_id:type_id`;
- display name;
- descriptor;
- origin = EXTERNAL.

The built-in registry remains intentionally ignorant of external packages.

### 8. External factory

`FlowExternalBlockFactory`:

- accepts only an external catalog entry;
- revalidates its descriptor/script at creation time;
- loads the script;
- calls `Script.new()`;
- requires the result to be a `FlowBlock`;
- requires a valid stable ID;
- initializes the visible block name from the descriptor;
- returns structured diagnostics instead of a fallback;
- creates independent instances with independent IDs.

The factory does not persist, execute, register or retain created instances.

### 9. Generic structural validation hook

`FlowGraphValidator` invokes `block.validate_structure({...})` after normal resource identity validation.

This allows a custom block to contribute block-local diagnostics without adding its concrete type to the core validator.

The current context includes at least:

- validation result;
- element path.

A future block must not mutate the graph during validation.

### 10. Generic duplication/remapping hook

Graph duplication:

1. creates all copied resources and builds the old-ID → new-ID map;
2. runs `remap_internal_references(id_map)` on copied blocks after the map is complete.

This supports arbitrary stable-ID references owned by custom block subclasses without adding those types to `FlowGraph`.

Unknown/unmapped references may be preserved literally so validation can diagnose them.

### 11. Persistence model

No new schema is required merely to add a custom `FlowBlock` subtype because supported graph schemas already store polymorphic `Array[FlowBlock]` resources.

Persisted block data should use Godot serializable properties. In current Flujo conventions:

- `@export` = persisted and editor-visible by Godot;
- `@export_storage` = persisted but hidden from the Inspector, appropriate for internal stable references/IDs.

A saved external block depends on its script resource remaining available in the project.

## Official Godot 4.7 confirmation

The existing SDK design matches Godot 4.7 fundamentals:

- `Resource` is the base for serializable data objects and can be nested/saved.
- exported GDScript properties are saved with their resource; `@export_storage` saves without exposing the field in the Inspector.
- `Script.new()` creates a script instance.
- `Script.can_instantiate()` and `Script.get_base_script()` provide the exact checks used by Flujo's external script validator.
- `ResourceLoader` is the correct project-resource loader, and `CACHE_MODE_IGNORE_DEEP` bypasses cached resource trees during validation.
- Godot warns that `DirAccess` over `res://` can behave differently in exported projects; this reinforces Flujo's existing decision that package discovery belongs to authoring/editor tooling, not the exported runtime.
- Godot editor plugins themselves conventionally live under `addons/`; Flujo deliberately keeps user block packages outside its own addon so plugin updates do not own or overwrite user content.

## Current automated evidence

The repository currently contains focal tests for:

- external manifest descriptor validation;
- manifest discovery and deterministic diagnostics;
- script inheritance/instantiability validation;
- combined catalog ordering and isolation;
- external factory creation and controlled rejection;
- generic validation/remap hooks;
- runtime navigation;
- first integrated custom block persistence/runtime.

The behavior catalog records passing evidence for the external-manifest, loader, script validator, catalog, factory and hook foundations.

Do not convert those historical passing statuses into a claim that a fresh run was executed for a new block.

## Designed but not implemented

### External IF block

The prior research designed, but did not implement, an external IF block roughly equivalent to:

```gdscript
class_name FlowIfBlock
extends FlowBlock

@export var condition: bool = false
@export_storage var true_target_block_id: String = ""
@export_storage var false_target_block_id: String = ""
```

Intended behavior:

- TRUE returns JUMP to `true_target_block_id`;
- FALSE returns JUMP to `false_target_block_id`;
- targets belong to the same `FlowBlockContainer`;
- the block does not own executor cursor movement;
- the block does not know other concrete block types;
- duplication remaps both target IDs through the generic hook;
- validation checks its own structural references through the generic hook.

The old unresolved question about empty targets has effectively narrowed because current `FlowNavigationDecision.jump_to("")` is malformed. A custom IF still needs an explicit product decision: empty target should produce a deterministic diagnostic/STOP-like outcome or another explicitly documented behavior. It must never silently infer a target by name/index.

### IF editor

The prior design proposed:

- Condition = CheckBox;
- True target / False target = ID-backed option lists;
- names only for presentation;
- Undo/Redo for structural/editor mutations;
- no IF-specific Godot Inspector controls.

This editor was not implemented.

## Important gaps before a fully useful external Block Builder

### Gap A — normal Flow/Fluo Add path does not use the external catalog

Current `FlowReadyProcessEditor` still builds Add buttons with:

`FlowBlockRegistry.creatable_type_ids()`

and `FlowGraphEditorCommands.add_ready_block()` still calls:

`FlowBlockRegistry.create(type_id)`

Therefore external blocks are not yet selectable through the normal Flow/Fluo authoring UI even though the external catalog/factory exist.

This is the most important missing bridge.

### Gap B — Flusso has no generic external-property renderer

Current Flusso rendering has special handling for known types such as:

- `FlowPrintBlock`;
- `FlowMethodCallBlock`.

A new external block with exported configuration fields does not automatically receive a purpose-built Flusso editor.

The future SDK/Skill therefore needs one of these explicit strategies:

1. a generic metadata/property UI contract for common field types; or
2. a declared editor-extension contract for custom block configuration; or
3. a deliberately limited first Skill that only produces zero-config/simple blocks until the editor contract exists.

Do not hide this limitation inside the Skill.

### Gap C — no real project-owned external package fixture exists

The repository has test fixtures under `tests/fixtures/external_manifests/`, but no real package under `flow_packages/`.

The first dogfooding block should create a real package through the same public contract intended for users.

### Gap D — missing package-at-load UX

Godot persistence keeps the concrete script resource. If a saved scene references an external block whose package is removed, loading can fail at the resource layer. Flujo still needs a deliberate user-facing diagnostic/recovery policy for missing installed packages; do not silently replace the block.

### Gap E — promotion policy is not implemented

The project wants the external folder to act as an incubator and later promote proven blocks into an official Flujo library without rewriting implementation. The exact promotion packaging/API remains a follow-up.

## What the future `flujo-block-builder` Skill must do

The Skill should encode the existing SDK instead of inventing a second API.

### Required preflight

For every requested block, determine:

- package ID;
- block type ID;
- display name;
- base class (`FlowBlock` or an approved specialization such as `FlowOutputBlock`);
- persistent fields and which are user-visible vs storage-only;
- runtime behavior;
- navigation behavior;
- stable-ID references owned by the block;
- structural validation rules;
- duplication/remapping rules;
- whether existing Flow/Fluo can author and configure it;
- required tests;
- minimum compatible Flujo/Godot version.

### Classification gate

Before generating code, classify the request:

- **SDK-supported now**: can be implemented entirely through existing hooks/contracts.
- **SDK-supported but authoring-limited**: runtime/model are supported, but normal Flow/Fluo creation or configuration needs the known editor bridge.
- **SDK extension required**: the block requires a new generic capability. Stop treating it as a simple block task and propose the smallest SDK extension first.
- **Core-only capability**: belongs in Flujo core rather than a package because it changes shared execution/model semantics.

### Generated package shape

Default target:

`res://flow_packages/<package_id>/`

with at least:

- `manifest.json`;
- one or more block scripts;
- package-level README/license/compatibility metadata when the package is meant for distribution;
- focused tests/fixtures appropriate to the block behavior.

The current v1 loader only consumes the minimal manifest fields documented above. Extra package documentation must not be confused with manifest v1 fields.

### Coding rules

The Skill must enforce:

- static typing;
- stable IDs inherited from `FlowBlock`;
- no persistent identity based on display name/index;
- editor APIs never imported into runtime block scripts;
- external package code never written inside `addons/vp_flujo/`;
- exported/storage properties chosen deliberately;
- navigation returned through `FlowNavigationDecision`;
- block-local structural checks through `validate_structure`;
- stable-ID remapping through `remap_internal_references`;
- no concrete block branch added to `FlowReadyExecutor` when a generic hook already exists;
- no external-package branch added to `FlowBlockRegistry`;
- package path traversal prohibited;
- deterministic diagnostics and order.

### Verification rules

The Skill must integrate with existing Flujo governance:

1. read `AGENTS.md`, current iteration, model contract, this document and behavior catalog;
2. run/record the appropriate baseline before changing existing behavior;
3. implement the smallest block/package scope;
4. add focused tests without weakening existing expectations;
5. run affected focal tests and proportional regressions;
6. use `$flujo-prove` before commit/publication;
7. keep visual/manual evidence separate from automated evidence;
8. never claim external authoring UI support that the current bridge does not provide.

### No exclusive capability

The Skill must never be the only way to create a block.

Its output should be ordinary project files using the same public contract that a human can author manually. Removing the Skill must not make existing custom blocks unloadable or unmaintainable.

## First dogfooding recommendation

The historical plan used IF because it exercises navigation, stable references, validation and remapping. It remains an excellent **SDK stress test**, but it is not the simplest first block for validating the Skill itself.

A staged dogfood can distinguish:

1. **builder smoke block** — simple external `FlowOutputBlock` with no custom editor fields, proving package generation/manifest/script/tests;
2. **IF/control block** — exercises navigation, two stable references, validation/remapping and editor requirements.

However, normal Flow/Fluo creation still requires Gap A to be bridged for either block to be added through the user-facing editor. A zero-config block only reduces the separate Flusso configuration problem.

## Research status

### Implemented

- custom-block polymorphism;
- built-in custom proof;
- generic runtime navigation;
- manifest v1 data contract;
- read-only manifest discovery;
- script validation;
- namespaced external authoring IDs;
- combined editor catalog;
- external factory;
- generic block validation hook;
- generic stable-ID remapping hook;
- persistence-compatible polymorphic block model;
- automated focal coverage for those foundations.

### Designed, not implemented

- real external IF block;
- IF editor controls;
- real project-owned dogfood package;
- normal Flow/Fluo external Add integration;
- generic Flusso property/editor extension contract;
- package-missing recovery UX;
- promotion workflow from incubator to official library;
- final `flujo-block-builder` Skill.

## Next step after this research

Do **not** start by inventing another block API.

The next design task is to write the first-party `flujo-block-builder` Skill against this documented contract, with an explicit capability-detection gate for the current authoring gaps. Its first practical mission should also serve as dogfooding evidence for the external SDK.

Todo es Flujo; todo fluye. 🌊
