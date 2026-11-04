# Potok 10A — Tanda 2 (10A-4 / 10A-5 / 10A-6), cierre recuperable

**Fecha:** 2026-11-03. **Rama:** `feature/fsm-runtime-flow-flusso`. **HEAD funcional verificado:** `1041dcec6567c28b489936631694c1ec9666f888`. **Dictamen:** **dos caracterizaciones con PASS automatizado y una propuesta documental terminada**. Fase 10 **ABIERTA**; contrato DEBUG-FSM v0 **no aprobado**. GitHub Actions no equivale a aceptación humana.

| Microprompt | Resultado | Commit | CI |
|---|---|---|---|
| 10A-4 | [Condiciones/no-op](fsm_phase10_10a4_conditions_characterization.md), nueva fixture `tests/runtime/flow_fsm_observability_conditions_test.tscn`, catálogo y workflow | `eb7ba4b87d952d639e83b19a3c7c7abec4935249` | [#41744246830](https://github.com/mercurysama/Flujo/actions/runs/41744246830) SUCCESS |
| 10A-5 | [Ciclo de vida](fsm_phase10_10a5_lifecycle_characterization.md), fixture `tests/runtime/flow_fsm_observability_lifecycle_test.tscn`, catálogo y workflow | `0c2204c71fa85704aa63cc0113851ae19f208e5c` | [#41744492793](https://github.com/mercurysama/Flujo/actions/runs/41744492793) SUCCESS |
| 10A-6 | [Retención y presupuestos](fsm_phase10_10a6_trace_budget_proposal.md), matriz de pruebas futuras y decisiones pendientes, sin producción | `1041dcec6567c28b489936631694c1ec9666f888` | [#41744622179](https://github.com/mercurysama/Flujo/actions/runs/41744622179) SUCCESS |

## Hechos comprobados

1. **10A-4:** condiciones `false` y autotransiciones legales no generan señal pública de descarte; únicamente la transición verdadera ganadora emite Exit/Enter/Commit. Un comando directo al mismo estado se consume sin commit. No hay todavía traza estructurada de evaluación.
2. **10A-5:** la ejecución por reloj y el reset/stop emiten señales ordenadas; se conserva el aislamiento de dos `PVController`. Un observador que se conecte después de `_ready` no recibe retroactivamente señales `machine_started` previas; falta consulta inicial de debugger.
3. **10A-6:** se examinaron los límites reales 256 (cola), 32 (paquetes/máquina/tick), 8 (chain hops), 128 (dinámicos), y 8/256/65536 (datos JSON); **ninguno equivale a tamaño aprobado de historial**. No se fija cuota sin permiso.
4. Catálogo: `FLUJO-BHV-POTOK-OBSERVABILITY-CONDITIONS-002` y `FLUJO-BHV-POTOK-OBSERVABILITY-LIFECYCLE-003` pasan de `not_run` a `passing` **después** de verificar los workflows del mismo commit. Tests originales y focal 10A-3 siguen intactos.

## Gates y deuda visible

- **Regresión CI integral:** las tres ejecuciones terminaron `completed/success`; incluye validador del catálogo, editor, modelo, Ready y demás tests requeridos, además de ambas focales nuevas en runs 10A-5/6.
- **Godot local/Fedora y ejecución formal de Skills:** **NOT RUN**; no simular `READY/PASA`. **Revisión humana:** 0/25, pendiente y diferida.
- **Runtime/editor:** ningún archivo productivo modificado. Sin `main`, merges, releases, APK ni telemetría.
- **Persistencia fase 9:** sin cambios en snapshot `format_version=1`, copy/rename/backup, F5–F7/F7R, política F9 o recuperación automática F10; **aceptación condicionada** preservada.
- **Contrato DEBUG-FSM:** [v0](fsm_observability_contract_proposal_v0.md) permanece **PROPUESTO**. Para construir 10B faltan decisiones sobre cuota de buffer, política de activación, origen único del registro, eventos intermedios y sanitización de datos; no asumir aprobación por la señal de continuidad.

## Próxima tanda planificada

**10A-7:** revisar trazabilidad requisitos → tests → CI y validar que ningún comportamiento quedó sobredeclarado; registrar auditoría complementaria sin cambiar productivo. **10A-8:** inspeccionar superficies Godot EditorDebuggerPlugin / Fluo y describir integración mínima sin UI nueva ni dependencia del editor en el runtime. **10A-9:** preparar propuesta final de contrato v1 y decisiones explícitas para abrir 10B; hasta recibir autoridad, continuar sólo con caracterización/documentos.

**Próximo paso recuperable:** comprobar primero HEAD, el CI de este cierre documental y los dos estados del catálogo. Si una decisión está bloqueada, trabajar únicamente en tareas independientes.

*Todo es Flujo; todo fluye.* 🌊
