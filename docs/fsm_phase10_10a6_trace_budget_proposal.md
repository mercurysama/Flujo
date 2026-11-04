# Potok 10A-6 — Presupuesto de observabilidad y política de retención (PROPUESTA)

**Fecha:** 2026-11-03. **Rama:** `feature/fsm-runtime-flow-flusso`. **HEAD base:** `0c2204c71fa85704aa63cc0113851ae19f208e5c`. **Naturaleza:** análisis y plan de pruebas, **sin contrato aprobado, sin cambio productivo y sin tests RED que aparenten PASS**. Conecta [10A-1](fsm_phase10_10a1_diagnostics_audit.md), [10A-2](fsm_observability_contract_proposal_v0.md), [10A-4](fsm_phase10_10a4_conditions_characterization.md), [10A-5](fsm_phase10_10a5_lifecycle_characterization.md) y la fase 10 de `fsm_implementation_plan.md`.

## 1. Presupuestos actuales confirmados por código

| Subsistema | Límite actual | Naturaleza |
|---|---:|---|
| `FlowFSMRuntime.MAX_PENDING_REQUESTS` | 256 | Solicitudes en cola por controlador; no es capacidad de trace |
| `MAX_REQUESTS_PER_MACHINE_TICK` | 32 | Solicitudes entregadas por máquina y tick coincidente |
| `MAX_CHAIN_HOPS` | 8 | Saltos heredados de una cadena de callbacks |
| `MAX_DYNAMIC_STATES` | 128 | Estados dinámicos por máquina |
| `FlowFSMDataValidator.MAX_DEPTH` | 8 | Profundidad de datos serializables |
| `FlowFSMDataValidator.MAX_ENTRIES` | 256 | Entradas permitidas por estructura |
| `FlowFSMDataValidator.MAX_JSON_LENGTH` | 65536 | Caracteres del JSON para datos seguros |
| Historial de diagnósticos FSM | **No existe** | Sin cuota actual, sin API de lectura, sin política de suscripción |

Los topes actuales **no** justifican un tamaño de buffer ni una cuota de tiempo de CPU para eventos de observación. No atribuir overhead medido: **not measured**.

## 2. Opciones arquitectónicas (sin decisión)

| Alternativa | Ventaja | Riesgo/contrato requerido | Estado |
|---|---|---|---|
| A. Adaptador externo conectado a señales existentes | No instrumenta arbitraje, conserva el runtime | No observa condiciones false, self/no-op, rechazos intermedios ni el arranque que ya ocurrió; depende del ciclo de vida del observador | Reutilizable solo para trazas **parciales**, no suficiente para DEBUG-FSM |
| B. Señal estructurada nueva con observador externo | Registro en tiempo real sin necesariamente retener historial en runtime | Orden público, señales reentrantes, suscripciones, costo de normalización, cierre y payload inerte | Requiere autorización |
| C. Buffer circular por `FlowFSMRuntime` con lectura desacoplada | Inspección tardía e historial limitado por instancia, sin depender de editor | Reserva de memoria, tamaño, costo por tick, descarte, secuencia, teardown, habilitación y seguridad de datos | Requiere autorización |
| D. Combinación B+C con captura activable | Ofrece historial y notificación, manteniendo ruta sin suscriptores | Más superficie de API y pruebas; evitar doble registro y comportamientos dependientes del observador | Requiere autorización específica |

**Recomendación para evaluar, no implementar:** modelar un buffer circular opcional por runtime que acepte sólo registros compactos y permita lectura por copia, más una capa adaptadora de UI. Antes de elegir capacidad, determinar en tests cómo se comporta sin suscripción y con cargas de 0/1/muchas FSM. El nombre, visibilidad y activación de cada API quedan abiertos.

## 3. Reglas candidatas de minimización

1. No guardar payloads completos: conservar únicamente nombre de evento, IDs, causas/resultado y códigos; los campos de texto deben truncarse mediante una regla aprobada y medible antes de activar producción.
2. No conservar `Object`, `Resource`, `Node`, `Callable`, referencias de `FlowGraph` ni contextos de valor; ningún evento de depuración es mutable desde el consumidor.
3. No reevaluar condiciones para obtener un log: el resultado debe capturarse en el mismo punto lógico de la evaluación existente.
4. Establecer un límite de **cantidad** y un límite separado de **bytes/caracteres aproximados**; descartar registros antiguos sin tocar cola FSM, IDs activos, transición ni comportamiento de Ready/Timer.
5. Los observadores no deben permitir reentrada accidental durante arbitraje. Determinar si se publica luego del commit o desde un colector diferido.
6. Limpiar en `stop` y teardown; al reconectar un depurador distinguir captura de estado actual de cualquier historial conservado. Nunca persistir historial dentro de snapshot FSM-004.
7. No activar registro por defecto en compilaciones exportadas sin autorización explícita; evitar telemetría de red y dependencias de editor.

