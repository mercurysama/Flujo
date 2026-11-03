# Potok 8D1-C1A — Prueba de referencias expiradas del SDK

**Fecha:** 2026-11-02, zona America/Mexico_City. **Rama:** `feature/fsm-runtime-flow-flusso`.

## Alcance y contrato

Reutilizar `FlowFSMOperations` y el ejecutor compartido, sin refactorizar la producción si su comportamiento existente cumple el contrato. Desde un `FlowBlock` de prueba se registra un alias en `StateEnter` y se conserva la fachada fuera del callback. Tras el retorno deben fallar `register_state`, `has_state`, `change_state`, `remove_state`, `get_state_data` y `set_state_data`, sin modificar `FlowGraph`, catálogo dinámico, datos, estado activo ni cola.

## Commits y evidencia

- Baseline: `85a9ace1aab97dfc6f9248910b7fa05462e2a4d7`, [CI 41558938893](https://github.com/mercurysama/Flujo/actions/runs/41558938893), SUCCESS 81/81.
- [Plan de 8D1-C](fsm_phase8_8d1c_microblocks.md): `5f85bede459a18b2a0930ae847f97084a99d632c`.
- Fixture `tests/fixtures/fsm_sdk_retained_operations_probe.gd`: `ef97663c0daee9e86a73d044855006373333497b`.
- Focal `tests/runtime/flow_fsm_sdk_expired_operations_test.gd`: `b5634ba68a0be15e7c03bdb027d014cb2eb1cfdc`; escena `.tscn`: `8ea4bd0ab9efb66545c13b1da3e0415c27d65534`.
- Paso requerido en `.github/workflows/flujo-fsm.yml`: `1a23ab129619fafb91928f86cfbd459cdfd99d80`.
- Catálogo `FLUJO-BHV-POTOK-SDK-CAPABILITY-EXPIRY-001`, creado `not_run` hasta la confirmación de CI.
- [CI focal inicial 41562174607](https://github.com/mercurysama/Flujo/actions/runs/41562174607): **SUCCESS 82/82**. [CI del HEAD 41562328203](https://github.com/mercurysama/Flujo/actions/runs/41562328203): **SUCCESS 82/82**.
- Incidente separado: [CI 41562016330](https://github.com/mercurysama/Flujo/actions/runs/41562016330) **FAIL** por espacios finales en el documento del plan, corregido en `585cbdd2a41da9886048183391a23aef5a78eee6`. No fue fallo del runtime.

## Decisión y limitaciones

- **PASS técnico 8D1-C1A.** Código de producción modificado: **0 archivos**. El comportamiento existente resultó correcto; no se introduce un registro adicional.
- `flujo-baseline` y `flujo-prove` se leyeron desde `tools/agent_skills` como procedimientos versionados, pero no hubo invocación formal de estas Skills. Godot local: **NOT RUN** por no estar instalado; ejecución remota real: GitHub Actions Godot 4.7.2.
- No se ha demostrado todavía la expiración en Update/Exit, parada/reinicio, cambio de grafo, dos controladores, Timer/Constructor ni el ciclo SDK Add→Change→Remove. Estas verificaciones pertenecen a C1B–C5.
- La aceptación humana de fase 7 permanece **PENDING**: 15 pruebas Fedora y 10 Android. Un PASS de CI no certifica experiencia visual.

**Punto de recuperación:** leer HEAD y última ejecución de Actions, continuar **8D1-C1B** según `docs/fsm_phase8_8d1c_microblocks.md`, y conservar las regresiones anteriores.

*Todo es Flujo; todo fluye.* 🌊
