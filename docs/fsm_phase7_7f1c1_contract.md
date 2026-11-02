# Potok 7F-1C1 — Plan recuperable de Flusso para bloques de fase

**Fecha:** 2026-11-02. **Rama exclusiva:** `feature/fsm-runtime-flow-flusso`. **HEAD de recuperación verificado:** `a6f247ac979744570dc5d9560f8bab7dfd976c8e`. **Evidencia anterior:** [Actions 41411960541](https://github.com/mercurysama/Flujo/actions/runs/41411960541) SUCCESS (61/61 pasos), sin aceptación visual humana. **Estado de este archivo:** especificación, no implementación ni aprobación de tests nuevos.

## Requisito y observación del código actual

La fase 7F-1B ya presenta listas nativas por Enter, Update y Exit y guarda selección transitoria `_potok_selected_phase` / `_potok_selected_phase_block_id` en `addons/vp_flujo/editor/flow_graph_inspector_property.gd`. `_potok_on_phase_block_selected` selecciona por ID, pero no activa un editor de propiedades. `FlowReadyProcessEditor` contiene el editor genérico Flusso y registros de propiedades editables para Ready; `FlowGraphEditorCommands` contiene comandos de edición/UndoRedo de bloques Ready y `add_fsm_phase_block_by_authoring_id` para las tres fases. La ruta Ready `_capture_flusso_snapshot` busca únicamente `container.blocks`; **no debe emplearse directamente para Enter/Exit**. La integración debe reutilizar descriptores genéricos y presentación sin duplicar un Flusso ni tocar `main`, runtime, esquema, demo o recursos externos.

## División técnica y criterios de aceptación

### 7F-1C1A — contrato de selección y pertenencia (este documento)
- Congelar clave de contexto `controller weakref + machine_id + state_id + phase + block_id + rebuild generation`; fases canónicas estrictas `enter/update/exit`.
- Resolver el `FlowBlock` real en la colección correcta: `enter_blocks`, `blocks` (Update) o `exit_blocks`. El ID debe pertenecer a ese estado, esa máquina y ese controlador; no basta con que exista globalmente.
- Rechazar IDs vacíos, huecos `null`, selecciones/callbacks caducos y controladores liberados, sin escritura, historial ni navegación accidental.
- Fuente de autoridad: contratos de 7F-1A/1B, `AGENTS.md`, Constitución y `docs/behavior_catalog.json`.
- **Resultado esperado:** contrato versionado; ninguna afirmación de prueba de código.

### 7F-1C1B — activación y Flusso existente
- Activar mediante Enter o doble clic en un bloque válido de cualquier fase; un simple clic solo selecciona. Vincular los controles al Flusso existente, no crear un segundo editor/modal.
- Mostrar las propiedades soportadas por el sistema genérico de descriptores y catálogo, incluidas las de bloques integrados y SDK externo, sin suponer que una propiedad exportada es editable automáticamente.
- Mantener contexto y restauración de foco a la misma lista y mismo ID al cerrar; mantener las rutas Ready/Timer intactas.
- Prueba focal de apertura/selección por tres fases y contexto obsoleto; RED explícito antes del cambio mínimo.

### 7F-1C1C — edición persistente, aislamiento y validación
- Encaminar cada modificación al bloque validado dentro de su fase, con validación previa y Undo/Redo sobre el recurso correcto; edición inmediata conforme al contrato de Flusso.
- No tocar fases hermanas, otros estados, otras máquinas, otras instancias de `PVController`, IDs, huecos `null` ni propiedades externas no representadas.
- Verificar bloque integrado y paquete externo, propiedades tipadas, cambios rechazados y sucesiones Undo/Redo.
- Si el editor genérico/comando actual asume `container.blocks`, crear una extensión acotada y explícita por contexto, sin aliasing de recursos o duplicación de renderizador.

### 7F-1C1D — Escape, Revertir, cancelar y foco
- Escape cierra Flusso primero, luego Fluo; cerrar no revierte ni confirma. Revertir restaura solo propiedades presentadas capturadas al abrir la sesión de ese bloque y conserva el editor abierto.
- Cancelar cualquier edición temporal no aplica datos. Cambio de estado/máquina/controlador invalida callbacks/snapshots previos.
- La restauración de foco usa ID y generación, nunca índice ni referencia a Control ya liberado; no roba foco a otro editor.
- Pruebas focales de cierre, regreso con teclado, sesiones independientes y callbacks antiguos.

### 7F-1C1E — cierre de regresión técnica
- Probar ruta Inspector → Fluo → fase → bloque → Flusso y modificaciones; foco/scroll/teclado; UndoRedo; persistencia por escena; integración con Ready, Timer, Tok y SDK externo.
- Añadir prueba focal a `.github/workflows/flujo-fsm.yml`; conservar casos históricos RED/GREEN sin reescribirlos. Consultar catálogo e invocaciones canónicas.
- Ejecutar validación del catálogo, carga headless y regresiones proporcionales con GitHub Actions; registrar URLs y resultados reales, no asumir PASS.
- Actualizar `docs/fsm_iteration_01_learning.md`, resultado independiente y HEAD/commit de cada unidad.

## Límites de esta entrega y puertas pendientes

No modificar el runtime ni el esquema de recursos; no implementar Move/Duplicate/Delete (7F-1C2), jornada completa (7F-1D), aceptación manual (7F-2), ni merges. La matriz humana sigue 15 Fedora + 10 Android pendientes. Las instrucciones de `$flujo-baseline`, `$flujo-prove`, `$flujo-fluo-maintenance` están disponibles en `tools/agent_skills/` y pueden aplicarse como checklist remoto, pero **no pueden declararse ejecutadas como Skills autónomas**; un chequeo CI remoto tampoco constituye auditoría local de worktree Fedora. Antes del siguiente cambio funcional se requieren baseline y prueba focal RED verificables, y después GREEN + regresiones.

**Punto de reanudación tras este microbloque:** 7F-1C1B, caracterización RED y apertura de Flusso, salvo que la rama haya avanzado. Todo es Flujo; todo fluye. 🌊
