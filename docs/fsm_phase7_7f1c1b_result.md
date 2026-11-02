# Potok 7F-1C1B — Activación de bloques de fase en Fluo

**Fecha:** 2026-11-02. **Rama:** `feature/fsm-runtime-flow-flusso`. **Estado:** AUTOMATED PASS (alcance de activación/proyección), **sin** revisión visual humana.

## Evidencias y checkpoints

- Base: `d2ebf9076baf9ff1d6d210ac66aa7caa2b4f93bc` (contrato 7F-1C1A).
- Prueba focal RED `tests/editor/flow_fsm_phase_block_activation_test.gd`: `872d136c6528c85e0d5576bf5211e5b9768ba15e`.
- CI incorpora la prueba con límite de 100 segundos: `9dd2b287595375e81cb08eeca056f525b5f12e73`. [RED esperado, Actions 41472435256](https://github.com/mercurysama/Flujo/actions/runs/41472435256): FAILURE concentrado en la nueva prueba, que aún no tenía superficie de activación.
- Implementación `af2f5db732500022559c89cbb5726a073f89ee4b`: ruta `item_activated`, resolución de propiedad estricta por controlador/máquina/estado/fase/bloque, proyección inicial en `PotokPhaseBlockProperties` dentro del `FluoFlowEditor` ya existente.
- La primera ejecución con implementación [Actions 41472656493](https://github.com/mercurysama/Flujo/actions/runs/41472656493) fue FAILURE: la prueba detectó que al cambiar la selección permanecía el panel anterior. **No se considera GREEN**.
- Corrección `1ac8da9c35cb4d540ec8cd5f97c0bed1bace83fc`: eliminar inmediatamente la proyección anterior cuando cambia el bloque seleccionado.
- [GREEN verificado, Actions 41472698791](https://github.com/mercurysama/Flujo/actions/runs/41472698791): **COMPLETED SUCCESS**. Corrió la prueba nueva más el resto del workflow existente; sin fallos reportados. El editor Godot 4.7.2 cargó, pasó el validador de catálogo y las regresiones Ready/Timer, Fluo, FSM anteriores. La prueba focal verifica por fase: un simple clic no abre propiedades, activación de bloque abre panel en el mismo Fluo, y metadata identifica ID exacto de bloque, fase y estado.

## Cambios reales

- `addons/vp_flujo/editor/flow_graph_inspector_property.gd`: un único editor existente, nueva activación por `ItemList.item_activated`; guardas de propiedad contra listas obsoletas, controlador ajeno, ID vacío o `null`, y fases estrictas `enter/update/exit`; proyección inicial del nombre, habilitación y descriptores del catálogo genérico **en modo lectura**. No persiste ni muta el modelo al activar.
- `tests/editor/flow_fsm_phase_block_activation_test.gd`: nueva prueba focal independiente.
- `.github/workflows/flujo-fsm.yml`: un paso focal con timeout; conserva las regresiones históricas.

## Límites / próximo microbloque

**No se ha implementado todavía la edición** de propiedades de bloque por fase con Undo/Redo, ni la semántica completa de sesión y Revertir/Escape. La vista de 7F-1C1B es deliberadamente de lectura; no se debe confundir con un Flusso completamente editable. No se añadieron clases nuevas de editor, comandos de edición por fase, migraciones, runtime o modificaciones de `main`. El botón de cierre y retorno de foco por fase forma parte de 7F-1C1D. La revisión humana sigue **25/25 PENDING** (15 Fedora, 10 Android).

**Siguiente:** 7F-1C1C, editar propiedades del bloque dentro de la fase exacta, reutilizando descriptores y comandos genéricos; test-first, UndoRedo, validación e identidad, sin crear un segundo Flusso. Luego 7F-1C1D Escape/Revertir/foco y 7F-1C1E integración/aceptación automatizada.

Las instrucciones versionadas de `$flujo-baseline`, `$flujo-prove`, `$flujo-fluo-maintenance` se consultaron; no se ejecutaron como Skills autónomas ni se auditó la máquina Fedora local. GitHub Actions proporciona evidencia CI, no revisión táctil/visual.

*Todo es Flujo; todo fluye.* 🌊
