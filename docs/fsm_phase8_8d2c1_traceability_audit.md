# Potok — 8D2-C1: auditoría de trazabilidad técnica (requisitos → implementación → pruebas → CI)

**Fecha:** 2026-11-03 (America/Mexico_City). **Rama exclusiva:** `feature/fsm-runtime-flow-flusso`. **Punto base:** `be5efdf684b4423ba55d1e71306dd73bd49beb69`. **Resultado de C1:** inventario y verificación documental completados. **No equivale a cierre de 8D2-C, 8E, fase 8 ni fase 9.**

## Contratos y rutas de implementación verificadas

- **FLU-FSM-003**: [contrato dinámico](fsm_dynamic_contract_v1.md) y `addons/vp_flujo/runtime/flow_fsm_runtime.gd`, con `register_state`, `get_dynamic_state_ids`, `get_dynamic_state_data`, `reset`, `stop`, `tick`. Un `PVController` posee su propia instancia mutable y no agrega alias a `FlowGraph`.
- **FLU-FSM-004**: [contrato snapshot](fsm_snapshot_contract_v1.md), `addons/vp_flujo/runtime/flow_fsm_snapshot_codec.gd` (`make_snapshot` / `prepare`) y `FlowFSMRuntime.export_snapshot`, `restore_snapshot`, `save_to_file`, `restore_from_file`. Se audita solamente la **frontera de compatibilidad** de 8D2, sin cerrar Fase 9.
- **Gobernanza:** `docs/behavior_catalog.json` contiene **92 comportamientos** al punto base, de los cuales **11 entradas automáticas FLUJO-BHV-POTOK de 8D2** tienen `baseline_status = passing`. Las once escenas `.tscn` tienen su gate obligatorio en `.github/workflows/flujo-fsm.yml`, que instala Godot 4.7.2, valida el catálogo y ejecuta cada focal con límite de tiempo. No se sustituyeron pruebas previas.
- **Punto de partida:** [8D2-A](fsm_phase8_8d2a_audit.md), [CI 41575182608](https://github.com/mercurysama/Flujo/actions/runs/41575182608) **SUCCESS** de la baseline histórica. La auditoría inicial no era una implementación.

## Matriz 8D2-C1: escenario / catálogo / CI verde confirmado

| Subfase | Código y comportamiento observable | Escena y comportamiento catalogado | Evidencia CI |
| --- | --- | --- | --- |
| **B1A** | `reset()`: EPHEMERAL activo eliminado, SESSION/PERSISTENT y datos sobreviven; peer/cola aislados | `flow_fsm_lifetime_reset_matrix_test.tscn` · `FLUJO-BHV-POTOK-LIFETIME-RESET-001` | [41576973539](https://github.com/mercurysama/Flujo/actions/runs/41576973539) **SUCCESS** |
| **B1B** | `stop()` + nuevo runtime: desaparecen los tres lifetimes, cola antigua y referencias SDK expiran; peer continúa | `flow_fsm_lifetime_stop_restart_test.tscn` · `FLUJO-BHV-POTOK-LIFETIME-STOP-002` | [41578192657](https://github.com/mercurysama/Flujo/actions/runs/41578192657) **SUCCESS** |
| **B2A** | `export_snapshot()`: EPHEMERAL/SESSION activos recuperan inicial authored, PERSISTENT conserva ID, orden y copia profunda | `flow_fsm_snapshot_transient_active_test.tscn` · `FLUJO-BHV-POTOK-SNAPSHOT-TRANSIENT-003` | [41579446980](https://github.com/mercurysama/Flujo/actions/runs/41579446980) **SUCCESS** |
| **B2B** | `prepare` y `restore_snapshot`: 23 rechazos atómicos sin alterar estados, aliases, cola, callbacks o peer; restore válido posterior | `flow_fsm_snapshot_preflight_atomicity_test.tscn` · `FLUJO-BHV-POTOK-SNAPSHOT-ATOMIC-004` | [41582200667](https://github.com/mercurysama/Flujo/actions/runs/41582200667) **SUCCESS** |
| **B3A1** | `tick` y `change_state`: dos PVControllers, dos máquinas, mismas solicitudes directas → mismas trazas | `flow_fsm_deterministic_dual_controller_test.tscn` · `FLUJO-BHV-POTOK-DETERMINISM-005` | [41584361713](https://github.com/mercurysama/Flujo/actions/runs/41584361713) **SUCCESS** |
| **B3A2** | Dos rondas B→A de comandos; commits A→B en orden authored y colas independientes | `flow_fsm_two_wave_order_replay_test.tscn` · `FLUJO-BHV-POTOK-DETERMINISM-ORDER-006` | [41584784409](https://github.com/mercurysama/Flujo/actions/runs/41584784409) **SUCCESS** |
| **B3A3** | 34 eventos A, un evento B; presupuesto 32 por máquina, FIFO, carryover y callback diferido entre controladores | `flow_fsm_dual_controller_event_budget_test.tscn` · `FLUJO-BHV-POTOK-DETERMINISM-EVENT-BUDGET-007` | [41588927428](https://github.com/mercurysama/Flujo/actions/runs/41588927428) **SUCCESS** |
| **B3A4** | Alias dinámicos con IDs explícitos iguales, reset aislado, eliminación EPHEMERAL y conservación PERSISTENT | `flow_fsm_dual_controller_dynamic_reset_test.tscn` · `FLUJO-BHV-POTOK-DETERMINISM-RESET-008` | [41589766004](https://github.com/mercurysama/Flujo/actions/runs/41589766004) **SUCCESS** |
| **B3B1** | `reset()` rechazado en Update durante tick; fuera de tick Exit→Enter por máquina y limpieza solo local | `flow_fsm_reset_callback_guard_test.tscn` · `FLUJO-BHV-POTOK-RESET-CALLBACK-GUARD-009` | [41590902774](https://github.com/mercurysama/Flujo/actions/runs/41590902774) **SUCCESS** |
| **B3B2** | `restore_snapshot()` global Exit(A), Exit(B), Enter(A), Enter(B); descarta cola local, peer intacto | `flow_fsm_restore_callback_queue_test.tscn` · `FLUJO-BHV-POTOK-RESTORE-CALLBACK-QUEUE-010` | [41591954025](https://github.com/mercurysama/Flujo/actions/runs/41591954025) **SUCCESS** |
| **B3B3** | `reset` / `restore_snapshot` y tick recursivo rechazados durante callbacks; evento diferido se limpia en restore externo | `flow_fsm_reset_restore_reentrant_guard_test.tscn` · `FLUJO-BHV-POTOK-RESET-RESTORE-REENTRANCY-011` | [41592345621](https://github.com/mercurysama/Flujo/actions/runs/41592345621) **SUCCESS** |

Las rutas de escenas anteriores comparten prefijo `tests/runtime/`. Documentos que agrupan evidencias: [B3A5](fsm_phase8_8d2b3a5_audit.md) y [B3B4](fsm_phase8_8d2b3b4_audit.md). La ejecución integral del propio checkpoint B3B4, [41593197556](https://github.com/mercurysama/Flujo/actions/runs/41593197556), **no había terminado al iniciar C1**; no se le atribuye PASS anticipadamente. Cada fila conserva su propio run anterior **SUCCESS**.

## Matriz de fronteras por lifetime

| Frontera | EPHEMERAL | SESSION | PERSISTENT | Nota |
| --- | --- | --- | --- | --- |
| Tick normal | Sigue registrado | Sigue registrado | Sigue registrado | Si se activa, ejecuta plantilla authored, sin mutar grafo |
| `reset()` | **Eliminado** | **Conservado** | **Conservado** | IDs/datos supervivientes preservados; cola del dueño vaciada; por máquina Exit→Enter |
| `stop()` y nuevo runtime | **Eliminado** | **Eliminado** | **Eliminado** | Ninguno se restaura automáticamente, incluidos los PERSISTENT |
| `export_snapshot()` | **Omitido** | **Omitido** | **Incluido** | Si el activo era no persistente, se registra inicial authored; no cambia el runtime vivo |
| `restore_snapshot()` válido | No se recupera | No se recupera | Registros persistentes serializados restaurados | Preflight antes de publicación, reemplaza registro local, limpia cola y emite Exit global / Enter global |
| `restore_snapshot()` inválido | Sin cambios | Sin cambios | Sin cambios | No se consumen colas ni se emiten callbacks |

## Riesgos, límites y pendiente de 8D2-C2

1. **No hay defectos productivos confirmados** en estas once caracterizaciones; no justifican cambios semánticos. El RED histórico [41589653144](https://github.com/mercurysama/Flujo/actions/runs/41589653144) era una aserción incorrecta de la prueba B3A4 (supuso Exits globales en `reset`); corrección exclusiva del test `fb6c134` y PASS posterior.
2. **No confundir reset y restore**: `reset` recorre una máquina con su Exit→Enter antes de la siguiente; restore emite todos los Exit, publica estado candidato, y después todos los Enter. No hay garantía de seguridad universal frente a código de usuario arbitrariamente adversarial o callbacks en todas las fases fuera de tick; B3B prueba intentos acotados en tick.
3. **Límites técnicos explícitos**: pruebas remotas Godot 4.7.2; no se ejecutó Godot local ni se invocaron formalmente las Skills del repositorio. Sin pruebas de estrés/performance medidas ni aceptación UI en dispositivo; 15 verificaciones Fedora + 10 Android = **25 pendientes**.
4. **No invadir fase 9**: `save_to_file` / `restore_from_file`, backups, rutas `user://`, migraciones y cobertura de persistencia de FS-M004 requieren su auditoría/cierre propio. La existencia del código o de pruebas anteriores no implica fase 9 completada.
5. **Próxima unidad 8D2-C2:** confirmar último CI documental, conciliar requisitos y áreas sin cobertura con el plan de 12 fases, declarar explícitamente el cierre *técnico* de 8D2 solo si no falta evidencia obligatoria y preparar 8E; preservar pruebas manuales aplazadas.

*Todo es Flujo; todo fluye.* 🌊
