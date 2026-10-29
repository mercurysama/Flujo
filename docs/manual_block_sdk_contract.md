# Manual Block SDK Profile Contract

## Status and scope

This contract defines D1 of the Flujo block ecosystem roadmap: the manual, reproducible package profile built on the already implemented external manifest/loader/validator/catalog/factory foundation.

D1 itself does not connect external packages to the normal Flow Add row, does not
implement generic Flusso configuration, does not create
`flujo-block-builder`, does not approve provenance or editor-presentation sidecar
formats, and does not change graph schemas or `manifest_version = 1`. Later D3
and D4 deliveries provide those separate bridges without changing the D1 manual
profile.

The purpose of D1 is to prove that a developer can author a supported external block entirely by hand using ordinary project files and the public Flujo contracts.

## D1 requirements

### BLKMAN-001 — Manual authoring is the reference path

The reference authoring path is manual creation of ordinary files under `res://flow_packages/<package_id>/`.

Automation may reproduce this path later, but D1 is valid without any builder, generator, network service or private metadata.

### BLKMAN-002 — Canonical distributable profile is one block per package

The D1 profile contains exactly one distributable block descriptor per package.

Historical manifest v1 files containing several descriptors remain readable for compatibility, but they are not the canonical authoring profile.

### BLKMAN-003 — Manifest v1 is reused without extension

The package contains `manifest.json` using the already implemented fields only:

- `manifest_version`;
- `package_id`;
- `blocks`;
- per block: `type_id`, `script`, `display_name`.

D1 does not add provenance, editor metadata, dependencies, permissions, versions, signatures or checksums to manifest v1.

### BLKMAN-004 — Package and script paths remain project-relative

The package lives outside `addons/vp_flujo/`.

The descriptor script path is relative to the package and must not escape through absolute paths, drive prefixes or `..` traversal.

No generated or handwritten D1 file depends on a machine-specific absolute path.

### BLKMAN-005 — Standard runtime script uses the public block contract

A D1 script:

- uses `@tool`;
- derives from an approved public block base such as `FlowBlock` or `FlowOutputBlock`;
- remains instantiable;
- uses portable Godot APIs;
- does not depend on editor-only APIs;
- does not require a global `class_name`;
- receives its persistent instance ID from inherited `FlowBlock` behavior.

### BLKMAN-006 — Authoring identity and persistent identity remain separate

The catalog identity is `package_id:type_id`.

Each created block instance receives its own stable `FlowId`. Creating the same catalog entry twice must produce independent instances with different persistent IDs.

Display names are never identity.

### BLKMAN-007 — Existing discovery, validation, catalog and factory are authoritative

D1 reuses:

- `FlowPackageManifestLoader`;
- `FlowExternalBlockScriptValidator`;
- `FlowEditorBlockCatalog`;
- `FlowExternalBlockFactory`.

D1 must not create a parallel loader, registry, factory or package format.

### BLKMAN-008 — Manual pipeline is deterministic

The manual proof follows this order:

`files → manifest discovery → script validation → editor catalog projection → external factory creation`

Repeated discovery and creation must preserve deterministic metadata ordering while creating independent block instances.

### BLKMAN-009 — D1 proves a simple class-A package

The D1 fixture is a simple output block derived from `FlowOutputBlock`.

It may expose one scalar/string property and deterministic output. It does not navigate, access scene nodes, depend on another package, own editor UI, or implement IF.

Class-B configurable authoring was limited until D4. D4 v1 now supports the
approved scalar property set through the generic descriptor/Flusso path; complex
or custom presentation remains outside this profile.

### BLKMAN-010 — Persistence preserves the external concrete script

A manually created external block must survive supported persistence without being converted to a built-in type.

D1 evidence covers:

- `ResourceSaver` round trip;
- `PackedScene` round trip through a `PVController`/`FlowGraph`;
- persistent block ID preservation on save/load;
- exported field preservation;
- concrete external script preservation.

### BLKMAN-011 — Duplication preserves type and renews identity

Graph duplication must preserve the concrete external block script and its persistent values while assigning a new block ID according to the existing duplication contract.

D1 introduces no block-specific duplication branch.

### BLKMAN-012 — Sidecar formats remain unresolved

D1 does not create or approve `provenance.json` or `editor_schema.json`.

Their eventual serialized forms remain governed by later maintainer approval. Their absence must not prevent the D1 manual package from passing manifest discovery, script validation, catalog projection or factory creation.

### BLKMAN-013 — Test fixture is evidence, not an installed package

The D1 example lives under `tests/fixtures/manual_block_sdk/` and exists only as deterministic project evidence.

It must not be described as an installed user package or as proof that the normal Flow/Flusso authoring path is complete.

### BLKMAN-014 — D1 makes no Flow/Flusso end-to-end claim

Passing D1 proves the manual SDK/profile boundary only.

The normal Add row requires D3 and generic property configuration uses the D4 v1
descriptor boundary. A package that passes D1 is still only proof of the manual
SDK profile; it does not claim D3/D4 end-to-end authoring by itself.

### BLKMAN-015 — Future builder output must be semantically equivalent

When `flujo-block-builder v1` is implemented in D5, a generated class-A package must be semantically equivalent to the D1 manual profile.

The builder may automate file creation and validation, but it must not add a capability that the manual package cannot reproduce.

## Canonical D1 fixture shape

```text
tests/fixtures/manual_block_sdk/
  manual_output/
    manifest.json
    block.gd
```

Equivalent future installed packages use:

```text
res://flow_packages/<package_id>/
  manifest.json
  block.gd
```

No sidecar is required by D1.

## D1 acceptance evidence

D1 is accepted when:

1. the contract is versioned;
2. the fixture contains exactly one descriptor and one external block script;
3. manifest discovery returns the package deterministically;
4. script validation accepts the descriptor;
5. the combined catalog exposes `manual_output:output` as external;
6. factory creation returns independent instances with different valid IDs;
7. the external block is a `FlowOutputBlock` and preserves its exported message;
8. ResourceSaver reload preserves script, ID and message;
9. PackedScene reload preserves script, ID and message inside the graph;
10. graph duplication preserves script/message and creates a different block ID;
11. existing manifest/catalog/factory regressions remain passing;
12. no file under `addons/vp_flujo/` is modified by D1;
13. `demo/main.tscn` remains an unrelated pre-existing local change;
14. no commit is created without maintainer acceptance.

Everything is Flow; everything flows. 🌊
