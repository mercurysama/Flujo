# Potok 8D2-B2A — Snapshot de alias transitorios activos y orden estable

**Fecha:** 2026-11-02 (America/Mexico_City). **Rama única:** `feature/fsm-runtime-flow-flusso`. **Resultado:** **PASS CI 93/93**, caracterización de la frontera FSM-003/FSM-004; **Fase 9 y Fase 8 completas: NO**.

## Escenario real

La nueva escena `tests/runtime/flow_fsm_snapshot_transient_active_test.tscn` crea **tres máquinas MANUAL** con sendos estados authored inicial y plantilla, en el mismo `FlowGraph` esquema 3, compartido por dos `PVController` con runtimes separados. Registra **nueve alias**, con orden intercalado de lifetimes (seis `PERSISTENT`, un `EPHEMERAL`, dos `SESSION`). Tras admitir tres solicitudes y ejecutar un tick manual: la primera máquina tiene activo un alias `EPHEMERAL`, la segunda uno `SESSION`, y la tercera un alias `PERSISTENT`.

El snapshot exportado usando **`FlowFSMRuntime.export_snapshot()` y el `FlowFSMSnapshotCodec` existente** mantiene `format_version=1`, `graph_id` y `schema_version`. En `machines`, las dos primeras máquinas registran sus **estados iniciales authored** como recuperables, mientras la tercera conserva el **ID del alias persistente activo**. Los tres registros siguen el orden de `graph.state_machines`; no se filtran IDs transitorios al documento.

En `dynamic_states`, los seis registros `PERSISTENT` se mantienen agrupados por máquina y en su orden de registro, incluso donde fueron intercalados con alias transitorios. Se comprueba igualdad exacta de la estructura, IDs, lifetimes y datos anidados JSON-safe. La exportación **no modifica las máquinas activas ni registros originales**; mutar el objeto exportado no altera el siguiente snapshot. Dos exportaciones sin cambios producen contenido idéntico.

El segundo controlador comienza con un alias propio `SESSION`, restaura explícitamente el snapshot mediante `restore_snapshot` y queda con los seis registros persistentes, en el orden verificado, y estados activos authored/authored/persistente como se esperaba. Una reexportación del receptor coincide con la exportación original. Modificar metadatos del receptor **no afecta** al controlador origen. Ningún paso cambia definiciones authored ni infraestructura productiva de persistencia.

## Evidencia de GitHub y regresiones

- **Baseline anterior:** `50fe20def6c91a3b59ef11d54ff3e701583392cb`, [Actions 41578626503](https://github.com/mercurysama/Flujo/actions/runs/41578626503), **SUCCESS 92/92**.
- **Commit focal:** `78a9a7d265ddad369f2473de661b01bb906d3fe5`, añade `tests/runtime/flow_fsm_snapshot_transient_active_test.gd` y `.tscn`, la comprobación obligatoria `Potok-8D2B2A transient snapshot active fallback and ordering focal` a `.github/workflows/flujo-fsm.yml`, y comportamiento `FLUJO-BHV-POTOK-SNAPSHOT-TRANSIENT-003` con `not_run` inicialmente.
- **CI verificado:** [Actions 41579446980](https://github.com/mercurysama/Flujo/actions/runs/41579446980), **completed SUCCESS 93/93** en Godot 4.7.2: focal **PASS**, validador del catálogo y regresiones existentes también **PASS**, sin pasos fallidos ni omitidos. Entrada del catálogo elevada a `passing` **después** de obtener la prueba.
- **Código productivo cambiado:** 0 archivos. Se preservaron `FlowFSMSnapshotCodec`, el formato v1, `FlowFSMRuntime`, editor, `main`, esquemas y `demo/main.tscn`.

## Alcance, reserva y siguiente microbloque

**8D2-B2A caracterizó un contrato ya funcional, no inventó una persistencia nueva.** `FLU-FSM-004` pertenece a **Fase 9** y conserva su responsabilidad de exportar/restaurar de manera segura; esta prueba no acredita recuperación automática al reinicio ni revisa toda la seguridad de archivos. No se ejecutó Godot local; los procedimientos de skills versionadas se leyeron como documentación y no se invocaron formalmente. **15 pruebas humanas Fedora y 10 Android siguen PENDING (0/25)**.

**Siguiente: 8D2-B2B**, caracterizar el rechazo atómico de snapshots inválidos con estados/registries/colas existentes; reutilizar cobertura de `flow_fsm_snapshot_test.tscn`, añadir solo el hueco necesario, no cambiar el codec sin una falla reproducida y aprobación de contrato. Revisar HEAD, Actions y [plan 8D2](fsm_phase8_8d2_microblocks.md) antes de empezar.

*Todo es Flujo; todo fluye.* 🌊
