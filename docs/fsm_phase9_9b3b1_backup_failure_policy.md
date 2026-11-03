# Potok 9B3-B1 — Política propuesta de respaldo bajo errores y primer escenario seguro

**Fecha:** 2026-11-03 (America/Mexico_City). **Rama exclusiva:** `feature/fsm-runtime-flow-flusso`. **Tipo:** decisión de planificación documental y límites de contrato. **No cambia todavía** `FLU-FSM-004`, formato v1, `FlowFSMRuntime`, codec, comportamiento público ni workflow. Este documento **no presume autorización** para modificaciones de semántica en guardar/restaurar.

## Baseline comprobado

- [9B3-A](fsm_phase9_9b3a_failure_path_audit.md) contiene matriz F0–F10 y análisis de `save_to_file`. Base histórica [Actions 41659742397](https://github.com/mercurysama/Flujo/actions/runs/41659742397) **SUCCESS** de 9B2-B, [41658845225](https://github.com/mercurysama/Flujo/actions/runs/41658845225) **SUCCESS** de matriz de rutas y [41654276567](https://github.com/mercurysama/Flujo/actions/runs/41654276567) **SUCCESS** de respaldos S1/S2.
- Los CI de 9B3-A [41668929079](https://github.com/mercurysama/Flujo/actions/runs/41668929079) y [41669024313](https://github.com/mercurysama/Flujo/actions/runs/41669024313) estaban **in_progress** en la comprobación inicial de 9B3-B1; consultar su resultado final antes de afirmar conformidad.
- [Contrato FSM-004](fsm_snapshot_contract_v1.md): archivos `user://*.json`, temporal verificado, backup al reemplazar, retorno de error y preflight atómico al restaurar. **No exige recuperación automática desde .bak ni establece qué hacer con un destino previo corrupto.**
- El código actual elimina `.bak` previo antes de copiar el destino a `.bak`; ante fallo de rename puede eliminar el destino y reintentar, y solo entonces intenta recuperarlo desde el backup. La inspección muestra ventanas de riesgo, **no** una prueba de pérdida efectiva.

## Política de trabajo propuesta (sujeta a aceptación)

| Caso | Política deseada para evaluar | Estado de autorización |
| --- | --- | --- |
| **F5** copia de nuevo backup falla | Preferir conservar **el último backup conocido y validado** hasta crear y verificar el nuevo respaldo; no eliminar el anterior como primer paso | **Propuesta**, requiere cambio de contrato/implementación si se aprueba |
| **F6/F7** reemplazo o reintento falla | Evitar destruir el archivo destino previo antes de garantizar ruta de restauración; ante error, preservar al menos un snapshot previo íntegro y devolver `false` | **Objetivo propuesto**, no garantía actual probada |
| **F9** archivo principal previo corrupto | No declarar válido un `.bak` por el solo hecho de copiar bytes. Decidir explícitamente entre rechazar la operación de sobrescritura y preservar todos los archivos, o conservar copia de bytes corruptos diferenciada del *backup validado* | **Alternativas abiertas**, no cambiar formato ni comportamiento sin aprobación |
| **F10** archivo principal corrupto/ausente y `.bak` presente | Mantener por ahora el comportamiento existente: `restore_from_file(path)` falla sin aplicar `.bak` automáticamente. Una recuperación futura debería ser **explícita**, con preflight, decisión del usuario y prueba de aislamiento | **Conservación del contrato v1 actual; recuperación nueva pendiente de autorización** |
| **F8** corte energético/sistema | No prometer atomicidad universal, durabilidad física o protección contra pérdida de energía basada solo en GitHub CI | **Limitación reconocida**, requiere validación multiplataforma específica |

**Recomendación para decisión posterior:** recuperación explícita antes que automática; backup previamente validado y temporal escrito/verificado antes de afectar destino. Un diseño podría emplear staged backup o almacenamiento por generación, pero **no se elige API ni se ejecuta cambio** hasta observar brechas reproducibles y obtener autorización del mantenedor. Se rechaza por ahora como alternativa la restauración silenciosa desde `.bak`, porque puede sobrescribir expectativas del usuario y ocultar corrupción.

## Selección test-first de 9B3-B2: error temprano de directorio (F3)

Escenario seguro y reproducible sin manipular permisos ni archivos de usuario:

1. Usar exclusivamente `user://flujo_fsm_tests/phase9_9b3_blocker` como **archivo centinela** creado por el test; no utilizar carpetas ajenas ni `res://`. Limpiar solo archivos generados por el propio test.
2. Construir un `PVController` funcional con estado `PERSISTENT` activo y guardado válido S1 independiente en `user://flujo_fsm_tests/phase9_9b3_valid.json`. Comprobar JSON y estado antes de iniciar el caso negativo.
3. Solicitar `save_to_file("user://flujo_fsm_tests/phase9_9b3_blocker/blocked.json")`, donde `phase9_9b3_blocker` **es un archivo normal, no un directorio**. La preparación del directorio debe fallar: resultado `false`. Si el entorno crea un directorio inesperadamente, registrar el caso como FAIL en lugar de atribuir PASS.
4. Comprobar que S1 conserva exactamente sus bytes/JSON, no aparece `blocked.json` ni `.tmp` bajo el centinela, no se sobrescribe `.bak` de S1 y la operación fallida no modifica estado activo, alias ni datos persistentes.
5. Opcionalmente dejar una transición directa pendiente antes del intento; después de rechazo, un tick debe confirmarla normalmente. Esto caracteriza que un error temprano de guardado no muta la cola, sin duplicar la prueba general de rutas 9B2.
6. Limpiar únicamente los dos nombres creados bajo el prefijo temporal dedicado. No borrar directorios generales ni cambiar permisos del host.
7. Agregar **nueva escena y script focal**, comportamiento del catálogo `not_run` y gate CI obligatorio Godot 4.7.2 en el microbloque **9B3-B2**; nunca publicar `passing` antes de SUCCESS integral.

Este caso prueba **F3 exclusivamente**. No ejercita F5, F6 ni F7 (fallos intermedios de copia/rename), ni verifica tolerancia a interrupciones. No simular fault injection agregando puertas o hacks en runtime en este bloque.

## Traspaso de microbloques

- **9B3-B2:** crear y ejecutar prueba F3 con centinela en `user://`, registro y gate. Si el preflight falla como se esperaba y CI completo aprueba, marcar `passing` en cierre separado **9B3-B3**.
- **9B3-C1:** revisar si F5/F7 pueden probarse mediante abstracción de I/O en entorno desechable, sin introducir hooks de fallos en producción o alterar el contrato aún no aprobado; presentar diseño al mantenedor cuando corresponda.
- **9B3-C2 y D:** implementar un cambio funcional únicamente tras evidencia RED reproducible, autorización de política y cumplimiento de Skills formales; auditar suite integral y documentar límites. Si no hay reproducción o aprobación, conservar brecha abierta, **no** inventar solución ni cerrar universalmente el riesgo.

## Gobierno, mediciones y protección de alcance

No se han hecho nuevas ejecuciones Godot en 9B3-B1; latencia y durabilidad ante crash: **no medidos**. No cambian `AGENTS.md`, `docs/behavior_catalog.json`, `demo/main.tscn`, `FlowGraph`, `schema_version` o `main`. Las **25 verificaciones humanas** (15 Fedora y 10 Android) permanecen expresamente diferidas. Consultar las Skills versionadas no equivale a invocarlas formalmente. El CI de este documento y su checkpoint se verificarán por separado, y hasta entonces su estado es pendiente.

*Todo es Flujo; todo fluye.* 🌊
