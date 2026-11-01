# Receta reusable — Bloques compatibles con arrastrar y soltar nodos de Godot

**Flujo | propuesta de contrato DRAG-BLOCK-001 | 2026-11-01**  
**Estado:** especificación y receta para `flujo-block-builder`; **no es una implementación funcional ni un contrato SDK aprobado**.  
**Rama de integración prevista:** `feature/fsm-runtime-flow-flusso` (fase UI-FSM 7, antes de construir el autor visual completo).  
**Origen técnico:** `tools/agent_skills/flujo-block-builder/SKILL.md`, `docs/manual_block_sdk_contract.md`, `FlowSceneNodePanel`, `FlowSceneNodeTree`, `FlowEditorBlockAuthoringContext` y `FlowGraphEditorCommands`.

## 1. Objetivo y alcance

Permitir arrastrar un nodo del árbol de la escena, soltarlo en una posición concreta de **Flow** y crear un bloque instalado y compatible, rellenando sus entradas de referencia al nodo mediante chips. La misma infraestructura sirve para **Process, Timer, State Machine** (fases Enter/Update/Exit), Method, Constructor y otros contenedores que admiten `FlowBlock`; no crear un tipo especial por contenedor. El motor FSM decide cuándo ejecuta las fases, y el bloque no conoce ni necesita conocer el contenedor.

**Distinción importante:** el código existente ya produce el payload `flujo_scene_node` y admite soltarlo como `NodeRef/NodePropertyRef` en los chips. **No** existe todavía una asociación declarativa universal `clase de nodo → bloque` ni la creación automática sobre una fila de Flow. Esta receta define cómo construirla sin fingir que ya está operativa.

```text
Árbol de escena (FlowSceneNodeTree)
     └─ payload ya existente: tipo, NodePath, nombre, clase, requirement_id
          ↓
FlowSceneNodePanel — arrastre/clic/teclado
          ↓
Drop resolver genérico (futuro SDK compartido)
     ├─ verifica escena, controlador, destino, fase y tipo de nodo
     ├─ consulta catálogo de bloques existentes + declaraciones de compatibilidad
     ├─ determina 0, 1 o varios candidatos compatibles
     └─ solicita confirmación de selección cuando hace falta
          ↓
FlowEditorBlockAuthoringContext.create_block(authoring_id)
          ↓
Binding adapter genérico → chips NodeRef/NodePropertyRef
          ↓
Validación del candidato completo
          ↓
Un único comando Undo/Redo (insertar en posición + enlazar chips)
          ↓
Flow muestra el bloque → Flusso presenta propiedades editables
```

## 2. Principios obligatorios

1. **Reutilización por contrato.** El bloque sigue siendo un `FlowBlock` agnóstico de contenedor. La lógica Drop no debe duplicarse para Process/Timer/State Machine.
2. **Un paquete por bloque.** `res://flow_packages/<package_id>/manifest.json` más `block.gd`; identificador de autoría `package_id:type_id`. El `manifest_version = 1` contiene solo sus campos existentes; **no añadir** `node_classes`, `drop_targets` ni propiedades nuevas al manifiesto sin aprobación.
3. **Skill optativo, autoría manual equivalente.** Cualquier bloque generado por `flujo-block-builder` puede escribirse con GDScript/JSON normales, y debe funcionar sin el skill instalado.
4. **Catálogo/fábrica únicos.** Reutilizar `FlowPackageManifestLoader`, `FlowExternalBlockScriptValidator`, `FlowEditorBlockCatalog`, `FlowExternalBlockFactory` y `FlowEditorBlockAuthoringContext`. Nunca crear una fábrica o registro alternativo en el panel.
5. **Identidades separadas.** `authoring_id` identifica la clase instalable, `FlowId` identifica la instancia del bloque, y `requirement_id`/ruta de escena identifican o localizan el nodo. Nunca usar nombre visible o índice como identidad persistente.
6. **Borrador atómico.** El drag crea y vincula un bloque fuera del grafo; si falla cualquier paso, no añade nada, no deja chips huérfanos y no registra Undo.
7. **Seguridad.** Un payload de arrastre no es una autoridad; resolver el nodo real y verificar que pertenece a la escena/controlador admitidos. No instanciar scripts arbitrarios derivados de texto.
8. **Una interfaz.** El host Fluo gestiona Theme, Motion, foco, teclado, Cancel/Revertir, scroll, Undo/Redo, confirmaciones y Android. Los bloques no insertan interfaces ad hoc.
9. **Paridad funcional.** Arrastrar y soltar, activación por teclado y selector manual de bloques deben producir el mismo `FlowBlock` persistente y validado.
10. **Cobertura incremental.** No afirmar que todos los nodos y sus métodos se pueden mapear hasta construir un catálogo de capacidades probado. Se puede admitir cualquier clase de Godot con una o varias recetas declaradas, sin inventar comportamiento para clases desconocidas.

