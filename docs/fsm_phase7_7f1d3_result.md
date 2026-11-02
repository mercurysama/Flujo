# Potok 7F-1D3 — Persistencia de una jornada UI completa

**Fecha:** 2026-11-02. **Rama exclusiva:** `feature/fsm-runtime-flow-flusso`. **Baseline:** `d58174698f8e9d79c66e28d407f184daf0ca6d71`; [CI 41525575708](https://github.com/mercurysama/Flujo/actions/runs/41525575708), SUCCESS.

## Prueba y alcance

- `de43009c0702647674487741de7468ad5deab43f`: `tests/editor/flow_fsm_sdk_ui_scene_roundtrip_test.gd`.
- `4ee94e7bf88238e4215665b7312628dafae4aa2e`: entrada de prueba en `.github/workflows/flujo-fsm.yml`.
- **GREEN confirmado:** [Actions 41526101676](https://github.com/mercurysama/Flujo/actions/runs/41526101676), **completed SUCCESS 76/76 pasos**, cero fallos, sobre commit `4ee94e7bf88238e4215665b7312628dafae4aa2e`; incluye la prueba integrada de persistencia y todas las regresiones del workflow Godot 4.7.2.

La prueba integra por primera vez en **una misma escena** el ciclo nativo Fluo/Flusso: selección y activación de bloque externo `manual_output:output` en Enter, edición inmediata del descriptor `message`, cierre del panel, Duplicate con ID nuevo, modal Delete/Cancel sin mutación ni historial, Confirm/Delete, Undo/Redo y reactivación del SDK original. Tras comprobar integridad se cierra el drawer y se empaqueta con `PackedScene.pack`, se guarda a archivo temporal `.tscn` y se vuelve a cargar mediante `ResourceLoader.CACHE_MODE_IGNORE`, sin reutilizar la instancia previa. Se verifican IDs de máquina y estados, script externo, texto SDK editado, exactamente un bloque original sin copia residual, hueco `null`, estado hermano, Update y Exit, bloque Ready, esquema 3 y `FlowGraphValidator`. El test elimina el archivo temporal al finalizar.

## Límites y continuidad

No hay cambios en runtime, esquema, contratos o UI productiva. El recorrido no demuestra aceptación visual física de paneles, scroll o accesibilidad ni cubre todos los paquetes de SDK. **Siguiente: 7F-1D4**, auditoría de integración y preparación de la matriz 7F-2. Las **15 pruebas Fedora y 10 Android** permanecen **PENDING**; no se modifica `main` ni se presume un worktree local Fedora.

*Todo es Flujo; todo fluye.* 🌊
