---
name: flujo-plan
description: Create or safely revise one concrete DRAFT Gota a Gota workplan from a sufficiently authorized Flujo request, when explicitly invoked as $flujo-plan.
---

# Flujo plan gate

Planning only. The sole permitted repository write is one requested `docs/workplans/<ID>-<slug>.md` plan. Do not modify production, tests, contracts, the behavior catalog, templates, skills, or other plans. Do not run tests, install tools, stage, commit, amend, push, tag, publish, or release.

## Procedure

1. Read `AGENTS.md`, `docs/gota_a_gota.md`, `docs/workplans/template.md`, and `docs/behavior_catalog.json` completely. Follow their authority and do not copy their maintained rules or command inventories into a competing source of truth.
2. Inspect the real current branch, full HEAD SHA, index, working tree, target plan path, and protected files using read-only repository operations. Record facts; never repair or hide unexpected state.
3. Require an authorized request that identifies a stable plan ID, objective, included scope, non-goals or limits, allowed files, protected files, affected behavior or genuinely new behavior, expected tests/evidence, and stop conditions. If any of objective, boundaries, protected files, tests, or authorization is missing or materially ambiguous, ask one concise clarification when possible and return `BLOCKED` without creating a partial or misleading plan.
4. Validate every supplied behavior ID by exact match against `docs/behavior_catalog.json`. Never invent an ID. Distinguish catalogued existing behavior from genuinely new behavior; for new behavior, write `none — authorized new behavior` and describe the required acceptance evidence without fabricating catalog coverage.
5. Create the plan only at `docs/workplans/<ID>-<slug>.md`. Copy every heading, metadata field, checklist, table, evidence section, pause checkpoint, proof field, and authorization field from `docs/workplans/template.md`; replace placeholders with request facts where known and explicit `pending`, `unknown`, or `not measured` where the template permits them. Use the real branch and full HEAD SHA. The state is always `DRAFT`; never mark approval, baseline, execution, proof, or acceptance as completed.
6. Reference tests and commands only when supported by `AGENTS.md`, the catalog, an applicable contract, or an existing repository entrypoint. Planning records evidence to obtain; it does not execute that evidence or convert file existence into a passing claim.

## Existing plans

- A requested revision is allowed only while the plan itself remains `DRAFT`, stays within the authorized request, and preserves the complete template structure.
- Before changing a `DRAFT`, establish its current bytes and report the exact requested scope adjustment.
- If the plan is `APPROVED` or any later state, reject changes to its objective, scope, base SHA, allowed files, or protected files. Return `BLOCKED` and preserve the file byte for byte. Do not create a replacement plan to bypass approval.
- Never approve the plan being authored. Only the maintainer can authorize lifecycle transitions defined by `docs/gota_a_gota.md`.

## Result

- `DRAFT`: report the created or adjusted plan path, real branch/base SHA, catalog IDs or authorized-new classification, unresolved `pending` fields, and final Git/index state.
- `BLOCKED`: report the missing or conflicting facts and the smallest human clarification or authorization needed. Confirm that no plan or other file was changed.

In both results, keep environmental warnings separate from planning blockers. Do not weaken coverage, broaden the request, add arbitrary commands, or treat this skill as authorization for implementation or Git integration.
