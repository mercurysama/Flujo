# Potok 8B1 — Cuota de estados dinámicos, IDs y orden

**Fecha:** 2026-11-02. **Rama:** `feature/fsm-runtime-flow-flusso`. **Baseline:** `83c8441ed38fba94415f4753f9818e614bf43333`; [Actions 41544539146](https://github.com/mercurysama/Flujo/actions/runs/41544539146) completed SUCCESS. **Contrato:** [auditoría 8A](fsm_phase8_8a_gap_audit.md), [FSM-003 v1](fsm_dynamic_contract_v1.md).

## Evidencia del microbloque

- `3b6540bf43b6d41216b0ac9149d5b6291a6ed0f6`: nuevo focal `tests/runtime/flow_fsm_dynamic_quota_identity_test.gd`.
- `7cfda8e1831811f2b87a92ec784384339d855c27`: nueva escena de prueba `tests/runtime/flow_fsm_dynamic_quota_identity_test.tscn`.
- `7c1fefc3a2c64ad46cf063b69557dfd412a31210`: añade el paso `Potok-8B1 dynamic state quota ID and ordering focal` a `.github/workflows/flujo-fsm.yml`.
- **GREEN global confirmado:** [Actions 41547536522](https://github.com/mercurysama/Flujo/actions/runs/41547536522), **completed SUCCESS 77/77 pasos**, cero fallos, sobre `7c1fefc3a2c64ad46cf063b69557dfd412a31210`; incluye focal 8B1, focal original FSM dynamic y validador de catálogo.

## Prueba existente caracterizada

Dos controladores usan el mismo grafo validado con dos máquinas. Se rechaza la colisión con los IDs authored de plantilla/estado inicial, la plantilla de otra máquina y un intento inválido antes de llenar el cupo. Se registran **128** alias con IDs generados válidos, datos por entrada y orden de enumeración determinista; el 129 es rechazado sin alterar la lista. Se elimina una entrada interior, preservando el orden restante, y se re-registra el ID liberado con política SESSION y datos frescos: reaparece al final, sin duplicarse. Se comprueba independencia de segundo controlador y segunda máquina, inmutabilidad del array `machine.states`, validez de `FlowGraph` y limpieza del registro al detener la primera instancia sin detener la segunda.

## Decisión y límites

La implementación previa ya satisface estos comportamientos: **no se cambió código de producción, esquema, snapshots, runtime ni escenas del usuario**. El cupo `MAX_DYNAMIC_STATES=128` es una constante conforme al contrato v1, aunque el plan inicial sugería configurabilidad; cambiarlo exige un contrato nuevo, no está autorizado en 8B1. Esta prueba usa la implementación real y no representa validación física Android/Fedora.

**Siguiente: 8B2**, plantillas propias/ajenas y datos estructurados, copia profunda y límites de `FlowFSMDataValidator`; después 8C1 lifecycle con fallback. Las **25 pruebas humanas de Fase 7 siguen diferidas**; `main` permanece sin cambios.

*Todo es Flujo; todo fluye.* 🌊
