# Potok 9B2-B — Cierre técnico de matriz de rutas FSM-004

**Fecha:** 2026-11-03 (America/Mexico_City). **Rama:** `feature/fsm-runtime-flow-flusso`. **Resultado: PASS automatizado integral** del contrato de rutas en su cobertura documentada.

- **Test focal:** `tests/runtime/flow_fsm_snapshot_path_matrix_test.tscn` (GDScript correspondiente), comportamiento `FLUJO-BHV-POTOK-SNAPSHOT-PATH-POLICY-013`; gate obligatorio en `.github/workflows/flujo-fsm.yml`.
- **Evidencia GREEN:** [Actions 41658845225](https://github.com/mercurysama/Flujo/actions/runs/41658845225) **completed SUCCESS** sobre `85e5b7f03c401c0186b4745e9d2abc8c0bc48eb9`; **103/103 pasos completed, cero fallos**, incluido `Potok-9B2A user snapshot write and restore path matrix focal`. El catálogo se actualiza **`not_run → passing` solo después** de esa verificación.
- **Historial RED conservado:** [Actions 41658231067](https://github.com/mercurysama/Flujo/actions/runs/41658231067) terminó FAILURE únicamente en la aserción final de igualdad directa entre Dictionary antes/después de JSON. El ajuste de fixture en `85e5b7f` normalizó ambos lados vía `JSON.parse_string(JSON.stringify(...))`, preservando pruebas de rutas, cola, alias, datos y estado.
- **Garantías dentro de la prueba:** rutas permitidas `user://` en raíz y subcarpeta de test; rechazo de rutas relativas, `res://`, absolutas, traversal, barra inversa y extensiones inválidas; rechazo sin mutación del estado activo ni pérdida de solicitud pendiente; restauración válida posterior con alias persistente y datos; limpieza de archivos de test.
- **Límites:** no se ha probado filesystem hostil, symlinks, acceso fuera de sandbox por rutas normalizadas especiales, fallo a mitad de guardado, interrupción eléctrica o recuperación de backup ante fallo de rename. Son asuntos para **9B3**; no se infiere seguridad universal a partir de esta matriz.
- **Control:** no se cambia `FlowFSMRuntime`, codec, `FlowGraph`, esquema, editor, `demo/main.tscn` o `main`. Pruebas humanas 15 Fedora + 10 Android = **0/25 diferidas**. Godot local no ejecutado; las Skills versionadas no se invocaron formalmente. El checkpoint documental 9B2-B requiere su propio CI separado.

**Siguiente 9B3-A:** caracterizar riesgos de respaldo/reemplazo mediante una auditoría test-first de escenarios de error realmente reproducibles sin manipular datos del usuario. Separar operaciones detectables con permisos/rutas de fallos inyectados no reproducibles; confirmar semántica de `.bak`, `.tmp`, rename y restore. No cambiar runtime sin RED contrastado y autorización de contrato.

*Todo es Flujo; todo fluye.* 🌊
