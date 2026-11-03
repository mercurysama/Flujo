# Potok 9B1-B — Cierre de la caracterización de respaldo S1/S2

**Fecha:** 2026-11-03 (America/Mexico_City). **Rama:** `feature/fsm-runtime-flow-flusso`. **Dictamen:** **PASS técnico automatizado de 9B1**. No hay aceptación visual, cierre de fase 9 ni publicación estable.

- **Código de prueba:** `tests/runtime/flow_fsm_snapshot_backup_contents_test.gd` y `.tscn`, [commit `c0385b6`](https://github.com/mercurysama/Flujo/commit/c0385b67ba7ae62080a34961c2a084f55db167cf). Behavior `FLUJO-BHV-POTOK-SNAPSHOT-BACKUP-CONTENT-012`.
- **CI real:** [GitHub Actions 41654276567](https://github.com/mercurysama/Flujo/actions/runs/41654276567), **completed SUCCESS** sobre `c0385b67ba7ae62080a34961c2a084f55db167cf`. Job `headless`: **102 pasos completed, cero fallos**; paso `Potok-9B1A distinct snapshot backup contents focal` **completed SUCCESS**, y suite integral aprobada en Godot 4.7.2.
- **Aceptación caracterizada:** primer `save_to_file` crea S1 y no produce respaldo previo; tras cambio efectivo de datos de alias PERSISTENT, segundo guardado crea S2 ≠ S1. Parseo JSON confirma `destino=S2`, `backup .bak=S1` y ambos son snapshots válidos, misma identidad, versión y registro persistente, con payload anterior y nuevo diferenciados. El runtime activo no se modifica y no queda `.tmp`.
- **Trazabilidad:** [9A2](fsm_phase9_9a2_contract_and_gate.md), [9B1-A](fsm_phase9_9b1a_backup_contents_result.md), `docs/behavior_catalog.json`, gate obligatorio en `.github/workflows/flujo-fsm.yml`. Catalog `not_run → passing` **después** de verificar CI; ninguna prueba debilitada.
- **Límite:** esto no garantiza atomicidad frente a caídas de energía o fallos de renombrado/copia en todos los sistemas. Los escenarios negativos de filesystem corresponden a 9B3. **No** se modifica `FlowFSMRuntime`, `FlowFSMSnapshotCodec`, `FlowGraph`, modelo, escena demo o `main`; solo documentación/catálogo.
- **Gobernanza:** 25 pruebas humanas (15 Fedora + 10 Android) aplazadas; Godot local no ejecutado; Skills del repositorio no invocadas formalmente. Cualquier ajuste funcional posterior requiere evidencia adicional y puertas de gobernanza.

**Próximo microbloque 9B2-A:** caracterizar una matriz acotada de rutas `user://` válidas e inválidas, tanto `save_to_file` como `restore_from_file`. Asegurar no crear archivos fuera del área aislada y preservar estado/cola ante rechazos, con behavior inicial `not_run`, escena y gate CI obligatorio. Cerrar 9B2-B solamente después de CI integral SUCCESS.

*Todo es Flujo; todo fluye.* 🌊
