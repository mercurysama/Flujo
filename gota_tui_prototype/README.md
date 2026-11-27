# 🌧️ Gota TUI — prototipo TUI-001

Primer prototipo visual para supervisar Gota desde una terminal.

## Qué hace

- Panel superior compacto con proyecto, tarea, estado, fase, agentes, Git y GPU.
- Panel principal grande de actividad/consola.
- Eventos simulados para evaluar el diseño antes de conectarlo a OpenCode o SQLite.
- Scroll con `PageUp` / `PageDown`.
- Botón **Salir de TUI** y tecla `Q`.

## Importante

**Salir de TUI** termina únicamente la aplicación TUI y devuelve el control al shell.
No cierra la ventana de terminal, no marca una tarea como DONE, no toca Git y no modifica Gota.

En una iteración posterior se podrá añadir una acción separada como `Finalizar tarea`,
pero sólo cuando esté conectada al coordinador y protegida por las reglas de autorización/fencing.

## Fedora: instalar y ejecutar

```bash
python3 -m venv .venv
source .venv/bin/activate
python -m pip install -r requirements.txt
python app.py
```

Para salir:

- pulsa el botón **Salir de TUI**, o
- pulsa `Q`.

## Alcance

Este prototipo corresponde a TUI-001/TUI-002 visual:
todavía no ejecuta OpenCode, Luna, Qwen ni Gota real.
