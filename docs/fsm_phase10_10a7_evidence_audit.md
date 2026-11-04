# Potok 10A-7 — Auditoría de trazabilidad y evidencia CI

**Fecha:** 2026-11-03. **Rama:** `feature/fsm-runtime-flow-flusso`. **Base auditada:** `07d8050c82a50f441e4428883e120d64fa0df4d5`. **Tipo de tarea:** revisión de evidencia, sin cambio de producción, UI, baseline ni catálogo. **Dictamen de alcance:** caracterizaciones 10A-3/4/5 verificadas por CI; contrato de DEBUG-FSM y aceptación final **no aprobados**.

## 1. Cadena requisito → prueba → evidencia → commit

| Requisito / frontera | Caracterización | Comportamiento en catálogo | Commit que introdujo la focal | GitHub Actions exitoso |
|---|---|---|---|---|
| DEBUG-01/02/05/06/11, señales existentes | `tests/runtime/flow_fsm_observability_existing_signals_test.tscn` (10A-3) | `FLUJO-BHV-POTOK-OBSERVABILITY-EXISTING-001` = `passing` | `15da55c216e62afbd8aeb2c2ded40e1107983a39` | [#41734104878](https://github.com/mercurysama/Flujo/actions/runs/41734104878) |
| DEBUG-04, condición `false`, ganador y no-op | `tests/runtime/flow_fsm_observability_conditions_test.tscn` (10A-4) | `FLUJO-BHV-POTOK-OBSERVABILITY-CONDITIONS-002` = `passing` | `eb7ba4b87d952d639e83b19a3c7c7abec4935249` | [#41744246830](https://github.com/mercurysama/Flujo/actions/runs/41744246830) |
| DEBUG-01/03/08/11, ciclo de vida y relojes | `tests/runtime/flow_fsm_observability_lifecycle_test.tscn` (10A-5) | `FLUJO-BHV-POTOK-OBSERVABILITY-LIFECYCLE-003` = `passing` | `0c2204c71fa85704aa63cc0113851ae19f208e5c` | [#41744492793](https://github.com/mercurysama/Flujo/actions/runs/41744492793) |
| DEBUG-07, presupuesto de retención | `docs/fsm_phase10_10a6_trace_budget_proposal.md` | **Ninguna entrada automática**: sólo propuesta | `1041dcec6567c28b489936631694c1ec9666f888` | [#41744622179](https://github.com/mercurysama/Flujo/actions/runs/41744622179) |

**Precisión de lectura:** PASS en los tres tests caracteriza señales **ya existentes**; no significa que DEBUG-04 (explicación completa de candidatos), DEBUG-07 (buffer circular) o DEBUG-10 (controles interactivos) estén implementados. Los respectivos contratos en `docs/fsm_observability_contract_proposal_v0.md` están marcados como **PROPUESTA**.

## 2. Cierre documental anterior y prueba presente

- El cierre de tanda 2 es el commit `07d8050c82a50f441e4428883e120d64fa0df4d5`; su workflow [#41745215720](https://github.com/mercurysama/Flujo/actions/runs/41745215720) estaba **in_progress** al iniciar 10A-7. Este documento **no lo marca aprobado** hasta consultar resultado final y hash del mismo run.
- Los workflows #41734104878, #41744246830, #41744492793, #41744622179 constan como `completed/success` en GitHub Actions, ligados a sus SHAs. Incluyeron las focales en el workflow obligatorio según su fecha de introducción. **La mera existencia de una fixture o el estado `passing` histórico no reemplaza correrla hoy.**
- La caracterización 10A-4 no registra `false` ni `self` como diagnósticos: valida la **ausencia** de señales de descarte/commit. Un depurador futuro necesita instrumentación con semántica aprobada.
- La caracterización 10A-5 observa el runtime **después** de `_ready`: no valida recuperación de `machine_started` inicial, replay ni visibilidad de ventanas del editor.
- La propuesta 10A-6 identifica límites **del ejecutor** que no son cuotas de historial; no contiene benchmarks medidos.

## 3. Huecos y límites de evidencia

| Necesidad | Estado real | Evidencia faltante para cierre |
|---|---|---|
| API de lectura structured trace y circular bounded | NO IMPLEMENTADO | Contrato aprobado + pruebas RED/GREEN de capacidad y copias |
| Consulta inicial del estado para observador tardío | SOLO `get_active_state_id` y `get_active_machine_ids`; sin snapshot DEBUG-FSM | Interfaz de inspección read-only definida y test |
| Fase actual, condiciones fallidas/candidatas y últimas decisiones | NO OBSERVABLE mediante señales existentes | Captura de evaluación única y semántica de resultado |
| Inspección de variables en contexto | NO IMPLEMENTADA como API de debugger | Definir fuente y redacción; preservar propiedad del grafo |
| Depurador visual/editor Godot | NO IMPLEMENTADO | Aceptación de diseño, UI, pruebas visuales Fedora y Android |
| Pausa / reanudar / avanzar tick con seguridad | NO IMPLEMENTADO como contrato de depuración | Política por máquina/controlador y pruebas reentrantes |
| Rendimiento de historial | NOT MEASURED | Benchmark con límites aprobados |
| `$flujo-baseline` y `$flujo-prove` | NO INVOCADAS FORMALMENTE | Godot 4.7.2 local, salidas y códigos |
| Revisión humana FSM | **0/25** diferida | 15 Fedora + 10 Android (sin suplantarlas por headless) |
| Fase 9 persistencia | CONDICIONAL | F5–F7/F7R, autorización F9, política F10 y pruebas físicas |

## 4. Auditoría de gobernanza e invariantes

`AGENTS.md`, `docs/constitution.md`, `docs/development_workflow.md` y `docs/fsm_implementation_plan.md` exigen determinismo, IDs estables, ejecución por instancia, separación editor/runtime, ninguna mutación silenciosa de `FlowGraph`, métricas no inventadas y aprobación humana antes de integrar. Se preservaron los contratos FLU-FSM-001/002/003/004; `main`, esquemas y snapshot `format_version=1` no se tocaron durante esta tanda.

**No confundir:** los scripts de Skills versionados leídos por GitHub son información, **no la invocación formal** exigida para cambios productivos. Este bloque es una auditoría documental; no activa `$flujo-prove` ni reclama `PASA`.

## 5. Medidas de flujo verificables y siguiente corte

**Hechos medibles:** 3 fixtures documentadas, 3 entradas de catálogo `passing` sólo tras sendos CI exitosos, 1 matriz de pruebas propuesta, 4 workflows previos `completed/success`. Duración de ingeniería, consumo de recursos, incremento de memoria, FPS/latencia e interacción manual: **not measured**. **Riesgo de interpretación:** convertir caracterización en supuesta nueva capacidad.

**Siguiente 10A-8:** inspeccionar la composición `addons/vp_flujo/plugin.gd`, `editor/fluo_drawer.gd`, `editor/flow_fsm_editor_projection.gd` y `runtime/pv_controller.gd`; recomendar rutas posibles para mostrar una vista depuradora sin editar el grafo ni contaminar runtime con `Editor*`.

*Todo es Flujo; todo fluye.* 🌊
