# Potok 8E-1 — Auditoría de criterios de cierre de la fase 8 (FLU-FSM-003)

**Fecha:** 2026-11-03 (America/Mexico_City). **Rama exclusiva:** `feature/fsm-runtime-flow-flusso`. **Baseline:** `43a970ce22477b2da102268d2bab811997e01eff` con [Actions 41594048021](https://github.com/mercurysama/Flujo/actions/runs/41594048021) **completed SUCCESS**, Godot 4.7.2, 101 pasos del job completados sin fallos. **Dictamen 8E-1:** criterios de aceptación *técnica automatizada* sustentados; **fase 8 completa, aceptación humana y release aún NO declarados**. Este documento es una auditoría, no una nueva prueba.

## Criterio normativo y alcance

El [plan de implementación](fsm_implementation_plan.md) define como criterio final **FLU-FSM-003** que un personaje adquiera temporalmente un nuevo estado (p. ej. `Aturdido`), lo active y retire **sin cambiar su FlowGraph original**. El [contrato dinámico v1](fsm_dynamic_contract_v1.md) concreta: registro desde plantilla authored de la misma máquina, ID runtime válido y sin colisiones, cuota 128, datos JSON-safe aislados, cambio de estado, retiro activo con fallback válido, purga de requests directos al eliminar alias inactivo, aislamiento entre controladores y limpieza en stop. Las tres políticas de duración se interpretan según el contrato de 8D2; exportación/restore es una frontera de compatibilidad con `FLU-FSM-004` **sin cerrar fase 9**.

## Matriz 8A–8D: obligación, demostración y evidencia automatizada

| Tramo | Criterio y cobertura verificada | Ruta de escenario o auditoría | Acción / estado |
| --- | --- | --- | --- |
| **8A** | Inventario de API y deuda de evidencias, sin reescribir producción | [8A gap audit](fsm_phase8_8a_gap_audit.md); `tests/runtime/flow_fsm_dynamic_test.tscn` histórico | [41538641710](https://github.com/mercurysama/Flujo/actions/runs/41538641710) **SUCCESS** de baseline |
| **8B1** | `register_state` / `has_state`: ID, colisión, 128 por máquina, registro tras retiro y orden | `tests/runtime/flow_fsm_dynamic_quota_identity_test.tscn`; [8B1 result](fsm_phase8_8b1_result.md) | [41547536522](https://github.com/mercurysama/Flujo/actions/runs/41547536522) **SUCCESS** |
| **8B2** | Plantillas de la misma máquina habilitadas y datos JSON-safe; copia profunda y rechazo de cargas inválidas | `tests/runtime/flow_fsm_dynamic_template_data_test.tscn`; [8B2 result](fsm_phase8_8b2_result.md) | [41548395878](https://github.com/mercurysama/Flujo/actions/runs/41548395878) **SUCCESS** |
| **8C1** | `remove_state` de activo con fallback seguro, rechazo sin mutación y lifecycle correcto | `tests/runtime/flow_fsm_dynamic_active_removal_test.tscn`; [8C1 result](fsm_phase8_8c1_result.md) | [41549228081](https://github.com/mercurysama/Flujo/actions/runs/41549228081) **SUCCESS** |
| **8C2** | Alias inactivo retirado purga solo directos destinados al ID; otros eventos, máquinas y colas no se contaminan | `tests/runtime/flow_fsm_dynamic_pending_multimachine_test.tscn`; [8C2 result](fsm_phase8_8c2_result.md) | [41550131409](https://github.com/mercurysama/Flujo/actions/runs/41550131409) **SUCCESS** |
| **8D1** | Servicio/capacidad SDK por máquina desde fase FSM, caducidad y rechazo desde contextos no FSM, controlador y propietario correctos, datos/ciclo de vida/retirada | [8D1-C5 audit](fsm_phase8_8d1c5_audit.md), `tests/runtime/flow_fsm_sdk_*_test.tscn`; `FlowFSMOperations` y `FlowFSMRuntime` | [41574412835](https://github.com/mercurysama/Flujo/actions/runs/41574412835) **SUCCESS** de 90 pasos. RED inicial de [8D1-B1](fsm_phase8_8d1b1_red_contract_result.md) resuelto; no reescribir su historia |
| **8D2** | EPHEMERAL/SESSION/PERSISTENT, reset/teardown, export y restore de frontera, rechazo atómico, determinismo múltiple, callbacks y protección contra reentrancia | [8D2-C1 matriz de 11 focos](fsm_phase8_8d2c1_traceability_audit.md), [8D2-C2 cierre](fsm_phase8_8d2c2_closeout.md), `FlowFSMRuntime` y `FlowFSMSnapshotCodec` | [41594048021](https://github.com/mercurysama/Flujo/actions/runs/41594048021) **SUCCESS**, checkpoint de 8D2-C2 |

### Relación con las ocho tareas originales de fase 8

1. **API**: `register_state`, `has_state`, `change_state`, `remove_state` disponibles y ejercitadas; API concreta congelada por contrato.
2. **Registro por instancia**: `_dynamic_states` runtime local; el estado dinámico nunca se agrega a `FlowStateMachineDefinition.states`.
3. **Plantillas**: solo plantillas authored válidas del propio contexto de máquina; la vía de paquetes instalados no forma parte del contrato v1.
4. **IDs, colisiones, cupos y orden**: cuota **constante** 128 por máquina según contrato v1 y pruebas; el plan original proponía límite *configurable*, pero no existe acuerdo de cambiar esa constante. **Diferencia de redacción documentada, no defecto demostrado**; requiere nuevo contrato si el mantenedor decide hacer el límite configurable.
5. **Retiro del activo**: fallback explícito y validado, con Exit→Enter; en tick se rechaza.
6. **Pendientes**: al retirar alias inactivo se purgan sus requests directos, preservando eventos y órdenes de otras máquinas; no se promete borrar indiscriminadamente todos los eventos.
7. **Servicios desde bloques**: camino FSM autorizado en 8D1, con contexto/SDK de capacidad y caducidad; Ready/Timer o llamadas no FSM no adquieren el permiso.
8. **Pruebas**: los escenarios 8B, 8C y 8D cubren altas, activación, eliminación, registro posterior, duplicados, callbacks, reinicio, stop, controladores distintos y FIFO/budget.

## Puertas de aceptación y limitaciones

- **Automatización:** todos los tramos citados cuentan con ejecución integral histórica SUCCESS; [último checkpoint 8D2-C2](https://github.com/mercurysama/Flujo/actions/runs/41594048021) **SUCCESS**. El gate `.github/workflows/flujo-fsm.yml` conserva pruebas basales y focales 8B–8D, además del validador `docs/behavior_catalog.json`.
- **Seguridad/alcance:** se comprueba validación de datos y aislamiento de la fachada en los casos ensayados; no se afirma un sandbox infalible ante GDScript hostil. Tampoco se midieron latencia, memoria, escalabilidad más allá de cotas verificadas ni todas las combinaciones de concurrencia/callback.
- **Fase 9 no se adelanta**: archivos `user://`, backup, corrupción, migración, disco y compatibilidad de snapshots merecen auditoría/aceptación propia. `PERSISTENT` es elegible para snapshot; no se guarda ni recupera automáticamente al reiniciar.
- **Pruebas humanas:** 15 Fedora + 10 Android = **25 PENDING (0/25)** del ciclo anterior. Son puerta pendiente antes de integrar/publicar estable; no bloquearon, por decisión del mantenedor, la continuidad de desarrollo/CI.
- **No regresión de alcance**: sin modificación de `main`, `demo/main.tscn`, sistema Ready/Timer ni contratos `FLU-FSM-003/004` durante este microbloque. No se ejecutó Godot local ni se invocaron formalmente Skills de repo; evidencia remota solamente.

## Continuidad: 8E-2 y 8E-3

**8E-2:** conciliar `AGENTS.md`, `docs/constitution.md`, `docs/development_workflow.md`, validador de catálogo y TODOS los gates de 8B/8C/8D con el último CI y las reglas de no regresión. Si algún gate falta, crear reparación mínima separada y verificar. El resultado de 8E-1 es una auditoría documental, y **su nuevo CI no debe llamarse PASS hasta terminar**.

**8E-3:** emitir dictamen condicionado de fase 8 con **automatización aprobada** y **aceptación visual diferida**, sin hacer merge ni llamar al release estable. **8E-4:** hoja de continuidad para fase 9, separando estrictamente alcance FSM-004 y pruebas de archivos/backup.

*Todo es Flujo; todo fluye.* 🌊
