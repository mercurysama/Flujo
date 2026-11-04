# Potok 10A-4 — Condiciones, autotransiciones y señales observables

**Fecha:** 2026-11-03. **Base:** `54575fe4f38370376fa9297bf13709d4fe33cf21`; [tanda anterior](fsm_phase10_10a_tanda1_closeout.md). **Estado inicial:** test focal registrado como `not_run`, a la espera de GitHub Actions del commit. **Sin modificaciones al runtime.**

## Hallazgos de código y pruebas previas

- `tests/runtime/flow_fsm_conditions_test.gd` (FSM-5B) ya prueba una condición falsa de prioridad 100, autotransición booleana verdadera de prioridad 90 y una transición verdadera válida de prioridad 10. Su prueba valida que sólo la tercera cambia de estado, y que un comando directo a estado activo es no-op.
- `FlowFSMRuntime._pick_condition` evalúa condiciones habilitadas tras Update; descarta destinos no válidos/idénticos y acepta sólo `FlowValueResult` exitoso de tipo `TYPE_BOOL` y valor `true`. La priorización conserva orden authored en empate.
- Las señales actuales `state_updated`, `state_exited`, `state_entered` y `transition_committed` sólo muestran el ganador aplicado, y `request_rejected` sólo informa fallos de admisión. **No existe evento público específico para condición false, condición sin ganador, condición no tipada o autotransición sin commit.** No se debe inventar una traza que atribuya una causa ausente.

## Nueva caracterización acotada

`tests/runtime/flow_fsm_observability_conditions_test.tscn` ejercita dos máquinas MANUAL con un mismo grafo: (A) candidata falsa de alta prioridad, autotransición verdadera y candidata verdadera válida; (B) sólo falsa + autotransición. Comprueba secuencia de señales, ganador por ID, ausencia de señales de commit de (B), no-op directo consumido, cola vacía y `FlowGraph` sin modificaciones. **No vuelve a evaluar condiciones** para depuración.

**Riesgo conocido:** `_pick_condition` carece de señal de cada resultado intermedio; una UI no puede explicar literalmente por qué una condición falló sin un cambio contractual futuro y una captura en el mismo cálculo. Cualquier instrumentación debe preservar frecuencia y orden de evaluaciones, no guardar referencias mutables.

**Evidencia:** catálogo `FLUJO-BHV-POTOK-OBSERVABILITY-CONDITIONS-002` en `not_run`; focal obligatoria del workflow. Las pruebas históricas FSM-5B y 10A-3 ya constan como `passing` en el baseline, no constituyen PASS para este nuevo commit. Las Skills `$flujo-baseline`/`$flujo-prove` sólo se consultaron como documentación; **invocación formal local NOT RUN**. Sin aprobación humana.

**Siguiente:** 10A-5 ciclo de vida y relojes; después 10A-6 presupuesto/retención como propuesta. No extender el runtime antes de aprobar 10B.

*Todo es Flujo; todo fluye.* 🌊
