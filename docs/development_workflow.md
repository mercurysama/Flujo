# Flujo Development Workflow

## Required delivery path

Every change follows this sequence. A step may be brief when its scope is
small, but it may not be silently skipped:

1. **Constitution:** confirm that the work respects the [Flujo Constitution](constitution.md).
2. **Numbered specification:** update or confirm the applicable numbered
   specification before implementation begins.
3. **Clarification:** resolve material ambiguities with an authorized
   maintainer before choosing a representation or changing scope.
4. **PLAN:** use the native OpenCode Plan agent to define the smallest
   coherent path, invariants, boundaries, acceptance, and verification.
5. **Human approval:** receive explicit human approval of the plan and its
   scope before any Build/Worker implementation.
6. **BUILD/WORKER:** implement only the approved handoff and preserve model,
   runtime, editor, schema, security, and authority boundaries.
7. **REVIEWER/AUDITOR:** perform an independent, read-only review/audit of the
   approved scope, diff, evidence, and protected invariants.
8. **Tests and measurement:** run deterministic checks and focused regressions;
   record only available engineering-flow evidence.
9. **Audit and traceability:** review the change against the specification and
   record the requirement-to-evidence chain.
10. **Applicable visual review:** manually inspect visible editor behavior when
    it changes; headless tests do not replace this review.
11. **Documentation and postmortem:** update current state and contracts when
    authorized, record verified lessons, and include available metrics.
12. **Change control:** integrate only after an authorized human accepts the
    evidence and the Git state is verified.

The formal gate is `PLAN → explicit human approval → BUILD/WORKER →
REVIEWER/AUDITOR`.

The native OpenCode Plan is the only planning mechanism required here. Do not
create `flujo-plan`, a custom plan skill, or a parallel planning authority.
Plan output is a proposal/context boundary; human approval, Coordinator
authority, SQLite evidence, and the applicable contract remain authoritative.

## PLAN gate policy

A PLAN is mandatory for:

- model, persistence, schema, runtime, or editor changes;
- security changes;
- Coordinator/Gota changes;
- multiple files;
- contracts;
- behavior changes; and
- ambiguous work.

Direct BUILD is permitted only for narrowly bounded documentation or a
mechanical one-file change with no impact on behavior, contract, security,
schema, or authority. When in doubt, use PLAN. Direct BUILD never bypasses
human approval, security checks, or review.

## PLAN → BUILD/WORKER handoff

The approved handoff is compact operational context. It should contain:

```text
OBJECTIVE
AUTHORIZED_SCOPE
FILES_EXPECTED
INVARIANTS
IMPLEMENTATION_STEPS
VALIDATION
KNOWN_DEBT
DO_NOT
APPROVED_PLAN_ID
```

The handoff does not create authority, replace the numbered TaskSpec, replace
a GotaRequest, replace Coordinator, replace SQLite, or replace durable
evidence. BUILD/WORKER does not need the complete PLAN investigation repeated;
it receives the approved handoff and consults the canonical sources that apply.

## Failure and replan policy

Classify the outcome before acting:

### `RETRY_EXECUTION`

Transient runner, tool, or environment failure with the approved scope intact.
In a formal Gota, retry only through recovery authorized by Coordinator.

### `FIX_FORWARD`

Reviewer found a defect within the already approved scope. Correct it forward
without expanding the approval boundary, then revalidate.

### `REPLAN_REQUIRED`

Replan when any of these changes: requirement, contract, schema, acceptance,
scope, base SHA, design, authority, or an unexpected boundary.

### `REVIEW_ONLY`

The result is already validated, or it is known baseline debt that requires no
change.

### `STOP`

Stop on a security risk, protected-path conflict, missing Coordinator
authority, unrelated dirty worktree, incoherent durable evidence, prohibited
automatic retry, or two equivalent attributable failures under the existing
rules.

No category authorizes weakening a test, redefining a contract silently, or
discarding user changes.

## Volatile-state authority

- **Git** is authoritative for `HEAD`, branch, and worktree.
- **Coordinator/SQLite** is authoritative for `TaskRun`, lease, fencing,
  attempt, checkpoint, evidence, and operational state.
- [`current_iteration.md`](current_iteration.md) is the human handoff for the
  active iteration; it is not a runtime state store.
- Durable TUI state is the run ID, prompt, live log, and report. It does not
  become Coordinator state by implication.
- `AGENTS.md` stores none of this volatile state.

## Compaction decision

VIT-002 records `COMPACTION_DEFAULTS_OK`: there is no evidence to tune keep
tokens, buffer, or summary model. This workflow does not modify compaction.

## Specification and traceability

Every change begins by updating the corresponding specification or explicitly confirming that it already describes the intended behavior. Keep a reviewable relationship:

`requirement → task → code or documentation → test or review evidence → commit`

Use stable requirement labels, file paths, test names, and commit SHAs where available. A trace may live in a specification, issue, plan, audit, commit message, or delivery report, provided the links remain concrete and reviewable.

Use the [Engineering Flow Metrics](engineering_metrics.md) policy to record
repository evidence for a task or iteration. Metrics support system
improvement and bottleneck review; they do not rank people, create quotas, or
require unavailable data. Use `unknown` or `not measured` when evidence is not
available; never estimate.

## Mandatory delivery justification

Each delivery includes a concise, verifiable record of:

- What changed.
- Why that approach was chosen.
- Relevant alternatives that were rejected and why.
- Invariants protected.
- Risks and known limitations.
- Automated test, audit, and applicable visual-review evidence.

This requirement documents decisions and evidence, not private reasoning. Do not require, request, infer, or retain hidden chain-of-thought or other private internal agent reasoning.

## Review boundaries

Human maintainers retain authority over requirements, scope, trade-offs,
acceptance, and integration. AI tools may prepare proposals, implementations,
tests, or audits, but validators, tests, and authorized human review determine
whether a change is accepted. Coordinator and SQLite remain the operational
authority for formal Gota execution; Reviewer and Auditor do not edit or
rewrite that authority.

## Urgent security corrections

An urgent security correction follows the normal evidence and authorization requirements while prioritizing containment:

1. Verify and classify the incident without disclosing sensitive information.
2. Create or update a security specification. It may remain private while exploitation risk exists.
3. Define the smallest safe patch and its acceptance criteria.
4. Implement the patch in an isolated branch.
5. Run proportionate tests, a security audit, and the requirement-to-evidence trace.
6. Publish the patch and a responsible advisory when it is safe to do so.
7. Complete the documentation and postmortem after containment.

Urgency may compress phases, but it never omits validation, authorized human approval, or auditable evidence.

## Stable release chronicles

For every stable release, create `docs/releases/vX.Y.Z.md` titled **Flujo Release Chronicle**. It records the release date, tag, SHAs, included iterations, implemented features, architecture, visible changes, migrations, tested platforms and versions, audits, resolved problems, debt, limitations, maintenance updates, human contributions, transparent AI use, and the next roadmap segment.

After publication, link the chronicle from the README, changelog, and GitHub release publication. A Release Chronicle is a release recap for users and maintainers; it does not replace the technical postmortem for an iteration. Each chronicle ends with `Everything is Flow; everything flows. 🌊`.

Everything is Flow; everything flows. 🌊
