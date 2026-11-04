# Potok 10A-5 — Ciclo de vida, señales y aislamiento entre relojes

**Fecha:** 2026-11-03. **Base:** `eb7ba4b87d952d639e83b19a3c7c7abec4935249`. **Estado:** prueba focal preparada, **NOT RUN** hasta conocer el resultado CI del commit. Alcance test-only y documentación; sin modificar runtime.

## Arquitectura observada

`PVController._ready()` arranca `FlowFSMRuntime` y entrega `get_fsm_runtime()` cuando la creación ya concluyó. Las señales `machine_started` y `state_entered` emitidas durante `start` **no pueden ser recuperadas** por un observador que se suscribe después de obtener el runtime: el sistema no cuenta con replay. Las señales `state_updated`, `state_exited` y `machine_stopped` sí pueden observarse desde el siguiente ciclo. `reset()` emite Exit → Enter por máquina; `stop()` emite Exit → Stopped, limpia colas y es idempotente. El reloj manual no equivale a una API de pausa del depurador.

## Caracterización 10A-5

La nueva fixture `tests/runtime/flow_fsm_observability_lifecycle_test.tscn` observa **dos controladores** que comparten el mismo `FlowGraph`, con máquinas MANUAL y PHYSICS. Congela los relojes automáticos de la fixture, verifica actualizaciones por reloj, reset en A, queue independiente en B, stop repetido en A, entrega por reloj de B y cierre de ambos sin alteraciones del grafo. El nuevo catálogo `FLUJO-BHV-POTOK-OBSERVABILITY-LIFECYCLE-003` inicia en `not_run`, gate obligatorio en GitHub Actions. Se mantienen los tests FSM-4B/4C, 6H2, 10A3 y 10A4.

**Brecha:** un panel que se conecte tarde requerirá inspección read-only inicial porque los eventos de startup no se repiten. Agregar replay o emitir una señal nueva constituiría un cambio contractual no autorizado todavía.

**Revisión:** CI del mismo commit pendiente, Godot local/Skills formales **NOT RUN**, pruebas humanas diferidas; sin modificaciones a `main`.

*Todo es Flujo; todo fluye.* 🌊

## Verificación de cierre posterior

**PASS de la focal y regresión integral:** [GitHub Actions 41744492793](https://github.com/mercurysama/Flujo/actions/runs/41744492793) finalizó `completed/success` para `0c2204c71fa85704aa63cc0113851ae19f208e5c`. El catálogo se cierra como `passing` únicamente por esta evidencia. Local Fedora/Skills formales y aprobación humana: **NOT RUN**; fase 10 sigue abierta.
