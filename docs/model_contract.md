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
- Colección ordenada `Array[FlowBlockContainer]` que conserva también las posiciones `null`.

**Duplicación:** crea otro `FlowGraph` y genera identificadores nuevos para el grafo, sus contenedores y los bloques contenidos, manteniendo el orden y las posiciones `null`.

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

### PVController

**Base:** `Node`.

**Responsabilidad:** actuar como fachada de Flujo para una escena.

**Modelo:** posee la propiedad exportada `flow_graph` de tipo `FlowGraph`. Cada controlador nuevo recibe su propio grafo predeterminado.

**Ejecución:** todavía no está implementada.

## Referencias y orden

El orden de `FlowGraph.containers` y `FlowBlockContainer.blocks` se conserva durante la duplicación. Las posiciones `null` también se conservan y no se eliminan ni compactan.

Los identificadores no dependen del índice ni de la posición en estas colecciones. La copia recibe identificadores nuevos en el grafo, los contenedores y los bloques.

## Contrato planificado — todavía no implementado

Los requisitos de esta sección son decisiones de diseño futuras. No describen funciones disponibles en la implementación actual.

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
