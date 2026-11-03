# Potok 8D2-C2 — Conciliación de evidencia y cierre técnico de 8D2

**Fecha:** 2026-11-03 (America/Mexico_City). **Rama:** `feature/fsm-runtime-flow-flusso`. **Dictamen:** **8D2 CERRADO TÉCNICAMENTE** para las condiciones automatizadas previstas; aceptación humana y cierre de fase 8 **NO** realizados. Documento de auditoría, sin modificación productiva.

## Cadena de evidencia

1. [8D2-A inventario](fsm_phase8_8d2a_audit.md): baseline [41575182608](https://github.com/mercurysama/Flujo/actions/runs/41575182608) **SUCCESS**; contratos `FLU-FSM-003`, compatibilidad `FLU-FSM-004`, riesgos y pruebas faltantes identificados.
2. **8D2-B1:** matriz de tres lifetimes ante `reset()` y `stop()` con controladores aislados. [41576973539](https://github.com/mercurysama/Flujo/actions/runs/41576973539) y [41578192657](https://github.com/mercurysama/Flujo/actions/runs/41578192657), ambos **SUCCESS**.
3. **8D2-B2:** serialización de alias persistentes, fallback authored para activos transitorios, reexportación estable, 23 rechazos preflight atómicos y posterior restore válido. [41579446980](https://github.com/mercurysama/Flujo/actions/runs/41579446980) y [41582200667](https://github.com/mercurysama/Flujo/actions/runs/41582200667), ambos **SUCCESS**. Se prueba frontera con FSM-004, no cierre de fase 9.
4. **8D2-B3A:** cuatro pruebas de determinismo multicontrolador, orden authored, eventos con presupuesto 32, callbacks y reset dinámico; [auditoría B3A5](fsm_phase8_8d2b3a5_audit.md), cuatro CI integrales **SUCCESS**, incluido [41589766004](https://github.com/mercurysama/Flujo/actions/runs/41589766004) para B3A4. La ejecución [41589653144](https://github.com/mercurysama/Flujo/actions/runs/41589653144) falló por una expectativa de test equivocada sobre el orden de `reset()`; la corrección fue solo en el test.
5. **8D2-B3B:** reset con `Exit→Enter` por máquina, restore con todos los `Exit` antes de los `Enter`, guardas de `_in_tick`, rechazo de tick anidado, descarte de cola local, segundo controlador intacto; [auditoría B3B4](fsm_phase8_8d2b3b4_audit.md). [41590902774](https://github.com/mercurysama/Flujo/actions/runs/41590902774), [41591954025](https://github.com/mercurysama/Flujo/actions/runs/41591954025) y [41592345621](https://github.com/mercurysama/Flujo/actions/runs/41592345621) **SUCCESS**.
6. [8D2-C1 trazabilidad](fsm_phase8_8d2c1_traceability_audit.md): once `FLUJO-BHV-POTOK-*` de 8D2 en `docs/behavior_catalog.json`, todos `passing`, cada uno ligado a su escena y gate obligatorio en `.github/workflows/flujo-fsm.yml`; implementaciones `FlowFSMRuntime` y `FlowFSMSnapshotCodec` inspeccionadas, sin cambios. [41593493271](https://github.com/mercurysama/Flujo/actions/runs/41593493271) **SUCCESS** de auditoría C1. [41593197556](https://github.com/mercurysama/Flujo/actions/runs/41593197556) **SUCCESS** de checkpoint B3B4. La ejecución del checkpoint documental C1 [41593585836](https://github.com/mercurysama/Flujo/actions/runs/41593585836) seguía en curso al iniciar la revisión C2: no se atribuye un resultado definitivo que aún no había sido comprobado.

## Conciliación de contratos y políticas

| Frontera | EPHEMERAL | SESSION | PERSISTENT |
| --- | --- | --- | --- |
| `reset()` | Se elimina | Conserva ID/datos | Conserva ID/datos |
| `stop()` + instancia nueva | Se elimina | Se elimina | Se elimina, salvo restauración explícita posterior |
| `export_snapshot()` | No se guarda | No se guarda | Se incluye; conserva ID/datos permitidos |
| Estado activo no persistente en snapshot | Fallback a inicial authored | Fallback a inicial authored | No corresponde; ID persistente recuperable |
| `restore_snapshot()` válido | No recupera alias omitido | No recupera alias omitido | Restaura solo registros autorizados; reemplaza cola y registro local |
| `restore_snapshot()` inválido | Sin cambios | Sin cambios | Sin cambios |

Estas reglas son la semántica observada en los contratos y pruebas actuales. `PERSISTENT` significa elegible para snapshot, **no** almacenamiento automático entre ejecuciones. No hubo cambios en codec, formato o versionado.

## Decisión C2 y límites

- **Aprobado:** trazabilidad requisitos → implementación → catálogo → escenas → gates → CI verde de los once escenarios de 8D2. **El cierre técnico de 8D2 queda asentado por esa evidencia**; no hace falta inventar nueva funcionalidad para esta subfase.
- **No aprobado ni declarado:** cierre integral de fase 8, validación manual, pruebas de rendimiento, seguridad frente a callbacks maliciosos arbitrarios, cobertura exhaustiva de todas las intercalaciones, ni aceptación de fase 9. No hay evidencia local de Godot; las skills del repositorio no fueron invocadas formalmente.
- **Pendientes humanos:** 15 Fedora + 10 Android = **25 manuales**, aplazados por instrucción del mantenedor. No bloquean el avance documental a 8E, pero sí impiden afirmar aceptación visual final.
- **Control de cambios:** se conserva rama `feature/fsm-runtime-flow-flusso`; no modificar `main`, no hacer merge, no tocar editor, Ready/Timer, `demo/main.tscn` o la infraestructura de la fase 9. Este checkpoint es solo documentación.

## Traspaso recuperable a 8E

- **8E-1:** revisar criterio de cierre `FLU-FSM-003` y mapear los tests de 8A, 8B, 8C, 8D1 y 8D2 a APIs actuales; separar evidencia objetiva de las 25 visuales aplazadas.
- **8E-2:** catálogo/CI final de fase 8 y verificación de `AGENTS.md`, constitución, política de versiones y no regresión, sin reimplementar pruebas ya existentes.
- **8E-3:** documento de aceptación técnica **condicionada**: fase 8 automatizada cerrada solo si todo lo obligatorio está verde; pruebas humanas expresamente pendientes, sin afirmar release estable.
- **8E-4:** hoja de continuidad para la fase 9 FSM-004 (persistencia, archivos `user://`, backups, validación e integridad), con límites claros de alcance y microbloques recuperables. No implementar fase 9 prematuramente.

El nuevo commit documental de C2 debe verificar su propio GitHub Actions antes de afirmar que ese último checkpoint está aprobado; **no invalida** los SUCCESS precedentes.

*Todo es Flujo; todo fluye.* 🌊
