# Potok 7F-1C2B — Duplicación estructural de bloques por fase

**Fecha:** 2026-11-02. **Rama exclusiva:** `feature/fsm-runtime-flow-flusso`. **Alcance:** comando de duplicación, no controles visuales.

## Evidencia y checkpoints

- Baseline `22a0e36e9f5fc0e31710b5c5f93e479f1b345bab`; [GitHub Actions 41498768286](https://github.com/mercurysama/Flujo/actions/runs/41498768286), SUCCESS.
- Prueba de contrato `tests/editor/flow_fsm_phase_block_duplicate_commands_test.gd`, commit `9521b0694d2b263ca3030614c665481225b49996`.
- Workflow añadió la focal en `6b19511ffbe25d0de5502176b1f6e6e82ec2713b`; [Actions 41508412591](https://github.com/mercurysama/Flujo/actions/runs/41508412591) produjo el fallo RED esperado del método inexistente.
- Implementación del comando `duplicate_fsm_phase_block` en `addons/vp_flujo/editor/flow_graph_editor_commands.gd`, commit `fea73dfbf784d0e8f52486d147a71598f5f066a2`.
- Ejecución GREEN: [Actions 41508625773](https://github.com/mercurysama/Flujo/actions/runs/41508625773). **Antes de declarar finalizada la suite global, comprobar conclusión y cantidad real de pasos.**

## Comportamiento

El comando recibe controlador, máquina, estado, fase canónica y bloque. Solo admite `enter`, `update`, `exit` en el estado exacto; no edita un bloque con el mismo nombre en otra lista o controlador. Copia el recurso con `FlowBlock.duplicate_with_new_id()`, reutilizando la implementación central de copia profunda y remapeo de referencias internas. Rechaza copias inválidas o scripts distintos. El nombre se construye con el nombre original y sufijo ` Copy`, incrementando un número si ya existe en esa fase. Inserta el recurso inmediatamente después del original, no desplaza ni compacta huecos `null`. Valida un borrador estructural del grafo y confirma exactamente una acción UndoRedo sobre la colección de fase, preservando la misma referencia al hacer Redo.

El test cubre entradas inválidas sin cambios ni historial, conservación de `null`, propiedades `text` y `user_note`, nuevo ID y nombre, Enter/Update/Exit, SDK externo con script y `message` originales, Undo/Redo, estado hermano y Ready sin alteración y validador global.

## Límites y continuidad

No hay botón Duplicate ni control de foco añadido; corresponden a **7F-1C2D**. **7F-1C2C** será el borrado del bloque exacto, con UndoRedo y posterior confirmación visual en 7F-1C2D. Las pruebas de escenarios especiales de subrecursos mutables y documentos estructurados todavía requieren cobertura adicional; la duplicación reutiliza el método del modelo y no debe darse por exhaustiva con un solo fixture SDK. Las 15 pruebas humanas Fedora y las 10 Android siguen **PENDING**. `main`, runtime, esquema y demo permanecen sin modificaciones.

*Todo es Flujo; todo fluye.* 🌊
