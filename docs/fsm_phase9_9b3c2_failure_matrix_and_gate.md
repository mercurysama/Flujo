# Potok 9B3-C2 — Matriz determinista y puerta de autorización para errores de respaldo

**Fecha:** 2026-11-03 (America/Mexico_City). **Rama:** `feature/fsm-runtime-flow-flusso`. **Base:** [9B3-C1](fsm_phase9_9b3c1_fault_test_design_audit.md) y [política 9B3-B1](fsm_phase9_9b3b1_backup_failure_policy.md). **Estado:** diseño verificable, sin implementación productiva, sin nueva focal y sin actualización del catálogo. El contrato `FLU-FSM-004` **no se ha modificado**.

## Contrato para el eventual banco de pruebas

El objetivo de una futura caracterización es poder observar y fallar **una operación de I/O por vez**, en una copia aislada de los archivos creados por el test, conservando el orden de operaciones reales. No se implementa ahora una interfaz de fallos, ya que la extracción productiva requiere aceptación, baseline y prove formales. Se rechaza exponer parámetros como `fail_rename`, `debug_inject_error` o hooks públicos a usuarios finales.

| ID propuesto | Precondición | Punto de fallo exacto | Aserciones exigidas | Verificación disponible |
| --- | --- | --- | --- | --- |
| **C-F5** | principal S2, backup S1 previamente validado, temporal S3 preparado | copia de principal a respaldo falla tras la política de backup aprobada | `save_to_file=false`, principal S2 no cambia, no destruir S1 sin reemplazo válido, cleanup del temporal y FSM idéntica | **NO RUN**; requiere seam o prueba real exacta |
| **C-F6** | principal S2, temporal S3, backup recuperable | primer `rename(tmp,main)` falla | ruta de fallo/reintento observada, no pérdida silenciosa del último snapshot íntegro, estado FSM intacto | **NO RUN**, dependiente de plataforma |
| **C-F7** | tras fallo de primer rename, falla segundo rename | segundo rename falla después de rama de publicación | `false`, intento de recuperación observado; bytes de principal/respaldo verificados, reportar si falta principal | **NO RUN**; exige fault control exacto |
| **C-F7R** | fallback requiere copia backup → principal | falla restauración de respaldo | evidenciar pérdida/estado parcial sin afirmar éxito; preservar `.bak` y diagnosticar recuperación explícita | **NO RUN**, sin implementación |
| **C-F9** | archivo previo corrupto y backup válido | operación de reemplazo solicitada | separar elección de política: rechazar y preservar vs copiar bytes; no declarar bytecopy válido | **POLÍTICA ABIERTA** |
| **C-F10** | principal ilegible, backup con JSON validable | `restore_from_file(main)` | rechaza sin cambiar runtime; **no** aplica `.bak` de forma silenciosa | Cubierto conceptualmente por contrato; escenario puntual **NO RUN** |

## Especificación mínima de un seam futuro (no implementado)

- Una responsabilidad de **coordinador de archivos**, separada de `FlowFSMSnapshotCodec` y de los cambios de estado: `write_tmp`, `verify_tmp`, `backup_previous`, `replace_main`, `restore_previous`, `cleanup_tmp`, con una operación fallida controlada por la **implementación de test**, no por el runtime público. El nombre y la forma final de la API no quedan aprobados por este documento.
- El backend real usa solo operaciones de archivo soportadas por Godot 4.7.2; un fake puro registra llamadas/resultados para probar orden y las ramas negativas. Mantener intactos `format_version=1`, `graph_id`, `schema_version`, IDs y lifetimes.
- Crear tests test-first con nombres nuevos bajo `tests/runtime/` o `tests/model/` según dependencia de motor; cada comportamiento nuevo entra al catálogo en `not_run` y al workflow como paso **obligatorio**, nunca condicional. No marcar `passing` sin CI integral SUCCESS.
- La suite funcional heredada y las focals 9B1, 9B2 y F3 deben seguir aprobando; primero ejecutar baseline y luego prove conforme a las Skills versionadas formalmente invocadas. No hay autorización para cambiar comportamiento existente o migrar schema en este microbloque.

## Secuencia de implementación condicionada

1. **C3 (autorización y especificación):** solicitar al mantenedor decisión explícita sobre semántica F5/F7/F9 y si permite extraer la coordinación de archivos a helper testeable. Hasta entonces **no tocar código productivo**.
2. **C4 (caracterización):** si se aprueba, construir un test de secuencia pura con fake y baseline de comportamiento real, dejando el primer RED visible y sin debilitar aserciones.
3. **C5 (ajuste mínimo):** si un RED demuestra incumplimiento, aplicar solo la corrección contractual; conservar el resultado exitoso S1/S2 y rollback de runtime. Implementar cambio de comportamiento como commit separado de refactors.
4. **C6 (cierre automatizado):** ejecutar Godot 4.7.2 y todas las puertas; actualizar catálogo a `passing` solo tras SUCCESS y documentar lo no cubierto (power-loss, dispositivos, permisos).
5. **Si no hay autorización:** conservar F5–F7 abiertos como **riesgos no caracterizados** y avanzar a los demás elementos documentados de fase 9 que no cambien la política; no declarar F5–F7 resueltos.

## Criterio de salida C2

- Matriz de puntos de fallo y aserciones listos para revisión: **documentada**.
- Pruebas F5–F7 ejecutadas: **0**; resultado F5–F7: **no verificado**.
- Runtime, codec, contrato v1, workflow, catálogo y `main`: **sin modificación**.
- 25 verificaciones humanas: **aplazadas**.
- Medición de durabilidad frente a corte eléctrico: **no medida**.

**Próximo microbloque recomendado:** **9B3-C3**, preparar decisión de autorización de diseño, sin deducir consentimiento por el hecho de continuar; alternativamente pasar a **9C1-A** (lectura corrupta/ausente) si el mantenedor decide mantener la política actual. Las dos tareas C1 y C2 quedaron limitadas a documentación y no equivalen a implementación de recuperación.

*Todo es Flujo; todo fluye.* 🌊
