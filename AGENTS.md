# Flujo project authority

- Flujo is a visual programming plugin for Godot 4.7.2 stable, licensed MIT.
- Public UI text is English; localization of user-facing tooltips is separate.
- This file is a stable authority and index. Do not store HEAD, branch, commits,
  current iteration state, temporary plans, or other volatile state here.

## Essential architecture

- Runtime code belongs under `addons/vp_flujo/runtime/` and never depends on
  editor-only APIs.
- Editor code belongs under `addons/vp_flujo/editor/`; editor-executed scripts
  use `@tool`.
- User-created packages stay outside the plugin at
  `res://flow_packages/<package_id>/`.
- Coordinator owns operational orchestration. SQLite is the durable authority
  for TaskRun, lease, fencing, attempt, checkpoint, evidence, and state.
- The TUI is a facade over Coordinator/Gota boundaries, not a second task
  state machine. It must not mirror or bypass Coordinator or SQLite authority.

## Critical invariants

- Persistent model classes use the `Flow` prefix, static typing, and names that
  do not hide native Godot classes.
- Stable IDs come from `FlowId`; references use IDs, never display names or
  array indexes. Preserve order and deliberate null positions.
- Duplication creates independent new IDs and remaps related references through
  an old-ID to new-ID map without modifying the source.
- Preserve schema compatibility. A schema change requires an implemented,
  tested migration. Runtime/editor and portable-runtime boundaries remain
  separate.
- Implement only the authorized step and smallest coherent scope. Do not
  rename internal `VP`/`PV` paths or change F4, dock, runtime, schema, or
  Inspector behavior without explicit authorization.

## Authority, security, and Git safety

- The delivery path is native OpenCode Plan → explicit human approval →
  Build/Worker → read-only Reviewer/Auditor; the gate and handoff rules live
  in the canonical development workflow below.
- Human maintainers authorize scope and integration. No agent, TUI, or local
  report creates a parallel authority.
- Never read, copy, log, expose, or commit credentials. `.opencode/service.json`
  and equivalent credential paths are protected; redaction is required for
  durable output. Do not use external directories or add secrets, telemetry,
  or undisclosed network dependencies.
- Preserve unrelated user changes. Never use `reset`, `clean`, `checkout`,
  `switch`, `restore`, `rebase`, `merge`, commit amend, push, or ref mutation
  as recovery. Stop on a protected-path conflict, unsafe Git state, or missing
  authority; commits and integration require explicit authorization. Never
  commit machine-specific absolute paths; tool paths belong in user config.

## Canonical map

- Principles: [`docs/constitution.md`](docs/constitution.md).
- Governance and delivery: [`docs/development_workflow.md`](docs/development_workflow.md).
- Active human iteration handoff: [`docs/current_iteration.md`](docs/current_iteration.md).
- Persistent model contract: [`docs/model_contract.md`](docs/model_contract.md).
- Production Godot authority: [`docs/production_godot_contract.md`](docs/production_godot_contract.md).
- Gota TUI contract: [`docs/gota_tui_contract.md`](docs/gota_tui_contract.md).
- Behavior evidence catalog: [`docs/behavior_catalog.json`](docs/behavior_catalog.json).
- Verification gates: invoke `$flujo-baseline` before implementation and
  `$flujo-prove` before an authorized commit. These are verification gates,
  not alternate authority or permission to mutate the repository.

## Critical validation

- Before changing files, read the Constitution, active iteration handoff, and
  applicable contract; read the model contract before persistent-model work.
- Use the production resolver and exact-version rules in the canonical Godot
  contract; never substitute PATH or Flatpak for production authority.
- Run the applicable catalog validator, focal regressions, `git diff --check`,
  and required editor/model checks. Headless checks do not replace applicable
  visual review. Report warnings, project errors, baseline debt, modified
  files, and final Git status separately.
- Follow the complete canonical workflow, report externally reviewable evidence
  only, and stop after two equivalent failures of the same resource under the
  repository rules.
