# Potok 10A-9 — Contrato candidato DEBUG-FSM v1 y acta de decisión 10B

**Fecha:** 2026-11-03. **Rama:** `feature/fsm-runtime-flow-flusso`. **Base:** `34a427bdf7cba0bf30439cc58ca8ffa66b38d600`. **Clasificación:** **CANDIDATO PARA APROBACIÓN DEL RESPONSABLE, NO APROBADO.** No reemplaza ni cambia los contratos productivos FLU-FSM-001/002/003/004, FSM-R27/R28, el snapshot `format_version=1` ni la política de persistencia. Sin cambios de código.

**Fuentes del diseño:** [contrato v0](fsm_observability_contract_proposal_v0.md), [auditoría 10A-7](fsm_phase10_10a7_evidence_audit.md), [integración 10A-8](fsm_phase10_10a8_editor_debugger_integration_map.md), [presupuesto 10A-6](fsm_phase10_10a6_trace_budget_proposal.md) y [plan fase 10](fsm_implementation_plan.md).

## 1. Objetivo y ámbitos de implementación

**Objetivo observable:** para una FSM de un `PVController` real, permitir consultar su estado actual y una historia acotada de decisiones que explique, sin inspeccionar código, por qué sí cambió de estado o por qué una candidata no se aplicó. La observación no ejecuta expresiones de nuevo, no modifica `FlowGraph`, no mueve tokens/chips, no serializa el rastro en snapshots y no permite ordenar transiciones por accidente.

**Ámbito recomendado en dos entregas, sujetas a aprobación independiente:**
- **10B-core** (runtime portable): captura opt-in de resultados ya calculados, registros compactos y bounded, snapshot de lectura por instancia con copias y secuencia; sin editor.
- **10B-view** (editor): adaptador `EditorDebuggerPlugin` por sesión Godot, comunicación segura y tab read-only; no sustituye Inspector → Fluo → Flow/Flusso.
- **10B-controls** (opcional separado): pause/resume/step con contrato específico antes de editar cualquier código. No forma parte de la autorización implícita del core.

## 2. Decisiones explícitas propuestas (todas con estado PENDIENTE)

| Gate | Elección candidata preferida | Alternativas / advertencia | Estado |
|---|---|---|---|
| **10B-G1** Retención | Anillo por instancia `FlowFSMRuntime` con **128 registros** candidatos, sobrescritura del más antiguo y máximo **1024 bytes JSON UTF-8/registro**, sujeto a benchmark | Tamaño 64/256 registros o presupuesto configurable; cuota en bytes no es memoria residente del motor y debe medirse | **PENDIENTE** |
| **10B-G2** Activación | **Deshabilitado por defecto**, incluso en export; habilitar explícitamente sólo para inspección autorizada, sin construir registros si está desactivado | Activado sólo en editor puede facilitar pruebas pero supone trabajo oculto; requiere definir salida y limpieza | **PENDIENTE** |
| **10B-G3** Fuente | Una sola fuente estructurada por runtime que alimenta un anillo de lectura read-only; el editor escucha un adaptador y no reconstruye causas desde señales incompletas | Señal adicional `debug_recorded` o polling del anillo: elegir sólo tras prueba de reentrancia y pérdidas | **PENDIENTE** |
| **10B-G4** Semántica | Registrar separadamente **admitted**, **delivered**, **considered**, **selected**, **skipped**, **committed**, **deferred** y **rejected** según el punto exacto ya existente, sin renombrar las señales públicas legacy | Un paquete admitido NO equivale a evento entregado ni a transición; self-target sin commit es `skipped`, no rechazo de admisión | **PENDIENTE** |
| **10B-G5** Privacidad | Sólo IDs, nombre de evento truncado y código de diagnóstico; **ningún payload**, `Node`, `Object`, `Resource`, `Callable`, resultado libre de condición ni token de usuario | Una razón `reason` textual arbitraria podría contener datos sensibles: preferir código/enum y truncado sin guardar valor libre | **PENDIENTE** |
| **10B-G6** Estado inicial | Snapshot de estado **actual** al conectar observador, después registros con `sequence`; declarar pérdida de pasado y gap de secuencia | No fabricar `machine_started` retroactivo ni mezclar dos controladores o sesiones del editor | **PENDIENTE** |
| **10B-G7** Transporte/editor | Integración de sesión con `EditorDebuggerPlugin` y adaptador aislado; juego sin dependencia de `Editor*` | Confirmar cada método con Godot 4.7.2; una pestaña nueva no debe robar foco a Fluo | **PENDIENTE** |
| **10B-G8** Controles | Inspección sólo lectura en 10B-core/view; pausa, resume, step y edición de valores requieren contrato 10B-controls separado | Cambiar `SceneTree.paused` o llamar `tick()` directamente desde la UI sin política no es aceptable | **PENDIENTE** |

