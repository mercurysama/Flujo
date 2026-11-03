# Potok 8D1-C3 — Exclusión de capacidades FSM en Ready, Timer, Constructor y Method

**Fecha:** 2026-11-02 (America/Mexico_City). **Rama:** `feature/fsm-runtime-flow-flusso`. **Resultado:** PASS técnico, sin aceptación visual.

## Contrato y alcance

`FlowFSMOperations` sólo debe entregarse dentro de callbacks reales `StateEnter`, `StateUpdate` y `StateExit` a través del ejecutor compartido. Las rutas `Ready`, `Timer`, `Constructor` y `Method` no reciben una capacidad FSM, aun cuando exista un runtime activo; un método invocado desde `StateUpdate` no hereda su autoridad aunque preserve el nombre `entry_point`. Una etiqueta `StateEnter` por sí sola no otorga la fachada si el ejecutor no recibió un `FlowFSMRuntime` autorizado.

## Cobertura focal

- Instancia real `PVController` con grafo schema 3 y FSM manual con plantilla y fases Enter/Update/Exit.
- Bloque de prueba SDK sin `class_name` ejecutado en Constructor, Ready, Timer (disparo real del `Timer.timeout`) y Method, además de las tres fases FSM.
- Constructor y Ready ejecutados al iniciar y repetidos **después de arrancar FSM**; Timer también disparado con FSM activo.
- Mismo Method llamado desde Ready, Timer y `StateUpdate`: no recibe fachada, incluido el último caso con etiqueta de fase FSM.
- Llamada aislada a `FlowReadyExecutor._execute_blocks` con etiqueta sintética `StateEnter`, sin pasar runtime: no obtiene capacidad.
- Comprobación positiva: las tres fases FSM reales reciben fachadas temporales que registran sus propios alias; después de cada callback se invalidan.
- Todas las rutas conservan `FlowGraph` intacto y la ejecución normal Ready/Timer/Constructor/Method.

## Implementación y evidencia

- Baseline: `b65b7a481673820a55136cf8547c1735d6a5e26c`, [CI 41566270777](https://github.com/mercurysama/Flujo/actions/runs/41566270777), **SUCCESS 84/84**.
- Commit focal `1989bf6fc52b52903770c8c53ec4207f304cd2af`: `tests/fixtures/fsm_sdk_non_fsm_capability_probe.gd`, `tests/runtime/flow_fsm_sdk_non_fsm_capability_test.gd` y `.tscn`, paso obligatorio en `.github/workflows/flujo-fsm.yml`, entrada `FLUJO-BHV-POTOK-SDK-CAPABILITY-EXCLUSION-004` del catálogo (inicialmente `not_run`).
- [Actions 41566863222](https://github.com/mercurysama/Flujo/actions/runs/41566863222): **completed SUCCESS 85/85**. La prueba focal `Potok-8D1C3 non-FSM SDK capability exclusion` tuvo **PASS** y la regresión global no reportó fallos.
- Código productivo modificado: **0 archivos**. `main`, esquema y `demo/main.tscn`: sin cambios. Los casos RED históricos permanecen intactos.

## Límites y continuidad

- Este contrato es una **fachada de autoridad por callback**, no un sandbox frente a GDScript hostil. La prueba no avala el acceso directo a APIs públicas del controlador, que queda fuera del alcance.
- Las instrucciones `tools/agent_skills/flujo-baseline` y `flujo-prove` se consultaron como referencia, pero no se invocaron formalmente como Skills en este entorno. Godot local: **NOT RUN**; GitHub Actions Godot 4.7.2: **PASS**.
- Fase 7 conserva **25 pruebas humanas pendientes**: 15 Fedora, 10 Android. CI automático no aprueba la experiencia visual.
- **Próximo microbloque 8D1-C4A:** registro de alias dinámico desde SDK y solicitud de cambio encolada sin reentrada, seguido de C4B (datos), C4C (retiro) y C5 (auditoría). Consultar HEAD y CI antes de actuar.

*Todo es Flujo; todo fluye.* 🌊
