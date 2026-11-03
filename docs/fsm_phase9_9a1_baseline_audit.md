# Potok 9A1 — Auditoría de la base FSM-004 y brechas de evidencia en persistencia

**Fecha:** 2026-11-03 (America/Mexico_City). **Rama exclusiva:** `feature/fsm-runtime-flow-flusso`. **Tipo:** inventario técnico y matriz de brechas, sin cambio productivo ni nueva ejecución focal. **Fase 9 NO cerrada.** La fase 8 tiene dictamen técnico automatizado condicionado, con 25 pruebas manuales aún diferidas.

## Baseline y límites

- **HEAD inicial:** `b33c48cdb7d1a2b1e9180281dc1dcea8842f70d1`.
- **CI previo:** [8E-3 dictamen 41612296707](https://github.com/mercurysama/Flujo/actions/runs/41612296707) y [checkpoint 41612358115](https://github.com/mercurysama/Flujo/actions/runs/41612358115) **completed SUCCESS**. Los dos runs documentales de 8E-4, [41612702361](https://github.com/mercurysama/Flujo/actions/runs/41612702361) y [41612764625](https://github.com/mercurysama/Flujo/actions/runs/41612764625), **seguían en curso al verificar**; no se les atribuye SUCCESS anticipadamente.
- **Contrato rector:** [FLU-FSM-004](fsm_snapshot_contract_v1.md) y [plan original de fase 9](fsm_implementation_plan.md), `FSM-R20..R22`; compatibilidad con [FLU-FSM-003](fsm_dynamic_contract_v1.md) y [handoff 8E-4](fsm_phase8_8e4_phase9_handoff.md).
- **Código inspeccionado:** `addons/vp_flujo/runtime/flow_fsm_snapshot_codec.gd` (`make_snapshot`, `prepare`) y `addons/vp_flujo/runtime/flow_fsm_runtime.gd` (`export_snapshot`, `restore_snapshot`, `save_to_file`, `restore_from_file`, `_snapshot_path_allowed`). No se cambia formato o schema.

## Matriz requisito → evidencia → brecha precisa

| Criterio FSM-004 | Implementación presente | Prueba existente / estado de evidencia | Próxima caracterización mínima |
| --- | --- | --- | --- |
| **R20: políticas y formato portable** | `FORMAT_VERSION=1`; `make_snapshot` serializa máquina en orden authored, solo alias PERSISTENT y datos JSON-safe; EPHEMERAL/SESSION activos se sustituyen por inicial authored | `tests/runtime/flow_fsm_snapshot_test.tscn`; `flow_fsm_snapshot_transient_active_test.tscn` (8D2-B2A, PASS) | 9A2 confirmar v1 y política SESSION; 9C2 prueba de archivo con teardown/restart |
| **R20: preflight seguro** | `prepare` rechaza formato, grafo/schema, duplicados, alias no persistentes, cupo, plantillas ajenas y datos inseguros; reconstruye candidato separado | `flow_fsm_snapshot_preflight_atomicity_test.tscn` (23 negativas, PASS), `flow_fsm_snapshot_test.tscn` | 9C1 probar rechazo de archivo ausente, JSON corrupto/excesivo y que se preserven también cola y callbacks |
| **R21: rutas de archivo** | `_snapshot_path_allowed` exige `user://`, extensión `.json`, sin `..` ni `\\` | El test base rechaza `res://unexpected.json` y `user://../escape.json` | 9B2 matriz acotada de rutas; comprobar rutas absolutas, extensión, subcarpetas y segmentos peculiares sin escribir fuera de `user://` |
| **R21: guardado y backup** | `save_to_file` escribe `.tmp`, `flush`, verifica texto, copia previo a `.bak`, intenta renombrado y ruta de recuperación | Test base guarda dos veces y comprueba **existencia** de `.bak` | 9B1 guardar **S1 ≠ S2**, comprobar que `destino=S2` y `backup=S1`, validar JSON de ambos |
| **R21: errores de reemplazo** | Si `rename_absolute` falla, puede eliminar destino e intentar segundo rename; en rama de fallo restaura desde backup. Un `.bak` anterior se elimina antes de copiar destino | Ninguna prueba del test base comprueba el contenido ante fallo parcial; riesgo **no confirmado** | 9B3 caracterizar casos reproducibles y seguros; evitar fault injection destructivo; RED solo si evidencia real |
| **R22: lectura y restore** | `restore_from_file` valida ruta, existencia, longitud, parsea JSON y delega al preflight `restore_snapshot`; en éxito emite Exit global antes de Enter global | Test base restaura a segundo `PVController` y rechaza un JSON corrupto; 8D2-B3B2/B3B3 PASS de callbacks/reentrancia | 9C1–9C3 fallos de archivo sin mutación y restauración tras reconstrucción del controlador; no duplicar tests de 8D2 |
| **R22: incompatibilidad de versión** | `prepare` exige `format_version=1`, `graph_id` y `schema_version` exactos | Test base versión inválida; 8D2-B2B cubre graph/schema y otros 23 rechazos | 9D1 probar rechazo desde disco ante cambio de versión/grafo, sin migración implícita |
| **Aislamiento y contrato de estado** | Datos desacoplados; runtime de cada `PVController` separado | Test base restaura en B y A no se modifica; 8D2 confirma más combinaciones | 9C2 incluir archivo real, teardown de instancia y dos controladores |
| **CI como puerta obligatoria** | Paso `FSM snapshot focal (when present)` ejecuta la prueba si existe; de lo contrario imprime ausencia sin fallar. Tests de snapshot 8D2 son obligatorios | La escena base existe y el CI histórico es verde, **pero el paso base es condicional** | 9A2 confirmar cambio de gobernanza y convertirlo en gate incondicional en microbloque separado antes de depender de la evidencia de fase 9 |

### Distinción entre riesgo y defecto

- **Backup no comprobado en contenido:** el test existente solo inspecciona `FileAccess.file_exists(FILE_PATH + ".bak")`; un `PASS` no demuestra que el respaldo sea la versión previa correcta.
- **Ventana de sustitución:** el código usa un fallback que elimina un destino antes del segundo `rename_absolute`; **no afirmar atomicidad en todas las plataformas** sin pruebas. Un `.bak` anterior puede eliminarse antes de confirmar la copia nueva. Esto es una **limitación/riesgo deducido por inspección**, no un fallo observado del runtime.
- **Un error en ruta o guardado no autoriza cambiar política** sin prueba focal, contrato y revisión de mantenedor. Probar solo archivos temporales dedicados bajo `user://flujo_fsm_tests/`; limpiar cuidadosamente.
- **Política de SESSION:** el contrato v1 establece supervivencia a `reset()`, desaparición en teardown y exclusión del snapshot. La propuesta inicial de “SESSION tras recarga de escena” no se ha aprobado como cambio contractual.
- **Formato v1:** no se introducen `controller_instance_key`, flags `started/paused`, migradores automáticos ni cambios de `schema_version` por sugerencias del plan histórico.

## Decisión de 9A1 y continuación

**9A1 auditado y documentado**: el sistema FSM-004 existente es un baseline válido para caracterización, **no** una implementación ausente que deba reescribirse. Faltan especialmente pruebas del *contenido* del backup, robustez frente a reemplazos con error, rutas/archivos inválidos, recuperación después de reconstruir instancia y formalizar la obligatoriedad del gate de snapshot base. El bloque 9A1 no crea ni modifica pruebas de Godot, entradas del catálogo, modelo, runtime o codec; su propio CI de documentación debe confirmarse por separado.

**Siguiente 9A2 (documentación/contrato):** confirmar que el contrato v1 de persistencia y lifetimes se mantiene; diseñar tabla de aceptación y pasos recuperables para **9B1** (contenido S1/S2 del backup) y el cambio pequeño de **gate obligatorio FSM-004** con trazabilidad. Si se decide cambiar semántica pública, exigir autorización de contrato, nueva cobertura y versión/migración justificadas. Proseguir después 9B2/9B3 y 9C1–9E1 según [8E-4](fsm_phase8_8e4_phase9_handoff.md).

**Verificación pendiente:** Fedora/Android 0/25 pruebas manuales heredadas. No local Godot, no invocación formal `flujo-baseline`/`flujo-prove`, no `main` o release y ningún resultado de rendimiento medido.

*Todo es Flujo; todo fluye.* 🌊
