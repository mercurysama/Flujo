# Potok 10A-1 — Auditoría de observabilidad y diagnósticos existentes

**Fecha:** 2026-11-03. **Rama:** `feature/fsm-runtime-flow-flusso`. **HEAD de entrada:** `dfae6d0ea2ab1743383ec98994dbc5b0e59e8b4f`. **Alcance:** solo inventario y riesgos; sin cambio productivo. **Fuente normativa:** `docs/fsm_implementation_plan.md`, fase 10 (DEBUG-FSM), FSM-R27/R28, y contratos FLU-FSM-001/002/003/004.

## Inventario verificado en la rama

| Fuente concreta | Capacidad existente y reutilizable | Límite actual |
|---|---|---|
| `addons/vp_flujo/runtime/flow_fsm_runtime.gd` | Señales `machine_started`, `state_entered`, `state_updated`, `state_exited`, `machine_stopped`; `get_active_machine_ids`, `get_active_state_id`, `is_running` | No exponen fase actual persistida, secuencia/tick ni snapshot de inspección completo |
| Mismo runtime | `event_consumed(machine_id,event_name,payload)`; `request_rejected(machine_id,kind,code)`; `work_budget_deferred(machine_id,deferred_count)` | Las solicitudes aceptadas no tienen señal propia; no hay auditoría de candidatos no elegidos ni contexto de por qué se rechazaron durante arbitraje |
| Mismo runtime | `transition_committed(machine_id,from,to,trigger_id)` y `direct_transition_committed(...,reason,payload)` | Sólo transiciones aplicadas; no hay resultado estructurado de condición false, tipo erróneo, destino ausente en reevaluación o autotransición no-op |
| Mismo runtime | Cola FIFO 256 por controlador, 32 paquetes/máquina/tick, cadena máxima 8; `_in_tick`, solicitudes diferidas, aislamiento del `PVController` | Son **presupuestos de ejecución**, no presupuestos de historial de depuración |
| `pv_controller.gd` | Cada controlador posee su `FlowFSMRuntime`, `get_fsm_runtime()` y relojes PROCESS/PHYSICS; disponibilidad de contexto de valores | No exponer objetos vivos ni convertir el recurso compartido en fuente de diagnóstico mutable |
| `flow_fsm_operations.gd` | SDK acotado y validaciones de capacidad/ciclo de vida | No duplicar la interfaz de depuración en el SDK de ejecución |
| `flow_fsm_data_validator.gd` | Límites JSON seguros: profundidad 8, 256 entradas y 65536 caracteres | Sus límites de persistencia no fijan una cuota de trazas |
| `runtime/model/flow_diagnostic.gd`, `FlowGraphValidator` | Códigos estables de validación y severidades, incluido conjunto FSM | Diagnóstico de definición, no rastro cronológico de eventos runtime |
| `flow_ready_executor.gd` y `flow_runtime_output.gd` | Ejecución común Enter/Update/Exit con etiquetas de entrada y señales de salida contextual | Señales de mensajes de bloque no equivalen a causas de transición; evitar duplicar Ready/Timer |
| `flow_fsm_snapshot_codec.gd` / `flow_fsm_runtime.gd` | Preflight de restauración y advertencias `push_warning` | Error de snapshot no expuesto como registro FSM estructurado; **no** cambiar semántica de FSM-004 en fase 10 |

## Requisitos vs. brechas (fase 10 original)

1. **Eventos estructurados + buffer circular:** **NO IMPLEMENTADO**. Señales existentes permiten una caracterización sin tocar la lógica.
2. **Inspección de máquinas, ID, estado y fase:** **PARCIAL**. APIs de estado activo existen; falta proyección de lectura con fase/candidato/última transición.
3. **Diagnóstico distinguible:** **PARCIAL**. Rechazos de admisión usan códigos estables; condiciones, alternativas de arbitraje y restauración no comparten un esquema.
4. **Contexto de valores sin efectos de autoría:** **PENDIENTE**. Se necesita una vista separada, filtrada y profundamente copiada; no ofrecer referencias directas de `FlowGraph`.
5. **Pausa, reanudación y avance por tick:** **PENDIENTE** como controles de depuración. `MANUAL` es un reloj existente, no una autorización para cambiar políticas de pausa.
6. **Memoria, limpieza y portabilidad:** **PENDIENTE** para historial. El buffer debe vivir por instancia, ser acotado y limpiarse al terminar la escena; no depender del editor.

## Tests existentes que caracterizan comportamientos

- `tests/runtime/flow_fsm_admission_diagnostics_test.tscn`: rechazos, códigos, overflow, reserva de cola y parada.
- `tests/runtime/flow_fsm_event_order_test.tscn`: eventos sin transición, prioridad, orden y diferimiento.
- `tests/runtime/flow_fsm_direct_request_metadata_test.tscn`: FIFO, metadatos desacoplados y compatibilidad de señales.
- `tests/runtime/flow_fsm_deterministic_dual_controller_test.tscn`: aislamiento y repetibilidad.
- `tests/runtime/flow_fsm_engine_clocks_test.tscn` y `tests/runtime/flow_ready_runtime_test.tscn`: relojes y Ready; Timer requiere su focal específica.
- `.github/workflows/flujo-fsm.yml`: regresión remota de Godot 4.7.2; último baseline histórico comprobado: [41730691563](https://github.com/mercurysama/Flujo/actions/runs/41730691563) SUCCESS en `dfae6d0`.

## Riesgos y decisiones reservadas

- Observar una condición no debe **reevaluarla**: se alterarían efectos, orden y determinismo.
- No conservar referencias a `Node`, `Resource`, `FlowGraph`, `Callable` ni payloads editables. Definir normalización/copia segura y presupuesto antes de instrumentar.
- No insertar eventos que cambien el orden de señales públicas ni ejecutar callbacks durante decisiones intermedias sin contrato.
- Distinguir **consumido**, **aceptado**, **rechazado**, **sin coincidencia**, **descartado** y **aplicado**.
- No atribuir fase de editor a fase de ejecución; no añadir dependencias del editor al runtime.
- **Deuda ajena y preservada:** fase 9 condicionada, F5–F7/F7R y F9 sin autorización de política, F10 sin recuperación automática, 25 pruebas humanas pendientes.

## Gate, justificación y próximo bloque

**10A-1: AUDITADA / documentación lista.** El inventario proviene de código y contratos en `dfae6d0ea2ab1743383ec98994dbc5b0e59e8b4f`, **no** de una ejecución local de Godot. `$flujo-baseline` y `$flujo-prove` se consultaron como archivos versionados; invocación formal y pruebas locales: **NOT RUN** (sesión de conector GitHub). No afirmar READY/PASA. Historial CI citado es evidencia histórica, no del presente commit.

**10A-2:** congelar un contrato mínimo de observabilidad **propuesto**, sin modificar comportamiento ni publicar APIs todavía. **10A-3:** caracterizar, con señales existentes, separación de dos controladores, orden y no mutación de grafo; integración en CI y veredicto únicamente tras ejecución real. Alternativa descartada: crear de inmediato un panel o un `DebugManager` paralelo.

*Todo es Flujo; todo fluye.* 🌊
