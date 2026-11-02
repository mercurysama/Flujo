# Potok 7E-4B — Contrato de consolidación y auditoría de fase 7

**Fecha:** 2026-11-02. **Rama:** `feature/fsm-runtime-flow-flusso`. **Base verificada:** `cbd68a56c762d1f11a51e62f99b436fc53e91ec9`, [CI 41406599140](https://github.com/mercurysama/Flujo/actions/runs/41406599140) **59/59 SUCCESS**.

## Alcance único: auditoría documental, no aceptación manual ni implementación

1. Contrastar individualmente los **nueve** puntos de `docs/fsm_implementation_plan.md` (Fase 7) con recursos reales, rutas de edición y tests presentes **en este HEAD**, separando `CUBIERTO_AUTOMATICO`, `PARCIAL`, `FALTANTE_CONFIRMADO` y `PENDIENTE_MANUAL`. Una CI verde no cambia una casilla manual.
2. Consolidar **las 15 pruebas Fedora F01–F15 y 10 Android A01–A10** de `docs/fsm_phase7_7e4a_manual_review.md` como registro de recepción vacío (sin capturas nuevas): todas `PENDING`; especificar campos para evidencias/fecha/SHA/observador y triage cuando lleguen resultados reales.
3. Auditar con prioridad crítica el escenario uno→dos estados desde la **interfaz existente**, incluyendo crear máquina en Inspector, añadir estados, ver Enter/Update/Exit, **añadir/editar/mover/eliminar bloques en cada fase**, condiciones, transición y ejecución. **Distinguir proyección de bloques de comandos de autoría**.
4. Registrar la brecha confirmada de UI de fase: `FlowGraphInspectorProperty._render_potok_state_phases` dibuja `Label` para nombres y bloques; sin botones de fase ni conexiones para crear/editar. `FlowGraphEditorCommands.add_ready_block*` opera sobre Process/Ready y su lista `blocks` — no sirve directamente para Enter/Exit ni acredita flujo Potok. El modelo `FlowStateDefinition` almacena `enter_blocks`, `blocks` (Update) y `exit_blocks`; no modificarlo en este lote.
5. Proponer microbloques independientes y verificables para cubrir la brecha, empezando por contrato de comandos por fase y pruebas de caracterización. Conservar IDs estables, orden y `null` deliberados, UndoRedo atómico, validación previa, catálogos de bloques integrados/externos y aislamiento editor/runtime. Planificar pruebas de interfaz y persistencia, además de revisión humana.
6. No crear ni modificar `addons/`, tests, workflow, modelos, schema, `demo/main.tscn`, `main` ni releases. Solo contrato, auditoría, registro, resultado y documentos de continuidad. La verificación de entrega es la CI normal, `git diff --check` y ausencia de cambios funcionales; no inventar pruebas que no se ejecutaron.
7. Señalar contradicciones/ausencias claramente: un resultado histórico `manual_approved` para el **Fluo anterior** no autoriza aprobación del Potok actual; la ausencia de evidencia manual impide cerrar fase 7. Distinguir defecto de funcionalidad comprobado en fuente de fallo observado en un dispositivo.

## Evidencia / gobernanza

Fuentes: `AGENTS.md`, `docs/constitution.md`, `docs/current_iteration.md`, `docs/development_workflow.md`, `docs/fsm_implementation_plan.md`, `docs/fsm_phase7_microblocks.md`, `docs/fsm_phase7_7e4a_manual_review.md`, scripts `flow_graph_inspector_property.gd`, `flow_graph_editor_commands.gd`, `flow_fsm_editor_projection.gd`, `flow_ready_process_editor.gd` y `flow_state_definition.gd`; catálogo y pruebas de fase 7. Los procedimientos de repositorio `$flujo-baseline`, `$flujo-prove`, `$flujo-fluo-maintenance` sirven como referencia, pero la integración GitHub no ejecuta Skills locales ni inspecciona el índice/worktree Fedora: **no reclamar READY/PASA formal**.

**Definición de terminado 7E-4B:** auditoría de nueve ítems, registro manual 25/25 PENDING, plan de brecha ordenado, resultado y checkpoint documental con CI verde. **La fase 7 no queda cerrada.**

Todo es Flujo; todo fluye. 🌊
