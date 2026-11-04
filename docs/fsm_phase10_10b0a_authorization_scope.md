# Potok 10B-0A — Registro de autorización contextual G1–G6

**Fecha:** 2026-11-03. **Rama:** `feature/fsm-runtime-flow-flusso`. **Base:** `796b09c406abea5b2c8a5997ed7ae2ad97fcf75a`. **Ámbito:** exclusivamente el **core portable de observabilidad** (DEBUG-FSM), sin interfaz Godot ni controles de pausa.

## Evidencia de autorización y alcance

En la conversación actual, después de presentar exactamente la pregunta «¿apruebas G1–G6 tal como están propuestos, incluyendo 128 registros, límite de 1024 bytes por registro, captura desactivada por defecto y consultas de solo lectura? G7 y G8 quedarían para después», el responsable respondió `🙆🏻`. La respuesta es **directa a esa pregunta de aprobación**, no un emoji aislado de continuidad de un lote sin decisiones. Se interpreta como **asentimiento contextual para preparar 10B-core bajo G1–G6**.

**Límite de esta constancia:** no se inventa una declaración textual ni una firma. La gobernanza anterior prohibía convertir un emoji **de continuidad genérica** en aceptación de parámetros; si se exige una constancia verbal literal, esta autorización contextual es **insuficiente para integración productiva** hasta obtener ratificación inequívoca. Este registro autoriza por ahora únicamente las tareas **test-only y planificación** que no requieren decidir semánticas aún abiertas, y no reemplaza `$flujo-baseline`, `$flujo-prove` ni la revisión humana.

## Parámetros concretos sometidos a aprobación

| Gate | Elección a mantener para el núcleo | Restricciones |
|---|---|---|
| **G1** | Historial circular por `FlowFSMRuntime` de **128 registros**, sobreescribir el más antiguo, máximo lógico **1024 bytes UTF-8 JSON/registro** | Definir y probar exceso/truncado sin romper IDs; memoria real **not measured** |
| **G2** | Captura OFF por defecto, incluso en export | Habilitación explícita, ningún cambio de la FSM al no capturar |
| **G3** | Fuente estructurada única por runtime, consulta **por copia y polling read-only** | Sin nuevas señales sincrónicas en el primer corte ni editor |
| **G4** | `admitted`, `delivered`, `considered`, `selected`, `skipped`, `committed`, `deferred`, `rejected` | Cada resultado sólo donde el runtime original efectivamente lo sabe; no reevaluar condiciones |
| **G5** | Exclusivamente datos inertes y sanitizados; no payloads, `Node`, `Resource`, `Callable`, valores arbitrarios | No truncar IDs authored de forma que invente identidades; no datos sensibles |
| **G6** | Snapshot actual para conexión tardía y secuencia/epoch locales | Nunca fingir historial previo al inicio de captura |

**No autorizados:** G7 (adaptador/editor/tab de Godot), G8 (pause/resume/step/edición de valores), cambios de `FlowGraph`, schema o snapshots, `main`, merges, releases, telemetría o recuperación automática `.bak`.

## Puertas obligatorias para código productivo

1. Mantener la [propuesta de contrato v1](fsm_observability_contract_v1_candidate.md), [acta G1–G6](fsm_phase10_10a15_approval_decision_sheet.md) y [plan RED/GREEN](fsm_phase10_10a11_red_green_test_blueprint.md) como referencias. Una API pública concreta y las políticas de cadenas de caracteres necesitan subcontrato probado antes de implementarse.
2. **Invocar formalmente** `$flujo-baseline` con Godot 4.7.2 y registrar un resultado `READY` o `NEW BEHAVIOR`. Un workflow remoto histórico no es una invocación formal.
3. Escribir una fixture RED aislada y guardar fallo real antes de implementar el mínimo GREEN; no introducir un RED permanente en CI obligatorio.
4. Después de GREEN, **invocar formalmente** `$flujo-prove`, ejecutar regresiones e integrar sólo tras evidencia comprobada. Nunca marcar un comportamiento futuro como `passing` sin ejecución.

**Resultado de este microbloque:** decisión contextual delimitada y pruebas preparables; **no se declara implementado ni aceptado para integrar 10B**. El emoji en sí no sustituye los gates técnicos o la ratificación literal si ésta resulta exigible.

*Todo es Flujo; todo fluye.* 🌊
