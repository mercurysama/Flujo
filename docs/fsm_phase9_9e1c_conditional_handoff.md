# Potok 9E1-C — Checkpoint recuperable de fase 9 y continuidad FSM-004

**Fecha:** 2026-11-03 (America/Mexico_City). **Rama única:** `feature/fsm-runtime-flow-flusso`. **Naturaleza:** checkpoint de documentación; **no** integración, no cierre total, no aprobación de pruebas humanas.

## Estado consolidado

- Contrato [FLU-FSM-004](fsm_snapshot_contract_v1.md) conserva `format_version=1`, identidad estable `graph_id/schema_version` y lifetimes EPHEMERAL, SESSION, PERSISTENT. No se implementaron autoload ni migración.
- [9D2-A](fsm_phase9_9d2a_coverage_risk_audit.md): inventario de **100 comportamientos**, **8 nuevos 012–019 passing**, todos con focals obligatorios, y suite [Actions 41711670098](https://github.com/mercurysama/Flujo/actions/runs/41711670098) **SUCCESS 109/109**. Checkpoint 9D2-A [41712607299](https://github.com/mercurysama/Flujo/actions/runs/41712607299) **SUCCESS**.
- [9E1-A](fsm_phase9_9e1a_conditional_verdict.md) establece dictamen **técnico automatizado condicionado**: ninguna conclusión de durabilidad ante power loss o fallos no probados. [9E1-B](fsm_phase9_9e1b_restart_acceptance_protocol.md) define la prueba de **dos procesos** Godot, que todavía NO se implementa ni ejecuta.
- F5/F6/F7/F7R (fallo de copia/rename y recuperación) **NO RUN**, F9 (backup del archivo previo corrupto) **sin decisión aprobada**; F10 sin recuperación automática. No se invocan Skills formales ni se modifica runtime/codec/modelo.
- La revisión humana permanece **0/25**: 15 Fedora y 10 Android. Ningún merge a `main`, PR aceptado o release.

## Próximos microbloques ejecutables sin romper contrato

1. **9R1-A:** crear fixture de FlowGraph authored con IDs estables entre procesos; probar por separado `user://` y exportación S1. Registrar nuevo behavior `not_run`, test scripts y gate obligatorio Godot 4.7.2; esta etapa no puede prometer PASS.
2. **9R1-B:** ejecutar el proceso B contra el mismo directorio de usuario, confirmar ausencia de autoload y restauración **explícita** PERSISTENT; CI integral y cierre `passing` solo tras SUCCESS.
3. **9R2-A (solo con autorización expresa):** acordar semántica F5/F7/F9; si se aprueba, baseline/prove formales, diseño del seam aislado y test-first de fallos exactos. No tocar producción o crear un fake que afirme probar operaciones reales antes de esa decisión.
4. **9E1-D:** actualizar dictamen cuando se ejecute R1 y, si procede, R2, diferenciando evidencia de CI y aprobación humana. No adelantar fase 10 automáticamente.

## Reglas para siguiente chat

Leer `AGENTS.md`, `docs/constitution.md`, `docs/development_workflow.md`, `docs/current_iteration.md`, contrato FSM-004 y documentos 9E1-A/B/C. **No empezar de cero**, no reescribir el codec, no alterar IDs/modelo ni `main`. Microbloques pequeños, commits individuales, tests primero, y reportes con SHA, CI final, estado real del catálogo y siguiente tarea. Cualquier CI pendiente se reporta como pendiente, nunca como SUCCESS anticipado. La autorización general para encadenar microbloques **no** habilita nuevos comportamientos de recuperación destructiva.

**Métricas disponibles:** 8/8 nuevos behaviours passing, 109/109 última suite con nueva focal, 0 pruebas F5–F7, 0/25 manuales, 0 pruebas de reinicio de juego en dos procesos. Tiempo de recuperación, durabilidad física y portabilidad Android: no medidos.

*Todo es Flujo; todo fluye.* 🌊
