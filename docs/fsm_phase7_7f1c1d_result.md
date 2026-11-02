# Potok 7F-1C1D — Sesión Flusso, Revertir, Escape y foco

**Fecha:** 2026-11-02. **Rama:** `feature/fsm-runtime-flow-flusso`. **Estado:** implementación y focal automatizada; aceptación humana pendiente.

## Cambios y recuperación

- Baseline `9a12e6e26082d7baa1367593e70f268f2b526729`: [CI 41476096311](https://github.com/mercurysama/Flujo/actions/runs/41476096311) SUCCESS.
- `44d048575636937025121467fc8e35ae9426614d`: comando `restore_fsm_phase_block_snapshot` en `flow_graph_editor_commands.gd`, valida propiedad/valor, propietario exacto, estado candidato y aplica restauración como una acción UndoRedo.
- `1b84b12e275647345e511f88403896f3d13f49df`: sesión por controlador, máquina, estado, fase y bloque; botones Revertir y Close en `PotokPhaseBlockProperties`; cierre no revierte, foco vuelve al mismo ID.
- `7893a39b4136f52ddad4fbe15f7ee657984355a7` y `91e0b23b3ac51de5e62d6decd70c88bf3495f4fb`: primer Escape cierra el Flusso de bloque de fase antes que el drawer, y cerrar el drawer invalida la sesión activa.
- `34264b0cc81c5885876166fc67922b7585ff1886` y `1776abcd973aaf987a684dec781fdce17c8a19d1`: test `flow_fsm_phase_block_revert_focus_test.gd`; `0c90df5f5737b5310c302678aff835ae1dcb646c` lo integra al workflow.
- Evidencia CI focal y regresiones: [Actions 41491611189](https://github.com/mercurysama/Flujo/actions/runs/41491611189). Consultar el resultado *final* de ese run antes de declarar cobertura GREEN integral.

## Alcance y límites

Revertir captura valores originales de las propiedades realmente presentes en controles escalares soportados; no debe afectar propiedades externas desconocidas ni documentos estructurados. El bloque sigue identificado por ID estable; cambiar máquina/estado/fase/controlador invalida la sesión anterior. El primer Escape cierra la configuración del bloque y el siguiente Escape puede cerrar Fluo. El comportamiento general de Ready y Timer queda en las rutas existentes.

Esta implementación **no** cubre aún la revisión manual 15 Fedora + 10 Android, edición de documentos estructurados, ni toda la compatibilidad de paquetes externos; esos puntos quedan para 7F-1C1E y aceptación consolidada. El método de revisión versionado `$flujo-baseline`/`$flujo-prove`/`$flujo-fluo-maintenance` se consultó, no se ejecutó autónomamente en Fedora. Sin merge a `main`.

**Siguiente microbloque:** 7F-1C1E, integrar y auditar las pruebas de los bloques de fase y los casos SDK, persistencia, cambios obsoletos y recuperación de foco. Después 7F-1C2, 7F-1D y 7F-2.

*Todo es Flujo; todo fluye.* 🌊
