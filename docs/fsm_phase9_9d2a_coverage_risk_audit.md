# Potok 9D2-A — Auditoría integral de cobertura y pendientes de la fase 9

**Fecha:** 2026-11-03. **Rama exclusiva:** `feature/fsm-runtime-flow-flusso`. **Corte de evidencia:** [Actions 41711670098](https://github.com/mercurysama/Flujo/actions/runs/41711670098) **completed SUCCESS**, 109/109 pasos del job headless Godot 4.7.2; commit base `a41076b37ac7db8de754eda0b7c5e62ceab73ff9`. **Tipo:** auditoría documental, no aceptación final, no release, sin cambios productivos.

## Alcance verificado (FSM-004)

| Frente | Prueba obligatoria CI | Behavior del catálogo | Estado |
| --- | --- | --- | --- |
| Archivo principal S2, respaldo S1 tras dos guardados | `flow_fsm_snapshot_backup_contents_test.tscn` | `FLUJO-BHV-POTOK-SNAPSHOT-BACKUP-CONTENT-012` | **passing** |
| Rutas user:// y rechazos no destructivos | `flow_fsm_snapshot_path_matrix_test.tscn` | `FLUJO-BHV-POTOK-SNAPSHOT-PATH-POLICY-013` | **passing** |
| F3 fallo temprano preparando directorio de guardado | `flow_fsm_snapshot_save_preflight_failure_test.tscn` | `FLUJO-BHV-POTOK-SNAPSHOT-SAVE-PREFLIGHT-014` | **passing** |
| Lectura corrupta, ausente, excesiva, versión/identidad inválida | `flow_fsm_snapshot_invalid_file_restore_test.tscn` | `FLUJO-BHV-POTOK-SNAPSHOT-INVALID-FILE-015` | **passing** |
| Destrucción de controlador y recuperación PERSISTENT explícita | `flow_fsm_snapshot_instance_reconstruction_test.tscn` | `FLUJO-BHV-POTOK-SNAPSHOT-RECONSTRUCT-016` | **passing** |
| Lectura de disco y Exit(A),Exit(B),Enter(A),Enter(B), aislamiento | `flow_fsm_snapshot_disk_restore_callbacks_test.tscn` | `FLUJO-BHV-POTOK-SNAPSHOT-DISK-CALLBACKS-017` | **passing** |
| Reentrancia de restore_from_file y ticks anidados | `flow_fsm_snapshot_disk_restore_reentrant_test.tscn` | `FLUJO-BHV-POTOK-SNAPSHOT-DISK-REENTRANCY-018` | **passing** |
| Rechazo estricto de compatibilidad v1 por grafo/schema/IDs | `flow_fsm_snapshot_compatibility_matrix_test.tscn` | `FLUJO-BHV-POTOK-SNAPSHOT-COMPATIBILITY-019` | **passing** |

**Inventario de gobernanza inspeccionado:** `docs/behavior_catalog.json` contiene **100 entradas** al corte de esta auditoría; los **ocho** nuevos behavior 012–019 aparecen en `passing`, cada uno con escena declarada y puerta incondicional correspondiente en `.github/workflows/flujo-fsm.yml`. El histórico `flow_fsm_snapshot_test.tscn` también es obligatorio desde 9A2. Existen focals anteriores de snapshots, lifetimes, preflight y callbacks de 8D2.

## Relación con los ocho criterios de fase 9 del plan general

1. **Políticas de vida:** EPHEMERAL se elimina en reset y SESSION en teardown; PERSISTENT es elegible para snapshot. El contrato vigente exige restauración **explícita** tras crear una instancia nueva; las pruebas de ciclo de vida cubren un controlador reconstruido, **no reinicio de un ejecutable completo ni reinicio del dispositivo**.
2. **Formato:** `format_version=1` y `graph_id/schema_version`, máquinas y alias PERSISTENT. No se introdujeron `controller_instance_key` ni `started/paused` propuestos en plan pero no fijados por `FLU-FSM-004`.
3. **Seguridad de datos:** codec y validador originales cubren JSON-safe, límites y referencias no ejecutables; las pruebas de disco comprueban rechazo antes del commit. No se probó ejecución de payload malicioso de plataforma.
4. **Guardado seguro:** F1 (`main=S2`, `.bak=S1`) y F3 (fallo temprano) **sí** están caracterizados. La resistencia a copia fallida, backup borrado, segundo renombrado y pérdida de energía **no** está verificada.
5. **Preflight → commit:** archivos corruptos/incompatibles se rechazan sin mutar estado ni cola; restore válido recupera alias y datos. El commit ejecuta callbacks del contrato.
6. **Callbacks:** restore emite todos los Exit antes de todos los Enter, una sola vez por máquina en pruebas; no se debe confundir con secuencia de reset. In-tick restore rechazado.
7. **Compatibilidad:** formatos 0/2, schema ajeno, graph/machine/state/template incorrectos rechazan, sin inventar migración por nombre/posición.
8. **Pruebas de I/O y múltiples controladores:** cobertura de archivo, rutas, errores, dos controladores y teardown. **No** se ha ejecutado una prueba real de crash o write interruption en media publicación.

## Riesgos abiertos y no conformidades de cierre

- **F5–F7/F7R:** [auditoría 9B3-A](fsm_phase9_9b3a_failure_path_audit.md), [matriz 9B3-C2](fsm_phase9_9b3c2_failure_matrix_and_gate.md): el código borra `.bak` antes de copiar su reemplazo y puede eliminar `main` antes del segundo rename. Se trata de **riesgos deducidos del código, no defectos reproducidos**; no hay fault injection ni garantía de recuperación robusta. Requieren decisión del mantenedor y evidencia específica para extraer helper de I/O o cambiar la política. **No se consideran resueltos por el 109/109.**
- **F9:** manejo de destino corrupto antes de hacer backup no está acordado: un bytecopy a `.bak` no implica snapshot validado.
- **F10:** `restore_from_file` no recupera automáticamente desde `.bak`. Esta decisión se mantiene deliberadamente, no supone defecto confirmado.
- **Persistencia de juego reiniciado:** 9C2 reconstruye un controlador dentro de la misma ejecución del motor. No sustituye una prueba de ejecutar Godot de nuevo, que figura como criterio final de fase 9. Por tanto el cierre técnico **es condicionado**.
- **Pruebas humanas:** 15 Fedora + 10 Android = **25 aplazadas**, ninguna declarada PASS. Tampoco se midieron garantías de sistema de archivos o crash en Android/Fedora.
- **Puertas formales:** se han leído referencias del proyecto y comprobado CI remoto, pero no se acredita invocación formal de Skills `$flujo-baseline`/`$flujo-prove` desde este entorno. No atribuir su ejecución.
- **Estado de integración:** no hay merge a `main`, PR aceptada, release ni aprobación de UI.

## Dictamen de 9D2-A y siguiente microbloque

**Cobertura automatizada de los ocho behaviors nuevos: 8/8 passing, con suite integral SUCCESS de referencia 109/109.** Esta cifra describe un conjunto acotado de pruebas y no equivale a 8/8 requisitos de durabilidad universal. **El cierre incondicional de fase 9 NO procede** con F5–F7 sin caracterización, la prueba de reinicio de juego no ejecutada y 25 verificaciones humanas expresamente diferidas. Se recomienda **9E1-A: dictamen técnico condicionado y plan de aceptación**, sin cambiar código productivo ni aprobar recuperación automática. Si el mantenedor autoriza pruebas de fallo de reemplazo, ejecutarlas como microbloques separados con baseline y prove formales.

**Métricas comprobables:** ocho entradas nuevas y ocho gates explícitos, 109 pasos SUCCESS en el run integral indicado, F5–F7 ejecutados 0, pruebas humanas ejecutadas 0/25. Durabilidad/tiempo de recuperación **no medidos**.

*Todo es Flujo; todo fluye.* 🌊
