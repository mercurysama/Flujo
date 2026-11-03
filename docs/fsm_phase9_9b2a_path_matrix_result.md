# Potok 9B2-A — Matriz segura de rutas de snapshot

**Fecha:** 2026-11-03 (America/Mexico_City). **Rama:** `feature/fsm-runtime-flow-flusso`. **Contrato:** [FSM-004](fsm_snapshot_contract_v1.md) y [9A2](fsm_phase9_9a2_contract_and_gate.md). **Estado: passing**, tras [Actions 41658845225](https://github.com/mercurysama/Flujo/actions/runs/41658845225) completed SUCCESS 103/103.

Se agregó `tests/runtime/flow_fsm_snapshot_path_matrix_test.gd` y su escena `.tscn`, un nuevo comportamiento `FLUJO-BHV-POTOK-SNAPSHOT-PATH-POLICY-013` y el gate obligatorio `Potok-9B2A user snapshot write and restore path matrix focal` (Godot 4.7.2, timeout 70 s). Se conserva intacta toda la implementación productiva.

## Escenario y criterios

1. Preparar `PVController` real con un alias activo `PERSISTENT`, guardar su snapshot v1 en `user://flujo_fsm_tests/phase9_9b2_paths.json` y también en `user://flujo_fsm_tests/phase9_9b2_nested/valid.json`; ambos archivos deben contener el mismo objeto JSON portable.
2. Encolar transición directa a estado authored, **sin tick**. Intentar `save_to_file` y `restore_from_file` sobre rutas relativas, `res://`, absolutas, con traversal `..`, barra inversa, extensión inesperada o ausente y cadena vacía; todas deben devolver `false`.
3. En cada rechazo, mantener estado activo y snapshot íntegros. Comprobar que ninguno de los dos archivos válidos desapareció y que no aparecen `.bak` o `.tmp` en la ruta normal.
4. Ejecutar el tick: la solicitud directa previamente encolada debe confirmarse, demostrando que los restores rechazados **no borraron la cola**. Finalmente cargar el snapshot desde la ruta anidada válida y verificar estado activo, alias persistente, datos y exportación idénticos al documento previo.

Los caminos prohibidos se pasan a las APIs para comprobar su rechazo, **no** se crean archivos de prueba fuera de `user://`. La limpieza solo afecta los dos nombres explícitos bajo `user://flujo_fsm_tests/`. Este experimento no simula fallos de permisos, rutas simbólicas, IO interrumpida o un corte eléctrico; esas brechas corresponden a 9B3. No se modifica el codec, runtime, schema, Ready/Timer, `demo/main.tscn` ni `main`.

**Baseline:** [Actions 41655383920](https://github.com/mercurysama/Flujo/actions/runs/41655383920) **SUCCESS** del checkpoint 9B1-B; [41654276567](https://github.com/mercurysama/Flujo/actions/runs/41654276567) **SUCCESS**, 102 pasos, para el focal S1/S2. **9B2-A PASS tras verificación integral:** [Actions 41658845225](https://github.com/mercurysama/Flujo/actions/runs/41658845225) SUCCESS 103/103; fallo histórico [41658231067](https://github.com/mercurysama/Flujo/actions/runs/41658231067) documentado abajo. Las 25 pruebas manuales Fedora/Android siguen diferidas.

**9B2-B concluido:** catálogo `not_run → passing` tras CI integral. Próximo 9B3-A, caracterización segura de errores de respaldo y reemplazo, sin afirmar atomicidad bajo cortes de energía.

*Todo es Flujo; todo fluye.* 🌊

## 9B2-B — primer CI RED; corrección focal sin modificar producción

- [Actions 41658231067](https://github.com/mercurysama/Flujo/actions/runs/41658231067) **completed FAILURE**: solo falla el paso `Potok-9B2A user snapshot write and restore path matrix focal`. El log muestra una única aserción fallida: `Successful restore reproduces snapshot`; las aserciones precedentes sobre rutas, cola, alias y datos pasaron.
- **Diagnóstico de fixture:** `expected` procede de un Dictionary en memoria con tipos numéricos Godot; tras JSON, enteros pueden decodificarse como floats. La igualdad directa de Dictionary exige la representación original. El resultado contractual de un snapshot **portable** se compara ahora tras `JSON.parse_string(JSON.stringify(runtime.export_snapshot()))` frente a `json_expected` ya normalizado. Se conservan las comprobaciones explícitas de alias, datos, estado, rechazo de rutas y cola; no se relajan.
- **Estado:** `baseline_status=not_run` hasta nuevo CI integral SUCCESS. Runtime, codec, escenas, workflow y formato permanecen intactos. Este fallo histórico debe conservarse en la auditoría de 9B2-B.
