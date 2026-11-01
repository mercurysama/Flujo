# Flujo — Plan integral de implementación de máquinas de estados (FSM)

**Versión del plan:** 1.0 (propuesta técnica para revisión)  
**Fecha de elaboración:** 1 de noviembre de 2026  
**Proyecto:** Flujo, complemento de programación visual para Godot 4.7.2  
**Rama consultada:** `feature/block-builder-fprint-dogfood`  
**Rama de implementación:** `feature/fsm-runtime-flow-flusso`  
**Estado:** planificación; **no se ha implementado este plan ni ejecutado sus pruebas**.

> **Principio rector:** la máquina de estados debe ser funcional con un solo estado; Flujo impone integridad de datos, referencias válidas y ejecución determinista, pero no fuerza al programador a crear estados, comportamientos o transiciones artificiales. Las definiciones de `FlowGraph` son compartibles; la ejecución mutable pertenece exclusivamente a la instancia de `PVController`.

## 1. Objetivo, alcance y resultado esperado

Construir un sistema de máquinas de estados finitos (FSM) que permita declarar, ejecutar, configurar, depurar y conservar estados mediante la interfaz visual **Fluo** (panel **Flow** y configuración **Flusso**), sin depender del editor de Godot en juegos exportados. El sistema debe ejecutar `enter`, `update` y `exit`, gestionar transiciones por condiciones y eventos, permitir varias máquinas simultáneas y coordinadas, incorporar estados dinámicos y restaurar los que se hayan marcado como persistentes. La implementación debe reutilizar, cuando sea viable, el ejecutor de bloques y el sistema de valores ya existentes en Flujo, sin romper los procesos `Ready` y `Timer`.

**Se considera terminada** cuando una escena con un `PVController` puede ejecutar una o varias FSM configuradas visualmente, reaccionar a eventos y condiciones, admitir cambios seguros en tiempo de ejecución, guardar/restaurar su estado, mostrar diagnósticos útiles y aprobar una matriz automatizada y manual reproducible. La aceptación debe realizarse en Godot 4.7.2; las pruebas Android y de orientación táctil son una etapa explícita, no una suposición.

### 1.1 Estado de partida verificado

- **Existe:** `FlowGraph.state_machines`, `FlowStateMachineDefinition`, `FlowStateDefinition`, identificadores internos estables, selección `initial_state_id`, validación de identidad/referencias, duplicación profunda y persistencia mediante recursos y escenas.
- **Existe en la rama consultada:** ejecución `Ready`/`Timer` para los esquemas 3 y 4 por `FlowReadyExecutor`, con `FlowNavigationDecision` (`CONTINUE`, `JUMP`, `STOP`) y resolución de valores; hay almacenamiento por instancia en trabajo para el esquema 5, con límites distintos.
- **Existe en la interfaz:** Fluo/Flow/Flusso, comandos de edición y mecanismos genéricos para bloques y propiedades; todavía no constituyen por sí solos un editor FSM completo.
- **No está demostrado como funcional:** planificador FSM, `enter/update/exit`, evaluador y cola de transiciones, coordinación entre máquinas, registro dinámico, instantáneas de FSM y panel de depuración específico.
- **Advertencia de compatibilidad:** el ejecutor `FlowReadyExecutor` no ejecuta el esquema 5 en la implementación examinada. **No debe** ampliarse a los cinco esquemas por simple cambio de condición: primero se necesita el contrato propio de ejecución o compatibilidad del esquema 5.

### 1.2 Decisiones heredadas y propuestas nuevas

**Acuerdos que se deben respetar:** máquina válida con un estado; máquina vacía solo como borrador, no como ejecutable; IDs estables; varias máquinas dentro del mismo programa; solicitudes cruzadas de cambio por evento o ID; cambios solicitados encolados para evitar reentrancia; ciclo `enter/update/exit`; runtime por instancia; estados creados dinámicamente; separación de persistencia `EPHEMERAL`, `SESSION` y `PERSISTENT`; interfaz a través de Flow y Flusso, sin duplicar una lista `Blocks` en el Inspector; pruebas humanas concentradas al final de los lotes cuando sea técnicamente seguro.

**Propuestas sujetas a revisión en este plan:** nombres exactos de nuevas clases, formato de transiciones, políticas detalladas de prioridades, momento de aplicar cambios, contenido del guardado, modo de tick por máquina, estructura del panel de depuración y nomenclatura final de comandos. Estos elementos deben congelarse en un contrato numerado **antes de modificar código**.

## 2. Arquitectura objetivo y responsabilidades

```text
PVController (un ejemplar por instancia de escena)
  ├─ flow_graph: FlowGraph                         [definiciones, solo lectura]
  │    └─ state_machines: Array[FlowStateMachineDefinition]
  │         └─ states: Array[FlowStateDefinition]
  ├─ FlowFSMRuntime                               [coordinador runtime propuesto]
  │    ├─ FlowMachineRuntime × N                   [estado activo por máquina]
  │    ├─ cola de eventos y solicitudes            [ordenada, acotada]
  │    ├─ registro de estados dinámicos             [por instancia]
  │    └─ servicio de instantáneas                  [solo datos serializables]
  ├─ ejecutor de secuencias de FlowBlock           [compartido con Ready/Timer]
  └─ contexto de valores y diagnósticos            [sin dependencia del editor]

EditorPlugin → Inspector: selecciona la máquina → Fluo
                                       ├─ Flow: estados, fases y bloques
                                       └─ Flusso: propiedades, transiciones y condiciones
Depurador: observa el runtime; no altera FlowGraph ni guarda cambios sin acción explícita.
```

