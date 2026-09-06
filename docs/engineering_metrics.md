# Flujo Engineering Flow Metrics

## Purpose

These metrics describe the complete path from a requirement to an accepted delivery. They measure how the engineering system behaves, not the volume of code produced or the value of an individual contributor.

## Principles

- Use metrics to improve the system, never to rank, monitor, or compare people.
- Do not use lines changed, commits, or speed as isolated targets.
- Do not collect personal information, private prompts, credentials, or private internal reasoning.
- Prefer reproducible repository evidence: requirement IDs, task records, Git timestamps and SHAs, diffs, test output, audit reports, and review records.
- Record only evidence that is available for the task. Write `unknown` or `not measured` rather than estimating or inventing a value.
- AI tools may be recorded when known as development context, but they are not a productivity score and are not a Flujo dependency.

## Per-task metrics

For each task, record when evidence is available:

- Requirement and task identifiers.
- Verifiable start and completion timestamps.
- Time to a validated commit and review time.
- Change size: files, insertions, and deletions.
- Required, passing, and failing tests.
- First-validation result.
- Number and cause of corrections or amends.
- High, Medium, and Low audit findings.
- Subsequent regressions.
- Visual-review status: required, approved, or not applicable.
- Manual interventions and environmental blockers.
- AI tool or model used, when known.
- Credit consumption only when a user supplies it voluntarily.

## Per-iteration metrics

When evidence is available, an iteration records:

- Requirement lead time.
- Waiting time versus active work time.
- Percentage of tasks approved on first validation.
- Rework, defects, change size, and review time.
- Bottlenecks and corrective actions.

Establish a baseline over three iterations before setting numerical targets. Do not compare personal productivity or set quotas before sufficient evidence exists.

## Evidence and interpretation

Correlation does not establish causation. Metrics can distort behavior when converted into quotas, so review them with the relevant technical context, limitations, and human judgment. A missing measurement is information about the evidence available, not a failure by a person.

## Compact template

Use this template in future technical postmortems and Flujo Release Chronicles as applicable:

```markdown
### Engineering flow metrics

| Field | Evidence |
| --- | --- |
| Requirement / task | `<id>` / `<id>` |
| Start / completion | `<ISO 8601 or unknown>` / `<ISO 8601 or unknown>` |
| Validated commit / review time | `<SHA or unknown>` / `<duration or not measured>` |
| Change size | `<files, +insertions, -deletions>` |
| Tests | `<required; passed; failed>` |
| First validation / corrections | `<passed, failed, or unknown>` / `<count and cause>` |
| Audit findings / later regressions | `<H/M/L>` / `<none, list, or not measured>` |
| Visual review | `<required, approved, or not applicable>` |
| Manual interventions / blockers | `<evidence or none>` |
| AI tool or model / voluntary credits | `<known, unknown, or not measured>` / `<provided value or not measured>` |
| Iteration bottleneck / corrective action | `<evidence or not measured>` |
```

Everything is Flow; everything flows. 🌊
