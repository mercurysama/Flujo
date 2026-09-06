# Flujo Development Workflow

## Required flow

Every change follows this sequence. A step may be brief when its scope is small, but it may not be silently skipped.

1. **Constitution:** confirm that the work respects the [Flujo Constitution](constitution.md).
2. **Numbered specification:** update or confirm the applicable numbered specification before implementation begins.
3. **Clarification:** resolve material ambiguities with an authorized maintainer before choosing a representation or changing scope.
4. **Plan:** define the smallest coherent path, invariants, boundaries, and verification.
5. **Small tasks:** divide the plan into independently reviewable tasks with explicit acceptance criteria.
6. **Implementation:** make only the authorized changes and preserve model, runtime, editor, and schema boundaries.
7. **Tests and measurement:** run deterministic checks and any focused regression needed for the changed invariant; record only available engineering-flow evidence.
8. **Audit and traceability:** review the change against the specification, record the requirement-to-evidence chain, and review measurable bottlenecks without ranking individuals.
9. **Applicable visual review:** manually inspect visible editor behavior when it changes; headless tests do not replace this review.
10. **Documentation and postmortem:** update current state and contracts, record verified lessons when a milestone closes, and include the applicable engineering-flow metrics and corrective actions.
11. **Change control:** integrate only after an authorized human accepts the evidence and the Git state is verified.

## Specification and traceability

Every change begins by updating the corresponding specification or explicitly confirming that it already describes the intended behavior. Keep a reviewable relationship:

`requirement → task → code or documentation → test or review evidence → commit`

Use stable requirement labels, file paths, test names, and commit SHAs where available. A trace may live in a specification, issue, plan, audit, commit message, or delivery report, provided the links remain concrete and reviewable.

Use the [Engineering Flow Metrics](engineering_metrics.md) policy to record repository evidence for a task or iteration. Metrics support system improvement and bottleneck review; they do not rank people, create quotas, or require unavailable data.

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

Human maintainers retain authority over requirements, scope, trade-offs, acceptance, and integration. AI tools may prepare proposals, implementations, tests, or audits, but validators, tests, and authorized human review determine whether a change is accepted.

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
