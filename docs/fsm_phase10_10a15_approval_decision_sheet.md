# Potok 10A-15 — Acta propuesta de decisión para autorizar 10B-core

**Fecha:** 2026-11-03. **Rama:** `feature/fsm-runtime-flow-flusso`. **Base verificada:** `979a07b423299b49fe1610cb76a944df83fcdc1f`. **Estado:** **PROPUESTA PARA DECISIÓN EXPLÍCITA DEL RESPONSABLE — NO APROBADA**. 10A-13 certifica el CI del handoff y 10A-14 añade una focal de introspección Godot; esta acta no constituye una aceptación de ningún gate ni un nuevo contrato de API productiva.

## Alcance exacto de una posible autorización

Esta propuesta se limita al **núcleo portable 10B**: capacidad de registrar un historial acotado, consultar estado actual y describir decisiones realmente evaluadas dentro de cada `FlowFSMRuntime`. **No incluye** una pestaña nueva en Godot, protocolo remoto, edición de variables, pausa, reanudación, stepping ni cambios de `FlowGraph` o snapshot. Esos otros temas requieren aprobación posterior.

| Gate | Elección concreta **propuesta** | Cuestión que la aprobación debe resolver |
|---|---|---|
| **G1 — Capacidad** | Anillo de **128 registros por `FlowFSMRuntime`**, sobrescribir el más antiguo; presupuesto lógico de **1024 bytes JSON UTF-8 por registro** con rechazo/truncamiento seguro a definir por pruebas | Aceptar N y bytes, y cómo señalizar pérdidas. **No confundir bytes serializados con memoria residente** |
| **G2 — Activación** | Captura **OFF por defecto**, también en export; se habilita sólo por llamada/autorización explícita. Sin observador, estado FSM igual al baseline | ¿Se desea OFF por defecto? Costo aún no medido |
| **G3 — Fuente/lectura** | Una sola traza estructurada interna por runtime, copia en consultas, **polling read-only** en el primer corte, sin nueva señal síncrona pública inicial | Evitar reentrada y doble fuente; nueva señal se decidiría por separado |
| **G4 — Semántica** | Distinguir `admitted`, `delivered`, `considered`, `selected`, `skipped`, `committed`, `deferred`, `rejected`; no reevaluar condiciones ni alterar el orden de señales legacy | Distinguir solicitud admitida de entregada, matching y commit; no reportar condiciones no ejecutadas |
| **G5 — Datos** | Sin payload completo, `Node`, `Resource`, `Callable`, objetos, contexto o valores de condición. Registrar únicamente escalares inertes como IDs, códigos, nombre de evento acotado y etapa; copias defensivas | Definir saneamiento UTF-8, exceso de longitud y fallos seguros sin truncar identidad interna de manera silenciosa |
| **G6 — Conexión tardía** | Snapshot **actual** por controlador/máquina, más secuencia local y epoch efímero. No replay de eventos anteriores a captura, ni mezcla de sesiones | Aceptar que el historial comienza cuando se activa la captura, sin fabricar `machine_started` |

**G7 editor:** `EditorDebuggerPlugin` y transporte por sesión, después de un test del canal real Godot 4.7.2 y aprobación independiente. **G8 controles:** pausa/reanudar/paso manual y edición de valores excluidos de 10B-core; necesitarán contrato separado. **10A-14 no es prueba de funcionamiento de transporte**.

## Invariantes que una aceptación de G1..G6 NO modifica

- `FlowGraph` authored permanece read-only; IDs estables, orden definido y schema 3/4 sin migración.
- `FlowFSMRuntime` continúa perteneciendo a cada `PVController`; no guardar estado debug en recursos, `user://`, `.bak` ni formato FSM-004.
- Se conservan `machine_started`, `state_updated`, `event_consumed`, `request_rejected`, `transition_committed`, `direct_transition_committed` y `work_budget_deferred` con firma y orden existentes.
- Ready/Timer, colas FIFO, prioridades, cuotas, reentrancia y stops idempotentes no cambian al habilitar/deshabilitar captura.
- Sin telemetría de red ni código `Editor*` dentro del runtime. No `main`, merge, release ni revisión humana automática.
- La **fase 9 sigue condicionada** por F5–F7/F7R, F9 y política F10. No tocar archivos del usuario ni inventar recuperación.

## Tras una aprobación explícita

1. Registrar el texto aprobado de G1..G6, fecha, alcance y commit como `DEBUG-FSM v1.0 accepted`; parámetros no aprobados permanecen propuestos.
2. Invocar **formalmente** `$flujo-baseline` en entorno con Godot 4.7.2, determinar READY/BLOCKED. Si no es posible, no afirmar cumplimiento ni ejecutar refactor productivo.
3. Preparar **10B-1A RED** aislado para la API contratada; documentar fallo esperado sin convertirlo en gate permanente.
4. **10B-1B GREEN** con la implementación mínima de anillo opt-in y tests de copia, saturación y ausencia de efectos secundarios; agregar gate CI sólo cuando GREEN, invocar `$flujo-prove` y ejecutar regresiones.
5. Extender por microbloques a lectura inicial y decisiones arbitradas, manteniendo observabilidad separada de controles/UI. Revisión Fedora/Android cuando corresponda.

## Estado y forma de decisión

- **Hoy:** G1–G6 **PENDIENTES**; G7/G8 fuera de alcance. Ni `🙆🏻` de continuidad, ni PASS de CI, ni este documento constituyen aceptación de las elecciones.
- **Respuesta positiva inequívoca propuesta:** «Apruebo G1–G6 como están descritos en `docs/fsm_phase10_10a15_approval_decision_sheet.md` para implementar únicamente 10B-core, sin G7/G8». Si el responsable desea cambios, debe indicar el gate y el valor alternativo; se actualiza la propuesta antes de congelar contrato.
- **Alternativa válida:** «No apruebo todavía 10B-core; continuar sólo con pruebas/documentación no productivas».

**Veredicto de 10A-15:** tres microbloques de preflight 10A-13/14/15, separados de la implementación; toda la fase 10 continúa abierta hasta nueva evidencia y decisión.

*Todo es Flujo; todo fluye.* 🌊
