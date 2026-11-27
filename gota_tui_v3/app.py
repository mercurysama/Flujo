from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime
from itertools import cycle
from pathlib import Path
import subprocess

from textual.app import App, ComposeResult
from textual.containers import Horizontal
from textual.widgets import Button, Footer, Label, ProgressBar, RichLog, Static


@dataclass(frozen=True)
class DemoStep:
    actor: str
    action: str
    file: str
    progress: int


class HeaderLine(Static):
    pass


class DetailLine(Static):
    pass


class TelemetryLine(Static):
    pass


class GotaTUI(App):
    """Gota TUI v3: visor compacto con barra de progreso real de interfaz."""

    TITLE = "Gota TUI"
    SUB_TITLE = "Supervisor experimental"

    CSS = """
    Screen {
        layout: vertical;
    }

    #status_box {
        height: 7;
        border: round $primary;
        margin: 0 1;
        padding: 0 1;
    }

    #header_line,
    #detail_line,
    #file_line,
    #telemetry_line {
        height: 1;
    }

    #task_progress {
        height: 1;
        margin: 0 0;
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
        scrollbar-size-horizontal: 0;
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
        ("home", "log_home", "Inicio"),
        ("end", "log_end", "Final"),
    ]

    def __init__(self) -> None:
        super().__init__()
        self._seconds = 0
        self._errors = 0
        self._gpu = {
            "name": "NVIDIA",
            "temp": "—",
            "util": "—",
            "mem": "—",
        }

        self._steps = cycle(
            [
                DemoStep(
                    "LUNA",
                    "preparando plan",
                    "tools/coordinator/src/flow_coordinator/coordinator.py",
                    8,
                ),
                DemoStep(
                    "QWEN",
                    "leyendo implementación",
                    "tools/coordinator/src/flow_coordinator/store.py",
                    24,
                ),
                DemoStep(
                    "QWEN",
                    "contrastando persistencia",
                    "tools/coordinator/tests/test_gota_persistence.py",
                    41,
                ),
                DemoStep(
                    "EXPLORE",
                    "localizando frontera de review",
                    "tools/coordinator/src/flow_coordinator/gota_review_entry.py",
                    57,
                ),
                DemoStep(
                    "QWEN",
                    "revisando decisiones",
                    "tools/coordinator/src/flow_coordinator/gota_decision_application.py",
                    72,
                ),
                DemoStep(
                    "LUNA",
                    "integrando resultados",
                    "tools/coordinator/src/flow_coordinator/decision_policy.py",
                    88,
                ),
                DemoStep(
                    "REVIEW",
                    "verificando evidencia",
                    "tools/coordinator/tests/test_gota_decision_application.py",
                    100,
                ),
            ]
        )
        self._step = next(self._steps)

    def compose(self) -> ComposeResult:
        with Static(id="status_box"):
            yield HeaderLine(id="header_line")
            yield DetailLine(id="detail_line")
            yield DetailLine(id="file_line")
            yield ProgressBar(total=100, show_eta=False, id="task_progress")
            yield TelemetryLine(id="telemetry_line")

        yield Label("ACTIVIDAD / CONSOLA", id="activity_title")
        yield RichLog(
            id="log",
            wrap=True,
            highlight=True,
            markup=True,
            auto_scroll=True,
            max_lines=3000,
        )

        with Horizontal(id="controls"):
            yield Button("Salir de TUI", id="exit_button", variant="error")

        yield Footer()

    def on_mount(self) -> None:
        log = self.query_one("#log", RichLog)
        log.write("[dim]Gota TUI v3 — actividad de agentes/archivos simulada; telemetría NVIDIA real.[/dim]")
        log.write("[dim]La barra representa el progreso de la tarea actual, no el porcentaje leído de un archivo.[/dim]")
        log.write("[dim]«Salir de TUI» termina sólo esta interfaz y devuelve el control a la terminal.[/dim]")
        log.write("[dim]Pantalla completa: usa F11 en tu emulador de terminal.[/dim]")

        self._read_gpu()
        self._refresh_status()
        self.set_interval(1.0, self._tick)
        self.set_interval(2.0, self._read_gpu)

    def _tick(self) -> None:
        self._seconds += 1

        if self._seconds % 4 == 0:
            self._step = next(self._steps)
            now = datetime.now().strftime("%H:%M:%S")
            self.query_one("#log", RichLog).write(
                f"[green]{now}[/green]  [b][{self._step.actor}][/b]  {self._step.action}\n"
                f"          [cyan]{self._step.file}[/cyan]\n"
                f"          [dim]Progreso de tarea: {self._step.progress}%[/dim]"
            )

        self._refresh_status()

    def _read_gpu(self) -> None:
        try:
            result = subprocess.run(
                [
                    "nvidia-smi",
                    "--query-gpu=name,temperature.gpu,utilization.gpu,memory.used,memory.total",
                    "--format=csv,noheader,nounits",
                ],
                check=True,
                capture_output=True,
                text=True,
                timeout=1.5,
            )
            line = result.stdout.strip().splitlines()[0]
            name, temp, util, used, total = [part.strip() for part in line.split(",", 4)]
            self._gpu = {
                "name": name,
                "temp": f"{temp} °C",
                "util": f"{util} %",
                "mem": f"{used}/{total} MiB",
            }
        except Exception:
            self._gpu = {
                "name": "NVIDIA",
                "temp": "N/D",
                "util": "N/D",
                "mem": "N/D",
            }
        self._refresh_status()

    @staticmethod
    def _shorten_path(path: str, width: int) -> str:
        if len(path) <= width:
            return path
        keep = max(20, width - 1)
        return "…" + path[-keep:]

    def _refresh_status(self) -> None:
        minutes, seconds = divmod(self._seconds, 60)
        elapsed = f"{minutes:02d}:{seconds:02d}"

        width = max(40, self.size.width - 10)
        shown_path = self._shorten_path(self._step.file, width - 10)

        self.query_one("#header_line", HeaderLine).update(
            f"[b]🌧️ GOTA[/b]  Flujo · TUI-DEMO-003   🛠 RUNNING · OBSERVING   {elapsed}"
        )
        self.query_one("#detail_line", DetailLine).update(
            f"[b]{self._step.actor}[/b] · {self._step.action}"
        )
        self.query_one("#file_line", DetailLine).update(
            f"Archivo: [cyan]{shown_path}[/cyan]"
        )
        progress = self.query_one("#task_progress", ProgressBar)
        progress.update(progress=self._step.progress)

        self.query_one("#telemetry_line", TelemetryLine).update(
            f"GPU: {self._gpu['name']}  │  Temp: {self._gpu['temp']}  │  "
            f"Uso: {self._gpu['util']}  │  VRAM: {self._gpu['mem']}  │  "
            f"Errores: {self._errors}"
        )

    def on_resize(self) -> None:
        self._refresh_status()

    def action_quit_tui(self) -> None:
        self.exit(message="TUI finalizada")

    def action_log_page_up(self) -> None:
        self.query_one("#log", RichLog).action_page_up()

    def action_log_page_down(self) -> None:
        self.query_one("#log", RichLog).action_page_down()

    def action_log_home(self) -> None:
        self.query_one("#log", RichLog).scroll_home(animate=False)

    def action_log_end(self) -> None:
        self.query_one("#log", RichLog).scroll_end(animate=False)

    def on_button_pressed(self, event: Button.Pressed) -> None:
        if event.button.id == "exit_button":
            self.action_quit_tui()


if __name__ == "__main__":
    GotaTUI().run()