## 3. Contrato propuesto de compatibilidad (EXTENSIÓN C: aún no aprobado)

El manifiesto v1 permanece intacto. La propuesta es un **descriptor declarativo adicional y opcional**, leído únicamente por el adaptador de arrastre; si no existe, el bloque sigue siendo perfectamente válido para el flujo manual Add. La forma/ubicación definitiva del descriptor deberá decidirse en la puerta de aprobación del SDK (por ejemplo, un sidecar aprobado, o un registro de metadatos compuesto con el catálogo). **No implementar silenciosamente este formato como contrato vigente.**

### Esquema conceptual (pseudodatos; NO archivo compatible hoy)

```yaml
binding_version: 1
authoring_id: "mercury.node_2d_set_position:set_position"
godot_classes: ["Node2D"]   # clases base y herencia real
placement:
  phase_agnostic: true
  allowed_containers: ["FlowBlockContainer"]
bind:
  chip_slot: "target_node"
  source_kind: "NodeRef"
  expected_node_type: "Node2D"
  payload_field: "node_path"
selection:
  priority: 10
  visible_label: "Modificar posición (Node2D)"
```

**Campos que deberán congelarse antes de implementarse:** versión y validación del descriptor, tipos de nodo compatibles por herencia (`ClassDB.is_parent_class` o lógica equivalente que incluya scripts de usuario), `authoring_id`, requisitos por escena, ubicación del chip destino y tipo esperado, prioridad determinista, soporte `NodePropertyRef`, elección entre múltiples bloques, y compatibilidad de fase por capacidades declaradas en vez de listas de clases duplicadas.

**No corresponde serializar este descriptor ni la vista del panel dentro de `FlowGraph`.** Solo se serializa el bloque que resulte y sus fuentes de valor/chips, de acuerdo con su contrato de persistencia aprobado.

## 4. Receta de creación para cada bloque personalizado

### Paso A. Elegir un comportamiento específico de Godot

Definir **una acción concreta** (por ejemplo, escribir `Node2D.position`, activar `CanvasItem.visible`, reproducir un `AnimationPlayer`, arrancar un `Timer` de la escena). No crear un bloque `Node` universal que exponga cualquier método arbitrario. Comprobar clase base, herencia, disponibilidad de métodos, argumentos, efecto colateral y contexto de ejecución. Una acción puede ser transversal a decenas de clases gracias a la herencia.

**Ficha mínima por bloque:**

| Campo | Contenido esperado |
|---|---|
| Nombre visible | Verbo + objeto/resultado, sin ambigüedad |
| Paquete | ID estable `mercury.<accion>` |
| Tipo de bloque | `type_id` estable, un bloque por paquete |
| Nodo compatible | Clase nativa de referencia y subtipos permitidos |
| Operación | Método o propiedad Godot y semántica exacta |
| Entradas | Referencia `NodeRef`, parámetros tipados, valores predeterminados |
| Chips | Campo/slot receptor, tipo y restricción `FIXED/FLEXIBLE/HYBRID` cuando esté admitido |
| Salida | Resultado, señal, navegación o efecto |
| Fallos | Nodo borrado, ruta inválida, clase incompatible, argumentos faltantes |
| Contextos | Todo contenedor que ejecute `FlowBlock`; únicamente excepciones justificadas |
| Persistencia | ID, fuentes de valor, copia, guardado/carga y migración si procede |

### Paso B. Ejecutar la puerta del skill

Invocar `flujo-block-builder` para **planificar**, no producir automáticamente el paquete:

1. Recuperar normas del skill, contrato público SDK y estado del catálogo.
2. Clasificar capacidades: **A**, realizable con SDK actual; **B**, requiere configuración compatible con D4; **C**, requiere ampliar API pública reusable, como los nuevos metadatos de Drop; **D**, requiere nueva semántica del núcleo.
3. Entregar especificación de comportamiento + contrato de entradas/chips + plan de implementación + plan de comprobaciones.
4. **Detenerse para autorización explícita del mantenedor antes de generar un bloque**, incluso cuando parezca simple. Para una capacidad C/D, proponer primero la extensión mínima y detenerse también.

### Paso C. Crear el paquete estándar

Una vez autorizado y si no queda un bloqueo C/D:

```text
res://flow_packages/mercury.<accion>/
├── manifest.json
├── block.gd
└── block_property_presentation.json    # opcional D4, solamente presentación
```

