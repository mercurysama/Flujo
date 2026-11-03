# Potok 8E-4 — Inventario FSM-004 y hoja de continuidad recuperable para fase 9

**Fecha:** 2026-11-03 (America/Mexico_City). **Rama exclusiva:** `feature/fsm-runtime-flow-flusso`. **Tipo:** auditoría y planificación documental, **sin reimplementar ni modificar el runtime existente**. **Fase 8:** cierre técnico automatizado condicionado registrado en [8E-3](fsm_phase8_8e3_conditional_technical_acceptance.md); **25 manuales pendientes**. **Fase 9:** todavía **NO iniciada como implementación nueva, NO cerrada**.

## Baseline y contratos que no deben reinventarse

**Norma:** [FLU-FSM-004](fsm_snapshot_contract_v1.md), objetivo del [plan de 12 fases](fsm_implementation_plan.md), con validación y persistencia seguras de la instancia FSM, evitando referencias corruptas, scripts ejecutables y modificaciones de `FlowGraph`. Se respeta [FLU-FSM-003](fsm_dynamic_contract_v1.md) y la cobertura de vida/restore de [8D2-C1](fsm_phase8_8d2c1_traceability_audit.md).

**Implementación ya presente inspeccionada:**
- `addons/vp_flujo/runtime/flow_fsm_snapshot_codec.gd`: `FlowFSMSnapshotCodec.FORMAT_VERSION = 1`, `make_snapshot`, `prepare`, orden de máquinas authored y registros por máquina, validación de versión, identidad de grafo y esquema, IDs, plantillas, cuota y datos JSON-safe, construcción de candidato desacoplado.
- `addons/vp_flujo/runtime/flow_fsm_runtime.gd`: `export_snapshot`, `restore_snapshot` con preflight, todos los Exit antes de publicar, sustitución de estado/registro, limpieza de solicitudes y todos los Enter después; bloqueo durante `_in_tick`. `save_to_file`, `restore_from_file` y `_snapshot_path_allowed`: rutas `user://*.json` filtradas, archivo temporal `.tmp`, lectura de verificación, copia `.bak`, `rename_absolute` y recuperación de respaldo ante error, parseo JSON y preflight.
- `tests/runtime/flow_fsm_snapshot_test.gd` y escena `.tscn` **ya existentes**: tres lifetimes, snapshot portable, versión inválida/plantilla desconocida/dato Object, reset, restauración, dos guardados, existencia de `.bak`, rechazo de `res://` y traversal, segundo controlador, y corrupción de JSON sin publicar cambios. El gate del workflow `FSM snapshot focal (when present)` es **condicional**; debe revisarse su obligatoriedad según contrato de fase 9.
- 8D2 aportó dos pruebas de snapshot adicionales con gate obligatorio: `tests/runtime/flow_fsm_snapshot_transient_active_test.tscn` (EPHEMERAL/SESSION activos recuperan inicial authored y PERSISTENT conserva alias y datos) y `tests/runtime/flow_fsm_snapshot_preflight_atomicity_test.tscn` (23 rechazos atómicos, restauración válida posterior). 8D2-B3B2/B3B3 añadió orden global de callbacks y reentrancia, sin cambiar codec.

