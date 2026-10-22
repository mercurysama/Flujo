"""Minimal Textual UI for menu, preview, live execution, history and reports."""

from __future__ import annotations

import asyncio
from pathlib import Path
from threading import Event
from typing import Sequence

from rich.text import Text
from textual.app import App, ComposeResult
from textual.containers import Vertical
from textual.widgets import Footer, Header, Label, ListItem, ListView, RichLog, Static

from .actions import ActionDefinition, ActionRegistry, ActionRegistryError
from .clipboard import ClipboardError, ClipboardReader, ClipboardWriter
from .durable import DurableRunStore
from .envelope import PromptEnvelope, PromptEnvelopeError
from .execution import ActionExecutionResult, ActionExecutor, PreparedAction, TUIConfig
from .prompt_library import PromptLibrary, PromptTemplateError
from .reporting import ReportManager


class GotaApp(App[None]):
    """The UI owns navigation only; Coordinator owns task truth."""

    TITLE = "Gota"
    SUB_TITLE = "Local Coordinator interface"

    CSS = """
    Screen {
        layout: vertical;
    }
    #screen-title {
        height: 2;
        padding: 0 1;
        text-style: bold;
    }
    #status {
        height: 2;
        padding: 0 1;
        color: $warning;
    }
    #action-list {
        height: 1fr;
        margin: 0 1;
        border: round $primary;
    }
    #prompt-view, #live-log {
        height: 1fr;
        margin: 0 1;
        border: round $secondary;
        scrollbar-size-horizontal: 0;
    }
    #report-view {
        height: 1fr;
        margin: 0 1;
        border: round $success;
        padding: 1;
        overflow-y: auto;
    }
    """

    BINDINGS = [
        ("c", "clipboard", "Clipboard"),
        ("h", "history", "History"),
        ("r", "copy_report", "Copy report"),
        ("o", "open_report", "Open report"),
        ("p", "open_prompt", "Open prompt"),
        ("enter", "accept", "Accept"),
        ("escape", "back", "Back/cancel"),
        ("q", "quit_requested", "Quit"),
    ]

    def __init__(
        self,
        *,
        registry: ActionRegistry,
        runs: DurableRunStore,
        prompts: PromptLibrary,
        config: TUIConfig,
        clipboard_reader: ClipboardReader,
        clipboard_writer: ClipboardWriter,
        initial_prompt: str | None = None,
        initial_action: str | None = None,
        initial_history: bool = False,
    ) -> None:
        super().__init__()
        self.registry = registry
        self.runs = runs
        self.prompts = prompts
        self.config = config
        self.clipboard_reader = clipboard_reader
        self.clipboard_writer = clipboard_writer
        self.initial_prompt = initial_prompt
        self.initial_action = initial_action
        self.initial_history = initial_history
        self._screen = "menu"
        self._prompt: str | None = None
        self._envelope: PromptEnvelope | None = None
        self._selected_action: ActionDefinition | None = None
        self._prepared: PreparedAction | None = None
        self._cancel_event = Event()
        self._execution_task: asyncio.Task[None] | None = None
        self._result: ActionExecutionResult | None = None
        self._historical_report_run_id: str | None = None
        self._confirming = False
        self._quit_after_cancel = False
        self._history: list[dict[str, object]] = []
        self._history_index = 0

    def compose(self) -> ComposeResult:
        yield Header()
        with Vertical():
            yield Static("GOTA", id="screen-title")
            yield Static("", id="status")
            yield ListView(id="action-list")
            yield RichLog(id="prompt-view", wrap=True, markup=False, auto_scroll=False)
            yield RichLog(id="live-log", wrap=True, markup=False, auto_scroll=True)
            yield Static("", id="report-view", markup=False)
        yield Footer()

    def on_mount(self) -> None:
        self._populate_actions()
        if self.initial_history:
            self._show_history()
        elif self.initial_prompt is not None:
            self._show_prompt(self.initial_prompt, self.initial_action)
        else:
            self._show_menu()

    def _populate_actions(self) -> None:
        action_list = self.query_one("#action-list", ListView)
        action_list.clear()
        for action in self.registry:
            action_list.append(ListItem(Label(f"{action.label}  [dim]{action.id}[/dim]")))

    def _show_menu(self) -> None:
        self._screen = "menu"
        self._confirming = False
        self._prompt = None
        self._envelope = None
        self._prepared = None
        self._result = None
        self._historical_report_run_id = None
        self._set_visible("action-list")
        self._set_hidden("prompt-view", "live-log", "report-view")
        self.query_one("#screen-title", Static).update("GOTA  ·  Main menu")
        self.query_one("#status", Static).update(
            "Select an action. C loads clipboard; Enter accepts; H opens history; Q quits."
        )
        self._populate_actions()
        if self._selected_action is None and len(self.registry) > 0:
            self._select_action(self.registry.actions[0].id)
        elif self._selected_action is not None:
            self._select_action(self._selected_action.id)

    def _show_prompt(self, prompt: str, action_id: str | None = None) -> None:
        try:
            envelope = PromptEnvelope.parse(prompt)
        except PromptEnvelopeError as error:
            self._prompt = None
            self._envelope = None
            self._show_menu()
            self._set_status(f"Clipboard diagnostic: {error}")
            return
        self._prompt = prompt
        self._envelope = envelope
        self._screen = "preview"
        self._set_visible("action-list", "prompt-view")
        self._set_hidden("live-log", "report-view")
        prompt_view = self.query_one("#prompt-view", RichLog)
        prompt_view.clear()
        prompt_view.write(Text(prompt))
        self.query_one("#screen-title", Static).update(
            "GOTA  ·  Prompt preview  ·  scroll independently"
        )
        self._set_status(
            "Structured envelope: yes" if envelope.structured else
            "Plain text: read-only actions only"
        )
        if action_id is not None:
            self._select_action(action_id)

    def _show_history(self) -> None:
        self.runs.recover_interrupted()
        self._history = [dict(record) for record in self.runs.history_records()]
        self._history_index = 0
        self._screen = "history"
        self._set_visible("action-list")
        self._set_hidden("prompt-view", "live-log", "report-view")
        action_list = self.query_one("#action-list", ListView)
        action_list.clear()
        for record in self._history:
            action = str(record.get("action_id") or "unknown")
            state = str(record.get("ui_state") or "UNKNOWN")
            run_id = str(record.get("run_id") or "unknown")
            sha = str(record.get("prompt_sha256") or "UNKNOWN")[:12]
            action_list.append(ListItem(Label(f"{run_id}  {action}  {state}  sha={sha}")))
        self.query_one("#screen-title", Static).update("GOTA  ·  History")
        self._render_history_detail()

    def _render_history_detail(self) -> None:
        if not self._history:
            self._set_status("No durable TUI runs found. Escape returns to the menu.")
            return
        record = self._history[self._history_index]
        self._set_status(
            "DATE={date}  RUN_ID={run}  ACTION={action}  STATE={state}  TASK_ID={task}  "
            "PROMPT_SHA={sha}  VERDICT={verdict}  · O report · P prompt · C copy".format(
                date=record.get("updated_at", "UNKNOWN"),
                run=record.get("run_id", "UNKNOWN"),
                action=record.get("action_id", "UNKNOWN"),
                state=record.get("coordinator_state") or record.get("ui_state", "UNKNOWN"),
                task=record.get("task_id", "UNKNOWN"),
                sha=record.get("prompt_sha256", "UNKNOWN"),
                verdict=record.get("verdict", "UNKNOWN"),
            )
        )

    def _show_running(self) -> None:
        self._screen = "running"
        self._set_visible("live-log")
        self._set_hidden("action-list", "prompt-view", "report-view")
        self.query_one("#screen-title", Static).update(
            "GOTA  ·  Running  ·  Esc cancels UI process request"
        )
        self.query_one("#live-log", RichLog).clear()
        self._set_status("Coordinator state is authoritative; exit=0 is not DONE.")

    def _show_final(self, result: ActionExecutionResult) -> None:
        self._screen = "final"
        self._result = result
        self._historical_report_run_id = None
        # Visual clear: remove the log panel contents/view; no shell clear is
        # ever launched. The durable live.log remains available in history.
        self.query_one("#live-log", RichLog).clear()
        self._set_visible("report-view")
        self._set_hidden("action-list", "prompt-view", "live-log")
        self.query_one("#screen-title", Static).update("GOTA  ·  Final report")
        self.query_one("#report-view", Static).update(Text(result.report))
        copy_status = result.clipboard_status
        if result.clipboard_error:
            copy_status += f" ({result.clipboard_error})"
        self._set_status(
            f"VERDICT={result.verdict}  COORDINATOR_STATE={result.coordinator_state or 'UNKNOWN'}  "
            f"CLIPBOARD_COPY={copy_status}  · C copy · H history · Enter menu · Q quit"
        )

    def _set_visible(self, *ids: str) -> None:
        for widget_id in ids:
            self.query_one(f"#{widget_id}").display = True

    def _set_hidden(self, *ids: str) -> None:
        for widget_id in ids:
            self.query_one(f"#{widget_id}").display = False

    def _set_status(self, message: str) -> None:
        self.query_one("#status", Static).update(message)

    def _select_action(self, action_id: str) -> None:
        try:
            action = self.registry.get(action_id)
        except ActionRegistryError:
            self._set_status(f"Unknown action: {action_id}")
            return
        if self._selected_action is None or self._selected_action.id != action_id:
            self._confirming = False
        self._selected_action = action
        action_list = self.query_one("#action-list", ListView)
        for index, candidate in enumerate(self.registry.actions):
            if candidate.id == action_id:
                action_list.index = index
                break
        self._set_status(
            f"Selected: {action.label} — {action.description}"
            + ("  · confirmation required" if action.requires_confirmation else "")
        )

    def on_list_view_selected(self, event: ListView.Selected) -> None:
        if self._screen == "menu" or self._screen == "preview":
            index = event.list_view.index
            if index is not None and 0 <= index < len(self.registry.actions):
                if (
                    self._selected_action is None
                    or self._selected_action.id != self.registry.actions[index].id
                ):
                    self._confirming = False
                self._selected_action = self.registry.actions[index]
                self._set_status(
                    f"Selected: {self._selected_action.label} — {self._selected_action.description}"
                )
        elif self._screen == "history":
            index = event.list_view.index
            if index is not None and 0 <= index < len(self._history):
                self._history_index = index
                self._render_history_detail()

    def action_clipboard(self) -> None:
        if self._screen in {"final", "history"}:
            self.action_copy_report()
            return
        try:
            prompt = self.clipboard_reader.read()
        except ClipboardError as error:
            self._set_status(f"Clipboard diagnostic: {error}")
            return
        self._show_prompt(prompt)

    def action_history(self) -> None:
        self._show_history()

    def action_accept(self) -> None:
        if self._screen == "history":
            self._show_menu()
            return
        if self._screen == "final":
            if self._historical_report_run_id is not None:
                self._show_history()
            else:
                self._show_menu()
            return
        if self._screen == "running":
            self._set_status("Already running; Escape requests controlled cancellation.")
            return
        if self._selected_action is None:
            self._set_status("Select a registered action first.")
            return
        if self._selected_action.id == "clipboard-prompt":
            self.action_clipboard()
            return
        if self._selected_action.requires_prompt and self._envelope is None:
            self._set_status("This action requires a clipboard prompt. Press C first.")
            return
        if self._selected_action.requires_confirmation and not self._confirming:
            self._confirming = True
            self._set_status(
                f"CONFIRM {self._selected_action.label}? Enter confirms; Escape cancels."
            )
            return
        self._confirming = False
        self._start_execution()

    def _start_execution(self) -> None:
        assert self._selected_action is not None
        envelope = self._envelope or PromptEnvelope("", "", False, {})
        try:
            executor = ActionExecutor(
                config=self.config,
                runs=self.runs,
                prompts=self.prompts,
                clipboard_writer=self.clipboard_writer,
                output_sink=self._live_sink,
            )
            prepared = executor.prepare(self._selected_action, envelope)
        except Exception as error:
            # This screen-level diagnostic is deliberately before any child
            # process. The broad final arm keeps injected filesystem errors visible.
            self._set_status(f"Action blocked: {type(error).__name__}: {error}")
            return
        self._prepared = prepared
        self._cancel_event.clear()
        self._show_running()
        self._execution_task = asyncio.create_task(self._execute_prepared(executor, prepared))

    async def _execute_prepared(
        self, executor: ActionExecutor, prepared: PreparedAction
    ) -> None:
        try:
            result = await asyncio.to_thread(
                executor.execute,
                prepared,
                cancel_event=self._cancel_event,
            )
        except Exception as error:
            self._set_status(f"Execution boundary error: {type(error).__name__}: {error}")
            self._show_menu()
            return
        self._show_final(result)
        if self._quit_after_cancel:
            self.exit()

    def _live_sink(self, entry: str) -> None:
        try:
            self.call_from_thread(self._append_live, entry)
        except RuntimeError:
            return

    def _append_live(self, entry: str) -> None:
        if self._screen == "running":
            self.query_one("#live-log", RichLog).write(Text(entry.rstrip("\n")))

    def action_copy_report(self) -> None:
        if self._screen == "final":
            run_id = (
                self._result.run_id
                if self._result is not None
                else self._historical_report_run_id
            )
            if run_id is not None:
                try:
                    backend = ReportManager(self.runs, self.clipboard_writer).copy_existing(
                        run_id
                    )
                    self._set_status(f"Report copied with {backend}. C/R retries are safe.")
                except (ClipboardError, OSError) as error:
                    self._set_status(f"Clipboard warning; report retained: {error}")
            return
        if self._screen == "history" and self._history:
            run_id = str(self._history[self._history_index].get("run_id"))
            try:
                backend = ReportManager(self.runs, self.clipboard_writer).copy_existing(run_id)
                self._set_status(f"History report copied with {backend}.")
            except (ClipboardError, OSError) as error:
                self._set_status(f"Clipboard warning; report retained: {error}")

    def action_open_report(self) -> None:
        if self._screen != "history" or not self._history:
            return
        run_id = str(self._history[self._history_index].get("run_id"))
        try:
            report = self.runs.read_report(run_id)
        except Exception as error:
            self._set_status(f"Report unavailable: {error}")
            return
        self._screen = "final"
        self._result = None
        self._historical_report_run_id = run_id
        self._set_visible("report-view")
        self._set_hidden("action-list", "prompt-view", "live-log")
        self.query_one("#screen-title", Static).update("GOTA  ·  Historical report")
        self.query_one("#report-view", Static).update(Text(report))
        self._set_status("Historical report is durable. C copies; Escape returns to history.")

    def action_open_prompt(self) -> None:
        if self._screen != "history" or not self._history:
            return
        run_id = str(self._history[self._history_index].get("run_id"))
        try:
            prompt = self.runs.read_prompt(run_id)
        except Exception as error:
            self._set_status(f"Prompt unavailable: {error}")
            return
        self._screen = "historical-prompt"
        self._set_visible("prompt-view")
        self._set_hidden("action-list", "live-log", "report-view")
        self.query_one("#prompt-view", RichLog).clear()
        self.query_one("#prompt-view", RichLog).write(Text(prompt))
        self.query_one("#screen-title", Static).update("GOTA  ·  Historical prompt")
        self._set_status("Prompt is durable. Escape returns to history.")

    def action_back(self) -> None:
        if self._screen == "running":
            self._cancel_event.set()
            self._set_status("Cancellation requested; waiting for controlled process cleanup.")
            return
        if self._screen == "historical-prompt":
            self._show_history()
            return
        if self._screen == "final":
            if self._historical_report_run_id is not None:
                self._show_history()
            else:
                self._show_menu()
            return
        if self._screen in {"preview", "history"}:
            self._show_menu()

    def action_quit_requested(self) -> None:
        if self._screen == "running":
            self._cancel_event.set()
            self._quit_after_cancel = True
            self._set_status("Quit requested; waiting for controlled process cleanup.")
            return
        self.exit()
