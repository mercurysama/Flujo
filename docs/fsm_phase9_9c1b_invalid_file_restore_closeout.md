# Potok 9C1-B — Cierre técnico de restauración desde archivos inválidos

**Fecha:** 2026-11-03. **Rama:** `feature/fsm-runtime-flow-flusso`. **Estado: PASS automatizado**, `FLUJO-BHV-POTOK-SNAPSHOT-INVALID-FILE-015` se actualiza `not_run → passing` tras CI integral.

**Evidencia:** [GitHub Actions 41678522740](https://github.com/mercurysama/Flujo/actions/runs/41678522740) finalizado **SUCCESS** sobre `f2fb13c7f9ff0d68a74f7ea33b398e6e16cf8613`; job headless **105/105 pasos completados sin fallos**, incluida la puerta `Potok-9C1A invalid snapshot file restore preflight focal`. Test `tests/runtime/flow_fsm_snapshot_invalid_file_restore_test.tscn`. 

**Criterio confirmado:** archivos ausentes, JSON malformado, raíz con tipo incorrecto, tamaño superior al máximo, versión no soportada y `graph_id` ajeno se rechazan sin cambiar alias PERSISTENT activo ni sus datos, y preservan la transición directa pendiente para el siguiente tick. El resultado no demuestra comportamiento ante apagado físico ni recuperación de `.bak` y no cierra los riesgos F5–F7.

**Gobernanza:** ningún cambio de runtime, codec, esquema, formato, escena demo ni `main`; no hay aceptación manual ni publicación final. 25 pruebas humanas (15 Fedora, 10 Android) diferidas. Skills versionadas no invocadas formalmente y Godot local no ejecutado. El checkpoint de cierre debe verificarse por su propio CI.

**Siguiente 9C2-A:** nueva instancia de controlador sobre el mismo `FlowGraph` después de teardown y restauración explícita desde archivo `user://`, con datos y alias persistente verificables, sin confundirlos con autoload.

*Todo es Flujo; todo fluye.* 🌊
