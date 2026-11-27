from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime
from itertools import cycle
from pathlib import Path
import subprocess

from textual.app import App, ComposeResult
from textual.containers import Horizontal
from textual.widgets import Button, Footer, Label, RichLog, Static


@dataclass(frozen=True)
class DemoStep:
    actor: str
    action: str
    file: str
    progress: int


class StatusPanel(Static):
    """Panel superior compacto con telemetría y actividad actual."""

    def render_state(
        self,
        *,
        project: str,
        task: str,
        state: str,
        elapsed: str,
        actor: str,
        action: str,
        current_file: str,
        progress: int,
        gpu_name: str,
        gpu_temp: str,
        gpu_util: str,
        gpu_mem: str,
        errors: int,
    ) -> None:
        filename = Path(current_file).name if current_file else "—"
        self.update(
            f"[b]🌧️ GOTA[/b]  {project} · {task}   {state}   {elapsed}\n"
            f"[b]{actor}[/b]  {action}   Archivo: [cyan]{filename}[/cyan]   Progreso: {progress:>3}%\n"
            f"GPU: {gpu_name}  │  Temp: {gpu_temp}  │  Uso: {gpu_util}  │  VRAM: {gpu_mem}  │  Errores: {errors}"
        )


class GotaTUI(App):
    """Prototipo visual: estado compacto + consola + telemetría NVIDIA real."""

    TITLE = "Gota TUI"
    SUB_TITLE = "Supervisor experimental"

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
        yield StatusPanel(id="status")
        yield Label("ACTIVIDAD / CONSOLA", id="activity_title")
        yield RichLog(
            id="log",
            wrap=True,
            highlight=True,
            markup=True,
            auto_scroll=True,
            max_lines=2000,
        )
        with Horizontal(id="controls"):
            yield Button("Salir de TUI", id="exit_button", variant="error")
        yield Footer()

    def on_mount(self) -> None:
        log = self.query_one("#log", RichLog)
        log.write("[dim]Prototipo visual. Actividad de archivos simulada; telemetría NVIDIA real si nvidia-smi está disponible.[/dim]")
        log.write("[dim]«Salir de TUI» termina sólo esta interfaz y devuelve el control a la terminal.[/dim]")
        log.write("[dim]Para usar toda la pantalla, pon la terminal en pantalla completa (normalmente F11).[/dim]")
        self._read_gpu()
        self._refresh_status()
        self.set_interval(1.0, self._tick)
        self.set_interval(2.0, self._read_gpu)

    def _tick(self) -> None:
        self._seconds += 1

        # Simula el cambio de archivo/acción cada 4 segundos.
        if self._seconds % 4 == 0:
            self._step = next(self._steps)
            now = datetime.now().strftime("%H:%M:%S")
            self.query_one("#log", RichLog).write(
                f"[green]{now}[/green]  [b][{self._step.actor}][/b]  "
                f"{self._step.action}\n"
                f"          [cyan]{self._step.file}[/cyan]"
            )

        self._refresh_status()

    def _read_gpu(self) -> None:
        """Lee temperatura, uso y VRAM de la primera GPU NVIDIA visible."""
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

    def _refresh_status(self) -> None:
        minutes, seconds = divmod(self._seconds, 60)
        elapsed = f"{minutes:02d}:{seconds:02d}"
        self.query_one("#status", StatusPanel).render_state(
            project="Flujo",
            task="TUI-DEMO-002",
            state="🛠 RUNNING",
            elapsed=elapsed,
            actor=self._step.actor,
            action=self._step.action,
            current_file=self._step.file,
            progress=self._step.progress,
            gpu_name=self._gpu["name"],
            gpu_temp=self._gpu["temp"],
            gpu_util=self._gpu["util"],
            gpu_mem=self._gpu["mem"],
            errors=self._errors,
        )

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
