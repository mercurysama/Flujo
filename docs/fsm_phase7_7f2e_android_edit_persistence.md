# Potok 7F-2E — Segunda tanda de aceptación Android (A06–A10)

**Preparación:** 2026-11-02. **Rama exclusiva:** `feature/fsm-runtime-flow-flusso`. **Versión objetivo:** Godot 4.7.2 stable; registrar la versión real de Godot Android. **Estado:** A06–A10 **PENDING / NOT RUN**. Este documento completa los procedimientos para los 25 casos, **no ejecuta ni aprueba** ninguna prueba visual. [Matriz global](fsm_phase7_7f2_manual_acceptance_matrix.md) · [Android A01–A05](fsm_phase7_7f2d_android_loading_touch_orientation.md).

## Condiciones previas y protección de datos

1. Trabajar en **una copia del proyecto completo** correspondiente al SHA de la rama, no solamente el addon. Registrar dispositivo, Android, versión de Godot, orientación, resolución, métodos de entrada y origen del proyecto. No afirmar equivalencia con HEAD remoto sin evidencia.
2. Preparar una escena descartable con `PVController`, dos máquinas o estados, Enter/Update/Exit, un `null` intencional, bloque Print, paquete SDK `manual_output:output` realmente instalado cuando sea posible y un Ready testigo. **Nunca sobrescribir `demo/main.tscn` ni escenas personales**.
3. Tomar capturas antes/después, conservar los valores conocidos de los bloques y registrar `PASS / FAIL / BLOCKED / NOT RUN` por escenario. Si faltan controles, no inventar alternativas ni marcar éxito. No asumir que un teclado físico está conectado; distinguir acciones táctiles y atajos no disponibles.
4. Distinguir los errores de Godot de sus avisos. Si se produce fallo, documentar el mínimo reproducible y las modificaciones observadas en el modelo. La historia de Fluo Preview 1 en Android cubre carga/render anterior, no esta matriz.

## A06 — Propiedades SDK y teclado táctil

1. Abrir Fluo y activar Flusso en una instancia de `manual_output:output` del estado seleccionado.
2. Editar `message` usando el teclado virtual, ocultar y volver a mostrar el teclado, y comprobar que el valor es inmediato y no se pierde.
3. Modificar `boolean_value` mediante su checkbox y `ranged_int` mediante el control numérico, si esos descriptores son realmente visibles.
4. Cerrar Flusso sin pulsar Revertir, reabrir el mismo bloque y comprobar que persisten los valores editados.
5. Cambiar de estado y volver: no debe escribir en otro bloque ni conservar el teclado o foco sobre un control destruido.

**PASS:** tres tipos de controles funcionan con toque/teclado virtual, cambios live y contexto correcto. **Evidencia:** mensajes, booleano y rango antes/después, capturas con teclado abierto/cerrado.

## A07 — Revertir y Undo/Redo por controles disponibles

1. Abrir Flusso con un `message` inicial conocido y registrar el valor de apertura.
2. Cambiarlo por toque/teclado a un segundo valor; confirmar que se aplica inmediatamente.
3. Pulsar Revertir; confirmar que se conserva Flusso abierto y se restaura el snapshot exacto.
4. Usar Undo/Redo mediante las acciones de Godot realmente disponibles en el editor Android; comprobar que alternan el cambio y la reversión esperados.
5. Verificar valores de otro estado y otra fase; si no existe control accesible para Undo/Redo, marcar `BLOCKED` y registrarlo en vez de afirmar que funciona.

**PASS:** snapshot correcto, controles táctiles alcanzables, historial coherente y sin afectar a otros propietarios. **Evidencia:** valor inicial, valor editado, resultado Revertir y Undo/Redo.

## A08 — Move, Duplicate y Delete con Cancelar/Confirmar

