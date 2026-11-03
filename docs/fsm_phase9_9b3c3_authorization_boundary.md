# Potok 9B3-C3 — Decisión de límites y continuidad sin cambio de política

**Fecha:** 2026-11-03. **Rama:** `feature/fsm-runtime-flow-flusso`. **Referencia:** [9B3-C2](fsm_phase9_9b3c2_failure_matrix_and_gate.md). **Decisión de ejecución:** mantener **abiertos** F5/F6/F7/F7R y F9; no introducir helper productivo ni reinterpretar `FLU-FSM-004` por mera continuidad. El permiso de ejecutar microbloques consecutivos no equivale a aprobar una política nueva de sobrescritura o recuperación.

- **Pendiente de decisión específica:** si conservar siempre el último backup validado y cómo manejar el destino previo corrupto. La recuperación desde `.bak` no es automática en el contrato actual.
- **Evidencia:** 9B1/9B2/F3 protegen escenarios de éxito, rutas inválidas y fallo temprano; **ninguno inyecta fallos exactos de copy/rename**. C1/C2 son diseño, no implementación.
- **Ruta de avance independiente aprobable con el contrato vigente:** **9C1-A**, pruebas test-first de lectura ausente, JSON corrupto, contenido excesivo y versiones incompatibles, con comparación de estado y solicitud pendiente; cualquier defecto real se informa por separado.
- **No hay cambio productivo, formato, catálogo ni CI en C3**. 25 pruebas humanas pospuestas. Los runs de C1/C2/checkpoint se consultan antes de atribuirles SUCCESS. Godot local no ejecutado; las Skills versionadas no se invocaron formalmente.

*Todo es Flujo; todo fluye.* 🌊