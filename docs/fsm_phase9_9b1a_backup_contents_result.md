# Potok 9B1-A — Caracterización de respaldo con guardados distintos

**Fecha:** 2026-11-03 (America/Mexico_City). **Rama:** `feature/fsm-runtime-flow-flusso`. **Contrato:** [FLU-FSM-004](fsm_snapshot_contract_v1.md) y [9A2](fsm_phase9_9a2_contract_and_gate.md). **Estado:** **PASS automatizado y cerrado técnicamente**; `baseline_status=passing` tras CI integral.

- Nueva escena obligatoria `tests/runtime/flow_fsm_snapshot_backup_contents_test.tscn`, implementación `.gd`. Catálogo: `FLUJO-BHV-POTOK-SNAPSHOT-BACKUP-CONTENT-012`. Gate: `Potok-9B1A distinct snapshot backup contents focal`, con timeout 70 s en Godot 4.7.2.
- A partir de un controlador real, activar alias dinámico `PERSISTENT` con datos JSON-safe. Generar snapshot portable `S1`, guardarlo en `user://flujo_fsm_tests/phase9_9b1_backup.json` y comprobar contenido JSON; cambiar los datos a `S2 != S1` y guardar de nuevo.
- La aceptación compara los dos archivos **por contenido**, no solo existencia: archivo principal = snapshot S2; `.bak` = snapshot S1. Valida `format_version=1`, identidad del alias y grafo, valores `generation=1/2`, ausencia de `.tmp`, estado activo intacto y limpieza final de archivos de prueba.
- No cambia `FlowFSMRuntime`, `FlowFSMSnapshotCodec`, esquema ni `demo/main.tscn`. La prueba no caracteriza todavía corrupción, fallo de rename, fallos de I/O ni atomicidad ante corte de energía; corresponden a 9B3 y posteriores.
- [9A2 CI 41624218942](https://github.com/mercurysama/Flujo/actions/runs/41624218942) **SUCCESS integral**, incluyendo el gate base obligatorio. **9B1-A PASS confirmado:** [Actions 41654276567](https://github.com/mercurysama/Flujo/actions/runs/41654276567) **completed SUCCESS**, 102/102 pasos sin fallos, incluido el focal 9B1-A sobre commit `c0385b67ba7ae62080a34961c2a084f55db167cf`. 25 pruebas humanas Fedora/Android permanecen aplazadas; no hubo ejecución local de Godot ni invocación formal de Skills.

**9B1-B completado:** el catálogo pasa de `not_run` a `passing` solo tras confirmación integral; código productivo, codec y esquema intactos. **Siguiente:** 9B2, matriz de rutas y rechazo seguro. Después 9B3, integridad/reemplazo ante errores.

*Todo es Flujo; todo fluye.* 🌊
