# Potok 9C3-D — Cierre del guard de reentrancia de restore_from_file

**Fecha:** 2026-11-03. **Rama:** `feature/fsm-runtime-flow-flusso`. **Resultado: PASS técnico automatizado.** [GitHub Actions 41706512868](https://github.com/mercurysama/Flujo/actions/runs/41706512868) finalizó **SUCCESS** sobre `1a882fe540d66af5acf92ca2d1de2e64a22b5888`: **108/108 pasos**, ningún fallo y focal obligatorio `Potok-9C3C in-tick disk restore reentrancy focal` aprobado.

**Garantías verificadas:** `restore_from_file` intentado desde `StateUpdate` y `transition_committed` durante tick devuelve `false`; no hay callbacks extra ni tick recursivo, las colas y el otro controlador mantienen aislamiento, y la restauración válida fuera del tick emite globalmente Exit(A), Exit(B), Enter(A), Enter(B). El behavior `FLUJO-BHV-POTOK-SNAPSHOT-DISK-REENTRANCY-018` pasó de `not_run` a `passing` solo después del resultado integral.

**Límites:** no se comprueban cortes de energía ni los fallos de copia/rename F5–F7. No hay cambio de runtime, codec, schema, demo ni `main`. Las 25 pruebas humanas siguen aplazadas; el checkpoint documental tendrá su propio CI separado.

**Siguiente:** 9D1-A, rechazo de snapshots con formato, esquema, grafo, ID de máquina o estructura incompatible; mantener v1 y no realizar migración implícita.

*Todo es Flujo; todo fluye.* 🌊
