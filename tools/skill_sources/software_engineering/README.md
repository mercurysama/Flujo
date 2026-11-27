# Software engineering skill sources

Vendored upstream reference material for future Flujo-specific engineering skills. These snapshots are intentionally stored under `tools/skill_sources/software_engineering/` and are not active Flujo skills yet.

## Godot plugin development

- Upstream: https://github.com/jame581/GodotPrompter
- Pinned commit: `426e8ab597473d1c71a11a04f6f0f2e1182a8e39`
- Imported: `skills/addon-development` with all of its local references
- License: MIT (upstream license preserved)
- Intended role: Godot EditorPlugin, @tool, custom inspectors, docks, gizmos, and plugin lifecycle guidance.

## Architecture / software engineering

- Upstream: https://github.com/owainlewis/blueprint
- Pinned commit: `ebbc20587dd4942450fa26cbf02de375781cbd1f`
- Imported separately in this branch: `architecture` and `architecture-review`
- License: MIT.

## Godot programming patterns

- Upstream: https://github.com/pbzona/godot-skills
- Pinned commit: `0ad8f3c58d54580a57a1a6de3cd345a1d9376e3d`
- Imported separately in this branch: `godot-programming-patterns`
- License: MIT.

## Object-oriented programming

The originally considered `bsene/skills/object-oriented-programming` source was not copied because the upstream repository does not publish a repository license. Instead, this branch vendors a small OOP cluster from `Sriramkk123/skills`; each selected SKILL.md explicitly declares `license: MIT` in its frontmatter.

- Pinned commit: `1449da8204bb5c5c705c04fe14eb13987f2a8538`
- Selected: `oop-pillars`, `solid`, `composition-principles`, `coupling-cohesion`, `object-calisthenics`, and `tell-dont-ask`.

## Integration note

Do not edit these source snapshots in place. They are references for future Flujo adapters such as a Godot/plugin engineering skill and an architecture/OOP layer. Any active Flujo skill should wrap these sources with `AGENTS.md`, `$flujo-baseline`, `$flujo-prove`, stable IDs, serialization rules, editor/runtime separation, and existing Fluo/Block SDK constraints.
