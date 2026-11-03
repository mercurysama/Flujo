# Potok 8D1-C4A — Registro y activación diferida de estado dinámico por SDK

**Fecha:** 2026-11-02 (America/Mexico_City). **Rama:** `feature/fsm-runtime-flow-flusso`. **Estado:** PASS técnico en GitHub Actions.

## Alcance contractual

Un bloque externo `FlowBlock` en `StateEnter` usa exclusivamente `FlowNavigationContext.get_fsm_operations()`, sin llamar directamente a `FlowFSMRuntime`, para registrar un alias de plantilla de la misma máquina y solicitar su activación mediante `change_state`. El registro y la consulta son inmediatos, pero el cambio de estado se **encola**: jamás interrumpe ni reentra en el callback donde nació. El primer tick compatible completa `Update` de origen, `Exit`, `Enter` de la plantilla dinámica y una confirmación `direct`; el `Update` de la nueva identidad sólo ocurre en un tick posterior.

## Evidencia y resultados

- Baseline anterior: `0c6b3749029f4cfd161d11dc52771fdc7d904486`, [Actions 41567300158](https://github.com/mercurysama/Flujo/actions/runs/41567300158), **SUCCESS 85/85**.
- Test commit `89d9bfb7382f44eaa2b52862a3e8562253db4ca9`; archivos añadidos: `tests/fixtures/fsm_sdk_register_and_change_probe.gd`, `tests/runtime/flow_fsm_sdk_register_change_test.gd` y `.tscn`. Cambios de soporte: prueba obligatoria en `.github/workflows/flujo-fsm.yml` y catálogo `FLUJO-BHV-POTOK-SDK-REGISTER-CHANGE-005`, inicialmente `not_run`.
- [Actions 41567631405](https://github.com/mercurysama/Flujo/actions/runs/41567631405): **completed SUCCESS 86/86**. El paso `Potok-8D1C4A SDK queued dynamic activation focal` resultó **PASS**, junto con la regresión completa. No se encontraron fallos de Godot ni necesidad de modificar producción.
- El bloque registra un ID generado válido desde la plantilla autorizada con lifetime `SESSION` y datos `{"source":"SDK","nested":{"level":4}}`; `has_state` y `get_state_data` funcionan durante el callback. El alias reside únicamente en el registro dinámico de la instancia, sin agregarse a `FlowGraph`.
- Tras regresar de `StateEnter`, la fachada retenida rechaza nuevas consultas y cambios. Antes del primer tick, `get_active_state_id` continúa en el estado original, hay exactamente una solicitud encolada y la siguiente instrucción del mismo `StateEnter` se ejecutó normalmente.
- El tick manual inicial produce la traza `StateUpdate:idle-update → StateExit:idle-exit → StateEnter:template-enter → Commit:direct` y consume la solicitud; el segundo tick produce `StateUpdate:template-update`. Se verifica que el grafo original conserva sus objetos e IDs y supera validación.
- Código productivo modificado: **0 archivos**. No cambió `main`, API de SDK, persistencia, esquema ni `demo/main.tscn`.

## Límites y recuperación

Esta focal prueba registro y solicitud de activación desde `StateEnter`; no aprueba aún los contratos C4B de escritura/lectura con copias profundas y payload inválido, ni C4C de retirada dinámica desde el SDK. `FlowFSMOperations` es una fachada de contexto, **no un sandbox GDScript**. Se consultaron como guía las instrucciones versionadas `flujo-baseline` y `flujo-prove`, pero no se invocaron como Skills ejecutables; Godot local **NOT RUN** y Godot 4.7.2 remoto **PASS**. Las 25 pruebas humanas de la fase 7 siguen **PENDING**: 15 Fedora + 10 Android.

**Punto exacto de recuperación:** verificar HEAD y última Actions de `feature/fsm-runtime-flow-flusso`, consultar este reporte y [plan C](fsm_phase8_8d1c_microblocks.md), y comenzar **8D1-C4B** (lectura/escritura de metadatos SDK como copias independientes y rechazo de valores inválidos). Conservar C1A, C1B, C2, C3 y C4A sin debilitamiento de pruebas.

*Todo es Flujo; todo fluye.* 🌊
