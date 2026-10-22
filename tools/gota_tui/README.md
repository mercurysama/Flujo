# Production Gota TUI

`gota_tui` is the local Textual terminal interface for Flujo Coordinator/Gota.
It replaces long shell invocations with a small menu, clipboard preview, live
logs, durable reports, and recoverable history. Historical prototypes remain
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
gota clipboard --action execute-task
gota history
gota doctor
gota --self-check
```

`--action` only preselects an action. Mutable actions always show the preview
and an explicit confirmation screen. `C` retries clipboard input, `H` opens
history, `R`/`C` copies an available report, `Enter` accepts or returns,
`Escape` cancels/returns, and `Q` quits. A cancellation during a child process
requests controlled termination; it does not mark a Coordinator task
`CANCELLED`.

## Actions

Actions live in `actions.toml` and are validated by `ActionRegistry`. The
initial registry contains Execute task, Execute prompt from clipboard, Review
existing Gota run, Read-only audit, Revalidate production, Run tests,
Diagnostics, Recovery, View status, and History. Backends are an allowlist;
there is no arbitrary shell action.

Mutable Execute task requires a version 1 envelope. Review requires a durable
Coordinator `REVIEW` frontier and never gives the Reviewer mutation access.
Read-only actions use fixed argv or the existing read-only Git/Coordinator
APIs. The configured default is `openai/gpt-5.6-luna#max`, overridable with
`--model`, `--variant`, `GOTA_TUI_MODEL`, and `GOTA_TUI_VARIANT`.

## Clipboard and security

Input backends are tried in order: `wl-paste`, `xclip`, then `xsel`. Output
uses `wl-copy`, `xclip`, then `xsel`. Clipboard text is UTF-8 data passed as
argv or stdin; it is never evaluated, sourced, or run as shell. Missing
backends and copy errors leave the UI/report functional.

OpenCode execution reuses
`tools/coordinator/src/flow_coordinator/opencode_runner.py`, including
`--standalone`, canonical agents, provider/model#variant, bounded cleanup,
Linux containment, and protocol validation. The optional observer only streams
captured stdout/stderr to the TUI; it does not change Coordinator authority.

## Prompt library and envelope

Templates are versioned TOML files under `prompts/`. A template is combined
with the clipboard assignment using explicit `TEMPLATE_BEGIN` and
`ASSIGNMENT_BEGIN` markers. Both the original prompt and template/version
metadata are recorded in the local run request.

Plain text is always previewable and is allowed for read-only actions only.
Mutable actions require all authority/scope values; the TUI does not invent
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
  runs/<ui-run-id>/result.json
  runs/<ui-run-id>/report.txt
  history.jsonl
```

The prompt, digest, request, and live log are flushed before an execution
child can start. History reload tolerates a truncated JSONL tail. An incomplete
local record is marked `UI_INTERRUPTED` only in TUI state; any durable
Coordinator state is displayed separately through public read APIs. Opening
history never transitions, cancels, accepts, or rewrites a Coordinator task.

The final report is compact and includes `RUN_ID`, `ACTION`, `TASK_ID`,
`CONTEXT_ID`, model/variant, OpenCode version, repository/base/commit,
Coordinator/Worker/Review state, tests, diff check, prompt SHA, report/log
paths, clipboard status, findings, and verdict. Full output remains in
`live.log`. The report is persisted before copy is attempted, and a clipboard
failure never removes it.

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