**El número 128 y 1024 bytes son parámetros de DISEÑO**, no límites actuales ni evidencia de rendimiento; no aplican hasta aprobación y pruebas. El cálculo 128×1024 representa sólo un **techo lógico de serialización por registro** para el candidato, no una predicción válida de memoria o latencia de Godot.

## 3. Registro DEBUG-FSM v1 propuesto

Registro copiable e inerte con `version: 1`, `sequence`, `tick`, `controller_epoch` (efímero, no authored), `machine_id`, `state_id`, `from_state_id`, `to_state_id`, `trigger_id`, `request_kind`, `event_name`, `stage`, `outcome`, `diagnostic_code`, `phase`. Los identificadores authored siguen siendo autoridad; `session_id` de Godot identifica conexión de debugger, **no** máquina. Considerar `controller_epoch` un token temporal generado al iniciar una captura que no se persiste.

**Reglas candidatas de emit:** 
- `admission/admitted`: `emit_event()` o `request_transition()` acepta en cola; no prometer matching futuro.
- `admission/rejected`: falla preexistente, reusar `request_rejected` sin modificar su orden/código.
- `consumption/delivered`: el paquete cruza la barrera de reloj y se procesa en el tick actual. `event_consumed` conserva su semántica pública legacy.
- `arbitration/considered`: la condición/edge ya se evaluó una única vez; el registro debe reflejar el resultado efectivamente obtenido, no una segunda llamada a `resolve()`. Prohibido guardar objeto de resultado o contexto.
- `arbitration/skipped`: no-op por mismo ID, candidato `false`, ausencia de matching o bloqueo de cadena con causa diferenciable si el código original la conoce.
- `commit/committed`: cambio real de `active_state_id` después de Exit/Enter en el orden vigente; no mover la señal legacy `transition_committed`.
- `budget/deferred`: paquete permanece en la cola para su reloj posterior; `work_budget_deferred` conserva firma.

**Nota sobre detalle insuficiente:** si el evaluador sólo produce `FlowValueResult` con fallo no normalizable, publicar `condition_error` con código aprobado **sin** incluir un valor privado. No inventar explicación por cada elemento que jamás fue evaluado porque un candidato previo ganó.

**Orden:** `sequence` estrictamente creciente por runtime y época de captura; `tick` sólo aumenta cuando la FSM realmente procesa un tick elegible, no al invocar `tick()` que retorna temprano. Registrar secuencia de eventos de startup como `tick=0` sólo cuando la captura ya está habilitada antes de `start()`. El test debe fijar cuándo se generan registros entre `_execute_phase` y señal legacy sin alterar callbacks.

## 4. API propuesta (pseudointerfaz, NO IMPLEMENTADA)

```text
set_debug_capture_enabled(enabled: bool) -> bool        # sólo con contrato/aprobación
get_debug_snapshot() -> Dictionary                       # copia inerte de estado actual
get_debug_records(after_sequence: int = 0) -> Array      # copia, ordenada, acotada
clear_debug_records() -> void                            # sin tocar cola, FSM ni graph
```

