# Potok 9C3-B — Cierre de callbacks de restore desde archivo

**Fecha:** 2026-11-03. **Rama:** `feature/fsm-runtime-flow-flusso`. **PASS integral:** [Actions 41681389535](https://github.com/mercurysama/Flujo/actions/runs/41681389535) completó **107/107 pasos sin fallo**, incluido `Potok-9C3A file restore callbacks and peer queue focal`, sobre `f69d6d9106dbdf3ba99158a1d14de4ca149aa1fe`. Behavior `FLUJO-BHV-POTOK-SNAPSHOT-DISK-CALLBACKS-017` actualizado `not_run → passing` solo después de revisar resultados.

**Alcance probado:** `restore_from_file` ejecuta orden global Exit(A), Exit(B), Enter(A), Enter(B), sin commit, descarta la cola antigua solo del propietario y mantiene aisladas solicitudes/callbacks de un segundo controlador. No prueba todavía `restore_from_file` solicitado dentro de un tick; para ello se planifica focal específica.

**Sin cambios productivos ni merge.** F5–F7 siguen abiertos. 25 pruebas manuales diferidas. CI del propio checkpoint documental pendiente de verificación independiente.

**Siguiente 9C3-C:** reentrancia de lectura/restauración de disco desde `StateUpdate` y `transition_committed`, con éxito explícito fuera de tick y sin mutaciones prematuras.

*Todo es Flujo; todo fluye.* 🌊
