# Potok 9C2-A — Restauración explícita tras teardown del controlador

**Fecha:** 2026-11-03. **Rama:** `feature/fsm-runtime-flow-flusso`. **Contrato:** [FLU-FSM-004](fsm_snapshot_contract_v1.md), política de life time [9A2](fsm_phase9_9a2_contract_and_gate.md). **Estado: not_run** hasta CI integral.

- Escena `tests/runtime/flow_fsm_snapshot_instance_reconstruction_test.tscn`, script GDScript y gate obligatorio `Potok-9C2A controller teardown and disk restore focal` Godot 4.7.2.
- Se construye controlador fuente real y estados dinámicos SESSION/PERSISTENT; se activa PERSISTENT con datos JSON-safe, se guarda a `user://flujo_fsm_tests/phase9_9c2_reconstruct.json`, se comprueba JSON y se destruye el nodo original mediante `queue_free` y un frame.
- Se crea **otro** PVController con el mismo FlowGraph: ID de runtime distinto, estado inicial authored y ausencia de los viejos alias. No existe carga automática. Después de llamar explícitamente `restore_from_file`, la instancia nueva debe restaurar el ID PERSISTENT activo, datos y snapshot JSON normalizado idéntico. El alias SESSION no aparece.
- Behavior `FLUJO-BHV-POTOK-SNAPSHOT-RECONSTRUCT-016` entra al catálogo como `not_run`. No se editan runtime, codec, esquema, workflow previo, formato v1, `main` ni demo. La prueba y gate son nuevos, sin ganchos de fallo ni autoload.
- **Baseline:** 9C1-A [Actions 41678522740](https://github.com/mercurysama/Flujo/actions/runs/41678522740) completó **SUCCESS 105/105**. 9C1-B queda registrado como `passing` por esa evidencia. 25 verificaciones manuales diferidas.

**Siguiente 9C2-B:** verificar nuevo CI integral y actualizar status a `passing` solo con éxito; posteriormente 9C3-A callbacks y reentrancia de restore.

*Todo es Flujo; todo fluye.* 🌊
