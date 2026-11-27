# 🌧️ Gota TUI v2 — prototipo visual

Cambios de esta versión:

- Panel superior compacto.
- Muestra **agente/acción actual**.
- Muestra **archivo actual** y **porcentaje de progreso** (simulados por ahora).
- Lee en vivo con `nvidia-smi`:
  - nombre de GPU,
  - temperatura,
  - utilización,
  - VRAM usada/total.
- Consola más grande, con wrap y sin barra horizontal.
- `PageUp`, `PageDown`, `Home` y `End` para navegar el log.
- `Q` o botón **Salir de TUI** para terminar sólo la interfaz.

## Pantalla completa

La TUI ocupa toda el área disponible de la terminal. Para ampliar la ventana de terminal a pantalla completa,
usa el atajo de tu emulador (en muchas terminales de Fedora/Xfce es `F11`).

## Importante

La actividad de agentes y archivos **todavía es simulada** para evaluar el diseño.
La telemetría NVIDIA sí es real cuando `nvidia-smi` está disponible.

No modifica Gota, Git ni OpenCode.