**Evidencia verificada:** cierre de 8D2 [Actions 41594048021](https://github.com/mercurysama/Flujo/actions/runs/41594048021) **SUCCESS**; auditorías 8E-1 [41594476054](https://github.com/mercurysama/Flujo/actions/runs/41594476054) y 8E-2 [41595172497](https://github.com/mercurysama/Flujo/actions/runs/41595172497), con sus checkpoints [41594515152](https://github.com/mercurysama/Flujo/actions/runs/41594515152) y [41595220445](https://github.com/mercurysama/Flujo/actions/runs/41595220445), **SUCCESS**. Los [Actions 41612296707](https://github.com/mercurysama/Flujo/actions/runs/41612296707) y [41612358115](https://github.com/mercurysama/Flujo/actions/runs/41612358115) de 8E-3 seguían en curso durante esta auditoría: **no atribuirles PASS sin comprobar finalización**.

## Cobertura y riesgos por caracterizar: no declarar RED sin reproducir

| Área | Evidencia actual | Brecha verificable para fase 9 |
| --- | --- | --- |
| Políticas de vida | 8D2 B1/B2 y `flow_fsm_snapshot_test.tscn` | Reabrir escenario de nuevo runtime real y restauración explícita desde archivo, sin afirmar que PERSISTENT se auto-carga |
| Formato y orden | Codec v1; snapshots portables y deterministas en 8D2-B2A | Probar salida JSON de disco, reexportación idéntica y límites bajo carga; preservar `format_version=1` |
| Datos seguros | `FlowFSMDataValidator` y 23 rechazos B2B | Probar frente a JSON corrupto o demasiado grande leído de disco; sin ejecución de objetos/Callables |
| Escritura, reemplazo y respaldo | Un guardado, segundo guardado y existencia de backup en test base | **No está demostrado** que `.bak` conserve *el contenido anterior válido*, ni qué ocurre con fallos antes/después de borrar o copiar backup y durante `rename_absolute`. El código actualmente elimina un `.bak` anterior antes de copiar el destino actual; catalogar riesgo de pérdida de respaldo en error intermedio, **sin declarar defecto confirmado** |
| Atomicidad/recuperación | Temporal verificado y fallback con `rename_absolute` | En algunas plataformas se elimina el destino previo si falla reemplazo directo; caracterizar integridad ante condiciones representables en pruebas, sin provocar daños externos |
| Rutas `user://` | `_snapshot_path_allowed` rechaza `res://`, `..`, barras invertidas y extensión incorrecta | Matriz de rutas vacías, subcarpetas, unicode, dobles barras y compatibilidad multiplataforma; no relajar seguridad |
| Lectura y restauración | `restore_from_file` parsea JSON y delega a `restore_snapshot`; test de corrupción | Probar fuente faltante, texto excesivo, esquema/versiones incompatibles, múltiples controladores; asegurar no mutación de cola/alias ante error |
| Callbacks/ticks | 8D2-B3B2/B3B3 y FLU-FSM-004 | Distinguir restore `Exit(A), Exit(B), Enter(A), Enter(B)` de reset `Exit(A), Enter(A), Exit(B), Enter(B)`; no activar acciones durante tick |
| Evolución de esquema | Formato actual v1 y rechazo de mismatch `graph_id/schema_version` | Formalizar rechazo y diagnóstico al cambiar grafo; **no** inventar migración, ID por nombre o estrategia implícita |
| CI/gobernanza | Workflow Godot 4.7.2 con snapshot focal condicional y 8D2 obligatorios | Convertir el caso FSM-004 base en gate no opcional **solo si el plan/contrato lo requiere**, registrando cambio separado; cada nueva prueba debe tener catálogo `not_run` antes de PASS |

**Límite importante:** el texto de plan fase 9 ofrece algunos campos futuros como `controller_instance_key` o `started/paused`, pero **el contrato v1 vigente no los exige**. No alterar el formato sin propuesta y migración aprobadas. El plan pregunta por `SESSION` tras recarga de escena; el contrato actual define persistencia únicamente dentro de una instancia en ejecución y eliminación al teardown, salvo redefinición explícita del mantenedor.

## Microbloques de fase 9 — ejecución independiente y recuperable

| Paso | Objetivo mínimo | Aceptación/evidencia |
| --- | --- | --- |
| **9A1** | Auditar requisitos `FSM-R20–R22`, codec y lifecycle `FLU-FSM-004` contra tests existentes; registrar matrices de formatos/rutas/backup | Documento sin código, baseline GitHub CI **SUCCESS** e inventario de brechas exacto |
| **9A2** | Congelar alcance de formato v1, política SESSION y backup; identificar decisiones abiertas sin mutar producción | Contrato confirmado por mantenedor; si requiere cambios públicos, plan/versionado/migración antes de implementación |
| **9B1** | Caracterizar guardado `user://` y segundo guardado: contenidos de destino `S2` y backup `S1` con datos distintos | Nueva focal `.gd/.tscn`, behavior `not_run` y gate obligatorio; CI full SUCCESS antes de `passing` |
| **9B2** | Matriz de rutas de escritura/lectura, extensión, traversal, fallo temprano y ausencia de efectos fuera de `user://` | Focal segura bajo `user://flujo_fsm_tests/` y limpieza; no escritura a paths externos |
| **9B3** | Recuperación de guardados, errores controlados al copiar/renombrar y preservación de `.bak`, evitando simulaciones destructivas del entorno | Probar casos realmente reproducibles; si hay RED, registrar logs y corregir **solo** con autorización de contrato y Skills formales |
| **9C1** | `restore_from_file`: archivo ausente, texto inválido/corrupto, exceso de tamaño y versión/esquema ajenos | Rechazos no mutan colas ni callback traces; mantener snapshot válido posterior |
| **9C2** | Guardar en una instancia, reconstruir controlador y restaurar el PERSISTENT autorizado; EPHEMERAL/SESSION no resurgen; segundo controlador aislado | Identidad/orden/datos exactos, una sola secuencia Enter, grafo intacto |
| **9C3** | Callbacks de restore y guarda `_in_tick` bajo entradas acotadas, con reexportación estable | No reentrancia ni doble commit; sin bucles no acotados |
| **9D1** | Compatibilidad v1, rechazo explícito a grafo cambiado/versión futura y diagnóstico, sin migraciones implícitas | Rechazo atómico verificado; si se aprueba migración, plan separado |
| **9D2** | Auditoría final requisito → runtime/codec → catálogo → escena → commit → Actions | Todas las puertas obligatorias completas, fallos históricos registrados |
| **9E1** | Consolidación y dictamen automatizado de fase 9, sin confundir con aceptación humana | Documento de aceptación condicionada y handoff a fase 10 |

**Regla por microbloque:** uno o pocos archivos, commits atómicos, no tocar `main`; primero escena/test con comportamiento caracterizado, catálogo `baseline_status="not_run"`, gate obligatorio; Godot 4.7.2 full CI; solo marcar `passing` después de `SUCCESS` integral; reporte y `docs/fsm_iteration_01_learning.md`. Si no hay nuevo comportamiento, hacer solo auditoría/documentación y evitar pruebas duplicadas.

## Condiciones de entrega y recuperación

- **Próximo turno 9A1**, **no 9B1**: confirmar HEAD, la rama y Actions; leer `AGENTS.md`, `docs/constitution.md`, `docs/development_workflow.md`, este documento, contrato FSM-004, codec, `FlowFSMRuntime`, pruebas snapshot y `docs/current_iteration.md`. Auditar diferencias reales antes de desarrollar.
- **Skills:** `tools/agent_skills/flujo-baseline/SKILL.md` y `flujo-prove/SKILL.md` son reglas versionadas, no implican ejecución formal en este entorno. Para cualquier implementación/corrección funcional, respetar sus puertas o documentar explícitamente la imposibilidad, sin afirmar equivalencia entre lectura y ejecución.
- **25 pruebas visuales** heredadas (15 Fedora, 10 Android) permanecen diferidas; no hacen parte de la aprobación CI. Ningún resultado local de Godot está disponible. No merge, release ni cambios a `main`.

*Todo es Flujo; todo fluye.* 🌊