| Componente | Responsabilidad | Prohibiciones / límites |
|---|---|---|
| `FlowStateMachineDefinition` | Declarar nombre, ID, habilitación, estados y estado inicial. | No mantener `current_state` ni modificar la definición en juego. |
| `FlowStateDefinition` | Declarar comportamiento y bloques asociados con sus fases. | No guardar un `Node`, `Callable` ni datos vivos dentro del recurso. |
| `FlowStateTransitionDefinition` *(propuesta)* | Declarar origen/destino, disparador, condición, prioridad y acciones. | No usar nombres visibles o índices como destino estable. |
| `FlowFSMRuntime` *(propuesta)* | Coordinar inicio, tick, eventos, colas, transición y detención de máquinas. | No depender de `EditorPlugin` ni editar recursos persistentes. |
| `FlowMachineRuntime` *(propuesta)* | Mantener máquina activa, estado actual, historial mínimo y estados dinámicos. | No compartir su estado mutable entre instancias de escena. |
| Ejecutor reutilizable de bloques | Ejecutar una secuencia de bloques con contexto, navegación y presupuesto. | No codificar reglas especiales por clase concreta de bloque. |
| Adaptadores editor | Mostrar y modificar declaraciones con Undo/Redo y Fluo. | No convertirse en fuente de verdad de los datos runtime. |
| Persistencia FSM | Guardar/restaurar datos declarados, IDs y valores compatibles. | No serializar scripts, código arbitrario, objetos vivos ni credenciales. |

### 2.1 Contrato del modelo: cambios mínimos recomendados

Se recomienda conservar `FlowStateDefinition.blocks` como **secuencia `update` de compatibilidad**, e incorporar secuencias `enter_blocks` y `exit_blocks` solo si la auditoría concluye que ese cambio puede versionarse y migrarse de forma segura. Si se prefiere un recurso especializado por fase, deberá demostrarse equivalencia de orden, IDs, `null`, duplicación y serialización. El criterio es mantener la lógica existente de `blocks` sin borrarla ni reasignar silenciosamente su significado. Las transiciones se declaran por ID de destino, con origen definido por contención o `from_state_id` según el contrato definitivo; no se almacenan punteros directos a otros estados como identidad. **Toda incorporación persistente debe pasar por una revisión de compatibilidad de `schema_version`; cuando cambie el contrato serializado se requiere migración explícita y probada.**

## 3. Catálogo de requerimientos trazables

| ID | Requisito verificable | Prioridad | Entrega |
|---|---|---|---|
| FSM-R01 | Una FSM con un único estado es válida y ejecutable. | Crítica | FSM-001 |
| FSM-R02 | Una FSM sin estados puede editarse, pero no iniciar ejecución. | Crítica | FSM-001 |
| FSM-R03 | Cada FSM activa posee un `initial_state_id` resoluble dentro de ella. | Crítica | FSM-001 |
| FSM-R04 | Los IDs sobreviven renombrado/reordenamiento; duplicar produce IDs nuevos y referencias remapeadas. | Crítica | FSM-001 |
| FSM-R05 | `enter` se ejecuta una vez al entrar, `update` en cada tick y `exit` una vez al salir. | Crítica | FSM-001 |
| FSM-R06 | Deshabilitar máquina o `PVController` detiene su ejecución sin mutar definiciones. | Crítica | FSM-001 |
| FSM-R07 | Dos instancias de la misma escena mantienen estados activos y valores aislados. | Crítica | FSM-001 |
| FSM-R08 | Los bloques reutilizan el ejecutor genérico sin regresiones de Ready/Timer. | Crítica | FSM-001 |
| FSM-R09 | Se admiten transiciones condicionales tipadas, verificadas y con destino válido. | Crítica | FSM-002 |
| FSM-R10 | Se admiten transiciones por eventos emitidos por bloques o sistema. | Alta | FSM-002 |
| FSM-R11 | Las solicitudes de cambio se encolan y procesan de forma determinista. | Crítica | FSM-002 |
| FSM-R12 | La máquina define un orden inequívoco cuando coinciden varias transiciones. | Crítica | FSM-002 |
| FSM-R13 | Varias FSM pueden funcionar simultáneamente bajo el mismo `PVController`. | Alta | FSM-002 |
| FSM-R14 | Una FSM puede pedir cambios en otra por ID estable, con diagnóstico si no existe. | Alta | FSM-002 |
| FSM-R15 | Los cambios cíclicos/reentrantes tienen presupuesto y política de contención. | Crítica | FSM-002 |
| FSM-R16 | El runtime permite `register_state`, `has_state`, `change_state` y `remove_state`. | Alta | FSM-003 |
| FSM-R17 | Los estados dinámicos se almacenan solo en el runtime de su controlador. | Crítica | FSM-003 |
| FSM-R18 | Borrar un estado activo exige una política explícita de salida segura. | Crítica | FSM-003 |
| FSM-R19 | El estado dinámico admite identidad, origen, datos y ciclo de vida verificables. | Alta | FSM-003 |
| FSM-R20 | `EPHEMERAL`, `SESSION` y `PERSISTENT` poseen semánticas documentadas. | Alta | FSM-004 |
| FSM-R21 | El guardado/restauración valida versión, graph ID, machine ID y state ID. | Crítica | FSM-004 |
| FSM-R22 | Persistencia no guarda código, `Node`, `Resource` arbitrario ni `Callable`. | Crítica | FSM-004 |
| FSM-R23 | El Inspector abre máquinas existentes en Fluo sin lista `Blocks` duplicada. | Alta | UI-FSM |
| FSM-R24 | Flow y Flusso permiten crear/editar/reordenar estados, fases y transiciones. | Alta | UI-FSM |
| FSM-R25 | Las ediciones persistentes ofrecen Undo/Redo, foco y teclado completos. | Crítica | UI-FSM |
| FSM-R26 | Las condiciones visuales aprovechan `FlowConditionValueSource`/Tok `#` cuando el contrato sea compatible. | Alta | UI-FSM |
| FSM-R27 | Se muestran estado activo, eventos, transiciones, errores y referencias rotas. | Alta | DEBUG-FSM |
| FSM-R28 | Editar valores del depurador no reescribe el grafo ni la escena implícitamente. | Crítica | DEBUG-FSM |
| FSM-R29 | Hay pruebas de modelo, runtime, persistencia, editor, regresión y Android. | Crítica | GATE-FSM |
| FSM-R30 | Todos los lotes tienen evidencia, trazabilidad, contrato y aprobación humana antes de integración. | Crítica | GATE-FSM |

