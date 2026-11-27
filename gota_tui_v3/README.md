# 🌧️ Gota TUI v3

Versión 3 del prototipo visual.

## Cambios principales

- Barra de progreso gráfica real de la interfaz.
- El porcentaje representa el progreso de la tarea actual.
- Archivo actual en una línea separada.
- Ruta completa cuando cabe; truncado inteligente cuando la terminal es estrecha.
- Telemetría NVIDIA real mediante `nvidia-smi`.
- Consola grande con scroll, wrap y auto-scroll.
- `Q` o botón **Salir de TUI** termina sólo la interfaz.
- `PageUp`, `PageDown`, `Home` y `End` navegan el log.

## Nota

La actividad de agentes, archivos y porcentaje de tarea sigue siendo simulada en esta maqueta.
La temperatura, uso y VRAM de NVIDIA sí son reales.

## Ejecución

Puedes reutilizar el entorno virtual de la versión anterior:

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
