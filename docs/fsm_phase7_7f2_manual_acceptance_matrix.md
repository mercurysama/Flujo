# Potok 7F-2 — Matriz de aceptación visual Fedora y Android

**Preparada:** 2026-11-02. **Rama:** `feature/fsm-runtime-flow-flusso`. **Godot mínimo y objetivo:** 4.7.2 stable. **Estado:** **0/25 ejecutadas en esta fase**, 15 Fedora y 10 Android **PENDING**. Esta matriz es un procedimiento para quien tenga el editor/dispositivo; CI headless no completa ninguna casilla. Partir de la rama y del HEAD que se registre antes de iniciar; no cambiar `main`.

## Preparación y evidencia

1. En Fedora, comprobar `git branch --show-current`, `git rev-parse HEAD`, `git status --short`, `git diff --check`, `git log -1 --oneline`. Respetar cualquier cambio local o worktree ajeno. Elegir Godot desde `AGENTS.md`: ejecutable nativo 4.7.2, host Flatpak o Flatpak directo, con `--version` confirmado.
2. Abrir el proyecto y una escena de prueba que contenga `PVController` con `FlowGraph` schema 3, dos máquinas de estados, dos estados en la principal, un bloque Print en Enter y Update, un bloque SDK externo en Exit, un slot `null` deliberado y un proceso Ready independiente. No sobrescribir escenas del usuario. Crear copias en `res://.godot/flujo_tests/` o proyecto desechable.
3. Registrar **resultado por ID: PASS / FAIL / BLOCKED / NOT RUN**; capturas antes/después, OS, versión real de Godot, dispositivo, orientación, resolución, entrada utilizada, hash del commit y notas/logs. Una prueba bloqueada no es PASS. Registrar incidencias con pasos mínimos de reproducción, esperado/obtenido y si el problema afecta datos.
4. Android: abrir **proyecto completo** en el editor Godot Android con la misma revisión y comparar la interfaz real; la prueba histórica de carga/render de octubre no sustituye esta aceptación. No asumir teclado físico presente.
5. Para cerrar 7F-2, exigir las 25 verificaciones ejecutadas y aceptadas por la persona mantenedora, con defectos documentados/resueltos, sin inferir aprobación a partir de GitHub Actions. Si algo no puede ejecutarse, conservar BLOCKED explícito y decidir con la persona mantenedora.

## Fedora — 15 escenarios presenciales

| ID | Prueba manual | Criterio observable | Estado |
| --- | --- | --- | --- |
| F01 | Abrir Fluo desde la fila de máquina del Inspector con Enter y doble clic | Una única instancia de drawer; Flow visible; máquina correcta; no aparece lista Blocks duplicada en Inspector | PENDING |
| F02 | Crear máquina/estado y seleccionar entre estados A y B | Las listas Enter/Update/Exit corresponden al estado seleccionado; sin valores de estado anterior | PENDING |
| F03 | Enter: mostrar una colección con hueco `null` | Renglón Empty distinguible y deshabilitado; ID y orden del bloque real no cambian | PENDING |
| F04 | Agregar Print a Enter desde catálogo | Aparece una vez, se selecciona el ID nuevo y teclado enfoca su fila | PENDING |
| F05 | Abrir Flusso del Print con Enter y doble clic | Solo una configuración, propiedad text visible, retorno a misma fila al cerrar | PENDING |
| F06 | Editar text en Flusso; cerrar con X y Escape | Edición en vivo queda aplicada; cerrar no confirma ni revierte; Escape no cierra Fluo en primer paso | PENDING |
| F07 | Revertir text y luego Undo/Redo | Se restaura el snapshot de sesión, y Undo/Redo alterna valores exactos sin tocar otra fase | PENDING |
| F08 | Move Up/Down cerca de dos bloques y de `null` | Solo intercambia vecinos físicos no nulos; límites no hacen saltos ni alteran datos | PENDING |
| F09 | Duplicate del bloque editado | ID único, texto igual, nombre de fase único, foco en copia y no en original | PENDING |
| F10 | Delete: Cancel, Escape y Confirm | Cancel/Escape no mutan ni agregan UndoRedo; Confirm elimina solo bloque escogido; Undo/Redo recupera exactamente recurso/ID | PENDING |
| F11 | SDK `manual_output:output`: agregar y editar en Enter, Update y Exit | Descriptores tipados aplicables, valores inmediatos, Revertir y duplicación con script y datos preservados | PENDING |
| F12 | Cambiar estado, máquina y `PVController` con Flusso/diálogo abiertos | No se editan elementos antiguos; callbacks obsoletos quedan inertes; el foco no salta a controles destruidos | PENDING |
| F13 | Navegación de teclado (Up/Down, Ctrl+Page, Page, Alt+Page, Shift+Alt+Page) | La selección de Inspector/Flow/Flusso y el foco real corresponden al contrato de cada tecla; Escape modal → Flusso → Fluo | PENDING |
| F14 | Guardar, cerrar y reabrir escena tras editar, mover, duplicar y borrar | Persisten IDs, fase, orden, huecos, texto, script SDK; Ready/Timer/Tok mantienen sus valores anteriores | PENDING |
| F15 | Drawer en izquierda/derecha, scroll largo, cambios de tamaño y aperturas repetidas | Elementos accesibles y visibles, botones sin solapamientos, teclado funcional, sin focus trap ni errores de consola de proyecto | PENDING |