## 4. Secuencia de implementación completa

### Fase 0 — Baseline, alcance y especificación ejecutable

**Objetivo.** Proteger el comportamiento actual antes de incorporar FSM y establecer las decisiones que no pueden dejarse al azar.

**Pasos de implementación:**
1. Crear una rama de trabajo FSM desde una referencia verificada; registrar SHA, estado limpio, esquema(s) presentes y las rutas protegidas. No trabajar sobre una copia desactualizada sin conciliar diferencias.
2. Leer `docs/constitution.md`, `docs/current_iteration.md`, `docs/model_contract.md`, `docs/project_memory.md` y los contratos de chips/Toks, runtime y navegación pertinentes. Leer `AGENTS.md` y el catálogo de comportamiento.
3. Invocar **explícitamente** el procedimiento versionado `$flujo-baseline` antes de cualquier cambio funcional y ejecutar las focales relevantes. Registrar fallos preexistentes; no corregirlos de forma silenciosa dentro del lote FSM.
4. Fijar la matriz de esquemas compatibles: distinguir definición declarativa de FSM y posibilidad real de ejecutarla en esquemas 2/3/4/5. Ningún esquema queda soportado por analogía; el soporte se demuestra por prueba.
5. Aprobar el diseño del tick (`_process` o `_physics_process`, o configuración por máquina), política de colas, prioridad, reinicio, deshabilitación, borrado del estado activo y persistencia.
6. Publicar `docs/flow_fsm_contract.md` con `FSM-R01…FSM-R30`, decisiones explícitas, invariantes, migraciones necesarias y escenarios de aceptación. Registrar estas capacidades en `docs/behavior_catalog.json`.

**Entregables.** Contrato numerado; matriz de alcance por esquema; inventario de tests baseline; catálogo de comportamiento y plan de pruebas. **Criterio de cierre:** no hay decisiones abiertas que alteren identidad, serialización, aislamiento, ciclo o determinismo.

### Fase 1 — Modelo de FSM, ciclo de vida y migración segura (FSM-001/A)

**Objetivo.** Transformar la definición de FSM existente en una descripción completa, editable y validable de comportamiento, sin confundirla con el runtime.

**Pasos de implementación:**
1. Conservar los campos existentes de `FlowStateMachineDefinition` y `FlowStateDefinition`; documentar la política del campo legado `is_initial`: solo para migraciones antiguas, nunca autoridad de ejecución.
2. Representar los bloques de fase: conservar `state.blocks` como `update` de compatibilidad y añadir `enter`/`exit` mediante una representación concreta aprobada; validar orden y posiciones `null` de cada secuencia.
3. Definir la semántica de `enabled` en máquina, estado y bloque. Propuesta: máquina deshabilitada no inicia; estado inicial deshabilitado produce diagnóstico; bloque deshabilitado se omite, como en el ejecutor existente.
4. Mantener la regla de inicialización: al añadir el primer estado válido a una máquina vacía, asignar su ID inicial; nunca crear un segundo estado artificial. Permitir cero estados en borrador y producir diagnóstico al intentar ejecutar.
5. Añadir diagnósticos tipados para estado ausente, inicial inválido, definición duplicada, fase dañada y referencia no resoluble. Los validadores solo observan y **no reparan** recursos.
6. Extender duplicación profunda/migración: IDs nuevos para elementos persistentes duplicados, mapa old→new completo antes de remapear referencias, conservación de orden y `null`, fracaso atómico de migración.
7. Probar guardado/reapertura `ResourceSaver`, `PackedScene`, escenas instanciadas y migración desde grafos heredados.

**Funcionalidad visible al cierre.** Es posible definir una FSM válida de un estado con tres fases y guardarla de modo seguro; todavía no se afirma que se ejecute. **Criterio de aceptación:** toda definición válida pasa pruebas; toda estructura inválida produce diagnóstico estable y no se modifica sola.

### Fase 2 — Estado de ejecución aislado por `PVController` (FSM-001/B)

**Objetivo.** Disponer de un espacio mutable por escena, sin escribir nunca en `FlowGraph` ni compartir estado activo entre copias de la escena.

**Pasos de implementación:**
1. Diseñar `FlowFSMRuntime` como servicio runtime propiedad de `PVController` y `FlowMachineRuntime` como contexto de cada máquina: `machine_id`, `active_state_id`, `started`, `paused`, `last_transition`, contadores y catálogo dinámico local.
2. Crear el runtime durante la inicialización normal del controlador; impedirlo bajo `Engine.is_editor_hint()` y respetar `visual_program_enabled` y `is_inside_tree()`.
3. Resolver máquinas por **ID estable**, no por nombre, índice o ruta. Rechazar duplicados y máquinas deshabilitadas con diagnósticos.
4. Establecer `start`, `stop`, `reset`, `pause`, `resume` y consulta `get_active_state_id` con resultados explícitos (`ok/error_code`), evitando silencios ambiguos.
5. Definir ciclo de destrucción al salir de la escena; desconectar eventos, cancelar solicitudes pendientes y liberar referencias a objetos vivos; no dejar temporizadores huérfanos.
6. Probar dos `PVController` que compartan el mismo `FlowGraph`: cada uno debe iniciar y cambiar de estado independientemente. Probar reinicio, reentrada al árbol y desactivación.
7. Aislar este servicio del almacenamiento de atributos Schema 5 ya presente: puede reutilizar principios comunes, pero no modificar ni asumir su semántica.

**Funcionalidad al cierre.** Las FSM pueden tener un estado activo por instancia y mantener su ciclo de vida básico. **Criterio de aceptación:** ninguna operación runtime muta definición, `Resource` compartido ni estado de otra instancia.

### Fase 3 — Núcleo reutilizable para ejecutar bloques por fase (FSM-001/C)

**Objetivo.** Ejecutar bloques `enter/update/exit` sin copiar la lógica de `FlowReadyExecutor` ni introducir un ejecutor incompatible.

