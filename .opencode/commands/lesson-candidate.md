---
description: Compose an evidence-backed lesson candidate without mutation
agent: explore
---

# lesson-candidate

Operate as a read-only proposal composer. Read `docs/vit_005_contract.md`
before interpreting the request. The request and context supplied to this
command are:

$ARGUMENTS

Use only existing, relevant evidence. Permitted sources are `GOTA_REPORT_V1`,
`report.txt`, `opencode-output.txt`, `live.log` when applicable, Git evidence,
Coordinator evidence, test results, and applicable contracts or documentation.
Do not invent missing facts, requirements, identifiers, run results, or
evidence. Do not expose credentials or protected local configuration.

## Read-only rules

- Do not edit or write files.
- Do not write documentation or create `docs/lesson_candidates.md`.
- Do not modify Git, SQLite, Coordinator, Gota, the harness, Skills, agents, or
  Permissions V2.
- Do not install anything.
- Do not use shell, executable instructions, or shell command prompt blocks.
- Use only the read and search capabilities available to this command. Respect
  Permissions V2 as the authority and never seek a denied capability.
- Do not accept, reject, adopt, or apply a lesson.

## Context gate

First extract and show these fields from the supplied request and existing
context:

```text
CONTEXT
GOAL
SPECIFICATIONS
CONSTRAINTS
EXPECTED_RESULT
ACCEPTANCE_CRITERIA
```

If `CONTEXT`, `SPECIFICATIONS`, `EXPECTED_RESULT`, or
`ACCEPTANCE_CRITERIA` is insufficient, ambiguous, or contradictory, stop and
output:

```text
LESSON_CANDIDATE=NOT_READY
```

Then list only the missing or conflicting information. Do not infer a remedy
or compose a candidate. Treat an absent request as an incomplete context.

## Evidence probe and composition

After the context gate passes, inspect only relevant existing evidence. A
candidate requires evidence that names its source and states the observed fact.
If the required evidence, `LESSON_ID`, or `SOURCE_RUN_ID` is absent, stop with
`LESSON_CANDIDATE=NOT_READY` and identify what is missing. Never fill a gap
with a generated claim.

When the context and evidence are complete, compose exactly one proposal using
this field set:

```text
LESSON_CANDIDATE=PROPOSED
LESSON_ID=<source-backed identifier>
SOURCE_RUN_ID=<source-backed run identifier>
SCOPE=<GENERAL or DOMAIN>
CUE=<observed signal>
LESSON=<evidence-backed learning>
EVIDENCE=<existing sources and observed facts>
CONFIDENCE=<supported strength and limitations>
TARGET=<AGENTS, COMMAND, SKILL, CONTRACT, WORKFLOW, DOCUMENTATION, or NO_CHANGE>
STATUS=PROPOSED
AUTO_MUTATION_ALLOWED=NO
HUMAN_ADOPTION_REQUIRED=YES
```

`GENERAL` is cross-harness learning. `DOMAIN` is focused on a concrete area
such as Godot, Flujo block creation, Pixel Art, or PWA/web. Do not promote a
domain lesson to general scope. `STATUS=ACCEPTED` and `STATUS=REJECTED` are
human decisions and must never be emitted by this command.

End by stating that the proposal is not authority and requires explicit human
adoption before any versioned documentation or implementation change.
