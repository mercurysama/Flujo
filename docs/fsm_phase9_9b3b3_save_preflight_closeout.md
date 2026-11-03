# Potok 9B3-B3 — Cierre técnico de guardado fallido F3

**Fecha:** 2026-11-03 (America/Mexico_City). **Rama:** `feature/fsm-runtime-flow-flusso`. **Cierre:** **PASS automático para F3**, no aceptación manual ni cierre total de 9B3.

- **Evidencia reproducible:** [GitHub Actions 41670135010](https://github.com/mercurysama/Flujo/actions/runs/41670135010) finalizó `completed SUCCESS` sobre `9fc4d44a9c4de18100d2b4095ded461ad0355bcf`, con job `headless` **104/104 pasos completados**, cero fallidos y focal obligatorio `Potok-9B3B2 early save I/O preflight failure focal` **SUCCESS**.
- **Prueba focal:** `tests/runtime/flow_fsm_snapshot_save_preflight_failure_test.gd` / `.tscn`, registrada en `docs/behavior_catalog.json` como `FLUJO-BHV-POTOK-SNAPSHOT-SAVE-PREFLIGHT-014`, transicionada `not_run → passing` **solo después** de comprobar la totalidad de GitHub Actions.
- **Qué prueba F3:** guardar bajo un componente intermedio que es un archivo centinela devuelve `false`; no se crea destino ni temporal indebido; se conserva la integridad textual del guardado S1, el centinela, el alias activo PERSISTENT, sus datos y la petición de transición que después confirma un tick.
- **Qué no prueba:** corrupción de datos, falla de escritura parcial, pérdida energética, F5 borrado de backup anterior, F6 y F7 errores de rename/copia y recovery, recuperación automática desde `.bak` o garantías multiplataforma. Siguen como riesgo o decisión de política en [9B3-A](fsm_phase9_9b3a_failure_path_audit.md) y [9B3-B1](fsm_phase9_9b3b1_backup_failure_policy.md).
- **Control:** ninguna modificación del runtime, codec, contrato v1 o FlowGraph. No merge ni release, no pruebas locales Godot y Skills formales no ejecutadas. Las 25 pruebas manuales (15 Fedora, 10 Android) permanecen pospuestas.
- **Siguiente 9B3-C1:** inventariar alternativas para probar de forma determinista y aislada fallos F5–F7 sin inyectar fallos en producción ni afectar archivos de usuario; proponer arquitectura mínima y pruebas, sin implementarla antes de autorización contractual. El CI del propio checkpoint de cierre se verifica por separado.

*Todo es Flujo; todo fluye.* 🌊
