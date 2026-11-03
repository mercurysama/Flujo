# Potok 8E-3 — Dictamen de cierre técnico condicionado de fase 8 (FLU-FSM-003)

**Fecha:** 2026-11-03 (America/Mexico_City). **Rama exclusiva:** `feature/fsm-runtime-flow-flusso`. **Dictamen:** **FASE 8 APROBADA TÉCNICAMENTE POR PRUEBAS AUTOMATIZADAS, CON ACEPTACIÓN HUMANA DIFERIDA**. No equivale a aceptación final, merge, release ni validación de fase 9.

## Base verificable

- Criterio [FLU-FSM-003](fsm_dynamic_contract_v1.md), y [plan original](fsm_implementation_plan.md): un personaje puede adquirir un estado runtime, activarlo y retirarlo sin alterar `FlowGraph`; están protegidos aislamiento, IDs, plantillas autorizadas, cupos, datos, retirada con fallback y ciclo de vida.
- [Auditoría 8E-1](fsm_phase8_8e1_closure_criteria_audit.md): correspondencia de las ocho tareas de fase 8 con pruebas de 8A, 8B1/B2, 8C1/C2, 8D1 y 8D2. [CI 41594476054](https://github.com/mercurysama/Flujo/actions/runs/41594476054) **completed SUCCESS**; checkpoint [41594515152](https://github.com/mercurysama/Flujo/actions/runs/41594515152) **completed SUCCESS**.
- [Auditoría 8E-2](fsm_phase8_8e2_governance_gate_audit.md): gobernanza `AGENTS.md`, `docs/constitution.md` y `docs/development_workflow.md`; del catálogo completo de 92 entradas, **22 automáticas Potok** tienen `passing`, test-paths existentes y cobertura en el workflow Godot 4.7.2. [CI 41595172497](https://github.com/mercurysama/Flujo/actions/runs/41595172497) **completed SUCCESS**; checkpoint [41595220445](https://github.com/mercurysama/Flujo/actions/runs/41595220445) **completed SUCCESS**.
- [8D2-C2](fsm_phase8_8d2c2_closeout.md) describe lifetimes, resets, snapshot compatible, determinismo y callbacks con **11 focos B1–B3 obligatorios**; [CI 41594048021](https://github.com/mercurysama/Flujo/actions/runs/41594048021) **completed SUCCESS**. [8D1-C5](fsm_phase8_8d1c5_audit.md) registra acceso autorizado a la capacidad FSM y pruebas SDK; [CI 41574412835](https://github.com/mercurysama/Flujo/actions/runs/41574412835) **SUCCESS**.
- Los controles automáticos incluyen validación de catálogo, carga headless del editor, modelo, runtime, Ready/Timer, regresiones editoriales y tests focales de estados. **Los SUCCESS se refieren a los commits concretos citados**, no a un release integrado en `main`.

## Alcance de la aprobación técnica

| Aspecto | Veredicto |
| --- | --- |
| Registro dinámico, consulta, activación y retirada por máquina desde plantillas del grafo | **PASS automatizado** |
| IDs, validación, cuota 128, datos desacoplados y aislamiento `PVController` | **PASS automatizado** |
| Alias activos con fallback y purga selectiva de solicitudes | **PASS automatizado** |
| SDK/capacidad de bloques FSM y caducidad del acceso | **PASS automatizado** |
| Políticas `EPHEMERAL`, `SESSION`, `PERSISTENT`; reset/stop y snapshots como compatibilidad | **PASS automatizado** en frontera 8D2 |
| Determinismo multicontrolador, colas y protecciones de reentrancia comprobadas | **PASS automatizado** en escenarios acotados |
| Aceptación visual/interacción en Fedora y Android | **PENDING 0/25** |
| Integración en `main`, tag, release estable | **NO AUTORIZADOS / NO EJECUTADOS** |
| Cierre FSM-004: persistencia en archivo, `user://`, backups y migraciones | **FUERA DE ALCANCE; fase 9 pendiente** |

La diferencia de redacción entre el plan histórico («límite configurable») y el contrato efectivo (**cuota fija de 128 por máquina**) permanece como una decisión futura, no como defecto reproducido o permiso para reescribir el runtime.

## Condiciones pendientes y límites

1. Las **25 pruebas humanas** de [7F-2](fsm_phase7_7f2_manual_acceptance_matrix.md) están expresamente **diferidas por el mantenedor**: 15 Fedora y 10 Android. No se ejecutó ninguna de ellas ni cabe registrar `manual_approved` como sustituto. Las pruebas headless no acreditan usabilidad, selección visual, teclado, orientación móvil ni persistencia en el editor real.
2. Los estados `manual_pending`, `not_run` y `not_covered` de otras áreas del catálogo permanecen intactos. La auditoría de 8E-2 verificó el subconjunto automático Potok, **no** afirmó que todos los 92 registros fueran PASS.
3. No se midieron rendimiento, seguridad universal frente a GDScript adversarial, ni todas las intercalaciones de callbacks. No se ejecutó Godot local, y consultar las fuentes de `flujo-baseline` / `flujo-prove` no es invocación formal de esas Skills.
4. Solo se trabajó en la rama `feature/fsm-runtime-flow-flusso`; `main` y las escenas de demostración no se editaron. **Este dictamen no autoriza la integración ni publicación**; requieren conformidad y pruebas aplicables.
5. **8E-3 es documental** y se basa en CI previamente verificado. El CI de su commit debe comprobarse por separado antes de afirmar que el checkpoint nuevo también tiene SUCCESS.

## Decisión y continuidad

**Declaración aprobada para la hoja de proyecto:** «Potok / fase 8 / FLU-FSM-003: implementación y validación técnica automatizada completas sobre la rama de trabajo; aceptación manual 25/25 diferida; integración y publicación no autorizadas; fase 9 independiente».

**Siguiente 8E-4:** preparar hoja de continuidad de FSM-004, con microbloques recuperables y auditoría de lo ya existente: snapshots versionados, serialización persistente, rutas `user://`, escritura segura con backup, lectura, corrupción, preflight, estabilidad del esquema, múltiples controladores y recuperación de datos. No asumir Fase 9 terminada porque exista `FlowFSMSnapshotCodec` o pruebas adyacentes de 8D2. Primero verificar contratos, archivos y base CI; después crear pruebas focales solo donde falte evidencia.

*Todo es Flujo; todo fluye.* 🌊
