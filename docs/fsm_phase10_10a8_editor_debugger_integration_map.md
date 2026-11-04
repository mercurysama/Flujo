# Potok 10A-8 — Inventario de integración con depurador Godot / Fluo

**Fecha:** 2026-11-03. **Rama:** `feature/fsm-runtime-flow-flusso`. **Base:** `432f59e1700a1fa433ff0bf4170100fc007adc91`. **Estado:** diseño de integración **PROPUESTO**, sin UI nueva, script productivo, señal, registro de mensajes ni API de runtime. **No representa autorización 10B**.

## 1. Superficies comprobadas en el repositorio

| Archivo / clase | Función existente y frontera | Implicación para DEBUG-FSM |
|---|---|---|
| `addons/vp_flujo/plugin.gd` (`EditorPlugin`) | Composition root, registra `PVControllerInspectorPlugin`, monta `FluoDrawer` y panel de nodos; desmonta en `_exit_tree` | Futuro lugar para **registrar/desregistrar** un adaptador de depuración *del editor*, nunca almacenamiento de estado de juego |
| `editor/pv_controller_inspector_plugin.gd` | Provee Inspector de PVController y relevos de selección hacia Fluo | La selección authored **no equivale** a instancia depurada en ejecución |
| `editor/fluo_drawer.gd` | Drawer de edición; gestiona flujos de teclado, foco, Escape, Fluo/Flow/Flusso, Revertir | No agregar comandos o vistas que rompan Undo/Redo, foco, edición en vivo o Revertir |
| `editor/flow_fsm_editor_projection.gd` | `@tool`, presentación read-only de `FlowGraph`: máquina, ID/nombre, estado inicial, fases y transiciones | Fuente visual para **metadatos authored**, pero no contiene estado runtime, resultado de condición o historial |
| `runtime/pv_controller.gd` | Cada instancia posee `_fsm_runtime`; `get_fsm_runtime()`; `_process/_physics_process` alimentan ticks | Fuente local por dueño y ciclo de vida; nunca usar un singleton compartido |
| `runtime/flow_fsm_runtime.gd` | `RefCounted` con señales públicas, `get_active_state_id`, `get_active_machine_ids`, `pending_request_count`, `is_running` | Sólo permite vista viva **parcial**; no tiene API de snapshot observacional ni trace circular |
| `docs/fluo_preview_01.md` | Fluo preliminar con navegación/teclado aprobados para preview; Android sin matriz de aceptación final | No confundir preview con depurador ni reclamar aceptación móvil |

**Confirmación negativa por inventario de fuente:** no se observó `EditorDebuggerPlugin` registrado en el actual `plugin.gd`; ninguna de las funciones runtime actuales crea historial de depuración, y `FlowFSMEditorProjection.present` sólo proyecta recursos authored.

## 2. Canal de integración de Godot: referencia externa y límite de verificación

Godot documenta el patrón de extensión **`EditorPlugin.add_debugger_plugin()` → `EditorDebuggerPlugin._setup_session(session_id)` → `EditorDebuggerSession.add_session_tab(control)`**, y un transporte de mensajes de juego **`EngineDebugger.send_message()`** hacia `EditorDebuggerPlugin._capture()`; las sesiones disponen de `started`/`stopped` e `is_active()`. Fuentes oficiales:

- `https://docs.godotengine.org/en/4.4/classes/class_editordebuggerplugin.html` (API documentada en Godot 4.4).
- `https://docs.godotengine.org/en/stable/classes/class_editordebuggersession.html` (API de sesiones actual).
- `https://docs.godotengine.org/en/latest/classes/class_enginedebugger.html` (referencia de canal en latest/unstable; **no asumir** compatibilidad de todos sus métodos con 4.7.2 sin una focal local).

**No se ha probado aquí el canal de mensajes ni un `EditorDebuggerPlugin` contra el binario Godot 4.7.2 del proyecto.** La documentación es un inventario de opciones, no evidencia de runtime.

## 3. Integración mínima candidata, sin acoplamiento

