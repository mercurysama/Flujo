# Contrato técnico del modelo de Flujo

## Propósito y alcance

Este documento define el contrato estable del modelo central de Flujo para Godot 4.7.2. Establece responsabilidades, identidad, persistencia, dependencias y reglas de validación. No define todavía la implementación del ejecutor ni de la interfaz gráfica.

## Principios generales

- `FlowGraph` es la raíz persistente de cada programa visual y comienza con `schema_version = 1`.
- El grafo y todos sus elementos persistentes se tratan como datos de solo lectura durante la ejecución.
- El editor puede depender de clases del runtime. El runtime nunca puede depender de clases ni APIs exclusivas del editor.
- Las modificaciones del modelo se expresan como operaciones pequeñas y deterministas, preparadas para registrar sus acciones de hacer y deshacer.
- La implementación utiliza GDScript portátil y únicamente APIs disponibles en juegos exportados cuando el código pertenece al runtime.
- Los grafos y bloques creados por el usuario se guardan bajo `res://flow/`.
- Los paquetes instalados se guardan bajo `res://flow_packages/<package_id>/`.
- Ningún grafo, bloque, paquete ni otro contenido del usuario se guarda dentro de `res://addons/vp_flujo/`.

## Identidad persistente

Todo elemento persistente posee un identificador interno estable, independiente de su nombre visible, ruta de recurso, índice o posición en una colección.

- Renombrar un elemento no cambia su identificador.
- Reordenar un elemento no cambia su identificador.
- Mover un recurso dentro de las ubicaciones admitidas no debe cambiar su identificador.
- Duplicar un elemento genera un identificador nuevo para la copia y para cada elemento persistente contenido que también se duplique.
- Las referencias internas almacenan identificadores; nunca nombres visibles ni posiciones de listas.
- Los identificadores se comparan de forma exacta y con reglas independientes del sistema operativo.
- Un identificador vacío, mal formado o duplicado hace que el modelo no sea válido.
- La generación y sustitución de identificadores ocurre durante la creación, duplicación o migración controlada, nunca como efecto secundario de ejecutar el grafo.

## Clases del modelo

### FlowGraph

**Base:** `Resource`.

**Responsabilidad:** representar de forma persistente la raíz completa de un programa visual y ser el límite principal de carga, validación, migración y guardado.

**Datos mínimos:**

- Identificador interno estable.
- Nombre visible independiente del identificador.
- `schema_version`, cuyo valor inicial es `1`.
- Colección ordenada de referencias a `FlowBlockContainer`.
- Colección de definiciones de estado o referencias a `FlowStateDefinition`, cuando el grafo las utilice.

**Ciclo de vida:** se crea como contenido de usuario o de un paquete; se carga y valida antes de editarse o utilizarse; puede migrarse de forma explícita; se guarda como recurso persistente. Durante una ejecución permanece en modo de solo lectura y no almacena estado temporal.

**Dependencias permitidas:** puede depender de otros tipos persistentes del modelo y de utilidades runtime portátiles de validación o migración. No puede depender del plugin, controles, docks, selección del editor, deshacer/rehacer del editor ni de un ejecutor concreto.

### FlowBlockContainer

**Base:** `Resource`.

**Responsabilidad:** agrupar y conservar una secuencia ordenada de bloques dentro de un grafo.

**Datos mínimos:**

- Identificador interno estable.
- Nombre visible independiente del identificador.
- Colección ordenada de `FlowBlock`.

**Ciclo de vida:** pertenece a un `FlowGraph`, se crea o duplica mediante una operación del modelo y se persiste con el grafo o como subrecurso válido. Su orden y el de sus bloques pueden cambiar sin alterar identidades. No se modifica durante la ejecución.

**Dependencias permitidas:** puede depender de `FlowBlock` y de tipos de datos portátiles del runtime. No puede depender de nodos de escena, clases del editor, controles gráficos ni estado temporal de ejecución.

### FlowBlock

**Base:** `Resource`.

**Responsabilidad:** definir el contrato persistente común de todos los tipos de bloque y almacenar únicamente su configuración declarativa.

**Datos mínimos:**

- Identificador interno estable.
- Nombre visible o etiqueta, cuando corresponda.
- Configuración persistente específica del tipo de bloque.
- Referencias internas expresadas mediante identificadores.

**Ciclo de vida:** se crea como instancia de una subclase concreta, se agrega a un contenedor y se valida junto con el grafo. Al duplicarse recibe una identidad nueva. Su configuración se trata como solo lectura durante la ejecución y nunca contiene datos mutables propios de una instancia en ejecución.

**Dependencias permitidas:** una subclase puede depender del contrato del modelo y de APIs runtime portátiles disponibles en exportaciones. No puede depender de clases del editor, de la interfaz gráfica ni conservar una referencia a `FlowRuntimeState` entre ejecuciones.

### FlowStateDefinition

**Base:** `Resource`.

**Responsabilidad:** representar la definición persistente de un estado de máquina, sin contener el estado mutable de una ejecución concreta.

