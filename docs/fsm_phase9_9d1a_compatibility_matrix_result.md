# Potok 9D1-A — Matriz de compatibilidad y rechazo de snapshots FSM-004

**Fecha:** 2026-11-03. **Rama:** `feature/fsm-runtime-flow-flusso`. **Contrato:** [FLU-FSM-004](fsm_snapshot_contract_v1.md), formato **1**, sin migración implícita.

Nueva escena `tests/runtime/flow_fsm_snapshot_compatibility_matrix_test.tscn`, behavior `FLUJO-BHV-POTOK-SNAPSHOT-COMPATIBILITY-019` y gate obligatorio `Potok-9D1A snapshot version graph and schema matrix focal` en Godot 4.7.2. La prueba construye un controlador real con alias PERSISTENT activo, almacena ocho fixtures incompatibles en `user://flujo_fsm_tests/phase9_9d1_compat.json` y comprueba el rechazo atómico de versiones 0/2, esquema diferente, `graph_id` ajeno, `machine_id` inválido, `active_state_id` ausente, plantilla desconocida y tipo de colección incorrecto. Cada intento conserva alias, datos y cola; tras comprobar la transición pendiente, un archivo v1 exacto restaura correctamente.

**Baseline: passing** tras [Actions 41711670098](https://github.com/mercurysama/Flujo/actions/runs/41711670098) SUCCESS integral 109/109. [9C3-C Actions 41706512868](https://github.com/mercurysama/Flujo/actions/runs/41706512868) **SUCCESS 108/108**; [9C3-D](fsm_phase9_9c3d_disk_reentrant_closeout.md) registra cierre. No se altera runtime, codec, formato, schema, `main` ni demo. F5–F7 siguen sin pruebas exactas, y las 25 verificaciones humanas están aplazadas.

**9D1-B completado:** focal y suite integral 109/109 SUCCESS; catálogo `passing`. **Siguiente:** auditoría 9D2, después dictamen condicionado 9E1.

*Todo es Flujo; todo fluye.* 🌊
