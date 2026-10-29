# Plan técnico y arquitectónico para bloques distribuibles, SDK y Fluo

**Fecha:** 2026-10-29
**Estado:** plan técnico reconciliado; D0–D3 completados; D3 COMPLETE tras `$flujo-prove` PASS; la Skill inicial de planificación `flujo-block-builder` está creada y validada; D4-A COMPLETE; D4-B COMPLETE; D4-C COMPLETE — MANUAL PASS; D4 está cerrado en la frontera A/B/C; D5–D9 permanecen planificados
**Alcance de esta entrega:** cierre documental y manual de D4-C sobre la implementación runtime/model de D4-B y el renderer genérico de Flusso, más el Major Increment Checkpoint D4-C/D5; no existe ni se inicia una entrega D4-D

**Revisión incremental:** reconciliada el 2026-10-28 con `docs/custom_block_sdk_research.md`, la implementación D4-B y la revisión manual D4-C aprobada.

Este documento prepara el trabajo posterior de `flujo-block-builder`, paquetes de
bloques, configuración genérica de Flusso y Themes + Motion. La Skill inicial de
planificación vive en `tools/agent_skills/flujo-block-builder/SKILL.md`; este plan no
crea bloques nuevos, no mueve bloques existentes y no cambia comportamiento de
Inspector, Fluo, Flow, Flusso, runtime, persistencia o schemas. La Skill es opcional:
todo su resultado debe poder crearse y mantenerse manualmente con GDScript, JSON y
los contratos públicos documentados.

## 1. Propósito y resultado esperado

El objetivo es establecer primero las fronteras y contratos que permitan distribuir
bloques de forma independiente sin convertir cada bloque en una excepción del
editor o del executor. El resultado buscado es:

1. un SDK manual, reproducible y versionable basado en GDScript, JSON y contratos
   públicos;
2. un paquete independiente por cada bloque distribuible; diez bloques significan
   diez paquetes, nunca un paquete monolítico como solución predeterminada;
3. un catálogo de autoría efímero que no confunda el tipo de autoría con el ID
   persistente del bloque;
4. una configuración genérica de Flusso basada en datos y validada por reflexión;
5. una política explícita para procedencia, ausencia, eliminación y restauración;
6. Themes y Motion que no rompan el layout de Containers ni la interacción del
   drawer;
7. entregas pequeñas, reversibles y auditables antes de cualquier `IF`, dejando el
   bloque externo estándar deliberadamente simple y fuera de esta misión.

## 2. Fuentes, estado actual y evidencia de la revisión

Se confirmaron como fuentes aplicables:

- `docs/constitution.md`;
- `docs/current_iteration.md`;
- `docs/project_memory.md`;
- `docs/custom_block_sdk_research.md`;
- `docs/fluo_preview_01.md`;
- `docs/model_contract.md`, especialmente `BLOCKSDK-001` a `BLOCKSDK-006` y la
  fundación del manifiesto externo;
- `docs/development_workflow.md`;
- `docs/behavior_catalog.json`;
- `addons/vp_flujo/runtime/model/flow_package_manifest*.gd`;
- `addons/vp_flujo/runtime/model/flow_external_block_*.gd`;
- `addons/vp_flujo/runtime/model/flow_editor_block_catalog*.gd`;
- `addons/vp_flujo/runtime/model/flow_block_registry.gd`;
- `addons/vp_flujo/runtime/model/flow_block.gd` y `flow_output_block.gd`;
- `addons/vp_flujo/editor/flow_ready_process_editor.gd`,
  `flow_graph_inspector_property.gd` y `fluo_drawer.gd`;
- las pruebas de `tests/model`, `tests/runtime` y `tests/editor` relacionadas.

La investigación disponible es una fuente adicional de reconciliación, no una
autorización para implementar. Confirma la fundación externa existente y delimita
los puentes que todavía faltan. Las conclusiones de la sección 27 se contrastaron
con la documentación oficial de Godot 4.7 para `Control` y `Container`, el código
real de Fluo y las pruebas propias; no se adoptan contratos de Skills externas.
`scenario-godot-expert` y `scenario-godot-ui`, consultadas en una ejecución
anterior, tienen aquí únicamente valor educativo y no son autoridad normativa ni
dependencia de Flujo.

Estado protegido al iniciar el trabajo:

- rama: `feature/fluo-drawer-poc`;
- `HEAD`: `58ca3ae50226351804e32234713e0b3e37f68767` (`docs: consolidate custom block SDK research`);
- cambio preexistente no realizado por este trabajo: `demo/main.tscn` modificado;
- Godot confirmado: `4.7.2.stable.fedora.ed1daf0bf`.

### 2.1 Auditoría de reconciliación A/B/C/D/E

La clasificación siguiente compara el plan anterior con la investigación y el
código actual. No debe confundirse con la clasificación operativa A/B/C/D de
riesgo de bloques de la sección 7.

| Clase | Hallazgo reconciliado | Tratamiento en este plan |
| --- | --- | --- |
| **A — Correcto** | IDs estables separados de los IDs de autoría; `FlowBlock` polimórfico; manifest v1 sin campos nuevos; separación runtime/editor; Inspector → Fluo → Flow → Flusso sin lista duplicada; reflexión + metadata como enfoque híbrido; IF fuera de alcance; Motion sin estado persistente. | Se conserva y se explicita como contrato protegido. |
| **B — Incompleto** | Faltaban el inventario explícito de la infraestructura implementada, la distinción entre catálogo/factory y su integración real, la Skill opcional/manual, la procedencia declarada, el modelo incubadora→biblioteca, el contrato previo de Theme/Motion y los puentes antes del bloque estándar. | Se agregan las secciones 8.1–8.3, 10, 14–17, 25–29 y el gate de builder. |
| **C — Desactualizado** | El plan afirmaba que `custom_block_sdk_research.md` estaba ausente y registraba un `HEAD` anterior. D1 también podía leerse como si hubiera que volver a construir manifest loader, validator, catálogo y factory. | Se corrige la evidencia y D1 pasa a documentar/probar el perfil sobre la fundación existente, no a reconstruirla. |
| **D — Propuesta** | Integración del catálogo en Add, Flusso genérico, procedencia persistente, recuperación de paquetes ausentes, promoción y pulido visual. | Se mantiene como propuesta futura, con dependencias, límites y aceptación separados. |
| **E — Conflicto** | La versión anterior trataba “un bloque = un paquete” como aprobación pendiente y usaba ejemplos que podían identificar a Flujo, no a Mercury, como publisher oficial. | Recomendación: aplicar la decisión aprobada de esta misión: el perfil distribuible es un bloque por paquete y los ejemplos oficiales usan Mercury. Se conserva la compatibilidad de lectura del manifest v1 histórico de varios descriptores; queda pendiente sólo el nombre final de cada paquete y la forma persistente de procedencia. |

### 2.2 Decisiones aprobadas que este plan ya no reabre

- Cada bloque distribuible ocupa un paquete independiente bajo
  `res://flow_packages/<package_id>/`. Ejemplos de topología son
  `mercury.print/`, `mercury.everything_flows/` y `usuario.mi_bloque/`.
- La Skill `flujo-block-builder` es opcional y no tiene capacidades secretas: su
  salida son archivos normales que una persona puede crear, revisar y mantener a
  mano.
- Los bloques oficiales declaran procedencia publicada por Mercury; los bloques de
  usuario declaran su propia procedencia. Esto no equivale a autenticidad
  criptográfica, que queda fuera de esta etapa.
- `Print`, `Custom Hello` y `Everything Flows` permanecen disponibles para
  compatibilidad y referencia; `Add Call Method` conserva su categoría y ruta
  editorial separada; `FlowBlockRegistry` no cambia en este checkpoint.
- La compatibilidad histórica de manifiestos v1 se conserva: el loader puede leer
  manifiestos con varios descriptores aunque la distribución canónica futura sea
  un bloque por paquete. No se cambia el schema del grafo ni se añaden campos al
  manifiesto v1.

### 2.3 Cierre D4 y aclaración del antiguo D4-D

El contrato canónico define D4-A, D4-B y D4-C, y después D5. La auditoría no
encontró alcance técnico, requisitos, dependencias ni una matriz de aceptación
A–E para `D4-D`. Por tanto, D4 queda completo en D4-C y la etiqueta histórica
`D4-D NEXT` se retira como placeholder de continuidad. Un futuro D4-D no puede
inferirse ni comenzar por convención: requiere una especificación numerada,
plan, matriz de aceptación y aprobación independiente.

## 3. Especificación, trazabilidad y gobernanza

La especificación vigente ya describe el fundamento externo. Este documento la
confirma y propone extensiones separadas; no modifica todavía `schema_version`, el
manifiesto v1 ni el catálogo de comportamiento.

Etiquetas de planificación propuestas:

| Etiqueta | Alcance |
| --- | --- |
| `PKG-PLAN` | paquetes, identidad, ciclo de vida y procedencia |
| `SDK-PLAN` | contrato GDScript, JSON, builder y reproducibilidad |
| `FLUSSO-PLAN` | metadata, reflexión y controles genéricos |
| `MOTION-PLAN` | Theme, Motion, layout e interacción |
| `DELIVERY-PLAN` | entregas reversibles y evidencia |

La traza obligatoria para cada futura entrega será:

`requisito → etiqueta de plan/contrato → tarea → archivo o código → prueba/revisión → commit`.

Traza inicial de requisitos ya existentes:

