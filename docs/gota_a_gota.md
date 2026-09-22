# Gota a Gota Workflow

## Status and authority

This document defines the first documentation-only delivery of the Gota a Gota workflow. It coordinates existing project governance without replacing or copying its sources of truth:

- [`AGENTS.md`](../AGENTS.md) defines repository-wide safety, scope, verification, and change-control rules.
- The [behavior catalog](behavior_catalog.json) defines versioned public behaviors and their evidence.
- [`$flujo-baseline`](../tools/agent_skills/flujo-baseline/SKILL.md) is the reusable pre-change verification procedure.
- [`$flujo-prove`](../tools/agent_skills/flujo-prove/SKILL.md) is the reusable completion verification procedure.
- The [development workflow](development_workflow.md) remains the governing end-to-end sequence.

Skills contain reusable procedures. A workplan contains one authorized, concrete body of work. A plan may point to commands and evidence owned by the sources above, but must not copy them into a competing source of truth.

## Plan identity and storage

Every workplan is an individual Markdown file named `docs/workplans/<ID>-<slug>.md`, created from the [workplan template](workplans/template.md). The ID is stable; renaming the title or slug does not create a new plan identity.

There is no mutable `ACTIVE.md`. The plan's explicit `state` and Git history identify its lifecycle. Plans retain only concise decisions, checkpoints, and evidence references; verbose command logs and transient agent transcripts belong in external task output or ignored temporary storage, not in the plan.

## Roles and authority

- **Maintainer:** the human authority for scope, approval, resumption, cancellation, acceptance, and integration.
- **Moderator:** helps make scope and decisions explicit, checks that the plan remains coherent, and requests human authorization where required. A moderator cannot approve its own proposal.
- **Verifier:** invokes the required verification skill and records its result without correcting the delivery under review.
- **Executor:** performs only an approved drop within its stated files and limits. A plan never grants the executor permission to widen scope or perform Git integration.

One person or tool may perform more than one role, but authority does not transfer with the role. Human authorization remains required wherever this contract says **maintainer**.

## Lifecycle states

| State | Meaning | Permitted next states | Authority |
| --- | --- | --- | --- |
| `DRAFT` | The plan is being written and is not executable. | `APPROVED`, `CANCELLED` | A maintainer approves or cancels. |
| `APPROVED` | Scope, exclusions, files, drops, and acceptance evidence are authorized. Production work has not begun. | `BASELINED`, `BLOCKED`, `CANCELLED` | A verifier records baseline evidence; a maintainer resolves ambiguity or cancels. |
| `BASELINED` | Explicit `$flujo-baseline` returned `READY` or an authorized `NEW BEHAVIOR`, and required current-state evidence is recorded. | `RUNNING`, `BLOCKED`, `CANCELLED` | A maintainer authorizes execution; the executor records the start. |
| `RUNNING` | Exactly one approved drop is being executed. | `PAUSED`, `BLOCKED`, `PROVING`, `CANCELLED` | The executor may pause safely, block, or enter proof when all drops are complete; cancellation is maintained by a human. |
| `PAUSED` | Work stopped at a recoverable checkpoint with partial state preserved. | `RUNNING`, `BLOCKED`, `CANCELLED` | A maintainer explicitly authorizes resumption or cancellation. |
| `BLOCKED` | Work cannot safely continue because evidence, authority, a precondition, or a repeated check is missing or failing. | `DRAFT`, `APPROVED`, `CANCELLED` | A maintainer decides whether to revise, reapprove, or cancel. Changed scope must be baselined again. |
| `PROVING` | Implementation is frozen while explicit `$flujo-prove` reviews the complete delivery. | `DONE`, `BLOCKED`, `CANCELLED` | The verifier records `PASA` or `NO PASA`; only a maintainer may accept `PASA` and authorize `DONE`. |
| `DONE` | Evidence was accepted and the work is ready for separately authorized integration. | None | Terminal state. It does not itself authorize commit, push, release, or deployment. |
| `CANCELLED` | The maintainer ended the plan without acceptance. Partial work remains governed by its checkpoint and repository safety rules. | None | Terminal state. |

`BLOCKED` is mandatory after two failures of the same resource. Changing executors, command variants, or test entrypoints does not reset that count. `PAUSED` is not a way to bypass a failed gate.

## Drop contract

A **drop** is the smallest reviewable unit of an approved plan. Each drop must declare:

1. A single objective and observable completion condition.
2. Included scope and explicit non-goals.
3. Allowed files and protected files.
4. Affected behavior-catalog IDs, or an explicit statement that the work is genuinely new and does not alter catalogued behavior.
5. Preconditions, including branch, base SHA, clean-index expectations, and required prior state.
6. Baseline, focal, and completion checks derived from the catalog and repository instructions.
7. Evidence to retain, with expected markers or outcomes where applicable.
8. Stop conditions, including ambiguity, unauthorized changes, abnormal processes, and the two-failure rule.
9. A recoverable checkpoint that lets another authorized executor continue without reconstructing hidden state.

Only one drop is `RUNNING` at a time. Completing a checkbox does not authorize the next drop when a checkpoint requires human review.

## Execution invariants

An executor must not:

- expand scope, change exclusions, or add files without maintainer approval;
- weaken, bypass, delete, or silently reinterpret tests or catalog evidence;
- change production while the plan is `DRAFT`, `APPROVED`, `PAUSED`, `BLOCKED`, or `PROVING`;
- continue after two failures of the same resource;
- overwrite protected user work or hide unexpected files;
- repair a failure while acting as `$flujo-baseline` or `$flujo-prove`;
- commit, amend, push, tag, publish a release, deploy, or open/merge a pull request.

Commit, publication, and release are separate integration operations performed by a human or a separately authorized Git operator after an accepted `PASA`. Neither a plan, a checked drop, nor a skill result implicitly grants that authority.

Any intentional public-behavior change follows the catalog and separate-commit rules in `AGENTS.md`. Missing coverage for existing behavior blocks production edits until a passing characterization exists on unchanged production.

## Evidence and recovery

Evidence is concise and reproducible: behavior IDs, commands, exit codes, expected markers, relevant paths, SHAs, and links to durable review records. Environmental warnings remain separate from project failures. Unavailable metrics are recorded as `unknown` or `not measured` according to the engineering metrics policy.

Before pausing, the executor records the current drop, completed steps, exact remaining step, Git/index state, protected files, active processes, owned temporaries, last command and result, and the condition required to resume. The checkpoint must not contain secrets, private reasoning, or large raw logs.

## Future orchestration boundary

The intended future division is:

- **ChatGPT as moderator:** prepares or reviews bounded plans, surfaces ambiguity, and requests human decisions. It does not become project authority.
- **Local AI as limited executor:** receives one approved drop and only the repository/files/commands required for it, then stops at its checkpoint.
- **GitHub Actions as independent verification:** repeats deterministic repository checks from committed configuration and reports evidence without approving product decisions.

This delivery does not install or configure OpenCode, Ollama, runners, hosted agents, credentials, webhooks, or remote connections. Provider choice remains optional, and the repository contract—not an external orchestration service—remains authoritative.

Everything is Flow; everything flows. 🌊
