# Potok — 8D2: microbloques recuperables de lifetimes, reset y determinismo

**Plan auditado:** 2026-11-02 (America/Mexico_City). **Rama exclusiva:** `feature/fsm-runtime-flow-flusso`. **Base:** `ad73a4816849556810dd62047d468decdd562a9f`; [CI 41575182608](https://github.com/mercurysama/Flujo/actions/runs/41575182608) **SUCCESS 90/90**. **8D2-A:** [auditoría del comportamiento existente](fsm_phase8_8d2a_audit.md) aprobada como documento. **8D2-B1A:** [resultado](fsm_phase8_8d2b1a_result.md) **PASS**, commit `7d9f702c1eef19af52d7ba90a600bf153eeb204e`, [Actions 41576973539](https://github.com/mercurysama/Flujo/actions/runs/41576973539) SUCCESS 91/91. **8D2-B1B:** [resultado](fsm_phase8_8d2b1b_result.md) **PASS** en [Actions 41578192657](https://github.com/mercurysama/Flujo/actions/runs/41578192657) 92/92; **8D2-B2A:** [resultado](fsm_phase8_8d2b2a_result.md) **PASS** en [Actions 41579446980](https://github.com/mercurysama/Flujo/actions/runs/41579446980) 93/93; **B2B–C PENDING**.

## Contrato congelado y restricciones

- **FSM-003**: [FLU-FSM-003](fsm_dynamic_contract_v1.md), `FlowFSMRuntime` y tres lifetimes; registro dinámico separado por máquina y controlador, sin escritura en `FlowGraph`.
- **FSM-004**: [FLU-FSM-004](fsm_snapshot_contract_v1.md) y `FlowFSMSnapshotCodec` ya implementados; se toman como **baseline de compatibilidad**, sin reabrir ni cerrar la Fase 9 por implicación.
- Primero caracterizar el comportamiento actual. Un test GREEN en producción intacta es suficiente para cerrar una brecha de evidencia; un RED no autoriza cambiar semántica o debilitar aserciones sin análisis y contrato del mantenedor.
- **Cada paso de prueba**: test `.gd` + escena `.tscn` o entrypoint conforme a `AGENTS.md`, behavior ID nuevo cuando el caso no esté catalogado, gate no opcional en `.github/workflows/flujo-fsm.yml`, CI Godot 4.7.2 completo. No alterar Ready/Timer, editor, UI, esquemas, `main`, `demo/main.tscn` ni otros branches.
- Las 25 pruebas manuales de Fase 7 siguen diferidas; no se confunde CI con aceptación humana ni se declaran Skills invocadas formalmente.

## Ruta en microbloques pequeños

| Paso | Experimento mínimo / aceptación verificable | Regresiones y límites | Estado |
| --- | --- | --- | --- |
| **8D2-A** | Inventario de lifetime, reset, teardown, snapshot, controladores y determinismo; separar cobertura existente de faltante. | [Auditoría](fsm_phase8_8d2a_audit.md), 90/90 baseline remota. | **AUDITADO**, sin código |
| **8D2-B1A** | Tres alias `EPHEMERAL`, `SESSION`, `PERSISTENT`, con datos JSON-safe y uno temporal activo; reset elimina EPHEMERAL, conserva IDs/datos SESSION/PERSISTENT y no altera otro controlador. | [PASS 91/91](fsm_phase8_8d2b1a_result.md), focal + FSM-004 snapshot/8D1-C y regresiones; Exit→Enter verificado. | **PASS CI** |
| **8D2-B1B** | Tras stop y reinicio del mismo `PVController`, los tres lifetimes desaparecen, cola vieja no reaparece, runtime anterior y SDK retenidos no pueden operar; segundo controlador no se detiene. | [PASS 92/92](fsm_phase8_8d2b1b_result.md), focal de ciclo de vida y regresiones FSM-003/004/SDK. | **PASS CI** |
| **8D2-B2A** | Exportar snapshot con alias EPHEMERAL o SESSION **activo**; inicial authored como recuperación; PERSISTENT activo retiene ID. Tres máquinas y seis persistentes ordenados; restaurar a otra instancia. | [PASS 93/93](fsm_phase8_8d2b2a_result.md), focal B2A + FSM-004, codec v1 preservado. | **PASS CI** |
| **8D2-B2B** | Rechazar en preflight versiones, graph/schema ID, máquina/estado invalidos, duplicación, límites y datos no JSON-safe; las fallas no alteran estado activo, registry ni cola. Restitución válida debe reemplazar datos de forma independiente. | Casos ya cubiertos se reutilizan, cubrir solo huecos comprobados; no cambiar formato ni semántica sin nueva autorización. | **PENDING** |
| **8D2-B3A** | Dos controladores y varias máquinas reciben la misma secuencia definida de entradas, resets y ticks; comparar trazas ordenadas y resultados con IDs explícitos estables. | `flow_fsm_negative_routing_test.tscn`, 6A/6B/6G, 8C2; no equiparar GUID aleatorios. | **PENDING** |
| **8D2-B3B** | Aislar casos de callbacks `StateExit`/`StateEnter` durante reset/restore y solicitudes encoladas; comprobar guardas dentro de tick y que no haya doble Enter/Exit inesperado. | Pruebas pequeñas y acotadas; detener ante dos fallos de un recurso; nunca forzar recursión potencialmente sin límite. | **PENDING** |
| **8D2-C** | Auditoría final requisito → código → catálogo → escena → commit → Actions, reconstrucción de qué lifetimes sobreviven a cada frontera; declarar cierre técnico **solo** si todos los gates pasan. | Conservar alcance de Fase 9, 25 visuales pendientes y límites de SDK; preparar entrada 8E. | **PENDING** |

## Punto de recuperación

1. Revisar HEAD, `.github/workflows/flujo-fsm.yml`, último Actions y [auditoría A](fsm_phase8_8d2a_audit.md). No asumir que etapas posteriores están completas por existir código previo.
2. **8D2-B1A, B1B y B2A ya están PASS**. Continuar **8D2-B2B**: escenarios de preflight inválido con runtime activo, registro y cola; verificar que todas las fallas mantienen estado y datos inalterados. Añadir solo el hueco no cubierto por `flow_fsm_snapshot_test.tscn`, catálogo `not_run` antes de nuevo CI.
3. Mantener `FLU-FSM-003` y `FLU-FSM-004` como contratos separados. El código ya existente de Fase 9 no se modifica por una prueba complementaria de 8D2.
4. En 8D2-C decidir si procede 8E. Las 25 pruebas Fedora/Android siguen PENDING y la fase 8 no se da por cerrada durante esta planificación.

*Todo es Flujo; todo fluye.* 🌊
