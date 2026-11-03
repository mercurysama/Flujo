# Potok 8D1-C1B — Vigencia de fachadas SDK durante reset, stop y cambio de grafo

**Fecha:** 2026-11-02 (America/Mexico_City). **Rama:** `feature/fsm-runtime-flow-flusso`. **Resultado:** PASS automatizado.

## Contrato verificado

En un `PVController` real, un bloque externo de prueba ejecuta `StateEnter`, `StateUpdate`, `StateExit` en reset y otra entrada `StateEnter`. Cada callback registra un alias SESSION y entrega una fachada `FlowFSMOperations` que, una vez concluido, rechaza acceso posterior. Los alias SESSION sobreviven al reset del mismo runtime, pero se descartan al detenerlo y activar un runtime nuevo. Durante la detención del controlador, el callback Exit no puede registrar nuevos alias.

Una fachada **construida directamente en la prueba**, no entregada por el SDK, también comprueba la guarda `_can_use`: responde mientras el grafo de su controlador coincide y rechaza consultas y registros si `flow_graph` cambia. Esto verifica la guarda de contexto, pero no demuestra por sí solo un sandbox frente a GDScript hostil.

## Implementación y pruebas

- Baseline de este lote: `3e9088b4c30665c3c83870c78f77cc6d9ce49893`, [CI 41562801506](https://github.com/mercurysama/Flujo/actions/runs/41562801506), SUCCESS **82/82**.
- Commit del test `1df32fdbb0ccba29eede437bc3f1ae6b33374a33`: `tests/runtime/flow_fsm_sdk_lifecycle_guards_test.gd`, escena `.tscn`, paso obligatorio en `.github/workflows/flujo-fsm.yml`, y entrada de catálogo `FLUJO-BHV-POTOK-SDK-CAPABILITY-LIFECYCLE-002` inicialmente `not_run`.
- [CI 41563021661](https://github.com/mercurysama/Flujo/actions/runs/41563021661): **completed SUCCESS 83/83**; el focal `Potok-8D1C1B SDK lifecycle reset graph and stop guards` resultó **PASS**; sin fallos en las regresiones.
- Código productivo modificado: **0 archivos**; fixture de C1A reutilizada.
- `flujo-baseline`/`flujo-prove`: instrucciones consultadas desde `tools/agent_skills/`, **no invocadas formalmente** en este entorno. Godot local: **NOT RUN**; CI remota Godot 4.7.2: **PASS**.

## Límites y recuperación

- Este microbloque no demuestra todavía que las fachadas SDK de dos instancias `PVController` sean independientes, ni niega acceso directo a otros objetos GDScript por APIs públicas. Tampoco certifica Ready/Timer/Constructor por prueba focal nueva ni un ciclo completo Add→Change→Remove desde SDK.
- Fase 7: **25 pruebas humanas pendientes**, 15 Fedora y 10 Android; CI no implica aceptación visual.
- Siguiente microbloque: **8D1-C2**, dos controladores con grafo compartido y múltiples máquinas, sin cruces de capacidades. Leer HEAD real y GitHub Actions antes de escribir; continuar conforme al [plan 8D1-C](fsm_phase8_8d1c_microblocks.md).

*Todo es Flujo; todo fluye.* 🌊
