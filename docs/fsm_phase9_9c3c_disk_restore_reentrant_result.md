# Potok 9C3-C — Reentrancia de restore_from_file en tick

**Fecha:** 2026-11-03. **Rama:** `feature/fsm-runtime-flow-flusso`. **Estado:** `not_run`, pendiente del CI integral.

Prueba focal `tests/runtime/flow_fsm_snapshot_disk_restore_reentrant_test.tscn` y gate obligatorio `Potok-9C3C in-tick disk restore reentrancy focal`. Usa dos máquinas MANUAL, dos controladores y un snapshot inicial real escrito a `user://`. Dentro de `StateUpdate` y `transition_committed` intenta `restore_from_file` y anidar ticks; estos intentos deben retornar `false` y no introducir callbacks recursivos. La cola generada por Update y la del segundo controlador se conservan. Fuera del tick el restore debe aprobar y ejecutar Exit(A), Exit(B), Enter(A), Enter(B), vaciando solo la cola del propietario. Después, el segundo controlador procesa su solicitud sin contaminar el trace del propietario.

Se registra `FLUJO-BHV-POTOK-SNAPSHOT-DISK-REENTRANCY-018` con cobertura `automatic` y baseline `not_run`. La validación anterior de callbacks [Actions 41681389535](https://github.com/mercurysama/Flujo/actions/runs/41681389535) fue **SUCCESS 107/107**; el nuevo CI requiere su propia comprobación. No se modifica el runtime, codec, contrato, esquema, `main` ni la escena demo. F5–F7 siguen abiertos y las 25 pruebas humanas aplazadas.

**Siguiente 9C3-D:** verificar primero focal e integral CI; cambiar a passing solo tras éxito, y continuar a 9D1.

*Todo es Flujo; todo fluye.* 🌊
