# Potok 7F-2D — Primera tanda de aceptación Android (A01–A05)

**Preparado:** 2026-11-02. **Rama de referencia:** `feature/fsm-runtime-flow-flusso`. **Godot objetivo:** 4.7.2 stable (anotar versión que Android realmente reporte). **Estado:** A01–A05 **PENDING**; tampoco hay evidencias nuevas que permitan dar por aprobados F01–F15 o A06–A10. Este documento es un protocolo de prueba **presencial**, no una ejecución remota ni un resultado de CI. [Matriz general](fsm_phase7_7f2_manual_acceptance_matrix.md) · [Precedente de Fluo Android](fluo_preview_01.md).

## Preparar el entorno sin arriesgar archivos

1. Abrir el **proyecto completo** de Flujo, correspondiente al commit de la rama que se vaya a probar. Anotar el SHA con el que se preparó la copia: si el editor Android no muestra Git, obtenerlo previamente del origen del proyecto y registrar cómo se identificó. No usar el ZIP solo-del-addon como si fuera el proyecto completo. No afirmar equivalencia entre el Android instalado y el GitHub actual sin evidencia de los archivos.
2. Anotar **dispositivo, versión de Android, versión Godot visible en About, tamaño/resolución de pantalla, orientación y método de entrada**. Las capturas de Fluo del 2026-10-27 son evidencia histórica de render en otro checkpoint, **no** aprobación de la presente tanda.
3. Usar una **copia descartable** de la escena con `PVController`, una máquina Potok, al menos dos estados y bloques editables de Enter/Update/Exit. No sobrescribir `demo/main.tscn` ni escenas de trabajo. Para A05, preparar también un paquete `manual_output:output` compatible con el proyecto de prueba; si no aparece en el catálogo, registrar `BLOCKED` en el subcaso SDK en lugar de simularlo.
4. Grabar una captura **antes y después** de cada acción. Si girar el dispositivo reinicia Godot, hace perder cambios, o impide continuar, registrarlo como defecto observable. Separar advertencias normales de errores de carga/editor.
5. Para cada A01–A05 usar `PASS | FAIL | BLOCKED | NOT RUN`. No dar `PASS` por CI, porque la entrada táctil, orientación, hitboxes y accesibilidad visual no se prueban de manera suficiente con Godot headless.

## A01 — Apertura real del proyecto y paneles Fluo, Flow y Flusso

1. Iniciar Godot Android y abrir la copia del proyecto completo en el mismo commit identificado.
2. Confirmar que la escena de prueba y `PVController` aparecen en la vista de editor sin error bloqueante.
3. Desde la fila de máquina del Inspector, abrir Fluo mediante toque según el mecanismo que realmente ofrezca el editor Android; comprobar que la máquina y el estado seleccionados son correctos.
4. Activar un bloque existente y mostrar Flusso. Verificar que **Flow**, **Flusso**, botones de cierre y Revertir son legibles; distinguir visibilidad de operabilidad.
5. Cerrar Flusso y luego Fluo, sin cambios accidentales en el modelo.

**PASS:** proyecto/escena cargados, panel contextual único y ruta de apertura/cierre operable. **Evidencia:** versión, captura del proyecto, Inspector, Fluo y Flusso, errores de consola.

## A02 — Vertical: panel completo y scroll accesible

1. Con la orientación **vertical** fijada, abrir desde el Inspector la misma máquina.
2. Verificar que Fluo no tapa permanentemente un control necesario, el panel cabe en el área efectiva del editor y las secciones no se montan unas sobre otras.
3. Abrir Flusso de un bloque y desplazar su contenido hasta el final cuando supere la altura visible.
4. Comprobar si los controles de **Cerrar**, **Add** y **Revertir** son alcanzables y si el scroll conserva la selección al volver arriba.
5. Capturar el principio y fin del recorrido. Si Android/Godot no permite orientar en vertical, marcar `BLOCKED` y describir el bloqueo real.

**PASS:** controles utilizables sin recortes, scroll completo y sin pérdida de contexto. **Evidencia:** capturas verticales superior/inferior y tamaño de pantalla.

