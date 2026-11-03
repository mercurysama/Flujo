# Potok 8D2-B2B — Rechazo atómico de snapshots inválidos

**Fecha de trabajo:** 2026-11-02 (America/Mexico_City). **Rama:** `feature/fsm-runtime-flow-flusso`. **Resultado:** **PASS técnico en CI**, sin modificaciones de producción. **8D2 completo: NO**.

## Alcance del contrato

Caracterizar `FLU-FSM-003` y la compatibilidad con [`FLU-FSM-004`](fsm_snapshot_contract_v1.md) sin modificar el `FlowFSMSnapshotCodec`. El nuevo test `tests/runtime/flow_fsm_snapshot_preflight_atomicity_test.tscn` usa dos máquinas MANUAL y dos controladores independientes que comparten definiciones authored del mismo `FlowGraph`. En el runtime A hay un alias `PERSISTENT` activo, otro `PERSISTENT` inactivo, un `SESSION` y **tres solicitudes pendientes** (dos directas y un evento); el controlador B retiene una cola y un registro separados.

La prueba crea un snapshot `format_version=1` válido y **23 variantes inválidas** a partir de copias independientes: formato, identidad de grafo o schema, colecciones y registros de tipos incorrectos, máquina omitida o repetida, estado activo desconocido o referencia a alias no persistente, máquina dinámica ajena, colisiones authored, alias y plantilla inválidos, lifetime incorrecto, datos no serializables (incluido `Callable`), profundidad superior a la permitida, ID duplicado y exceso del cupo por máquina. Esto **amplía** y **no sustituye** las pruebas previas de FSM-004.

En cada rechazo se comprueba conjuntamente que **no cambian** ambos estados activos, registros e IDs, datos anidados, snapshots del runtime vivo, solicitudes pendientes ni trazas de `StateExit`/`StateEnter`/commits. La otra instancia tampoco puede sufrir efectos indirectos. Después de las 23 negativas, un snapshot válido sí se restaura, ejecuta los `Exit` de ambas máquinas y los `Enter` de ambas en orden, limpia la cola vieja y elimina la entrada transitoria no guardada; los datos persistentes se copian profundamente y no alteran el grafo. B conserva su cola hasta su tick independiente.

## Historial y evidencia verificable

- **Baseline:** `8583cbdc0e8bf01e98364d19671bd162b65f488d`, [Actions 41579978091](https://github.com/mercurysama/Flujo/actions/runs/41579978091) **SUCCESS 93/93**.
- **Primer commit focal:** `cb32badbe432e1cd8060d182cbf155597e9b046d`, añade escena `.gd/.tscn`, gate obligatorio `Potok-8D2B2B snapshot invalid preflight atomicity focal` en `.github/workflows/flujo-fsm.yml`, catálogo `FLUJO-BHV-POTOK-SNAPSHOT-ATOMIC-004` inicialmente `not_run`. [Actions 41581962872](https://github.com/mercurysama/Flujo/actions/runs/41581962872) **FAIL**, porque los escenarios de fila malformada trataban de introducir una cadena en un arreglo tipado `Array[Dictionary]` generado por el propio codec. Godot bloqueó esa mutación de fixture y el error desencadenó fallos posteriores. **No fue evidencia de un defecto productivo.**
- **Corrección focal test-only:** commit `32f6ab6a95ccb31c51dac882be578180afbe9dd4`, en las dos variantes de registros inválidos se construye expresamente una copia `Array` no tipada para representar fielmente el documento malformado antes de llamar al preflight. No se cambió ninguna aserción del contrato, se preservaron los **23 casos**.
- **CI definitivo:** [Actions 41582200667](https://github.com/mercurysama/Flujo/actions/runs/41582200667), Godot **4.7.2**, **completed SUCCESS 94/94** con focal B2B PASS, catálogo y todas las regresiones PASS, sin omisiones. La entrada `FLUJO-BHV-POTOK-SNAPSHOT-ATOMIC-004` cambia `not_run` → `passing` **después** del resultado. Los dos intentos y el motivo del primer fallo permanecen documentados.

## Justificación, reservas y continuidad

No se editaron `addons/vp_flujo/runtime/`, codec de fase 9, esquemas, `main`, `demo/main.tscn` ni interfaz. La validación sobre candidato desacoplado ya satisface estos rechazos en el comportamiento inspeccionado; se descartó refactorizar o cambiar formato/semántica porque no existe una falla productiva reproducida. La prueba caracteriza `restore_snapshot` y **no certifica todo `restore_from_file`** ni autoriza un cierre prematuro de FSM-004/Fase 9.

**Limitaciones:** Godot local/Flatpak **NOT RUN**; Skills versionadas `flujo-baseline`/`flujo-prove` consultadas como documentación, **no invocadas formalmente**. Aceptación humana de la fase 7: **0/25** (15 Fedora y 10 Android), diferida por el mantenedor. Tiempo de trabajo, revisión visual y demás métricas no verificadas: **not measured**.

**Siguiente microbloque 8D2-B3A:** verificar determinismo de entradas, orden de máquinas, colas y resets entre dos instancias independientes con IDs explícitos conocidos. Conservar límites de presupuesto y no exigir igualdad de IDs generados al azar. Luego 8D2-B3B (callbacks y guardas) y 8D2-C (auditoría), **sin declarar terminada la fase 8**.

*Todo es Flujo; todo fluye.* 🌊