**Datos mínimos:**

- Identificador interno estable.
- Nombre visible independiente del identificador.
- Configuración persistente necesaria para describir el estado.
- Referencias a otros elementos mediante identificadores, cuando existan transiciones o relaciones.

**Ciclo de vida:** se crea y edita como parte del contenido persistente del grafo; se valida antes de usarse; al duplicarse recibe un identificador nuevo. Permanece inmutable desde la perspectiva de cada ejecución.

**Dependencias permitidas:** puede depender de tipos persistentes del modelo y utilidades runtime portátiles. No puede depender de `FlowRuntimeState`, clases del editor, nodos de interfaz ni información específica de una sesión de ejecución.

### FlowRuntimeState

**Base:** `RefCounted`.

**Responsabilidad:** contener el estado mutable y aislado de una única instancia durante su ejecución.

**Datos mínimos:**

- Referencia o identificador de la definición persistente que representa, cuando corresponda.
- Datos temporales propios de la instancia.
- Información de estado necesaria para esa ejecución, sin modificar el grafo.

**Ciclo de vida:** se crea al iniciar o preparar una instancia de ejecución, existe solamente durante ella y se libera al terminar o descartarse la instancia. Nunca se guarda como parte del grafo y nunca se comparte entre controladores, entidades o ejecuciones simultáneas.

**Dependencias permitidas:** puede leer `FlowGraph`, `FlowStateDefinition` y otros contratos runtime. No puede modificar recursos persistentes ni depender de clases del editor. Ningún recurso persistente puede poseerlo como dato serializado.

## Referencias y orden

El orden de contenedores y bloques expresa presentación o secuencia, pero no identidad. Toda relación que deba sobrevivir a renombrados, movimientos o reordenamientos utiliza el identificador interno del destino.

Al duplicar una estructura compuesta se crea un mapa entre identificadores originales y nuevos. Las referencias internas de la copia que apunten a elementos también duplicados se actualizan con ese mapa. Las referencias externas solo se conservan si el contrato de la operación de duplicación lo permite y el destino existe.

## Operaciones de modificación

Cada modificación debe poder describirse como una operación pequeña, con entradas explícitas y resultado determinista. Entre ellas se incluyen crear, agregar, retirar, duplicar, renombrar, reordenar y cambiar una propiedad persistente.

Las operaciones deben:

- Identificar los objetivos mediante sus identificadores internos.
- Conservar la información necesaria para revertirse.
- Validar sus precondiciones antes de modificar el modelo.
- No introducir referencias ausentes ni identificadores duplicados.
- Permanecer independientes de una implementación concreta de deshacer/rehacer del editor.

El editor podrá adaptar estas operaciones a su sistema de deshacer y rehacer sin trasladar dependencias del editor al runtime.

## Validación

La validación se realiza después de cargar o migrar un grafo y antes de editarlo o utilizarlo. Debe informar errores con suficiente contexto para localizar el elemento y la propiedad afectados.

### Identificadores duplicados

- Se recorren todos los elementos persistentes contenidos o referenciados por el grafo.
- Cada identificador no vacío debe aparecer una sola vez dentro del espacio de identidad del grafo.
- Una duplicación detectada es un error de validación; no se elige silenciosamente uno de los elementos.
- La reparación automática, si se incorpora posteriormente, debe ser una migración u operación explícita que genere identificadores nuevos y actualice todas las referencias afectadas.

### Referencias ausentes

- Cada identificador referenciado debe resolver a un elemento existente y de un tipo permitido para esa relación.
- Una referencia vacía solo es válida si la propiedad está definida expresamente como opcional.
- Una referencia que no resuelve o resuelve al tipo incorrecto es un error de validación.
- No se debe sustituir una referencia ausente buscando un elemento con el mismo nombre o la misma posición.

### Versiones de esquema

- `schema_version = 1` es la primera versión reconocida del formato.
- Una versión anterior compatible debe migrarse explícitamente, en pasos ordenados, antes de usar el grafo.
- Una versión posterior a la máxima versión soportada es incompatible y debe rechazarse sin sobrescribir ni guardar el recurso.
- Una versión ausente, inválida o no migrable produce un error de carga controlado.
- La migración debe preservar identidades existentes siempre que sean válidas y producir un resultado que vuelva a pasar todas las validaciones.
- La versión del esquema es independiente de la versión del complemento.

## Ubicación y portabilidad

El contenido propio del proyecto se organiza bajo `res://flow/`. Los paquetes instalados usan `res://flow_packages/<package_id>/`, donde `package_id` es estable y apto para rutas portátiles. `res://addons/vp_flujo/` queda reservado exclusivamente al código y recursos distribuidos con el complemento.

El modelo no utiliza rutas absolutas, separadores específicos del sistema operativo, procesos externos ni APIs exclusivas del editor. Todo código runtime relacionado con carga, validación, migración o lectura del modelo debe funcionar también en juegos exportados en las plataformas compatibles con Godot 4.7.2.
