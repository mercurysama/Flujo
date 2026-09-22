# Gota a Gota Workplan: `<title>`

> Copy this file to `docs/workplans/<ID>-<slug>.md`. Do not use this template as a mutable active-plan pointer.

## Metadata

| Field | Value |
| --- | --- |
| Plan ID | `<stable ID>` |
| Title | `<concise title>` |
| State | `DRAFT` |
| Branch | `<branch>` |
| Base SHA | `<full SHA>` |
| Current drop | `<drop ID or none>` |
| Maintainer authorization | `<reference or pending>` |
| Created / updated | `<verifiable date or unknown>` |

Governing sources: [Gota a Gota workflow](../gota_a_gota.md), [`AGENTS.md`](../../AGENTS.md), [behavior catalog](../behavior_catalog.json), [`$flujo-baseline`](../../tools/agent_skills/flujo-baseline/SKILL.md), and [`$flujo-prove`](../../tools/agent_skills/flujo-prove/SKILL.md).

## Behavior mapping

- Catalog IDs: `<FLUJO-BHV-... or none>`
- Existing behavior, new behavior, or behavior-preserving work: `<classification>`
- Applicable contract and requirement IDs: `<links/IDs>`
- Baseline result: `<READY, NEW BEHAVIOR, BLOCKED, or pending>`
- Baseline evidence: `<commands, exit codes, markers, durable references>`

## Objective

`<One observable outcome.>`

## Scope

- `<included item>`

## Non-goals

- `<explicit exclusion>`

## File boundaries

### Allowed

- `<path>`

### Protected

- `<path and required preservation rule>`

## Preconditions

- [ ] Branch and base SHA match the metadata.
- [ ] Index and working-tree state match the authorized expectation.
- [ ] Protected-file hashes or conceptual state are recorded when required.
- [ ] Required contracts and repository instructions were read.
- [ ] `$flujo-baseline` completed with a state that permits the authorized work.
- [ ] No unexpected process, lock, temporary, or unrelated change is present.

## Drops

### `<DROP-ID>` — `<small objective>`

- [ ] Preconditions confirmed.
- [ ] Smallest authorized change completed.
- [ ] Focal evidence completed.
- [ ] Recoverable checkpoint recorded.

Scope: `<included work>`

Exclusions: `<drop-specific exclusions>`

Allowed files: `<paths>`

Affected behaviors: `<catalog IDs or authorized new behavior>`

Tests and expected evidence: `<references, not duplicated command inventories>`

Stop conditions: `<ambiguity, unexpected state, repeated failure, or other boundary>`

Checkpoint: `<what another authorized executor needs to continue safely>`

## Verification plan

| Phase | Behavior IDs | Evidence source | Expected result | Actual result |
| --- | --- | --- | --- | --- |
| Baseline | `<IDs>` | `<catalog paths/entrypoints>` | `<marker/state>` | `<code/result or pending>` |
| Focal | `<IDs>` | `<test/review>` | `<marker/state>` | `<code/result or pending>` |
| Regression | `<IDs>` | `<test/review>` | `<marker/state>` | `<code/result or pending>` |
| Proof | `<IDs>` | `$flujo-prove` | `PASA` | `<result or pending>` |

## Evidence summary

- Commands and exit codes: `<concise list or durable reference>`
- Modified files: `<paths>`
- Protected invariants: `<list>`
- Limitations and deferred work: `<list>`
- Visual review: `<not applicable, pending, or approved with reference>`
- Engineering metrics unavailable from evidence: `<unknown/not measured fields>`

Do not paste extensive logs or transcripts here. Keep them in the authorized external task record or ignored temporary storage and link only durable evidence.

## Environmental warnings

- `<warning, clearly separated from project failures, or none>`

## Pause checkpoint

- State: `<PAUSED or BLOCKED>`
- Current drop and last completed atomic operation: `<value>`
- Last command and result: `<command, exit code, marker>`
- Git/index/working-tree state: `<value>`
- Protected files: `<hash/state>`
- Active processes and owned temporaries: `<value>`
- Exact next step: `<one bounded action>`
- Resume condition and authorization: `<value>`

## Completion proof

- `$flujo-prove` result: `<PASA, NO PASA, or pending>`
- Scope/diff review: `<reference>`
- Catalog/test-strength review: `<reference>`
- Remaining blockers: `<none or list>`

## Final authorization

- Maintainer decision: `<accepted, rejected, cancelled, or pending>`
- Authorized terminal state: `<DONE, CANCELLED, or pending>`
- Integration authorization: `<separate reference or none>`
- Commit/push/release performed by: `<human or separately authorized Git operator; never inferred from this plan>`

Everything is Flow; everything flows. 🌊
