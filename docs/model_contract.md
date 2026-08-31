# Contrato técnico del modelo de Flujo

## Propósito y alcance

Este documento define el contrato del modelo central implementado de Flujo para Godot 4.7.2. Establece sus responsabilidades, identidad, persistencia y dependencias. No define todavía la implementación del ejecutor ni de la interfaz gráfica.

## Principios generales

- `FlowGraph` es la raíz persistente de cada programa visual y comienza con `schema_version = 1`.
- El editor puede depender de clases del runtime. El runtime nunca puede depender de clases ni APIs exclusivas del editor.
- La implementación utiliza GDScript portátil y únicamente APIs disponibles en juegos exportados cuando el código pertenece al runtime.
- Los grafos y bloques creados por el usuario se guardan bajo `res://flow/`.
- Los paquetes instalados se guardan bajo `res://flow_packages/<package_id>/`.
- Ningún grafo, bloque, paquete ni otro contenido del usuario se guarda dentro de `res://addons/vp_flujo/`.

## Identidad persistente

Todo elemento persistente posee un identificador interno estable, independiente de su nombre visible, ruta de recurso, índice o posición en una colección.

- `FlowId` centraliza la generación de identificadores de 32 caracteres mediante `FlowId.create()` y no depende del editor.
- Los identificadores internos se almacenan en propiedades ocultas y serializables mediante `@export_storage`.
- Renombrar un elemento no cambia su identificador.
- Mover un elemento no cambia su identificador.
- Reordenar un elemento no cambia su identificador.
- Duplicar un elemento genera un identificador nuevo para la copia y para cada elemento persistente contenido que también se duplique.

## Clases del modelo

### FlowId

**Base:** `RefCounted`.

**Responsabilidad:** generar de forma centralizada identificadores aleatorios de 32 caracteres sin depender de APIs del editor.

### FlowGraph

**Base:** `Resource`.

**Responsabilidad:** representar la raíz persistente de un programa visual.

**Datos mínimos:**

- Identificador interno estable.
- `CURRENT_SCHEMA_VERSION = 1` y `schema_version`, cuyo valor inicial es `1`, reservados para futuras migraciones.
- El esquema 1 usa exclusivamente la colección ordenada `Array[FlowBlockContainer]` llamada `containers`, que conserva también las posiciones `null`.
- La representación disponible para el esquema 2 usa exclusivamente las colecciones ordenadas y tipadas `processes`, `variables` y `state_machines`, que también conservan las posiciones `null`.
- Las dos representaciones no se sincronizan. Un grafo que contiene entradas en `containers` y en cualquier colección de esquema 2 es inválido.

**Duplicación:** requiere un grafo que haya superado la validación. Crea otro `FlowGraph` y genera identificadores nuevos para el grafo y todos los recursos de la representación activa, manteniendo el orden y las posiciones `null`. La copia de esquema 2 usa un único mapa de ID original a ID nuevo para remapear `owner_container_id`, `global_variable_id` e `initial_state_id`; las referencias no resueltas se conservan para diagnóstico.

**Migración:** `FlowGraphMigrator.migrate_schema_1_to_2()` crea de forma atómica un nuevo grafo de esquema 2 a partir de un grafo de esquema 1 validado. Conserva el ID del grafo y los IDs válidos de procesos, estados y bloques, sin compartir recursos mutables con el origen. Los procesos y los estados conservan las posiciones de `containers`; los estados se agrupan en una máquina nueva llamada `Migrated States`.

**Dependencias permitidas:** puede depender de los tipos persistentes del modelo y de utilidades portátiles del runtime. No depende del editor ni de un ejecutor.

### FlowBlockContainer

**Base:** `Resource`.

**Responsabilidad:** servir como clase base polimórfica persistente y agrupar una secuencia ordenada de bloques dentro de un grafo.

**Datos mínimos:**

- Identificador interno estable.
- Nombre visible independiente del identificador.
- Activación mediante `enabled`.
- Nota del usuario mediante `user_note`.
- Colección ordenada `Array[FlowBlock]` que conserva también las posiciones `null`.

**Duplicación:** mantiene el tipo derivado del contenedor, genera un identificador nuevo para este y duplica sus bloques con identificadores nuevos, conservando el orden y las posiciones `null`.

**Dependencias permitidas:** puede depender de `FlowBlock` y de tipos de datos portátiles del runtime. No depende de nodos de escena, clases del editor ni controles gráficos.

### FlowBlock

**Base:** `Resource`.

**Responsabilidad:** representar un bloque persistente con identidad, nombre visible, activación y nota del usuario.

**Datos mínimos:**

- Identificador interno estable.
- Nombre visible mediante `display_name`.
- Activación mediante `enabled`.
- Nota del usuario mediante `user_note`.