| Requisito vigente | Entrega prevista | Código/prueba de referencia | Commit |
| --- | --- | --- | --- |
| `BLOCKSDK-001`–`BLOCKSDK-006` | D1, D3, D4 y D6 | `FlowOutputBlock`, registry, catalog/factory y `tests/runtime/flow_custom_block_test.tscn` | pendiente |
| `FLUJO-BHV-FLUO-OPEN-001`, `EDIT-001`, `NAV-001` | D2, D3, D4 y D8 | `flow_process_timer_editor_test.gd` y `fluo_drawer_integration_test.gd` | pendiente |
| `FLUJO-BHV-FLUO-DRAWER-001` | D2, D3 y D8 | `fluo_drawer_test.gd`, `fluo_drawer_integration_test.gd` | pendiente |
| `FLUJO-BHV-FLUO-ANDROID-001` | D8 | `docs/fluo_preview_01.md` más matriz Android nueva | pendiente |
| `D4A-PROP-001`–`D4A-PROP-010`, `FLUJO-BHV-FLUO-GENERIC-PROPERTY-001` | D4-A, D4-B y D4-C | `flow_block_property_descriptor_test.tscn`, `flow_generic_flusso_property_editor_test.gd`, `flow_revert_owned_properties_editor_test.gd` y revisión manual Flusso | automático PASS + manual PASS; D4-C completo |

Las reglas de procedencia, paquetes ausentes y Motion necesitarán entradas nuevas del
catálogo cuando se implementen; el descriptor de propiedades de D4-B conserva su
entrada automática y el renderer genérico D4-C tiene evidencia automática y manual
aprobada en su entrada.

Una propuesta de este documento no se convierte en requisito implementable hasta
que exista una especificación numerada aprobada y se resuelvan las preguntas de la
sección 30.

## 4. Objetivos y exclusiones

### Objetivos

- reutilizar `FlowBlock`, `FlowOutputBlock`, sus hooks de validación/remapeo y el
  executor polimórfico ya existente;
- separar discovery, validación, catálogo, creación, autoría, persistencia y
  ejecución;
- conservar compatibilidad con proyectos, escenas, bloques, IDs, orden, posiciones
  `null` y schemas actuales;
- permitir que un paquete inválido no oculte ni invalide silenciosamente a sus
  hermanos válidos;
- hacer visible la falta de una dependencia sin destruir datos del usuario;
- mantener una experiencia Inspector → Fluo → Flow → Flusso única y no duplicada;
- validar visualmente el drawer en escritorio y Android antes de retirar el fallback.

### Exclusiones deliberadas

- no se genera un bloque ni se declara completado el builder funcional en esta
  entrega; la Skill inicial de planificación queda registrada por separado;
- no se implementa `FlowIfBlock`, `IF` ni otra lógica de ramificación;
- no se añaden campos al manifiesto v1;
- no se introduce un schema nuevo ni una migración;
- no se mueven los bloques integrados actuales a `res://flow_packages`;
- no se elimina ni oculta el dock legacy ni `Open Fluo (POC)`;
- no se implementa hot reload, descarga de red, firma criptográfica, permisos o
  ejecución de código arbitrario desde JSON;
- no se refactoriza el código de Fluo antes de que la matriz Android del preview sea
  aceptada.

## 5. Vocabulario y fronteras de arquitectura

- **Inspector:** Godot Inspector; conserva la selección de contenedores por ID y es
  el punto de entrada.
- **Fluo:** drawer contextual completo.
- **Flow:** panel izquierdo del drawer que lista bloques.
- **Flusso:** panel derecho que configura el bloque seleccionado.
- **FlowGraph/FlowBlock:** modelo persistente y portable.
- **Catálogo:** proyección efímera de cosas que se pueden autorizar en el editor.
- **Paquete:** contenido de usuario bajo `res://flow_packages/<package_id>/`.
- **Registry integrado:** `FlowBlockRegistry`; es la superficie actual de compatibilidad
  para bloques integrados del plugin. Durante la transición seguirá funcionando, pero no
  es el destino arquitectónico final de los bloques distribuibles oficiales.
- **Runtime:** carga, valida y ejecuta contratos portables; nunca usa
  `EditorInterface`, `EditorUndoRedoManager` ni controles del editor.
- **Editor:** adapta el catálogo al Inspector/Fluo y registra undo/redo.

Un paquete nunca se convierte en una dependencia implícita del plugin. El plugin
puede leerlo y mostrar diagnósticos; el paquete no puede convertir al editor en su
fuente de verdad.

## 6. Invariantes que deben permanecer protegidos

1. Los IDs internos se generan por `FlowId`, no por nombre, índice, ruta ni tipo de
   autoría.
2. Renombrar, mover o reordenar no cambia IDs.
3. Duplicar genera IDs nuevos y remapea referencias con un mapa completo
   old-ID → new-ID.
4. El orden de arrays y las posiciones `null` se conservan.
5. Un schema existente no se cambia sin migración atómica, probada y explícita.
6. Los recursos persistentes no se mutan durante discovery, validación o ejecución.
7. Runtime no depende de APIs de editor.
8. Las modificaciones del editor pasan por comandos undoables y por el
   `PVController` propietario.
9. El nombre visible nunca es identidad ni destino de una referencia.
10. Flusso conserva edición inmediata, cierre sin commit/cancel y `Revertir` sobre
    el snapshot de sesión.
11. El foco semántico se guarda por ID y no por una referencia a un `Control`
    reconstruido.
12. Una ausencia de paquete genera diagnóstico; nunca borra automáticamente un
    bloque, una escena o un proyecto.

## 7. Clasificación operativa A/B/C/D

Se propone la siguiente clasificación para decidir qué puede entrar en una entrega.
Es una herramienta de alcance, no una nueva jerarquía de clases.

| Clase | Característica | Permitido en el primer bloque | Dependencias adicionales |
| --- | --- | --- | --- |
| **A — salida/pura** | Deriva de `FlowOutputBlock`, produce un mensaje determinista y no transfiere control. | Sí | Sólo contrato `FlowOutputBlock` y campos escalares opcionales. |
| **B — datos/configuración** | Lee o transforma campos tipados, sin saltos ni acceso directo a nodos del editor. | Sí, después de cerrar Flusso genérico | Metadata de campos, persistencia y validación de tipos. |
| **C — navegación/control** | Decide `CONTINUE`, `JUMP` o `STOP`, o introduce caminos alternativos. | No | Contrato de navegación, presupuesto, diagnósticos y pruebas de ciclos. `IF` queda fuera. |
| **D — integración/efectos** | Usa nodos, escenas, recursos externos, IO, editor o servicios del proyecto. | No | Contratos de bindings, seguridad, portabilidad, ciclo de vida y revisión específica. |

Regla: una solicitud con características de varias clases se clasifica en la clase
de mayor riesgo y no se descompone implícitamente para evitar sus dependencias.

## 8. Contrato genérico de bloque

El contrato actual de `FlowBlock` ya ofrece identidad, nombre, `enabled`, nota,
`validate_structure(context)` y `remap_internal_references(id_map)`. Sus hooks base
son no-op y la validación/duplicación del grafo los invoca en puntos definidos.

El contrato futuro debe mantener esta forma conceptual:

```gdscript
@tool
extends FlowBlock

func validate_structure(context: Dictionary) -> void:
	# Sólo añade diagnósticos deterministas; no repara el bloque.
	pass

func remap_internal_references(id_map: Dictionary[String, String]) -> void:
	# Remapea únicamente referencias persistentes propias del bloque.
	pass
```

Un bloque externo no puede:

- sobrescribir `_internal_id` con el `type_id` del paquete;
- depender de `FlowBlockRegistry` para existir;
- añadir una rama concreta al executor;
- guardar `Node`, `NodePath`, `Callable` o estado de ejecución como identidad;
- llamar a `EditorInterface` desde runtime.

Para la clase A, el contrato existente es suficiente:

```gdscript
@tool
extends FlowOutputBlock

@export var message: String = ""

func get_output_message() -> String:
	return message
```

La implementación no debe declarar `class_name` global salvo que una futura
especificación lo justifique; el `package_id:type_id` evita colisiones de nombres
globales. La script debe ser instanciable por el editor y portable en runtime.

### 8.1 Infraestructura del BLOCK SDK ya implementada — no reconstruir

La investigación y el código actual confirman como **ya implementado**:

- `FlowBlock` como contrato base persistente, con `_internal_id` estable,
  `display_name`, `enabled`, `user_note`, `validate_structure()`,
  `remap_internal_references()`, `get_navigation_decision()` y duplicación con ID
  nuevo;
- `FlowId` y persistencia polimórfica en `Array[FlowBlock]`, incluyendo
  `ResourceSaver`, `PackedScene`, duplicación y conservación de orden/posiciones
  `null` según los schemas vigentes;
- `FlowOutputBlock` como contrato de salida compartido;
- `FlowNavigationDecision` y `FlowNavigationContext`, con `CONTINUE`, `JUMP` y
  `STOP`, y un `FlowReadyExecutor` que resuelve destinos por ID sin ramas por tipo;
- `FlowGraphValidator` conectado a `validate_structure()` y el remapeo genérico
  conectado a la duplicación mediante el mapa completo old-ID → new-ID;
- manifest v1, `FlowPackageManifestLoader`,
  `FlowExternalBlockScriptValidator`, `FlowEditorBlockCatalog` y
  `FlowExternalBlockFactory`;
- la identidad de autoría externa `package_id:type_id`, separada del ID persistente
  de cada instancia;
- validación genérica, remapeo genérico y pruebas focales de manifest, discovery,
  scripts, catálogo, factory, hooks, navegación y persistencia/runtime del primer
  bloque integrado.

Nada de lo anterior debe volver a implementarse dentro de `flujo-block-builder` ni
duplicarse como otro registry/API. D1 sólo documenta el perfil público, añade
fixtures o cobertura autorizada y verifica la integración de lo existente.

### 8.2 Infraestructura existente y límites posteriores a D3

El estado actual es deliberadamente mixto y D3 ya está cerrado:

- Flow/Fluo conserva el registry para integrados, pero comparte un contexto de
  authoring con el catálogo y la factory externa;
- `FlowEditorBlockCatalog` y `FlowExternalBlockFactory` están conectados a la ruta
  normal Add de Flow mediante `authoring_id` y comandos undoables;
- el ciclo externo de descubrir, añadir, seleccionar, mover y eliminar reutiliza la
  ruta común y no añade ramas por paquete o tipo concreto;
- la creación externa es independiente del contenedor compatible que aloje el
  `FlowBlock`; el contenedor controla la secuencia y el bloque conserva su contrato;
