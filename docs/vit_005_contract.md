# VIT-005 — Commands + Evidence Learning

## Contract boundary

VIT-005 defines the smallest evidence-backed learning flow for the OpenCode
harness. This delivery creates exactly these two paths:

- `docs/vit_005_contract.md`
- `.opencode/commands/lesson-candidate.md`

It does not create `docs/lesson_candidates.md`. It does not introduce a new
logging system, framework, state machine, authority, or persistence model.

The Coordinator, SQLite, Gota TUI, `GOTA_REPORT_V1`, existing Skills, agents,
Permissions V2, MCP, plugins, worktrees, compaction, Godot, and
`.opencode/service.json` remain outside this contract's implementation scope.

## Authoritative delivery flow

The authoritative development flow is:

```text
CONTEXT / SPECIFICATION
→ EVIDENCE
→ LESSON CANDIDATE
→ HUMAN APPROVAL 🙆🏻
→ PLAN
→ BUILD / WORKER
→ REVIEWER / AUDITOR
```

The lesson command is a proposal aid inside this flow. It does not replace the
native OpenCode Plan, Coordinator, SQLite, Worker, Reviewer, or Auditor.

## Context and specification gate

`CONTEXT / SPECIFICATION` is always the first phase. It must make the intent
reviewable before any evidence is interpreted. It contains, at minimum, these
fields:

```text
CONTEXT
GOAL
SPECIFICATIONS
CONSTRAINTS
EXPECTED_RESULT
ACCEPTANCE_CRITERIA
```

Each field must be explicit enough to distinguish an observed requirement from
an inference. `CONTEXT`, `GOAL`, `SPECIFICATIONS`, `CONSTRAINTS`,
`EXPECTED_RESULT`, and `ACCEPTANCE_CRITERIA` must each be sufficient,
unambiguous, and mutually consistent. Constraints must be preserved rather than
relaxed to make a proposal easier to write.

If any of the six fields is insufficient, ambiguous, or contradictory, the gate
result is:

```text
LESSON_CANDIDATE=NOT_READY
```

The command must identify only the missing or conflicting information and stop.
It must not infer or complete `GOAL` or `CONSTRAINTS`, invent facts, turn an
inference into a requirement, or compose a `PROPOSED` candidate from an
incomplete context. `NOT_READY` is a gate result; it is distinct from the
lifecycle field `STATUS=PROPOSED` used by a complete candidate.

## Evidence boundary

After the intent is understood and the context gate passes, use only relevant
evidence that already exists. Permitted evidence sources include:

- `GOTA_REPORT_V1`;
- `report.txt`;
- `opencode-output.txt`;
- `live.log` when applicable;
- Git evidence;
- Coordinator evidence;
- test results;
- applicable contracts and documentation.

Every evidence item must identify its existing source and the observable fact
that supports or limits the proposed lesson. Missing evidence remains missing;
the command must not fabricate a run, result, log line, test, Git fact, or
Coordinator fact. Evidence references must not expose credentials or protected
local configuration.

VIT-005 does not create a second log, modify `GOTA_REPORT_V1`, modify the
Coordinator, write SQLite, or reinterpret a local report as operational
authority. Evidence is input to human review, not an acceptance decision.

## Lesson candidate

A complete candidate is a structured proposal composed from the gated context
and relevant existing evidence. It contains exactly these semantic fields:

```text
LESSON_ID
SOURCE_RUN_ID
SCOPE
CUE
LESSON
EVIDENCE
CONFIDENCE
TARGET
STATUS
```

The command preserves identifiers and facts supplied by the context or source
evidence. It does not manufacture a missing `LESSON_ID` or `SOURCE_RUN_ID`.
Without all required candidate data and supporting evidence, the result is
`LESSON_CANDIDATE=NOT_READY`, not a partially filled proposal.

`CUE` describes the observed signal that prompted the proposal. `LESSON` states
the learning without silently turning it into a new requirement. `EVIDENCE`
records the existing sources and facts. `CONFIDENCE` states the strength and
limits supported by those facts; it does not create authority.

The allowed scope values are:

- `GENERAL` — learning applicable to the harness transversally;
- `DOMAIN` — learning focused on one concrete area.

