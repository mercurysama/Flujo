# Godot skill sources

Vendored upstream reference material for a future Flujo-specific Godot programming skill. These snapshots are intentionally stored under `tools/skill_sources/godot/` and are not active Flujo skills yet.

## ziva-sh/godot-skills
- Upstream: https://github.com/ziva-sh/godot-skills
- Pinned commit: `f3199da6413bc40bfb8733bd0189761c237c64cf`
- Scope: complete Godot skill set under `skills/`
- Target stated by upstream: Godot 4.7.2
- License: MIT (preserved)

## Skyrant/gamedev-agent-skills
- Upstream: https://github.com/Skyrant/gamedev-agent-skills
- Pinned commit: `7eb1b53305fab881f4758e2eff2e371cd7869221`
- Imported Godot subset:
  - `godot-gdscript`
  - `godot-nodes-scenes`
  - `godot-signals-groups`
  - `godot-resources`
- License: Apache-2.0 (preserved)

## Integration note
Do not edit these snapshots in place when creating the Flujo integration. Use them as source references for a future `flujo-godot` (name provisional), wrapped by Flujo's `AGENTS.md`, Godot 4.7.2 baseline/prove gates, stable IDs, serialization rules, editor/runtime separation, and existing UI/block-specific skills.