**No usar** estas firmas como afirmación de que existen en `flow_fsm_runtime.gd`. El snapshot debe distinguir `machine_id`, nombre authored permitido, `initial_state_id`, `active_state_id`, `tick_mode`, `running`, `pending_count` y `last_transition` **únicamente si se capturó realmente**. La `phase` se captura como dato efímero al ejecutar `Enter/Update/Exit`; tras callback es `idle` o desconocida según contrato, no se deduce del último texto mostrado. Los nombres derivados del grafo se normalizan al copiar y nunca exponen el recurso.

## 5. Condiciones de aceptación para abrir y luego cerrar 10B

| Requisito | Prueba requerida, tras autorización | Estado hoy |
|---|---|---|
| OBS-B01 | Captura deshabilitada ≡ ejecución legacy en estados, colas, callbacks y latencia medida | **NOT RUN, no API** |
| OBS-B02 | Sobrepasar capacidad/bytes → se pierden sólo registros antiguos, gaps detectables | **NOT RUN** |
| OBS-B03 | Dos controladores y múltiples máquinas → secuencias/épocas aisladas | **NOT RUN** |
| OBS-B04 | Datos anidados/objetos/inyección → sólo diccionarios inertes, mutación de copia no cambia estado | **NOT RUN** |
| OBS-B05 | Eventos false/true/self/invalid → sin reevaluar condición, commit igual que baseline | **NOT RUN** |
| OBS-B06 | Suscripción tardía y reconexión → estado actual, sin falsas entradas históricas | **NOT RUN** |
| OBS-B07 | Stop y cierre de escena durante callbacks → no fuga, no doble cleanup | **NOT RUN** |
| OBS-B08 | Ready/Timer, schemas 3/4, FSM 001-004, Fluo, export → regresión sin cambio | **NOT RUN** |
| OBS-B09 | Benchmark de 0/1/muchas máquinas y saturation → costo/memoria medidos, no estimados | **NOT MEASURED** |
| OBS-B10 | Restore snapshot formato 1 → no registro de depuración persistido ni policy F9/F10 alterada | **NOT RUN** |
| UI-B11 | Godot editor 4.7.2, sesión, foco, teclado, selección por ID, cierre | **NOT RUN, UI no implementada** |
| ANDROID-B12 | Separación de exportación y configuración debug sin dependencias `Editor*` | **NOT RUN** |

La preparación de RED/GREEN debe hacerse en commits distintos según la gobernanza, tras congelar decisiones, nunca inventando un estado `passing` para fixtures inexistentes. Cualquier cambio productivo requiere ejecutar **formalmente** `$flujo-baseline` antes y `$flujo-prove` al terminar, además de CI y revisión humana aplicable.

## 6. Decisión solicitada, sin asumirla

Para autorizar **sólo el primer paso 10B-core**, el responsable deberá aceptar o cambiar **10B-G1..G6**; **10B-G7** puede reservarse a la UI/editor y **10B-G8** permanece fuera hasta un contrato explícito de controles. Se propone redactar una entrada de catálogo RED para el contrato aprobado y empezar con una prueba mínima del anillo **antes** de añadir estado nuevo al runtime.

**Recomendación técnica sujeta a revisión:** buffer de 128 registros desactivado por defecto y sin payload, sanitizado y leído por copia, por `FlowFSMRuntime` individual; decisiones de arbitraje registradas en el punto de evaluación original; transporte Godot sólo desde adaptador externo. No habilitar por simple continuidad o emoji de la tanda documental: el cierre de diseño y la implementación requieren aprobación de sus parámetros.

**Veredicto:** **10A-9 DOCUMENTADO — v1 candidato, 10B BLOQUEADA hasta aprobación de opciones y gates**. Ningún runtime, esquema, UI ni `main` modificados. Tests visuales y Skills formales **NOT RUN**, revisión 0/25.

*Todo es Flujo; todo fluye.* 🌊
