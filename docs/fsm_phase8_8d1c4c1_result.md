# Potok 8D1-C4C1 — Retirada inactiva SDK y depuración selectiva de solicitudes

**Fecha:** 2026-11-02 (America/Mexico_City). **Rama:** `feature/fsm-runtime-flow-flusso`. **Resultado:** PASS técnico automatizado; C4C no se declara completo hasta C4C2.

## Contrato probado

Dos máquinas FSM manuales pertenecen a un mismo `PVController`. La máquina secundaria ejecuta primero su `StateUpdate` real y, a través de la fachada `FlowFSMOperations`, encola una transición hacia su estado authored. Después, la máquina principal ejecuta un bloque externo tipo SDK desde su propio `StateUpdate`: registra **dos alias dinámicos** en una plantilla de la misma máquina, solicita dos veces la activación de uno y una vez la del otro, y elimina el alias inactivo que tenía las dos solicitudes.

**Resultado esperado y comprobado:** exactamente las dos solicitudes dirigidas al alias eliminado desaparecen. Permanecen la solicitud de la segunda máquina y la del alias sobreviviente, ambas encoladas hasta el tick manual siguiente. Ni la eliminación ni las solicitudes que nacen en Update reentran en la ejecución actual.

## Evidencia reproducible

- Baseline: `bb9b73a00c3b8fb0d0160a79fcb220137732beab`; [Actions 41569317117](https://github.com/mercurysama/Flujo/actions/runs/41569317117) **SUCCESS 87/87**.
- Commit focal `948c3b9d8a9f4d5df08d31a20e0ad7dba57ba631`: nuevos `tests/fixtures/fsm_sdk_selective_removal_probe.gd`, `tests/runtime/flow_fsm_sdk_selective_removal_test.gd` y `.tscn`; paso obligatorio `Potok-8D1C4C1 SDK selective pending alias removal focal` en `.github/workflows/flujo-fsm.yml`; entrada `FLUJO-BHV-POTOK-SDK-INACTIVE-REMOVE-007` del catálogo, inicialmente `not_run`.
- [Actions 41570578617](https://github.com/mercurysama/Flujo/actions/runs/41570578617): **completed SUCCESS 88/88** en Godot 4.7.2; focal y regresiones obligatorias en **PASS**.
- Durante el callback, el SDK comprueba que el alias eliminado no se resuelve, su lectura de datos está vacía, un cambio posterior hacia él se rechaza y eliminarlo otra vez también rechaza. El alias sobreviviente sigue registrado con datos propios.
- Tras el primer tick, la cola contiene exactamente **dos** solicitudes sobrevivientes; todavía no hubo commit. En el siguiente tick las dos transiciones se confirman en el orden de máquinas esperado, sin activar el alias eliminado.
- Las fachadas retenidas expiran al salir del callback. `FlowGraph`, objetos authored e IDs no cambian; no se modificó código productivo, esquema, editor, `main` ni `demo/main.tscn`.

## Límites y continuidad

Este microbloque demuestra únicamente la **eliminación de un alias inactivo** mediante un callback de SDK real durante `StateUpdate`. El contrato de **alias activo con fallback**, y la garantía de orden `Exit→Enter` inducida por esa eliminación, siguen **PENDING** y se comprobarán en el microbloque **8D1-C4C2**; las pruebas 8C1 y 8C2 previas cubren operaciones directas sobre el runtime, pero no reemplazan ese caso SDK. No se afirma sandbox contra GDScript hostil.

Las instrucciones versionadas `flujo-baseline` y `flujo-prove` han sido consultadas, **no invocadas formalmente**; Godot local **NOT RUN**, Godot 4.7.2 remoto **PASS**. La fase 7 mantiene **25 pruebas humanas pendientes**, 15 Fedora y 10 Android; CI no equivale a aprobación visual.

**Continuidad:** verificar HEAD y Actions en `feature/fsm-runtime-flow-flusso`; continuar **8D1-C4C2**, diseñando cuidadosamente la llamada SDK de eliminación de alias activo fuera de `tick`, con fallback válido y eventos Exit→Enter ordenados, y registrar explícitamente cualquier limitación de reentrancia. Después **8D1-C5** auditará C1–C4 antes de declarar cerrado 8D1-C.

*Todo es Flujo; todo fluye.* 🌊
