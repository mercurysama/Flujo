# Potok — 8D1-C: contrato y microbloques recuperables

**Fecha del plan:** 2026-11-02 (America/Mexico_City)
**Rama exclusiva:** `feature/fsm-runtime-flow-flusso`
**Punto de partida verificado:** `85a9ace1aab97dfc6f9248910b7fa05462e2a4d7`; [Actions 41558938893](https://github.com/mercurysama/Flujo/actions/runs/41558938893), SUCCESS 81/81.
**Estado actual:** C1A, C1B, C2, C3, C4A, C4B, C4C1 y C4C2 **PASS**; **C5 AUDITADO y 8D1-C técnicamente CERRADO** por [CI 41574412835](https://github.com/mercurysama/Flujo/actions/runs/41574412835), SUCCESS 90/90. Aceptación humana y pruebas visuales pendientes.

**Último checkpoint:** [auditoría 8D1-C5](fsm_phase8_8d1c5_audit.md), validación funcional `ae8b4710e9e1da22b12f708a5e0cdbbf6252bffd`, [Actions 41574412835](https://github.com/mercurysama/Flujo/actions/runs/41574412835) SUCCESS 90/90. Próximo **8D2-A** (auditar y planear).

## Contrato y límites

Continuación de [8D1-B2](fsm_phase8_8d1b2_result.md) y [auditoría SDK 8D1-A](fsm_phase8_8d1a_sdk_boundary_audit.md), bajo [FLU-FSM-003](fsm_dynamic_contract_v1.md). `FlowFSMOperations` es una fachada por callback, máquina y controlador; no es un sandbox de GDScript. La instancia conserva su registro dinámico en `FlowFSMRuntime`, no en `FlowGraph`. No se añaden esquemas, listas editor, servicios paralelos ni cambios a Ready/Timer/Constructor. Ante un uso obsoleto, operaciones mutadoras retornan valores de rechazo, consultas no filtran datos y el grafo queda intacto.

## Microbloques

| ID | Objetivo y contrato verificable | Entregable/gate |
| --- | --- | --- |
| **8D1-C1A** | Retener una fachada SDK de `StateEnter` y comprobar que funcionó dentro del callback pero `register_state`, `has_state`, `change_state`, `remove_state`, `get_state_data` y `set_state_data` rechazan la referencia después de retornar; sin mutación del runtime ni del grafo. | Fixture externa sin `class_name`, escena focal y paso CI obligatorio. Si pasa con producción intacta, no refactorizar. |
| **8D1-C1B** | Retención en `StateUpdate`/`StateExit`; parada, reactivación y cambio de `flow_graph` invalidan la capacidad vieja, incluso con los mismos IDs. | Test independiente y CI; controlar la semántica de Exit al detener. |
| **8D1-C2** | Dos `PVController` con `FlowGraph` compartido: callback de A no altera B; capacidades guardadas de A/B no se cruzan. Múltiples máquinas en un controlador también se aíslan. | Test focal de independencia y regresiones 8B/8C. |
| **8D1-C3** | Ready, Timer y Constructor no reciben capacidad FSM; fases Enter/Update/Exit sí; el ejecutor genérico no autoriza accidentalmente métodos no FSM. | Focal de ejecución real con callbacks y regresiones Ready/Timer. |
| **8D1-C4A** | Un bloque externo registra un alias válido con datos y plantilla autorizada y solicita cambio a él. | Focal de SDK, transición encolada sin reentrada. |
| **8D1-C4B** | Desde un callback SDK autorizado se consulta/actualiza una copia independiente de datos; rechazo de payload inválido. | Focal de copias profundas y datos. |
| **8D1-C4C1** | Desde un callback real StateUpdate del SDK retirar alias inactivo y purgar únicamente las solicitudes dirigidas a él. | [PASS 88/88](fsm_phase8_8d1c4c1_result.md), prueba focal SDK y cola selectiva. |
| **8D1-C4C2** | Dos escenarios independientes: eliminación activa con fallback dinámico; eliminación activa con fallback authored y reingreso legítimo en StateEnter sin nuevos alias; rechazo de eliminación durante tick. | [PASS 90/90](fsm_phase8_8d1c4c2_result.md), dos focales SDK y regresión global; conector externo controlado fuera de tick. |
| **8D1-C5** | Auditoría C1–C4 con contrato→behavior→test→commit→Actions y comparación de 24 commits. | [C5 auditado](fsm_phase8_8d1c5_audit.md), 9 focales y CI 90/90 PASS; cierre técnico con reservas sobre test seam, sandbox y aceptación humana. |

Cada microbloque se comitea por separado, con pruebas RED solo cuando existe una brecha demostrada y GREEN posterior; las pruebas históricas no se debilitan. Un test nuevo que caracteriza comportamiento ya presente puede ser GREEN en la primera ejecución. CI Godot 4.7.2 es la fuente remota de ejecución; un archivo de prueba sin ejecución cuenta **NOT RUN**. Se distinguen **PASS**, **FAIL**, **SKIPPED** y **NOT RUN**; no se presume aprobación visual por CI.

## Requisitos y recuperación

- `FSM-R16..R19`: operaciones dinámicas y aislamiento de instancias; `FSM-R08`: ejecutor compartido sin regresión Ready/Timer; `FSM-R29`: evidencia automatizada.
- Baseline/revisión: seguir `tools/agent_skills/flujo-baseline/SKILL.md` y `flujo-prove/SKILL.md` en la medida verificable por conector GitHub. Consultar sus archivos **no equivale** a invocarlas formalmente. Las Skills no están disponibles como ejecutables instalados en este entorno; CI remota permite verificación real.
- `docs/behavior_catalog.json`: añadir cobertura separada por escenario probado si falta, sin sobrescribir estados históricos.
- Regresión focal base: `tests/runtime/flow_fsm_sdk_context_capability_contract_test.tscn`, 8B1/8B2/8C1/8C2 y flujo Ready/Timer; `.github/workflows/flujo-fsm.yml` concentra el gate remoto.
- Proteger `demo/main.tscn`, `main`, recursos persistentes, las 25 pruebas humanas pendientes (15 Fedora, 10 Android) y todos los cambios de otras ramas.
- Tras **8D1-C5**, auditar 8D2 (políticas EPHEMERAL/SESSION/PERSISTENT, stop/restart, snapshots, determinismo) y 8E; seguir fases 9–11 con brechas reales, no reconstrucción.

**Punto de recuperación:** **8D1-C completada técnicamente**, sin aceptación visual/humana. Leer [C5](fsm_phase8_8d1c5_audit.md), verificar HEAD/Actions y continuar **8D2-A, auditoría y plan**, comenzando por código ya implementado y contratos de lifetime, stop/restart, snapshots y determinismo. No declarar fase 8 completa.

*Todo es Flujo; todo fluye.* 🌊
