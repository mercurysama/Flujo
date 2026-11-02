# Potok 7F-1D2B — Revertir tipado y aislamiento entre propietarios SDK

**Fecha:** 2026-11-02. **Rama:** `feature/fsm-runtime-flow-flusso`. **Baseline verificado:** `c2a281ed3be9e1c9db5bfcf886cf1a777ca00bff`, [Actions 41523094769](https://github.com/mercurysama/Flujo/actions/runs/41523094769) SUCCESS.

## Evidencia

- `8981530f143bc48c75fba9d2fb0ad3d216c5a29c`: prueba `tests/editor/flow_fsm_sdk_owner_revert_journey_test.gd`.
- `a996b60d4a97f13b363668ec44290e3f9a66cee5`: registro de test focal en `.github/workflows/flujo-fsm.yml`.
- La prueba focal 7F-1D2B pasó en [Actions 41523995815](https://github.com/mercurysama/Flujo/actions/runs/41523995815); ese run permaneció marcado `in_progress` al consultarlo aunque mostraba 73/73 pasos completados. **GREEN global confirmado independientemente** en [Actions 41524160884](https://github.com/mercurysama/Flujo/actions/runs/41524160884): `completed SUCCESS`, **74/74 pasos**, cero fallos, commit documental `6546216178bceb560cd7e0021f2f6859116fffeb` sobre la misma implementación y test.

## Qué comprueba

Genera dos máquinas dentro de un controlador y otra máquina dentro de un segundo `PVController`. Usa un bloque externo real `manual_output:output` y el catálogo de descriptores SDK para abrir Flusso desde Enter, modificar `message`, `boolean_value` y `ranged_int`. Comprueba que Revertir vuelve al snapshot inicial de forma atómica y que Undo/Redo restaura alternadamente los valores esperados. Conserva un descriptor y un botón de la sesión antigua, cambia de máquina, llama el callback anterior e invoca el botón anterior: el recurso original y el segundo estado permanecen intactos, sin entradas nuevas en el historial. Repite el intento tras cambiar de `PVController`; ambas máquinas y el bloque externo mantienen su pertenencia, su `null` inicial y validez estructural.

No se han modificado los comandos de producción ni el esquema. Los test focales previos de SDK en las tres fases y las pruebas de persistencia siguen en el workflow.

## Continuidad

**Siguiente 7F-1D2C**: Confirm/Cancel Delete de un bloque SDK externo, UndoRedo, copia/script y nueva apertura de Flusso tras reorientación de contexto; después **7F-1D3** guardado/recarga de la jornada integrada y **7F-1D4** auditoría de aceptación. Las 15 pruebas Fedora y 10 Android siguen **PENDING**. Sin merge a `main`, sin aceptación visual humana ni auditoría local Fedora.

*Todo es Flujo; todo fluye.* 🌊
