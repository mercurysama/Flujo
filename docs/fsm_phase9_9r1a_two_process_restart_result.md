# Potok 9R1-A — Snapshot FSM-004 entre procesos independientes

**Fecha:** 2026-11-03. **Rama:** `feature/fsm-runtime-flow-flusso`. **Estado:** **PASS automatizado**. GitHub Actions [41722469207](https://github.com/mercurysama/Flujo/actions/runs/41722469207), `completed SUCCESS`, con ambos procesos Godot 4.7.2 verificados.

El script `tests/runtime/flow_fsm_snapshot_two_process_test.gd` dispone de dos escenas: `flow_fsm_snapshot_two_process_write.tscn` y `flow_fsm_snapshot_two_process_restore.tscn`. Ambas crean el mismo grafo de prueba con IDs authored estables, solo dentro de la fixture. Se registró `FLUJO-BHV-POTOK-SNAPSHOT-TWO-PROCESS-020`, y un gate obligatorio de GitHub Actions Godot 4.7.2 que ejecuta **dos procesos separados** con el mismo `XDG_DATA_HOME` temporal obtenido de `mktemp` y limpio por `trap`.

El proceso A registra EPHEMERAL, SESSION y PERSISTENT, activa PERSISTENT y guarda un snapshot portable formato v1 en `user://flujo_fsm_tests/phase9_restart/snapshot.json`. El proceso B vuelve a arrancar el motor; confirma que no hubo carga automática y ejecuta `restore_from_file` explícito, verificando identificadores, datos JSON-safe y ausencia de aliases SESSION/EPHEMERAL.

**PASS solo si:** ambos procesos exit 0, la focal en dos lanzamientos aprueba y la suite integral GitHub Actions finaliza SUCCESS. No prueba reinicio del dispositivo, corte energético ni errores F5–F7. No se cambió código productivo, runtime, codec, formato, modelo, escena demo o `main`; manuales 0/25 aplazados.

**Evidencia real 9R1-A:** en el log del job `headless` del workflow [41722469207](https://github.com/mercurysama/Flujo/actions/runs/41722469207) aparecen `[Flujo] Potok 9R1 process write passed` y `[Flujo] Potok 9R1 process restore passed`, en dos lanzamientos separados, sin error ni timeout; el paso `Potok-9R1A two separate Godot processes preserve user snapshot` y el job completo finalizaron `success`. El uso de `XDG_DATA_HOME` temporal y `trap` quedó confirmado. El contrato del snapshot v1, la restauración explícita y la ausencia de autoload se mantienen.

**Cierre 9R1-B:** [reporte de verificación](fsm_phase9_9r1b_two_process_restart_closeout.md), catálogo `FLUJO-BHV-POTOK-SNAPSHOT-TWO-PROCESS-020` marcado `passing` por evidencia de CI. [Dictamen actualizado](fsm_phase9_9e1d_post_restart_conditional_verdict.md): fase 9 permanece condicionada por F5–F7/F7R, F9 y revisión humana. No hubo cambios productivos.

*Todo es Flujo; todo fluye.* 🌊
