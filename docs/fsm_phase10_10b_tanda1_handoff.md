# Potok 10B — Checkpoint recuperable de la primera tanda

**Fecha:** 2026-11-03. **Rama:** `feature/fsm-runtime-flow-flusso`. **Base del checkpoint:** `c3ceb157eeec5cbd5f0aa9c557d993c1a2fa321a`. **Estado:** preparación documentada, **ningún cambio productivo 10B**; `main` intacta, sin merge, rebase ni release.

## Tres commits separados

| Microbloque | Commit | Evidencia / estado |
|---|---|---|
| **10B-0A** | `3ae1ec0d31e4a276f611427535b7a26375ae0d25` | [Autorización contextual acotada](fsm_phase10_10b0a_authorization_scope.md); [CI 41767573774](https://github.com/mercurysama/Flujo/actions/runs/41767573774) |
| **10B-0B** | `94a78eb8d13b3f3eb1f8da3359454a9cd3b3ac93` | [Diagnóstico de baseline formal](fsm_phase10_10b0b_baseline_gate_assessment.md); [CI 41767660670](https://github.com/mercurysama/Flujo/actions/runs/41767660670) |
| **10B-1A** | `c3ceb157eeec5cbd5f0aa9c557d993c1a2fa321a` | [Fixture test-only RED](fsm_phase10_10b1a_red_fixture_prepared.md); [CI 41767813828](https://github.com/mercurysama/Flujo/actions/runs/41767813828), test RED **NO EJECUTADO** |

**CI observados al preparar este cierre:** `#41767573774` = `completed/success`, 114 pasos success, sin pasos fallidos hasta ahora; `#41767660670` = `in_progress/pending`, 75 pasos success, sin pasos fallidos hasta ahora; `#41767813828` = `in_progress/pending`, 54 pasos success, sin pasos fallidos hasta ahora. La ausencia de fallo intermedio no equivale a un PASS final. El CI de este nuevo checkpoint debe comprobarse por su propio SHA.

## Distinguir diseño, prueba y producción

- G1..G6: asentimiento contextual a la pregunta concreta sobre **128 registros**, **1024 bytes UTF-8 JSON**, OFF por defecto, polling read-only, semántica y sanitización/estado actual. No se inventa una frase literal de aprobación; la política de ratificación o subcontratos aún pueden exigir claridad adicional.
- G7/G8: **fuera del alcance**; no crear UI de debugger, enlace remoto, edición de variables ni pause/step.
- Fixture `tests/runtime/flow_fsm_debug_trace_red_test.tscn` verifica ausencia de API nueva para RED y después ring/estado; **no es una suite passing y NO se añadió al workflow obligatorio**.
- Catálogo `FLUJO-BHV-POTOK-DEBUG-TRACE-CORE-005` queda `not_run` hasta RED real y GREEN posterior. Las entradas 10A-3/4/5 y 10A-14 conservan PASS histórico para **comportamiento existente**, no DEBUG-FSM completo.
- `$flujo-baseline`: **BLOCKED** en esta sesión GitHub-only por falta de checkout y ejecutor local Godot 4.7.2. `$flujo-prove`: **NOT RUN**, pues no hubo implementación productiva; no afirmar READY ni PASA.
- Revisiones humanas: 0/15 Fedora y 0/10 Android, diferidas. Fase 9: **CONDICIONAL** por F5–F7/F7R y F9/F10; sin cambios a snapshot FSM-004 o autocarga de backup.
- Métricas de costo de ejecución/latencia/memoria de trazas: **not measured**. Ningún nuevo evento debugeado existe en producción.

## Siguiente microbloque real

**10B-1A-VERIFY**: disponer de checkout Godot 4.7.2 y ejecutar formalmente `$flujo-baseline`; luego correr **fuera del CI obligatorio** la fixture `tests/runtime/flow_fsm_debug_trace_red_test.tscn` y registrar fallo esperado, salida exacta y código. Sólo entonces **10B-1B-GREEN**: introducir un mínimo anillo opcional conforme a G1..G6, registrar tests, invocar `$flujo-prove` formal, pasar CI completo y revisar lo aplicable. Si el entorno bloquea Skills, NO modificar `addons/vp_flujo/runtime/` en este flujo ni saltarse el gate por un emoji.

## Razón técnica y alternativas

Se prefirió una prueba aislada test-only frente a (a) meter RED como fallo permanente en el workflow o (b) implementar ciegamente tras un CI histórico. La decisión protege comportamiento legacy, invariantes FIFO/prioridad, dos controladores, no mutar `FlowGraph`, datos de usuario y estabilidad del esquema. La ausencia de ejecución formal se reporta como limitación y no se inventan métricas.

*Todo es Flujo; todo fluye.* 🌊
