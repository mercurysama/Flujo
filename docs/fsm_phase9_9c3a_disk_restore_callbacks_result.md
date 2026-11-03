# Potok 9C3-A — Callbacks y colas durante restore_from_file

**Fecha:** 2026-11-03. **Rama:** `feature/fsm-runtime-flow-flusso`. **Contrato:** [FLU-FSM-004](fsm_snapshot_contract_v1.md). **Estado:** behavior `FLUJO-BHV-POTOK-SNAPSHOT-DISK-CALLBACKS-017` **not_run**, pendiente de CI integral.

La nueva escena `tests/runtime/flow_fsm_snapshot_disk_restore_callbacks_test.tscn` toma el contrato de la focal en memoria [8D2-B3B2](../tests/runtime/flow_fsm_restore_callback_queue_test.tscn) y comprueba el camino adicional de **lectura real desde disco**: dos máquinas MANUAL, snapshot de ambos estados objetivo, retorno a estado authored inicial, solicitudes pendientes direct/event en propietario, solicitud propia en otro controlador. `restore_from_file` debe producir **Exit(A), Exit(B), Enter(A), Enter(B)** exactamente, sin `transition_committed`; vacía solo la cola del propietario. El otro controlador no cambia ni publica señales hasta que se ejecuta su propio tick.

Se añade gate obligatorio `Potok-9C3A file restore callbacks and peer queue focal` Godot 4.7.2, escena y behavior `not_run`. No se modifica runtime, codec, contrato v1, schema, escena demo o `main`. La prueba caracteriza lectura exitosa, **no** reentrancia de callbacks durante un tick (pendiente de 9C3-B). Los riesgos F5–F7 de copia/rename siguen abiertos bajo autorización explícita.

**Base:** [9C2-B checkpoint](fsm_phase9_9c2b_instance_reconstruction_closeout.md) y [Actions 41679988667](https://github.com/mercurysama/Flujo/actions/runs/41679988667) **SUCCESS 106/106**. Las 25 pruebas humanas siguen aplazadas; ninguna prueba local ni Skills formales ejecutadas.

**Siguiente:** 9C3-B, verificar CI y, después de PASS, focal de reentrancia de `restore_from_file` sin duplicar pruebas anteriores.

*Todo es Flujo; todo fluye.* 🌊