## 4. Matriz de pruebas propuesta para 10B (NO EJECUTADA)

| ID candidato | Escenario | Resultado aceptable | Gate |
|---|---|---|---|
| OBS-B01 | Captura deshabilitada, 0 observadores | Mismos resultados FSM y memoria incremental nula o dentro del presupuesto aprobado | RED → GREEN luego de contrato |
| OBS-B02 | Más registros que capacidad aprobada | FIFO circular conserva últimos N y secuencia monotónica, sin cambiar prioridades ni colas | RED → GREEN |
| OBS-B03 | Máquinas múltiples en dos controladores con mismo grafo | Buffers, IDs, secuencias y cierres aislados | RED → GREEN |
| OBS-B04 | Payload mutable anidado, datos excesivos o `Node` | No referencias vivas ni filtración de objetos; rechazo/truncado conforme a contrato | RED → GREEN |
| OBS-B05 | Condición false, true, self, inválida | Una sola evaluación original, causas inequívocas, mismos commits | RED → GREEN |
| OBS-B06 | Conexión tardía del depurador | Se obtiene estado inicial de inspección read-only sin fingir historia previa | RED → GREEN |
| OBS-B07 | Pausa, reinicio, stop, escena destruida y callbacks | Sin reentrada, dobles Exit ni historial huérfano | RED → GREEN |
| OBS-B08 | Esquemas 3/4, Ready, Timer, SDK y export | Igual comportamiento observable y sin clases de editor | Regresiones integrales |
| OBS-B09 | Ciclos repetidos, colas saturadas, 128 dinámicos | Captura acotada bajo carga; números de costo registrados, sin inferencias | Benchmark separado |
| OBS-B10 | Persistencia/restore v1 | No aparece trace en archivo ni se altera preflight/rollback | FSM-004 regresión |

Estos IDs **no** son nuevas entradas del catálogo: faltan APIs y decisiones, por lo que no se registra un falso test `automatic` ni un PASS.

## 5. Decisiones reservadas para aprobación humana del diseño de 10B

- **10B-G1:** capacidad máxima N por controlador, cuota de caracteres/registro, límite global y qué sucede al llegar al máximo (preferencia: sobrescribir el más antiguo).
- **10B-G2:** captura activada por defecto/desactivada por defecto, suscripción activa y exportación; sin costo de depuración en un build que no la usa.
- **10B-G3:** formato público y propiedad del rastro: adaptador sobre señales, señal nueva, circular de runtime o combinación; elegir una fuente única de orden.
- **10B-G4:** definición de `accepted`, `consumed`, `matched`, `not_matched`, `skipped`, `committed`; en particular las solicitudes admitidas pero descartadas por arbitraje.
- **10B-G5:** datos permitidos de condición y privacidad, normas de sanitización, propiedad de clones, ausencia de referencias mutables.
- **10B-G6:** política de inicialización para observadores tardíos, limpieza tras stop y accesibilidad desde vista de Godot exportado.

**Estado de gates:** ninguna política anterior queda autorizada por continuidad. `$flujo-baseline` y `$flujo-prove`: documentos revisados, no invocación formal en entorno local; Godot local: **NOT RUN**. Esta entrega documental se verificará por GitHub Actions del commit correspondiente, pero el workflow no demuestra rendimiento real o aceptación de API.

## 6. Siguiente tanda sugerida — independiente de las decisiones 10B

- **10A-7:** revisar el CI de 10A-4/5/6, resolver cualquier RED real sólo en tests de caracterización cuando corresponda, y certificar catálogo **sólo** tras PASS integral.
- **10A-8:** matriz detallada de integración del depurador nativo Godot y la separación de Fluo; sólo inventario de superficies, sin crear UI.
- **10A-9:** propuesta final de contrato v1 y revisión de trade-offs para aprobación de 10B; si una decisión sigue sin autorización, no modificar runtime.

**Invariantes:** `main` intacta; sin cambio de esquema, snapshots, APIs SDK, persistencia F5–F7/F9 o aceptación manual diferida 0/25.

*Todo es Flujo; todo fluye.* 🌊