Ejemplo **únicamente de manifiesto v1 válido**:

```json
{
  "manifest_version": 1,
  "package_id": "mercury.node2d_action",
  "blocks": [
    {
      "type_id": "node2d_action",
      "script": "block.gd",
      "display_name": "Acción Node2D"
    }
  ]
}
```

El script `block.gd` usa `@tool`, hereda de `FlowBlock` o `FlowOutputBlock`, permanece sin `class_name` global salvo nuevo contrato, se valida y ejecuta mediante las interfaces públicas del SDK; **no** invoca `EditorInterface`, `FlowSceneNodePanel` ni `EditorUndoRedoManager`. Su método exacto de resolución y su escritura del nodo dependen de las capacidades públicas que queden aprobadas, no de un ejemplo improvisado.

### Paso D. Declarar el punto de conexión de Drop

Con el contrato C aprobado, publicar un descriptor de compatibilidad para el bloque que incluya clases compatibles y un binding explícito al **slot/chip receptor**. La preferencia es **referencia por identidad estable de requerimiento** cuando exista, más `NodePath` local según el contrato de `NodeRef`. Nunca guardar referencias vivas a `Node` o `SceneTree` dentro del recurso de bloque.

Resolver la **clase efectiva del nodo** mediante el árbol real de la escena. Un nodo puede coincidir con varias acciones instaladas: no seleccionar la primera por azar. Ordenar por especificidad de clase, prioridad declarada y `authoring_id`; si hay más de una opción válida de usuario, abrir selector. Si no hay opción compatible, ofrecer inserción de chip `NodeRef` en un campo compatible o cancelar sin mutación.

### Paso E. Resolver el contenedor y la posición

El **destino** proporciona: `controller`, `container_id`, `phase`, `insertion_index`, y si corresponde, `machine_id`/`state_id`. Solo hay un adaptador de inserción para todas las fases:

- Process/Timer/Method/Constructor: lista de bloques del `FlowBlockContainer` existente.
- State Machine: `FlowStateDefinition.enter_blocks`, `blocks` (Update) o `exit_blocks`, según la fase de destino.
- Ningún target acepta un `block` si la colección, fase o definición no es válida.
- El índice es el punto concreto donde se soltó; no se agrega silenciosamente al final.
- La selección/foco y los límites del contenedor pertenecen al host.

### Paso F. Instanciar, vincular y validar atómicamente

1. Validar origen (payload real, escena, nodo vigente y clase).
2. Resolver el descriptor contra el catálogo **instalado y validado**.
3. Instanciar mediante `FlowEditorBlockAuthoringContext.create_block(authoring_id)`.
4. Asignar la referencia del nodo al slot/chip del bloque usando el servicio compartido de binding, **sin modificar su formato de chips en el panel**.
5. Verificar tipos y obligatoriedad de entradas; si quedan argumentos opcionales sin resolver, dejar el bloque configurado como borrador válido o mostrar configuración antes de confirmar, conforme a la política del bloque.
6. Validar el bloque y el nuevo grafo candidato; revisar ausencia de ID duplicado, referencias rotas y compatibilidad del destino.
7. Confirmar una sola acción de `EditorUndoRedoManager` con creación + binding + inserción; una sola acción Undo la deshace por completo.
8. Enfocar el nuevo bloque en Flow y, si necesita parámetros adicionales, abrir Flusso sin perder foco de teclado.

### Paso G. Pruebas antes de aprobar la receta para una familia de nodos

| Prueba | Resultado esperado |
|---|---|
| Nodo compatible → Process | Bloque creado y chip referenciado, posición exacta |
| Mismo nodo → Timer | Misma clase de bloque y mismo contrato |
| Mismo nodo → FSM Enter/Update/Exit | Mismo bloque, ejecución vinculada a la fase |
| Dos arrastres iguales | Dos bloques con nuevos IDs, sin duplicar el nodo |
| Múltiples candidatos | Selector determinista; cancelar no modifica |
| Ningún candidato | Fallback de referencia/cancelación, sin bloque espurio |
| Nodo borrado o movido | Validación y diagnóstico explícitos |
| Datos de arrastre malformados | Rechazo limpio, sin scripts arbitrarios |
| Undo/Redo, Revertir | Cambio atómico y restauración correcta |
| Duplicación y ResourceSaver/PackedScene | Persistencia de script, IDs y fuentes de valor |
| Flow/Flusso | Selección, foco, Escape, teclado y scroll intactos |
| Android | Arrastre táctil, orientación, soltar, cancelar y panel lateral revisados |
| Pruebas de regresión | Ready, Timer, navegación, FSM-001/002/003/004 intactos |