- Flusso conserva la selección/activación común y la frontera explícita de
  propiedades owned, y D4-A/B/C ya aporta el renderer genérico por
  reflexión/metadata para el conjunto escalar aprobado;
- el paquete temporal de revisión no es dogfooding permanente; el fixture manual
  bajo `tests/fixtures/manual_block_sdk/` permanece como evidencia.

Por tanto, la existencia de catálogo y factory puede describirse como soporte
end-to-end para el Add/selección/estructura cubiertos por D3, y D4-C añade soporte
genérico de Flusso dentro de la frontera escalar aprobada. Esto no equivale a
soporte end-to-end de procedencia, ciclo de vida, widgets arbitrarios o Debug
Panel. Esos límites siguen explícitos y no pueden ocultarse con la Skill.

### 8.3 Diseñado pero no implementado

Continúan fuera de esta misión y no deben presentarse como disponibles:

- bloque externo IF y editor de IF;
- paquete real de dogfooding y primer bloque externo estándar;
- widgets arbitrarios/propiedades complejas fuera de la superficie escalar D4 v1
  aprobada;
- UX de paquete desaparecido, placeholder, eliminación y restauración;
- promoción de un bloque incubado a una biblioteca oficial sin reescribir su
  implementación;
- el builder funcional end-to-end y sus pruebas de salida; la Skill inicial de
  planificación ya existe, pero no genera bloques en este checkpoint.

## 9. Primer bloque de dogfooding futuro — FPrint

Cuando exista el builder —si se decide usarlo— el primer dogfood planificado será
`FPrint`, distinto de `Print`. Se espera que ejercite un bloque simple de clase A,
ilustrativamente un paquete oficial `mercury.<id_aprobado>` con un único campo de
mensaje y una salida determinista, pero esa expectativa no es todavía una
especificación congelada. El `package_id`, `type_id`, nombre visible, mensaje,
capacidad final y clasificación A/B/C/D requieren aprobación; no se reutilizará
el `custom_hello` integrado ni se moverá esa prueba existente. La creación manual
del mismo paquete seguirá siendo válida y equivalente.

Antes de crear cualquier archivo FPrint, la solicitud debe pasar el workflow de
`flujo-block-builder`: recuperar contexto, clasificar por capacidad, especificar,
planificar implementación y validación, recibir revisión humana y obtener
`🙆🏻` explícito. Una clasificación C o D detiene el dogfood hasta aprobar la
extensión pública o el trabajo de core correspondiente. No existe un paquete
FPrint en este checkpoint.

Su función arquitectónica será probar, en este orden:

1. paquete independiente;
2. manifiesto v1 sin campos nuevos;
3. script externo que deriva de `FlowOutputBlock`;
4. creación por factory y nuevo ID;
5. persistencia `ResourceSaver` y `PackedScene`;
6. configuración genérica de un campo en Flusso;
7. ejecución por el mismo `FlowReadyExecutor` y `FlowRuntimeOutput`;
8. duplicación y remapeo sin conocimiento específico del bloque.

No tendrá navegación, acceso a nodos, recursos arbitrarios, dependencias de otro
paquete ni lógica `IF`. Este bloque continúa fuera de la misión actual: aquí sólo
se fija el criterio de selección para el futuro dogfooding.

## 10. Frontera de `flujo-block-builder`

El builder y su Skill son herramientas de autoría/desarrollo, no una dependencia de
runtime ni un requisito para crear bloques. Su salida mínima será un directorio de
paquete revisable, no un registro global ni un binario opaco. Sólo automatizan la
estructura, validación, pruebas y convenciones que también están disponibles para
la autoría manual.

Entrada propuesta:

- `package_id` y `type_id` validados;
- nombre visible y licencia;
- plantilla de clase A/B aprobada;
- campos declarativos permitidos;
- datos de procedencia declarados.

Salida propuesta:

```text
res://flow_packages/<package_id>/
  manifest.json
  provenance.json                 # sidecar propuesto; no es manifest v1
  block.gd
  block_property_presentation.json # opcional; metadata declarativa, no manifiesto
  README.md
```

El perfil de distribución generado contiene exactamente un descriptor de bloque y
un paquete independiente. El loader v1 puede seguir leyendo manifiestos históricos
con varios descriptores, pero el builder no usará esa forma como salida
predeterminada.

El builder debe ser reproducible manualmente: una persona puede crear los mismos
archivos sin el builder y obtener el mismo resultado semántico. No debe generar
rutas absolutas, IDs persistentes de bloques, credenciales ni código que dependa de
un sistema operativo. Su implementación futura puede ser un job GDScript headless
en `tools/`, pero esa elección no se cierra aquí.

### Estado actual de la Skill inicial

La Skill inicial está creada en `tools/agent_skills/flujo-block-builder/SKILL.md` y
es un workflow de planificación explícita, no la aceptación funcional de D5. El
principio operativo es **la Skill automatiza el SDK público; la Skill no es el SDK**.
La autoría manual sigue siendo equivalente, el paquete sigue siendo legible y el
runtime no depende de la Skill. Ningún bloque fue generado por esta creación.

Cada solicitud debe recuperar contexto, clasificar capacidades, producir
especificación, plan de implementación y plan de validación, pasar revisión humana
y esperar `🙆🏻` explícito antes de construir. Las capacidades se clasifican como
`A — SDK-supported now`, `B — SDK-supported but authoring-limited`,
`C — SDK extension required` o `D — Core-only capability`; pueden mezclarse. Una
solicitud C/D se detiene con la brecha y el plan de extensión explicado, sin parche
silencioso al núcleo.

### Gate exacto antes de la generación funcional v1

El diseño y el workflow de planificación de `flujo-block-builder` pueden existir
antes, pero **la generación y aceptación de `flujo-block-builder v1` no comienza
hasta que el
camino manual y la experiencia estándar de autoría estén disponibles de extremo a
extremo**. El gate queda así:

1. perfil SDK manual sobre la infraestructura existente (D1), incluida detección de
   capacidades y clasificación de solicitudes;
2. contrato mínimo de Theme + Motion implementado en componentes host reutilizables
   (D2): estados, ownership, foco/input y configuración declarativa, sin exigir el
   pulido visual final;
3. catálogo/factory externos conectados al Add normal de Flow sin ramas por tipo
   (D3);
4. Flusso genérico mediante reflexión + metadata validada para los campos A/B
   soportados (D4-A/B/C);
5. equivalencia comprobable entre autoría manual y automatizada, sin IDs persistentes
   generados por la Skill, rutas absolutas ni dependencia de la Skill;
6. matriz que declare qué puede generar el builder y qué debe detenerse como
   `SDK extension required`.

La Skill de planificación no satisface este gate. D5 se considera completo sólo
cuando la implementación funcional de v1 genera una salida ordinaria, validable y
manualmente reproducible, y el paquete generado recorre el flujo estándar:
paquete creado por Skill o a mano → Add de Flow → configuración de Flusso →
persistencia → runtime. El primer dogfood FPrint se mantiene separado de esta
decisión de disponibilidad: no puede comenzar mientras su especificación y su
clasificación A/B/C/D sigan sin aprobar.

#### Definición de aceptación funcional de D5

La futura entrega D5 debe demostrar, como mínimo:

- **A — salida:** un paquete canónico, independiente y de un solo bloque, con
  archivos ordinarios revisables y sin rutas absolutas ni IDs persistentes
  generados por la Skill;
- **B — determinismo:** dos ejecuciones limpias y la recreación manual producen
  contenido semánticamente equivalente; entradas inválidas o capacidades no
  soportadas se rechazan con diagnósticos reproducibles;
- **C — SDK público:** el resultado usa exactamente el contrato público manual,
  no depende de la Skill en runtime y se valida con el mismo loader, factory,
  Flow, Flusso, persistencia y runtime;
- **D — gobernanza:** cada solicitud pasa la clasificación A/B/C/D y la revisión
  humana; C/D detiene la generación para aprobar la extensión mínima, y el
  builder no modifica silenciosamente el núcleo;
- **E — mantenimiento:** eliminar la Skill no impide cargar, editar, probar,
  mantener o distribuir el paquete generado.

Hasta que A–E estén demostrados, D5 permanece futuro aunque exista la Skill de
planificación.

## 11. SDK público y reproducible

La versión inicial del SDK será un contrato documental con fixtures, no una API de
servicios ni una capacidad exclusiva del builder. El procedimiento manual será:

1. crear la carpeta del paquete fuera de `addons/vp_flujo`;
2. escribir el manifiesto JSON v1 con orden estable;
3. escribir la script `@tool` que derive de un contrato permitido;
4. ejecutar discovery de metadata;
5. ejecutar validación de script;
6. ejecutar factory sobre una entrada válida;
7. guardar, recargar, duplicar y ejecutar una fixture;
8. revisar diagnósticos y diff de los archivos generados.

La documentación del SDK deberá fijar:

- versión del contrato del SDK separada de `schema_version` del grafo;
- versión mínima Godot: 4.7.2;
- tipos de campos soportados;
- orden de validación y códigos de diagnóstico;
- reglas de rutas relativas;
- límites editor/runtime;
- política de licencias y procedencia;
- comandos exactos de prueba.

No se usará una red externa para descubrir, validar o restaurar paquetes. La
reproducibilidad se comprueba con fixtures locales, JSON canónico y resultados
deterministas, no con la presencia de un servicio.

## 12. Contrato JSON del manifiesto v1

El manifiesto aprobado se conserva exactamente como está definido en
`docs/model_contract.md`:

```json
{
  "manifest_version": 1,
  "package_id": "mercury.simple_output",
  "blocks": [
    {
      "type_id": "simple_output",
      "script": "block.gd",
      "display_name": "Simple Output"
    }
  ]
}
```

Sus únicos campos v1 son `manifest_version`, `package_id` y `blocks`; cada descriptor
tiene `type_id`, `script` y `display_name`. `script` es una ruta relativa al paquete,
sin escape mediante `..`. El loader mantiene orden de paquetes y de descriptores.

