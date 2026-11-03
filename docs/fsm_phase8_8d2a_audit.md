# Potok 8D2-A — Auditoría de duraciones, reinicios, snapshots y determinismo

**Fecha:** 2026-11-02 (America/Mexico_City). **Rama exclusiva:** `feature/fsm-runtime-flow-flusso`. **HEAD de partida:** `ad73a4816849556810dd62047d468decdd562a9f`. **Tipo:** revisión y planificación, **sin alterar código productivo ni expectativas de prueba**.

**Baseline confirmada:** [GitHub Actions 41575182608](https://github.com/mercurysama/Flujo/actions/runs/41575182608), Godot 4.7.2, **completed SUCCESS 90/90**, incluido el validador del catálogo y los tests `FSM 003 dynamic states`, `FSM 004 snapshot`, 8B1, 8B2, 8C1, 8C2 y SDK 8D1-C. Inspeccionados sus nombres, estados y marcadores de ejecución. No se ejecutó Godot local en esta auditoría.

## Alcance y límites contractuales

- **Fase 8 / FSM-003:** [FLU-FSM-003](fsm_dynamic_contract_v1.md) define registro de alias runtime aislados, semántica de vida, eliminación, cola y ausencia de mutación del grafo. El plan [8A](fsm_phase8_8a_gap_audit.md) reservó **8D2** para aislamiento, determinismo, reset, stop y políticas `EPHEMERAL`/`SESSION`/`PERSISTENT`.
- **Fase 9 / FSM-004:** [FLU-FSM-004](fsm_snapshot_contract_v1.md) define snapshots, `user://`, validación y restauración. **Ya existen** `FlowFSMSnapshotCodec`, `FlowFSMRuntime.export_snapshot/restore_snapshot/save_to_file/restore_from_file` y test automatizado. Aquí solo se comprobará **compatibilidad y cobertura adyacente**, no se declarará implementada ni cerrada la Fase 9.
- **Requisitos:** `FSM-R17..R22` y determinismo general del plan; la frontera con `FSM-R20..R22` de FSM-004 se conserva sin cambiar el contrato de snapshots. `PVController` controla inicio/cierre por instancia; las máquinas y controladores no comparten registro.
- Los snapshots guardan **solo** aliases PERSISTENT. `EPHEMERAL` termina en reset/teardown; `SESSION` y `PERSISTENT` sobreviven reset; **los tres** se pierden al detener y reconstruir el runtime, salvo la restauración explícita de PERSISTENT mediante snapshot. En snapshots, un alias no persistente activo se representa mediante el inicial authored de su máquina, conforme a FLU-FSM-004.

## Inventario código → cobertura histórica → brecha a caracterizar

| Ámbito | Implementación existente (sin cambios) | Evidencia automática disponible | Cobertura adicional recomendada — **no es defecto confirmado** |
| --- | --- | --- | --- |
| Registro y orden | `FlowFSMDynamicStateRecord.Lifetime`; `FlowFSMRuntime.register_state/get_dynamic_state_ids` | `flow_fsm_dynamic_quota_identity_test.tscn`: cuota 128, IDs, orden, re-registro e aislamiento | Cruce de las tres políticas con `reset`, estado activo, datos y múltiples máquinas en un mismo escenario determinista |
| Reset | `FlowFSMRuntime.reset` preflight de estados iniciales, clear cola, Exit previo, filtro de EPHEMERAL, Enter inicial | `flow_fsm_snapshot_test.tscn`: los tres lifetimes y destino inicial; `flow_fsm_sdk_lifecycle_guards_test.tscn`: secuencia de callbacks y alias SESSION | Verificar orden de señales y datos tras reset con alias **EPHEMERAL activo** y cola mixta. Comportamiento con solicitudes emitidas por callbacks: caracterizar sin presumir resultado |
| Stop y nuevo runtime | `FlowFSMRuntime.stop`; `PVController._stop_state_machines/_start_state_machines`, deshabilitar y reactivar | `flow_fsm_dynamic_test.tscn`: eliminación por stop; `flow_fsm_sdk_lifecycle_guards_test.tscn`: nueva instancia y facades expiradas; `flow_fsm_runtime_test.tscn`: dos controladores independientes | Matriz de las tres políticas antes/después de teardown/restart; preservar otro controlador y no recuperar queues antiguas |
| Snapshot y vida | `FlowFSMSnapshotCodec.make_snapshot/prepare`; `export_snapshot/restore_snapshot` | `flow_fsm_snapshot_test.tscn`: PERSISTENT incluido, EPHEMERAL/SESSION omitidos, round-trip, fallback y reemplazo, aislamiento entre controladores | Caracterizar **alias EPHEMERAL/SESSION activo** al exportar (fallback inicial), y orden de múltiples máquinas y aliases registrados, sin modificar FLU-FSM-004 |
| Validación/restauración | `prepare` valida forma, formato, grafo, máquinas, IDs, plantillas, cupo, tipos y datos; `restore_snapshot` preflight previo al commit, Exit, swap, vacía cola, Enter | `flow_fsm_snapshot_test.tscn`: versión inválida, plantilla ajena, objeto vivo, JSON corrupto; `save_to_file` mantiene `.bak` | Distinguir fallos no cubiertos (graph/schema ID, IDs duplicados, máquina desconocida, límite, archivo/path inválido), comprobar **no mutación de estado y cola**; primero focal de caracterización |
| Determinismo y orden | `FlowFSMRuntime.tick` orden de máquinas authored, eventos y solicitudes; `_pending_requests` y work budget; enumeración de IDs por registry | `flow_fsm_dynamic_quota_identity_test.tscn`, `flow_fsm_negative_routing_test.tscn`, 6A/6B/6G, 8C2, test de relojes | Dos ejecuciones de secuencias idénticas con IDs explícitos; comparar transiciones/colas/lecturas en varios resets sin exigir UUID generado idéntico |
| Seguridad de ejecución | `reset/restore_snapshot` rechazan dentro de tick; `stop` en tick solicita salida diferida; `save_to_file` usa `user://` y backup | `flow_fsm_snapshot_test.tscn`, `flow_fsm_reentrant_stop_test.tscn` y pruebas anteriores cubren partes | Ensayo explícito de guardas durante callbacks y limpieza del runtime; cuidado con invocación de `reset` o restore desde Exit/Enter fuera de tick: **riesgo de reentrancia por caracterizar**, no bug demostrado |

## Hallazgos y decisiones de alcance

1. **No existe brecha de implementación probada en 8D2-A.** `EPHEMERAL`, `SESSION`, `PERSISTENT`, reset, stop y snapshot funcionan al menos en los casos históricos ejecutados. Por eso no se autoriza reescribir el motor ni duplicar el codec.
2. **Brechas de evidencia**: secuencia integral por política, fallback de alias transitorio activo durante snapshot, matriz de rechazo sin mutación de cola, reproducibilidad multimaquina y combinaciones de señales durante reset. Serán caracterizadas en escenarios pequeños sobre la producción actual.
3. **No invadir FSM-004:** los archivos de snapshot son infraestructura ya existente de **Fase 9**. Cualquier cambio a su formato, reglas de recovery, versionado o firmas requiere una decisión propia y cobertura compatible; 8D2 solo los observa como frontera.
4. **Riesgo a vigilar (sin alegar falla):** un callback de salida/entrada puede encolar solicitudes o ejecutar código de usuario. Los tests deberán distinguir condiciones de uso autorizadas frente a reentrancia, y nunca forzar recursiones potencialmente ilimitadas para obtener un PASS.
5. **Separar evidencias**: no hay revisión visual nueva; Fedora 15 y Android 10 de Fase 7 siguen **0/25 PENDING**. No se invocaron formalmente `flujo-baseline`/`flujo-prove`; se leyeron sus instrucciones versionadas. Esta auditoría es documental, no una certificación nueva de runtime.

## Verificación y continuidad

- Base: CI [41575182608](https://github.com/mercurysama/Flujo/actions/runs/41575182608) **90/90 SUCCESS**. Para cada microbloque futuro, añadir un test y paso **obligatorio** en `.github/workflows/flujo-fsm.yml`, catalogar `not_run` hasta recibir Godot 4.7.2 GREEN, y conservar regresiones FSM-003/004 y SDK. Los tests existentes en el CI están confirmados; los escenarios adicionales propuestos quedan **NOT RUN**.
- [Plan detallado de 8D2](fsm_phase8_8d2_microblocks.md). **Siguiente microbloque: 8D2-B1A**, matriz de lifetimes y reset; el runtime de producción permanece intacto salvo que una prueba RED identifique una brecha efectiva y se autorice un ajuste mínimo.
- Métricas de este inventario: 1 baseline de 90 pasos confirmada; implementación nueva: **0 archivos**; casos de la futura matriz: **no ejecutados**. Tiempo humano, aceptación y cobertura total fuera de lo observado: **not measured**.

*Todo es Flujo; todo fluye.* 🌊
