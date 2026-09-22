---
name: flujo-recover
description: Reconstruct and verify a recoverable checkpoint for one interrupted or paused Flujo Gota a Gota workplan, without repeating work or resuming execution, when explicitly invoked as $flujo-recover.
---

# Flujo checkpoint recovery

Require one repository-relative `docs/workplans/<ID>-<slug>.md` path. Recover evidence and checkpoint state only; never execute the drop, start another drop, run its tests, invoke another Flujo skill, or infer permission to resume.

## Establish facts

1. Read `AGENTS.md`, `docs/gota_a_gota.md`, the supplied plan, and `docs/behavior_catalog.json` completely. Follow those sources rather than copying or redefining their rules.
2. Accept only a plan in `RUNNING` after an interruption or in `PAUSED`. Reject `DRAFT`, `APPROVED`, `BASELINED`, `BLOCKED`, `PROVING`, `DONE`, and `CANCELLED` without mutation. A prior terminal result cannot be bypassed through recovery.
3. Inspect the actual branch, full HEAD, upstream relationship, index, working tree, locks, relevant processes, owned temporaries, current drop, dependencies, maintainer authorization, allowed and protected paths, declared evidence, and the existing checkpoint. Use read-only operations until the state is understood. Do not use Git plumbing that writes objects or index metadata, including `git write-tree`, `git hash-object -w`, or `git update-index`; derive evidence with read-only status, diff, `git ls-files -s`, `git ls-tree`, `git rev-parse`, and ordinary SHA-256 commands.
4. Record deterministic initial evidence: Git blob IDs for tracked files, SHA-256 for untracked files, and stable manifests for protected directories. Never restore, delete, overwrite, stage, or hide user work.
5. Require the branch, base SHA, current drop, completed dependencies, and recorded authorization to agree with observable state. Unexpected files, ambiguous ownership, stale processes, conflicting hashes, missing authority, or a changed protected path returns `BLOCKED` without editing the plan.

## Reconcile without invention

Classify each current-drop step from durable evidence:

- **confirmed complete** only when the plan and observable artifact or recorded command result agree;
- **present but unproven** when an artifact exists without the required evidence;
- **not started** when both plan and repository show no work;
- **unknown or conflicting** when evidence is absent or inconsistent.

Never mark a step complete from file existence, a success marker without normal termination, an unchecked assertion, agent memory, or a claim that cannot be reproduced from retained evidence. Preserve recorded commands, exit codes, markers, hashes, failure counts, and warnings exactly; do not rerun tests or repeat mutations to fill gaps. Two confirmed failures of one resource require `BLOCKED` and prohibit a third attempt.

## Write the checkpoint

When the preflight is eligible and evidence is consistent, the only repository write permitted is the supplied plan's lifecycle and recovery evidence:

1. For interrupted `RUNNING`, set the plan to `PAUSED`. For existing `PAUSED`, preserve that state.
2. Update only current-drop checkboxes that durable evidence proves, the evidence summary, environmental warnings, modified-file summary, and pause checkpoint. Freeze plan identity, objective, scope, non-goals, branch, base SHA, behavior mapping, file boundaries, drop definitions, dependencies, test declarations, and authorization.
3. Record the last confirmed atomic operation, last command and result, actual Git/index state, protected-file hashes, active processes, owned temporaries, retained partial work, exact next bounded action, and the explicit maintainer authorization required before `$flujo-execute` may resume.
4. If two failures or another established blocker makes continuation unsafe, set an otherwise eligible plan to `BLOCKED` and record the evidence. Do not mutate an ineligible or contradictory plan merely to label it blocked.

After writing, compare the final diff with the frozen boundaries. The plan file must be the only changed path attributable to recovery; index and history must remain unchanged.

## Result

Return `PAUSED` when the checkpoint is coherent and awaits explicit maintainer resumption, or `BLOCKED` when recovery cannot establish a safe next step. Report plan/current drop, initial and final Git state, hashes, confirmed and unproven work, commands already evidenced, project failures, environmental warnings, retained processes/temporaries, plan diff, and the smallest next authorization needed.

Never create or approve a plan, modify production or tests, weaken evidence, execute or retry a drop, stage, commit, amend, push, tag, release, install tools, or invoke `$flujo-baseline`, `$flujo-execute`, or `$flujo-prove` automatically.