La política aprobada de distribución es **un bloque distribuible por paquete**.
No se fuerza cambiando el loader v1: un manifiesto histórico con varios
descriptores sigue siendo legible mientras la especificación de compatibilidad no
disponga lo contrario. El builder y la documentación del perfil de distribución
generarán exactamente un descriptor. La compatibilidad histórica no convierte el
paquete monolítico en la solución predeterminada.

No se añadirá `provenance`, `block_property_presentation`, dependencia, permiso o checksum al
manifiesto v1. Cada dato nuevo debe demostrar primero que pertenece a ese contrato y
no a un sidecar o a una versión posterior.

## 13. Topología de paquetes independientes

La topología canónica aprobada para la distribución es un paquete por bloque:

```text
res://flow_packages/
  mercury.print/
    manifest.json
    provenance.json
    block.gd
    block_property_presentation.json
    README.md
  mercury.everything_flows/
    manifest.json
    provenance.json
    block.gd
    README.md
  usuario.mi_bloque/
    manifest.json
    provenance.json
    block.gd
    README.md
```

Los nombres anteriores son ejemplos de package IDs y no declaran que esos paquetes
ya existan en este repositorio. Diez bloques distribuibles ocupan diez carpetas.

Reglas:

- `package_id` debe coincidir con el nombre de la carpeta;
- cada paquete distribuible contiene un solo bloque como perfil canónico; no se usa
  un paquete monolítico como solución predeterminada;
- el paquete no se instala dentro de `res://addons/vp_flujo/`;
- un paquete no importa otro paquete en el perfil inicial;
- los assets opcionales usan rutas relativas y se validan antes de mostrarse;
- el plugin no copia ni modifica archivos durante discovery;
- una instalación futura será una operación explícita del editor, con respaldo y
  undo lógico donde sea posible;
- el paquete oficial se instala en la misma raíz de proyecto, no se trata como
  código privilegiado del plugin;
- el objetivo final es que bloques oficiales y de usuario usen esta misma topología.
  Los bloques integrados actuales sólo se migran después, uno por uno, mediante una
  estrategia explícita de compatibilidad (D9).

## 14. Identidad, namespace y procedencia

Hay tres identidades diferentes:

| Identidad | Ejemplo | Persistencia/uso |
| --- | --- | --- |
| paquete y tipo de autoría | `mercury.print:print` | catálogo, diagnósticos y creación |
| bloque persistente | `FlowId` de 32 caracteres | modelo, referencias, selección y duplicación |
| origen declarado | `publisher/source_revision` | auditoría y restauración, si el contrato futuro lo aprueba |

El `package_id:type_id` no sustituye el ID del bloque. Dos instancias creadas desde
el mismo descriptor deben tener IDs distintos. Un nombre visible igual tampoco
indica que dos bloques sean intercambiables.

Para bloques externos creados hoy, el modelo actual no guarda todavía un registro
de origen dedicado. No se inferirá un origen desde `display_name` o desde una ruta
durante esta planificación. La persistencia de origen y el placeholder de paquete
ausente requieren una decisión de schema separada (sección 22).

El paquete externo funciona como incubadora: una promoción futura a biblioteca
oficial debe reutilizar la misma script, manifest compatible y pruebas, sin reescribir
el comportamiento del bloque. El mecanismo exacto de publicación, instalación y
actualización sigue sin implementarse y requiere la decisión de la sección 30.

## 15. Procedencia v1 declarada, no criptográfica

Se propone un sidecar separado `provenance.json`; no es un campo del manifiesto v1
ni una firma de autenticidad. Su propósito es responder “quién declara de dónde
proviene esto” y permitir auditoría humana reproducible.

Forma propuesta para un bloque oficial publicado por Mercury:

```json
{
  "provenance_version": 1,
  "package_id": "mercury.simple_output",
  "origin_kind": "official",
  "author_id": "mercury",
  "author_name": "Mercury",
  "publisher_id": "mercury",
  "publisher_name": "Mercury",
  "source_locator": "declared://mercury/simple_output",
  "source_revision": "release-0.1.0",
  "sdk_contract": "flow-block-sdk/v1",
  "godot_minimum": "4.7.2",
  "license": "MIT"
}
```

`author_*` identifica quién creó o mantiene intelectualmente el bloque; `publisher_*`
identifica quién distribuye esa versión del paquete. Pueden coincidir, como en un
bloque oficial creado y publicado por Mercury, o ser distintos en una futura
contribución comunitaria distribuida por otro publisher. Para un paquete personal,
el usuario puede declararse a sí mismo en ambos roles. En todos los casos son
metadata declarada, no identidad inferida desde nombre o ruta ni autenticidad
criptográfica.

Reglas de cualquier identificador declarativo opcional que se agregue después:

- se genera de forma determinista con los campos declarados y orden canónico;
- no usa clave secreta, certificado, hash como prueba de integridad ni autoridad
  remota;
- sólo puede indicar consistencia textual entre la declaración, `package_id` y la
  revisión indicada;
- nunca se muestra como “verificado”, “oficialmente autenticado” o “seguro” por el
  mero hecho de coincidir;
- una procedencia ausente produce “desconocida”, no un bloqueo automático;
- una procedencia mal formada produce diagnóstico y puede dejar el paquete fuera
  del catálogo si así lo decide la futura política de distribución;
- `source_locator` no puede ser una ruta absoluta de la máquina del autor.

Una futura firma criptográfica deberá ser otro contrato y otra versión. No se
mezclará con la procedencia declarada ni se prometerá seguridad criptográfica en
v1.

## 16. Discovery, validación y diagnósticos

El pipeline debe conservar las fases ya separadas. Las dos primeras y la base de
catálogo/factory ya existen; la validación de perfil sigue futura y la autoría D3
ya está implementada:

1. **[IMPLEMENTADO] Discovery de metadata:** `FlowPackageManifestLoader` lee JSON, ordena
   `package_id`, conserva orden interno y no carga scripts.
2. **[IMPLEMENTADO] Validación de scripts:** `FlowExternalBlockScriptValidator` comprueba archivo,
   `Script`, instanciabilidad y herencia de `FlowBlock` sin retener instancias.
3. **[PROPUESTO] Validación del perfil:** comprueba, cuando se apruebe, paquete de un bloque,
   sidecars, procedencia y schema de editor.
4. **[IMPLEMENTADO] Catálogo efímero:** `FlowEditorBlockCatalog` combina primero el registry
   integrado y después paquetes válidos en orden determinista.
5. **[IMPLEMENTADO] Factory:** `FlowExternalBlockFactory` revalida antes de instanciar, comprueba
   ID nuevo y devuelve bloque o diagnósticos ordenados.
6. **[IMPLEMENTADO — D3] Autoría:** el editor transforma `authoring_id` en una acción
   undoable del controlador; el contexto/factory devuelve un resultado explícito y no
   escribe directamente desde el popup.

Un paquete inválido no invalida hermanos válidos. Un descriptor inválido no entra al
catálogo. Discovery no ejecuta código de paquete. La creación sí instancia la
script validada en el límite controlado del editor/runtime, y cualquier error debe
producir un resultado explícito, no un `null` ambiguo.

## 17. Catálogo, registry y executor

El estado D3 conserva la transición: `FlowEditorBlockCatalog` proyecta entradas
integradas y externas, y `FlowReadyProcessEditor` obtiene sus Add controls desde el
contexto de authoring compartido. El registry integrado sigue siendo la factory de
compatibilidad para los bloques built-in; los externos entran por la factory común.

La integración futura se divide en dos etapas:

- **Transición:** `FlowBlockRegistry` conserva `Print`, `Everything Flows`,
  `Custom Hello` y otros integrados actuales para no romper proyectos ni rutas de
  recursos existentes mientras el editor adopta el catálogo común.
- **Destino arquitectónico:** los bloques distribuibles oficiales de Mercury deben
  poder migrar gradualmente al mismo estándar `res://flow_packages/<package_id>/`
  usado por los bloques del usuario, un paquete independiente por bloque. El
  registry integrado queda entonces como compatibilidad/migración o infraestructura
  estrictamente interna, no como un segundo ecosistema de bloques distribuibles.
- un adaptador de editor obtiene `FlowEditorBlockCatalog` una vez por contexto de
  authoring y entrega entradas al mismo Add row;
- durante la transición, los integrados mantienen orden, nombres, controles,
  undo/redo y comportamiento existentes; ninguna migración se hace implícitamente;
- los externos se crean por la factory común y se insertan por
  `FlowGraphEditorCommands`;
- Flow debe poder descubrir y mostrar la entrada, añadirla por el mismo Add row,
  seleccionar la instancia por ID, moverla y eliminarla por comandos undoables;
- Flow debe representar la procedencia declarada disponible para el catálogo, sin
  confundirla con autenticidad criptográfica;
- Theme y Motion se aplican desde el host Fluo a la misma superficie, no desde la
  script del bloque ni desde un widget arbitrario del paquete;
- `FlowReadyExecutor` continúa preguntando por contratos polimórficos como
  `FlowOutputBlock`, no por `package_id`, clase concreta o `IF`;
- no se registra una clase externa en un singleton global del plugin;
- no se escanea el filesystem desde el executor.

## 18. Configuración de Flusso: decisión recomendada

La recomendación es una **combinación de metadata declarativa y reflexión limitada**.
Para el caso estándar, la reflexión debe bastar por sí sola cuando el tipo/hint de
Godot y la semántica del control sean inequívocos; la metadata sólo completa la
intención que la reflexión no puede expresar:

- la reflexión obtiene la verdad técnica del objeto: propiedades exportadas,
  tipos, hints, usage y existencia real;
- metadata JSON opcional declara intención de UI: orden, etiqueta, tipo visual,
  multilinea, tooltip y restricciones permitidas;
- la validación compara ambos conjuntos antes de construir controles;
- la script sigue siendo la fuente de tipos y valores persistentes;
- la metadata no puede ejecutar callbacks, cambiar defaults ni declarar referencias
  que no existan en la script.