**Pasos de implementación:**
1. Caracterizar `FlowReadyExecutor._execute_blocks`: navegación `CONTINUE/JUMP/STOP`, salida, llamadas a método, diagnóstico, límite de pasos y contexto de valores.
2. Extraer o adaptar **solo el núcleo compartible** a una unidad runtime orientada a `FlowBlockContainer`/secuencia; mantener intacta la API pública y semántica de Ready/Timer mediante adaptadores o delegación.
3. Permitir contexto de ejecución que identifique `controller_id` contextual, `machine_id`, `state_id`, fase (`ENTER/UPDATE/EXIT`), `delta`, evento y origen de transición, sin guardar referencias vivas en el modelo.
4. Mantener compatibilidad con `FlowValueResolutionContext` y fuentes de valores existentes. Si una fuente no es ejecutable en determinado esquema, emitir error preciso; no sustituir un valor por defecto de forma silenciosa.
5. Reutilizar los bloques externos del SDK por contrato genérico. No escribir variantes `StatePrint`, `TimerPrint` ni excepciones por tipo concreto de bloque.
6. Conservar un presupuesto de navegación de bloques y aislar fallos: un bloque defectuoso no debe provocar bucles infinitos ni corromper el estado de otras máquinas.
7. Ejecutar regresiones Ready/Timer, métodos sin argumentos, navegación, FPrint/SDK, tipos de salida y persistencia antes y después de la extracción.

**Funcionalidad al cierre.** Una secuencia de bloques en cualquier fase puede ejecutarse mediante el núcleo común. **Criterio de aceptación:** no hay cambio no autorizado en el comportamiento observable de Ready/Timer.

### Fase 4 — Inicio y ciclo `enter → update → exit` (FSM-001/D)

**Objetivo.** Completar la primera FSM realmente ejecutable, incluso con un solo estado y ninguna transición.

**Pasos de implementación:**
1. Al iniciar una máquina válida, establecer su ID inicial en el runtime y ejecutar `enter` exactamente una vez.
2. Implementar el tick según el modo aprobado. Cada tick del estado activo ejecuta su secuencia `update` una sola vez con el `delta` correspondiente; no reentrar si ya se procesa.
3. Al detener o reiniciar, definir y probar si se llama `exit` (propuesta: salida normal sí, terminación por destrucción se documenta expresamente); evitar doble `exit`.
4. Definir qué sucede con una máquina sin transiciones: continúa en su único estado hasta recibir `stop/reset` u otra solicitud explícita.
5. Registrar señales runtime observables (`machine_started`, `state_entered`, `state_updated` cuando sea apropiado para depuración, `state_exited`, `machine_stopped`) sin alterar las definiciones.
6. Probar secuencia de llamadas y conteos, `delta`, pausa/reanudación, deshabilitación y casos de error.

**Criterio de cierre FLU-FSM-001.** Una FSM de un estado imprime o ejecuta el bloque esperado en `enter`, ejecuta `update` por tick, ejecuta `exit` al terminar y no necesita un segundo estado. Se demuestra aislamiento por instancia y ausencia de regresión Ready/Timer.

### Fase 5 — Transiciones condicionadas y por eventos (FSM-002/A)

**Objetivo.** Convertir la FSM de un estado en una máquina capaz de cambiar de estado por reglas de autoría.

**Pasos de implementación:**
1. Aprobar el recurso de transición con ID propio, destino por ID, habilitación, disparador (`CONDITION`, `EVENT`, `REQUEST` u otra taxonomía aprobada), condición tipada, prioridad y orden estable; no depender de texto visible como identidad.
2. Integrar condiciones con la representación de valores ya existente, preferentemente `FlowConditionValueSource`/Tok `#` cuando pueda verificarse que produce un booleano evaluable en runtime. No interpretar una cadena de texto como código.
3. Definir cuándo se evalúan condiciones: propuesta, después de `update` de la máquina y antes del commit de transiciones; el resultado debe leerse una vez por decisión bajo el contexto de ese tick.
4. Implementar eventos dirigidos o locales con payload tipado y alcance explícito. Distinguir emisión, recepción y consumo; no duplicar eventos por el orden de los listeners.
5. Determinar resolución de conflictos: propuesta, prioridad explícita descendente, después posición de declaración ascendente y finalmente ID estable como desempate diagnóstico; **una transición confirmada como máximo por máquina y tick**.
6. Producir solicitud de cambio en lugar de llamar recursivamente `exit/enter` durante un bloque; procesar solicitudes en el punto de commit aprobado.
7. Ejecutar `exit` del origen, cambiar `active_state_id` de forma atómica y ejecutar `enter` del destino. No ejecutar `update` del destino en ese mismo tick salvo decisión contractual explícita.
8. Rechazar destino inexistente, ID de otra máquina, condición no booleana, evento mal formado o transición deshabilitada con diagnóstico estable.
9. Probar transiciones manuales, verdadero/falso, evento consumido/no consumido, varias candidatas y autorreferencia al mismo estado (política explícita: ignorar o reiniciar fases, nunca implícita).

**Funcionalidad al cierre.** Los estados cambian con reglas y eventos, manteniendo ejecución predecible. **Criterio:** transiciones atómicas, sin saltos a recursos inexistentes ni reevaluaciones recursivas.

### Fase 6 — Varias máquinas, solicitudes cruzadas y límites de seguridad (FSM-002/B)

**Objetivo.** Permitir varias FSM simultáneas y comunicación controlada entre ellas sin acoplar sus recursos o crear ciclos incontrolables.

