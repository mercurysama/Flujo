# Production Gota TUI

`gota_tui` is the local Textual terminal interface for Flujo Coordinator/Gota.
It replaces long shell invocations with a small menu, direct clipboard prompt
execution, live logs, durable reports, and recoverable history. Historical prototypes remain
outside this checkout and are not imported by the implementation.

## Installation

The historical v4 implementation uses Textual. The production launcher keeps
that framework and requires a user-owned environment; it never installs system
packages or uses `sudo`.

```sh
DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
VENV="$DATA_HOME/flow-coordinator/gota-tui-venv"
python3 -m venv "$VENV"
"$VENV/bin/python" -m pip install \
  -r tools/gota_tui/requirements.txt
```

The system Python is used only to bootstrap the venv. The installed launcher
always uses `$DATA_HOME/flow-coordinator/gota-tui-venv/bin/python`, even when
the installer itself is invoked by a different Python:

```sh
"$VENV/bin/python" tools/gota_tui/install_launcher.py --force
```

It writes only `~/.local/bin/gota`, refuses to replace an existing file unless
`--force` is supplied, and reports when that directory is not in `PATH`.

If `~/.local/bin` is not in `PATH`, add it in the user's environment outside
this project; the launcher does not edit shell startup files. `gota doctor` or
`gota --self-check` verifies the actual Python runtime, venv, Textual, Rich,
`GotaApp`, state root, registries, and clipboard backends. Clipboard warnings
are non-fatal. The installed launcher invokes the versioned
`tools/gota_tui/gota.py` target with the dedicated venv, so no machine-specific
path is committed.

## Usage

```sh
gota
gota clipboard
gota history
gota doctor
gota --self-check
```

`gota clipboard` reads and executes the current clipboard prompt immediately.
From the main menu, `Enter` selects the selected action; selecting `Execute
prompt from clipboard` is the confirmation and does not open a second selector
or confirmation screen. `Execute task`, `Review existing Gota run`, and
`Read-only OpenCode audit` reads the clipboard when selected and runs on that
same `Enter`; it does not require `C` or a second confirmation. `C` always
means **Run clipboard prompt** and invokes the direct `clipboard-prompt`
action with `build`. `H` opens history, `R` copies an available report, `Escape` cancels/returns,
and `Q` quits. A cancellation during a child process requests controlled
termination; it does not mark a Coordinator task `CANCELLED`.

## Actions

Actions live in `actions.toml` and are validated by `ActionRegistry`. The
initial registry contains Execute task, Execute prompt from clipboard, Review
existing Gota run, Read-only Git audit, Read-only OpenCode audit, Revalidate
production, Run tests, Diagnostics, Recovery, View status, and History.
Backends are an allowlist; there is no arbitrary shell action.

Mutable Execute task requires a version 1 envelope. Review requires a durable
Coordinator `REVIEW` frontier and never gives the Reviewer mutation access.
Read-only Git audit uses the local Git adapter without a model. Read-only
OpenCode audit validates the canonical `gota-auditor` policy, reads its prompt
from durable `prompt.txt`, and reuses the existing shell-free OpenCodeRunner.
It never creates Coordinator task state and fails when Git changes across the
child. The configured OpenCode default is model `openai/gpt-5.6-luna` with
variant `max`, overridable with `--model`, `--variant`, `GOTA_TUI_MODEL`, and
`GOTA_TUI_VARIANT`. Semantic role and agent configuration overrides use
`--role`, `--agent`, `GOTA_TUI_ROLE`, and `GOTA_TUI_AGENT`; prompt headers take
precedence over these values.

## Clipboard and security

Input backends are tried in order: `wl-paste`, `xclip`, then `xsel`. Output
uses `wl-copy`, `xclip`, then `xsel`. Clipboard text is UTF-8 data passed as
argv or stdin; it is never evaluated, sourced, or run as shell. Missing
backends and copy errors leave the UI/report functional.

Direct and formal OpenCode execution reuse
`tools/coordinator/src/flow_coordinator/opencode_runner.py`, including
`--standalone`, canonical agents, OpenCode 2.1.4 `provider/model#variant`
selectors, bounded cleanup,
Linux containment, and shell-free argv construction. Formal Gota actions retain
protocol validation. The direct clipboard action treats a zero-exit raw
response as a direct result and does not create Coordinator authority. The
optional observer streams captured stdout/stderr to the TUI.

### Per-run OpenCode routing

A prompt may begin with a contiguous machine-readable header. Only these lines
at the very beginning of the prompt are configuration; identical text later in
the assignment remains ordinary prompt data:

```text
GOTA_MODEL=openai/gpt-5.6-sol
GOTA_VARIANT=low
GOTA_ROLE=Reviewer of the requested change
GOTA_AGENT=build

Implement the assignment.
```