**Duplicación:** conserva sus datos persistentes y recibe un identificador nuevo.

**Dependencias permitidas:** utiliza únicamente el contrato del modelo y APIs portátiles del runtime. No depende de clases del editor ni de la interfaz gráfica.

### FlowProcess

**Base:** `FlowBlockContainer`.

**Responsabilidad:** representar de forma persistente uno de los puntos de proceso admitidos.

**Tipo de proceso:** `ProcessType` admite exclusivamente `READY`, `PROCESS`, `PHYSICS_PROCESS`, `INPUT` y `UNHANDLED_INPUT`.

**Nombre visible:** comienza como `_ready`, pero `display_name` sigue siendo renombrable e independiente de `process_type`. Cambiar el tipo de proceso no cambia automáticamente el nombre visible.

**Duplicación:** conserva el tipo `FlowProcess` y genera identificadores nuevos mediante la duplicación heredada.

### FlowStateDefinition

**Base:** `FlowBlockContainer`.

**Responsabilidad:** representar la definición persistente de un estado de una futura máquina de estados.

**Estado inicial:** `is_initial` representa la selección del estado inicial. La futura máquina de estados será responsable de garantizar que exista un único estado inicial.

**Duplicación:** conserva el tipo `FlowStateDefinition`, el valor de `is_initial` y genera identificadores nuevos mediante la duplicación heredada.

### FlowGraphMigrationResult

**Base:** `RefCounted`.

**Responsabilidad:** representar una tentativa de migración con el grafo migrado, cuando existe, y los diagnósticos ordenados del origen, la transformación o la candidata.

### FlowGraphMigrator

**Base:** `RefCounted`.

**Responsabilidad:** migrar un `FlowGraph` de esquema 1 a una copia independiente de esquema 2 sin modificar el origen. La migración valida el origen antes de construir la candidata y valida la candidata antes de devolverla como exitosa.

### FlowGraphInspectorPresenter

**Base:** `RefCounted`.

**Responsabilidad:** producir una representación determinista y de solo lectura de un `FlowGraph` para la interfaz del Inspector. Pertenece al editor, incluye versión de esquema, fuente activa, secciones ordenadas, índices, nombres, tipos, IDs internos y diagnósticos, y no modifica el grafo.

### PVController

**Base:** `Node`.

**Responsabilidad:** actuar como fachada de Flujo para una escena.

**Modelo:** posee la propiedad exportada `flow_graph` de tipo `FlowGraph`. Cada controlador nuevo recibe su propio grafo predeterminado.

**Ejecución:** todavía no está implementada.

## Referencias y orden

El orden de `FlowGraph.containers` y `FlowBlockContainer.blocks` se conserva durante la duplicación. Las posiciones `null` también se conservan y no se eliminan ni compactan.

Los identificadores no dependen del índice ni de la posición en estas colecciones. La copia recibe identificadores nuevos en el grafo, los contenedores y los bloques.

## Validación implementada de los esquemas 1 y 2

`FlowGraphValidator` valida el modelo sin modificarlo y devuelve un `FlowValidationResult` con diagnósticos estructurados `FlowDiagnostic`. Cada diagnóstico contiene un código estable, severidad, mensaje, ruta del elemento e identificador relacionado. El resultado permite consultar si existen errores.

La validación actual detecta grafos nulos, versiones de esquema no soportadas, identificadores vacíos, de longitud distinta de 32 caracteres, no hexadecimales o duplicados, instancias de recursos repetidas y tipos de contenedor que no pueden migrarse según el contrato planificado del esquema 2. También detecta el uso simultáneo de `containers` y las colecciones de esquema 2. Recorre de forma determinista el grafo, sus colecciones activas, máquinas de estados y bloques; acepta las posiciones `null` sin producir diagnósticos.

En el esquema 2, `owner_container_id` debe resolver a un `FlowProcess` o `FlowStateDefinition` perteneciente al mismo grafo y `global_variable_id` debe resolver a una variable `GLOBAL` del mismo grafo. Las referencias ausentes o de tipo/ámbito no permitido se conservan y generan un diagnóstico.

El validador pertenece al runtime, usa únicamente APIs portátiles y no depende del editor.

## Presentación implementada del Inspector

El editor usa `FlowGraphInspectorPresenter` para mostrar `flow_graph` de `PVController` sin modificar recursos. En esquema 1 muestra `Containers`; en esquema 2 muestra `Processes`, `Variables` y `State Machines`. Cada posición conserva su índice y las posiciones `null` se muestran como `Empty`. Los IDs internos se muestran como metadatos estables, mientras que `display_name` es solo texto de presentación.

