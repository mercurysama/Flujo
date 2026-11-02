# Potok 7F-1D2C — Delete del SDK desde Fluo y recuperación

**Fecha:** 2026-11-02. **Rama:** `feature/fsm-runtime-flow-flusso`. **Baseline:** `a578e1bb854f43f1d1ee1b1e1af25ab406d5533d`. Contrato padre: [7F-1D](fsm_phase7_7f1d_contract.md).

## Evidencia

- `da1b51afd303f2781add27cde6a0d7b4de07fa1f`: focal `tests/editor/flow_fsm_sdk_delete_journey_test.gd`.
- `a551de763dbf4ec8be6bb7b5492efab517b7ce58`: paso añadido en `.github/workflows/flujo-fsm.yml`.
- **GREEN confirmado:** [Actions 41525063836](https://github.com/mercurysama/Flujo/actions/runs/41525063836), **completed SUCCESS: 75/75 pasos**, sin fallos, sobre `a551de763dbf4ec8be6bb7b5492efab517b7ce58`; incluye focal 7F-1D2C y regresiones Godot 4.7.2.

## Recorrido y contrato comprobado

Crea un `FlowBlock` SDK real `manual_output:output` mediante catálogo de descriptores y lo incorpora a Enter después de un hueco `null`, junto con estado hermano y Ready independientes. Usa Fluo para seleccionar y abrir el Flusso existente, edita el campo `message`, cierra sus detalles y duplica el bloque externo con el botón de fase: el duplicado conserva script y texto, pero obtiene ID y recurso propios. Delete solo abre el diálogo; Cancel no altera ni la colección ni la versión del historial. Confirm elimina exactamente la copia en una única operación de UndoRedo; Undo restituye la misma instancia e ID y Redo vuelve a retirarla. Se selecciona/activa nuevamente el bloque SDK original, cuyos ID, script y mensaje editado se conservan. El estado hermano, Ready y el grafo se mantienen válidos. Esta prueba no representa un guardado/reapertura de escena, reservado al recorrido 7F-1D3.

## Continuidad

Concluir 7F-1D2C tras confirmar GitHub Actions. **Siguiente 7F-1D3:** integrar edición nativa de SDK + acciones de UI con guardado y reapertura de escena mediante `PackedScene`, IDs, propiedades, schema y aislamiento. Después **7F-1D4** auditoría de integración y matriz humana para 7F-2. Se mantienen **15 casos Fedora + 10 Android PENDING**; no se modifica `main`, runtime, esquema ni demo.

*Todo es Flujo; todo fluye.* 🌊
