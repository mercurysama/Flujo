# Potok 7F-1C2A — Move de bloques por fase

**Fecha:** 2026-11-02. **Rama:** `feature/fsm-runtime-flow-flusso`. **Alcance:** contrato y comando estructural Move (sin UI de controles Move).

## Evidencia RED → GREEN

- Baseline `43d8c3413a17e4ad24d929e75d12f4adaf56669d` y [CI 41496047937](https://github.com/mercurysama/Flujo/actions/runs/41496047937) SUCCESS.
- Contrato [`fsm_phase7_7f1c2_contract.md`](fsm_phase7_7f1c2_contract.md), commit `39a726b15319c7d5c561725394144f8e66908053`.
- Prueba focal `tests/editor/flow_fsm_phase_block_move_commands_test.gd`, commit `0e8af907608458b183f387e0bf136fe78366cb99`. Agregada al workflow en `ba10f1be42ccd385220c177feb8c037a8be1c123`; [Actions 41497932628](https://github.com/mercurysama/Flujo/actions/runs/41497932628) registró fallo esperado de la prueba por ausencia del método Move, sin implementar el comando.
- Implementación `40495da7547955643434f9569710ed4159ad22ae`; [Actions 41498107835](https://github.com/mercurysama/Flujo/actions/runs/41498107835) incluye la focal Move y regresión Godot 4.7.2. Consultar conclusión final del run antes de declarar suite completa GREEN.

## Comportamiento implementado

`move_fsm_phase_block(controller, machine_id, state_id, phase, block_id, direction)` modifica únicamente la lista correspondiente a `enter`, `update` o `exit` cuando `direction` es `-1` o `1`. Intercambia dos recursos vecinos no nulos; prohíbe saltar sobre `null`, no compacta, no crea ni elimina bloques ni cambia IDs. Verifica IDs propios, controlador, fase y límites, valida un estado candidato sin tocar el modelo original y confirma exactamente una acción del `EditorUndoRedoManager` con el mismo recurso para Undo/Redo.

La prueba negativa cubre fase desconocida, movimiento inválido o fuera de límites, otro estado/máquina, hueco `null`, bloque ajeno a una fase y acciones rechazadas sin UndoRedo. Positivos en Enter, Update heredado y Exit comprueban listas, referencias, orden y aislamiento de estado hermano; también ejecuta Undo/Redo y validador.

## Límites y próximos pasos

**No está implementada la interfaz Move**. Tampoco Duplicate/Delete, ni la confirmación modal para eliminar: corresponden a 7F-1C2B/1C2C/1C2D según contrato. Mantener la matriz manual 15 Fedora y 10 Android **PENDING**, sin afirmar revisión de worktree local ni aceptación visual. Sin cambios a runtime, esquema, demo o `main`.

Próximo: **7F-1C2B**, duplicación del bloque con nuevo ID, preservación de propiedades y script externo, recursos hijos independientes, validación y UndoRedo.

*Todo es Flujo; todo fluye.* 🌊
