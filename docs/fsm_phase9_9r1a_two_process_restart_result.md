# Potok 9R1-A — Snapshot FSM-004 entre procesos independientes

**Fecha:** 2026-11-03. **Rama:** `feature/fsm-runtime-flow-flusso`. **Estado:** `not_run` hasta CI integral.

El script `tests/runtime/flow_fsm_snapshot_two_process_test.gd` dispone de dos escenas: `flow_fsm_snapshot_two_process_write.tscn` y `flow_fsm_snapshot_two_process_restore.tscn`. Ambas crean el mismo grafo de prueba con IDs authored estables, solo dentro de la fixture. Se registró `FLUJO-BHV-POTOK-SNAPSHOT-TWO-PROCESS-020`, y un gate obligatorio de GitHub Actions Godot 4.7.2 que ejecuta **dos procesos separados** con el mismo `XDG_DATA_HOME` temporal obtenido de `mktemp` y limpio por `trap`.

El proceso A registra EPHEMERAL, SESSION y PERSISTENT, activa PERSISTENT y guarda un snapshot portable formato v1 en `user://flujo_fsm_tests/phase9_restart/snapshot.json`. El proceso B vuelve a arrancar el motor; confirma que no hubo carga automática y ejecuta `restore_from_file` explícito, verificando identificadores, datos JSON-safe y ausencia de aliases SESSION/EPHEMERAL.

**PASS solo si:** ambos procesos exit 0, la focal en dos lanzamientos aprueba y la suite integral GitHub Actions finaliza SUCCESS. No prueba reinicio del dispositivo, corte energético ni errores F5–F7. No se cambió código productivo, runtime, codec, formato, modelo, escena demo o `main`; manuales 0/25 aplazados.

**Siguiente 9R1-B:** verificar ambos logs y CI, diagnosticar RED si surge; actualizar `not_run → passing` únicamente tras éxito integral. Después actualizar dictamen 9E1-D.

*Todo es Flujo; todo fluye.* 🌊
