# Potok 9E1-A — Dictamen técnico condicionado de fase 9 / FSM-004

**Fecha:** 2026-11-03 (America/Mexico_City). **Rama:** `feature/fsm-runtime-flow-flusso`. **Tipo:** dictamen de evidencia, **no aceptación incondicional, cierre global, merge, release ni modificación de contrato**.

## Resultado verificable

- [Auditoría 9D2-A](fsm_phase9_9d2a_coverage_risk_audit.md), [Actions 41712521737](https://github.com/mercurysama/Flujo/actions/runs/41712521737) y [checkpoint 41712607299](https://github.com/mercurysama/Flujo/actions/runs/41712607299): ambos **completed SUCCESS** en Godot 4.7.2. La implementación fase 9 parte del contrato existente [FLU-FSM-004](fsm_snapshot_contract_v1.md), sin reconstruir el codec ni modificar schema.
- La última suite con nueva focal implementada fue [Actions 41711670098](https://github.com/mercurysama/Flujo/actions/runs/41711670098), **109/109 pasos completed SUCCESS**. El catálogo tiene **100 comportamientos**; los **8 nuevos 012–019** de fase 9 aparecen en `passing`, cada uno con gate de escena incondicional. La prueba FSM-004 original también es un gate obligatorio.
- Cobertura positiva: S1/S2 y backup anterior, rutas seguras, fallo F3 al crear directorio, archivo ausente/corrupto/excesivo, preflight de esquema y IDs, controlador realmente destruido y recreado en el mismo proceso, recuperación explícita de PERSISTENT, exclusión de SESSION, callbacks de disco, aislamiento y reentrancia.

## Dictamen

**Aceptación técnica automatizada: CONDICIONADA**, circunscrita a los comportamientos con evidencia y escenas focales. **Fase 9 no está cerrada incondicionalmente**: el criterio del [plan de 12 fases](fsm_implementation_plan.md) pide demostrar recuperación al volver a iniciar el *juego*, no solo crear un nuevo controlador. Se ha probado restauración manual tras `queue_free` dentro del mismo proceso del motor, que es evidencia distinta.

La durabilidad bajo errores intermedios `F5–F7/F7R` también permanece **no verificada**: la secuencia actual elimina un `.bak` previo antes de reemplazarlo y contempla borrar `main` antes de reintentar rename. Son **riesgos observados al revisar código**, no defectos reproducidos. Los casos F9 (destino previamente corrupto) y política de recuperación explícita/automática requieren decisión del mantenedor; **no añadir autoload ni recuperación automática** sin cambiar contrato autorizado.

## Barreras y decisiones

| Elemento | Estado hoy | Condición para un dictamen de cierre más amplio |
| --- | --- | --- |
| Ocho pruebas de fase 9 012–019 | **8/8 passing** por CI | Mantener gate y revalidar todos los cambios nuevos |
| Recreación de controlador en proceso vivo | PASS | Probar **dos lanzamientos separados de Godot/juego** con archivo persistente en el mismo `user://` |
| F5–F7/F7R copia, backup, rename y rollback | **NO RUN** | Acordar protección del último backup, implementar seam/fault-test formalmente autorizado o prueba real segura, comprobar errores exactos |
| F9 destino corrupto previo | **POLÍTICA ABIERTA** | Elegir explícitamente rechazo o preservación de bytes; no inferir backup válido |
| F10 recuperación desde `.bak` | No automática actualmente | Mantener v1 o aprobar nueva política explícita; no introducirla silenciosamente |
| Visuales y plataformas reales | **0/25** (15 Fedora + 10 Android), aplazadas | Ejecutar en sesión humana posterior, sin falsos PASS |
| Integración / publicación | No aprobada | Decisión humana, gobernanza y trazabilidad de Git; ninguna operación en `main` |

## Límites de confianza

La suite GitHub Actions headless Linux prueba únicamente su runner y las escenas enumeradas. **No prueba** cortes de alimentación, atomicidad física, comportamiento de chmod/symlinks en Android, durabilidad del almacenamiento real ni reinicio completo. No existe una invocación formal acreditada de `$flujo-baseline` y `$flujo-prove` en esta sesión: leerlas no es ejecutarlas. Tiempos, tasa de pérdida y métricas de disco: **no medidos**.

**Decisión 9E1-A:** preservar el avance automatizado y declarar fase 9 **técnicamente avanzada, con aceptación condicionada**, sin cerrarla o lanzar una release. **Siguiente 9E1-B:** contrato de prueba en dos procesos y matriz de pendientes reproducible, sin alterar runtime. **9E1-C:** checkpoint de continuidad, con prioridades y límites de alcance para quien retome el trabajo.

*Todo es Flujo; todo fluye.* 🌊
