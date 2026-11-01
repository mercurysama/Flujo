# Flujo — Lote 10: integración final Akis/Tok

## Estado

**Implementado en la rama de trabajo; verificación formal en Godot 4.7.2 pendiente.**

Lote 10 cierra el impulso de integración de Toks/Akis iniciado en los lotes
anteriores. No introduce un nuevo sistema de valores ni un nuevo tipo de acción:
conecta, prueba y endurece los contratos ya existentes.

El gate humano y los focales de Godot permanecen separados de la inspección de
código. La existencia de los tests no se registra como PASS hasta ejecutarlos.

## Alcance aprobado

### L10-001 — Remapeo completo de referencias del grafo

Al duplicar un `FlowGraph`, los ValueSources anidados deben remapear toda
identidad que pertenezca al grafo duplicado:

- `FlowVariableRefValueSource.variable_id`;
- `FlowNodeRefValueSource.requirement_id`;
- `FlowNodePropertyRefValueSource.requirement_id`.

El remapeo recorre Array, Dictionary, Expression legado, Operation y Condition.

El remapeo ocurre sólo después de que el mapa old-ID → new-ID contiene también
los Requirements, Methods, containers y demás identidades duplicadas.

### L10-002 — Akis de bloques también participa en el remapeo

Todo `FlowStructuredDocument` persistido como propiedad de un bloque se
duplica independientemente y sus ValueSources reciben el mismo remapeo de
identidades del grafo.

Una copia no puede conservar accidentalmente un VariableRef o RequirementRef
que apunte al grafo original.

### L10-003 — Runtime Schema 4 para Process/Ready

`FlowReadyExecutor` admite Schema 3 y Schema 4 para las entradas ejecutables
existentes.

Schema 4 reutiliza el mismo executor, navegación, output y
`FlowValueResolutionContext`; no obtiene un executor paralelo.

Antes de ejecutar Schema 4, el mapa
`PVController.requirement_bindings` se valida estructuralmente. Un binding con
error detiene esa ejecución en lugar de ocultar el defecto mediante fallback.

### L10-004 — Constructor legado de Schema 4 permanece inerte

`FlowConstructorDefinition.blocks` conservado por Schema 4 es payload legado.
Lote 10 no convierte ese payload en el futuro Apply Constructor declarativo.

Por tanto:

- Schema 3 conserva su ejecución Constructor existente;
- Schema 4 no ejecuta `constructor.blocks`;
- Requirement application, creación de Nodes y Apply Constructor continúan
  fuera de alcance.

### L10-005 — Timer Schema 4

`FlowTimerRuntime` admite definiciones de Timer en Schema 3 y Schema 4.

En Schema 4:

1. valida el grafo;
2. valida `requirement_bindings`;
3. crea clocks sólo si ambos contratos son válidos;
4. el timeout entra a `FlowReadyExecutor`;
5. los Toks `$` vuelven a leer el Node/propiedad vivo en cada ejecución.

Schema 5 permanece fuera de este scheduler ejecutable.

### L10-006 — Composición completa dentro de Array/Dictionary

El modelo ya aceptaba `FlowValueSource` arbitrarios dentro de colecciones.
Lote 10 iguala la capacidad de autoría visual con ese contrato.

`FlowComplexValueEditor` puede crear o reemplazar hijos como:

- Scalar;
- VariableRef;
- Operation;
- Condition;
- NodeRef;
- NodePropertyRef;
- Array;
- Dictionary;
- ResourceRef;
- Enum;
- Bitfield.

No se flattenean los hijos a String o Variant authored values.

### L10-007 — Reutilización de los editores existentes

La composición de colecciones no implementa editores privados.

Reutiliza:

- `FlowVariableSelector`;
- `FlowOperationEditor`;
- `FlowConditionEditor`;
- `FlowSceneNodePanel`;
- `FlowNodePropertyOperandPicker`;
- `FlowComplexValueEditor` recursivo.

El contexto de escena (`scene_controller`, `scene_root`) viaja desde Akis o
desde el editor de Variables hasta los editores anidados.

Un Node ya ligado conserva su `requirement_id`; si no existe Requirement
ligado, el source conserva el `NodePath` relativo como locator de fallback.

