# Potok 8D1-B1 — Contrato RED del acceso FSM desde bloques

**Fecha:** 2026-11-02 (hora local del mantenedor); **rama:** `feature/fsm-runtime-flow-flusso`. **Baseline previo:** `00bc533ed1ba7205606fc08c2c6ea649cba98b4a`, [CI 41551132124](https://github.com/mercurysama/Flujo/actions/runs/41551132124) SUCCESS. **Estado:** **RED esperado y confirmado**, no una implementación terminada ni una regresión aprobada.

## Archivos/commits

- `tests/fixtures/fsm_sdk_capability_probe.gd` (`d71066920174fa7051fcc58374e6154f085d3b5c`): bloque de prueba `@tool extends FlowBlock` sin `class_name` global, que consulta `context.get_fsm_operations()` cuando el método existe. En su ausencia registra que no existe, sin lanzar un método inexistente.
- `tests/runtime/flow_fsm_sdk_context_capability_contract_test.gd` (`53d1ad6e22cd00eeabffd6047f078bee830364ec`): prueba integral que utiliza el ejecutor real y la misma clase de bloque en Ready, StateEnter, StateUpdate y StateExit, con una segunda máquina testigo.
- `tests/runtime/flow_fsm_sdk_context_capability_contract_test.tscn` (`8540e9b4b519d77be46f831d754870f5c7999fe3`): escena Godot.
- `.github/workflows/flujo-fsm.yml` (`13a494334df5a3ac23e622163a07747ae72e2665`): paso requerido, **sin** `continue-on-error` ni marcador de éxito artificial.

## Evidencia RED verificada

[Actions 41552195224](https://github.com/mercurysama/Flujo/actions/runs/41552195224) finalizó **completed FAILURE**, paso `Potok-8D1B1 SDK machine-scoped capability contract (expected RED until 8D1B2)`. Antes de fallar pasaron la carga del editor, validador y pasos anteriores. Log de Godot 4.7.2 identifica específicamente cuatro aserciones contractuales:

- `StateEnter receives live machine-scoped register_state capability`;
- `StateUpdate receives same-machine capability`;
- `StateExit receives capability via the shared executor`;
- `Three FSM callbacks register distinct instance-local aliases`.

Esto confirma la brecha ya auditada en 8D1-A: el callback de `FlowBlock.get_navigation_decision` sí se ejecuta, pero no recibe la nueva fachada de operaciones requerida. **No se observaron fallos de parseo como causa del paso RED**, según el diagnóstico registrado. La parte Ready debe permanecer sin capacidad; la nueva API solo será válida durante fases FSM.

## Reglas para 8D1-B2

Implementar la fachada **mínima por llamada** sin crear otra registry: `get_fsm_operations` en contexto para fases FSM, con `register_state` delegando a `FlowFSMRuntime.register_state` y `machine_id` fijo obtenido de la fase propietaria. La capacidad nunca debe entregarse en Ready, Timer, Constructor o ejecución de método; no debe exponer un `FlowGraph` mutable como campo propio. El ciclo de vida debe invalidar o rechazar referencias almacenadas después del callback. Luego completar accesores/operaciones adicionales y pruebas de obsolescencia de 8D1-C según contrato, sin cambiar esquemas ni APIs de estado existentes. El test RED **no debe desactivarse ni diluirse** para fabricar GREEN.

**Gates próximos:** leer y aplicar baseline/prove a la modificación productiva y confirmar ejecución focal + regresiones de Godot; documentar nuevos resultados y SHA. **Fase 7** mantiene 25 pruebas humanas diferidas. `main` intacta.

### Métricas observables

- Cobertura incorporada: 1 prueba focal runtime, 1 bloque fixture, 1 escena, 1 paso requerido del CI.
- Estado de focal: FAIL esperado por cuatro aserciones de capacidad no disponible, código de salida 1.
- Código productivo: 0 archivos modificados.
- Duraciones, horas humanas y coste: no medidos.

*Todo es Flujo; todo fluye.* 🌊