## A03 — Horizontal: redistribución y controles sin superposición

1. Cambiar físicamente a orientación **horizontal** con el mismo proyecto y máquina.
2. Comprobar que Godot conserva el contexto; si reinicia la escena, documentarlo explícitamente.
3. Abrir/reabrir Fluo y Flusso; comparar anchura y altura útiles, contraste, botones de cierre y contenido en Flow.
4. Desplazarse hasta el final de un panel largo, seleccionar un bloque y comprobar que Flusso no esconde definitivamente controles operativos.
5. Repetir el cierre/apertura tras un segundo giro sin pérdida de cambios previamente guardados.

**PASS:** interfaz funcional en horizontal, sin hitboxes tapadas ni contenido inaccesible. **Evidencia:** capturas horizontal y tras segundo giro, descripción de redistribución.

## A04 — Doble toque y cierre de Flusso

1. Seleccionar un bloque Print existente en Flow.
2. Activarlo mediante **doble toque** (no pulsaciones sobre botones distintos) y observar si Flusso abre exactamente una vez.
3. Verificar que la configuración corresponde al bloque realmente seleccionado, no al anterior, y que el texto sigue siendo el esperado.
4. Cerrar Flusso con su botón X; comprobar que Fluo sigue abierto y que el bloque sigue seleccionado.
5. Repetir la apertura y cierre varias veces; no deben aparecer paneles duplicados ni errores de foco.

**PASS:** activación fiable con doble toque, cierre jerárquico correcto y selección preservada. **Evidencia:** vídeo corto o secuencia antes/después, modelo seleccionado.

## A05 — Crear Print y SDK desde el catálogo por toque

1. En Enter, usar **Add** por toque y seleccionar el bloque **Print** desde el catálogo.
2. Comprobar que se agrega **una sola instancia** y que queda en la fase y estado correctos.
3. Repetir desde otra fase con la entrada real `manual_output:output` del SDK, si está instalada la fixture; comprobar que no se reemplaza por Print ni se crea un bloque incorrecto.
4. Seleccionar cada instancia recién creada y abrir Flusso. Verificar que los controles y botones son táctilmente alcanzables (no basta con que se vean).
5. Comprobar que otra máquina/estado y la colección Ready no cambiaron; si falta el paquete SDK, registrar la parte afectada como `BLOCKED`, no como éxito parcial global.

**PASS:** ambos tipos se crean exactamente una vez, controles tocables y recursos correctos, sin escrituras fuera de fase. **Evidencia:** catálogo antes, listas después y panel de cada bloque.

## Registro de evidencia A01–A05

```text
Potok 7F-2D / Android — Fecha:
GitHub rama + SHA del proyecto copiado:
Dispositivo/modelo:              Android versión:
Godot versión (About):           Resolución:
Fuente del proyecto / ubicación de copia:
Entrada: táctil / mouse / teclado externo:
A01: PASS | FAIL | BLOCKED | NOT RUN — evidencia:
A02: PASS | FAIL | BLOCKED | NOT RUN — evidencia:
A03: PASS | FAIL | BLOCKED | NOT RUN — evidencia:
A04: PASS | FAIL | BLOCKED | NOT RUN — evidencia:
A05: PASS | FAIL | BLOCKED | NOT RUN — evidencia:
Consola / errores:
Defecto + reproducción mínima + datos afectados:
Confirmación de archivos originales intactos:
Validación y aprobación del mantenedor:
```

## Continuidad

**Siguiente microbloque: 7F-2E**, guía Android **A06–A10** (edición con teclado táctil, Revertir/UndoRedo, acciones destructivas, scroll y persistencia). Ningún caso de 7F-2 cambia de PENDING a PASS sin resultados físicos verificados; si aparece un bug, conservar evidencia RED y corregirlo en una etapa separada siguiendo `$flujo-baseline`, pruebas focales y `$flujo-prove`. `main`, runtime, esquema y demos permanecen fuera de alcance.

*Todo es Flujo; todo fluye.* 🌊
