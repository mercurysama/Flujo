# Potok 7F-2C — Tercera tanda Fedora: SDK, contexto, teclado y persistencia

**Fecha de preparación:** 2026-11-02. **Rama exclusiva:** `feature/fsm-runtime-flow-flusso`. **Godot:** 4.7.2 stable. **Escenarios:** F11–F15 de la [matriz 7F-2](fsm_phase7_7f2_manual_acceptance_matrix.md). **Estado:** los cinco escenarios **PENDING / NOT RUN**; tampoco existen resultados humanos acreditados de F01–F10 ni de A01–A10. Esta guía no declara aprobación visual.

## Condiciones generales

- Completar el inventario seguro de [7F-2A](fsm_phase7_7f2a_fedora_preflight.md): SHA, rama, `git status --short`, Godot real y escena de prueba descartable. Si hay cambios locales de otros trabajos, conservarlos sin `reset`, `clean`, `stash` ni operaciones automáticas.
- Trabajar sobre **copias** de escenas en un proyecto desechable, no `demo/main.tscn`. Preparar un `PVController` de esquema 3 con dos máquinas, dos estados por máquina, Enter/Update/Exit, un bloque SDK `manual_output:output` cuando el paquete de prueba esté disponible, un `null` intencional, Ready y, para F14, testigos Timer/Condition Tok que realmente estén soportados por ese grafo.
- Guardar antes de cada caso los valores de referencia y los IDs internos en un registro reproducible si el editor permite consultarlos. **No fabricar IDs ni acceder a recursos internos mediante un control inexistente**. Capturas, vídeo breve o registro textual acompañado de salida del editor pueden servir como evidencia, según el caso.
- Ante un error, capturar esperado/observado, versión Godot, SHA, pasos mínimos y error de consola. Marcar `FAIL` o `BLOCKED` según corresponda; ninguna prueba automática sustituye la revisión.

## F11 — Paquete externo SDK en Enter, Update y Exit

1. Verificar que el catálogo muestra la entrada del paquete `manual_output:output`; si el paquete no está disponible, anotar el motivo y marcar `BLOCKED`.
2. Insertar una instancia distinta en cada fase mediante su botón Add. Confirmar que aparecen en las listas correctas sin modificar fases hermanas.
3. Abrir Flusso de cada instancia; comprobar los descriptores expuestos, como `message`, `boolean_value`, `ranged_int` y `enum_value`, según los controles realmente representados.
4. Editar propiedades, comprobar actualización inmediata, usar Revertir y Undo/Redo de una edición tipada; validar que los valores de las otras fases no cambian.
5. Duplicar una instancia; verificar nuevo ID, script SDK preservado e independencia de valores de ambas copias.

**PASS:** tres fases funcionales, tipado correcto y recurso externo conservado, sin filtración de datos entre fases. **Evidencia:** vista de catálogo, campos y valores antes/después, comparación de instancia original/copia.

## F12 — Cambio de contexto y rechazo de acciones obsoletas

1. Con Flusso de un bloque SDK abierto, cambiar del estado A al estado B de la misma máquina; comprobar qué panel permanece visible y que no se edita A usando controles del nuevo contexto.
2. Repetir cambiando a otra máquina y después a otro `PVController`; verificar que listas, selección y propiedades corresponden al nuevo propietario.
3. Abrir Delete en una copia descartable y cambiar el contexto antes de confirmar, cuando la interfaz permita hacerlo de forma normal. Verificar que no se borra el recurso del contexto anterior.
4. Alternar varias veces entre los contextos, editar una propiedad de la entidad actual y revisar si aparece un cambio colateral o un error de foco.
5. No simular señales mediante código para considerar esta prueba manual: comprobar lo que el usuario puede realizar realmente en Godot.

**PASS:** los controles del contexto anterior quedan invalidados y no se modifica otro estado, máquina o controlador. **Evidencia:** identificación de los dos contextos, valores antes/después y registro de consola.

## F13 — Teclado, jerarquía Escape y foco visible