### L10-008 — Profundidad segura de colecciones

La estructura persistente sigue siendo recursiva, pero el editor limita la
creación interactiva de Array/Dictionary recursivos a
`FlowComplexValueEditor.MAX_EDITOR_NESTING_DEPTH`.

Al alcanzar el límite:

- Array y Dictionary nuevos se deshabilitan;
- fuentes no recursivas y compuestas continúan disponibles;
- no se repara ni trunca contenido persistido existente.

### L10-009 — Matriz de interoperabilidad Tok

Un solo Akis debe poder validar y resolver, usando el mismo contexto, una
instancia de cada familia implementada:

- Literal;
- VariableRef (`@`);
- Operation (`~`);
- Condition (`#`);
- NodeRef (`$`);
- NodePropertyRef (`$`);
- Array;
- Dictionary;
- ResourceRef;
- Enum;
- Bitfield.

El resultado textual es una proyección runtime; los sources conservan sus tipos
semánticos originales.

### L10-010 — Un único gate final de revisión

Los lotes implementados durante este impulso no requieren una revisión humana
separada por lote. Se prepara una única revisión final en Godot 4.7.2 que cubra
los contratos cruzados y las superficies visuales afectadas.

Esto no convierte evidencia no ejecutada en PASS.

### L10-011 — Compatibilidad de la taxonomía escalar

Los valores históricos `BOOL..COLOR` permanecen en 0–6 y continúan siendo la
taxonomía escalar compartida para Method parameters/returns y Schema 5
Attributes/Outputs.

Array, Dictionary y Resource son una extensión exclusiva de graph Variables:

- se aceptan mediante `is_valid_variable_value_type()`;
- requieren `complex_value_source`;
- `is_valid_value_type()` sigue aceptando sólo 0–6;
- un Method/Attribute/Output no se vuelve complejo por el simple hecho de que
  los miembros adicionales existan en el enum de almacenamiento.

El smoke histórico conserva así su garantía sobre los siete tipos escalares,
mientras las focales de Lote 09/10 cubren las Variables complejas.

## Contratos preservados

- `segment_id` identifica la instancia Tok.
- `slot_id` identifica el rol semántico del schema.
- `source_id` identifica la instancia de ValueSource.
- `variable_id` identifica la definición Variable.
- `requirement_id` identifica la declaración Required Node.
- IDs, nombres, índices y NodePaths no se intercambian como identidades.
- Runtime no persiste Nodes, Callables u objetos vivos en el FlowGraph.
- Runtime no depende de APIs de editor.
- `demo/main.tscn` permanece protegido.
- Schema version no cambia; no se agrega una migración implícita.
- Expression legado permanece por compatibilidad.
- Schema 5 permanece fuera del executor Ready/Timer de Schema 3/4.

## Cambios principales

### Runtime/model

- `FlowValueSourceReferenceRemapper` remapea Variable y Requirement IDs de
  forma recursiva.
- `FlowGraph` espera al mapa completo antes del remapeo anidado.
- `FlowBlock` aplica el remapper a Akis persistido en propiedades.
- `FlowReadyExecutor` acepta Process/Ready/Timer Schema 4 con bindings válidos.
- `FlowReadyExecutor` mantiene Constructor Schema 4 inerte.
- `FlowTimerRuntime` agenda Timers Schema 4 tras validar bindings.

### Editor

- `FlowComplexValueEditor` añade un selector común de child source.
- Array/Dictionary pueden contener todas las familias públicas actuales.
- Node/Node Property reutilizan el Scene Node panel.
- El contexto de escena se propaga desde Akis y Variables.
- La creación recursiva Array/Dictionary está acotada.

## Evidencia automática preparada

### Referencias y duplicación

- `tests/model/flow_integration_lot_10_test.tscn`

Cubre:

- Requirement ID nuevo en copia;
- NodeRef anidado remapeado;
- NodePropertyRef anidado remapeado;
- bloque Akis remapeado;
- validación del grafo duplicado.

### Runtime Schema 4

- `tests/runtime/flow_integration_lot_10_test.tscn`

Cubre:

