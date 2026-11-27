from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime
from itertools import cycle

from textual.app import App, ComposeResult
from textual.containers import Horizontal
from textual.widgets import Button, Footer, Label, RichLog, Static


@dataclass(frozen=True)
class DemoEvent:
    actor: str
    message: str


class StatusPanel(Static):
    """Panel superior compacto: estado resumido y confiable."""

    def update_state(
        self,
        *,
        project: str,
        task: str,
        state: str,
        phase: str,
        elapsed: str,
        luna: str,
        qwen: str,
        explore: str,
        git_state: str,
        gpu: str,
        queue: int,
        errors: int,
    ) -> None:
        self.update(
            f"[b]🌧️ GOTA[/b]   {project} · {task}   {state} · {phase}   {elapsed}\n"
            f"🧠 Luna {luna}  │  🖥 Qwen {qwen}  │  🔎 Explore {explore}\n"
            f"Git: {git_state}  │  GPU: {gpu}  │  Queue: {queue}  │  Errors: {errors}"
        )


class GotaTUI(App):
    """Prototipo TUI-001/TUI-002: visor read-only con actividad simulada."""

    TITLE = "Gota TUI"
    SUB_TITLE = "Prototipo de supervisión"

    CSS = """
    Screen {
        layout: vertical;
    }

    #status {
        height: 5;
        border: round $primary;
        padding: 0 1;
        margin: 0 1;
    }

    #activity_title {
        height: 1;
        margin: 0 2;
    }

    #log {
        height: 1fr;
        border: round $secondary;
        margin: 0 1;
        padding: 0 1;
    }

    #controls {
        height: 3;
        margin: 0 1;
        align: right middle;
    }

    #exit_button {
        width: 18;
    }
    """

    BINDINGS = [
        ("q", "quit_tui", "Salir de TUI"),
        ("pageup", "log_page_up", "Log ↑"),
        ("pagedown", "log_page_down", "Log ↓"),
    ]

    def __init__(self) -> None:
        super().__init__()
        self._seconds = 0
        self._event_index = 0

        self._events = [
            DemoEvent("GOTA", "tarea RUNNING"),
            DemoEvent("LUNA", "sesión iniciada; preparando delegación"),
            DemoEvent("GOTA", "Luna → SLEEPING"),
            DemoEvent("QWEN", "iniciando ollama/qwen2.5-coder:3b"),
            DemoEvent("QWEN", "GPU CUDA0; analizando archivos"),
            DemoEvent("QWEN", "resultado local preparado"),
            DemoEvent("GOTA", "result_received"),
            DemoEvent("GOTA", "reanudando sesión de Luna"),
            DemoEvent("LUNA", "procesando resultado recibido"),
            DemoEvent("REVIEW", "esperando siguiente frontera segura"),
        ]

        self._agent_states = cycle(
            [
                ("SLEEP", "RUNNING", "DONE"),
                ("SLEEP", "RUNNING", "DONE"),
                ("WAKE", "DONE", "DONE"),
                ("RUNNING", "IDLE", "DONE"),
            ]
        )
        self._current_agents = ("SLEEP", "RUNNING", "DONE")

    def compose(self) -> ComposeResult:
        yield StatusPanel(id="status")
        yield Label("ACTIVIDAD / CONSOLA", id="activity_title")
        yield RichLog(id="log", wrap=True, highlight=True, markup=True)
        with Horizontal(id="controls"):
            yield Button("Salir de TUI", id="exit_button", variant="error")
        yield Footer()

    def on_mount(self) -> None:
        self._refresh_status()
        log = self.query_one("#log", RichLog)
        log.write("[dim]Prototipo read-only. No modifica Gota, Git ni OpenCode.[/dim]")
        log.write("[dim]«Salir de TUI» termina sólo esta interfaz y devuelve el control a la terminal.[/dim]")
        self.set_interval(1.0, self._tick)

    def _tick(self) -> None:
        self._seconds += 1

        if self._seconds % 2 == 0:
            event = self._events[self._event_index % len(self._events)]
            self._event_index += 1
            now = datetime.now().strftime("%H:%M:%S")
            self.query_one("#log", RichLog).write(
                f"[dim]{now}[/dim]  [b][{event.actor}][/b]  {event.message}"
            )

        if self._seconds % 6 == 0:
            self._current_agents = next(self._agent_states)

        self._refresh_status()

    def _refresh_status(self) -> None:
        minutes, seconds = divmod(self._seconds, 60)
        elapsed = f"{minutes:02d}:{seconds:02d}"
        luna, qwen, explore = self._current_agents

        self.query_one("#status", StatusPanel).update_state(
            project="Flujo",
            task="TUI-DEMO-001",
            state="🛠 RUNNING",
            phase="OBSERVING",
            elapsed=elapsed,
            luna=luna,
            qwen=qwen,
            explore=explore,
            git_state="sin cambios",
            gpu="CUDA0",
            queue=1,
            errors=0,
        )

    def action_quit_tui(self) -> None:
        """Sale sólo de la TUI; no cierra la terminal ni cambia el estado de Gota."""
        self.exit(message="TUI finalizada")

    def action_log_page_up(self) -> None:
        self.query_one("#log", RichLog).action_page_up()

    def action_log_page_down(self) -> None:
        self.query_one("#log", RichLog).action_page_down()

    def on_button_pressed(self, event: Button.Pressed) -> None:
        if event.button.id == "exit_button":
            self.action_quit_tui()


if __name__ == "__main__":
    GotaTUI().run()
