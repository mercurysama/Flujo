# Production Gota TUI contract

## Scope

This contract defines the local Textual terminal interface in
`tools/gota_tui/`. It is an interface and application facade over the public
Coordinator/Gota boundaries; it is not a second task state machine.

## TUI-001 — Local durable run record

After the user activates an action that will execute, and before any Worker,
OpenCode, or child process, the TUI writes a complete UTF-8 prompt, SHA-256,
request metadata, and an empty live log below the XDG state root. Writes use
replacement files and flushes where the platform permits. A run has a stable
UI `run_id`; the Coordinator-created run identity is recorded separately when
available.

## TUI-002 — Clipboard data boundary

Clipboard input and output use injectable reader/writer abstractions. System
commands receive argv lists and clipboard bytes as data. No clipboard content
is evaluated, sourced, passed to a shell, or used to select an executable.
Missing backends and copy failures remain visible diagnostics and never delete
the durable report.

## TUI-003 — Versioned prompt envelope

Plain text is previewable and may be used by read-only actions and the direct
clipboard OpenCode action. A mutable Gota action requires a versioned TOML
frontmatter envelope containing the Coordinator authority and scope fields it
needs. Missing or invalid fields fail closed; the TUI does not derive paths,
behavior identity, base SHA, acceptance criteria, or task identity from prose
or the current Git state.

## TUI-004 — Action and prompt registries

Visible actions and their mutability, confirmation, agent, model, backend, and
prompt-template metadata are declarative TOML. Only registered backends can
execute. Prompt templates, when configured, and the clipboard assignment are
persisted and combined as distinct, auditable data; the direct clipboard
backend intentionally passes the raw assignment as its prompt data.

## TUI-005 — Coordinator authority

Formal mutable execution composes the public Coordinator/Gota APIs in this order:
create/start through `CoordinatorService`, durable Worker reservation and
result persistence, read-only Git Worker-to-Review entry, durable read-only
Reviewer result persistence, and `GotaDecisionApplicationBoundary`. The TUI
never maps an OpenCode exit code to `DONE`, writes operational SQLite directly,
accepts Reviewer changes, alters fencing, or skips leases.

## TUI-006 — Recovery and UI state

History reload is based on durable JSONL/run files and tolerates a truncated
last history record. An incomplete local run is marked `UI_INTERRUPTED` only
in TUI state. Any Coordinator state is read separately and is never rewritten
by opening history. A report or prompt remains recoverable after a UI crash.

## TUI-007 — Final report lifecycle

Live logs are durable while execution runs. The compact final report is
persisted before clipboard copy is attempted. Copy failure changes only the
clipboard diagnostic, not the verdict. The log panel is cleared by changing
the Textual view, never by launching a shell `clear` command.

## TUI-008 — Dedicated-venv launcher and runtime check

The versioned launcher supports `gota`, `gota clipboard`, and `gota history`,
including `--help` and `--version`. Its runtime is exclusively the dedicated
user venv at `${XDG_DATA_HOME:-$HOME/.local/share}/flow-coordinator/gota-tui-venv`;
the installer never uses its own `sys.executable` as the product runtime.
`gota doctor` and `gota --self-check` import Textual, Rich, and `GotaApp`, and
check the state root, Action Registry, Prompt Library, and clipboard backends.
Clipboard backend absence is a warning when the TUI dependencies and app load
successfully. `Execute task` and `Review existing Gota run` retain preview and
confirmation. `Execute prompt from clipboard` is itself the confirmation: one
menu Enter starts direct OpenCode execution, and `gota clipboard` starts the
same flow without opening an action selector.

## TUI-009 — Direct clipboard OpenCode prompt

`Execute prompt from clipboard` and `gota clipboard` read one non-empty
clipboard prompt and execute it immediately through the existing
`OpenCodeRunner`. The default invocation is OpenCode 2.0.32 with model
`openai/gpt-5.6-luna#max` and agent `build`; the prompt remains one argv data
value and is never evaluated as shell syntax. This action does not create a
Coordinator `TaskRun`, lease, Worker result, Reviewer result, or decision.