- Ready Schema 4;
- Requirement binding prioritario;
- propiedad viva en Akis;
- segunda ejecución con valor actualizado;
- Timer Schema 4;
- binding inválido bloquea ejecución;
- constructor.blocks legado no emite output.

### Autoría de colecciones

- `tests/editor/flow_integration_lot_10_editor_test.gd`

Cubre:

- menú Add Source;
- Variable;
- Operation;
- Condition;
- presencia de Node/Node Property;
- fuentes estructuradas;
- resolución del árbol resultante;
- límite de profundidad.

### Matriz completa

- `tests/model/flow_tok_matrix_lot_10_test.tscn`

Cubre en un mismo Akis:

Literal + Variable + Operation + Condition + Node + Node Property + Array +
Dictionary + Resource + Enum + Bitfield.

## Catálogo de comportamiento

Entradas añadidas:

- `FLUJO-BHV-AKIS-LOT10-REFERENCE-REMAP-001`
- `FLUJO-BHV-AKIS-LOT10-SCHEMA4-RUNTIME-001`
- `FLUJO-BHV-AKIS-LOT10-COLLECTION-AUTHORING-001`
- `FLUJO-BHV-AKIS-LOT10-TOK-MATRIX-001`
- `FLUJO-BHV-AKIS-LOT10-MANUAL-001`

Los focales automáticos se registran como `not_run`; la revisión visual se
registra como `manual_pending` hasta obtener evidencia real.

## Gate formal en Fedora / Godot 4.7.2

Seguir el ejecutor aprobado por `AGENTS.md`: native Godot 4.7.2, host Flatpak,
o Flatpak directo, en ese orden.

Como mínimo:

1. `git diff --check` excluyendo únicamente defectos preexistentes/protegidos
   que estén explícitamente documentados;
2. behavior catalog validator;
3. carga headless de editor;
4. model mist smoke test;
5. focales Lot 02–10 afectados;
6. focales Lot 10 anteriores;
7. revisión visual de Akis/Flusso/Variables;
8. save/reopen;
9. Undo/Redo;
10. ejecución Ready y Timer Schema 4 con Requirement;
11. verificación de que `demo/main.tscn` no cambió.

Los comandos canónicos de executor se derivan de `AGENTS.md`; esta
especificación no crea una segunda fuente de verdad para ellos.

## Revisión visual consolidada

En una escena desechable con `PVController`:

- abrir un campo Akis real;
- insertar `@`, `#`, `~`, `$`;
- insertar Array/Dictionary/Resource/Enum/Bitfield;
- dentro de Array/Dictionary crear Variable, Operation, Condition, Node y Node
  Property;
- comprobar previews y tooltips;
- editar y cancelar;
- comprobar Undo/Redo;
- duplicar el grafo y confirmar que las referencias siguen al duplicado;
- guardar/reabrir;
- ejecutar Ready Schema 4;
- ejecutar Timer Schema 4;
- romper deliberadamente un binding y comprobar que no hay ejecución silenciosa;
- comprobar foco/teclado y scroll en los popups alterados.

## Límites explícitos después del Lote 10

No se implementan aquí:

- Set Variable / Assign Variable como nuevo bloque;
- argumentos/returns ejecutables de Methods;
- Apply Constructor declarativo;
- creación automática de Required Nodes;
- ejecución Schema 5;
- signal Tok o signal action;
- nuevos action Toks;
- conversiones implícitas de tipos;
- reemplazo o eliminación del Expression legado.

## Gobernanza y evidencia de esta sesión

El repositorio exige `$flujo-baseline` antes de cambios y `$flujo-prove` al
cierre. Esta sesión GitHub-only no dispone de un ejecutor Godot/Flatpak; por
tanto no se registra ejecución fresca de esos tests.

Se aplicaron sus comprobaciones de alcance y catálogo a la auditoría final, pero
el resultado formal de prove no puede ser `PASA` hasta ejecutar Godot 4.7.2 y
la revisión visual requerida.

Estado de aceptación:

**IMPLEMENTADO — PROVE PENDIENTE / REVISIÓN HUMANA PENDIENTE.**

Everything is Flow; everything flows. 🌊
