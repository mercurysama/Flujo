# Godot 4 skills for AI coding agents

AI assistants keep writing Godot 3 code into Godot 4 projects: `KinematicBody2D`, `yield`, `export var`, string `connect()` calls, the old `TileMap` API. This pack is six small [Agent Skills](https://agentskills.io/specification) about common Godot 4 mistakes AI assistants make, and how to check the result with the engine instead of trusting it. Every GDScript snippet in it is parse-checked on Godot 4.7.2 by `tests/check_snippets.py`, every deliberately wrong Godot 3 example is checked to fail, and the API claims were checked against the Godot 4.7.2 class reference and the official docs.

## Skills

- `godot-4-api-pitfalls`: Godot 3 to 4 renames and syntax changes (`CharacterBody2D`, `@export`, `await`, `instantiate()`, `FileAccess`, `create_tween()`...), plus the ones `--check-only` does not catch.
- `godot-tilemaplayer`: `TileMapLayer` (Godot 4.3+) cell API, custom data, terrains, tile collision, and migrating from `TileMap`.
- `godot-control-layout`: containers versus anchors, size flags, text that does not clip, `mouse_filter`, HUDs on a `CanvasLayer`, theme overrides and stretch settings.
- `godot-signals`: `Signal` and `Callable` syntax, `bind()`/`unbind()`, one-shot and deferred connections, `await`, editor-made connections.
- `godot-scene-organization`: scenes versus scripts versus Resources, finding nodes, groups, autoloads, `class_name`, and `.uid` files when moving files.
- `godot-verify`: parse-check scripts, run scenes headless and write exit-code tests from the command line, and read the output, because Godot exits with code 0 after runtime errors.

## Install

With the skills CLI (https://github.com/vercel-labs/skills, needs Node.js 22.20 or later), from your Godot project folder:

```bash
npx skills add ziva-sh/godot-skills                  # asks which skills and agents
npx skills add ziva-sh/godot-skills -a claude-code   # .claude/skills/
npx skills add ziva-sh/godot-skills -a universal     # .agents/skills/ (Cursor, Codex, Ziva and others)
```

Add `-g` to install for your user instead of the project, `--skill <name>` to pick skills and `-y` to skip the prompts.

By hand, copy the folders under `skills/` into the folder your agent reads:

| Agent | Project | User |
| --- | --- | --- |
| Claude Code | `.claude/skills/` | `~/.claude/skills/` |
| Cursor | `.agents/skills/` | `~/.cursor/skills/` or `~/.agents/skills/` |
| Codex | `.agents/skills/` | `~/.agents/skills/` |
| Ziva | `.ziva/skills/` or `.agents/skills/` | `~/.ziva/skills/` or `~/.agents/skills/` |

```bash
git clone https://github.com/ziva-sh/godot-skills /tmp/godot-skills
mkdir -p .agents/skills && cp -r /tmp/godot-skills/skills/* .agents/skills/
```

Agents load a skill when the task matches its description. In Ziva you can also load one with `/skill:<name>`, for example `/skill:godot-tilemaplayer`.

## How we test

```bash
python3 tests/check_snippets.py --godot /path/to/godot   # Python 3 standard library only
```

The script extracts every fenced code block labelled `gdscript` from every `SKILL.md` and reference file, writes each one as its own script in a temporary Godot project, and runs `godot --headless --path <project> --check-only --script res://<snippet>.gd`. A snippet fails on a non-zero exit code or any `ERROR` line. That project sets `unsafe_method_access` and `unsafe_property_access` to Error, so a Godot 3 member name on a typed object cannot slip through. Blocks labelled `gdscript-godot3` are the intentional Godot 3 examples: they run in a project with default settings and must fail to parse. An unlabelled fence also fails the run, so a snippet cannot be skipped by accident.

Current result on Godot 4.7.2: 20 `gdscript` snippets parse and 3 `gdscript-godot3` snippets fail as expected. Please run it before sending a change.

Loading: on 10 November 2026 all six skills loaded in Ziva with `/skill:<name>` from both `.agents/skills/` and `.ziva/skills/`; the session log showed each `SKILL.md` body sent to the model unchanged. In the one chat we ran without `/skill`, the model answered without opening the matching skill, so load a skill by name when you want it used for sure. On 11 November 2026, in Claude Code 2.1.318 after `npx skills add ziva-sh/godot-skills -a claude-code -y`, all six loaded unchanged with `/<skill-name>`, and in both chats we ran without a slash command Claude Code picked the matching skill by itself.

## License

The skills in this repository are MIT licensed, see [LICENSE](LICENSE). Made by Ziva (https://ziva.sh), an AI assistant inside the Godot editor; the Ziva plugin itself is proprietary.
