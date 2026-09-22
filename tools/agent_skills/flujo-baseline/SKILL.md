---
name: flujo-baseline
description: Verify Flujo behavior baselines before corrections, implementation on existing code, or refactoring, when explicitly invoked as $flujo-baseline.
---

# Flujo baseline gate

Verification only. Do not edit production, tests, catalog or other tracked files; do not stage, commit, amend or push. Preserve user changes and follow repository safety rules and execution limits. Stop after two failures of the same resource; do not retry merely to obtain a pass.

## Procedure

1. From the repository root, read `AGENTS.md` completely and its required context, including `docs/development_workflow.md` and the applicable contract. Read `docs/behavior_catalog.json`. Record HEAD, index, working tree, intended scope and protected user files without changing them.
2. Map scope and affected adjacent boundaries to catalog behavior IDs, public actions and invariants. Distinguish existing behavior with missing coverage from genuinely new behavior; an absent entry does not prove novelty.
3. Inspect and run the existing catalog validator using the canonical command in `AGENTS.md`; `tools/behavior_catalog_validator.gd` owns its rules. Consult `AGENTS.md` for executor selection and verification requirements, and catalog `test_paths` plus actual test entrypoints for focal invocations. Do not duplicate commands, reinterpret a script path as a scene argument or assume every `.gd` is directly executable. An unresolved invocation is a blocker.
4. Run applicable declared baselines before production changes, deduplicating shared entrypoints. Record commands, exit codes, expected markers and normal termination. A marker followed by a crash or script error is not a pass. A hang, timeout or unresolved invocation counts as a failed run of that resource; never repeat it past the repository's two-failure limit or substitute an undeclared command to seek a pass. Catalog status is historical evidence, not a fresh run. Separate manual evidence from automation; headless tests cannot approve visual behavior.
5. Missing characterization of existing behavior requires a test that passes on current, unchanged production before production edits. Report the missing public scenario and evidence needed. Adding that test or correcting the catalog belongs to a separately authorized implementation step, not this verification-only skill. A failing baseline never authorizes weakening expectations.

## Result

- `READY`: relevant existing behavior is characterized and required baselines/reviews pass.
- `NEW BEHAVIOR`: the requested behavior is genuinely new; identify its approved contract and required acceptance coverage, with affected existing baselines passing. This does not authorize implementation or waive characterization of existing behavior.
- `BLOCKED`: invalid catalog, failed/incomplete required checks, missing existing-behavior coverage, ambiguous scope or execution outside authorization. Name the smallest next authorized step.

Report scope → behavior IDs → evidence paths, exact commands and exit codes, unrun checks and reasons, project failures separately from environmental warnings, and final Git/process/owned-temporary status. Do not change catalog statuses. Remove only safe temporary outputs created by this verification, never user files.
