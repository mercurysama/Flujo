# Potok 7F-1C2D — Controles estructurales nativos de bloques en Fluo

**Fecha:** 2026-11-02. **Rama:** `feature/fsm-runtime-flow-flusso`. **Baseline:** `c8c1fff55b2656ba11b0d5bed2cfec5247ec569f`; [Actions 41513400370](https://github.com/mercurysama/Flujo/actions/runs/41513400370), SUCCESS.

## Commits y evidencia

- `bcb34078e178b3cd213a59d2b84d621622bbc280`: test-first nativo `tests/editor/flow_fsm_phase_block_actions_ui_test.gd`, validación de botones Move, Duplicate, Delete, modal Cancel/Confirm, preservación de null, selección por ID y UndoRedo.
- `ad68cfb1dca9025f037427b666c3325e11036d66`: inclusión de test focal en `.github/workflows/flujo-fsm.yml`; [Actions 41515164995](https://github.com/mercurysama/Flujo/actions/runs/41515164995), RED por botones nativos faltantes.
- `6de79d83ca652acf266b1d5f146a6e2339a70016`: botones por lista de fase, callbacks de MoveUp, MoveDown y Duplicate, selección estable; Delete abre `PotokStructureDeleteDialog` existente, solo Confirm ejecuta comando. Al borrar se selecciona el bloque restante vecino por ID. Todas las operaciones usan el controlador, máquina, estado y fase explícitos.
- `a0e07f756b11111f7a0c87e8420efbe8c16891a2`: habilitar las acciones tras `ItemList.item_selected` sin esperar reconstrucción de pantalla.
- `a382ee55293631ac9f80914601f4dee744c9749c`: Escape al cerrar diálogo devuelve foco a la lista exacta de fase, con guardas de grafo/callback.
- `ae0c3e14422d5873eed9845c1d4f2adf1e2a2bd6`: extiende prueba con Escape sin borrado, sin cerrar drawer ni registrar UndoRedo.
- `25c53e758cf7542fc45b7505adbbf62fdfe7aa7b`: callbacks de botones antiguos bloqueados cuando la UI ha sido reconstruida mediante WeakRef de control.
- **CI consolidado:** [Actions 41515628731](https://github.com/mercurysama/Flujo/actions/runs/41515628731). Confirmar status y número total de pasos antes de declararlo GREEN.

## Comportamiento

Las tres listas Enter/Update/Exit muestran un grupo de acciones de bloque. Al elegir un bloque válido, la UI habilita Move Up, Move Down, Duplicate y Delete. El botón Move aplica movimiento físico adyacente (sin saltar null), Duplicate crea copia con ID nuevo y la selecciona, Delete abre confirmación; Cancel/Escape no mutan. Confirm Delete llama al mismo comando previamente validado; UndoRedo restaura bloque original. El foco regresa al bloque por ID y generación luego de mover/duplicar y a la lista de fase tras Escape. Se preservan los comportamientos Ready/Timer/Tok y el diálogo estructural para eliminar estado/transición.

**Límites:** la evidencia es CI headless, no aceptación visual en Fedora/Android. El contrato de Delete requiere confirmar en UI, pero la API de bajo nivel está intencionalmente disponible sin modal. Pendiente 7F-1C2E: persistencia de operaciones y recorrido end-to-end; no se ha modificado runtime ni esquema. Matriz humana 15 Fedora + 10 Android PENDING; `main` permanece intacta.

*Todo es Flujo; todo fluye.* 🌊
