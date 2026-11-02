# Potok — Transición de Fase 7 a Fase 8 / Auditoría de brechas 8A

**Fecha:** 2026-11-02. **Rama:** `feature/fsm-runtime-flow-flusso`. **Baseline:** `30bb62256f09c50ec195f9ff01b23635c2fc9394`, [CI 41538641710](https://github.com/mercurysama/Flujo/actions/runs/41538641710) SUCCESS. **Autoridad:** el mantenedor autoriza continuar a Fase 8 y posponer explícitamente todas las pruebas humanas de Fase 7. No autoriza afirmar aceptación visual, merge a `main` ni release.

## Decisión de continuidad

**Fase 7: implementación y pruebas automatizadas terminadas; aceptación visual formal DIFERIDA, no aprobada.** El contrato `docs/fsm_phase7_7f1d_contract.md`, el informe `docs/fsm_phase7_7f1d4_audit.md`, y la matriz `docs/fsm_phase7_7f2_manual_acceptance_matrix.md` contienen el trabajo existente. Las 15 pruebas Fedora y 10 Android siguen **PENDING (0/25)** y reaparecerán como puerta obligatoria antes de integrar/publicar una versión estable; el usuario no desea hacerlas ahora.

**Fase 8: iniciada con auditoría de brechas 8A, no implementar nuevamente su núcleo.** El plan original `docs/fsm_implementation_plan.md` define FSM-003 como registro, consulta, cambio y retiro de estados durante runtime sin escribir al grafo.

## Inventario verificado al inicio

- `docs/fsm_dynamic_contract_v1.md` ya especifica alias runtime, fuente desde plantilla del mismo machine, IDs, tres políticas de vida, copia profunda JSON-safe, cupo 128, fallback activo, limpieza de solicitudes, aislamiento de instancias y no mutación de `FlowGraph`.
- `addons/vp_flujo/runtime/flow_fsm_dynamic_state_record.gd` contiene `FlowFSMDynamicStateRecord` y `Lifetime {EPHEMERAL, SESSION, PERSISTENT}`.
- `addons/vp_flujo/runtime/flow_fsm_runtime.gd` ya ofrece `register_state`, `has_state`, `change_state`, `remove_state`, `get_dynamic_state_ids`, `get_dynamic_state_lifetime`, `get_dynamic_state_data` y `set_dynamic_state_data`, además de resolución de plantilla desde el grafo y limpieza de peticiones directas al borrar un alias.
- `tests/runtime/flow_fsm_dynamic_test.gd/.tscn` ejercita dos controladores aislados, identidad, datos desacoplados, colisiones, plantilla inexistente, Enter/Update/Exit, eliminación activa con fallback, purga de solicitud pendiente y limpieza en stop. Su entrada `FSM dynamic state focal` ya existe en `.github/workflows/flujo-fsm.yml`. El CI histórico de baseline incluye esta ejecución; no se presenta como nueva funcionalidad.
- La fase 9 también posee infraestructura inicial de snapshot; no adelantar ni alterar esa fase en 8A.

## Brechas de evidencia frente a las ocho tareas originales

| Plan original | Evidencia existente | Brecha o verificación siguiente |
| --- | --- | --- |
| 8.1 API definida | Cuatro APIs públicas en `FlowFSMRuntime` y contrato v1 | Revisar errores y resultados públicos, no renombrar APIs sin necesidad |
| 8.2 Registro por instancia, sin FlowGraph mutable | `_dynamic_states` local, dos controladores en focal | Ampliar prueba a varias máquinas y escenarios simultáneos |
| 8.3 Plantillas válidas | `_find_authored_state`, `template.enabled` y grafo validado al iniciar | Comprobar colisión con IDs authored, plantilla deshabilitada, plantilla ajena y casos de grafo inválido |
| 8.4 IDs, duplicación, cupos y orden | `FlowId.is_valid`, rechazo de duplicado, límite constante 128 | **No se ve prueba explícita de cupo 128, orden determinista de enumeración, ni re-registro después de retiro**; el plan habla de límite configurable, el código usa constante: evaluar contrato antes de cambiarlo |
| 8.5 Eliminar estado activo | `remove_state` requiere fallback distinto, válido, fuera de tick | Ampliar tests a fallback ausente/deshabilitado/dinámico, error dentro de tick y rutas de reentrada |
| 8.6 Referencias y solicitudes pendientes | Purga de peticiones directas pendientes para alias eliminado | Probar mezcla con eventos, peticiones de máquinas distintas y referencias de transición; no alterar colas sin caracterizar |
| 8.7 Uso desde bloques oficiales/SDK | Runtime ofrece API; el contrato menciona servicios autorizados | **No hay demostración localizada de invocación por bloques mediante un servicio del contexto runtime**; inspeccionar el ejecutor genérico antes de ampliar |
| 8.8 Matriz de estrés y aislamiento | Focal de runtime básico disponible | Ampliar cuota, ID reusado, controladores múltiples, reset, tick, y definición persistente intacta |

Las brechas son **brechas identificadas por revisión de archivos/contrato**, no fallas reproducidas. No afirmar que el comportamiento falta hasta ejecutar una prueba RED.

## Microbloques recuperables Fase 8

- **8A (este documento):** congelar el alcance FSM-003, auditar la implementación preexistente, registrar deuda de evidencia. Sin cambio productivo.
- **8B1 — catálogo, IDs y cupo:** prueba focal de 128 alias, exceso, colisión con IDs authored, ID válido tras eliminación/re-registro y orden determinista. Test-first; si falla, corregir mínimo en nuevo microbloque.
- **8B2 — plantillas y datos:** plantilla del mismo machine/activa, datos mutables/deep clone, estructura/ciclos/tamaño, límites y rechazo de objetos.
- **8C1 — lifecycle activo:** fallback válido/inválido, fuera/dentro de tick, Exit→Enter, señales y no modificación en rechazo.
- **8C2 — pendientes y multi-machine:** requests directos, eventos, cambio de máquina, aliases eliminados y ausencia de referencias colgantes.
- **8D1 — servicio SDK de runtime:** analizar contexto real del ejecutor; contrato mínimo de capacidades sin entregar referencias mutables al grafo. Implementar solo si se demuestra una brecha y tras la puerta baseline.
- **8D2 — aislamiento y determinismo:** varias instancias de PVController, reset, stop, estados EPHEMERAL/SESSION/PERSISTENT y límites; preservar compatibilidad de snapshots existentes.
- **8E — auditoría de cierre FSM-003:** suites, validador del catálogo, traza requisito→prueba→SHA, sin aprobación física inventada. Dejar visuales diferidas para revisión pre-release.

## Reglas de ejecución y gobierno

Usar los checklists versionados `tools/agent_skills/flujo-baseline/SKILL.md` y `tools/agent_skills/flujo-prove/SKILL.md` según `AGENTS.md` antes de implementar/corregir producción; no interpretar lectura de una skill como su ejecución formal. Un test nuevo primero debe caracterizar la implementación actual. Los cambios al runtime/SDK se hacen en una entrega aparte y solo con justificación basada en falla comprobada. No tocar `main`, `demo/main.tscn`, esquema, ni componentes de fase 9. Guardar los checkpoints en esta rama, siempre con el SHA y run CI real.

**Siguiente:** **8B1** prueba focal cuota/identidad/re-registro y enumeración, confirmando el baseline sin duplicar el motor existente.

*Todo es Flujo; todo fluye.* 🌊
