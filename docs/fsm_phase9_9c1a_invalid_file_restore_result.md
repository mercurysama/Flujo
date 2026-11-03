# Potok 9C1-A — Restore de disco inválido: preflight sin publicación

**Fecha:** 2026-11-03. **Rama:** `feature/fsm-runtime-flow-flusso`. **Contrato:** `FLU-FSM-004`; continuidad [9B3-C3](fsm_phase9_9b3c3_authorization_boundary.md). **Estado:** test registrado, **not_run** hasta éxito del nuevo CI.

La escena `tests/runtime/flow_fsm_snapshot_invalid_file_restore_test.tscn` ejecuta el runtime de un PVController real, alias PERSISTENT activo y petición directa pendiente. En ruta temporal exclusiva `user://flujo_fsm_tests/phase9_9c1_invalid.json` comprueba archivos con: JSON malformado, raíz array, contenido mayor de `MAX_JSON_LENGTH`, formato v999 e identidad de grafo distinta; también un path `user://` válido con archivo ausente. Cada rechazo debe devolver false y conservar estado activo, registro, datos y snapshot; tras todos los rechazos el tick debe aceptar la solicitud previa. No se ensayan callbacks ni alias múltiples en este focal.

**Gobernanza:** behavior `FLUJO-BHV-POTOK-SNAPSHOT-INVALID-FILE-015` registrado inicialmente `not_run` y gate obligatorio `Potok-9C1A invalid snapshot file restore preflight focal` Godot 4.7.2; sin cambio de codec, runtime, semántica, esquema, fichero demo o `main`. Ninguna recuperación automática desde `.bak` queda habilitada. Los riesgos F5–F7 permanecen abiertos. 25 pruebas manuales pospuestas; ejecución local Godot no realizada ni Skills invocadas formalmente.

**Siguiente 9C1-B:** verificar logs y CI integral; solo entonces cambiar el catálogo a passing. **Siguiente independiente 9C2-A:** recreación explícita de instancia y restore desde disco tras teardown.

*Todo es Flujo; todo fluye.* 🌊
