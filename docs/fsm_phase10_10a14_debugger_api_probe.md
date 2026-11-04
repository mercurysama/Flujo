# Potok 10A-14 — Introspección segura de APIs de depuración en Godot

**Fecha:** 2026-11-03. **Rama:** `feature/fsm-runtime-flow-flusso`. **Base:** `e96079d214b760801fc520b7ac9a5c3dd2d0a24c`. **Ámbito:** compatibilidad del **motor**, no implementación de DEBUG-FSM, no aprobación G7, sin crear sesiones, emitir mensajes ni modificar `addons/`.

## Referencias y selección de prueba

La documentación oficial de Godot para `EditorDebuggerPlugin` muestra el patrón `EditorPlugin.add_debugger_plugin` → `EditorDebuggerPlugin.get_session`/`_setup_session` → `EditorDebuggerSession.add_session_tab`. La documentación de `EngineDebugger` (latest/unstable) incluye `send_message` y `register_message_capture`, pero la versión estable de la documentación no expone necesariamente la misma API. Referencias: `https://docs.godotengine.org/en/4.4/classes/class_editordebuggerplugin.html`, `https://docs.godotengine.org/en/stable/classes/class_editordebuggersession.html`, `https://docs.godotengine.org/en/latest/classes/class_enginedebugger.html`.

**Por qué introspección en CI:** conocer que una clase aparece en otra versión de la documentación no prueba su disponibilidad en el binario fijado para Flujo. La fixture `tests/editor/flow_fsm_debugger_classdb_probe.gd` consulta `ClassDB.class_exists` y `class_has_method` con el Godot 4.7.2 descargado por el workflow real.

## Contrato de la focal

- **Requerido/FAIL si falta:** `EditorPlugin`, `EditorDebuggerPlugin`, `EditorDebuggerSession`, registro/desregistro por EditorPlugin, consulta de sesión, `add_session_tab`, `remove_session_tab`, `send_message`, `is_active` y `is_breaked`. Son capacidades de interfaz del editor, no observación de máquinas.
- **Informe sin declarar PASS de transporte:** disponibilidad de `EngineDebugger` por `ClassDB`, `send_message` y `register_message_capture`; si ClassDB no expone ese singleton, **no se infiere** que el transporte funcione o falle en ejecución real.
- **No cubre:** `EditorDebuggerPlugin._capture` y `_setup_session` virtuales, sesión adjunta, envío/recepción efectivo juego-editor, desconexión, IDs de controlador, saturación, Android, debugger visual o Focus/UndoRedo. Esos comportamientos esperan un contrato G7 autorizado y focales posteriores.
- **No afecta:** `FlowFSMRuntime`, `PVController`, `FlowGraph`, snapshot FSM-004, `main`, Fluo y esquema.
- **Resultado inicial:** fixture y gate obligatorios añadidos con catálogo `FLUJO-BHV-POTOK-EDITOR-DEBUGGER-API-PROBE-004` en `not_run`. Actualizar a `passing` sólo después de verificar **el workflow integral** y paso focal del mismo SHA; no prometer resultados anticipadamente.

## Comando exacto de GitHub Actions

```sh
timeout --signal=TERM --kill-after=5s 35s ./Godot_v4.7.2-stable_linux.x86_64 --headless --editor --path . --script tests/editor/flow_fsm_debugger_classdb_probe.gd
```

**Gobernanza:** esta es una caracterización *test-only* de una capacidad existente del motor. No se ejecutaron formalmente `$flujo-baseline` ni `$flujo-prove` en Fedora; no hay revisión humana ni cambios productivos. Incluso con CI PASS, G1..G8 siguen sin aprobación.

*Todo es Flujo; todo fluye.* 🌊

## Evidencia posterior de 10A-14

- **Commit focal:** `979a07b423299b49fe1610cb76a944df83fcdc1f`.
- **Workflow integral y paso focal:** [GitHub Actions 41766064041](https://github.com/mercurysama/Flujo/actions/runs/41766064041), `completed/success`, paso «Potok-10A14 native Godot debugger API ClassDB probe» `success`.
- **Salida de introspección recuperada del log del job:** `EngineDebugger` `exists=true`, `send=true`, `receive=true`, y marcador de la fixture `editor debugger API probe result: passed`.
- **Interpretación exacta:** el binario Godot 4.7.2 ofrece las clases/métodos inspeccionados, **NO** se comprobó conexión entre editor y juego ni envío de un paquete real. `G7` y la fase 10B permanecen sin aprobar. Catalogado `FLUJO-BHV-POTOK-EDITOR-DEBUGGER-API-PROBE-004` como `passing` sólo después de este PASS completo.
