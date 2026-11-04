# Potok 10B-1A — Focal RED aislada y no habilitada en CI obligatorio

**Fecha:** 2026-11-03. **Rama:** `feature/fsm-runtime-flow-flusso`; **base:** `94a78eb8d13b3f3eb1f8da3359454a9cd3b3ac93`. **Estado:** **FIXTURE PREPARADA, NO EJECUTADA (NOT RUN)**. No se llama a esta escena desde `.github/workflows/flujo-fsm.yml`; no se considera éxito de nuevo comportamiento ni fracaso del proyecto.

## Preparación de RED

Se creó `tests/runtime/flow_fsm_debug_trace_red_test.tscn` con `tests/runtime/flow_fsm_debug_trace_red_test.gd`. La fixture construye un `FlowGraph` esquema 3 válido con una máquina MANUAL, arranca un `PVController` propio y, antes de exigir el resto del contrato, verifica que se hayan introducido las APIs candidatas `set_debug_capture_enabled`, `get_debug_records` y `get_debug_snapshot`.

**Resultado esperado en el código actual:** la focal produciría RED por **métodos ausentes**, pero **NO SE HA EJECUTADO** y no se inventa código de salida ni log. Si en el futuro esas APIs existen, la misma fixture caracteriza captura OFF por defecto, activación explícita, anillo de 128 filas, límites de 1024 bytes UTF-8 JSON, secuencia creciente, ausencia de payload arbitrario y preservación del estado authored. La forma exacta de `get_debug_snapshot()` debe congelarse antes de reclamar GREEN.

## Cómo obtener evidencia sin debilitar la suite

1. En un checkout local autorizado con Godot 4.7.2 y Skills formales, ejecutar `$flujo-baseline` y guardar sus resultados.
2. Ejecutar **fuera** del gate obligatorio: `godot --headless --path . tests/runtime/flow_fsm_debug_trace_red_test.tscn`; registrar salida/código de salida y el SHA test-only. El *fallo esperado por API ausente* no se debe reinterpretar como un PASS del comportamiento nuevo.
3. Implementar luego GREEN de forma mínima y autorizada, manteniendo el catálogo `not_run` hasta que la focal y CI real pasen. Sólo entonces añadir la escena a CI obligatorio y actualizar su estado siguiendo `docs/development_workflow.md`.
4. Invocar `$flujo-prove` formal, revisar regresiones FSM-5 y 10A-3/4/5, schema 3/4, Ready/Timer, presupuesto y snapshot. No se puede inventar aprobación humana 0/25.

## Catálogo y trazabilidad

Entrada **`FLUJO-BHV-POTOK-DEBUG-TRACE-CORE-005`**, cobertura `automatic` planeada y `baseline_status=not_run`, con el path de la fixture. Esto indica que la prueba existe como artefacto, **no** que ya se ejecutó o que la funcionalidad esté implementada. Si el gate de catalogación exige una categoría distinta para RED preparado, se debe documentar su resultado antes de cambiar la entrada; no usar `passing`.

**Siguiente corte:** el ejecutor/Skill formal sigue BLOCKED en este entorno GitHub-only; la implementación de producción `10B-1B` se mantiene detenida. La aprobación conversacional contextual G1–G6 está delimitada en [10B-0A](fsm_phase10_10b0a_authorization_scope.md).

*Todo es Flujo; todo fluye.* 🌊