**Pasos de implementación:**
1. Crear un registro `machine_id → runtime` por `PVController`; no utilizar `display_name` para localizar la máquina.
2. Introducir solicitud `request_transition(target_machine_id, target_state_id, reason/payload)` y `emit_event(target_machine_id, event_id, payload)` con validación de IDs y resultado explícito.
3. Encolar cambios cruzados hasta el final del ciclo aprobado. Propuesta: orden de máquina declarado + orden FIFO por secuencia de recepción; no ejecutar una solicitud dentro del callback que la creó.
4. Definir límites por tick: presupuesto de eventos, solicitudes y transiciones; al excederlo, generar diagnóstico de saturación y detener **la cadena afectada**, no todo el juego.
5. Probar que una máquina A puede solicitar cambio en B, que B no depende del orden accidental de los nodos de escena, y que una solicitud hacia una máquina borrada/deshabilitada se rechaza sin efectos secundarios.
6. Implementar política de reentrada: callbacks de `exit/enter` pueden emitir nuevas solicitudes para el **siguiente** tick, no forzar ejecución anidada.
7. Someter los casos A→B→A, ráfagas de eventos, prioridades iguales y máquinas múltiples a pruebas deterministas repetibles.

**Criterio de cierre FLU-FSM-002.** Dos o más máquinas pueden funcionar y comunicarse sin referencias por nombre, sin recursión y con resultado repetible ante los mismos eventos.

### Fase 7 — Autoría visual FSM en Inspector, Flow y Flusso (UI-FSM)

**Objetivo.** Permitir que alguien configure las FSM sin programar manualmente archivos `.gd` ni navegar un árbol duplicado de propiedades.

**Pasos de implementación:**
1. Mantener la fila **State Machines** en el Inspector como entrada al sistema. Doble clic o Enter sobre una máquina existente abre **Fluo**; no insertar una lista redundante `Blocks` en el Inspector.
2. En **Flow** representar la máquina y su árbol de estados: estado inicial, estados adicionales, fases `Enter/Update/Exit`, secuencias y Add de bloques. Mostrar `Empty` como borrador cuando no haya estados.
3. En **Flusso** editar nombre, habilitación, nota, estado inicial, propiedades del estado, transiciones, disparadores y prioridad; aprovechar el renderer genérico de propiedades y el ecosistema de bloques cuando sea compatible.
4. Integrar el editor Condition Tok `#` en campos de condición mediante `FlowChipFieldSchema` validado. Confirmar solo con condición completa; Cancel no modifica el documento; Escape cierra según la jerarquía vigente.
5. Definir comandos Undo/Redo atómicos para crear, renombrar, reordenar, duplicar y eliminar estados/transiciones, además de cambiar fase, condición o estado inicial; validar candidato **antes** de registrar una edición destructiva.
6. En eliminación, mostrar dependencias afectadas y ofrecer cancelación real. No borrar ni reparar referencias cruzadas automáticamente sin una acción explícita.
7. Respetar navegación de teclado y foco de Fluo: Enter y doble clic, Up/Down, PageUp/PageDown, Ctrl+PageUp/PageDown, Alt+PageUp/PageDown, Revertir y restauración del foco. No sobrescribir atajos generales.
8. Validar táctil Android, scroll horizontal/vertical, orientación, tamaños, doble toque y jerarquía de Escape de manera específica; una carga visual de Android no significa que estas interacciones aprobaron.
9. Guardar la escena, reabrirla y comparar IDs, orden, estados, transiciones y contenido de chips; comprobar Undo/Redo repetido.

**Criterio de cierre.** Un usuario puede crear una FSM de un estado, agregar uno segundo, configurar una transición y ejecutar el resultado usando el flujo normal Inspector→Fluo→Flow/Flusso.

### Fase 8 — Estados dinámicos de runtime (FSM-003)

**Objetivo.** Registrar, consultar, cambiar y retirar estados durante el juego, sin escribir nuevas definiciones en `FlowGraph`.

**Pasos de implementación:**
1. Definir API: `register_state(machine_id, state_template_id, runtime_id?, lifetime, data)`, `has_state(machine_id, state_id)`, `change_state(machine_id, state_id)`, `remove_state(machine_id, state_id, fallback_state_id?)`. Nombres y signaturas definitivos sujetos al contrato.
2. Mantener catálogo dinámico **por instancia**: ID runtime estable durante su vida, referencia a plantilla autorizada y datos serializables; jamás agregar el estado dinámico a `FlowStateMachineDefinition.states` durante ejecución.
3. Validar plantillas/estructura antes del registro. Una plantilla debe pertenecer al grafo, paquete instalado o catálogo permitido por el contrato, y ser compatible con el runtime activo.
4. Implementar colisiones de IDs (rechazo explícito), doble registro (política de idempotencia aprobada), orden determinista y límite configurable de estados registrados.
5. Si se elimina el estado activo, exigir una transición segura a un estado válido o detener la máquina con diagnóstico; jamás apuntar a un ID eliminado.
6. Definir la destrucción de transiciones, eventos y solicitudes pendientes que apunten al estado retirado. Limpiar en un solo punto de commit con comprobaciones de integridad.
7. Permitir que los bloques oficiales o externos invoquen las APIs a través de servicios autorizados del contexto runtime, sin obtener acceso mutable al `FlowGraph`.
8. Probar estado agregado, activado, desactivado, eliminado, re-registrado, duplicado entre controladores y eliminación con referencias pendientes.

**Criterio de cierre FLU-FSM-003.** Un personaje puede adquirir temporalmente un estado nuevo (por ejemplo, `Aturdido`), activarlo y retirarlo con el grafo original intacto.

### Fase 9 — Persistencia, sesión y restauración segura (FSM-004)

**Objetivo.** Conservar únicamente los datos autorizados de una FSM y restaurarlos sin ejecutar código no previsto ni dejar referencias corruptas.