1. Usar Up/Down en Flow; comprobar desplazamiento normal dentro de la lista de bloques.
2. Usar Ctrl+PageUp/PageDown; verificar navegación circular por bloques e ID seleccionado.
3. Usar PageUp/PageDown sin modificadores; comprobar sincronía de la selección visible del Inspector con el contenedor y retención del foco en Flow.
4. Con Flusso abierto, recorrer controles con Alt+PageUp/PageDown; invertir con Alt+Shift+PageUp/PageDown sin perder valores.
5. Comprobar Escape con diálogo de borrado abierto: primero cancela el modal; después, con Flusso abierto, lo cierra; un Escape posterior cierra Fluo. Documentar foco real en cada transición.

**PASS:** acciones y foco coinciden con la semántica documentada; ni cambios inadvertidos del modelo ni controles huérfanos. **Evidencia:** capturas/registro de secuencia de teclas y elemento enfocado.

## F14 — Guardar, cerrar y reabrir una escena modificada

1. En una escena de prueba con valores conocidos, realizar un cambio live en Flusso, un Move, un Duplicate y un Delete confirmado; registrar la disposición final.
2. Guardar como nueva `.tscn` descartable y cerrar la escena. Reabrir desde Godot, idealmente con una instancia nueva (no confundir el recurso anterior en memoria con deserialización).
3. Inspeccionar IDs de máquina/estado/bloque, orden exacto, posiciones `null`, mensajes y propiedades SDK, además de script externo y estado `enabled`.
4. Comparar Ready, Update y Exit con los valores iniciales. Si hay Timer o Condition Tok en la fixture utilizada, comprobar su contenido de forma independiente; si no los hay, registrar esa limitación, no inventar PASS para esas subcomprobaciones.
5. Confirmar que el proyecto no presenta errores de carga, migraciones implícitas ni sustitución de clases SDK; copiar el log de errores/advertencias por separado.

**PASS:** la escena realmente recargada conserva identidades, propiedades y todas las colecciones exigidas. **Evidencia:** ruta de la copia, capturas antes/después y valores/IDs registrados.

## F15 — Disposición, lectura, scroll y aperturas repetidas

1. Abrir Fluo varias veces con máquinas y estados diferentes, cerrar con X, Escape y clic externo donde corresponda.
2. Mover el drawer al lado izquierdo y derecho, sin abrir paneles duplicados.
3. Forzar una lista larga de bloques y un Flusso con controles suficientes para requerir scroll; comprobar que se puede llegar a los controles superiores e inferiores.
4. Cambiar el tamaño disponible del editor/ventana y volver a abrir Fluo. Verificar solapamientos, legibilidad, hitboxes, botones de confirmación y foco al regresar.
5. Comprobar la consola: distinguir avisos esperados de Godot de errores reales del proyecto. No aceptar `PASS` si alguna función crítica queda fuera de la pantalla.

**PASS:** layout y scroll permiten operar la interfaz de forma repetida, sin pérdida de selección, elementos inalcanzables ni errores críticos. **Evidencia:** capturas de ambos lados, de la zona inferior de scroll y de consola.

## Registro de evidencia F11–F15

```text
Potok 7F-2C / Fedora
Fecha:                   Rama: feature/fsm-runtime-flow-flusso
HEAD local:              Git status antes/después:
Godot ejecutor/version:  SO/resolución:
Escena de pruebas/copia:
F11: PASS | FAIL | BLOCKED | NOT RUN — observaciones, evidencias:
F12: PASS | FAIL | BLOCKED | NOT RUN — observaciones, evidencias:
F13: PASS | FAIL | BLOCKED | NOT RUN — observaciones, evidencias:
F14: PASS | FAIL | BLOCKED | NOT RUN — observaciones, evidencias:
F15: PASS | FAIL | BLOCKED | NOT RUN — observaciones, evidencias:
IDs/valores de referencia:
Errores de consola:
Advertencias:
Issues y reproducción:
Aprobación humana:
```

**Próxima tanda documental:** 7F-2D Android A01–A05; 7F-2E Android A06–A10. La aceptación real no se cierra sin completar las pruebas presenciales, corregir defectos observados y recibir aprobación expresa. Ninguna edición de producción, cambio de esquema o merge a `main` forma parte de 7F-2C.

*Todo es Flujo; todo fluye.* 🌊
