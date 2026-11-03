# Potok 10A — Tanda 1 A/B/C, cierre recuperable

**Fecha:** 2026-11-03. **Rama:** `feature/fsm-runtime-flow-flusso`. **HEAD base verificado:** `15da55c216e62afbd8aeb2c2ded40e1107983a39`. **Estado:** **10A-1 DOCUMENTADO / 10A-2 PROPUESTO / 10A-3 PASS CI**. No significa cierre de fase 10 ni aprobación del contrato.

## Tres microprompts y checkpoints separados

| Microprompt | Entregable | Commit | Evidencia CI |
|---|---|---|---|
| 10A-1 | [auditoría de diagnósticos](fsm_phase10_10a1_diagnostics_audit.md) | `a3d56ae874da2ee1a9b94d9922191b40bfcda238` | [#521](https://github.com/mercurysama/Flujo/actions/runs/41733666657) SUCCESS |
| 10A-2 | [contrato v0 propuesto](fsm_observability_contract_proposal_v0.md) | `2dcfca0dc7eb8d114c9ba41fe1659cbf860b865a` | [#522](https://github.com/mercurysama/Flujo/actions/runs/41733785823) SUCCESS |
| 10A-3 | `tests/runtime/flow_fsm_observability_existing_signals_test.gd`, `.tscn`, gate CI, entrada en catálogo | `15da55c216e62afbd8aeb2c2ded40e1107983a39` | [#523](https://github.com/mercurysama/Flujo/actions/runs/41734104878) SUCCESS, focal 10A-3 SUCCESS, job integral SUCCESS |

### Cobertura e invariantes

Rechazo con código estable, evento sin matching, copia profunda de payload, secuencia Update → Consumed → Exit → Enter → Commit, metadatos directos tras señal legacy, relojes independientes, colas separadas y autoría de `FlowGraph` inmutable. El comportamiento `FLUJO-BHV-POTOK-OBSERVABILITY-EXISTING-001` pasa `not_run → passing` **después** de confirmar #523. No se creó historial ni nueva API; se observa exclusivamente lo ya existente.

### Auditoría de límites

- **Archivos productivos modificados:** ninguno. **Persistencia/esquemas:** sin cambios. **Workflow:** sólo nueva focal obligatoria; pasos existentes preservados. **Catálogo:** una entrada nueva y posterior cierre de su resultado por evidencia.
- **Regresión integral:** los tres workflows finalizaron SUCCESS. `git diff --check` y catálogo se ejecutaron en los jobs remotos; sin ejecución en Fedora local. La verificación formal de las Skills versionadas no se efectuó: **NOT RUN**.
- **Riesgos abiertos:** no se infiere qué condiciones fallaron sin instrumentación; no fijar buffer ni exponer payloads editables sin autorización; depurador y controles de pausa siguen pendientes.
- **Fase 9:** 9R1-A/B demostrado, aún condicionada por fallos exactos F5–F7/F7R, política F9 no aprobada, F10 sin autocarga de backup y almacenamiento real no verificado.
- **Revisión humana:** Fedora 0/15, Android 0/10; diferidas por el responsable. Sin merge/release, `main` intacto.

### Siguiente tanda propuesta (tres bloques seguros)

1. **10A-4 — Condiciones/no-op:** comparar cobertura actual de `tests/runtime/flow_fsm_conditions_test.tscn` y caracterizar señales públicas sin instrumentación, declarando los resultados actualmente no observables.
2. **10A-5 — Ciclo de vida:** caracterizar `machine_started/stopped`, Enter/Exit, reset/stop y relojes entre controladores, sin cambiar señales ni runtime.
3. **10A-6 — Presupuestos:** auditar límites de retención, costos y alternativas de buffer; congelar *propuesta de decisión* y pruebas RED sólo cuando corresponda; **ninguna implementación 10B** antes de aceptación de política/capacidad.

El próximo chat puede recuperar desde este checkpoint y verificar primero el HEAD y el último CI. La **fase 10 permanece abierta**.

*Todo es Flujo; todo fluye.* 🌊