**Pasos de implementación:**
1. Congelar el significado de las políticas: **propuesta** `EPHEMERAL` vive hasta reset/destrucción y nunca se guarda; `SESSION` vive durante la sesión actual y se pierde al cerrarla; `PERSISTENT` participa en una instantánea versionada. Precisar si `SESSION` sobrevive recarga de escena antes de implementar.
2. Diseñar una instantánea simple y versionada: `format_version`, `graph_id`, `controller_instance_key` si aplica, máquinas `{machine_id, active_state_id, started/paused}`, estados dinámicos persistentes `{state_id, template_id, data}` y valores admitidos; excluir objetos vivos y eventos transitorios.
3. Crear exportación a Dictionary/JSON o recurso de datos seguro, con validación de tipos y límites (tamaño/profundidad/conteos). El archivo no contiene script fuente, bytecode, `Callable`, `NodePath` arbitrario ejecutable ni referencias vivas a Nodes.
4. Guardar de manera atómica: construir y validar instantánea, escribir temporal, verificar y reemplazar; conservar respaldo o archivo anterior ante error de escritura. No sobrescribir un guardado válido con datos parciales.
5. Restaurar en dos fases: **prevalidación** de versión, IDs, plantillas y compatibilidad; **commit** único al runtime cuando todo sea válido. Si falla, mantener estado actual o arrancar desde inicial según la política explícita.
6. Documentar qué callbacks se ejecutan al restaurar: propuesta, restauración marca el estado activo y ejecuta `enter` una vez al reanudar; evitar `exit` de un estado que nunca llegó a iniciar. Confirmar esta regla en contrato.
7. Definir estrategia para cambios de versión del grafo: migrar instantáneas mediante funciones explícitas o rechazar con diagnóstico; nunca adivinar nombres o índices.
8. Probar lectura y escritura, corrupción, guardado interrumpido, estado/plantilla faltante, cambio de versión, múltiples controladores y coexistencia de estados con políticas diferentes.

**Criterio de cierre FLU-FSM-004.** Un estado dinámico persistente se restaura tras volver a iniciar el juego, mientras estados `EPHEMERAL` y `SESSION` respetan exactamente su política documentada.

### Fase 10 — Observabilidad y depuración (DEBUG-FSM)

**Objetivo.** Hacer verificable qué sucede en cada máquina sin alterar los datos de autoría.

**Pasos de implementación:**
1. Emitir eventos runtime estructurados: máquina, estado origen/destino, tipo de solicitud, causa, tick/secuencia, resultado y código de diagnóstico. Mantener una bitácora circular acotada.
2. Mostrar en el depurador la lista de máquinas, ID/nombre, estado inicial y activo, fase actual, eventos recibidos, transiciones candidatas y última transición aplicada.
3. Diferenciar errores de definición, validación de condición, falta de destino, overflow de cola, estado dinámico inválido y restauración incompatible.
4. Permitir inspección de variables del contexto de valores sin escribir automáticamente sobre recursos, escenas o paquetes. Si existe edición en vivo, limitarla al runtime y exigir acción explícita.
5. Diseñar controles de pausa/reanudación/avance de un tick adecuados para debug; su disponibilidad en exportación debe definirse y desactivarse cuando no corresponda.
6. Probar bitácora acotada, rendimiento, limpieza al cerrar escena y ausencia de dependencias de editor en el runtime.

**Criterio de cierre.** Es posible explicar visualmente por qué una FSM cambió o no cambió de estado, sin necesidad de inspeccionar el código.

### Fase 11 — Calidad, compatibilidad, entrega y aceptación (GATE-FSM)

**Objetivo.** Convertir los componentes implementados en una entrega fiable y repetible.

**Pasos de implementación:**
1. Actualizar el contrato y el catálogo `docs/behavior_catalog.json` por cada cambio de comportamiento; conservar trazabilidad requisito→código→prueba→commit/PR.
2. Ejecutar pruebas de validador, migración, recursos, duplicación, escena, dos instancias, Ready/Timer, bloques externos, Conditions, chips, UI, Undo/Redo, persistencia, regresión de serialización y cierre limpio de runtime.
3. Ejecutar `git diff --check`, validación del catálogo, carga del editor Godot 4.7.2 en headless y prueba de modelo oficial. Registrar código de salida, advertencias y errores por separado.
4. Invocar **explícitamente** `$flujo-prove` antes de la integración. Los archivos de prueba existentes sin ejecución son únicamente evidencia preparada, no un resultado PASS.
5. Realizar **una revisión humana integral** al concluir el bloque de implementación aprobado: escritorio Fedora, teclado, foco, Inspector, Flow, Flusso, deshacer/rehacer, guardar/reabrir, escena instanciada; después Android (táctil y orientación) sobre un pre-release identificable.
6. Crear una demo de aceptación aislada, sin modificar `demo/main.tscn` protegido: NPC de un estado, NPC de dos estados, dos FSM comunicándose, estado dinámico y restauración de partida.
7. Documentar defectos bloqueantes, limitaciones conocidas y regresiones permitidas (si las hubiera) antes de etiquetar versión. No afirmar compatibilidad de un esquema/plataforma que no fue probado.
8. Integrar exclusivamente tras aprobación explícita del responsable y con rollback verificable.

**Criterio de cierre.** Todas las pruebas críticas pasan, la revisión manual está aprobada, la documentación coincide con el código y el pre-release funciona en un proyecto limpio de Godot.

## 5. Semántica de ejecución propuesta (para congelar en contrato)

### 5.1 Orden determinista de un tick

```text
1. Leer y validar eventos y solicitudes pendientes de ticks anteriores.
2. Para cada FSM habilitada, en orden de definición/ID:
   a) Si no inició: seleccionar initial_state_id y ejecutar enter una vez.
   b) Si está activa y no pausada: ejecutar update una vez.
   c) Evaluar condiciones/eventos en orden determinista.
   d) Encolar como máximo una candidata prioritaria para commit.
3. Fase de commit: validar aún cada destino, ejecutar exit(origen),
   modificar active_state_id solo en runtime, ejecutar enter(destino).
4. Encolar solicitudes creadas por exit/enter para el siguiente tick.
5. Emitir resultados/diagnósticos; no ejecutar update del destino en ese tick.
```

**Aspectos a decidir antes de codificar:** modo de tick por máquina; si el arranque consume un tick o ejecuta `enter` inmediatamente; si una solicitud manual supera una condición; cómo se trata una autotransición; qué ocurre al deshabilitar el controlador; si un callback que falla permite completar la transición o la cancela. Lo imprescindible es documentar una política **única, repetible y comprobada**, no imponer una preferencia sin autorización.

