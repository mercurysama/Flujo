# Project

- Flujo is a visual programming plugin for Godot.
- Target version: Godot 4.7.2 stable.
- License: MIT.
- Public UI text is written in English.
- User-facing tooltips will support localization separately.

# Architecture

- Runtime code belongs under `addons/vp_flujo/runtime/`.
- Runtime code must never depend on editor-only APIs.
- Editor code belongs under `addons/vp_flujo/editor/`.
- Scripts executed by the editor must use `@tool`.
- User-created packages must remain outside the plugin directory under `res://flow_packages/<package_id>/`.
- Read `docs/model_contract.md` before changing the persistent model.

# Model Rules

- Use static typing.
- Persistent model classes use the `Flow` prefix.
- Avoid names that hide native Godot classes.
- Stable internal IDs are generated through `FlowId`.
- Internal IDs are serialized with `@export_storage` and hidden from the Inspector.
- References use internal IDs, never display names or `Array` indexes.
- Preserve `Array` order and deliberate null positions.
- Duplication must create new IDs without modifying the original.
- Duplication of related objects must use an old-ID to new-ID map.
- Preserve `schema_version` compatibility.
- Do not change `schema_version` without an implemented and tested migration.

# Current Iteration

- The current branch is implementing typed Inspector containers.
- Processes, Variables, and State Machines will be edited in the Godot Inspector.
- The Flujo `EditorDock` is reserved for the future Scratch-style block editor.
- Do not place the container editor inside `EditorDock`.
- `FlowGraph` schema version remains 1.
- `FlowGraph.containers` remains the legacy collection for schema 1.
- Schema 2 integrates the typed `processes`, `variables`, and `state_machines` collections in `FlowGraph`; it must not use `containers` at the same time.
- `GLOBAL` variables currently mean global only inside one `FlowGraph`/`PVController`.
- Cross-graph global variables are not implemented.
- Persistent is currently model metadata; runtime save/load is not implemented.

# Scope Control

- Inspect existing code before editing.
- Implement only the explicitly requested step.
- Prefer the smallest coherent change.
- Do not refactor unrelated code.
- Do not rename existing internal `VP` or `PV` paths/classes unless explicitly requested.
- Do not modify F4 behavior, dock visibility, runtime execution, schema migration, or Inspector UI unless the task explicitly requests it.
- Do not perform commits, pushes, merges, rebases, or pull requests unless explicitly requested.

# Verification

- Run `git diff --check`.
- Run `godot --headless --editor --path . --quit-after 5`.
- Run `godot --headless --path . tests/model/flow_model_smoke_test.tscn`.
- The smoke test must print `[Flujo] Model smoke test passed`.
- Report warnings separately from project errors.
- Report every modified file and the final Git status.

# Fedora Flatpak Environment

- For Codex sessions running inside the VS Code Flatpak on Fedora 43, VS Code uses `com.visualstudio.code` and Godot uses `org.godotengine.Godot`.
- `flatpak` may not be available directly inside the sandbox. Use `/usr/bin/flatpak-spawn --host` to run Flatpak commands on the host.
- Godot version: `/usr/bin/flatpak-spawn --host flatpak run org.godotengine.Godot --version`
- Headless editor load: `/usr/bin/flatpak-spawn --host flatpak run org.godotengine.Godot --headless --editor --path . --quit-after 5`
- Model smoke test: `/usr/bin/flatpak-spawn --host flatpak run org.godotengine.Godot --headless --path . tests/model/flow_model_smoke_test.tscn`
- `WARNING: Scan thread aborted...` is acceptable only when the headless load exits with code 0 and the warning corresponds to the planned shutdown.

# Portability and Safety

- Runtime behavior must remain portable to Godot-supported export platforms.
- Do not introduce platform-specific runtime dependencies.
- Do not add secrets, credentials, telemetry, or external network dependencies.
