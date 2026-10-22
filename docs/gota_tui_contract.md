# Production Gota TUI contract

## Scope

This contract defines the local Textual terminal interface in
`tools/gota_tui/`. It is an interface and application facade over the public
Coordinator/Gota boundaries; it is not a second task state machine.

## TUI-001 — Local durable run record

After prompt confirmation and before any Worker, OpenCode, or child process,
the TUI writes a complete UTF-8 prompt, SHA-256, request metadata, and an
empty live log below the XDG state root. Writes use replacement files and
flushes where the platform permits. A run has a stable UI `run_id`; the
Coordinator-created run identity is recorded separately when available.

## TUI-002 — Clipboard data boundary

Clipboard input and output use injectable reader/writer abstractions. System
commands receive argv lists and clipboard bytes as data. No clipboard content
is evaluated, sourced, passed to a shell, or used to select an executable.
Missing backends and copy failures remain visible diagnostics and never delete
the durable report.

## TUI-003 — Versioned prompt envelope

Plain text is previewable and may be used only by read-only actions. A
mutable Gota action requires a versioned TOML frontmatter envelope containing
the Coordinator authority and scope fields it needs. Missing or invalid fields
fail closed; the TUI does not derive paths, behavior identity, base SHA,
acceptance criteria, or task identity from prose or the current Git state.

## TUI-004 — Action and prompt registries

Visible actions and their mutability, confirmation, agent, model, backend, and
prompt-template metadata are declarative TOML. Only registered backends can
execute. Prompt templates and the clipboard assignment are persisted and
combined as distinct, auditable data.

## TUI-005 — Coordinator authority

Mutable execution composes the public Coordinator/Gota APIs in this order:
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

## TUI-008 — Launcher

The versioned launcher supports `gota`, `gota clipboard`, and `gota history`,
including `--help` and `--version`. Mutable clipboard actions always show
preview and confirmation; `--action` never suppresses confirmation.

## Traceability

`TUI-001`–`TUI-008` map to the implementation modules and tests in
`tools/gota_tui/`, the `FLUJO-BHV-GOTA-TUI-001` behavior-catalog entry, and
the cohesive `feat: add production Gota TUI` commit. Coordinator/Gota
authority behavior remains covered by the existing
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
