# Potok 8D2-B1A — Matriz de lifetimes con reset y controlador independiente

**Fecha:** 2026-11-02 (America/Mexico_City). **Rama exclusiva:** `feature/fsm-runtime-flow-flusso`. **Resultado:** PASS automatizado de caracterización del runtime existente; **8D2 completo: NO**.

## Contrato y escenario

Para la [auditoría 8D2-A](fsm_phase8_8d2a_audit.md) y [plan 8D2](fsm_phase8_8d2_microblocks.md), la prueba `tests/runtime/flow_fsm_lifetime_reset_matrix_test.tscn` crea un `FlowGraph` schema 3 con una máquina manual, dos estados authored y **dos controladores** separados que comparten las definiciones. En el controlador A registra tres alias, en este orden, con datos anidados JSON-safe:

- `EPHEMERAL`: activo en el momento de reset;
- `SESSION`: inactivo y con datos anidados a conservar;
- `PERSISTENT`: inactivo y con datos anidados a conservar.

A emite dos solicitudes pendientes antes de reset (una directa hacia `SESSION` y un evento sin destino); B conserva su propio alias `SESSION` y una solicitud directa hacia el estado authored de plantilla. El escenario no exporta snapshots, no cambia el contrato FLU-FSM-004 y no escribe al grafo.

## Aserciones comprobadas

1. El alias EPHEMERAL se activa correctamente mediante transición en un tick manual, sin residuos de cola. `reset()` ejecutado fuera del tick es aceptado y su secuencia de salida/entrada **es exactamente** `StateExit:worker-exit → state_exited(alias) → StateEnter:idle-enter → state_entered(initial)`, sin una transición de la cola.
2. `reset()` elimina EPHEMERAL; su ID, lifetime y datos dejan de estar disponibles; no se pueden emitir nuevas solicitudes hacia él.
3. `SESSION` y `PERSISTENT` conservan los mismos IDs, lifetimes, orden de registro y datos anidados después de reset; los cambios realizados sobre los datos de entrada y lecturas previas no contaminan el runtime. Ambos alias pueden activarse posteriormente, en ticks distintos.
4. Solo la cola de A se vacía. B mantiene su alias, datos, estado inicial, solicitud pendiente y ausencia de callbacks causados por el reset de A. Al avanzar B explícitamente, su transición se completa sin modificar A.
5. `FlowGraph`, `FlowStateMachineDefinition.states` y validez de definiciones permanecen intactos. No se cambió código productivo, UI, schemas, snapshots ni otras ramas.

## Trazabilidad y ejecución

- Baseline previo: `a81af3ebb42efa101c5336381a831c5244f7ff07`, [Actions 41576142513](https://github.com/mercurysama/Flujo/actions/runs/41576142513), **SUCCESS 90/90**.
- Commit de prueba `7d9f702c1eef19af52d7ba90a600bf153eeb204e`: nuevo `tests/runtime/flow_fsm_lifetime_reset_matrix_test.gd/.tscn`, paso obligatorio **Potok-8D2B1A lifetime policy reset and controller isolation focal** en `.github/workflows/flujo-fsm.yml`, y catálogo `FLUJO-BHV-POTOK-LIFETIME-RESET-001` inicialmente `not_run`.
- [Actions 41576973539](https://github.com/mercurysama/Flujo/actions/runs/41576973539): **completed SUCCESS 91/91**, Godot 4.7.2, focal B1A **PASS**, regresiones previas **PASS**. Tras confirmar el resultado, la entrada del catálogo se cambia a `passing` en checkpoint documental.
- Los resultados previos de FSM-003, FSM-004, 8B, 8C y 8D1-C siguen disponibles y no se sustituyen por el nuevo test. Godot local **NOT RUN**. Skills versionadas consultadas pero **no invocadas formalmente**. No hay revisión humana: **25 pruebas pendientes** de Fase 7 (15 Fedora, 10 Android).

## Límites y recuperación

Esta caracterización cubre **reset** con un alias temporal activo y un segundo controlador independiente. **No cubre stop/restart** como matriz integral de las tres políticas, ni aprobación visual, ni un snapshot con alias transitorio activo; esos escenarios siguen reservados a pasos independientes del plan. No se observa defecto de producción en B1A y por tanto no se justifica modificar `FlowFSMRuntime`.

**Siguiente microbloque: 8D2-B1B**. Confirmar antes el HEAD real y Actions; caracterizar el cierre y reinicio de un mismo `PVController`, limpieza de los tres lifetimes y solicitudes previas, caducidad de cualquier SDK retenido e independencia del segundo controlador. Añadir prueba, catálogo y gate, revisar CI antes de señalar PASS. Conservar el codec snapshot de la Fase 9.

*Todo es Flujo; todo fluye.* 🌊
