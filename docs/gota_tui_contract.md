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
`openai/gpt-5.6-luna`, variant `max`, and agent `build`; the prompt remains one
argv data value and is never evaluated as shell syntax. This action does not create a
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
`mutable = false`, `requires_prompt = true`, `prompt_source = "clipboard"`,
`requires_confirmation = true`, `confirmation_mode = "selection"`, and backend
`opencode-readonly`. Its default model is
model `openai/gpt-5.6-luna` and variant `max`, with the existing configuration override boundary
preserved.

`audit-opencode` uses a canonical project agent whose OpenCode V2 permission
policy denies modification, shell, external-directory, Git-mutation,
subagent, and skill capabilities and allows only read/search inspection tools.
The action fails closed before execution when the durable prompt, repository,
model, or read-only policy is invalid. It never creates a Coordinator TaskRun,
acquires a Worker lease, invokes Reviewer, writes operational SQLite, or
performs Git/file/worktree mutation.

The prompt passed to OpenCode is read from the durable `prompt.txt` created by
the TUI when the action is activated; clipboard contents are not read again.
The selection plus Enter is the action confirmation and does not open a second
confirmation screen. The existing `OpenCodeRunner` remains the sole subprocess boundary and supplies
`--standalone`, canonical configuration, `provider/model#variant` selector argv
data,
bounded timeout/termination, shell-free invocation, and incremental stdout and
stderr observation. The local run request/result persist run/action identity,
prompt SHA-256, model, variant, OpenCode version, agent, repository, timestamp,
and timeout.

The audit snapshots Git HEAD, branch, porcelain status, and refs before and
after the child. Any changed snapshot or detected denied mutation attempt makes
the verdict `FAIL`; no automatic revert is attempted. A zero-exit generic
OpenCode response is accepted without requiring a `flujo.gota/v1` payload. The
complete observed stdout/stderr, with local credential values redacted, remains in `live.log`; a compact report may point to a
durable associated output artifact and preserves prompt-requested delimited
blocks without imposing a single findings schema. `TASK_ID`, `CONTEXT_ID`,
`WORKER_RESULT`, and `REVIEW_RESULT` are `NOT_APPLICABLE` for this action.

The report is persisted before clipboard copy. Clipboard failure is a warning
only and cannot change the analysis verdict. The Textual path is
clipboard → select `audit-opencode` → Enter → running/live log → durable report
→ final report. The user does not need to press `C`, and the action never
dispatches `clipboard-prompt` or `build`.

## GOTA-TUI-003 — Contextual clipboard prompt by action

Every declarative action with `requires_prompt = true` declares a supported
`prompt_source`. For the current clipboard-backed actions the source is
`clipboard`. When such an action is activated without an already loaded prompt,
the TUI obtains the current clipboard value through the injectable clipboard
reader, rejects empty input, and routes the resulting prompt through the
action's registered backend. The source and backend are resolved from the
Action Registry; `audit-opencode` is not a special clipboard dispatch.

`Execute prompt from clipboard` remains the direct `clipboard-prompt` action:
one Enter reads the clipboard, persists the prompt and SHA-256 before spawning,
and runs OpenCode with `build`, model `openai/gpt-5.6-luna`, and variant `max`. The `C` shortcut
has the explicit footer label **Run clipboard prompt** and invokes that same
direct action. `gota clipboard` remains equivalent to this direct flow.

For `audit-opencode`, one action selection plus Enter reads and validates the
clipboard, persists the prompt and SHA-256 before `OpenCodeRunner`, uses
`gota-auditor`, model `openai/gpt-5.6-luna`, and variant `max`, preserves the read-only policy,
streams live output, persists the report, and copies the report. Empty
clipboard, invalid read-only agent or policy, and an invalid repository fail
closed before OpenCode execution. No failure path silently changes the action
to `clipboard-prompt` or the agent to `build`.

## GOTA-TUI-007 — Per-run model, variant, role, and agent routing

Before a registered backend is prepared, the TUI parses only a contiguous
header at prompt offset zero. The supported fields are `GOTA_MODEL`,
`GOTA_VARIANT`, `GOTA_ROLE`, and `GOTA_AGENT`; duplicate or invalid values fail
closed before OpenCode starts. Header-looking lines later in the prompt remain
assignment data and are not reinterpreted.

The original prompt, including its header, remains the durable prompt and the
prompt SHA-256 covers that original text. The effective prompt removes the
initial header. When a role is present, the effective prompt is explicitly
constructed as `ROLE:\n<role>\n\nTASK:\n<body>`; without a role, the body is
preserved unchanged. For formal actions, the header-free body is the input to
the registered template/composition as well as to direct and read-only flows.

Each run resolves values with prompt-header precedence, then CLI/environment
configuration overrides, then the declarative action values, and finally the
legacy defaults (`openai/gpt-5.6-luna`, variant `max`, agent `build`). The
effective selection is persisted before execution and `GOTA_REPORT_V1` records
`MODEL`, `VARIANT`, `ROLE`, `AGENT` and the corresponding `*_SOURCE` fields.
For OpenCode 2.1.4, the subprocess boundary combines a configured variant into
the model selector and receives argv in the form `opencode run --standalone
--model <model>[#<variant>] --agent <agent> --auto <effective-prompt>`; it never
emits a separate `--variant` flag. Without a variant, the selector is exactly
`<model>` without a trailing `#`. No model, variant, role, agent, or prompt value
is evaluated through a shell. Read-only actions continue to validate the
resolved agent against their canonical policy.

