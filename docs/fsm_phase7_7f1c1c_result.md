# Potok 7F-1C1C — Edición de propiedades de bloques por fase

**Fecha:** 2026-11-02. **Rama:** `feature/fsm-runtime-flow-flusso`. **Resultado:** AUTOMATED PASS; revisión humana todavía PENDING.

## Checkpoints y evidencia

- Base validada: `5f78448cd2b7731d3eb1019fb3a1a24c853318ca`, [CI 41473288027](https://github.com/mercurysama/Flujo/actions/runs/41473288027) SUCCESS.
- Prueba RED de comandos: `aa12862160b8b0edf0c6d86e065285abc7f57928`; workflow `7e9cc18371872c0609da02fc2ef1f93332ee2231`, [CI 41475084787](https://github.com/mercurysama/Flujo/actions/runs/41475084787) FAILURE esperado, por ausencia de métodos de edición de fase.
- Implementación de comandos: `b561182ddc85bc964f6deaecd974bc2abe96fbfa`. Controles de Flusso: `c9f6cbd2469509afdf23dfbd84597e108dfa21cf`.
- Prueba de edición UI: `d1e402029e5298485dd608a6266746a7c85ed319` y corrección de aserción `e925ac212af2c3bdc8d7fa349aa23c782aa163b8`. Registro de la prueba en CI: `ea968ae4099e50f7949c2df452e6be8f5f19feb4`.
- [**GREEN 41475514388**](https://github.com/mercurysama/Flujo/actions/runs/41475514388): completed SUCCESS, **64 de 64 pasos**, cero fallos. Incluye los focos nuevos `flow_fsm_phase_block_property_commands_test.gd` y `flow_fsm_phase_block_property_ui_test.gd`, editor headless, validador, Ready, Timer, Fluo y FSM regresiones.

## Funcionalidad implementada

- En `FlowGraphEditorCommands`, dos rutas públicas nuevas:
  - `set_fsm_phase_block_property_live(controller, machine_id, state_id, phase, block_id, property_name, value)`: permite únicamente `display_name` (no vacío), `enabled` (booleano) y `text` para `FlowPrintBlock`, con tipos estrictos.
  - `set_fsm_phase_block_descriptor_live(controller, machine_id, state_id, phase, block_id, descriptor, value)`: exige descriptor genérico editable, reflejado en la propiedad real y reencontrado en el catálogo actual; los nombres arbitrarios o IDs internos no son editables.
- Ambas resuelven el bloque dentro de `machine.states[state].enter_blocks/blocks/exit_blocks`, verifican fase e ID, construyen candidato desacoplado para validar antes de mutar, y escriben el valor persistente en el recurso original mediante un único UndoRedo por edición. Se conservan el ID y el mismo recurso, otras fases, huecos `null`, estados hermanos y gráficos de otros controladores.
- En el único `FluoFlowEditor`, el panel `PotokPhaseBlockProperties` ofrece `PotokPhaseBlockName`, `PotokPhaseBlockEnabled`, `PotokPhaseBlockPrintText` y entradas genéricas cuando el catálogo las presenta como editables (booleano, texto/StringName, multilinea, número, rango y enum). Los callbacks exigen controlador actual, máquina, estado, fase y bloque seleccionados y Flusso abierto.
- UI y comandos no acceden a Ready mediante `find_block_container`, ni agregan un segundo catálogo/ventana; no alteran modelo persistente, esquema, runtime, proyecto demo ni `main`.

## Límites y siguiente microbloque

- El soporte genérico implementado cubre controles escalares; **no cubre edición de `FlowStructuredDocument` ni todo el comportamiento específico de bloques de SDK**. La ruta de descriptores se autoriza y valida, pero falta una prueba focal de integración con un paquete externo y sus metadatos presentados. Antes de cerrar 7F-1C1 integral, documentar o implementar los casos compatibles pendientes y regresión con SDK externo.
- **7F-1C1D** debe gestionar cerrar Flusso/Escape y devolver el foco a la lista seleccionada; `Revertir` debe restaurar solo los campos propios de la sesión, con UndoRedo sin tocar propiedades externas. También debe invalidar sesiones obsoletas.
- **7F-1C1E** integración final de las rutas, persistencia y regresiones. Después: 7F-1C2 estructura, 7F-1D jornada completa, 7F-2 revisión humana.
- Matriz manual Potok: **15 Fedora + 10 Android, 25/25 PENDING**. No se ejecutaron Skills de GitHub como programas autónomos ni auditoría del worktree Fedora; se consultaron sus contratos y se utilizó CI remoto. **No declarar READY/PASA formal ni aceptación humana**.

*Todo es Flujo; todo fluye.* 🌊
