# Refactoring skill sources

Vendored, unmodified upstream reference material for a future Flujo-specific refactoring skill. These snapshots live under `tools/skill_sources/` and are not active Flujo skills.

## Blueprint
- Upstream: https://github.com/owainlewis/blueprint
- Pinned commit: `ebbc20587dd4942450fa26cbf02de375781cbd1f`
- Imported skill: `skills/improve`
- License: MIT (preserved)

The current upstream skill is named `improve`; this is the behavior-preserving simplification/refactoring skill selected for Flujo.

## refactoring-skills
- Upstream: https://github.com/mickeyyaya/refactoring-skills
- Pinned commit: `cd0c22762849bd846115a1e10f403759bd7e4f92`
- Imported: the core refactoring subset under `refactoring-skills/`
- License: MIT (preserved)

## Integration note
Do not edit these snapshots in place when creating the Flujo integration. Use them as references for `tools/agent_skills/flujo-refactor`, wrapped by Flujo's AGENTS.md, baseline/prove, stable-ID, schema, editor/runtime, and behavior-preservation constraints.
