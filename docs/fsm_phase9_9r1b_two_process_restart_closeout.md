# Potok 9R1-B — Verificación y cierre documental de prueba entre procesos

**Fecha:** 2026-11-03. **Rama:** `feature/fsm-runtime-flow-flusso`. **Base verificada:** `eaa95cb9239fd37bb3a69d07298e5684dc7688c1`. **Dictamen:** **PASS automatizado de 9R1-A**, cierre de 9R1-B en catálogo y documentos. No implica cierre incondicional de la fase 9.

## Evidencia verificable

- **Requisito:** FSM-004, reinicio de proceso del juego con persistencia explícita del estado `PERSISTENT`, sin confundirlo con reconstrucción de un `PVController` dentro del mismo proceso.
- **Prueba y fixture:** `tests/runtime/flow_fsm_snapshot_two_process_test.gd`, `tests/runtime/flow_fsm_snapshot_two_process_write.tscn`, `tests/runtime/flow_fsm_snapshot_two_process_restore.tscn`; código de prueba versionado en `eaa95cb9239fd37bb3a69d07298e5684dc7688c1`.
- **Acción CI obligatoria:** `Potok-9R1A two separate Godot processes preserve user snapshot` de `.github/workflows/flujo-fsm.yml`, con Godot **4.7.2** y dos invocaciones `--headless` secuenciales, usando el mismo directorio de datos aislado `XDG_DATA_HOME` creado con `mktemp` y limpiado al salir mediante `trap`.
- **Resultado GitHub Actions:** [workflow 41722469207](https://github.com/mercurysama/Flujo/actions/runs/41722469207) en `eaa95cb9239fd37bb3a69d07298e5684dc7688c1`, **completed SUCCESS**, job `headless` **success**, y paso específico **success**.
- **Marcas reales de los logs:** `[Flujo] Potok 9R1 process write passed` y `[Flujo] Potok 9R1 process restore passed`. Ambas invocaciones acabaron con código 0 bajo `set -euo pipefail` y timeouts acotados. La segunda accedió al archivo persistido por la primera, no a un objeto vivo del mismo proceso.

## Invariantes cubiertos

1. El grafo authored de la fixture conserva IDs estáticos en ambos procesos y un snapshot con `format_version=1`.
2. A registra estados `EPHEMERAL`, `SESSION` y `PERSISTENT`, activa el persistente y guarda `user://flujo_fsm_tests/phase9_restart/snapshot.json`.
3. B arranca sin restauración implícita; ejecuta `restore_from_file` y recupera el alias persistente con el mismo ID y datos JSON-safe. Los aliases transitorios no se incluyen en el snapshot.
4. El catálogo `docs/behavior_catalog.json` actualiza exclusivamente `FLUJO-BHV-POTOK-SNAPSHOT-TWO-PROCESS-020` de `not_run` a `passing`, con referencia al workflow; no se altera su cobertura ni sus aserciones.

## Límites y alcance del cierre

La prueba confirma **persistencia entre dos procesos independientes de Godot en Linux CI**, no reinicio del dispositivo, pérdida de energía, resistencia a fallos de copia/rename, recuperación automática desde `.bak` ni almacenamiento Android. Los escenarios F5/F6/F7/F7R siguen **NOT RUN**, la política F9 requiere autorización expresa, y las **25 pruebas humanas** (15 Fedora y 10 Android) siguen **0/25 PENDING**. No se aprueba merge, release ni modificación de `main`.

**Cambios en esta entrega:** catálogo, actualización del reporte histórico 9R1-A, este cierre, dictamen condicionado 9E1-D y bitácora. **Cero cambios** en runtime, modelo, codec, tests o workflow. No se ejecutó Godot local/Flatpak; se consultaron los procedimientos versionados de baseline/prove como documentación, sin invocación formal ni dictamen READY/PASA. El nuevo commit documental necesita confirmación de CI propia; el PASS funcional proviene del workflow verificado y citado.

**Siguiente:** mantener fase 9 en estado condicionado; pedir aprobación específica antes de abordar 9R2/F5–F7 y F9; preparar la siguiente fase del plan solo sin ocultar esos riesgos ni las revisiones físicas.

*Todo es Flujo; todo fluye.* 🌊