1. Seleccionar un bloque en Enter con otro vecino, y ejecutar Move Up/Down mediante controles táctiles; comprobar orden y no saltar un `null`.
2. Duplicar el bloque; verificar copia adyacente con ID distinto, script y valores iguales inicialmente.
3. Pulsar Delete de la copia y **Cancelar**: nada debe desaparecer.
4. Abrir de nuevo Delete; tocar fuera del modal o el control de cancelar cuando exista, verificar que no se confirma la acción de manera implícita.
5. Reabrir y pulsar **Confirmar**; comprobar que únicamente desaparece la copia, y ejecutar Undo cuando esté disponible para recuperarla.

**PASS:** botones alcanzables, confirmación explícita, Cancelar/clic fuera sin pérdida y operaciones reversibles. **Evidencia:** fila antes/después, captura del diálogo y de la copia restaurada.

## A09 — Scroll largo, disposición y cambio de orientación

1. Abrir una lista extensa de bloques para requerir scroll en Flow y controles numerosos en Flusso.
2. Desplazarse desde el inicio al final y volver; comprobar que Add, Revertir y Cerrar siguen accesibles.
3. Cambiar el lado del drawer izquierda/derecha y cerrar/abrir Flusso varias veces sin selección equivocada.
4. Alternar orientación vertical/horizontal durante la sesión y volver a revisar controles, hitboxes y scroll. Documentar si Android reinicia el editor o pierde contexto.
5. Comprobar que el drawer no transmite gestos a controles subyacentes y que no queda una capa invisible capturando toques tras cerrar.

**PASS:** toda la interfaz operable con táctil y scroll, sin superposición o controles inaccesibles. **Evidencia:** capturas inicio/final en ambas orientaciones y con drawer a ambos lados.

## A10 — Persistencia real y aislamiento entre contextos

1. En una escena descartable registrar máquina, estado, bloque SDK, valores, orden y huecos `null`.
2. Editar el SDK, duplicar y borrar una copia con confirmación; guardar la escena.
3. Cerrar **realmente** la escena y reabrirla desde el editor Android. Comprobar bloque original, script, propiedades, IDs y orden: no basta con revisar un recurso en memoria.
4. Cambiar entre estados/máquinas y otro `PVController` cuando la escena de prueba los incluya; comprobar que las listas/Flusso corresponden al propietario actual.
5. Confirmar que Ready y otras fases no fueron alteradas; registrar cualquier cambio inesperado, error al guardar/reabrir o retorno de foco a controles obsoletos.

**PASS:** los valores y la estructura persisten entre sesiones y no se modifica otro propietario. **Evidencia:** capturas antes del guardado y después de la recarga, SHA de origen, escena descartable y consola.

## Registro de aceptación

```text
Potok 7F-2E / Android — Fecha:
Rama y SHA del proyecto:
Dispositivo y versión de Android:
Godot versión / orientación / resolución:
Fuente del proyecto y escena descartable:
Método de entrada:
A06: PASS | FAIL | BLOCKED | NOT RUN — evidencia:
A07: PASS | FAIL | BLOCKED | NOT RUN — evidencia:
A08: PASS | FAIL | BLOCKED | NOT RUN — evidencia:
A09: PASS | FAIL | BLOCKED | NOT RUN — evidencia:
A10: PASS | FAIL | BLOCKED | NOT RUN — evidencia:
Valores e IDs antes/después:
Errores y advertencias:
Defectos, impacto y reproducción:
Aprobación explícita del mantenedor:
```

## Cierre de preparación y siguiente puerta

La documentación queda preparada para **F01–F15 Fedora y A01–A10 Android**. **La fase 7F-2 todavía no está aprobada:** faltan las 25 ejecuciones presenciales. La siguiente actividad no es otra guía, sino realizar las verificaciones en los dispositivos, incorporar las evidencias, resolver defectos reproducibles en microbloques bajo `$flujo-baseline`/`$flujo-prove` y solicitar la aprobación humana expresa. No se modifica producción, runtime, esquema, escenas protegidas ni `main`.

*Todo es Flujo; todo fluye.* 🌊