### 5.2 Operaciones runtime mínimas propuestas

```gdscript
# Interfaz de diseño; no indica que estos métodos ya existan.
start_machine(machine_id: String) -> FlowFSMResult
stop_machine(machine_id: String) -> FlowFSMResult
pause_machine(machine_id: String) -> FlowFSMResult
resume_machine(machine_id: String) -> FlowFSMResult
get_active_state_id(machine_id: String) -> String
request_transition(machine_id: String, target_state_id: String) -> FlowFSMResult
emit_event(machine_id: String, event_id: StringName, payload: Variant) -> FlowFSMResult
register_state(machine_id: String, template_id: String, lifetime: int, data: Dictionary) -> FlowFSMResult
has_state(machine_id: String, state_id: String) -> bool
remove_state(machine_id: String, state_id: String, fallback_state_id: String = "") -> FlowFSMResult
create_snapshot() -> FlowFSMSnapshotResult
restore_snapshot(snapshot: Dictionary) -> FlowFSMResult
```

La API pública debe retornar errores tipados (`invalid_machine`, `invalid_state`, `disabled`, `unsupported_schema`, `queue_full`, `corrupt_snapshot`, etc.) y jamás dar por exitoso un comando que todavía está **encolado**; distinguir `ACCEPTED/QUEUED` de `APPLIED`.

### 5.3 Cinco reglas que no pueden romperse

1. **Identidad:** la máquina y el estado se localizan por ID estable; nombre visible y posición no son identidad.
2. **Aislamiento:** un `PVController` no altera el estado activo de otro ni `FlowGraph` compartido.
3. **Determinismo:** mismas definiciones, estado inicial y entradas producen la misma secuencia de transiciones.
4. **Integridad:** referencias faltantes se diagnostican; no se reparan ni sustituyen silenciosamente.
5. **Compatibilidad:** cambios a recursos serializados requieren estrategia explícita de versión y pruebas de migración.

## 6. Plan de pruebas y matriz de aceptación

| Caso | Escenario | Resultado exigido |
|---|---|---|
| T01 | FSM vacía en editor | Borrador editable; ejecución rechazada con diagnóstico. |
| T02 | FSM con un solo estado | Inicia y funciona sin transición ni estado inventado. |
| T03 | Primer estado añadido | `initial_state_id` apunta al nuevo estado. |
| T04 | Referencia inicial inválida | Error estable; ninguna modificación automática. |
| T05 | Renombrar y reordenar estados | El estado activo y las referencias siguen por ID. |
| T06 | Duplicación profunda | IDs nuevos y referencias internas remapeadas. |
| T07 | Enter/update/exit | Conteo y orden exactos; no se duplica entrada/salida. |
| T08 | Pausa, stop, reset y disable | No queda ejecución fantasma; semántica consistente. |
| T09 | Dos instancias de PackedScene | Estado de cada controlador aislado. |
| T10 | Condition `true`/`false` | Transición solo cuando corresponde. |
| T11 | Condición sin tipo booleano | Diagnóstico, sin transición. |
| T12 | Evento local | Activación una vez conforme a consumo definido. |
| T13 | Dos transiciones candidatas | Gana regla de prioridad/orden documentada. |
| T14 | Autotransición | Aplica la política declarada y no recurre sin límite. |
| T15 | Referencia a estado borrado | Rechazo antes del commit. |
| T16 | Dos FSM A/B | A solicita transición en B; commit no es reentrante. |
| T17 | Cadena A→B→A | Presupuesto evita ciclo infinito. |
| T18 | 100 solicitudes en un tick | Resultado estable, diagnóstico si supera límite. |
| T19 | Registrar estado dinámico | No cambia el recurso `FlowGraph`. |
| T20 | Eliminar estado activo | Fallback o stop explícito, nunca referencia colgante. |
| T21 | Estado dinámico en dos escenas | Identidades/catálogos independientes. |
| T22 | Guardar `PERSISTENT` | Snapshot versionado, validado y sin código. |
| T23 | Restaurar archivo corrupto | Se rechaza atómicamente; estado previo intacto. |
| T24 | `EPHEMERAL` y `SESSION` | Nunca se escriben como `PERSISTENT`. |
| T25 | Editor crear/editar/borrar | Undo/Redo, foco y guardado/reapertura correctos. |
| T26 | Condition Tok y chips | Fuente semántica intacta tras editar/duplicar. |
| T27 | Ready/Timer existentes | Ninguna regresión de orden, salida ni navegación. |
| T28 | Esquema 5 | No se ejecuta accidentalmente sin contrato aprobado. |
| T29 | Android vertical/horizontal | Tacto, foco, scroll y cierre de Fluo validados. |
| T30 | Exportación sin editor | Runtime funciona sin clases de `EditorPlugin`. |

**Ubicaciones de prueba sugeridas (crear solo si corresponde):** `tests/model/flow_fsm_model_test.tscn`, `tests/runtime/flow_fsm_lifecycle_test.tscn`, `tests/runtime/flow_fsm_transition_test.tscn`, `tests/runtime/flow_fsm_dynamic_test.tscn`, `tests/runtime/flow_fsm_persistence_test.tscn` y `tests/editor/flow_fsm_authoring_test.tscn`. Ninguno se declara existente o aprobado por esta propuesta.

## 7. Dependencias, entregas y puertas de integración

