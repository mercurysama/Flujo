# Potok 10A-10 — Certificación de CI por SHA y riesgos del contrato v1

**Fecha:** 2026-11-03. **Rama:** `feature/fsm-runtime-flow-flusso`. **HEAD base comprobado:** `53b67b68540ab3f76700004fe3444a1b7e46f288`. **Ámbito:** auditar evidencia remota y contrato candidato, no modificar implementación ni afirmar que DEBUG-FSM está operativo.

## 1. Verificación de ejecuciones y procedencia

Se consultaron los workflows **por ID** y su resultado final, y los pasos del job `headless`. Los enlaces a los runs forman la evidencia reproducible; un PASS de CI es exclusivo del SHA evaluado.

| Artefacto | SHA evaluado | Actions | Conclusión | Estado de las tres focales 10A-3/4/5 |
|---|---|---|---|---|
| 10A-7, auditoría de evidencia | `432f59e1700a1fa433ff0bf4170100fc007adc91` | [41745659957](https://github.com/mercurysama/Flujo/actions/runs/41745659957) | **completed/success** | **success/success/success** |
| 10A-8, mapa de integración | `34a427bdf7cba0bf30439cc58ca8ffa66b38d600` | [41745779604](https://github.com/mercurysama/Flujo/actions/runs/41745779604) | **completed/success** | **success/success/success** |
| 10A-9, contrato candidato inicial | `c3229cf0fa43808541acebf8357238195cfd614e` | [41745931151](https://github.com/mercurysama/Flujo/actions/runs/41745931151) | **completed/failure** | **skipped/skipped/skipped** |
| 10A-9, corrección línea 35 | `f795ab7098680a0feb3a137c6c6054873638d86c` | [41746020240](https://github.com/mercurysama/Flujo/actions/runs/41746020240) | **completed/success** | **success/success/success** |
| Tanda 3, checkpoint recuperable | `53b67b68540ab3f76700004fe3444a1b7e46f288` | [41746152560](https://github.com/mercurysama/Flujo/actions/runs/41746152560) | **completed/success** | **success/success/success** |

**Postmortem concreto:** el workflow inicial de 10A-9 detuvo la ejecución en `Git whitespace gate (latest committed diff)`; el log reportó `docs/fsm_observability_contract_v1_candidate.md:35: trailing whitespace` y salida 2. Se corrigió **sólo el espacio final** y se ejecutó un workflow nuevo; no se debilitó ningún gate ni se reescribió el historial de commits. El registro inicial debe seguir figurando FAILED, no se convierte retrospectivamente en PASS.

**Precisión:** cada run exitoso registra 113 pasos del job `headless` con conclusión `success` (esto **no** significa 113 tests independientes); los tres pasos focales específicos están incluidos. Los jobs se ejecutaron en GitHub Actions con Godot 4.7.2 según el workflow del proyecto. No se ejecutó una instalación Godot de Fedora local ni las Skills formales.

## 2. Verdad actual de la API frente a requisitos

| Requisito | Evidencia existente | Estado realmente alcanzado |
|---|---|---|
| DEBUG-01 y DEBUG-02: aislamiento/orden de señales | Focal 10A-3, dos `PVController` | Comportamiento actual caracterizado, **passing** |
| DEBUG-04: condiciones `false`, autotransición y ganador | Focal 10A-4 | Sólo señales públicas del ganador y ausencia de commit no-op; **no hay causa estructurada todavía** |
| DEBUG-08: reset/stop/relojes | Focal 10A-5 | Comportamiento observable actual caracterizado, **passing** |
| DEBUG-07: bitácora circular limitada | [10A-6](fsm_phase10_10a6_trace_budget_proposal.md) | **Sólo propuesta**; memoria/CPU **not measured** |
| FSM-R27: debugger muestra transiciones candidatas/errores | [10A-8](fsm_phase10_10a8_editor_debugger_integration_map.md) | Sin UI ni canal integrado |
| FSM-R28: inspección no modifica el grafo | Invariante de pruebas existentes y propuesta v1 | No hay API nueva de inspección/editor que declarar aceptada |

## 3. Riesgos contractuales que 10B no debe omitir

1. **Retención:** el anillo de 128 registros y cuota de 1024 bytes UTF-8 por registro son **parámetros candidatos**, no memoria real medida; establecer comportamiento de truncamiento y pérdida de eventos antes de codificar.
2. **Semántica:** una solicitud `admitted` no implica `delivered` ni `committed`; `considered` no puede prometer la evaluación de una condición que el arbitraje nunca ejecutó.
3. **Orden legacy:** preservación de `event_consumed`, `transition_committed` y `direct_transition_committed`; no añadir emisión síncrona reentrante que cambie la cola o el orden de callbacks.
4. **Identidades y aislamiento:** secuencia/epoch por runtime y controlador, separadas de ID authored y `session_id` del depurador nativo; no persistir referencias a `Node`.
5. **Captura deshabilitada:** garantía observacional y presupuestos medibles, no afirmar 'costo cero' sin medición; no contaminar export.
6. **Arranque tardío:** el estado actual se puede consultar parcialmente, pero no reconstruir eventos previos de `_ready`; el snapshot de debugger y posibles gaps requieren contrato expreso.
7. **Condiciones y datos:** registrar resultado ya calculado sin `resolve()` adicional, sin payloads/objetos/expresiones libres; sanitizar antes de exponer.
8. **Gobernanza:** `AGENTS.md` exige `$flujo-baseline` antes y `$flujo-prove` al concluir cambios productivos. Leer sus archivos en GitHub **no** sustituye su ejecución. Revisión humana Fedora 0/15, Android 0/10.

## 4. Veredicto de 10A-10

**CI histórico de la tanda 3: verificado por SHA; el fallo original tiene corrección demostrada.** El contrato DEBUG-FSM v1 continúa como **candidato no aprobado**, y la fase 10 continúa abierta. No se cambian el catálogo, la implementación FSM, `main`, Fluo, snapshot, esquemas ni el conjunto de pruebas. El test formal del **nuevo commit documental** se registra de forma independiente en GitHub Actions; no afirmarlo hasta observar su conclusión.

**Continuación autorizada de alcance documental:** 10A-11, diseño de RED/GREEN para 10B sin gate roto; 10A-12, handoff con estados y decisiones explícitas.

*Todo es Flujo; todo fluye.* 🌊
