# Potok 9A2 — Contrato congelado FSM-004, criterios de archivo y puerta CI obligatoria

**Fecha:** 2026-11-03 (America/Mexico_City). **Rama:** `feature/fsm-runtime-flow-flusso`. **Baseline:** `08a43c012a57c08fe731e324d74c574f725cd7dc`, [Actions 41613177819](https://github.com/mercurysama/Flujo/actions/runs/41613177819) **SUCCESS** del checkpoint 9A1; [41613093728](https://github.com/mercurysama/Flujo/actions/runs/41613093728) **SUCCESS** de la auditoría 9A1. **Alcance:** decisión documental y refuerzo mínimo del workflow; **ninguna modificación al runtime, codec, grafo, formato o pruebas existentes**.

## Decisiones para 9A2

1. **Se conserva [FLU-FSM-004](fsm_snapshot_contract_v1.md), formato 1.** `format_version=1`, `graph_id`, `schema_version`, lista de máquinas en orden authored y aliases dinámicos persistentes con datos JSON-safe. No incorporar campos históricos opcionales `controller_instance_key` o `started/paused`, ni migración automática, por esta subfase.
2. **SESSION no es persistencia a disco:** sobrevive `reset()` en el mismo runtime, desaparece con `stop()`/teardown, y nunca se almacena en snapshot. EPHEMERAL desaparece al reset y no se guarda. PERSISTENT sobrevive reset, es elegible para snapshot, **no** renace automáticamente al reconstruir un controlador: requiere `restore_snapshot` o `restore_from_file`. Un alias transitorio activo se representa por el estado inicial authored en el archivo.
3. **Respaldo esperado:** si el primer guardado crea `S1` y el segundo guarda `S2` (con `S1 != S2`), el archivo destino debe decodificar exactamente `S2` y el archivo `.bak` debe decodificar exactamente `S1`. Solo la existencia de `.bak` no satisface el criterio; los dos deben incluir versión, identidad, máquinas y datos persistentes coherentes. Ni la comparación del contenido ni la recuperación de errores se consideran PASS hasta pasar nuevas focals.
4. **Rutas y fallos:** `user://*.json` bajo carpeta aislada de pruebas. Rutas relativas, `res://`, absolutas y traversal deben rechazarse sin escrituras inesperadas. Ante rechazo/preflight, preservar estado activo, alias, datos, cola y callbacks. Fallos de copia o reemplazo se ensayan únicamente con medios seguros; **no** afirmar atomicidad de sistema operativo o comportamiento bajo power loss sin evidencia.
5. **CI obligatorio:** el test histórico `tests/runtime/flow_fsm_snapshot_test.tscn` sí existe y ejecutaba su focal en el workflow, pero bajo condición `if test -f` con camino `echo` que no fallaba si faltaba. Se reemplaza esa condición por un paso **incondicional** que ejecuta directamente la escena con timeout de 70 segundos. Si el archivo desaparece, el workflow fallará en lugar de imprimir un aviso no bloqueante. No se alteran aserciones ni la escena. Esta mejora de política es una puerta de verificación, **no un cambio de comportamiento público**.
6. **Gobernanza:** para implementar cambios funcionales posteriores se requiere caracterizar primero, catalogar behavior `not_run` y gate obligatorio, verificar Godot 4.7.2 CI integral, y pasar a `passing` solo tras `SUCCESS`. Una prueba RED no autoriza debilitar aserciones. La invocación formal de Skills del repositorio se distingue de leerlas.

## Matriz recuperable siguiente

| Microbloque | Prueba mínima prevista | Criterio de aceptación |
| --- | --- | --- |
| **9B1-A** | Preparar escena focal de dos guardados con datos persistentes distintos `S1`, `S2`, mismo grafo/ID, sin editar runtime | Aserciones de archivo destino `S2` y respaldo `S1`, validación JSON y datos JSON-safe, limpieza de `.json/.tmp/.bak` en `user://flujo_fsm_tests/`; behavior nuevo `not_run` y gate obligatorio |
| **9B1-B** | Confirmar focal, regresión completa Godot y actualizar catálogo | Cierre de 9B1 solo si GitHub Actions **SUCCESS** integral; documentar errores test-only versus fallos reales |
| **9B2** | Matriz de rutas y rechazo por path inválido en save/load | Rechazo sin archivos fuera del árbol temporal de pruebas |
| **9B3** | Escenarios seguros de error de copia/reemplazo y preservación de respaldo | No atribuir fallo hasta reproducir RED; no simulaciones destructivas |
| **9C1–9C3** | Archivo corrupto/incompatible, teardown/restart y callbacks seguros | Rechazos atómicos, recuperación explícita y aislamiento |
| **9D1–9E1** | Compatibilidad, auditoría y dictamen técnico condicionado | Trazabilidad completa, sin confundir con 25 manuales ni release |

## Riesgos y limitaciones

- La implementación de `save_to_file` usa temporal, copia de backup y operaciones rename/delete. El test base actual comprueba solo **existencia** del backup, no su contenido; se conserva esta diferencia como brecha de evidencia.
- La nueva puerta incondicional modifica solo `.github/workflows/flujo-fsm.yml`; no invade `addons/vp_flujo/`, `demo/main.tscn` ni `main`.
- **9A2 permanece pendiente de verificación** hasta que el propio commit tenga GitHub Actions integral `SUCCESS`. La existencia de un nuevo gate no prueba que ya haya corrido.
- Las 25 verificaciones manuales de fase 7/8 (15 Fedora, 10 Android) permanecen aplazadas. Fase 9 no está cerrada. Godot local no ejecutado; ninguna invocación formal de Skills realizada en este contexto.

**Próximo paso:** 9B1-A. Comprobar HEAD y Actions, leer este contrato, crear solamente el test focal + escena + registro y gate, preservar código productivo. Detenerse a diagnosticar un RED real y corregir el contrato solo con autorización.

*Todo es Flujo; todo fluye.* 🌊