```text
Juego (cada PVController)
  FlowFSMRuntime — señales presentes y futura vista de eventos read-only
       |
       v (sólo cuando contrato 10B habilite inspección)
  Adaptador de mensajes en ejecución: selección por instancia + sanitización + cuotas
       |
       v protocolo Godot Debugger (sin archivos, sin telemetría de red propia)
  EditorDebuggerPlugin — sesión por instancia ejecutada / attach / detach
       |
       v
  Potok Debugger tab (solo lectura) — máquinas activas, eventos, causas, diagnósticos

Autoría (separada): Inspector → Fluo → Flow / Flusso
  FlowFSMEditorProjection — IDs y metadatos authored, nunca fuente de state runtime
```

**Alternativa más pequeña y permitida mientras no exista contrato:** inspector de señales ya existentes en fixture de pruebas; **no** crear un panel que aparente mostrar causas no observables.

## 4. Problemas de ciclo de vida y propiedad

1. **Identidad de sesión:** `session_id` del depurador Godot es identidad del proceso remoto; `machine_id` es identidad authored. No son equivalentes. Definir identificador efímero y estable durante la vida del controlador *dentro de cada sesión* y mapear múltiples `PVController`; no usar NodePath ni nombre como identidad persistente.
2. **Arranque tardío:** `get_fsm_runtime()` se obtiene cuando `_ready` ya pudo emitir `machine_started` y `state_entered`; cualquier tab conectada tarde necesita un **snapshot actual read-only** antes de escuchar deltas futuros.
3. **Eventos y seguridad:** canal a editor transporta **datos inertes**, no `FlowGraph`, `Node`, `Resource`, `Callable`, payload arbitrario ni expresiones evaluables. No replicar archivos user:// ni snapshot FSM-004.
4. **Orden y concurrencia:** el contexto editor y juego pueden estar desacoplados; establecer handshake `protocol_version`, `session_epoch`, `controller_identity`, `sequence` y descartar eventos de sesiones cerradas/tardías. No suponer orden global entre diferentes controladores.
5. **Múltiples sesiones:** al parar un proyecto, liberar pestañas/conexiones, descartar WeakRefs y toda caché; si hay varias sesiones activas, no mezclar máquinas de una con las de otra.
6. **Editor/UI:** tab de depuración separada de Flow y Flusso, no roba foco del árbol editable, no dispara UndoRedo ni Revertir; selección de máquina por IDs estables. Los colores/estado visual no alteran orden authored.
7. **Android/exportación:** la vista nativa del editor no implica debugger embebido en APK; por defecto ningún canal de inspección/telemetría queda activo en export. Cualquier debug remoto necesita autorización adicional.
8. **Pausa:** el `SceneTree.paused` de Godot, `EditorDebuggerSession.is_breaked()` y la futura pausa de una FSM son conceptos diferentes. No reutilizar uno como sustituto del otro; el contrato debe definir dónde bloquea Update, cola, eventos, Timer y transiciones.

## 5. Orden seguro para futura implementación (NO INICIADO)

| Paso candidato | Entregable | Evidencia imprescindible |
|---|---|---|
| 10B-0 | Aprobación de contrato y presupuesto | Decisiones 10B-G1..G6 aceptadas, versión congelada |
| 10B-1 | Registro estructurado opcional runtime sin editor | Test RED/GREEN, trazas aisladas y acotadas |
| 10B-2 | Snapshot de inspección read-only + sanitización | Dos controladores, conexión tardía, snapshots desacoplados |
| 10B-3 | Transporte bajo sesión Godot en adaptador separado | Handshake, multi-sesión, desconexión, no telemetría |
| 10B-4 | Tab de depuración con accesibilidad | Godot 4.7.2 editor + Fedora revisión visual |
| 10B-5 | Pausa/step **sólo si autorizado** | Política explícita, pruebas reentrantes, Ready/Timer/PHYSICS |
| 10B-6 | Android y exportación | Prueba manual diferenciada, compatibilidad sin editor |

## 6. Veredicto del inventario

**10A-8: DOCUMENTADO, no implementado.** Reutilizar composición `plugin.gd` y mantener Fluo como autoría; evitar incrustar runtime/debug state en `FlowFSMEditorProjection`. El transporte oficial es una **opción técnica**, no un cambio ya aprobado. Sin cambios productivos, sin tests visuales, sin ejecución formal de Skills y sin cierre de fase 10.

*Todo es Flujo; todo fluye.* 🌊