## Android — 10 escenarios presenciales

| ID | Prueba manual | Criterio observable | Estado |
| --- | --- | --- | --- |
| A01 | Abrir el proyecto completo en Godot Android y entrar a Fluo | Carga real sin error crítico, Flow y Flusso legibles | PENDING |
| A02 | Repetir apertura de Fluo en orientación vertical | Drawer y controles dentro de pantalla; accesibilidad de ScrollContainer; sin recortes | PENDING |
| A03 | Repetir apertura de Fluo en orientación horizontal | Reflujo apropiado, contraste, controles visibles sin solapamiento | PENDING |
| A04 | Activar bloque con doble toque; abrir y cerrar Flusso | Doble toque no genera acciones repetidas, panel correcto y foco/selección coherente | PENDING |
| A05 | Agregar Print y SDK desde catálogo por toque | Botones táctiles alcanzables y fila nueva correcta en su fase | PENDING |
| A06 | Editar texto SDK y campo boolean/range con teclado táctil | Entrada de texto/valor usable, actualización inmediata y no se pierde contexto al salir del teclado | PENDING |
| A07 | Revertir y Undo/Redo mediante controles disponibles | El snapshot se restaura y las acciones no afectan estados vecinos; documentar controles no disponibles | PENDING |
| A08 | Mover, duplicar y borrar, probando Cancel y Confirm | Confirmación de borrado visible, botones de tamaño utilizable, ninguna eliminación por tocar fuera; Undo restaura | PENDING |
| A09 | Scroll vertical largo, abrir/cerrar Flusso, cambiar lado de drawer | Sin controles inalcanzables, drawer no captura toques externos inesperados, UI estable tras reorientaciones | PENDING |
| A10 | Guardar/reabrir escena y cambiar entre máquinas/estados/controladores | Persisten IDs y valores de SDK, la selección es correcta y las acciones antiguas no mutan otro propietario | PENDING |

## Plantilla de registro individual

```text
Caso: F01 / A01
Fecha y mantenedor:
Rama / commit SHA:
Dispositivo y OS:
Godot --version (o About en Android):
Orientación/resolución, método de entrada:
Estado: PASS | FAIL | BLOCKED | NOT RUN
Esperado:
Observado:
Captura o video (ruta/enlace):
Log de consola, errores y advertencias:
Issue/commit correctivo cuando aplique:
Revalidación y aprobación humana:
```

**Puerta de cierre:** 25 de 25 casos revisados, defectos críticos resueltos, evidencia capturada y aprobación explícita del mantenedor; sin cambios automáticos en `main`. Godot Actions, por definición, no ejecuta estas pruebas manuales.

*Todo es Flujo; todo fluye.* 🌊
