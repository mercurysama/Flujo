# Potok 8E-2 — Auditoría de gobernanza, catálogo y puertas obligatorias

**Fecha:** 2026-11-03 (America/Mexico_City). **Rama exclusiva:** `feature/fsm-runtime-flow-flusso`. **Punto auditado:** `03b90611ae8e98bdf1762a9a53998011981dc251`; [CI 41594515152](https://github.com/mercurysama/Flujo/actions/runs/41594515152) **completed SUCCESS** (checkpoint documental 8E-1), precedido por [41594476054](https://github.com/mercurysama/Flujo/actions/runs/41594476054) **completed SUCCESS** (auditoría 8E-1). **Dictamen:** puerta de gobernanza/técnica de 8E-2 documentalmente conforme a la evidencia consultada; no equivale a aprobación visual, release ni cierre definitivo de fase 8.

## Documentos normativos revisados

- `AGENTS.md`: objetivo Godot **4.7.2**, separación editor/runtime, IDs estables, persistencia de schema, cambios pequeños, trazabilidad y evidencia verificable; `$flujo-baseline` y `$flujo-prove` deben **invocarse explícitamente** cuando correspondan a implementación/corrección. Consultar su texto **no** equivale a invocación formal.
- `docs/constitution.md`: autoridad humana en integración, compatibilidad y privacidad; las pruebas automatizadas no sustituyen las revisiones humanas requeridas.
- `docs/development_workflow.md`: cadena `constitución → especificación → plan → tareas pequeñas → implementación → pruebas → auditoría → revisión visual aplicable → documentación → aprobación de integración`; requerimiento → tarea → artefacto → prueba → commit.
- [Contrato FLU-FSM-003](fsm_dynamic_contract_v1.md) y [auditoría 8E-1](fsm_phase8_8e1_closure_criteria_audit.md): estado dinámico desde plantilla authored de la misma máquina, sin mutar `FlowGraph`; cuota 128 por máquina y ciclo de vida. La variante de límite *configurable* mencionada en el plan histórico no altera el contrato v1 sin nueva decisión.
- `docs/behavior_catalog.json` y `.github/workflows/flujo-fsm.yml`: cobertura y comandos auditables; Godot 4.7.2 instalado y versión verificada, carga del editor, validador de catálogo, modelo, Ready y demás regresiones.

## Verificación del catálogo y workflow

Se inspeccionaron **92 registros** del catálogo completo y sus rutas en el árbol Git del punto auditado. Distribución observada:

| Estado global del catálogo | Número |
| --- | ---: |
| `passing` | 71 |
| `manual_approved` | 5 |
| `manual_pending` | 8 |
| `not_run` | 5 |
| `not_covered` | 3 |
| **Total** | **92** |

**Subconjunto automático Potok:** exactamente **22 entradas** con IDs `FLUJO-BHV-POTOK-*` y `coverage="automatic"`; las 22 tienen `baseline_status="passing"`. **Todos los archivos citados** por sus `test_paths` existen en el árbol Git auditado y **cada ruta aparece** en el workflow. No se observó ninguna ruta automática Potok inexistente, sin mención de gate ni con estado distinto de `passing`. Esto incluye los focos de fase 8 (SDK y once casos 8D2) y parte de la continuidad editor heredada; **no se debe confundir** con 92 entradas aprobadas globalmente.

El workflow contiene **97 pasos con nombre** (más acciones `uses` sin nombre), incluye validación de versión exacta 4.7.2, `git diff --check`, carga del editor, catálogo, modelo, Ready, tests de runtime y editor. La cadena anterior [41594515152](https://github.com/mercurysama/Flujo/actions/runs/41594515152) terminó **SUCCESS**. Se conserva un diagnóstico de parser marcado `continue-on-error: true`: es deliberadamente auxiliar, **no** debe contarse como garantía de parser sin revisar sus logs. También existe `FSM snapshot focal (when present)` condicionado por presencia de archivo; esta prueba tiene su ruta actualmente en el árbol y el job completo pasó, pero el diseño condicional no debe confundirse con una puerta contractual obligatoria independiente. Los 22 casos automáticos Potok auditados tienen cada uno su ruta en workflow y no se apoya su evidencia únicamente en esa focal condicional.

## Protección de alcance y hallazgos

1. **Sin brecha confirmada en las rutas/gates automáticos Potok:** el análisis del catálogo, árbol y YAML no revela focal obligatoria faltante dentro del subconjunto auditado. No es necesario añadir pruebas duplicadas ni modificar runtime/codec para alcanzar 8E-2.
2. **Evidencia acotada:** CI remoto Godot 4.7.2 para casos registrados. No declara ausencia universal de errores, sandbox completo frente a GDScript adversarial, pruebas de rendimiento ni que todos los 92 comportamientos del catálogo estén aprobados.
3. **Visual humana diferida:** 15 pruebas Fedora y 10 Android, **0/25 realizadas**. Registros manuales de otras áreas se respetan conforme a su estado individual; esta auditoría no altera `manual_pending`, `not_run` o `not_covered`.
4. **Separación de fases:** fase 8 `FLU-FSM-003` y fase 9 `FLU-FSM-004` no se fusionan. No modificar rutas `user://`, codec o backup por este cierre de gobernanza.
5. **Skills:** la auditoría documental se efectúa mediante conectores GitHub; las Skills versionadas `flujo-baseline` / `flujo-prove` **no fueron invocadas formalmente**. No se atribuye una certificación formal de Skills; Godot local **NO EJECUTADO**. Otras métricas no se midieron.

## Decisión 8E-2 y traspaso

- **8E-2 auditado, sin modificación de producto y sin necesidad de reparación de gates.** La auditoría queda sujeta al propio CI del commit documental: no declarar ese nuevo run **SUCCESS** antes de verificarlo.
- **Siguiente microbloque 8E-3:** dictamen de cierre técnico condicionado de fase 8 basado en `FLU-FSM-003`, informes 8E-1 y 8E-2 y resultado de Actions. Expresar nítidamente `automatización PASS` frente a `aceptación humana pendiente`; no publicar versión estable ni integrar `main`.
- **Después 8E-4:** continuidad recuperable de fase 9 `FLU-FSM-004` para validación de persistencia, archivos `user://`, escrituras seguras, backups, corrupción y compatibilidad, sin adelantarse a implementaciones.

*Todo es Flujo; todo fluye.* 🌊