| Orden | Entrega | Depende de | Prueba imprescindible para pasar |
|---|---|---|---|
| 0 | Baseline y contrato | Repo y rama verificados | Especificación y focales de partida documentadas. |
| 1 | FSM-001/A modelo | Fase 0 | Identidad, migración, serialización y un estado. |
| 2 | FSM-001/B runtime aislado | Modelo | Dos controladores independientes. |
| 3 | FSM-001/C ejecutor compartido | Runtime | No regresión Ready/Timer/SDK. |
| 4 | FSM-001/D ciclo de vida | Ejecutor | Enter/update/exit y un estado. |
| 5 | FSM-002/A transiciones | FSM-001 | Condición, evento, prioridad y commit. |
| 6 | FSM-002/B coordinación | Transiciones | Dos máquinas, colas y ciclos limitados. |
| 7 | UI-FSM | Modelo y FSM-002 | Edición completa, Undo/Redo, foco y save/reopen. |
| 8 | FSM-003 dinámicos | Runtime y coordinación | Registrar/borrar sin mutar grafo. |
| 9 | FSM-004 persistencia | Dinámicos | Round-trip y rechazo atómico de corrupción. |
| 10 | DEBUG-FSM | Eventos y runtime | Inspección y trazabilidad sin writes implícitos. |
| 11 | GATE-FSM | Todo lo anterior | Pruebas automáticas + revisión humana + pre-release. |

**Política de trabajo remoto:** se puede desarrollar por lotes con pruebas automáticas y preparar un pre-release para Android; la revisión humana visual puede agruparse al final de la campaña, pero **no** deben fusionarse ramas de alto riesgo o declararse aprobadas antes de esa revisión. Cada fase requiere su propio registro de evidencia y puede permanecer como `pending manual acceptance`.

## 8. Riesgos, medidas y decisiones pendientes

| Riesgo | Consecuencia | Mitigación exigida |
|---|---|---|
| Modificar serialización sin migración | Escenas/grafos antiguos incompatibles | Versionado + migración atómica + round-trip de regresión. |
| Copiar el ejecutor | Ready/Timer y FSM divergen | Extraer núcleo común con baseline comparativo. |
| Mutar definiciones compartidas | Dos instancias se afectan | Runtime per-controller y test con dos PackedScenes. |
| Transiciones durante callbacks | Recursión/reentrancia | Solicitudes en cola, commit único y presupuesto. |
| IDs o destinos corruptos | Saltos inesperados | Validador puro, mensajes tipados y rechazo de commit. |
| Guardar objetos/código arbitrario | Corrupción e inseguridad | Snapshot solo datos permitidos, versión y límites. |
| Introducir UI privada | Duplicación e inconsistencia | Fluo/Flow/Flusso y renderer/SDK genéricos. |
| Dar por ejecutable Schema 5 | Comportamiento incompatible | Gate específico por esquema; no activar sin contrato. |
| Pruebas Android incompletas | Problemas de tacto/foco/orientación | Matriz manual Android y versión de prueba identificable. |
| Lotes sin evidencia | Integración no reproducible | `$flujo-baseline`, catálogo, focales y `$flujo-prove`. |

**Decisiones que requieren aprobación antes de codificar (no bloquean la elaboración del documento):** (D1) almacenamiento de `enter/update/exit`; (D2) modo de tick; (D3) prioridad de solicitudes manuales versus reglas; (D4) semántica de autotransición; (D5) comportamiento de `exit` al destruir el controlador; (D6) tratamiento de fallo dentro de `enter` o `exit`; (D7) alcance exacto de `SESSION`; (D8) ejecución de `enter` al restaurar; (D9) formato de snapshot; (D10) compatibilidad de esquemas 2–5; (D11) qué funciones runtime se exponen al SDK externo; (D12) límites numéricos de colas y estados dinámicos. La recomendación es aprobarlas juntas en Fase 0 y mantenerlas congeladas durante cada entrega.

## 9. Criterios de término del proyecto

La FSM se declara **funcional** solo si: (a) inicia con un estado y cumple su ciclo; (b) cambia entre estados por condición/evento sin reentrancia; (c) coordina varias máquinas mediante IDs y colas; (d) posee estado runtime independiente por controlador; (e) puede crear/retirar estados dinámicos sin modificar el grafo; (f) persiste/restaura únicamente datos permitidos; (g) permite autoría completa desde Flow y Flusso; (h) brinda diagnósticos útiles; (i) conserva Ready/Timer y schemas soportados; y (j) cuenta con pruebas automáticas y aceptación humana reproducibles. El paso de “código escrito” a “hecho” requiere evidencia, no solo presencia de archivos.

## 10. Fuentes consultadas y trazabilidad

1. README de la rama consultada: https://github.com/mercurysama/Flujo/blob/feature/block-builder-fprint-dogfood/README.md
2. Modelo FSM: https://github.com/mercurysama/Flujo/blob/feature/block-builder-fprint-dogfood/addons/vp_flujo/runtime/model/flow_state_machine_definition.gd
3. Definición de estado: https://github.com/mercurysama/Flujo/blob/feature/block-builder-fprint-dogfood/addons/vp_flujo/runtime/model/flow_state_definition.gd
4. Validador: https://github.com/mercurysama/Flujo/blob/feature/block-builder-fprint-dogfood/addons/vp_flujo/runtime/model/flow_graph_validator.gd
5. Controlador: https://github.com/mercurysama/Flujo/blob/feature/block-builder-fprint-dogfood/addons/vp_flujo/runtime/pv_controller.gd
6. Ejecutor: https://github.com/mercurysama/Flujo/blob/feature/block-builder-fprint-dogfood/addons/vp_flujo/runtime/flow_ready_executor.gd
7. Contratos y gobierno: `docs/model_contract.md`, `docs/constitution.md`, `docs/current_iteration.md`, `docs/project_memory.md`, `AGENTS.md` (misma rama).
8. Integración Akis/Tok: `docs/flow_condition_tok_step_2c_c_2_contract.md` y `docs/flow_akis_tok_lot_10_contract.md` (misma rama).
9. Decisiones históricas del proyecto discutidas en los chats «flujo» y «flujo 2»: validez de una FSM con un estado, máquinas simultáneas, colas de solicitudes, ciclo de vida, estados dinámicos y modalidades de persistencia. Se incluyen como requisitos heredados; las signaturas y algoritmos detallados son **propuestas** de este plan.

---

**Nota de ejecución:** este documento es un plan de ingeniería y una base para futuras especificaciones numeradas. No incluye modificaciones al repositorio, no afirma haber ejecutado pruebas y no autoriza por sí mismo commits, merges ni releases.

*Todo es Flujo; todo fluye. 🌊*