The header is removed from the effective prompt sent to OpenCode, while the
original prompt and its digest remain in durable state. `GOTA_ROLE` is explicit
context rather than an OpenCode flag and is rendered as `ROLE` followed by
`TASK`. Values are resolved per run in this order: initial prompt header,
configuration/action defaults, then the legacy defaults. The variant is joined
to the `--model` value as `provider/model#variant`; no separate `--variant` flag
is sent to OpenCode. Without a variant, `--model` receives only `provider/model`.
Invalid values fail before the child starts. The effective model, variant, role,
agent, and their source are recorded separately in `GOTA_REPORT_V1`.

## Prompt library and envelope

Templates are versioned TOML files under `prompts/`. A template is combined
with the clipboard assignment using explicit `TEMPLATE_BEGIN` and
`ASSIGNMENT_BEGIN` markers. Both the original prompt and template/version
metadata are recorded in the local run request.

Plain text is always previewable and is allowed for read-only actions and the
direct clipboard action. Mutable actions require all authority/scope values; the TUI does not invent
`allowed_paths`, behavior IDs, base SHAs, task identity, or acceptance
criteria.

Example:

```toml
++
version = 1
task_id = "task-example"
title = "Example task"
project_id = "project-example"
repository_id = "repo-example"
workspace = "/absolute/path/to/repository"
branch = "feature/example"
base_sha = "0123456789abcdef0123456789abcdef01234567"
context_id = "context-example"
allowed_paths = ["src/example.py"]
protected_paths = [".opencode/agents/gota-reviewer.md"]
acceptance_criteria = ["The focused tests pass"]
commit_message = "feat: complete example"
attempt = 1
template_id = "gota-worker-v1"
++
Implement the assignment here.
```

Coordinator creates the operational run ID after validating this envelope;
that ID is stored separately from the stable local TUI run ID.

## Durable state and recovery

Default state is:

```text
${XDG_STATE_HOME:-~/.local/state}/flow-coordinator/tui/
  runs/<ui-run-id>/request.json
  runs/<ui-run-id>/prompt.txt
  runs/<ui-run-id>/prompt.sha256
  runs/<ui-run-id>/live.log
  runs/<ui-run-id>/opencode-output.txt
  runs/<ui-run-id>/result.json
  runs/<ui-run-id>/report.txt
  history.jsonl
```

The prompt, digest, request, and live log are flushed before an execution
child can start. History reload tolerates a truncated JSONL tail. An incomplete
local record is marked `UI_INTERRUPTED` only in TUI state; any durable
Coordinator state is displayed separately through public read APIs. Opening
history never transitions, cancels, accepts, or rewrites a Coordinator task.

The final report includes a machine-readable `GOTA_REPORT_V1` header with `RUN_ID`, `ACTION`, `TASK_ID`,
`CONTEXT_ID`, model/variant, OpenCode version/agent, repository/base/commit,
Coordinator/Worker/Review state, tests, diff check, prompt SHA, report/log and
associated-output paths, read-only policy, mutation guard, clipboard status,
findings, and verdict. Complete observed output with local credential values
redacted remains in `live.log` and, for both direct clipboard OpenCode and the
OpenCode audit, in `opencode-output.txt`. Direct reports expose the process
status/exit code, embedded-report fields, and `RESULT_CONSISTENCY`; a non-zero
process remains a failure even when an embedded report says PASS. When
`opencode-output.txt` contains a complete `STDOUT_BEGIN`/`STDOUT_END` block,
the report automatically appends its complete, untruncated stdout between
`GOTA_OPENCODE_STDOUT_BEGIN` and `GOTA_OPENCODE_STDOUT_END`, with
`OUTPUT_EMBED_STATUS`, `OUTPUT_EMBED_SOURCE`, and `OUTPUT_EMBED_BYTES` fields.
Coordinator embedded-report evidence and this stdout transport are distinct;
stderr is not appended and remains in `opencode-output.txt` for diagnostics.
Manual `sed`/`grep` recovery should normally no longer be necessary. The
report also includes `STARTED_AT`, `FINISHED_AT`, `DURATION_MS`, and
`DURATION_HUMAN`; the duration is measured with a monotonic runtime clock from
`ActionExecutor.execute()` entry to the backend outcome immediately before
reporting. Direct and read-only OpenCode actions additionally expose
`PROCESS_DURATION_MS` and `PROCESS_DURATION_HUMAN` when the single runner
subprocess boundary is available; formal multi-phase actions leave those
fields `UNKNOWN`. `TIMESTAMP` remains the local durable run-record creation
timestamp. The report is persisted before copy is attempted, and a clipboard
failure never removes it; later user-triggered report copies do not change the
recorded duration.

## Adding an action or template

1. Add a fully specified entry to `actions.toml` using an existing allowlisted
   backend; do not add an arbitrary command field.
2. Add or update a versioned TOML file in `prompts/` when common rules are
   needed.
3. Extend the corresponding fixed backend in `execution.py` or the public
   Coordinator facade, with tests for mutability, confirmation, and failure
   ordering.
4. Update `docs/gota_tui_contract.md` and the behavior-catalog evidence.

The TUI is UI state and a controller of permitted actions. Coordinator/SQLite
remain the operational authority, including Worker/Reviewer roles, leases,
fencing, decisions, and task states.
