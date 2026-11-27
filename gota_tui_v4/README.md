# 🌧️ Gota TUI v4 — TUI-003

Esta versión mantiene la baseline visual v3 y agrega el siguiente paso técnico:

## TUI-003: proceso real

- La TUI lanza un proceso Python real (`demo_process.py`).
- Captura **stdout** y **stderr** en vivo.
- Muestra el PID real del proceso.
- El proceso emite eventos estructurados `GOTA_EVENT {...}`.
- Esos eventos actualizan:
  - actor actual,
  - acción,
  - archivo,
  - fase,
  - progreso.
- La temperatura, uso y VRAM NVIDIA siguen siendo reales mediante `nvidia-smi`.
- Al terminar con `exit=0`, la TUI muestra `🙆🏻 DONE`.
- La TUI permanece abierta para poder revisar el log.
- `Salir de TUI` termina sólo esta interfaz; si el proceso siguiera vivo, lo termina antes de salir.

## Seguridad

Todavía **no ejecuta OpenCode, Gota real, Git ni agentes reales**.
El proceso hijo sólo imprime mensajes y duerme unos segundos.

## Ejecutar

Puedes reutilizar el entorno virtual existente:

```bash
source ../gota_tui_prototype/.venv/bin/activate
python app.py
```

o crear uno nuevo:

```bash
python3 -m venv .venv
source .venv/bin/activate
python -m pip install -r requirements.txt
python app.py
```

## Qué validar visualmente

1. stdout aparece como `[OUT]`.
2. stderr aparece como `[ERR]` en amarillo.
3. El panel superior cambia de actor/archivo/fase.
4. La barra progresa hasta 100%.
5. Al finalizar aparece `🙆🏻 DONE`.
6. La TUI no cierra la terminal.


## Ajuste visual adicional

- Se agregó una etiqueta visible **"TUI v4"** en la parte superior derecha para identificar rápidamente la versión cargada.