Examples of `DOMAIN` areas are Godot, Flujo block creation, Pixel Art, and
PWA/web. A `DOMAIN` lesson is not promoted to `GENERAL` automatically.

The allowed target values are:

- `AGENTS`
- `COMMAND`
- `SKILL`
- `CONTRACT`
- `WORKFLOW`
- `DOCUMENTATION`
- `NO_CHANGE`

The initial lifecycle value is always:

```text
STATUS=PROPOSED
```

Only a later explicit human decision may change it to `ACCEPTED` or
`REJECTED`. The command never accepts, rejects, adopts, or applies a lesson.

## Authority and adoption

A lesson candidate is not authority. Its evidence sources remain authoritative
within their own boundaries:

- Gota and the TUI for their recorded observations;
- Coordinator and SQLite for operational state;
- Git for branch, commit, and worktree facts;
- tests for their actual results;
- applicable contracts and documentation for their versioned requirements.

The final authority of an adopted lesson is versioned documentation in Git,
after explicit human approval. The candidate itself cannot change that
documentation or any operational state.

```text
AUTO_MUTATION_ALLOWED=NO
HUMAN_ADOPTION_REQUIRED=YES
```

## Adapted Harness² learning loop

Conceptually, the learning loop is:

```text
CONTEXT / SPECIFICATION
→ PROPOSE
→ PROBE
→ COMPOSE
→ HUMAN ADOPT
```

The loop is preceded by the context/specification gate and is followed, only
after human adoption and a separately authorized plan, by:

```text
PLAN
→ BUILD / WORKER
→ REVIEWER / AUDITOR
```

This is a conceptual sequence only. VIT-005 does not implement Harness², a
parallel framework, automatic probes, automatic adoption, or a second planning
authority.

## `lesson-candidate` command

VIT-005 creates only the native command:

```text
.opencode/commands/lesson-candidate.md
```

The command is read-only by design. It may inspect existing repository evidence
through normal agent capabilities and must respect the effective Permissions V2
policy. It must not edit files, write documentation, modify Git, write SQLite,
modify Gota, modify the harness, install anything, or accept a lesson. It must
not execute shell through command prompt blocks. A denied capability remains
denied; the command is not a permissions bypass.

The command must run the context/specification gate before evidence collection,
require relevant existing evidence, and emit either `NOT_READY` with the
missing or contradictory inputs or a complete `STATUS=PROPOSED` candidate. It
must make human adoption explicit and never emit `ACCEPTED` or `REJECTED` as an
automatic result.

## Commands deliberately rejected

VIT-005 creates no `preflight` command and no `evidence` command.

- `preflight` would duplicate capabilities already provided by Skills and the
  TUI.
- `evidence` would duplicate `GOTA_REPORT_V1`, the TUI, and Coordinator
  evidence.

Only `lesson-candidate` belongs to this delivery.

## Domain boundary

`GENERAL` describes a cross-harness learning. `DOMAIN` describes a learning
limited to a concrete domain. The command must retain the supplied scope and
must not infer a general rule from a domain observation. No domain Skill is
created during VIT-005.

## Versioning and Git control

`.opencode/` is affected by the shared exclude. VIT-005 does not modify
`.git/info/exclude`.

Selective staging is mandatory:

```sh
git add -- docs/vit_005_contract.md
git add -f -- .opencode/commands/lesson-candidate.md
```

Never use `git add .`, `git add -A`, or `git add -f .opencode`. Review the
staged paths and staged diff before the single local commit. Do not push, amend,
merge, rebase, reset, or change branches.

## Validation requirements

The delivery must verify, without fabricating evidence:

1. OpenCode v2.1.4 discovers the native `lesson-candidate` command.
2. The command contains no shell blocks and is read-only by design.
3. The context/specification phase contains all six minimum fields.
4. A candidate requires relevant existing evidence.
5. Automatic mutation and automatic adoption are both disabled.
6. `VIT-003` and `VIT-004` remain unchanged.
7. Only the two authorized paths change.
8. `git diff --check` passes.
9. The final worktree is clean after at most one local commit.

The catalog validator and any directly applicable checks may be run. Irrelevant
tests are not part of this delivery. Headless checks do not constitute human
adoption or visual approval.
