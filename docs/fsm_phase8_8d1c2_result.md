# Potok 8D1-C2 — Aislamiento SDK entre controladores y máquinas

**Fecha:** 2026-11-02 (America/Mexico_City). **Rama:** `feature/fsm-runtime-flow-flusso`. **Estado:** PASS técnico con regresión global.

## Objetivo y contrato

Caracterizar sin duplicar el runtime que una fachada `FlowFSMOperations` recibida en el callback de un bloque SDK se limita a **su máquina y su controlador**, incluso si dos `PVController` utilizan el mismo `FlowGraph`. La fachada no constituye un sandbox para scripts GDScript hostiles. No se altera la API pública, el modelo persistente, Ready/Timer ni la estructura de la interfaz Fluo.

## Alcance de la prueba

- Dos controladores `PVController`, cada uno ejecutando dos máquinas MANUAL del mismo `FlowGraph` (cuatro registros dinámicos independientes).
- Cuatro callbacks `StateEnter` reales que usan la fachada obtenida desde `FlowNavigationContext.get_fsm_operations()`. Se reutiliza **un mismo ID dinámico explícito** en las cuatro combinaciones, verificando su ámbito por máquina/instancia.
- Cada callback registra un estado desde su plantilla local, lee su alias y escribe un diccionario de datos identificando controlador y máquina. Las plantillas y estados de la máquina hermana rechazan registro, consulta, cambio, borrado, lectura y escritura.
- Se conservan las fachadas SDK y se comprueba su expiración tras retornar. La actualización de datos, las transiciones y la eliminación de un alias afectan solo al registro seleccionado, aun cuando otra máquina o controlador comparte el ID.
- Detener el primer controlador no detiene el segundo; su estado activo y sus alias permanecen. `FlowGraph` conserva las mismas declaraciones, objetos e IDs y supera `FlowGraphValidator`.

## Commits, archivos y pruebas

- Baseline antes de C2: `6b0913349eb5e513ecf9bd09f7a4136e3dc182eb`, [CI 41563497465](https://github.com/mercurysama/Flujo/actions/runs/41563497465), **SUCCESS 83/83**.
- Commit único de prueba: `4c867d45d6bc5878eb42cd57bdf6c08279a40049`. Archivos:
  - `tests/fixtures/fsm_sdk_machine_isolation_probe.gd`: bloque externo de prueba sin `class_name`, cuatro capacidades reales.
  - `tests/runtime/flow_fsm_sdk_machine_isolation_test.gd` y `.tscn`: verificación por controlador y máquina.
  - `.github/workflows/flujo-fsm.yml`: paso obligatorio sin `continue-on-error`.
  - `docs/behavior_catalog.json`: entrada `FLUJO-BHV-POTOK-SDK-MULTI-OWNER-003`, inicialmente `not_run`; actualizada a `passing` solo tras ejecución.
- [Actions 41565743817](https://github.com/mercurysama/Flujo/actions/runs/41565743817): **completed SUCCESS 84/84**. El paso `Potok-8D1C2 two controllers and two machines SDK isolation` resultó **PASS**, así como los baselines y regresiones obligatorios. `git diff --check` y el validador del catálogo formaron parte de la ejecución.
- Código productivo modificado: **0** archivos. No hubo necesidad de reparación GDScript ni cambio de esquema. `main` no se modificó.

## Limitaciones y continuidad

Las Skills versionadas `tools/agent_skills/flujo-baseline` y `flujo-prove` fueron leídas como referencia en esta continuidad, pero **no se ejecutaron formalmente**; el entorno no dispone de su invocación directa. Godot local: **NOT RUN**; pruebas remotas Godot 4.7.2: **PASS**. No se declara aislamiento frente a scripts con acceso directo a los objetos Godot.

No se adelantan las pruebas humanas: fase 7 mantiene **15 pruebas Fedora y 10 Android PENDING**. El PASS técnico no demuestra aceptación táctil ni visual.

**Punto exacto de recuperación:** tras esta bitácora, verificar el último HEAD de `feature/fsm-runtime-flow-flusso` y CI. Continuar **8D1-C3**, exclusión de capacidad FSM desde Ready, Timer y Constructor y no filtración hacia rutas de método; conservar regresiones C1A/C1B/C2. Ver [plan de microbloques](fsm_phase8_8d1c_microblocks.md).

*Todo es Flujo; todo fluye.* 🌊