## GOTA-TUI-004 — Auditor denial classification and credential boundary

The canonical `gota-auditor` remains deny-by-default. Its shell allowlist is
limited to explicit read-only Git command forms. The agent must issue one
operation per shell call: no command chaining, pipes, redirections, subshells,
or shell metacharacters. `git log -n 20 ...` is the supported replacement for
`git log ... | head -20`; separate read-only Git calls are required instead of
`;` or other chaining. The auditor may inspect existing tests and recorded
results, but it must not execute Python, unittest, or any test suite during
`audit-opencode` unless a future specialized action explicitly authorizes it.

Known local credential paths, including `.opencode/service.json`, are denied
before the model can read them. Public tracked configuration, schemas, agent
policies, and documentation remain the preferred audit sources. Local output
redaction remains a second defense and does not authorize credential reads.

The mutation guard has four observable classifications. `MUTATION_DETECTED`
means a changed HEAD, branch, porcelain status, protected ref, or file state;
`MUTATION_ATTEMPT_DENIED` means an explicitly denied edit/write/patch tool or
inequivocally mutating shell command; `READONLY_COMMAND_DENIED` means a
read-only or otherwise non-mutating command was denied by the shell policy;
and `SENSITIVE_PATH_BLOCKED` means a protected credential path was denied.
Only the first two classifications can make
`UNEXPECTED_MUTATION_GUARD=FAIL`. Read-only and sensitive-path denials are
warning findings and never become mutation evidence merely because the generic
diagnostic says `Permission denied: shell`. If a denied read was required for
complete evidence, the audit may remain incomplete/fail closed, but its report
must retain the non-mutating classification.

The report preserves these categories as distinct findings, redacts local
credential values from live logs, associated output, reports, and result data,
and never reads `.opencode/service.json` as audit input. The smoke path with
unchanged Git state and no denied operation ends in `READ_ONLY_OK`.

## GOTA-TUI-005 — Direct process and embedded report consistency

The `clipboard-prompt` backend keeps two explicitly separate observations:
the OpenCode process result and an optional embedded task report. The process
status and exit code remain authoritative for the direct technical verdict;
embedded report text is informational evidence only and never creates or
changes Coordinator, TaskRun, lease, fencing, SQLite, FSM, Git, or Reviewer
authority.

The direct backend creates `opencode-output.txt` before child execution and
persists the final captured stdout and stderr there before the compact report
is copied. All observed channels and durable result/report data pass through
the existing local credential redaction boundary. `GOTA_REPORT_V1` exposes the
durable `OUTPUT_PATH` when it exists, plus `PROCESS_STATUS` and
`PROCESS_EXIT_CODE`.

The reporting boundary also reads `OUTPUT_PATH` and, when a complete
`STDOUT_BEGIN`/`STDOUT_END` block is present, appends the complete UTF-8 stdout
as `GOTA_OPENCODE_STDOUT_BEGIN`/`GOTA_OPENCODE_STDOUT_END`. The machine-readable
fields `OUTPUT_EMBED_STATUS`, `OUTPUT_EMBED_SOURCE=OPENCODE_STDOUT`, and
`OUTPUT_EMBED_BYTES` describe that additional evidence. `OK` embeds the full
stdout without truncation; `EMPTY` is a valid empty block;
`NO_STDOUT_BLOCK` and `UNAVAILABLE` retain `OUTPUT_PATH` but append no body.
The original Coordinator embedded-report fields and `RESULT_CONSISTENCY` are
unchanged. `STDERR_BEGIN`/`STDERR_END` is never copied into the report and
remains available only through `OUTPUT_PATH` (and the durable live log).
`report.txt` and the clipboard use one extraction snapshot, so the embedded
stdout is identical in both representations; only their existing copy-status
field may differ while the copy is pending.

Only one complete, line-delimited stdout block with the exact shape
`=== <ID>_REPORT_BEGIN ===` and `=== <ID>_REPORT_END ===` is parsed. More than
one complete block is ambiguous, including repeated identical blocks. A
duplicate `STATUS` or `VERDICT` line is also structurally ambiguous, even when
the duplicate values are identical; the first observed value may remain only as
informational evidence. A BEGIN without its matching END, an END
without BEGIN, a loose `VERDICT` line, arbitrary PASS text, prompt/request
content, and stderr-only markers do not become an embedded report. The parser
preserves the original report values and text while conservatively normalizing
only the explicit contract values `PASA`, `PASS`, `READ_ONLY_OK`, `SUCCEEDED`,
`NO PASA`, `FAIL`, `FAILED`, `BLOCKED`, and `BLOQUEADO`.

