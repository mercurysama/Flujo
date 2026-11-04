# Potok 10B-0B — Baseline de preparación y estado del gate formal

**Fecha:** 2026-11-03. **Rama:** `feature/fsm-runtime-flow-flusso`, base `3ae1ec0d31e4a276f611427535b7a26375ae0d25`. **Alcance:** futuro DEBUG-FSM core, capturas opt-in y consultas inertes. **Resultado del gate:** `BLOCKED` para cambios de producción por no poder invocar formalmente `$flujo-baseline` con un checkout local Godot 4.7.2 en esta sesión. **NO** se presenta como `READY` ni `PASA`.

## 1. Baselines existentes mapeados

| Frontera | Comportamiento del catálogo | Focal actual | Evidencia remota (histórica) |
|---|---|---|---|
| Señales, identidades, dos controladores | `FLUJO-BHV-POTOK-OBSERVABILITY-EXISTING-001` = `passing` | `tests/runtime/flow_fsm_observability_existing_signals_test.tscn` | [CI 41766684034](https://github.com/mercurysama/Flujo/actions/runs/41766684034) SUCCESS del checkout `796b09c406abea5b2c8a5997ed7ae2ad97fcf75a` |
| Condición false, self/no-op y ganador | `FLUJO-BHV-POTOK-OBSERVABILITY-CONDITIONS-002` = `passing` | `tests/runtime/flow_fsm_observability_conditions_test.tscn` | Mismo CI, focal específica `success` |
| Ciclo de vida, reentrancia y reloj | `FLUJO-BHV-POTOK-OBSERVABILITY-LIFECYCLE-003` = `passing` | `tests/runtime/flow_fsm_observability_lifecycle_test.tscn` | Mismo CI, focal específica `success` |
| API de depurador de Godot (editor, no núcleo) | `FLUJO-BHV-POTOK-EDITOR-DEBUGGER-API-PROBE-004` = `passing` | `tests/editor/flow_fsm_debugger_classdb_probe.gd` | Mismo CI, ClassDB exitoso; **no** transporte funcional |

Las pruebas de `FSM-5A/5B/5C/5D/5E/5F/5G`, Ready, Timer, clocks y snapshot FSM-004 son límites colindantes del runtime. Su suite integral se ejecutó con el workflow CI anterior; **no se invoca aquí una copia local**. La interpretación de `passing` es evidencia histórica de comportamiento observado, no la afirmación de nuevas APIs.

## 2. Qué falta en esta sesión para completar `$flujo-baseline`

La Skill versionada `tools/agent_skills/flujo-baseline/SKILL.md` exige invocación formal con acceso al checkout, HEAD, índice, árbol de trabajo y ejecutor local seleccionado (Godot nativo, `flatpak-spawn` o Flatpak) identificado como 4.7.2. En esta sesión se dispone del **conector GitHub**, no del checkout de Fedora del usuario ni de un ejecutor Godot local 4.7.2. El contenedor de trabajo no expone `godot` en PATH; por ello no se ejecutaron comandos locales, no hay salida de tests propios de este nuevo HEAD ni una certificación independiente de cambios sin confirmar.

- `git diff --check` **local**: NOT RUN; CI previo sí comprobó HEAD anterior.
- Validador del catálogo canónico **local**: NOT RUN; CI anterior comprobó el validador.
- `godot --headless --editor --path . --quit-after 5` **local**: NOT RUN; CI anterior comprobó carga del editor.
- `godot --headless --path . tests/model/flow_model_smoke_test.tscn` **local**: NOT RUN; CI anterior comprobó modelo.
- Focales runtime 10A-3/4/5 **en checkout local**: NOT RUN; CI anterior las pasó.
- Revisión humana Fedora (15) y Android (10): **0/25**, intencionalmente diferida.

**No es un error de Potok.** Es una ausencia del entorno de verificación exigido. Dos fallos de recurso no ocurrieron; no corresponde forzar reintentos ni falsificar ejecutor. Se prohíbe denominar `READY` a un PASS de CI histórico sin completar la invocación formal.

## 3. Estado nuevo versus regresión existente

**Comportamiento nuevo aún no presente:** `set_debug_capture_enabled`, lectura de trace, snapshot de debugger, anillo 128 y sanitización 1024 bytes, secuencia/epoch y captura de arbitraje. No hay catalogación `passing` para estas capacidades. El contrato G1–G6 se delimita en [10B-0A](fsm_phase10_10b0a_authorization_scope.md), con la autorización contextual y su límite de ratificación.

**Próxima tarea permitida sin cambio productivo:** preparar fixture test-only RED aislada (10B-1A) y documento con invocación precisa; NO agregar esa escena al workflow obligatorio ni afirmar que RED fue ejecutado si no lo fue. Para GREEN productivo, recuperar acceso a ejecutor Godot 4.7.2 y completar Skills formales antes y después; alternativamente un mantenedor autorizado puede ejecutarlas en Fedora y remitir logs con el SHA correspondiente.

## 4. Razón técnica, alternativas y métricas

Se eligió **detener producción** en vez de sustituir las Skills por una inferencia del CI o introducir un registro con efectos desconocidos. Esto protege la separación editor/runtime, el `FlowGraph` inmutable, la semántica FIFO/prioridad, la privacidad, las garantías de snapshot y los estados legacy. El coste de captura, memoria, latencia y overhead permanecen **not measured**. `main` no se toca, sin merge ni release.

**Dictamen del microbloque:** preparación de baseline documentada; `$flujo-baseline = BLOCKED` para producción desde este entorno; CI del documento se verifica aparte. `$flujo-prove = NOT RUN`, porque no se ha implementado ningún cambio productivo.

*Todo es Flujo; todo fluye.* 🌊
