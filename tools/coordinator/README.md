# Flow task coordinator

This directory contains the local, language-independent core of the
Multiproject Coordinator v1. It is a standalone Python package and has no
dependency on Godot or the Flujo plugin.

## `flujo.gota/v1` contract boundary

Gota result framing recognizes `FLUJO_GOTA_RESULT_V1_BEGIN` and
`FLUJO_GOTA_RESULT_V1_END` only when each token is the complete content of a
line. Only LF and CRLF are valid line endings; CRLF is normalized explicitly,
and other separators are rejected. One complete payload may have free text
before and after it. The content between the delimiters is the JSON text
itself: blank framing lines and leading or trailing whitespace around that
text are invalid. The Python parser accepts only strict JSON, rejects
duplicate keys at every object depth, and rejects `NaN`, `Infinity`,
`-Infinity`, and numeric overflow such as `1e9999`.

The versioned JSON Schemas validate JSON-local structure: required fields,
non-blank strings, positive attempts, 40-character SHA formats, and protocol
enums. Under JSON Schema Draft 2020-12, mathematically integral numbers such
as `1.0` satisfy the `integer` type. The textual parser retains decimal
precision while validating `attempt`, then normalizes valid JSON `1` or `1.0`
to `int`; direct Python floats are not accepted as an exact replacement for a
JSON number. Python checks `request_id == run_id + ':' + attempt + ':' + phase`
after normalization. The protocol models own that cross-field invariant
because standard JSON Schema cannot express it portably. Schema tests use the
optional `test` dependency `jsonschema`; it is not a runtime dependency.

`flow_coordinator.Checkpoint` remains the historical persistent checkpoint.
The Gota protocol type is available only as the explicit `GotaCheckpoint`
name; it is not exported through a generic `Checkpoint` alias.

### FIX-REVIEW-ACCESS-001 — verified semantic review packet

The authorized correction to REVIEW-ACCESS-001 separates mechanical Git
verification (Coordinator) from read-only semantic audit (Reviewer). The closed
PILOT-001S remains historical BLOCKED evidence and must not be retried or edited.

After the existing `verify_worker_commit_git()` accepts the handoff, `ReviewPhase`
builds a self-contained packet with the review request/acceptance criteria,
allowed/protected paths, verified base/commit/changed paths, exact binary/full-index
patch, raw commit metadata, ancestry, exactly-one-commit, clean worktree and
`diff --check` result. `ReadOnlyGitAdapter` supplies the new read-only inspections;
Git fingerprints are checked again before execution and after review. No patch
truncation or new size policy is introduced. Existing process/OS limits remain
observable execution failures, never permission to silently omit evidence.

The complete WorkerResult (including evidence, checkpoint and reported warnings)
is a separate `worker_report`, not Git authority. The persistence boundary embeds
the run's persisted evidence bodies, task context and checkpoints as
`persisted_reports`; their contents remain reports, not independently verified
test results. It never follows report paths or asks Reviewer to read external
baseline files. Callers must persist necessary report bodies, not only references;
genuinely missing semantic evidence can still require correction or human review.

The canonical `gota-reviewer` permits only read/glob/grep. Shell, external-directory
access, edits, subagents and skills remain denied by default; no model is pinned.
The prompt requires auditing only the packet and returning one `flujo.gota/v1`
`review.result`. `--auto` is not human authorization and cannot override denials.
ReviewResult anchors, lease/fencing, restart idempotence and DecisionApplication
are unchanged. Push/merge support is not added.

Trace: FIX-REVIEW-ACCESS-001 → `gota_phases.py`, `gota_persistence.py`,
`git_adapter.py`, `.opencode/agents/gota-reviewer.md` → packet/permission tests in
`tests/test_gota_review_persistence.py`, existing entry/cycle/protocol/persistence/
decision tests → the single `fix: make Gota review packet self-contained` commit.
Widening permissions, trusting Worker stdout, following arbitrary external paths
and adding a parallel Git authority were rejected. Remaining limitations: test
reports are not rerun by Reviewer, and incomplete persisted evidence is not
fabricated. There is no plugin runtime/model/schema/UI change or visual review
requirement. Test totals, RED evidence, isolated real-agent smoke and final commit
are recorded in the delivery report; durations/credit consumption are not measured.

### FIX-REVIEW-TAKEOVER-001 — durable frontier recovery

