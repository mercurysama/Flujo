---
name: flujo-execute
description: Execute exactly one authorized drop from an existing Gota a Gota workplan, with strict preflight, evidence, checkpoint, and stop boundaries, when explicitly invoked as $flujo-execute.
---

# Flujo single-drop executor

Require a repository-relative workplan path and one drop ID. Execute only that drop, then stop. Never create a plan, stage, commit, amend, push, tag, release, install tools, or invoke `$flujo-prove` automatically.

## Preflight

1. Read `AGENTS.md`, `docs/gota_a_gota.md`, the supplied plan, and `docs/behavior_catalog.json` completely. The plan must be an individual `docs/workplans/<ID>-<slug>.md`, not the template.
2. Inspect the real branch, full HEAD SHA, index, working tree, dependencies, plan state, current drop, baseline evidence, maintainer authorization, allowed files, protected files, declared tests, and stop conditions. Validate catalog IDs by exact match; accept an uncatalogued behavior only when the plan explicitly records it as authorized new behavior.
3. Execution is eligible only from `BASELINED`, from `RUNNING` when the current drop and checkpoint match, or from `PAUSED` with explicit maintainer authorization to resume this drop. Reject `DRAFT`, `APPROVED` without a completed baseline, `BLOCKED`, `PROVING`, `DONE`, and `CANCELLED`.
4. Require the actual branch and HEAD to match the plan exactly, all prerequisite drops and dependencies to be complete, the baseline to be `READY` or an authorized `NEW BEHAVIOR`, and authorization to name this drop. Any wrong branch/SHA, incomplete dependency, unexpected staged or working-tree file, unauthorized target, scope expansion, or request to weaken evidence returns `BLOCKED` without changing any file.
5. Before writing, record HEAD, branch, index and working-tree status plus deterministic hashes for the plan and every existing allowed or protected file. Use Git blob IDs for tracked content and SHA-256 for untracked user files; use a deterministic tracked-file manifest when a protected path is a directory. Preserve unexpected user work and never restore it.
6. Freeze plan identity, title, objective, scope, non-goals, branch, base SHA, behavior mapping, allowed/protected boundaries, drop definitions, dependencies, and test declarations. The only plan edits permitted during execution are lifecycle state/current drop, checkboxes for this drop, actual evidence, warnings, modified-file summary, and its recoverable checkpoint.

If preflight fails, report the exact mismatch and smallest maintainer action needed. Do not mark the plan `BLOCKED` when doing so would itself mutate a plan that was never eligible.

## Execute one drop

1. After successful preflight, set the plan to `RUNNING` for the requested drop and perform only its declared actions. Modify only its allowed files plus the permitted plan evidence fields. Recheck status after every meaningful step and stop on any out-of-scope path.
2. Run only tests explicitly declared for this drop and supported by `AGENTS.md`, the catalog, an applicable contract, or an existing repository entrypoint. Do not add broader suites, substitute commands, weaken expectations, or treat file existence as a pass.
3. Record each executed command, exit code, expected marker, normal or abnormal termination, diff, modified files, tests, project failures, environmental warnings, and valid partial work. Environmental warnings never hide a project failure.
4. A resource may run at most twice. After its first failure, record and diagnose only within scope; retry once only when the drop authorizes it and the cause is understood. After a second failure, do not make a third attempt: set the plan to `BLOCKED`, preserve valid work, write the two attempts and exact next authorized step in the checkpoint, and stop.
5. When the requested drop succeeds, complete only its checkbox/evidence. If another drop remains, set the plan to `PAUSED` with a recoverable checkpoint and wait for maintainer authorization. If it was the final drop, the plan may be set to `PROVING`, with proof still pending. Never begin another drop or invoke `$flujo-prove`.

## Result

Report `PAUSED`, `PROVING`, or `BLOCKED`; the plan path and drop ID; initial and final Git state; hashes; files changed; commands and exit codes; tests and markers; project failures; environmental warnings; retained partial work; and the exact resume or proof authorization required. Confirm that index and history were not changed.

Never fix unrelated problems, alter protected plan fields, bypass the two-failure limit, or infer authorization from this skill.
