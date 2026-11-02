# Potok 7F-2B — Segunda tanda presencial Fedora (F06–F10)

**Preparado:** 2026-11-02. **Rama:** `feature/fsm-runtime-flow-flusso`. **Estado:** F06–F10 **NOT RUN**. Este guion no certifica la interfaz: requiere una sesión real de Godot 4.7.2 y evidencias humanas. La tanda F01–F05 y los demás escenarios continúan pendientes hasta tener resultados documentados. [Matriz madre](fsm_phase7_7f2_manual_acceptance_matrix.md) · [Preflight F01–F05](fsm_phase7_7f2a_fedora_preflight.md).

## Condiciones para ejecutar

- Confirmar `git branch --show-current`, `git rev-parse HEAD`, `git status --short` y Godot 4.7.2 estable, conforme al preflight de 7F-2A. No actualizar ni limpiar un worktree con cambios ajenos.
- Trabajar **únicamente con una copia descartable** de escena con `PVController`, máquina y estado identificables, al menos dos bloques Print contiguos en Enter, un hueco `null` deliberado, Update y Exit testigos, y Ready independiente. Guardar un respaldo de esa escena de prueba antes de editar. No tocar `demo/main.tscn` ni escenas del usuario.
- Abrir la máquina con el Inspector y dejar visible Fluo. Seleccionar un bloque Print en Enter; usar Flusso para los campos compatibles. Distinguir la selección de Flow, el foco efectivo, la visibilidad de Flusso y los cambios persistentes: son estados diferentes.
- Registrar capturas y valores **antes, después, tras Undo y tras Redo**. Si un control no se encuentra o el entorno no ofrece Undo/Redo, marcar `BLOCKED` y registrar lo observado, nunca `PASS` por inferencia.

## F06 — Edición inmediata y cierre sin cancelación

1. Abrir Flusso del Print seleccionado y anotar su `text` original (`mensaje_A`).
2. Editar el texto a `mensaje_B` y comprobar que el modelo se actualiza antes de cerrar Flusso.
3. Cerrar con X; volver a abrir el mismo bloque: `mensaje_B` debe permanecer.
4. Modificar a `mensaje_C`, presionar Escape una vez y comprobar que **solo cierra Flusso**, sin descartar `mensaje_C` ni cerrar Fluo.
5. Reabrir y confirmar `mensaje_C`, estado correcto y foco recuperado en la misma fila.

**PASS:** edición live, X y Escape no equivalen a cancelar, foco en el bloque original. **Evidencia:** tres valores, capturas de cierre/reapertura, estado del drawer.

## F07 — Revertir, Undo y Redo

1. Abrir Flusso del bloque con valor conocido `mensaje_A` y registrar el snapshot de apertura.
2. Cambiarlo a `mensaje_B` y comprobar actualización inmediata.
3. Pulsar **Revertir**; confirmar que vuelve a `mensaje_A` y que Flusso sigue abierto.
4. Usar Undo para restaurar `mensaje_B`; luego Redo para recuperar `mensaje_A`. Verificar que Update, Exit y el otro bloque siguen iguales.
5. Repetir desde una sesión abierta de nuevo; no asumir que Revertir equivale a borrar ni a deshacer una acción estructural.

**PASS:** snapshot inicial exacto, Revertir permanece dentro de Flusso, operación única y Undo/Redo coherentes. **Evidencia:** valores y foco/panel antes/después.

## F08 — Move Up/Down y límites de hueco null

1. Comenzar con Enter `[null, bloque_A, bloque_B]` en escena descartable.
2. Seleccionar `bloque_A`, pulsar Move Up: **no debe saltar** el `null`.
3. Pulsar Move Down: debe dejar `[null, bloque_B, bloque_A]`, conservando instancias e IDs.
4. Repetir Move Up/Down con los límites pertinentes y comprobar que no se crean elementos, que ningún `null` se normaliza, y que Flow selecciona el ID correcto.
5. Observar foco visible tras cada reconstrucción del editor.

**PASS:** movimiento exclusivamente adyacente y válido, sin cambio de propiedades, IDs, ni contenido de otra fase. **Evidencia:** orden y selección antes/después.

## F09 — Duplicate y selección de copia

1. Editar `bloque_A` en Flusso y cerrar manteniendo texto aceptado.
2. Seleccionar `bloque_A` y pulsar **Duplicate** desde Enter.
3. Confirmar nueva fila **adyacente** con el mismo texto editado pero nuevo ID interno; el original no cambia.
4. Abrir Flusso de la copia, editar su texto y comprobar que el original conserva el anterior. Verificar foco y selección de la copia.
5. Undo/Redo de duplicación según los controles disponibles, observando identidad restaurada sin duplicar de forma adicional.

**PASS:** copia independiente y texto inicial equivalente, nueva identidad, selección correcta; no tocar Update/Exit. **Evidencia:** captura con ambas filas y valores.

## F10 — Delete: Cancelar, Escape, Confirmar y Undo/Redo

1. Seleccionar la **copia de F09**; pulsar Delete y comprobar que **solo** aparece la confirmación y la colección aún no cambia.
2. Pulsar Cancel; confirmar que la copia y el historial se conservan.
3. Volver a abrir Delete; pulsar Escape. Debe cerrar la confirmación sin cerrar Fluo ni borrar, y devolver foco a la lista.
4. Volver a abrir y pulsar **Confirm/Delete**; solo la copia debe desaparecer.
5. Ejecutar Undo: reaparece el mismo bloque e ID; Redo: desaparece nuevamente. El original, el `null` y las fases restantes siguen intactos.

**PASS:** ninguna operación destructiva sin confirmación; Cancel/Escape sin entrada histórica; Undo/Redo restauran el mismo recurso y el foco continúa utilizable. **Evidencia:** cuatro capturas (diálogo, Cancel/Escape, Confirm y Undo).

## Registro de resultados

```text
Potok 7F-2B — Fedora  |  Fecha:
Repositorio/checkout:               Rama:
HEAD inicial y final:               git status:
Godot ejecutor y versión:           Escena descartable:
F06: PASS / FAIL / BLOCKED / NOT RUN — observado / evidencia:
F07: PASS / FAIL / BLOCKED / NOT RUN — observado / evidencia:
F08: PASS / FAIL / BLOCKED / NOT RUN — observado / evidencia:
F09: PASS / FAIL / BLOCKED / NOT RUN — observado / evidencia:
F10: PASS / FAIL / BLOCKED / NOT RUN — observado / evidencia:
Consola Godot — errores:
Consola Godot — advertencias:
Defectos: pasos reproducibles, esperado/obtenido, impacto sobre datos:
Estado final del proyecto, archivos modificados y aprobación explícita:
```

## Puerta de revisión y continuidad

Si un escenario falla, documentar antes de editar y no debilitar el comportamiento esperado. Aplicar `$flujo-baseline` y `$flujo-prove` conforme a `AGENTS.md` antes de cualquier corrección funcional. Se prohíbe declarar aprobada toda 7F-2 solo por CI, capturas previas o por la existencia de esta guía. Siguiente preparación: **7F-2C Fedora F11–F15**, una vez que exista evidencia presencial o se requiera preparar el resto de los procedimientos sin ejecutar. **Los 25 escenarios siguen pendientes hasta recibir resultados reales**.

*Todo es Flujo; todo fluye.* 🌊
