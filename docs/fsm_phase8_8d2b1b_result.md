# Potok 8D2-B1B — Teardown y restart de lifetimes y caducidad del SDK

**Fecha:** 2026-11-02 (America/Mexico_City). **Rama exclusiva:** `feature/fsm-runtime-flow-flusso`. **Dictamen:** **PASS automatizado**, 8D2-B1B solamente; no declarar 8D2 o fase 8 completa.

## Escenario y contrato

Conforme a [FLU-FSM-003](fsm_dynamic_contract_v1.md), [8D2-A](fsm_phase8_8d2a_audit.md) y [plan 8D2](fsm_phase8_8d2_microblocks.md), dos `PVController` independientes comparten un `FlowGraph` esquema 3 y una misma definición de máquina manual. El controlador A crea alias dinámicos `EPHEMERAL`, `SESSION` y `PERSISTENT`; activa **PERSISTENT** y encola dos solicitudes directas a los otros alias y un evento. B mantiene un alias propio `SESSION` y una solicitud directa pendiente. Un `FlowBlock` externo de prueba recibe `FlowFSMOperations` en un `StateEnter` real de A y retiene la referencia para comprobar su caducidad. También se observa el `StateExit` de cierre.

Al deshabilitar `visual_program_enabled` de A, `PVController` detiene su `FlowFSMRuntime`: `StateExit:worker-exit → state_exited(PERSISTENT) → machine_stopped(PERSISTENT)` una sola vez, con **cero transiciones pendientes confirmadas**. `get_fsm_runtime()` devuelve `null` y el runtime antiguo queda sin actividad, estados activos, alias de **ninguna política** ni solicitudes.

Al reactivar **el mismo controlador**, se instancia otro `FlowFSMRuntime`, se ejecuta exactamente una entrada a `Idle` authored y el registro/cola comienzan vacíos: `PERSISTENT` **no se recupera automáticamente** por su nombre de política. Tampoco pueden operar las referencias SDK de `StateEnter` y `StateExit` capturadas antes de stop; sus lecturas, solicitudes y registros se rechazan incluso después de que nace el runtime nuevo. Los IDs viejos no resuelven; el runtime nuevo registra su propio alias limpio.

La cola y el estado de B permanecen intactos durante el cierre y reinicio de A. B confirma su transición solo al recibir su propio tick. Ninguna API escribe en `FlowGraph`, modifica la máquina authored o altera snapshots.

## Pruebas y evidencia

- **Baseline:** checkpoint `f8a4120beb89ee27c276a9645ad045b69fc1e162`, [Actions 41577454239](https://github.com/mercurysama/Flujo/actions/runs/41577454239) **SUCCESS 91/91**.
- **Commit focal:** `2dad13c6815ae4269cbd42ebd07eb79f8fac2854`. Se añadieron `tests/fixtures/fsm_lifetime_stop_restart_probe.gd`, `tests/runtime/flow_fsm_lifetime_stop_restart_test.gd` y `.tscn`, y el paso obligatorio `Potok-8D2B1B lifecycle teardown and SDK expiry focal` en `.github/workflows/flujo-fsm.yml`.
- **Catálogo:** `FLUJO-BHV-POTOK-LIFETIME-STOP-002`, creado como `not_run` hasta ejecutar el focal.
- **CI:** [GitHub Actions 41578192657](https://github.com/mercurysama/Flujo/actions/runs/41578192657), **completed SUCCESS 92/92** en Godot **4.7.2**, sin pasos fallidos, focal B1B **PASS** y regresiones de SDK, FSM-003 y FSM-004 preservadas. El catálogo pasa a `passing` solo con esta evidencia.
- **Archivos productivos modificados:** cero. `addons/vp_flujo/runtime/`, `demo/main.tscn`, `main`, definiciones de snapshots y editor permanecen intactos.

## Alcance y límites

La diferencia clave entre B1A y B1B queda ahora caracterizada: **reset conserva SESSION/PERSISTENT**, mientras **stop/restart libera las tres políticas**, salvo que un snapshot PERSISTENT sea guardado y restaurado explícitamente mediante el contrato separado FLU-FSM-004. El test B1B **no** realiza restauración de disco ni demuestra recuperación automática.

La SDK es una fachada por callback, no un sandbox contra GDScript hostil. Ejecutar Godot local/Flatpak: **NOT RUN**. Las skills `flujo-baseline`/`flujo-prove` fueron consultadas como documentos versionados, **no invocadas formalmente**. Pruebas humanas de fase 7: **15 Fedora + 10 Android = 25 PENDING**, no sustituidas por CI.

**Siguiente paso 8D2-B2A:** snapshots con un alias `EPHEMERAL` o `SESSION` activo deben guardar su recuperación como el inicial authored, mientras un alias `PERSISTENT` activo debe conservar su referencia, sin cambiar el codec ni cerrar la fase 9. Comprobar HEAD y CI antes de empezar, añadir focal obligatoria y conservar evidencia independiente.

*Todo es Flujo; todo fluye.* 🌊
