# Potok 10A — Tanda 3, checkpoint 10A-7/8/9

**Fecha:** 2026-11-03. **Rama:** `feature/fsm-runtime-flow-flusso`. **HEAD de entrada:** `f795ab7098680a0feb3a137c6c6054873638d86c`. **Tipo de entrega:** auditoría documental, integración editor/juego propuesta y contrato candidato; **NO implementación 10B**. Los tres microbloques están comprometidos por separado, más una corrección mínima de whitespace.

| Microbloque | Entrega | Commit | Evidencia al generar el checkpoint |
|---|---|---|---|
| **10A-7** | [Auditoría requisito → test → CI](fsm_phase10_10a7_evidence_audit.md) | `432f59e1700a1fa433ff0bf4170100fc007adc91` | [#41745659957](https://github.com/mercurysama/Flujo/actions/runs/41745659957), **ejecución en progreso al elaborar este registro** |
| **10A-8** | [Mapa de integración Godot Debugger / Fluo](fsm_phase10_10a8_editor_debugger_integration_map.md) | `34a427bdf7cba0bf30439cc58ca8ffa66b38d600` | [#41745779604](https://github.com/mercurysama/Flujo/actions/runs/41745779604), **en progreso** |
| **10A-9** | [Contrato DEBUG-FSM v1 candidato](fsm_observability_contract_v1_candidate.md) | `c3229cf0fa43808541acebf8357238195cfd614e` | [#41745931151](https://github.com/mercurysama/Flujo/actions/runs/41745931151) **FAILED** sólo en `git diff --check` por trailing whitespace línea 35 |
| **10A-9 fix** | Corrección de **un solo espacio** en la línea 35, contenido técnico intacto | `f795ab7098680a0feb3a137c6c6054873638d86c` | [#41746020240](https://github.com/mercurysama/Flujo/actions/runs/41746020240), **en progreso**, whitespace gate superado al momento de revisar |

**Importante:** el CI de checkpoint de tanda 2 [#41745215720](https://github.com/mercurysama/Flujo/actions/runs/41745215720) terminó **SUCCESS** después de comenzar la tanda 3. Las tres focales 10A-3/4/5 conservaron su `passing` histórico correctamente fundamentado. No se realizaron nuevas modificaciones de tests ni del catálogo.

## Hallazgos útiles

1. `10A-7`: tres tests caracterizan señales **preexistentes**, no el historial, ni explicación de condición falsa ni paso a paso del depurador. Se separa correctamente `passing` de nuevas capacidades todavía no existentes.
2. `10A-8`: el `EditorPlugin` presente es una composición de editor; Fluo/Flow/Flusso son superficies de autoría. `EditorDebuggerPlugin`/`EditorDebuggerSession` son una vía posible de transporte con sesiones, pendiente de validación en Godot 4.7.2 y aprobación. El juego debe quedar independiente de `Editor*`.
3. `10A-9`: propuesta v1 da elecciones concretas para retención **128 registros** y cuota lógica de **1024 bytes JSON/registro**, captura **desactivada por defecto**, aislamiento por controlador, minimización/sanitización, orden, conexión tardía y pruebas RED/GREEN. **Estos parámetros NO son política aceptada**.
4. El fallo del CI inicial de 10A-9 fue reproducible y específico; no se cambió la prueba para obtener PASS. Una corrección de whitespace reintrodujo el contrato bajo un nuevo SHA y CI nuevo.

## Límites y próximos gates

- **Archivos productivos/editor/esquemas/snapshot:** ninguno modificado. `main` sin merges, release ni rebase.
- **Fase 9:** aceptación condicional preservada; F5–F7/F7R y política F9/F10 siguen en espera.
- **Revisión humana:** 0/25, diferida. Godot local/Fedora y Skills `$flujo-baseline`/`$flujo-prove` formales: **NOT RUN**.
- **Contrato 10B-G1..G6:** **NO APROBADO**, 10B-core bloqueada. 10B-G7/8 requieren decisiones por separado; pausa/step no está autorizada.
- **Estado CI:** consultar los enlaces indicados, resultados pueden cambiar; no confundir un documento publicado con PASS de toda la suite. Si alguna regresión falla, conservar evidencia de job y corregir sólo causa verificada.

## Próxima tanda segura sugerida

1. **10A-10** cierre de trazabilidad CI por SHA y revisión de riesgos de contrato v1 sin autorizar runtime.
2. **10A-11** diseño de pruebas RED de APIs propuestas, documentadas sin crear tests que fallen como gate obligatorio antes de la aprobación.
3. **10A-12** consolidación 10A y handoff con decisión explícita al responsable sobre 10B-G1..G6; no asumir respuesta.

**Veredicto del bloque:** los tres microbloques documentales están preparados y recuperables. **Fase 10 sigue ABIERTA.** No confundir el avance 10A con aceptación de una capacidad de debugger ya operativa.

*Todo es Flujo; todo fluye.* 🌊
