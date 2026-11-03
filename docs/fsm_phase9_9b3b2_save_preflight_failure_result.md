# Potok 9B3-B2 — Focal F3 de fallo temprano de guardado mediante archivo centinela

**Fecha:** 2026-11-03 (America/Mexico_City). **Rama:** `feature/fsm-runtime-flow-flusso`. **Contrato:** [FLU-FSM-004](fsm_snapshot_contract_v1.md), [9B3-A](fsm_phase9_9b3a_failure_path_audit.md) y [9B3-B1](fsm_phase9_9b3b1_backup_failure_policy.md). **Estado:** `baseline_status=not_run` hasta verificar el CI integral.

- **Nueva escena:** `tests/runtime/flow_fsm_snapshot_save_preflight_failure_test.tscn` y script `.gd`, gate obligatorio `Potok-9B3B2 early save I/O preflight failure focal` de GitHub Actions Godot 4.7.2.
- **Behavior:** `FLUJO-BHV-POTOK-SNAPSHOT-SAVE-PREFLIGHT-014`; `automatic`, inicialmente `not_run`.
- **Caracterización F3:** crear controlador real, alias dinámico `PERSISTENT` activo y guardado válido S1 bajo `user://flujo_fsm_tests/phase9_9b3_valid.json`. Guardar una marca textual en un archivo ordinario `user://flujo_fsm_tests/phase9_9b3_blocker`; intentar `save_to_file("user://flujo_fsm_tests/phase9_9b3_blocker/blocked.json")`. El componente padre es un **archivo**, por lo que la creación del directorio debe fallar antes de abrir el temporal.
- **Aceptar solo si:** devuelve `false`; el centinela conserva bytes; S1 conserva bytes y JSON; no surgen destino ni temporales bajo el centinela; alias, datos persistentes y estado no cambian; la solicitud directa previamente encolada se confirma en tick posterior. Si alguno de los nombres del fixture ya existe, la prueba falla sin sobrescribirlo; limpia solo los archivos que creó.
- **No cubre:** F4 escritura parcial, F5 destrucción de backup anterior, F6/F7 fallos de rename/fallback, F8 corte de energía ni F9/F10 recuperación ante corrupción. Tampoco pretende validar universalmente todas las plataformas con un CI Linux.
- **Gobernanza:** no se modifica `FlowFSMRuntime`, codec, esquema, contrato v1, `demo/main.tscn` ni `main`. El cambio consta únicamente de prueba, escena, catálogo, gate y documentación. La ejecución local de Godot no está disponible y no se atribuye invocación formal de Skills. 25 pruebas manuales Fedora/Android diferidas.
- **Baselines históricos:** [9B2-B checkpoint 41659742397](https://github.com/mercurysama/Flujo/actions/runs/41659742397) **SUCCESS**; [9B3-A audit 41668929079](https://github.com/mercurysama/Flujo/actions/runs/41668929079) **SUCCESS**. Los runs documentales siguientes se verifican por separado.

**Siguiente:** **9B3-B3**, comprobar primero el focal y luego el CI integral. Solo tras ambos en SUCCESS cambiar `not_run → passing`; ante RED leer logs, separar test-only y producto, sin cambiar criterios silenciosamente.

*Todo es Flujo; todo fluye.* 🌊