`PVControllerInspectorPlugin` y `FlowGraphInspectorProperty` pertenecen al editor y se registran desde el plugin principal. Las filas son seleccionables solo dentro de la interfaz; no escriben en el modelo. Los diagnósticos de `FlowGraphValidator` se muestran sin alterar el grafo.

## Migración implementada de esquema 1 a esquema 2

`FlowGraphMigrator` solo acepta un origen de esquema 1 que supere `FlowGraphValidator`. Cualquier diagnóstico de error del origen impide la migración y se conserva en `FlowGraphMigrationResult`. La candidata se construye por separado, se valida y solo se expone cuando no tiene errores.

Los `FlowProcess` se copian profundamente a `processes` manteniendo el tamaño, orden e índices de `containers`; las posiciones que no contienen procesos quedan como `null`. Los `FlowStateDefinition` se copian profundamente a una única máquina `Migrated States`, cuyo arreglo conserva esos mismos índices y posiciones. La máquina no se crea si no hay estados y recibe un ID nuevo si se crea.

Si existe exactamente un estado con `is_initial`, la máquina migrada lo selecciona; si no hay ninguno, selecciona el primer estado no nulo; más de uno produce un diagnóstico de error. Los tipos desconocidos de `FlowBlockContainer`, las referencias ausentes y cualquier otra invalidación estructural del origen impiden la migración sin cambiar el origen.

## Contrato planificado — todavía no implementado

Los requisitos de esta sección son decisiones de diseño futuras. No describen funciones disponibles en la implementación actual.

El contrato planificado para la evolución posterior del esquema 2 se define en [`flow_graph_v2_migration.md`](flow_graph_v2_migration.md). Sus partes no cubiertas por la migración implementada siguen siendo diseño previo.

### Ejecución y estado temporal

- Durante la futura ejecución, `FlowGraph` y todos sus recursos persistentes serán tratados como datos de solo lectura.
- `FlowRuntimeState` será una clase `RefCounted` temporal, independiente para cada controlador y cada ejecución.
- `FlowRuntimeState` contendrá únicamente datos mutables propios de la ejecución, nunca será serializado dentro del grafo y se liberará al terminar o descartar esa ejecución.

### Referencias internas y duplicación

- Las referencias internas persistentes usarán identificadores, nunca nombres visibles ni índices o posiciones de colecciones.
- La duplicación futura de estructuras con referencias creará un mapa entre identificadores originales y nuevos, y actualizará con él las referencias internas que apunten a elementos incluidos en la copia.

### Validación

- La validación rechazará identificadores vacíos, mal formados o duplicados dentro del espacio de identidad del grafo.
- Cada referencia interna deberá resolver a un elemento existente y de un tipo permitido para esa relación.
- Una referencia ausente o que resuelva al tipo incorrecto será un error; no se sustituirá buscando por nombre visible ni por posición.

### Versiones y migraciones

- Las migraciones de `schema_version` se ejecutarán explícitamente en pasos ordenados antes de usar el grafo.
- Una versión futura, posterior a la máxima soportada, o incompatible será rechazada de forma controlada sin sobrescribir ni guardar el recurso.
- Las migraciones preservarán todos los identificadores existentes que sean válidos y generarán identificadores nuevos solo cuando la transformación lo requiera.

### Operaciones y separación del editor

- Las modificaciones del modelo se expresarán como operaciones pequeñas y deterministas, con entradas explícitas y la información necesaria para deshacerlas y rehacerlas.
- El editor podrá adaptar esas operaciones a su sistema de deshacer y rehacer, sin trasladar dependencias del editor al runtime.
- El runtime, incluidos sus futuros componentes de carga, validación, migración y ejecución, no dependerá de clases ni APIs exclusivas del editor.

### Portabilidad futura

- La carga, validación, migración y ejecución del modelo funcionarán también en juegos exportados mediante APIs portátiles disponibles en las plataformas compatibles con Godot 4.7.2.

## Pruebas

La escena `tests/model/flow_model_smoke_test.tscn` valida los identificadores, la duplicación, la conservación de tipos derivados y posiciones `null`, y que cada `PVController` nuevo posea un `FlowGraph` independiente.

Se ejecuta manualmente abriendo esa escena en Godot y pulsando **F6**.

## Ubicación y portabilidad

El contenido propio del proyecto se organiza bajo `res://flow/`. Los paquetes instalados usan `res://flow_packages/<package_id>/`, donde `package_id` es estable y apto para rutas portátiles. `res://addons/vp_flujo/` queda reservado exclusivamente al código y recursos distribuidos con el complemento.

El modelo no utiliza rutas absolutas, separadores específicos del sistema operativo, procesos externos ni APIs exclusivas del editor. Su código runtime utiliza APIs disponibles en juegos exportados en las plataformas compatibles con Godot 4.7.2.
