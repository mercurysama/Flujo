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
- At the start of every task, read `docs/constitution.md`, `docs/current_iteration.md`, and the applicable contract before changing files. Read `docs/model_contract.md` before changing the persistent model.

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

# Task context

- `docs/current_iteration.md` and the applicable contract are the mandatory sources for the current branch, supported schemas, implemented scope, deferred work, and next task.
- Do not duplicate dynamic iteration state in this file.

# Scope Control

- Every change begins by updating or confirming the applicable numbered specification. Follow the complete governance sequence in [`docs/development_workflow.md`](docs/development_workflow.md).
- Inspect existing code before editing.
- Implement only the explicitly requested step.
- Prefer the smallest coherent change.
- Do not refactor unrelated code.
- Do not rename existing internal `VP` or `PV` paths/classes unless explicitly requested.
- Do not modify F4 behavior, dock visibility, runtime execution, schema migration, or Inspector UI unless the task explicitly requests it.
- Do not perform commits, pushes, merges, rebases, or pull requests unless explicitly requested.

## Required technical justification and traceability

- Every delivery records a verifiable justification: what changed, why it was chosen, relevant alternatives rejected, protected invariants, risks, limitations, and test or review evidence.
- Maintain an explicit trace from requirement to task, code, test, and commit. Link or name each artifact precisely enough to audit it.
- Record only externally reviewable decisions and evidence. Do not request, infer, or store an agent's private internal reasoning.

# Verification

- Run `git diff --check`.
- Run the selected Godot command with `--headless --editor --path . --quit-after 5`.
- Run the selected Godot command with `--headless --path . tests/model/flow_model_smoke_test.tscn`.
- The smoke test must print `[Flujo] Model smoke test passed`.
- Report warnings separately from project errors.
- Report every modified file and the final Git status.

# Visual Review

- Any change that alters the Inspector, dock, controls, visible ordering, focus, shortcuts, or editor interaction requires a manual check in Godot.
- When applicable, the review includes the empty state, the result after an action, undo/redo, keyboard navigation, save/reopen, and selection changes.
- Headless tests do not replace visual review.
- An internal class does not require visual review unless it produces or changes a visible representation.

# Fedora Flatpak Environment

- On Fedora, select the Godot executor in this order. Confirm every selected executor reports Godot 4.7.2 before using it.
  1. Use native `godot` when it is available in `PATH` and `godot --version` reports 4.7.2.
  2. If Codex runs inside the VS Code Flatpak, use `flatpak-spawn --host flatpak run org.godotengine.Godot` when native Godot is unavailable or is not 4.7.2. VS Code uses `com.visualstudio.code` and Godot uses `org.godotengine.Godot`.
  3. If Flatpak is available directly, use `flatpak run org.godotengine.Godot` when neither prior executor works.
  4. If none of these executors works with Godot 4.7.2, stop and report the failure. Do not invent paths or reuse Windows paths.
- Native Godot version: `godot --version`
- Native headless editor load: `godot --headless --editor --path . --quit-after 5`
- Native model smoke test: `godot --headless --path . tests/model/flow_model_smoke_test.tscn`
- Host Flatpak version: `flatpak-spawn --host flatpak run org.godotengine.Godot --version`
- Host Flatpak headless editor load: `flatpak-spawn --host flatpak run org.godotengine.Godot --headless --editor --path . --quit-after 5`
- Host Flatpak model smoke test: `flatpak-spawn --host flatpak run org.godotengine.Godot --headless --path . tests/model/flow_model_smoke_test.tscn`
- Direct Flatpak version: `flatpak run org.godotengine.Godot --version`
- Direct Flatpak headless editor load: `flatpak run org.godotengine.Godot --headless --editor --path . --quit-after 5`
- Direct Flatpak model smoke test: `flatpak run org.godotengine.Godot --headless --path . tests/model/flow_model_smoke_test.tscn`
- `WARNING: Scan thread aborted...` is acceptable only when the headless load exits with code 0 and the warning corresponds to the planned shutdown.

# Portability and Safety

- Runtime behavior must remain portable to Godot-supported export platforms.
- Do not introduce platform-specific runtime dependencies.
- Do not add secrets, credentials, telemetry, or external network dependencies.
- Never commit machine-specific absolute paths in shared configuration.
- Tool paths belong in user configuration.
- Report every emerging error, read/write failure, denied permission, or fallback recovery in the final report.
- If the same resource fails twice, stop and report it even if an alternative exists.
