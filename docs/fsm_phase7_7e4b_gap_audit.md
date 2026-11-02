# Potok 7E-4B — Auditoría de brechas de los nueve requisitos de fase 7

**Fecha de revisión:** 2026-11-02 · **Rama:** `feature/fsm-runtime-flow-flusso` · **Código auditado:** `cbd68a56c762d1f11a51e62f99b436fc53e91ec9` (7E-4A) · **Contrato 7E-4B:** `32c99169de3d5563f3177c5d64dcfb95c0492b92` · [CI del contrato 41407321246](https://github.com/mercurysama/Flujo/actions/runs/41407321246) **SUCCESS 59/59**.

## Convención de estados (dos ejes independientes)

- **Código/autómatas:** `EVIDENCIA AUTOMÁTICA`, `PARCIAL` o `FALTANTE CONFIRMADO EN FUENTE`. Una línea de código que existe no demuestra por sí sola una interacción completa; una prueba de ejecución o de persistencia no demuestra una acción de autoría.
- **Experiencia humana:** `PENDING` para **todas** las 15 pruebas Fedora y 10 Android, sin excepción. No se ha recibido evidencia actual de revisión física, versión/commit instalado o captura. La aceptación visual antigua de Fluo Preview 1 no es evidencia Potok.
- Ninguna fila de esta auditoría equivale a cerrar la fase 7. **Requisito de cierre integral:** primera máquina/un estado con Enter/Update/Exit editables desde UI, segundo estado, transición y ejecución por el flujo normal Inspector→Fluo→Flow/Flusso.

## Auditoría requisito a requisito (fuente: docs/fsm_implementation_plan.md, Fase 7)

| Nº | Requisito original | Estado del código y pruebas | Evidencia concreta / brecha | Aceptación humana |
|---|---|---|---|---|
| **1** | Inspector State Machines, Enter/doble clic, único Fluo, sin Blocks redundante | **EVIDENCIA AUTOMÁTICA** | `flow_graph_inspector_property.gd` ofrece `Add State Machine` y activación de lista; `pv_controller_inspector_plugin.gd` enlaza activación; tests `flow_fsm_fluo_navigation_test.gd` y `fluo_drawer_integration_test.gd` | **PENDING** F01, A02 |
| **2** | Flow: árbol de estados, inicial, Enter/Update/Exit, secuencias y **Add de bloques**; Empty | **PARCIAL + FALTANTE CONFIRMADO EN FUENTE** | `_render_potok_machine` muestra estados, inicial y `Empty`; `_potok_render_structure_actions` agrega estados. **`_render_potok_state_phases` (líneas aproximadas 2337–2361) crea solo etiquetas** para cada fase y los bloques existentes, sin botones Add, entradas editables ni callbacks. Faltan los comandos de autoría específicos por fase | **PENDING** F02/F03; F03 **gate bloqueado por brecha de código**, A10 |
| **3** | Flusso: editar máquina, estado, transición, disparadores y prioridad, compatibilidad con editor genérico | **PARCIAL** | Formularios reales `PotokMachineProperties`, `PotokStateProperties`, `PotokTransitionProperties`, Condition Tok, Revertir; `flow_fsm_flusso_scalar_test.gd`, `flow_fsm_transition_metadata_test.gd`, `flow_fsm_potok_revert_session_test.gd`. **Los bloques de fase mostrados son Labels**: no hay Flusso equivalente para seleccionar/configurar un bloque Enter/Update/Exit a partir de esa vista | **PENDING** F05 y parte de F03, A07 |
| **4** | Condition Tok #, Bool válido, Confirm/Cancel/Escape sin escrituras ocultas | **EVIDENCIA AUTOMÁTICA** | Editor de condición desde Flusso; tests `flow_fsm_condition_tok_scene_roundtrip_test.gd` y `flow_fsm_condition_tok_flusso_test.gd` según CI, más `flow_fsm_potok_flusso_escape_test.gd`. La revisión física de popup sigue faltante | **PENDING** F06/F07, A06 |
| **5** | Undo/Redo: crear, renombrar, reordenar, duplicar, borrar estados/transiciones; modificar fases/condiciones/inicial; validación previa | **PARCIAL** | `flow_graph_editor_commands.gd` expone `add_fsm_state`, `add_fsm_transition`, comandos estructurales y escalares validados, snapshot Revertir; tests 7C/7E. **No contiene API de Add/move/delete para bloques Enter/Update/Exit** ni comando de traslado de bloque entre fases; se necesita contrato tipado e historial atómico | **PENDING** F03/F09/F10/F14 |
| **6** | Eliminación: dependencias, confirmación y cancelación verdadera, sin reparación implícita | **EVIDENCIA AUTOMÁTICA** para estado/transición | `_potok_request_delete` muestra dependencias, `ConfirmationDialog`, Cancel/Escape; tests estructurales 7C-2B y `flow_fsm_drawer_context_recovery_test.gd`. **Borrado de bloques de fase** aún no tiene UI/comandos (depende de 2/5) | **PENDING** F10/A06 |
| **7** | Foco, Enter/doble clic, Page/Ctrl/Alt, Revertir, no robar atajos | **EVIDENCIA AUTOMÁTICA** para controles actuales | Tests `flow_fsm_keyboard_navigation_test.gd`, `flow_fsm_potok_flusso_escape_test.gd`, `flow_fsm_undo_focus_recovery_test.gd`. Al introducir controles de bloques de fase se necesitarán tests focales nuevos de teclado/foco | **PENDING** F01/F07/F08/F09, A02/A07 |
| **8** | Android táctil: scroll, tamaño, orientación, doble toque y Escape | **PENDIENTE MANUAL**; geometría automatizada parcial | 7E-3A probó `FluoEditorScroll`, vertical/horizontal AUTO y resize 1200×800/480×640, pero **no** gesto real de Android, teclado en pantalla, orientación de dispositivo, doble toque ni hitboxes físicos. `docs/fluo_preview_01.md` solo acredita carga/render del preview anterior | **PENDING** A01–A10 y F11 |
| **9** | Guardar/reabrir: IDs, orden, transiciones, chips y Undo/Redo repetido | **EVIDENCIA AUTOMÁTICA sobre modelos/escenas ya preparados; cierre UI PARCIAL** | Tests `flow_fsm_double_roundtrip_instance_isolation_test.gd`, `flow_fsm_condition_tok_scene_roundtrip_test.gd`, `flow_fsm_undo_focus_recovery_test.gd` y 7E-1B de escenas; **no prueban que el usuario pueda crear todos los bloques de fase desde Fluo** antes de guardar. Repetir después de la brecha 7F | **PENDING** F14/F15/A09/A10 |

**Precisión:** `FALTANTE CONFIRMADO EN FUENTE` describe una característica ausente en esta revisión de `addons/vp_flujo/editor/`, no un FAIL observado por una persona en Fedora/Android. **La hoja de revisión humana mantiene F03/A10 como PENDING**, con advertencia de bloqueo técnico previsto. No inventar capturas, defectos de pantalla ni marcas PASS.

## Brecha prioritaria: autoría de bloques por fase

Se verificó el modelo real: `addons/vp_flujo/runtime/model/flow_state_definition.gd` extiende `FlowBlockContainer`; la lista heredada `blocks` representa **Update**, mientras `enter_blocks` y `exit_blocks` son listas propias de `FlowBlock`. `FlowFSMEditorProjection._present_state` expone esos nombres y listas, pero nunca crea recursos. `FlowGraphInspectorProperty._render_potok_state_phases` solo dibuja `Label` (tanto para fases como para nombres de bloques existentes). Las acciones `PotokStateAdd` y `PotokTransitionAdd` son **estructurales de estado/transición**, no Add de bloques.

El ecosistema Ready sí tiene `FlowReadyProcessEditor` con catálogo/botones Add y `FlowGraphEditorCommands.add_ready_block_by_authoring_id`, que usa `find_block_container` y escribe en `container.blocks`. **Reutilizar ese comando directamente para Enter/Exit sería semánticamente erróneo** (Update usa `blocks`, Enter/Exit no). Se debe **reutilizar el catálogo de autoría y la política de validación**, pero crear un contrato por `machine_id + state_id + phase` y por `block_id`, con Undo/Redo y preservación de orden/IDs.

## Plan de cierre incremental propuesto (NO IMPLEMENTADO)

- **7F-1A — contrato/comandos para las tres fases:** especificar `ENTER/UPDATE/EXIT` y mapear los tres arrays sin inferencias por índice; escribir tests de candidato/destino/integridad y después comandos atómicos de Add por `authoring_id` validado. Crear un test RED primero, preservar estado/IDs, recursos `null` y UndoRedo, sin runtime/schema nuevos.
- **7F-1B — controles Flow por fase:** cada Enter/Update/Exit ofrece una secuencia navegable y un **Add** real con opciones del catálogo integrado/externo, selección por ID, `Empty` con Add utilizable; comprobar exactamente qué array cambia y que no se duplica Inspector. Test headless de UI y CI.
- **7F-1C1 — edición Flusso de bloque seleccionado:** al seleccionar/doble clic/Enter en bloque de fase, abrir configuración usando descriptores existentes sin escribir a otro bloque; cierre/Escape/Revertir/foco siguiendo el contrato de Ready pero con snapshot y contexto de fase propios.
- **7F-1C2 — operaciones estructurales por fase:** mover/duplicar/borrar y, si se aprueba, trasladar bloque entre fases. Guardar UndoRedo como acción atómica que valida dependencias, mantiene el orden y no modifica otras fases; diálogos Cancel sin escritura y rechazo de IDs obsoletos.
- **7F-1D — persistencia y ejecución real desde UI:** prueba automatizada de Inspector→Fluo→un estado→tres Add de bloques→segundo estado→transición→guardado/reapertura → ejecución del resultado; dos UndoRedo/reabrir, mismos IDs/fases/Tok, independencia por instancia. Pruebas de regresión Ready, Fluo y runtime existentes sin recortar.
- **7F-2 — revisión y cierre humano:** ejecutar `F01–F15` y `A01–A10` en dispositivos con la guía 7E-4A. Anotar capturas, SHA, versiones, defectos y decisión del mantenedor. **No cerrar fase 7 antes de tener PASS observable** en los gates F03, F04, F14, F15 y A10 y la revisión del resto.

Cada ítem 7F tiene contrato previo, pruebas pequeñas, cambios de código restringidos, CI, bitácora y checkpoint; dividir más en caso de bloqueo. Priorizar **7F-1A** como siguiente microbloque implementable. No iniciar fase 8/9 ni fusionar con `main` para ocultar estas deudas; empaquetado/pre-release es fase 11 independiente.

## Hallazgos colaterales no bloqueantes para este lote

El catálogo conserva `FLUJO-BHV-FLUO-ANDROID-001: manual_approved` para un preview anterior de Fluo. **No reutilizarlo** como evidencia del subsistema Potok 7E actual. `FLUJO-BHV-FOCUS-002` figura `not_covered`: considerar cobertura independiente cuando el nuevo Flusso por fase introduzca otro recorrido de foco; no cambiar catálogo sin contrato. El documento `docs/current_iteration.md` conserva la referencia histórica a la rama del preview anterior: no reinterpretarla como HEAD del trabajo Potok ni reescribirla en este lote de auditoría.

## Cierre de auditoría

**Estado de código:** parcial con brecha de autoría por fase confirmada. **Automatización:** 59/59 pasos verdes en el checkpoint previo. **Aceptación humana:** 25/25 escenarios PENDING. **Fase 7:** abierta. **Próxima acción autorizable:** 7F-1A, no una aprobación visual inventada.

Todo es Flujo; todo fluye. 🌊