The durable local run is written before the runner starts, streams stdout and
stderr into `live.log`, captures the Git HEAD before and after execution,
persists `report.txt` before attempting clipboard output, clears the live view,
shows the final report, and retains history after a UI interruption. Its report
uses `NOT_APPLICABLE` for `TASK_ID`, `CONTEXT_ID`, `COORDINATOR_STATE`,
`WORKER_RESULT`, and `REVIEW_RESULT`. Empty input does not start OpenCode;
runner start failure is `FAIL`, timeout is `FAIL/TIMEOUT`, and clipboard output
failure is a warning that does not remove the report.

## GOTA-TUI-002 — Read-only OpenCode audit backend

The production registry exposes two distinct analysis actions. `audit-readonly`
remains the fast local `git-audit` action and is labelled **Read-only Git audit**.
The new `audit-opencode` action is labelled **Read-only OpenCode audit** and has
`mutable = false`, `requires_prompt = true`, `requires_confirmation = true`,
and backend `opencode-readonly`. Its default model is
`openai/gpt-5.6-luna#max`, with the existing configuration override boundary
preserved.

`audit-opencode` uses a canonical project agent whose OpenCode V2 permission
policy denies modification, shell, external-directory, Git-mutation,
subagent, and skill capabilities and allows only read/search inspection tools.
The action fails closed before execution when the durable prompt, repository,
model, or read-only policy is invalid. It never creates a Coordinator TaskRun,
acquires a Worker lease, invokes Reviewer, writes operational SQLite, or
performs Git/file/worktree mutation.

The prompt passed to OpenCode is read from the durable `prompt.txt` created by
the TUI before confirmation; clipboard contents are not read again. The
existing `OpenCodeRunner` remains the sole subprocess boundary and supplies
`--standalone`, canonical configuration, provider/model#variant argv data,
bounded timeout/termination, shell-free invocation, and incremental stdout and
stderr observation. The local run request/result persist run/action identity,
prompt SHA-256, model, variant, OpenCode version, agent, repository, timestamp,
and timeout.

The audit snapshots Git HEAD, branch, porcelain status, and refs before and
after the child. Any changed snapshot or detected denied mutation attempt makes
the verdict `FAIL`; no automatic revert is attempted. A zero-exit generic
OpenCode response is accepted without requiring a `flujo.gota/v1` payload. The
complete stdout/stderr remains in `live.log`; a compact report may point to a
durable associated output artifact and preserves prompt-requested delimited
blocks without imposing a single findings schema. `TASK_ID`, `CONTEXT_ID`,
`WORKER_RESULT`, and `REVIEW_RESULT` are `NOT_APPLICABLE` for this action.

The report is persisted before clipboard copy. Clipboard failure is a warning
only and cannot change the analysis verdict. The Textual path is
clipboard → `audit-opencode` → Enter → confirmation → Enter → running/live log
→ durable report → final report; the footer labels remain `Enter Select/confirm`,
`Esc Back/cancel`, `C Clipboard`, and `H History`.

## Traceability

`TUI-001`–`TUI-009` and `GOTA-TUI-002` map to the implementation modules and tests in
`tools/gota_tui/`, the `FLUJO-BHV-GOTA-TUI-001` and
`FLUJO-BHV-GOTA-TUI-002` behavior-catalog entries, and the production-TUI
delivery commits. Coordinator/Gota authority behavior remains covered by the
existing `FLUJO-BHV-GOTA-*` and `FLUJO-BHV-OPENCODE-RUNNER-001` entries.

## Decisions and limitations

- Textual is retained because the historical v4 implementation uses it and
  the production UI needs independent scrolling surfaces.
- A new Coordinator schema or SQLite table is not introduced. The existing
  public boundaries are composed instead of mirrored.
- The initial mutable flow creates a Coordinator task from a valid envelope;
  Coordinator assigns the operational run ID. Retrying a reserved Worker
  attempt is not invented by the TUI; the existing recovery boundary remains
  authoritative.
- The TUI does not automatically recover or cancel an operational task after
  a crash. It reports the durable Coordinator truth and leaves takeover or
  cancellation to the existing authorized Coordinator APIs.