La clasificación de cada comprobación será **PASS / FAIL / NOT RUN**; Godot headless no sustituye comprobaciones visuales humanas.

## 5. Estrategia para abarcar todos los nodos de Godot

No generar cientos de scripts a ciegas. Construir la biblioteca **por capacidades heredables**:

1. **Node:** nombre, grupo, jerarquía y señales comunes, si están admitidos por el SDK.
2. **CanvasItem:** visibilidad y propiedades visuales compartidas.
3. **Node2D:** posición, rotación, escala, transformación.
4. **Control:** presentación/interacción con las restricciones propias de UI.
5. **Node3D:** posición/rotación/escala 3D.
6. **AnimationPlayer / AnimatedSprite2D / AudioStreamPlayer / Timer / Camera2D / Camera3D / CharacterBody2D / CharacterBody3D**, etc., por acciones específicas y contratos verificados.
7. **Clases de usuario y plugins:** compatibilidad por herencia/contrato explícito, sin confiar en cadenas de clase no verificadas.

**Objetivo medible:** cobertura declarativa de tipos de nodo y de acciones soportadas, no afirmar soporte universal hasta tener pruebas. Una clase nueva puede heredar automáticamente bindings de una clase base sin crear otro bloque.

## 6. Orden de implementación propuesto

| Entrega | Objetivo | Dependencia |
|---|---|---|
| DNB-0 | Congelar descriptor, mapping `NodeRef`/chips, criterios y métricas de cobertura | Aprobación de extensión C del SDK |
| DNB-1 | Resolver genérico `Node class → catalog authoring_id` sin mutación | Catálogo y factory existentes |
| DNB-2 | Adaptador de Drop a contenedores y fases FSM con inserción atómica | Comandos Undo/Redo |
| DNB-3 | Servicio de binding a slots/chips y validación de referencias de escena | Modelo de chips + NodeRef |
| DNB-4 | Selector para 0/1/N coincidencias, teclado, cancelación y foco | Fluo host |
| DNB-5 | Primer bloque real «dogfood», **elegido tras la planificación del skill**, probado en Process/Timer/FSM | Aprobación por bloque |
| DNB-6 | Catálogo progresivo de familias Node/CanvasItem/Node2D/... | Matriz por familia |
| DNB-7 | Pruebas automatizadas y revisión visual agrupada Fedora/Android | DNB-1–6 |

**Ubicación:** introducir DNB-0 a DNB-5 **al inicio de la fase UI-FSM (fase 7)**; luego concluir el editor FSM reutilizando el mismo Drop en Process/Timer. El catálogo de familias DNB-6 puede crecer iterativamente después sin modificar el motor FSM.

## 7. Plantilla de solicitud al skill (copiable)

> **Skill:** `flujo-block-builder`. Quiero especificar un único bloque externo portable para la acción **[acción]** sobre nodos Godot de clase base **[clase]** y sus subclases verificadas. Debe funcionar igual en Process, Timer y FSM Enter/Update/Exit; vinculará el nodo arrastrado a **[slot/chip]** mediante la fuente NodeRef vigente; usará el catálogo/fábrica estándar y el descriptor de Drop aprobado, sin ampliar `manifest_version = 1` ni añadir ramas específicas por paquete al core. Recupera contratos actuales, clasifica A/B/C/D, detalla campos, ejecución, errores, serialización, Undo/Redo, pruebas headless y pruebas Fedora/Android. **Entrega primero especificación, plan y matriz de validación; no crees código hasta aprobación explícita.**

## 8. Aprendizajes para la evolución del skill

- La experiencia drag-and-drop es un **adaptador de autoría**, no una nueva familia de bloques.
- El origen (nodo), resolución (catálogo), destino (contenedor/fase), binding (chip), comando (Undo/Redo) y ejecución (runtime) son seis fronteras independientes que deben probarse por separado.
- **No modificar manifiesto v1 ni SDK público para rellenar silenciosamente una funcionalidad faltante**. Resolver el descriptor de compatibilidad como ampliación C con puerta de aprobación.
- Usar una **acción por paquete** y reutilización por clase base/herencia para escalar el soporte a nodos de Godot.
- La compatibilidad con contenedores es la regla general; las restricciones deben estar justificadas por capacidades, no por nombres o casos especiales.
- Registrar por bloque: clases compatibles, slots, fixtures, pruebas, cobertura confirmada, inconvenientes y mejoras del skill.

**Siguiente iteración prevista:** aprobar y prototipar DNB-0/DNB-1 sin implementar todavía una familia completa de bloques; incorporar esta receta al skill después de validar el contrato y el primer dogfood.

Todo es Flujo; todo fluye. 🌊
