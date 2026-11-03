# Potok 8D1-C5 — Auditoría de cierre del contrato SDK/runtime

**Fecha:** 2026-11-02 (America/Mexico_City). **Rama única:** `feature/fsm-runtime-flow-flusso`. **Base de 8D1-C:** `85a9ace1aab97dfc6f9248910b7fa05462e2a4d7`. **HEAD auditado:** `ae8b4710e9e1da22b12f708a5e0cdbbf6252bffd`.

**Dictamen:** **CI y contrato 8D1-C técnicamente CERRADOS**, en el alcance automatizado descrito abajo. **No** equivale a aprobación humana, garantía de sandbox, certificación de todas las fases de Potok ni cierre del plan de 12 fases. No hubo cambios de producción en 8D1-C.

## Trazabilidad FLU-FSM-003 / FSM-R08, FSM-R16..R19 y FSM-R29

Cada escenario figura como `passing` en `docs/behavior_catalog.json`, posee una escena `.tscn` existente y aparece como paso obligatorio **SUCCESS** en `.github/workflows/flujo-fsm.yml`. Las siguientes filas representan **9 pasos focales**, incluyendo los dos subescenarios de C4C2.

| Microbloque y contrato | Behavior ID | Escena focal (`tests/runtime/`) | Commit focal | Actions SUCCESS |
| --- | --- | --- | --- | --- |
| **C1A:** SDK obsoleto rechaza lectura y mutación tras `StateEnter`. | `FLUJO-BHV-POTOK-SDK-CAPABILITY-EXPIRY-001` | `flow_fsm_sdk_expired_operations_test.tscn` | `f315ddb1d459f1685da2a339647008a501a47aef` | [41562328203](https://github.com/mercurysama/Flujo/actions/runs/41562328203), 82/82 |
| **C1B:** expiración en Update/Exit, stop, reset y cambio de grafo. | `FLUJO-BHV-POTOK-SDK-CAPABILITY-LIFECYCLE-002` | `flow_fsm_sdk_lifecycle_guards_test.tscn` | `1df32fdbb0ccba29eede437bc3f1ae6b33374a33` | [41563021661](https://github.com/mercurysama/Flujo/actions/runs/41563021661), 83/83 |
| **C2:** aislamiento por controlador y máquina aun con `FlowGraph` compartido. | `FLUJO-BHV-POTOK-SDK-MULTI-OWNER-003` | `flow_fsm_sdk_machine_isolation_test.tscn` | `4c867d45d6bc5878eb42cd57bdf6c08279a40049` | [41565743817](https://github.com/mercurysama/Flujo/actions/runs/41565743817), 84/84 |
| **C3:** Ready/Timer/Constructor/Method no adquieren la capacidad FSM. | `FLUJO-BHV-POTOK-SDK-CAPABILITY-EXCLUSION-004` | `flow_fsm_sdk_non_fsm_capability_test.tscn` | `1989bf6fc52b52903770c8c53ec4207f304cd2af` | [41566863222](https://github.com/mercurysama/Flujo/actions/runs/41566863222), 85/85 |
| **C4A:** `register_state` + `change_state`, transición diferida y Enter/Exit ordenados. | `FLUJO-BHV-POTOK-SDK-REGISTER-CHANGE-005` | `flow_fsm_sdk_register_change_test.tscn` | `89d9bfb7382f44eaa2b52862a3e8562253db4ca9` | [41567631405](https://github.com/mercurysama/Flujo/actions/runs/41567631405), 86/86 |
| **C4B:** datos JSON-safe copiados profundamente, rechazos no mutantes. | `FLUJO-BHV-POTOK-SDK-DATA-DETACH-006` | `flow_fsm_sdk_data_copy_validation_test.tscn` | `6dda6c74637170905877cb59ee7c50bc23bb4f07` | [41568809804](https://github.com/mercurysama/Flujo/actions/runs/41568809804), 87/87 |
| **C4C1:** borrar alias inactivo purga solo sus comandos pendientes. | `FLUJO-BHV-POTOK-SDK-INACTIVE-REMOVE-007` | `flow_fsm_sdk_selective_removal_test.tscn` | `948c3b9d8a9f4d5df08d31a20e0ad7dba57ba631` | [41570578617](https://github.com/mercurysama/Flujo/actions/runs/41570578617), 88/88 |
| **C4C2A:** alias activo → fallback dinámico, rechazo durante tick. | `FLUJO-BHV-POTOK-SDK-ACTIVE-REMOVE-008` | `flow_fsm_sdk_active_removal_test.tscn` | `6650d5c7571887f13e61d18f4c4753c5e59e80eb` | [41573978889](https://github.com/mercurysama/Flujo/actions/runs/41573978889), 90/90 |
| **C4C2B:** alias activo → fallback declared, `StateEnter` reingresa sin duplicar alias. | Mismo `-008` | `flow_fsm_sdk_authored_fallback_test.tscn` | `6650d5c7571887f13e61d18f4c4753c5e59e80eb` | [41573978889](https://github.com/mercurysama/Flujo/actions/runs/41573978889), 90/90 |

**Último gate comprobado:** [Actions 41574412835](https://github.com/mercurysama/Flujo/actions/runs/41574412835), **completed SUCCESS, 90/90 pasos**, ninguno fallido u omitido, commit `ae8b4710e9e1da22b12f708a5e0cdbbf6252bffd`. Se inspeccionaron los nombres y conclusiones de cada focal, y el registro de Godot identifica versión **4.7.2.stable** y marcadores `[Flujo] ... passed`. El pipeline también ejecuta validador de catálogo, pruebas 8B1/8B2/8C1/8C2 y regresiones Ready/Timer/editor. En esta auditoría no se debilitó ninguna aserción ni se eliminó cobertura.

## Control de alcance e historial

La comparación de GitHub `85a9ace1...ae8b4710` registra **24 commits y 38 rutas modificadas**: `tests/`, `docs/` y `.github/workflows/flujo-fsm.yml`. **Cero archivos en `addons/vp_flujo/`, `demo/main.tscn` o modelo persistente**. Se preservaron los dos resultados fallidos de C4C2, [41572128593](https://github.com/mercurysama/Flujo/actions/runs/41572128593) (parseo del test) y [41572368984](https://github.com/mercurysama/Flujo/actions/runs/41572368984) (expectativa incorrecta de retorno a `StateEnter`), junto al corrección posterior autorizada mediante dos escenas independientes. No se presenta esos intentos históricos como PASS.

## Hallazgos y límites abiertos

- **Alcance medio / evidencia acotada:** en **C4C2** el caso positivo de `remove_state` activo fuera de tick se dispara desde el **ejecutor compartido controlado en la prueba**, con `PVController` y `FlowFSMRuntime` reales. No se demostró que un bloque de un proyecto pueda disparar automáticamente ese camino en un punto fuera de tick por una interfaz pública existente. La limitación no invalida el comportamiento del runtime comprobado ni autoriza inventar una API nueva; revisar esta necesidad en diseño posterior si se requiere una experiencia pública.
- **Límite de seguridad conocido:** `FlowFSMOperations` es una fachada por callback/máquina/instancia, **no un sandbox**. Un GDScript externo podría tener otras vías públicas para llegar al controlador o al grafo; no se ha auditado seguridad frente a código hostil.
- **Aceptación separada:** las **25 pruebas manuales de fase 7 (15 Fedora, 10 Android) siguen PENDING**, no PASS. Godot local/Flatpak **NOT RUN** aquí, y ninguna captura certifica la interacción humana. Los procedimientos `flujo-baseline` y `flujo-prove` se consultaron en forma de instrucciones versionadas, **no se invocaron formalmente** como Skills instaladas; no atribuirles un dictamen `READY` o `PASA`. La aceptación final, merge y release exigen intervención del mantenedor.
- **Fuera del contrato 8D1-C:** políticas de lifetime EPHEMERAL/SESSION/PERSISTENT, recuperación/snapshots, determinismo en reinicios y persistencia externa deben auditarse bajo **8D2**. No se declara fase 8, fases 9–12 o producto Potok completos.

**Clasificación de auditoría dentro de lo inspeccionado:** ningún defecto productivo comprobado; un límite funcional de cobertura señalado, una restricción arquitectónica de confianza y aceptación humana pendiente. No se llevó a cabo un análisis general de seguridad ni certificación de plataformas. Valoración más allá del alcance: **not measured**.

## Métricas de flujo y recuperación

- Requisitos: `FLU-FSM-003`, `FSM-R08`, `FSM-R16..R19`, `FSM-R29`. Auditoría `8D1-C5`. Base/head, 24 commits, 38 rutas, 9 focales y 90 pasos CI verificables. Cambio productivo neto de 8D1-C: **0 archivos**.
- Pruebas: **9/9 focales finales PASS** y 90/90 gate completo PASS; fallos iniciales de C4C2: **2** (causas documentadas). Tiempo del trabajo, revisión humana, créditos y otros datos no extraídos de evidencias: **not measured**.
- **Siguiente microbloque recomendado: 8D2-A, auditoría/plan** de lifetimes, stop/restart, snapshots y determinismo; primero revisar lo ya implementado y mapear requisitos/coverage, luego subdividir trabajo real faltante. No empezar código 8D2 por suposición.
- Mantener estrictamente rama `feature/fsm-runtime-flow-flusso`; no editar `main` ni `demo/main.tscn`. En el siguiente chat comprobar el último HEAD y Actions, leer este documento, `docs/current_iteration.md`, `docs/fsm_phase8_8d1c_microblocks.md` y `AGENTS.md`.

**Conclusión:** el subtramo **8D1-C se cierra técnicamente por evidencia automatizada**, con reservas explícitas; el proyecto general, la aceptación y las pruebas humanas permanecen abiertos.

*Todo es Flujo; todo fluye.* 🌊
