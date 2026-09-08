# Flujo Constitution

## Purpose

This Constitution defines the non-negotiable development principles for Flujo. Contracts and plans may refine these principles, but may not weaken them.

## Non-negotiable principles

- **Object-oriented design, POO / PO🌊:** use inheritance for true "is a" relationships and composition for ownership and coordination. Keep responsibilities small and explicit.
- **Deterministic model:** persistent definitions, validation, diagnostics, ordering, and migrations must produce reproducible results without silently repairing invalid data.
- **Stable identity:** persistent elements use generated internal IDs. Names, indexes, paths, and positions are presentation or location data, never identity.
- **Editor/runtime separation:** portable runtime code never depends on editor-only APIs. The editor may adapt runtime definitions but must not become their source of truth.
- **Portability:** runtime behavior uses Godot-supported portable APIs and must not depend on a developer machine, operating system path, external process, or editor environment.
- **Keyboard accessibility:** visible editor workflows must be operable and reviewable by keyboard, with predictable focus and shortcuts.
- **Security and privacy:** do not add secrets, credentials, telemetry, or undisclosed external dependencies. Preserve user data and make destructive operations explicit.
- **Compatibility:** preserve schemas deliberately. Change a schema only with an explicit, tested migration that keeps prior data intact on success and failure paths.
- **Tests and evidence:** protect invariants with deterministic validation and proportionate automated and manual tests. A passing test never substitutes for evidence it cannot provide.
- **Human authority:** maintainers decide scope, accept designs, and authorize integration. Automation assists that decision; it does not replace it.

## AI assistance and authorization

ChatGPT and Codex are the tools currently used to assist Flujo development. Flujo does not depend on either product, provider, model, or service at runtime or as a condition of future development.

AI proposes. Validators, tests, and authorized human review approve. Development records must describe observable decisions and evidence, not private internal reasoning from an agent or a person.

## Repository inception evidence

- **Repository inception:** 2026-08-26T03:12:39-06:00, the first reachable commit, `4b9a96871b5b2e9e195cb09740d799eddf1e73b7` (`Initial commit`).
- **Conceptual project inception:** pending confirmation. The reachable Git history establishes the repository date only; it provides no reliable evidence of an earlier conceptual start.

Everything is Flow; everything flows. 🌊
