# Potok 8D1-C4C2 — SDK: eliminación activa con fallbacks dinámico y declarado

**Fecha de trabajo:** 2026-11-02 (America/Mexico_City). **Rama:** `feature/fsm-runtime-flow-flusso`. **Resultado:** PASS técnico, pendiente cierre de auditoría 8D1-C5.

## Alcance y resultados

El comportamiento de `FlowFSMOperations.remove_state` se comprobó con **dos escenas independientes** que instancian grafos, controladores y runtimes reales, sin cambiar producción:

- **8D1-C4C2A:** registro desde `StateEnter`, cambio diferido a alias activo, rechazo de eliminación activa durante `StateUpdate` y posterior eliminación desde la capacidad SDK vinculada a máquina **fuera de tick**, con fallback a **otro alias dinámico**. Se comprueban rechazo de fallbacks inválidos, Exit→Enter→Commit, borrado de solicitud al alias retirado, preservación de evento de otra máquina y caducidad de fachada.
- **8D1-C4C2B:** escenario independiente de fallback **hacia estado declarado**. El primer fallback dinámico se comprueba de nuevo para preparar la segunda eliminación; al volver al estado inicial, Godot ejecuta correctamente su bloque `StateEnter`. La prueba exige **exactamente ese reingreso**, pero verifica que el guard de creación impide registrar de nuevo alias, conserva los IDs originales, no añade solicitudes y finaliza con el registro dinámico vacío. Se comprueban ambos ciclos Exit→Enter→Commit sin reentrada recursiva inesperada.

La operación activa dentro del tick se **rechaza** en el contrato existente; el caso positivo fuera de tick usa un **test seam controlado**: `FlowReadyExecutor._execute_blocks` con el verdadero `PVController`, `FlowFSMRuntime`, ID de máquina y entrada `StateExit`, nunca una fachada falsificada. No implica que exista una ruta pública normal que permita al usuario provocar arbitrariamente ese callback fuera del tick. `FlowFSMOperations` tampoco es un sandbox para scripts GDScript arbitrarios.

## Registro histórico y evidencia

- Último baseline válido: `b6f61f9f2496e2d5f359d5127b3804a870f30dbb`, [Actions 41571201948](https://github.com/mercurysama/Flujo/actions/runs/41571201948) **SUCCESS 88/88**.
- Primera prueba combinada `d7ffa6b0c73c073fe5817426e5b4744eae14d75f`: [Actions 41572128593](https://github.com/mercurysama/Flujo/actions/runs/41572128593) **FAIL** por parseo en el test, línea 205. Corrección de sintaxis `b53ee9f51b3e2fc337ef5ea899c0d6d77c5fadd6`: [Actions 41572368984](https://github.com/mercurysama/Flujo/actions/runs/41572368984) **FAIL**, con dos aserciones incorrectas en la prueba que negaban el reingreso `StateEnter` al fallback authored; la evidencia indicaba funcionamiento del runtime, no una regresión demostrada. Se detuvo el recurso tras dos fallos, de acuerdo con `AGENTS.md`.
- Nuevo trabajo autorizado y dividido: commit `6650d5c7571887f13e61d18f4c4753c5e59e80eb`. La escena anterior `tests/runtime/flow_fsm_sdk_active_removal_test.tscn` cubre **C4C2A**; `tests/runtime/flow_fsm_sdk_authored_fallback_test.tscn` cubre **C4C2B**. Ambos pasos se ejecutan de forma obligatoria en `.github/workflows/flujo-fsm.yml` y aparecen en `FLUJO-BHV-POTOK-SDK-ACTIVE-REMOVE-008`.
- [Actions 41573978889](https://github.com/mercurysama/Flujo/actions/runs/41573978889): **completed SUCCESS 90/90** en Godot **4.7.2**; focal **8D1-C4C2A PASS**, focal **8D1-C4C2B PASS** y todas las regresiones requeridas sin fallos. Catalogado `passing` tras la evidencia, no antes.
- **Código productivo cambiado:** 0 archivos. Sin cambio de `FlowGraph`, esquemas, `main`, editor o `demo/main.tscn`; ningún gate histórico fue debilitado. Se dividió el escenario y se corrigieron expectativas para conservar y reforzar cobertura.

## Decisiones, límites y próximos pasos

**Justificación:** dividir pruebas evita confundir ausencia de callback al cambiar a alias con reingreso válido al volver al estado authored. Se descartó modificar el runtime o su semántica de `StateEnter` porque el comportamiento observado coincide con el contrato. Queda como riesgo técnico para auditoría 8D1-C5 el uso del test seam fuera del tick: prueba la fachada en una ejecución controlada, no una ruta pública que dispare ese ciclo de forma autónoma.

**Métrica disponible:** dos escenas focales SDK aprobadas, 90 pasos CI, dos ejecuciones fallidas históricas preservadas para trazabilidad y un commit de caracterización; esfuerzo y métricas no medibles: **not measured**. Godot local **NOT RUN**, CI remoto **PASS**. Las skills versionadas de baseline/prove se consultaron como documentación y **no fueron invocadas formalmente**. Pruebas humanas de fase 7: **25 pendientes** (15 Fedora, 10 Android).

**Punto de recuperación:** verificar HEAD y Actions de `feature/fsm-runtime-flow-flusso`; comenzar **8D1-C5**, auditoría integral de C1A, C1B, C2, C3, C4A, C4B, C4C1 y C4C2; relacionar contrato, comportamiento, tests, commits y CI, registrar límites de seguridad y cerrar técnicamente 8D1-C sólo con evidencia suficiente. Después auditar **8D2**.

*Todo es Flujo; todo fluye.* 🌊
