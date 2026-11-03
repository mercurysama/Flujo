# Potok 10A-2 — Contrato propuesto de observabilidad DEBUG-FSM v0

**Fecha:** 2026-11-03. **Rama:** `feature/fsm-runtime-flow-flusso`. **Base:** `a3d56ae874da2ee1a9b94d9922191b40bfcda238`, [auditoría 10A-1](fsm_phase10_10a1_diagnostics_audit.md). **Estado:** **PROPUESTA DE CONTRATO, NO APROBADA PARA MODIFICAR EL RUNTIME**. Sólo caracteriza y delimita futuras implementaciones. Conserva FLU-FSM-001/002/003/004 y FSM-R27/R28.

## Vocabulario y esquema mínimo candidato

Un **registro** representa una observación, nunca una orden de ejecución. Se propone un diccionario inmutable para el consumidor, compuesto sólo de valores escalares JSON-safe:

| Campo | Tipo | Regla |
|---|---|---|
| `version` | int | Fijo a `1` para el contrato de observabilidad, **distinto** de `FlowGraph.schema_version` y `snapshot.format_version` |
| `sequence` | int | Estrictamente creciente dentro del runtime, no global ni entre controladores |
| `tick` | int | Contador por runtime, aumenta solamente al entrar al procesamiento de un tick válido; `0` para observaciones previas al primero |
| `machine_id` | String | ID authored estable de máquina; para rechazo de ID desconocido se conserva el valor provisto, sin inventar identidad |
| `state_id` | String | Estado activo al observar; `""` si no existe |
| `from_state_id`, `to_state_id` | String | Vacíos si el evento no representa una transición concreta |
| `request_kind` | String | `direct`, `event`, `condition`, `lifecycle` u `other`; no reinterpretar el contrato original |
| `event_name` | String | Nombre, sin payload salvo normalización expresamente segura |
| `trigger_id` | String | ID authored de transición o `direct`; nunca el índice visible |
| `stage` | String | `admission`, `consumption`, `arbitration`, `commit`, `lifecycle` |
| `outcome` | String | `accepted`, `rejected`, `consumed`, `matched`, `not_matched`, `skipped`, `committed`, `deferred` |
| `diagnostic_code` | String | Código estable (p. ej. `queue_full`, `invalid_target`), vacío sin fallo |
| `phase` | String | `Enter`, `Update`, `Exit` o vacío; no suponer que persiste entre callbacks |

El esquema **no se serializa** en FSM-004. No almacena un `Variant` arbitrario, objeto `Node`, recurso ni diccionario de usuario. El eventual detalle de condición debe registrar el **resultado ya calculado** y su código de falla, jamás evaluar otra vez.

## Cláusulas verificables propuestas

**DEBUG-01 (aislamiento).** Cada `PVController` sólo puede exponer registros de su propia `FlowFSMRuntime`; ni buffer ni secuencia son compartidos. **Prueba:** dos controladores con un mismo `FlowGraph`, eventos intercalados, registros separados.

**DEBUG-02 (orden).** Cada observación recibe `sequence` monotónica y preserva el orden real de emisión; no altera la precedencia FIFO/prioridad de FSM-002. **Prueba:** evento consumido → Exit → Enter → commit; 1 transición máximo por máquina/tick.

**DEBUG-03 (ciclos).** Un tick ignorado por runtime parado, instancia inválida, inhibición de ejecución o reentrancia no aumenta el contador propuesto. **Prueba:** llamada tick inválida y comparación de secuencia.

**DEBUG-04 (decisiones).** Distinguir solicitudes admitidas/rechazadas, eventos consumidos, condiciones false/error y transiciones aplicadas, saltadas o sin coincidencia; la selección se registra **después de usar** la condición original. **Prueba:** candidato inválido/no-op, condición true/false, prioridad y diferimiento.

**DEBUG-05 (diagnósticos).** Reutilizar sin renombrar los códigos de `request_rejected` y `FlowDiagnostic` donde correspondan; errores de snapshot mantienen su preflight y clasificación propia. **Prueba:** rechazo no modifica cola, grafo ni estado.

**DEBUG-06 (copias y privacidad).** Todo valor expuesto es inerte, acotado y desacoplado; sin referencias a datos anidados de eventos, `Node`, `Resource` ni `FlowGraph`. **Prueba:** mutar una lectura no modifica la FSM ni las lecturas siguientes.

**DEBUG-07 (presupuesto).** Antes de integrar historial, aprobar un límite explícito de registros por controlador; cuando el buffer esté lleno, descartar el registro más antiguo sin cambiar la cola real. No usar las cuotas 256/32 de ejecución como límite implícito del depurador. **Prueba:** insertar más del límite y comprobar orden, memoria acotada y ejecución equivalente.

**DEBUG-08 (cierre).** Terminar controlador/escena invalida acceso a la vista viva y limpia historial, sin forzar callbacks ni publicaciones durante teardown. **Prueba:** liberar A con B vivo y comparar.

**DEBUG-09 (portabilidad).** Productivo en `runtime/` sin clases `Editor*`, `EditorPlugin`, plataforma específica, I/O externo ni telemetría. La vista de editor se conecta como observador y nunca fuente de verdad. **Prueba:** importación y suite runtime headless/exportabilidad.

**DEBUG-10 (autoridad).** Inspección es **read-only**. Edición de valores en vivo, pausa, reanudación y paso manual precisan contrato y autorización diferenciada; no tocan `FlowGraph` automáticamente. **Prueba:** lectura y cierre sin alteración de recursos.

**DEBUG-11 (retrocompatibilidad).** Señales públicas existentes conservan firma y orden; el observador no induce nuevas transiciones, no cambia resultados de Ready/Timer y no crea comandos. **Prueba:** regresiones FSM-5A/5G/6F, Ready, Timer y esquemas 3/4.

**DEBUG-12 (evidencia).** Un test escrito sin ejecución real se registra `NOT RUN`; `RED` esperado se distingue de `PASS`. CI y aceptación humana son gates separados. **Prueba:** resultados y enlaces concretos al mismo commit.

## Límites de autorización y próximos cortes

- **Aprobable sin cambios funcionales (10A-3):** caracterizar señales existentes, su orden, códigos, copias y aislamiento; añadir una focal y su gate CI sin modificar API pública ni persistencia.
- **Pendiente de decisión del mantenedor para 10B:** (a) capacidad exacta del buffer circular, (b) costo/activación por defecto y control de suscripción, (c) semántica de eventos `accepted` vs `consumed` en candidatos no ganadores, (d) elección entre un observador adaptador y nueva señal estructurada, (e) campos permitidos para diagnósticos de condición. No autorizar implementación productiva por inferencia de este borrador.
- **Sin modificar:** snapshot v1, política de `.bak`, F5–F7/F7R/F9/F10, revisión humana 0/25, API SDK y vista Fluo.

## Verificación de este microprompt

**10A-2: CONTRATO PROPUESTO.** Comprobación documental contra [10A-1](fsm_phase10_10a1_diagnostics_audit.md), `flow_fsm_runtime.gd` y fase 10 del plan. Ejecutar Godot/Skills/CI del presente commit: **NOT RUN** al redactar; no afirmar READY, PASA, ni aceptación arquitectónica. **Siguiente:** 10A-3, caracterización exclusivamente observacional mediante señales públicas ya presentes.

*Todo es Flujo; todo fluye.* 🌊
