# Potok 9C2-B — Cierre de restauración explícita tras reconstrucción

**Fecha:** 2026-11-03. **Rama:** `feature/fsm-runtime-flow-flusso`. **Estado: PASS técnico automatizado.**

[GitHub Actions 41679826206](https://github.com/mercurysama/Flujo/actions/runs/41679826206) y [checkpoint corregido 41679988667](https://github.com/mercurysama/Flujo/actions/runs/41679988667) terminaron **SUCCESS**; el segundo ejecutó **106/106 pasos sin fallos**, incluida la puerta obligatoria `Potok-9C2A controller teardown and disk restore focal`. La escena `tests/runtime/flow_fsm_snapshot_instance_reconstruction_test.tscn` verifica que tras `queue_free` de un controlador y creación del sucesor sobre el mismo FlowGraph no hay autoload de alias ni datos de instancia; `restore_from_file` explícito recupera PERSISTENT y mantiene SESSION ausente. Se actualizó `FLUJO-BHV-POTOK-SNAPSHOT-RECONSTRUCT-016` de `not_run` a `passing` después de éxito integral.

**Límites:** no es restauración automática del juego al arranque; los puntos F5–F7 del backup siguen sin reproducción. Código productivo, codec, formato, esquema y `main` sin cambios; 25 manuales siguen diferidas. El antiguo checkpoint de 9C1-B falló solo por whitespace, reparado en `0d3a445c39ed491b3f64c9d3c0c1834852da94cd` y validado por el run integral posterior.

**Siguiente:** 9C3-A, foco de `restore_from_file` y callbacks globales Exit→Enter con cola/reentrancia, sin duplicar pruebas de `restore_snapshot` preexistentes.

*Todo es Flujo; todo fluye.* 🌊
