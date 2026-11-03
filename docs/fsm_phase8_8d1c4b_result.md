# Potok 8D1-C4B — Datos dinámicos del SDK: copias profundas y validación

**Fecha de trabajo:** 2026-11-02 (America/Mexico_City). **Rama:** `feature/fsm-runtime-flow-flusso`. **Resultado:** PASS técnico automático, sin aprobación visual.

## Contrato

Caracterizar las operaciones `FlowFSMOperations.register_state`, `get_state_data` y `set_state_data` exclusivamente desde un bloque `FlowBlock` estilo SDK ejecutado en un callback real `StateEnter`. Los diccionarios y arreglos anidados deben copiarse de forma profunda en el registro, la escritura y la lectura. Los datos inválidos deben rechazarse sin mutar el estado previamente aceptado ni añadir alias.

## Evidencia verificable

- Baseline previo: `1b952a4d545f8c9620017eed5a75d22ef7e48a3a`, [CI 41568112472](https://github.com/mercurysama/Flujo/actions/runs/41568112472), **SUCCESS 86/86**.
- Commit focal: `6dda6c74637170905877cb59ee7c50bc23bb4f07`. Añadidos `tests/fixtures/fsm_sdk_data_copy_validation_probe.gd`, `tests/runtime/flow_fsm_sdk_data_copy_validation_test.gd` y la escena `.tscn`; incorporados un paso requerido a `.github/workflows/flujo-fsm.yml` y el comportamiento `FLUJO-BHV-POTOK-SDK-DATA-DETACH-006` inicialmente `not_run`.
- [CI 41568809804](https://github.com/mercurysama/Flujo/actions/runs/41568809804): **completed SUCCESS 87/87** en Godot **4.7.2**, incluido el paso `Potok-8D1C4B SDK data deep copy and validation focal` con **PASS**.
- Desde cada callback SDK se registra un alias `SESSION` con un `Dictionary` que contiene objetos `Dictionary` y `Array` anidados. Modificar el diccionario de entrada no cambia lo almacenado; modificar dos lecturas sucesivas tampoco.
- `set_state_data` acepta el reemplazo válido, pero modificar el argumento después de escribir no altera lo almacenado. Sus lecturas posteriores vuelven a entregar copias independientes.
- Se rechazan en registro y escritura **ocho categorías de payload inválido**: más de 256 entradas de arreglo, clave no `String`, `INF`, JSON mayor que 65 536 caracteres, profundidad superior a ocho, `Callable`, `Vector2` y `Node` vivo. Cada rechazo deja intactos los datos anteriores y no crea nuevos alias.
- Dos controladores `PVController` comparten un `FlowGraph` validado, pero poseen alias y metadatos independientes. Ninguna operación inválida cambia la cola, el estado activo ni los recursos persistentes; la fachada retenida expira al retornar su callback.
- **Código productivo modificado: 0 archivos**; `main`, `demo/main.tscn`, los esquemas y el editor no se modificaron. No se relajaron las aserciones históricas.

## Límites, decisiones y continuidad

Se reutilizaron `FlowFSMOperations`, `FlowFSMDataValidator` y el registro del runtime porque las comprobaciones existentes 8B2 ya caracterizaban las copias y límites mediante llamadas directas; esta focal añade la trayectoria real del **SDK** sin introducir una segunda implementación. No se afirma aislamiento frente a scripts GDScript con acceso directo a objetos públicos: la fachada **no es un sandbox**. Las instrucciones versionadas de `flujo-baseline` y `flujo-prove` se leyeron, pero **no se invocaron formalmente** como Skills; Godot local **NOT RUN**, remoto **PASS**. Aceptación humana de fase 7: **15 Fedora y 10 Android PENDING**.

**Métrica comprobable:** un escenario focal nuevo, ocho tipos de datos rechazados, dos instancias de controlador, 87 pasos de GitHub Actions con resultado global correcto; duración de trabajo y métricas humanas: **not measured**.

**Punto de recuperación:** confirmar HEAD y último Actions de `feature/fsm-runtime-flow-flusso`; continuar **8D1-C4C**: eliminación de alias desde un callback SDK autorizado, fallback válido, orden `Exit→Enter` y depuración selectiva de la cola. Luego **8D1-C5** para auditoría y cierre técnico de 8D1-C. Consultar [plan recuperable](fsm_phase8_8d1c_microblocks.md).

*Todo es Flujo; todo fluye.* 🌊