Este enfoque permite que un bloque simple se integre sin editar el núcleo de
Flusso. Un bloque que necesite una capacidad que no entre en el renderer común debe
detenerse en la clasificación de la Skill como `SDK extension required`, no
introducir silenciosamente un branch por tipo.

### Alternativas rechazadas

- **Sólo reflexión:** no expresa bien orden, etiqueta, semántica multilinea,
  localización ni políticas de presentación.
- **Sólo metadata:** permite drift entre JSON y propiedades reales y puede presentar
  campos que no se pueden guardar.
- **Un branch por bloque:** duplica lógica en Flusso y convierte cada bloque en una
  excepción no escalable.
- **Widgets arbitrarios suministrados por el paquete:** mezclan código externo con
  el editor, hacen difícil la seguridad y rompen la reproducibilidad.

## 19. `block_property_presentation.json` y campos genéricos

D4-A resuelve la terminología histórica `editor_schema.json` en favor de
`block_property_presentation.json`, un sidecar opcional de metadata declarativa
que puede ser consumido por Flusso y, cuando sea seguro y esté incluido en el
export, por el futuro Debug Panel. No se añade su ruta al manifiesto v1. El
contrato completo está en [FlowBlock Property Presentation Contract](flow_block_property_presentation_contract.md).
Un ejemplo mínimo es:

```json
{
  "format_version": 1,
  "block_type_id": "hello_message",
  "properties": [
    {
      "property": "message",
      "label": "Message",
      "order": 10,
      "tooltip": "Text emitted by this block.",
      "presentation": "multiline"
    }
  ]
}
```

El conjunto inicial aprobado es `bool`, `int`, `float`, `String` y `StringName`.
Los hints estándar de Godot (`range`, `enum` y multilinea) sólo se aceptan
cuando la reflexión ya describe una propiedad compatible. Quedan fuera de D4 v1
`Node`, `NodePath`, `Callable`, recursos arbitrarios, arrays editables,
callbacks, expresiones condicionales, widgets personalizados y navegación.

Validaciones obligatorias:

- `property` existe en el objeto instanciado, es un campo script-visible y es
  exportable/persistible según la regla D4-A;
- `presentation` es compatible con el tipo y hint de Godot y nunca suministra
  defaults, tipos, límites o valores enum;
- `_internal_id` y el estado interno nunca se exponen; `display_name`, `enabled`,
  `text` y `method_id` quedan fuera del renderer genérico cuando un control
  explícito los posee; un campo no es Flusso-owned sólo por existir;
- no hay propiedades repetidas ni órdenes ambiguos;
- campos desconocidos son diagnóstico, no se ignoran silenciosamente;
- defaults y valores se leen de la script; metadata sólo presenta;
- metadata no ejecuta código, carga escenas/scripts ni instala widgets.

## 20. Integración Inspector → Fluo → Flow → Flusso

La integración no crea una segunda lista de bloques en Inspector.

Flujo propuesto para un externo:

1. Inspector activa el contenedor existente por stable ID.
2. Fluo abre con Flow visible y Flusso cerrado según Preview 1.
3. Flow usa el catálogo para poblar sólo el Add row; la lista existente sigue
   seleccionando bloques por ID.
4. Crear un bloque llama al factory y registra una operación undoable.
5. La fila creada conserva el ciclo común de selección, movimiento y eliminación,
   siempre por ID estable y por comandos undoables; Flow puede mostrar la
   procedencia declarada de la entrada.
6. Activar el bloque abre Flusso; el panel común construye campos a partir de la
   reflexión y del schema/metadata validado cuando exista.
7. Un cambio de campo aplica inmediatamente al recurso a través del comando
   propietario.
8. El snapshot de sesión permite `Revertir`; cerrar no decide commit/cancel.
9. Rebuilds restauran foco al mismo ID y nunca reutilizan un `Control` destruido.
10. Theme y Motion pertenecen a los componentes host de Fluo; el bloque sólo
    describe sus campos y no anima sus controles ni posee el foco del drawer.

Archivos probablemente afectados en una entrega futura:

- `addons/vp_flujo/editor/flow_ready_process_editor.gd`;
- `addons/vp_flujo/editor/flow_graph_editor_commands.gd`;
- `addons/vp_flujo/editor/flow_graph_inspector_property.gd`;
- `addons/vp_flujo/editor/fluo_drawer.gd`;
- un adaptador nuevo de catálogo y, si se aprueba, un presentador de campos
  genéricos.

No se debe editar `flow_ready_process_editor.gd` para añadir una rama por cada
`package_id` o tipo externo.

## 21. Persistencia, duplicación y compatibilidad

El primer paquete debe persistir mediante el `Array[FlowBlock]` polimórfico vigente,
sin schema nuevo. Deben preservarse:

- script concreta al guardar/cargar `ResourceSaver`;
- script concreta al guardar/cargar `PackedScene`;
- ID original después de recargar;
- ID nuevo y referencias remapeadas al duplicar;
- orden y posiciones `null`;
- `enabled`, nombre, nota y campos exportados;
- comportamiento de esquemas 1–5 y migraciones existentes.

La selección de un bloque externo en el editor se basa en su ID persistente. La
clave de catálogo sólo se usa para construir una nueva instancia. No se cambiarán
las rutas de los bloques integrados actuales ni se convertirá una escena existente
por una migración implícita.

## 22. Paquetes ausentes y contrato de origen persistente

La ausencia de un paquete revela una tensión que no debe ocultarse: un recurso
polimórfico puede no poder instanciar la script concreta si el archivo desaparece.
El fundamento actual sólo diagnostica scripts inválidas; todavía no promete
rehidratación de bloques faltantes.

Antes de implementar eliminación/restauración se debe aprobar una de estas formas:

1. **Registro de origen en el bloque:** un recurso opcional `FlowBlockOrigin`
   asociado al ID, con `package_id`, `type_id`, versión de contrato y revisión
   declarada. Requeriría un schema y migración explícitos.
2. **Colección lateral del grafo:** mapa persistente de ID de bloque a origen, sin
   modificar cada subtipo, también con schema y migración explícitos.
3. **Envelope/placeholder:** representación `FlowMissingBlock` que preserve ID,
   origen y los campos escalares permitidos, con conversión explícita y reversible.

La recomendación es combinar un origen opcional con un placeholder limitado al
conjunto de campos que el SDK pueda serializar sin ejecutar la script. No se debe
inventar un origen a partir del nombre o de una ruta. La decisión debe incluir
payload desconocido, recursos no disponibles, IDs, undo, `ResourceSaver` y
`PackedScene`.

Hasta aprobarla, una carpeta eliminada manualmente se reporta como caso no
soportado para restauración automática y no se declara cubierto por el SDK.

## 23. Eliminación individual y restauración oficial

La operación futura de paquete será explícita y por `package_id`:

1. discovery y validación actuales;
2. inventario de grafos/escenas que referencian el paquete, cuando el origen exista;
3. diagnóstico de referencias desconocidas o no convertibles;
4. respaldo local en una ubicación ignorada y controlada;
5. confirmación humana con nombre y ruta exactos;
6. eliminación sólo de esa carpeta, nunca de `flow_packages` completo;
7. conversión a placeholder sólo si el contrato aprobado lo permite;
8. rescan y actualización del catálogo sin borrar bloques no relacionados.

La restauración oficial debe aceptar una fuente local declarada, no descargar nada:

- el paquete oficial se copia a `res://flow_packages/<package_id>/` sólo después de
  validar manifest, script, procedencia y contrato;
- se comprueba que `package_id`, `type_id` y versión sean compatibles;
- el placeholder se rehidrata sólo por una acción explícita y undoable;
- el ID del bloque, nombre personalizado, enabled, nota y valores compatibles se
  conservan;
- si la versión no es compatible, se mantiene el placeholder y el diagnóstico;
- “official” significa declaración de procedencia, no autenticidad criptográfica.

El plugin no guardará paquetes de usuario dentro de sí mismo. Un paquete oficial
distribuido junto al addon necesitará un mecanismo explícito de instalación hacia la
raíz del proyecto y no será una excepción silenciosa a esta regla.

## 24. Versiones, dependencia y distribución

Se mantienen separadas cuatro versiones:

1. `manifest_version`: formato JSON del manifiesto;
2. `schema_version`: formato persistente del `FlowGraph`;
3. `sdk_contract`: capacidades que una script puede usar;
4. `provenance_version`: formato de la declaración de origen.

Una versión de SDK no autoriza por sí sola una migración de grafo. La compatibilidad
inicial recomendada es:

- Godot 4.7.2;
- `manifest_version = 1`;
- `FlowBlock` o derivado permitido;
- sin dependencias entre paquetes;
- sólo APIs portables en scripts de runtime;
- sidecars opcionales y desconocidos tratados según contrato, no ejecutados.

Hot reload, dependencias, resolución de versiones, permisos, firma criptográfica,
repositorio remoto y publicación automática quedan para contratos posteriores.

## 25. Theme de Fluo y paquetes

Themes debe vivir en el host/editor, no en cada bloque. La dirección recomendada es:

- un `Theme` o adaptador central de Fluo derivado del theme activo del editor;
- roles semánticos y type variations para títulos, filas, campos, botones,
  diagnósticos, selección, foco y estados disabled;
- StyleBoxes compartidos con cuidado, sin mutar accidentalmente dos controles;
- overrides locales sólo donde exista una razón de contrato y con revisión visual;
- icono/metadato opcional del paquete como recurso declarado, nunca como un Theme
  arbitrario que reconfigure todo el editor;
- texto público en inglés y localización separada de la lógica de bloques;
- contraste, foco visible, tamaños táctiles y lectura a escala incluidos en la
  matriz manual.

### Contrato mínimo que debe existir antes de `flujo-block-builder`

Antes de implementar la Skill deben estar definidos y mínimamente implementados,
sin exigir el pulido artístico final:

- componentes visuales reutilizables para shell, filas de Flow, campos de Flusso,
  botones, diagnósticos, selección, foco y estados disabled;