`RESULT_CONSISTENCY` distinguishes at least `NO_EMBEDDED_REPORT`,
`PROCESS_AND_REPORT_PASS`, `PROCESS_AND_REPORT_FAIL`,
`PROCESS_FAIL_REPORT_PASS`, `PROCESS_PASS_REPORT_FAIL`, and
`INCOMPLETE_EMBEDDED_REPORT`. A non-zero process never becomes success because
an embedded report says PASS. A zero-exit process with an explicit negative
embedded verdict remains technically successful but is surfaced as a result
conflict. Conflict reports show `RESULT CONFLICT — review required` and, for
`PROCESS_FAIL_REPORT_PASS`, the diagnostic `Process failed, but the embedded
task report declared PASS. Manual review required.`
Ambiguous embedded evidence is classified as `AMBIGUOUS_EMBEDDED_REPORT` and
never becomes `PROCESS_AND_REPORT_PASS`. Whenever the visible final or
historical report changes, the `result-conflict` visual state is recalculated
from the newly displayed report.

## TUI-010 — Monotonic execution timing

Every `GOTA_REPORT_V1` contains `STARTED_AT`, `FINISHED_AT`, `DURATION_MS`, and
`DURATION_HUMAN`. `STARTED_AT` is the UTC ISO-8601 wall-clock observation made
when `ActionExecutor.execute()` accepts the prepared run, before its local
`RUNNING` marker and backend dispatch. `FINISHED_AT` is the corresponding
wall-clock observation taken when the selected backend has returned an outcome
or a handled exception has been converted into one, immediately before the
reporting pipeline begins. `DURATION_MS` is the authoritative elapsed value
from the runtime monotonic clock; it is never calculated by subtracting the
wall-clock timestamps. The duration includes the registered backend's
execution and its handled failure paths, but excludes report persistence,
automatic clipboard copy, and any later user-triggered `Copy report` action.

`DURATION_HUMAN` is a deterministic presentation derived from `DURATION_MS`.
`TIMESTAMP` retains its existing meaning: the `created_at` timestamp written
when the local durable TUI run record is prepared, before the prompt and live
log are made eligible for child execution. It is not replaced by either run
boundary timestamp.

For a single direct or read-only OpenCode invocation, the report also exposes
`PROCESS_DURATION_MS` and `PROCESS_DURATION_HUMAN`. These values come from the
OpenCodeRunner monotonic subprocess boundary: spawning the OpenCode process
(or its existing Linux containment wrapper) through completion and bounded
output collection. They exclude Gota report construction and clipboard work.
Formal Coordinator actions may invoke more than one OpenCode phase or reuse a
durable phase result, so their process fields remain `UNKNOWN` rather than
inventing one ambiguous subprocess duration. A process start failure before a
child exists likewise has no process duration. Whenever both durations are
present, the report only publishes a process duration no greater than the
total run duration.

The timing fields are written to `report.txt`, the canonical clipboard report,
and the local result/request evidence. Success, non-zero exit, invalid payload,
timeout, cancellation, transport failure, and handled exception outcomes all
retain the run timing fields. The live log adds only `Run started`, `Run
finished`, and `Duration` entries for the run; it does not emit per-event
timing noise.

## VIT-001R — Native OpenCode V2 permission guardrails

The project configuration is `.opencode/opencode.jsonc`, resolved through the
same `OPENCODE_CONFIG_DIR=.opencode` boundary used by `OpenCodeRunner`. The
effective OpenCode 2.0.32 configuration, rather than the JSON source alone, is
the authority and is inspected with `opencode debug config` and
`opencode debug agents`.

The built-in `build` agent retains ordinary repository development capabilities:
read, glob, grep, edit, test shell commands, Git status/diff/log inspection,
`git add`, and authorized local `git commit`. Its effective policy denies
external directories, `.opencode/service.json`, pushes, and destructive Git
operations including reset, clean, rebase, merge, checkout, switch, restore,
and commit amend. The `gota-worker` policy has no effective ASK barrier under
`--auto`: normal test/edit/status/diff/add/commit operations are allowed, while
destructive or remote Git operations, external directories, and the protected
service path are explicitly denied.

The existing `gota-auditor` and `gota-reviewer` policies remain read-only. The
auditor retains its deny-by-default shell policy and protected service path; the
reviewer retains read/glob/grep only and explicitly denies the protected service
path. This change does not alter Coordinator or SQLite authority, runtime
execution, task state, leases, or persisted evidence.

## Traceability

`TUI-001`–`TUI-010`, `GOTA-TUI-002`–`GOTA-TUI-007`, and `VIT-001R` map to the implementation modules and tests in
`tools/gota_tui/`, the `FLUJO-BHV-GOTA-TUI-001` and
`FLUJO-BHV-GOTA-TUI-002`, `FLUJO-BHV-GOTA-TUI-003`, and
`FLUJO-BHV-GOTA-TUI-004`, `FLUJO-BHV-GOTA-TUI-005`, and
`FLUJO-BHV-OPENCODE-PERMISSIONS-001`
behavior-catalog entries, and the production-TUI delivery commits.
Coordinator/Gota authority behavior remains covered by the existing
`FLUJO-BHV-GOTA-*` and `FLUJO-BHV-OPENCODE-RUNNER-001` entries.

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