Recovery/takeover never rewrites historical authority. The Worker request,
invocation and WorkerResult retain one coherent positive historical fence.
Each durable frontier keeps the fencing generation that created it: REVIEW's
`gota_worker_commit_verified` and its exact anchored RUNNING → REVIEW event
must share a positive fence **at least** as new as the Worker authority.
The anchor fixes the evidence ID/digest, event ID and shared timestamp; it does
not need a new fencing column or a schema migration.

Reentry validates that persisted frontier's historical authority, not the
Worker fence or a replacement lease's fence. The current lease still passes
`fenced_transaction` and final trusted-clock checks; only it authorizes new
mutations. Reentry rejects a frontier newer than that current lease. Thus a
takeover between durable WorkerResult and REVIEW can enter REVIEW without
repeating Worker. A crash after persisting REVIEW but before Reviewer can resume
Reviewer without duplicating the transition, commit verification or anchor.
A subsequent takeover during REVIEW preserves that frontier while new Reviewer
evidence uses the new lease.

Trace: FIX-REVIEW-TAKEOVER-001 → `src/flow_coordinator/store.py`
(`_review_entry_fencing_token`, entry/review/decision authority readers) →
`test_takeover_before_review_reentry_preserves_frontier_after_restart`,
`test_takeover_before_review_continues_reviewer_once_after_restart` and
`test_takeover_frontier_fencing_tampering_fails_closed` in `tests/`, plus existing
same-generation, post-REVIEW takeover, anchor/Git tampering and stale-lease tests →
the single `fix: preserve Gota review frontier across lease takeover` commit.
Both recovery regressions reproduced the exact transition-incoherence error
against unchanged production before the fix. The prior tests covered initial
entry after takeover and reentry separately, but never their composition.

This correction derives REVIEW fencing explicitly from persisted commit evidence
and checks its anchored event; disabling fence validation, rewriting old evidence,
special-casing pilot identities and changing the FSM/API/schema were rejected.
Review packet and deny-by-default Reviewer permissions remain unchanged. No real
agent/pilot execution or plugin model/runtime/UI change is needed; visual review
is not applicable. Limits: absent WorkerResult still requires human recovery;
this fix does not reconstruct missing authority. Baseline: 366 tests passed;
three new tests include ten adversarial fencing variants. Final test totals and
isolated persistence smoke are delivery evidence. Review time, credits and
lead time are not measured.

The operational store is SQLite. The future default location is
`~/.local/state/flow-coordinator/coordinator.sqlite3`; tests always pass an
isolated temporary database explicitly.

Official task states are:

- `🌊 ASSIGNED`
- `🛠 RUNNING`
- `👀 REVIEW`
- `🙆🏻 DONE`
- `🙅🏻 NOT_COMPLETED`
- `⛔ BLOCKED`
- `❌ CANCELLED`

`❤️‍🔥 COOLDOWN` belongs only to a coordinator resource. It is activated only
when a run actually used a resource whose policy requires cooldown. It never
changes the state of a task run.

The original Git inspection adapter remains read-only. Mutable acceptance is
isolated behind `TransactionalGitAdapter`, which requires an explicit
authorized root, stages only the task's exact allowlist, records a staging
manifest, and creates one local commit with task/run trailers. Recovery reuses
a matching commit rather than creating a duplicate. The integration suite uses
only temporary fixture repositories; the Flujo repository is inspected only
through its read-only boundary. Push and merge are intentionally unavailable.

Run the isolated tests from the repository root:

```sh
PYTHONPATH=tools/coordinator/src python3 -m unittest discover -s tools/coordinator/tests -v
```

Inspect an isolated store:

```sh
PYTHONPATH=tools/coordinator/src python3 -m flow_coordinator.cli --db /tmp/coordinator.sqlite3 init
PYTHONPATH=tools/coordinator/src python3 -m flow_coordinator.cli --db /tmp/coordinator.sqlite3 status
```

## Production Gota TUI

The local Textual terminal interface lives in `tools/gota_tui/`. Its
`CoordinatorGotaFacade` composes the public Worker reservation, Worker-to-Review,
Reviewer persistence, and decision-application boundaries; it does not write
Coordinator SQLite directly or infer `DONE` from an OpenCode exit code. See
[`tools/gota_tui/README.md`](../gota_tui/README.md) and
[`docs/gota_tui_contract.md`](../../docs/gota_tui_contract.md) for installation,
durable UI recovery, clipboard security, and the versioned envelope.
