# Potok 7F-1C2A — Contrato de operaciones estructurales de bloques

**Fecha:** 2026-11-02. **Rama:** `feature/fsm-runtime-flow-flusso`. **Baseline verificado:** `43d8c3413a17e4ad24d929e75d12f4adaf56669d`, [CI 41496047937](https://github.com/mercurysama/Flujo/actions/runs/41496047937) SUCCESS.

## Identidad, pertenencia y límites

Toda operación recibe `PVController + machine_id + state_id + phase + block_id`. La fase debe ser exactamente `enter`, `update` o `exit`, que proyectan a `enter_blocks`, `blocks` o `exit_blocks`. Antes de mutar se exige schema 3 vigente, controlador válido, máquina y estado del mismo grafo, recurso con ID estable en la lista exacta y candidato estructural que no introduzca errores nuevos. Un ID de otra fase, estado, máquina o instancia se rechaza sin escritura, acción de UndoRedo ni efecto en pantalla.

Las colecciones contienen `FlowBlock` o huecos `null` deliberados. Estos huecos tienen significado posicional y no se compactan silenciosamente. La validación y el UndoRedo se aplican a una única propiedad array de un único estado; los demás recursos y fases se mantienen idénticos. Tras Undo/Redo se conservan referencias e IDs donde la operación no crea un recurso nuevo.

## Microbloques

### 7F-1C2A — Contrato y Move mínimo

`move_fsm_phase_block(controller, mid, sid, phase, block_id, direction)` acepta solo `direction = -1 | +1`. Una operación mueve por **intercambio con el bloque físico adyacente**, únicamente cuando ambos slots contienen bloques no nulos. Si el vecino es `null` o el movimiento sale de la lista, se rechaza sin saltar sobre el hueco; no se trata `null` como bloque desplazable. No cambia IDs, nombres ni recurso; un paso válido crea exactamente una acción UndoRedo con sus dos arrays originales y nuevos. Pruebas: Enter/Update/Exit, límites, huecos, dueño obsoleto, aislamiento, Undo/Redo y validador.

### 7F-1C2B — Duplicate (pendiente)

`duplicate_fsm_phase_block(...)` devolverá el nuevo ID o vacío si falla. Duplicar en la misma fase, **inmediatamente después** del original y sin mover/compactar los huecos previos. Se debe duplicar el recurso con sus propiedades editables y subrecursos intencionalmente, emitir **un ID nuevo** y nombre único de fase. No compartir subrecursos mutables accidentalmente, no duplicar IDs de hijos, y no llamar al catálogo de fábrica innecesariamente para bloques externos; preservar su script. Una acción UndoRedo con el mismo duplicado en Redo, no recreación.

### 7F-1C2C — Delete (pendiente)

`delete_fsm_phase_block(...)` elimina exactamente el bloque identificado, sin borrar otros bloques y sin tratar un slot `null` como selección. Los `null` preexistentes se preservan con su orden relativo; no se insertan `null` sustitutos por defecto. Una acción UndoRedo recupera la referencia original e ID; la UI requiere confirmación antes de invocar el comando. Cancelar el diálogo no altera recursos ni historial.

### 7F-1C2D — Integración Fluo/Flusso (pendiente)

Controles Move Up/Down, Duplicate y Delete en el Fluo de fase; un único diálogo de confirmación para Delete. Selección y recuperación de foco mediante ID estable y generación de reconstrucción, no índice; cambio de máquina/estado/controlador invalida callbacks obsoletos. Escape respeta el orden modal → Flusso → Fluo. Pruebas nativas de teclado y foco sin regresiones para Ready/Timer/Tok.

### 7F-1C2E — Cierre de regresión (pendiente)

Guardar/recargar escena, validar grafo, bloques externos, UndoRedo completo, suite Godot 4.7.2 y documentación. No modificar `main`, runtime, esquema ni demo. Las pruebas manuales 15 Fedora + 10 Android siguen **PENDING**.

**Criterio de cierre de 7F-1C2A:** contrato y prueba focal test-first del comando Move, RED deliberado por falta de método seguido de GREEN verificable con regresiones. No afirmar completados Duplicate/Delete o integración UI.

*Todo es Flujo; todo fluye.* 🌊
