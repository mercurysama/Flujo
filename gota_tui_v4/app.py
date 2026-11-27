from __future__ import annotations

import asyncio
import json
from datetime import datetime
from pathlib import Path
import subprocess
import sys

from textual.app import App, ComposeResult
from textual.containers import Horizontal
from textual.widgets import Button, Footer, Label, ProgressBar, RichLog, Static


class GotaTUI(App):
    """Gota TUI v4: captura stdout/stderr real de un proceso hijo."""

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

    #header_row,
    #detail_line,
    #file_line,
    #telemetry_line {
        height: 1;
    }

    #header_row {
        layout: horizontal;
    }

    #header_left {
        width: 1fr;
    }

    #header_right {
        width: 12;
        text-align: right;
        content-align: right middle;
    }

    #task_progress {
        height: 1;
        margin: 0;
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
        self._progress = 0
        self._state = "🛠 RUNNING"
        self._phase = "STARTING"
        self._actor = "GOTA"
        self._action = "iniciando proceso de prueba"
        self._current_file = "—"
        self._process: asyncio.subprocess.Process | None = None
        self._pid = "—"
        self._gpu = {
            "name": "NVIDIA",
            "temp": "—",
            "util": "—",
            "mem": "—",
        }

    def compose(self) -> ComposeResult:
        with Static(id="status_box"):
            with Horizontal(id="header_row"):
                yield Static(id="header_left")
                yield Static("TUI v4", id="header_right")
            yield Static(id="detail_line")
            yield Static(id="file_line")
            yield ProgressBar(total=100, show_eta=False, id="task_progress")
            yield Static(id="telemetry_line")

        yield Label("ACTIVIDAD / CONSOLA — stdout/stderr real", id="activity_title")

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
        log.write("[dim]Gota TUI v4 — TUI-003: proceso hijo real, sin OpenCode y sin tocar Gota/Git.[/dim]")
        log.write("[dim]stdout aparece como [OUT]; stderr como [ERR].[/dim]")
        log.write("[dim]La actividad superior se actualiza con eventos estructurados emitidos por el proceso.[/dim]")

        self._read_gpu()
        self._refresh_status()

        self.set_interval(1.0, self._tick)
        self.set_interval(2.0, self._read_gpu)

        asyncio.create_task(self._run_demo_process())

    def _tick(self) -> None:
        self._seconds += 1
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

    async def _run_demo_process(self) -> None:
        worker = Path(__file__).with_name("demo_process.py")
        log = self.query_one("#log", RichLog)

        try:
            self._process = await asyncio.create_subprocess_exec(
                sys.executable,
                "-u",
                str(worker),
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE,
            )
            self._pid = str(self._process.pid)
            self._phase = "PROCESS_RUNNING"
            self._action = "proceso de prueba ejecutándose"
            self._refresh_status()

            log.write(
                f"[green]{datetime.now():%H:%M:%S}[/green]  "
                f"[b][GOTA][/b] proceso iniciado · PID {self._pid}"
            )

            assert self._process.stdout is not None
            assert self._process.stderr is not None

            await asyncio.gather(
                self._pump_stream(self._process.stdout, "OUT"),
                self._pump_stream(self._process.stderr, "ERR"),
            )

            return_code = await self._process.wait()

            if return_code == 0:
                self._state = "🙆🏻 DONE"
                self._phase = "PROCESS_COMPLETE"
                self._actor = "GOTA"
                self._action = "proceso real completado"
                self._progress = 100
                log.write(
                    f"[green]{datetime.now():%H:%M:%S}[/green]  "
                    f"[b][GOTA][/b] proceso terminó correctamente · exit=0"
                )
            else:
                self._state = "⛔ BLOCKED"
                self._phase = "PROCESS_FAILED"
                self._actor = "GOTA"
                self._action = f"proceso terminó con exit={return_code}"
                self._errors += 1
                log.write(
                    f"[red]{datetime.now():%H:%M:%S}[/red]  "
                    f"[b][GOTA][/b] proceso terminó con exit={return_code}"
                )

        except Exception as exc:
            self._state = "⛔ BLOCKED"
            self._phase = "PROCESS_EXCEPTION"
            self._actor = "GOTA"
            self._action = "excepción al ejecutar proceso"
            self._errors += 1
            log.write(f"[red][GOTA] {type(exc).__name__}: {exc}[/red]")
        finally:
            self._refresh_status()

    async def _pump_stream(
        self,
        stream: asyncio.StreamReader,
        source: str,
    ) -> None:
        log = self.query_one("#log", RichLog)

        while True:
            raw = await stream.readline()
            if not raw:
                break

            line = raw.decode("utf-8", errors="replace").rstrip("\n")
            now = datetime.now().strftime("%H:%M:%S")

            if source == "OUT" and line.startswith("GOTA_EVENT "):
                payload_text = line[len("GOTA_EVENT "):]
                try:
                    event = json.loads(payload_text)
                except json.JSONDecodeError:
                    log.write(f"[yellow]{now} [OUT][/yellow] {line}")
                    continue

                self._actor = str(event.get("actor", self._actor))
                self._action = str(event.get("action", self._action))
                self._current_file = str(event.get("file", self._current_file))
                self._progress = int(event.get("progress", self._progress))
                self._phase = str(event.get("phase", self._phase))

                log.write(
                    f"[green]{now}[/green]  [b][{self._actor}][/b]  {self._action}\n"
                    f"          [cyan]{self._current_file}[/cyan]"
                )
                self._refresh_status()
                continue

            if source == "OUT":
                log.write(f"[green]{now}[/green]  [b][OUT][/b]  {line}")
            else:
                log.write(f"[yellow]{now}[/yellow]  [b][ERR][/b]  [yellow]{line}[/yellow]")

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
        shown_path = self._shorten_path(self._current_file, width - 10)

        self.query_one("#header_left", Static).update(
            f"[b]🌧️ GOTA[/b]  Flujo · TUI-REAL-001   {self._state} · {self._phase}   {elapsed}"
        )
        self.query_one("#header_right", Static).update("[b]TUI v4[/b]")
        self.query_one("#detail_line", Static).update(
            f"[b]{self._actor}[/b] · {self._action}"
        )
        self.query_one("#file_line", Static).update(
            f"Archivo: [cyan]{shown_path}[/cyan]"
        )
        self.query_one("#task_progress", ProgressBar).update(progress=self._progress)

        self.query_one("#telemetry_line", Static).update(
            f"PID: {self._pid}  │  GPU: {self._gpu['name']}  │  "
            f"Temp: {self._gpu['temp']}  │  Uso: {self._gpu['util']}  │  "
            f"VRAM: {self._gpu['mem']}  │  Errores: {self._errors}"
        )

    def on_resize(self) -> None:
        self._refresh_status()

    def action_quit_tui(self) -> None:
        if self._process is not None and self._process.returncode is None:
            self._process.terminate()
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
