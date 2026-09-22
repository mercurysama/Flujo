---
name: flujo-prove
description: Verify a completed Flujo change against scope, behavior catalog and regressions before committing, when explicitly invoked as $flujo-prove.
---

# Flujo completion gate

Verification only. Do not fix code, tests, documentation or catalog entries; do not stage, commit, amend or push. Preserve user changes and follow repository safety rules and execution limits. Stop after two failures of the same resource, without bypassing the stop through another executor or test variant.

## Procedure

1. Read `AGENTS.md` completely and its required context, `docs/development_workflow.md`, the applicable contract and `docs/behavior_catalog.json`. Establish authorized scope, comparison base and baseline evidence. Inspect the complete relevant committed, staged, unstaged and untracked changes; distinguish delivery files from protected manual work. Do not silently choose an ambiguous comparison base.
2. Map changed code and callers to affected behavior IDs and invariants, not just filenames. Compare baseline and final tests/catalog: reject removed scenarios, weaker assertions, bypassed execution, unauthorized expectation changes or unsupported passing claims. Apply the workflow's separate-commit rule for intentional behavior changes; do not reorganize commits yourself.
3. Run the existing catalog validator using the canonical command in `AGENTS.md`, consulting `tools/behavior_catalog_validator.gd` instead of duplicating its rules. Derive focal invocations from catalog `test_paths` and actual entrypoints. Consult `AGENTS.md` and applicable contracts for additional regressions and executor selection; do not reinterpret a script path as a scene argument or embed a parallel command inventory.
4. Execute affected focal tests and required proportionate regressions within authorization, deduplicating shared entrypoints. Record commands, exit codes, expected markers and project errors. A marker before a crash, script error or abnormal termination is not a pass. A hang, timeout or unresolved invocation counts as a failed run of that resource; never repeat it past the repository's two-failure limit or substitute an undeclared command to seek a pass. Missing execution remains explicit, never inferred from catalog status. Check required visual evidence separately; headless tests cannot replace it.
5. Review final scope and diff, whitespace checks required by `AGENTS.md`, unexpected files, debug instrumentation, owned temporaries and test processes. Do not alter files to make verification pass. Remove only safe temporary outputs created by this verification.

## Result

Return `PASA` only when affected behaviors are preserved or their changes explicitly authorized, coverage is not weakened, and all required checks/reviews are complete and passing. Otherwise return `NO PASA` with blockers and the smallest next authorized step. Neither result authorizes a commit or publication.

Report requirement/scope → behavior IDs → changed paths → evidence, exact commands and exit codes, baseline differences, unrun checks and reasons, environmental warnings separately from project failures, and final index/working-tree/process/temporary status. Report missing catalog entries or corrections without making them. Never fabricate manual approval or treat file existence as coverage proof.
