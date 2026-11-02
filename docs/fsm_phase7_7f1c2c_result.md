# Potok 7F-1C2C — Delete de bloques por fase

**Fecha:** 2026-11-02. **Rama:** `feature/fsm-runtime-flow-flusso`. **Alcance:** comando estructural de borrado de bloque, sin botón ni diálogo de confirmación visual.

## Contrato, pruebas y commits

- Baseline `f051c8f8ec20e651451ae0ec4f8941f987dca408`, [Actions 41509176626](https://github.com/mercurysama/Flujo/actions/runs/41509176626) SUCCESS.
- Contrato [`fsm_phase7_7f1c2_contract.md`](fsm_phase7_7f1c2_contract.md), fase Delete 7F-1C2C.
- Prueba `tests/editor/flow_fsm_phase_block_delete_commands_test.gd`, commit `32e6e6ced2f3b0043ba39a93955cf804cfc86bb5`; workflow `abc98c60321d011bba665a982cb7ea9d77eeeab4`; [CI RED 41512635281](https://github.com/mercurysama/Flujo/actions/runs/41512635281): falló en el test nuevo porque no existía el comando.
- Implementación `b5b5643607fd621280414f1af5455c5db934e0cd` en `addons/vp_flujo/editor/flow_graph_editor_commands.gd`.
- **GREEN confirmado:** [Actions 41512783269](https://github.com/mercurysama/Flujo/actions/runs/41512783269), **completed SUCCESS: 69/69 pasos**, cero fallos, código en `b5b5643607fd621280414f1af5455c5db934e0cd`. Incluye test focal Delete y regresiones Godot 4.7.2.

## Comportamiento

`delete_fsm_phase_block(controller, machine_id, state_id, phase, block_id)` acepta únicamente fase canónica `enter`, `update` o `exit`, un bloque real y un controlador/estado/máquina que lo posean. El comando identifica por ID y elimina exactamente esa posición de la colección, sin rellenarla con un `null`. Los huecos `null` preexistentes permanecen en su orden relativo y los demás bloques preservan el objeto original. Se construye y valida estado candidato separado, y solo después se confirma **una** acción de `EditorUndoRedoManager`. Undo vuelve a colocar el mismo recurso e ID en el mismo índice; Redo lo retira nuevamente. Un segundo Delete con el ID eliminado no genera historial ni mutación.

La prueba focal verifica errores de pertenencia, fase desconocida, IDs vacíos o caducos, null preexistentes, Enter/Update/Exit, Undo/Redo, script y propiedades de bloque externo de SDK en Exit, Ready, estado hermano y `FlowGraphValidator`.

## Límites y siguientes bloques

Este es un comando de bajo nivel: **no se ha expuesto en la interfaz**. La confirmación/cancelación de Delete y recuperación de selección/foco al cerrar el diálogo corresponden a **7F-1C2D** junto con botones Move y Duplicate. La etapa **7F-1C2E** comprobará integración y persistencia de escena. Pruebas manuales 15 Fedora + 10 Android siguen **PENDING**. Sin cambios a `main`, runtime, esquema persistente ni demo.

*Todo es Flujo; todo fluye.* 🌊
