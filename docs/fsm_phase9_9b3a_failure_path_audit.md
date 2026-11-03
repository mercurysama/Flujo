# Potok 9B3-A — Auditoría de fallos de sustitución y conservación segura de respaldos

**Fecha:** 2026-11-03 (America/Mexico_City). **Rama:** `feature/fsm-runtime-flow-flusso`. **HEAD base:** `3ebc98415f7b9d70cd74ee54b9a16b1e81ddf6ae`. **Alcance:** auditoría de rutas de error y diseño de pruebas acotadas; no se modifican API, codec, runtime, workflow ni pruebas. **No se declara fallo funcional ni atomicidad universal** sin evidencia reproducida.

## Baseline y normativa confirmados

- [FLU-FSM-004](fsm_snapshot_contract_v1.md) exige `user://*.json`, temporal verificado, respaldo al reemplazar y restauración validada sin mutar el runtime ante fallo.
- [9B1-B](fsm_phase9_9b1b_backup_contents_closeout.md) caracteriza **dos guardados exitosos distintos**, archivo destino S2 y `.bak` anterior S1; [Actions 41654276567](https://github.com/mercurysama/Flujo/actions/runs/41654276567) **SUCCESS**.
- [9B2-B](fsm_phase9_9b2b_path_matrix_closeout.md) caracteriza rutas válidas/rechazos y preservación de solicitudes ante restore inválido; [Actions 41658845225](https://github.com/mercurysama/Flujo/actions/runs/41658845225) **SUCCESS**; checkpoint [41659742397](https://github.com/mercurysama/Flujo/actions/runs/41659742397) **SUCCESS** Godot 4.7.2.
- `AGENTS.md`, `docs/constitution.md` y `docs/development_workflow.md` requieren cambios pequeños, pruebas focales sin debilitar, trazabilidad y autorización humana para integración. Las Skills `flujo-baseline` y `flujo-prove` no se consideran formalmente ejecutadas en esta auditoría documental.
- No se probó Godot local; no se modificó `main`. Las 25 pruebas humanas Fedora/Android siguen aplazadas.

## Secuencia del código inspeccionada

En `addons/vp_flujo/runtime/flow_fsm_runtime.gd`, `save_to_file(path)`:

1. Rechaza rutas fuera del filtro `_snapshot_path_allowed` y snapshots vacíos/inseguros o demasiado grandes antes de acceder a disco.
2. Convierte a JSON; prepara el directorio en `user://`; abre `destino.tmp`, escribe, hace `flush`, cierra y compara su contenido con el JSON planeado.
3. Si existe `destino`, **borra cualquier `destino.bak` previo** y copia `destino → destino.bak`; si la copia falla, borra `.tmp` y retorna `false`.
4. Intenta `rename_absolute(tmp, destino)`. Cuando falla y había destino, puede **eliminar el destino previo** y reintentar el rename.
5. Si ese procedimiento falla, intenta copiar `.bak → destino` y borrar `.tmp`; devuelve `false`. `restore_from_file` solo lee `destino`, parsea y valida, sin recuperación automática desde `.bak`.

## Matriz de caracterización segura y riesgos

| Caso | Punto de fallo / condición | Resultado contractual deseable | Situación de evidencia / método seguro |
| --- | --- | --- | --- |
| **F0** | Primer guardado exitoso (no hay destino previo) | Archivo principal válido y ninguna copia anterior requerida | Cobertura histórica base; no duplicar |
| **F1** | Segundo guardado exitoso, contenido S1 != S2 | Destino S2; respaldo S1; sin temporal | **PASS 9B1**; no repetir como prueba nueva |
| **F2** | Ruta inválida, extensión/traversal | Retornar false sin publicar ni alterar cola | **PASS 9B2** para matriz conocida |
| **F3** | Fallo temprano al crear directorio o abrir temporal | Mantener último destino válido y backup anterior, evitar salida parcial si es posible | **Pendiente**: usar solo ruta de prueba reservada y permisos reproducibles, sin manipular archivos ajenos |
| **F4** | Error de escritura/cierre o discrepancia del temporal | No sustituir destino; limpiar temporal; preservar último archivo válido | **Pendiente**: difícil de provocar de modo portable; no simular artificialmente como PASS |
| **F5** | Existe backup antiguo, se elimina y la copia nuevo backup falla | No perder la última copia de recuperación válida sin política explícita | **Riesgo identificable en el orden de operaciones**; requerir fault injection aislado o prueba determinista en capa de I/O con contrato, no asumir falla observada |
| **F6** | Primer `rename(tmp, destino)` falla por restricciones de reemplazo | Evitar ventana insegura de pérdida del archivo previo; no asumir atomicidad en todas las plataformas | **Pendiente**: branch alternativo por plataforma; test CI Linux exitoso no prueba Android/Fedora en error |
| **F7** | Segundo rename falla después de borrar destino | Recuperar desde respaldo; confirmar contenido del archivo restaurado, preservar copia válida y señal de error | **Pendiente**: no se debe provocar sobre datos del usuario; exige ambiente efímero o interfaz de I/O inyectable, revisada previamente |
| **F8** | Se pierde energía/proceso entre borrar destino y renombrar | Estado de archivo/bak potencialmente intermedio | **No demostrable** solo con headless; no prometer tolerancia a corte eléctrico, fsync de directorio o reemplazo atómico universal |
| **F9** | Destino original corrupto y se solicita otro save | Definir si backup debe contener exclusivamente snapshot válido o bytecopy del archivo previo | **Decisión de política abierta**: la implementación actual copia bytes del destino existente sin ejecutar preflight del archivo anterior; el contrato menciona «backup» sin garantizar validación del documento previo |
| **F10** | `restore_from_file` ante destino ausente/incompatible y respaldo presente | Rechazo sin mutar runtime; recuperación manual o explícita según contrato | **Pendiente**, no inventar restauración automática de `.bak`, que hoy no está especificada |

### Prioridad y límites de diseño

- **Alta:** F5 y F7, por la posible pérdida de la última copia válida al hacer operaciones destructivas entre dos salvaguardas; F9, por la ambigüedad de qué significa «respaldo válido».
- **Media:** F3/F4 y F6 (portabilidad/fallos controlados); F10 (política de recuperación).
- **No determinable sin entorno/fault injection:** F8, crash consistency física. No prometer garantías no sustentadas.
- Evitar tests que cambien permisos sobre un directorio general, borren archivos fuera de `user://flujo_fsm_tests/`, alteren `res://` o dependan de `chmod` con significado distinto en Linux/Android. **No crear inyección de fallos en producción silenciosamente**.
- `FileAccess.get_file_as_string(temporary) == json` comprueba igualdad textual de la copia temporal; no prueba que el sistema de archivos haya forzado la persistencia física en disco.
- `DirAccess.rename_absolute` puede comportarse distinto según plataforma; la rama de eliminación/reintento merece pruebas focales reproducibles y, si se cambia, un diseño explícito y evidencias.

## Propuesta de microbloques 9B3

1. **9B3-B1 — contrato de respaldo bajo fallos (documental):** decidir el comportamiento esperado sobre F5/F7/F9/F10: conservar el último backup válido, preferir no perder el destino anterior, y definir si recuperar desde `.bak` es **explícito o automático**. Evitar cambio de formato v1. Si afecta semántica pública, obtener autorización del mantenedor.
2. **9B3-B2 — prueba segura de preflight de I/O:** caracterizar uno o pocos fallos reproducibles que no requieran alterar datos del usuario (por ejemplo, ruta `user://flujo_fsm_tests/` reservada donde un segmento es un archivo, impidiendo crear la subcarpeta). Validar retorno `false`, ausencia de archivos inesperados, estado intacto y preservación de otro guardado válido. Registrar behavior `not_run` y gate obligatorio, luego confirmar CI antes de `passing`.
3. **9B3-C — diseño de recuperación de reemplazo:** si hace falta testear F5–F7, proponer una capa de operaciones de archivo desacoplada o una estrategia de staging de backups con pruebas deterministas; **no** añadir hooks peligrosos ni tocar producción sin contrato aprobado y puertas formales de Skills. Controlar la posibilidad de testear verdaderamente los puntos exactos.
4. **9B3-D — verificación/cierre:** registrar logs y escenarios, corregir solo los defectos demostrados y volver a correr focals + suite integral. Declarar qué garantías sí y no se obtuvieron; no adelantar fase 9 ni fase 10.

**Siguiente turno:** **9B3-B1**, concretar política documental de recuperación sin introducir comportamiento nuevo, y seleccionar primer escenario de test seguro para B2. La política todavía no está congelada para casos de reemplazo fallido, por lo que no anticipar una modificación en `FlowFSMRuntime`.

## Métricas y evidencia

Auditoría basada en archivos versionados y workflows remotos previamente completados; nuevas pruebas ejecutadas en 9B3-A: **0**. Tiempos/latencias, tasas de fallo, pérdida bajo crash y portabilidad de recuperación: **no medidos**. Esta auditoría no cambia `docs/behavior_catalog.json`, porque no se implementó ni reclasificó comportamiento. El CI nuevo de este documento se revisará por separado antes de atribuirle SUCCESS.

*Todo es Flujo; todo fluye.* 🌊
