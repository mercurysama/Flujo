# Potok 8D1-B2 — Fachada de operaciones FSM acotada por callback y máquina

**Fecha:** 2026-11-02. **Rama:** `feature/fsm-runtime-flow-flusso`. **Baseline previo:** `3ceb73389eb06b7e6cd4aa154906bf1ba635fa45`, que mantenía [RED reproducible 41552195224](https://github.com/mercurysama/Flujo/actions/runs/41552195224) hasta implementar el servicio. **Alcance:** cerrar estrictamente la brecha 8D1-B1, sin otro registro de estados ni cambios de esquema.

## Implementación mínima

- `addons/vp_flujo/runtime/flow_fsm_operations.gd` — `FlowFSMOperations` es una fachada de `RefCounted`, vinculada al `FlowFSMRuntime` vigente, controlador y `machine_id` del bloque. Ofrece `register_state`, `has_state`, `change_state`, `remove_state`, `get_state_data` y `set_state_data`, delegando todas las verificaciones al runtime existente. Rechaza sin mutar cuando ha expirado, el runtime no está corriendo, el controlador deja de ejecutar o su `flow_graph` cambia. No ofrece la colección mutable ni un campo público `FlowGraph` por la interfaz de fachada. Commit `650cea199a2a4418e394260688772a6180615dee`.
- `addons/vp_flujo/runtime/flow_navigation_context.gd` — parámetros opcionales compatibles para `FlowFSMRuntime` y machine ID; `get_fsm_operations()` solamente construye capacidad con runtime explícito para `StateEnter`, `StateUpdate`, `StateExit`. `invalidate_fsm_operations()` invalida una fachada retenida por el bloque. Commit `a82960b025350ee73a3d27a488be59c0ed93cf44`.
- `addons/vp_flujo/runtime/flow_ready_executor.gd` — nuevo argumento opcional al final de `_execute_blocks`, sin cambiar invocadores existentes. El bloque recibe una capacidad durante su llamada a `get_navigation_decision`; se invalida inmediatamente al retornar. La ejecución independiente de Ready/Timer/Constructor y los métodos existentes no reciben runtime FSM. Commit `ea74dd99ea92b1fbf75809132a8cd1edcad41250`.
- `addons/vp_flujo/runtime/flow_fsm_runtime.gd` — pasa `self` al ejecutor exclusivamente al despachar las fases FSM y conserva el machine ID como `entry_id`. Commit `9ceebb737fb6a600c3aaacfe18fd4da9ce2e87fc`.

## Ajuste de prueba y diagnóstico

La prueba inicialmente esperaba tres registros (Enter, Update, Exit). En la ejecución manual de un `change_state` pendiente, **el tick siguiente ejecuta Update antes de Exit**, por contrato del runtime. [CI 41558346002](https://github.com/mercurysama/Flujo/actions/runs/41558346002) confirmó que Enter y Update ya disponían de fachada, pero fallaron las aserciones de índice/cantidad del test. El commit `5dbc64e18907b7833f19b63338029c8b54fd6686` corrige solo esta expectativa: Ready sin capacidad, Enter con capacidad, Update en tick 1, Update en tick 2, Exit con capacidad y **cuatro alias independientes** en la máquina A; la máquina B conserva registro vacío. Se mantienen exigencias de IDs válidos, ejecución real y ausencia de mutación del `FlowGraph`.

**GREEN global confirmado:** [CI 41558491721](https://github.com/mercurysama/Flujo/actions/runs/41558491721) finalizó **SUCCESS 81/81 pasos**, sin fallos, para el commit `5dbc64e18907b7833f19b63338029c8b54fd6686`. Incluye el contrato 8D1-B1 convertido a GREEN y todas las regresiones anteriores.

## Seguridad y límites

Esta capacidad es una **interfaz de autoridad por llamada**, no sandbox de GDScript: los paquetes con código del proyecto aún pueden acceder al controlador o grafo por otros caminos ya públicos. No se proporciona acceso mutable al `FlowGraph` **a través de esta fachada**, pero no se afirma aislar scripts hostiles. La invalidez de la capacidad funciona tras retornar la llamada, aunque los escenarios de guardar referencias obsoletas, múltiples PVController, ciclos de parada/reinicio, Timer/Constructor y recuperación cruzada requieren focal independiente **8D1-C**. No se ha aprobado todavía manualmente una interacción de editor.

**Siguiente:** 8D1-C — validar una fachada guardada y reutilizada fuera del callback, aislamiento de dos controladores y ciclo real add→change→remove desde SDK, con prueba en ejecución; continuar luego a 8D2 y 8E. Ningún cambio en `main`, esquema o `demo/main.tscn`; 25 pruebas visuales de Fase 7 pendientes por decisión explícita.

*Todo es Flujo; todo fluye.* 🌊