- estados visuales y su relación con el estado semántico, incluyendo vacío,
  seleccionado sin foco, foco de teclado, disabled, error y transición;
- ownership: el Theme y sus roles pertenecen al host/editor de Fluo; un paquete no
  puede instalar un Theme arbitrario ni reconfigurar el editor;
- ownership de Motion y foco: el host coordina transición, foco y rebuild; el
  bloque sólo expone datos/configuración declarativa;
- reglas de interacción comunes para mouse, touch, teclado, `mouse_filter`,
  scroll, backdrop y targets táctiles;
- un descriptor de configuración que no permita que el bloque cree o anime sus
  propios `Control` del editor.

Este contrato habilita al builder sin congelar el arte visual definitivo. Un bloque
externo no debe cambiar por sí mismo la duración, easing, foco o Theme de Fluo.

No se hace ahora un refactor de todos los `add_theme_*_override` existentes. La
extracción se hará después de aceptar el preview y en una entrega que pueda
compararse visualmente.

## 26. Motion de Fluo

Motion será una política de presentación editor-only, no estado persistente del
`FlowGraph`. Debe tener:

- estados `closed`, `opening`, `open`, `switching_side` y `closing`;
- una sola fuente de verdad para duración, easing, dirección y reduced motion;
- bloqueo o enrutamiento definido de input durante la transición;
- foco asignado después de que la geometría final exista;
- cancelación segura al cambiar de contenedor, reconstruir o cerrar el plugin;
- ningún tween que retenga un nodo ya liberado;
- pruebas de reabrir, cerrar, Escape, cambio de lado y rebuild.

La animación no debe modificar nombres, IDs, snapshots, selección del Inspector ni
valores de modelo. Al cambiar de contenedor se cierran opciones de Flusso obsoletas
antes de iniciar una nueva transición.

### Contrato antes del builder y pulido posterior

Antes del builder sólo es necesario fijar e implementar la interfaz contractual:

- nombres y semántica de los estados visuales;
- quién inicia/cancela una transición y cómo se bloquea o enruta input;
- cuándo existe geometría final para asignar/restaurar foco;
- cómo los componentes reciben Theme, Motion y configuración declarativa;
- cómo un rebuild, cambio de contenedor, cambio de lado o cierre invalida un tween.

Puede quedar para después, sin obligar a editar los bloques:

- duración exacta, easing definitivo y curvas;
- microanimaciones, sombras, rebotes y efectos estéticos;
- elección final de cada transición visual, siempre que respete la interfaz, el
  ownership, la accesibilidad y los invariantes de layout/input.

## 27. Godot 4.7: `offset_transform_*` y Containers

Godot 4.7 expone para `Control` el transform de offset, incluidos habilitación,
posición, rotación, escala, pivote y la opción `offset_transform_visual_only`.
La documentación oficial de [`Control`](https://docs.godotengine.org/en/stable/classes/class_control.html)
establece que, con `offset_transform_enabled = true`,
`offset_transform_visual_only = true` aplica el transform sólo visualmente y no
afecta la recepción de input; con `false`, el transform completo también determina
dónde se registran los eventos. La documentación de [`Container`](https://docs.godotengine.org/en/stable/classes/class_container.html)
confirma que el Container organiza automáticamente a sus hijos. Estas fuentes se
complementan con `fluo_drawer.gd`, que hoy usa un `PanelContainer` fuera del
`VBoxContainer` de contenido, un `ScrollContainer` para el contenido y
`MOUSE_FILTER_STOP` en backdrop/panel.
La regla arquitectónica es separar:

- **layout lógico:** anchors, offsets, minimum size y Containers;
- **presentación:** transform visual temporal;
- **interacción:** rect lógico o un proxy de input explícitamente alineado.

Consecuencias:

1. Un Container sigue siendo dueño de la disposición de sus hijos. No se debe
   animar manualmente `position` o `size` de un hijo directo esperando que el
   Container lo respete después de un relayout.
2. Un `offset_transform` visual puede mover lo dibujado sin mover el rect lógico;
   con `visual_only = true`, los eventos siguen correspondiendo a la ubicación
   original. El foco es una relación de `Control` y no se debe inferir que una
   transformación visual lo reasigna; la prueba debe comprobar foco y recepción de
   eventos por separado. Esto es válido para decoración, no para un botón que el
   usuario deba tocar donde lo ve.
3. El panel interactivo del drawer debe animarse en un wrapper no gobernado por un
   Container, o usar una transformación/hitbox que se compruebe alineada. Durante
   movimiento se puede usar un escudo de input que consuma eventos.
4. El contenido interno debe seguir en Containers. El scroll se anima en el shell,
   nunca manipulando la posición de los hijos que `ScrollContainer` administra.
5. Un cambio de lado debe esperar a geometría estable o hacer una transición con
   input definido; no se debe cambiar anchor, foco y transform en órdenes que
   produzcan un frame con la selección en una coordenada distinta.

La aceptación técnica debe comprobar, en una prueba propia, `offset_transform_enabled`,
posición/escala, `offset_transform_visual_only`, `get_global_rect`, foco visible,
posición del evento, `mouse_filter` y recepción de mouse/touch. No se debe inferir
alineación sólo de una captura ni tratar `get_global_rect` como evidencia suficiente
del área de input transformada.

## 28. Foco, hitboxes, mouse filtering, touch y scroll

La matriz de interacción de Themes + Motion debe cubrir:

- abrir desde Inspector por Enter/doble click;
- abrir Flusso desde Flow por Enter/doble click/tap;
- foco del primer bloque o primer Add cuando la lista está vacía;
- cierre de Flusso y restauración al mismo bloque por ID;
- Escape jerárquico y clicks fuera del drawer;
- Up/Down, PageUp/PageDown, Ctrl+Page y Alt+Page según Preview 1;
- orientación portrait/landscape y panel largo con scroll;
- targets táctiles medidos en el dispositivo, no sólo en coordenadas de escritorio;
- drawer a izquierda y derecha;
- contenido no interactivo con `MOUSE_FILTER_IGNORE` y superficies interactivas
  consumiendo eventos donde corresponde;
- backdrop que no filtre clicks hacia controles del editor subyacente;
- ausencia de foco en controles desprendidos después de cada rebuild.

La revisión visual Android de carga/render existente no se reutiliza como evidencia
de touch, orientación, scroll o teclado. La catalogación actual mantiene esas
afirmaciones separadas.

## 29. Entregas reversibles propuestas

Cada entrega tendrá su propia especificación numerada, pruebas focales, revisión
manual cuando corresponda y commit separado. Una entrega que cambie comportamiento
público no se combinará con una refactorización de comportamiento preservado.

### D0 — Congelar contratos y evidencia

- **Objetivo:** aprobar este plan reconciliado y convertir en contratos numerados las
  decisiones ya cerradas: un bloque distribuible por paquete, Skill opcional,
  procedencia declarada separada de autenticidad y destino común de paquetes para
  bloques oficiales y de usuario.
- **Dependencias:** `constitution`, workflow, model contract, investigación SDK y
  Preview 1.
- **Archivos:** este documento; después, contratos separados aprobados.
- **Contrato:** no cambia código, manifiesto ni schema.
- **Pruebas:** validator del catálogo, `git diff --check`, revisión documental.
- **Manual:** revisión humana de alcance y de las preguntas realmente abiertas.
- **Riesgo:** empezar implementación con una convención sólo implícita.
- **Aceptación:** las decisiones cerradas aparecen como contratos y las abiertas no se
  presentan como comportamiento implementado.

### D1 — SDK manual, fixtures y perfil de paquete

- **Objetivo:** documentar y probar el perfil manual sobre manifest v1, script
  validator, catálogo y factory ya existentes, sin reconstruirlos ni conectar aún
  el editor real. Los sidecars permanecen como contratos separados del manifest v1.
- **Dependencias:** D0 y fundamento `FlowPackageManifest*` existente.
- **Archivos probables:** contrato SDK, fixtures bajo `tests/fixtures`, pruebas de
  manifest/validator/factory, sin tocar bloques integrados ni duplicar la
  infraestructura existente.
- **Contrato:** JSON canónico, rutas relativas, tipos A/B permitidos, diagnósticos,
  procedencia declarada separada y capability gate de la Skill.
- **Pruebas:** repetibilidad, orden, hermano inválido, traversal, instancia nueva,
  ID nuevo, ResourceSaver/PackedScene.
- **Manual:** crear una fixture a mano sin builder y comparar resultados.
- **Riesgo:** confundir fixture de prueba con paquete instalable del usuario.
- **Aceptación:** el SDK manual funciona sin red y produce la misma proyección que el
  pipeline automatizado.

### D2 — Contrato mínimo de Theme + Motion

- **Objetivo:** estabilizar antes del builder la interfaz visual y de interacción que
  heredarán todos los bloques, sin terminar todavía el pulido artístico.
- **Dependencias:** D0, Preview 1 y contratos actuales de foco/navegación.
- **Archivos probables:** componentes/adaptadores editor-only de Fluo, pruebas
  focales de layout, foco e input; no scripts de paquetes.
- **Contrato:** componentes reutilizables, roles de Theme, estados visuales, ownership
  de Motion, foco, input, touch, scroll, `mouse_filter`, cancelación/rebuild y regla
  de que un bloque nunca crea ni anima sus propios `Control` estándar.
- **Pruebas:** apertura/cierre sin regresión, foco restaurado, input durante
  transición, Containers y prueba focal de `offset_transform_*`.
- **Manual:** escritorio y una comprobación táctil focal suficiente para validar el
  contrato; la matriz Android completa queda para D8.
- **Riesgo:** acoplar bloques a una animación concreta o desalinear hitbox y visual.
- **Aceptación:** cambiar duración/easing/efecto futuro no obliga a editar ningún
  bloque ni su package contract.

### D3 — Catálogo externo en el Add row real — COMPLETADO

**Estado:** D3 COMPLETE; Phase A–E automatizado PASS; revisión manual desktop PASS; `$flujo-prove` PASS; el
paquete temporal de revisión fue retirado. La inspección visual no se usa como
evidencia de FlowId: identidad/persistencia provienen de las pruebas automatizadas.

- **Objetivo:** conectar catálogo/factory con la ruta actual de autoría y habilitar
  descubrimiento, alta, selección, movimiento y eliminación sin ramas por tipo.
- **Dependencias:** D1 y D2; preview Inspector → Fluo aceptado para la superficie que
  se toque.
- **Archivos probables:** `flow_ready_process_editor.gd`,
  `flow_graph_editor_commands.gd`, adaptador de catálogo y pruebas editor.
- **Contrato:** registry integrado preservado como compatibilidad durante la
  transición; externos ordenados y creados por factory; toda mutación por undo/redo.
- **Pruebas:** regresiones de Add, catalog/factory, creación, cancelación, Undo/Redo,
  persistencia y foco.
- **Manual:** Inspector → Fluo → Add → Flow con un paquete fixture válido.
- **Riesgo:** romper el Add row existente o duplicar la lista en Inspector.
- **Aceptación:** integrados conservan resultado previo y un externo válido entra por
  la misma superficie sin branch por tipo.

### D4-A — Contrato de propiedad/presentación genérica — COMPLETE

- **Objetivo:** congelar la frontera reutilizable de descripción de propiedades
  para Flusso y el futuro Debug Panel, sin implementar el renderer.
- **Dependencias:** D1, D2 y D3.
- **Contrato:** [FlowBlock Property Presentation Contract](flow_block_property_presentation_contract.md)
  define reflection como fuente de verdad, elegibilidad, el sidecar opcional
  `block_property_presentation.json`, tipos/hints v1, orden, ownership,
  Revertir, diagnóstico y reutilización segura en runtime.
- **Estado:** contrato documental completado; no production renderer, no Debug Panel,
  no bloque nuevo y no cambio de schema/manifest. D4-B implementa sólo la capa
  runtime/model descrita por este contrato.

### D4-B — Descriptores runtime-safe por metadata + reflexión — COMPLETE

- **Objetivo:** construir el descriptor reusable de propiedades de cualquier
  `FlowBlock` desde reflexión y el sidecar opcional, sin crear controles ni
  registrar ownership.
- **Dependencias:** D4-A, D1, D2 y D3.
- **Archivos:** `addons/vp_flujo/runtime/model/flow_block_property_*.gd` y
  `tests/model/flow_block_property_descriptor_test.tscn`.
- **Contrato:** el script/modelo es fuente de tipo, valor y persistencia; metadata
  sólo refina presentación segura; tipos/hints no soportados, propiedades inelegibles
  y declaraciones desconocidas producen diagnósticos deterministas; la ruta no usa
  APIs de editor ni ramas por paquete o bloque concreto.
- **Pruebas:** bool, int, float, String, StringName, range, enum, multilinea,
  orden determinista, metadata válida/inválida, elegibilidad, tipos no soportados,
  no mutación, independencia de contenedor, ruta package-relative y auditoría
  estática de frontera runtime.
- **Manual:** no aplica revisión visual: D4-B no añade UI ni cambia la superficie
  Inspector/Fluo.
- **Riesgo:** reflection que exponga internals, drift metadata–script o una carga
  de sidecar que acceda a rutas absolutas; se mitiga con filtro fail-closed,
  validación y fallback reflection-only.
- **Aceptación:** un bloque configurable nuevo obtiene descriptores equivalentes sin
  añadir una rama concreta a Flusso, y la capa puede reutilizarse sin APIs de editor.

### D4-C — Renderer genérico de Flusso sobre los descriptores — COMPLETE — MANUAL PASS

- **Objetivo:** renderizar y editar los descriptores D4-B mediante controles comunes,
  aplicando ownership, snapshot/Revertir y el límite editor/runtime de D4-A.
- **Dependencias:** D4-B, D1, D2 y D3.
- **Archivos:** `flow_editor_block_authoring_context.gd`,
  `flow_ready_process_editor.gd`, `flow_graph_editor_commands.gd`,
  `flow_graph_inspector_property.gd` y sus focales editor.
- **Contrato:** sólo controles realmente renderizados registran ownership; los
  campos desconocidos, read-only o no soportados no se editan; no hay widgets
  arbitrarios ni ramas por paquete o tipo concreto.
- **Implementación:** el contexto delega la descripción a
  `FlowBlockPropertyCatalog`; el renderer consume `presentation_kind`, presenta
  diagnósticos y excluye controles explícitos activos para evitar duplicados. Los
  edits usan `set_ready_property_descriptor_live()` y el snapshot/Revertir de
  Flusso conserva sólo el conjunto owned de la sesión.
- **Pruebas:** `FLUJO-BHV-FLUO-GENERIC-PROPERTY-001` cubre live edit,
  snapshot/Revertir, ownership, bool/int/float/String/StringName, range, enum,
  multilinea, labels, order, groups, tooltips, diagnostics, built-in collision
  protection y equivalencia Process/Timer. Persistencia/runtime, Process/Timer,
  Fluo integration, descriptor D4-B y editor-load regressions pasan.
- **Manual:** `D4-C COMPLETE — MANUAL FLUSSO REVIEW PASS` en `Godot 4.7.2
  stable Flathub`, con aprobación humana `🙆‍♀️`. Process PASS, Timer PASS,
  generic property controls PASS, live editing PASS, Revertir PASS, multiple
  instances PASS, no duplicate built-ins PASS y container independence PASS.
  También pasaron labels, grupos, orden determinista, scroll, navegación,
  selección, close/reopen y la equivalencia de configuración Process/Timer.
- **Diagnósticos:** el único diagnóstico de engine observado fue el conocido
  `dragger_index = 2 is out of bounds`; `unsupported_property_type` es el
  diagnóstico intencional del fixture y del conjunto escalar D4 v1, no un fallo
  de aceptación.
- **Riesgo:** exponer internals, perder foco durante rebuild o confundir el
  descriptor runtime con autorización de edición; mitigado por filtro fail-closed,
  ownership posterior a la creación y el comando validado.
- **Aceptación:** un bloque configurable nuevo no añade una rama concreta a
  Flusso, sus controles respetan el ownership por sesión y la revisión visual
  manual fue aprobada. D4 está completo en D4-C; no existe una entrega D4-D
  aprobada ni una tarea D4-D que iniciar.

### D5 — `flujo-block-builder v1` funcional, mínimo y reproducible — FUTURO

- **Estado en este checkpoint:** la Skill inicial de planificación existe y fue
  validada; D5 funcional no está completo y no se ha generado ningún bloque.
- **Objetivo:** generar un paquete estándar revisable que use exactamente los
  contratos manuales ya funcionales de D1–D4, sin crear capacidades exclusivas.
- **Dependencias:** D1, D2, D3 y D4.
- **Archivos probables:** `tools/agent_skills/flujo-block-builder/`, referencias o
  plantillas necesarias y pruebas deterministas de salida. La ubicación final se
  ajustará a las convenciones vigentes de Skills del repositorio.
- **Contrato:** D5 significa Builder funcional, no sólo la Skill. La Skill no
  genera IDs persistentes de instancias, no usa rutas absolutas, no parchea
  silenciosamente el núcleo y clasifica cada solicitud como soportada, limitada,
  extensión SDK requerida o core-only. Official Mercury y user/community usan el
  mismo SDK público.
- **Pruebas:** dos ejecuciones limpias producen contenido semánticamente equivalente;
  salida inválida se rechaza; el mismo paquete creado manualmente pasa las mismas
  validaciones.
- **Manual:** inspección de archivos generados y recreación manual equivalente.
- **Riesgo:** convertir una herramienta de conveniencia en fuente de verdad.
- **Aceptación:** eliminar la Skill no impide crear, cargar, editar ni mantener el
  paquete manualmente; la salida pasa el flujo Inspector → Fluo → Flow → Flusso →
  persistencia → runtime y cumple la matriz A–E de la sección 10. FPrint queda
  como el primer dogfood futuro con especificación aún no congelada.

### D6 — Primer bloque externo estándar de clase A

- **Objetivo:** probar el vertical slice real con un bloque simple derivado de
  `FlowOutputBlock`, sin IF, creado primero mediante `flujo-block-builder v1` y
  reproducible a mano.
- **Dependencias:** D5; por transitividad D1–D4.
- **Archivos:** un paquete real de dogfooding bajo `res://flow_packages/<package_id>/`,
  sus pruebas model/runtime/editor y documentación del ejemplo.
- **Contrato:** un paquete = un bloque; salida determinista, sin navegación ni Node;
  procedencia declarada según el contrato aprobado.
- **Pruebas:** manifest, validator, catalog, factory, Add de Flow, configuración de
  Flusso, IDs, duplicación, ResourceSaver, PackedScene y runtime.
- **Manual:** crear/agregar/configurar/ejecutar/eliminar el paquete y comparar con la
  creación manual equivalente.
- **Riesgo:** que el ejemplo esconda un acoplamiento que otros paquetes no tienen.
- **Aceptación:** el bloque recorre Inspector → Fluo → Flow → Flusso → persistencia →
  runtime sin ninguna rama específica en el núcleo.

### D7 — Ciclo de vida: procedencia persistente, ausencia, eliminación, restauración y promoción

- **Objetivo:** cerrar el ciclo de vida de paquetes sin borrar datos de usuario.
- **Dependencias:** D1–D6 y decisión explícita de la sección 22 sobre origen/placeholder.
- **Archivos probables:** contrato de origen, modelo/loader de placeholder si se
  aprueba, manager editor-only y pruebas de persistencia/migración.
- **Contrato:** eliminación individual, respaldo, diagnóstico, restauración explícita
  y promoción de incubadora a oficial sin reescribir comportamiento; cualquier
  schema nuevo requiere migración atómica.
- **Pruebas:** paquete removido/restaurado, IDs/orden/null, escena guardada,
  incompatibilidad, paquete hermano intacto y undo donde aplique.
- **Manual:** retirar una carpeta y restaurar sólo ese paquete, sin red.
- **Riesgo:** pérdida de recursos o falsa confianza en procedencia declarada.
- **Aceptación:** ninguna acción sobre un paquete toca contenido no relacionado y una
  incompatibilidad preserva datos/diagnóstico según el contrato aprobado.

### D8 — Theme + Motion polish y aceptación final de Fluo Preview

- **Objetivo:** completar el pulido visual sobre el contrato D2 sin cambiar el
  contrato de los bloques.
- **Dependencias:** D2–D4, matriz Android de Preview 1 y revisión de UI.
- **Archivos probables:** `fluo_drawer.gd`, adaptador Theme, controlador Motion
  editor-only y pruebas de layout/foco/input.
- **Contrato:** Containers gobiernan layout; transform sólo presentación con
  hitbox/input comprobado; estados de movimiento no persisten.
- **Pruebas:** focales Fluo, layout/scroll, eventos lógicos, cierre/reopen, side
  placement, reduced motion y regresiones integradas.
- **Manual:** escritorio, portrait/landscape Android, targets, doble tap, scroll,
  teclado, foco, side switch, reduced motion y Theme.
- **Riesgo:** desalinear visual, foco y click mediante `visual_only`.
- **Aceptación:** el pulido puede cambiar sin tocar los paquetes; evidencia visual y
  de interacción queda separada de la automatización headless.

### D9 — Migración gradual de bloques oficiales a paquetes Mercury

- **Objetivo:** converger hacia un único ecosistema distribuible donde los bloques
  oficiales y los del usuario compartan la misma raíz y el mismo contrato, un paquete
  independiente por bloque.
- **Dependencias:** D6 y D7; D8 cuando la migración afecte superficies visuales.
- **Archivos probables:** paquetes `mercury.<bloque>/`, compatibilidad/migraciones
  explícitas y pruebas de proyectos existentes.
- **Contrato:** migración uno por uno; nunca mover/borrar scripts integrados de forma
  que rompa escenas guardadas; conservar shims o migración explícita mientras existan
  referencias históricas. `FlowBlockRegistry` deja de ser el hogar final de bloques
  distribuibles y queda sólo como compatibilidad o infraestructura interna necesaria.
- **Pruebas:** proyecto antiguo, carga/guardado, upgrade, ausencia de paquete,
  restauración oficial, eliminación independiente y hermanos intactos.
- **Manual:** instalar/eliminar/restaurar un bloque oficial sin afectar a los demás.
- **Riesgo:** romper rutas de script persistidas en proyectos anteriores.
- **Aceptación:** al menos un bloque oficial puede vivir como paquete Mercury sin
  romper compatibilidad; la migración de los siguientes no exige rediseñar el SDK.

## 30. Criterios globales, riesgos, decisiones humanas y cierre

### Criterios de aceptación globales

- El manifiesto v1 no recibe campos nuevos accidentalmente.
- Los bloques integrados actuales conservan registry, nombres, orden, editor,
  runtime, persistencia y pruebas durante la transición; su migración futura a
  paquetes Mercury es explícita, gradual y compatible.
- El primer externo usa contratos genéricos y no añade una rama `if` al executor o
  a Flusso.
- La Skill es opcional: el paquete resultante puede crearse y mantenerse a mano con
  GDScript, JSON y los contratos públicos.
- Los IDs, schemas, escenas, orden y `null` positions se conservan.
- El runtime no importa editor, red, filesystem absoluto ni herramientas del host.
- La procedencia se muestra como declaración, nunca como autenticidad.
- La ausencia/remoción/restauración tiene diagnóstico y respaldo explícitos.
- Inspector sigue siendo el punto de entrada; no aparece una lista duplicada de
  Blocks.
- Flow consume un catálogo genérico para descubrir, añadir, seleccionar, mover,
  eliminar y representar procedencia, sin ramas por tipo concreto.
- Motion no desincroniza Container, foco, hitbox, mouse filter, touch ni scroll.
- La aceptación manual Android se separa de la automatización headless.

### Riesgos principales y mitigación

| Riesgo | Mitigación |
| --- | --- |
| pérdida de datos por script ausente | decidir origen/placeholder antes de removal; respaldar y no reparar silenciosamente |
| drift metadata–script | reflection validatoria y diagnóstico de campos desconocidos |
| colisión de nombres | namespace `package_id:type_id`; no `class_name` global por defecto |
| paquete malicioso o no portable | no ejecutar en discovery, APIs permitidas, sin red ni editor en runtime |
| regresión de Preview 1 | D2/D3/D8 con aceptación focal; conservar catálogo y pruebas actuales |
| hitbox desplazado por Motion | wrapper/input proxy, `visual_only` limitado y revisión de rect/eventos |
| falsa garantía de procedencia | lenguaje “declarada”, sin checksum/firma criptográfica ni etiqueta “verificada” |

### Decisiones que requieren autoridad humana

1. elegir el `package_id`, `type_id`, nombre y mensaje del primer bloque externo;
2. elegir la representación persistente para recuperar un bloque cuando su paquete
   desaparece: origen en bloque, mapa lateral, placeholder o combinación;
3. aprobar el formato final de `provenance.json` —incluida la separación
   `author_*` / `publisher_*`— manteniendo su semántica declarada no criptográfica;
4. la revisión visual de D4-C sobre el contrato `block_property_presentation.json`
   quedó completada; localización futura y límites adicionales de los controles
   siguen fuera de esta aprobación, sin reabrir la fuente de verdad del modelo;
5. fijar umbrales de touch, targets, reduced motion y dispositivos Android de la
   aceptación;
6. definir la API de promoción del incubador a biblioteca oficial y el mecanismo
   concreto de migración de bloques oficiales actuales a paquetes Mercury sin
   romper proyectos históricos;
7. autorizar cualquier schema nuevo o eliminación del legacy dock/POC.

No requieren una nueva aprobación de principio: un bloque distribuible = un paquete;
la Skill es opcional/manual; los bloques oficiales y de usuario convergen al mismo
estándar de paquetes; la procedencia declarada se mantiene separada de autenticidad
criptográfica; Theme/Motion pertenecen al host; IF queda fuera hasta su ciclo propio.
El diseño final del IF seguirá `ESPECIFICACIÓN → PLAN → 🙆🏻 → IMPLEMENTACIÓN →
PRUEBAS`.

### Justificación y evidencia de esta entrega

- **Qué cambió:** se implementó D4-B en `addons/vp_flujo/runtime/model/` con
  reflexión fail-closed, carga/validación del sidecar opcional y descriptores
  deterministas; se añadió su focal, entrada de catálogo y trazabilidad. No se
   cambian schemas, manifest v1, bloques, ni `demo/main.tscn`; D4-C añade sólo
   la adaptación editor-side de controles genéricos.
- **Por qué:** Flusso necesita una proyección reusable antes de añadir controles;
  separar esta capa evita que metadata, editor o un paquete concreto se conviertan
  en fuente de verdad o dependencia runtime.
- **Alternativas rechazadas:** metadata como schema autónomo, widgets/scripts de
  paquetes y reflexión dependiente de APIs de editor; todos permitirían drift,
  ejecución arbitraria o pérdida de reutilización en runtime.
- **Invariantes protegidos:** IDs, orden, `null`, schemas 1–5, separación
  editor/runtime, persistencia del modelo, ownership explícito, compatibilidad
  temporal del registry y ruta Inspector → Fluo.
- **Limitaciones:** valores complejos, runtime debug write-back, localización y la
  matriz Android siguen fuera de D4-C; los controles, foco, scroll, Theme y
  etiquetas/tooltips de D4-C quedaron aprobados por la revisión manual registrada.
- **Evidencia ejecutada:** Godot 4.7.2; validator de catálogo y focal D4-B PASS;
  model smoke, perfil SDK manual, loader/descriptor/validator/factory/hooks/catalog
  externos, runtime custom/navigation/Ready, Add externo, persistencia/runtime,
  authoring Process/Timer, ownership/Revertir, Process/Timer editor y carga del
  editor PASS. Los diagnósticos negativos de fixtures y teardown se reportan
  separadamente y no cambiaron los marcadores de éxito.
- **Evidencia manual:** la revisión D4-C aprobó Process, Timer, generic property
  controls, live editing, Revertir, multiple instances, no duplicate built-ins y
  container independence. La aceptación visual Android sigue pendiente según su
  contrato.

### Métricas de flujo

| Campo | Evidencia |
| --- | --- |
| Requisito / tarea | `D4A-PROP-001`–`D4A-PROP-010` / descriptores runtime-safe D4-B |
| Inicio / finalización | no medido / no medido |
| Commit validado / tiempo de revisión | no existe todavía / no medido |
| Tamaño del cambio | no medido |
| Tests | validator, focal D4-B y regresiones proporcionales ejecutados; todos los marcadores PASS |
| Primera validación / correcciones | focal D4-B y validator pasaron / no medido |
| Hallazgos / regresiones posteriores | diagnósticos de fixture/teardown conocidos / no medido |
| Revisión visual | D4-B no aplicable; D4-C manual PASS; D8 mantiene su revisión |
| Intervenciones / bloqueos | ninguna; no hay bloqueo de ejecución |
| Herramienta/modelo IA | sistema reportado por la sesión; no es dependencia del proyecto |
| Créditos voluntarios | no medido |

`D4-C COMPLETE — MANUAL FLUSSO REVIEW PASS`. La implementación del renderer
genérico de Flusso sobre los descriptores D4-B pasó la revisión manual de controles,
ownership y Revertir. D4 queda cerrado en D4-C; el antiguo `D4-D NEXT` no tiene
alcance canónico ni matriz A–E y no se inicia. D5 funcional permanece futuro, no se
genera FPrint y este checkpoint no cambia schemas, `FlowBlockRegistry` ni las
superficies heredadas de `Print`, `Custom Hello`, `Everything Flows` o `Add Call
Method`.

Todo es Flujo; todo fluye. 🌊
