# Potok 7E-4A — Guía de aceptación humana en Fedora y Android

**Versión del plan:** 2026-11-02 · **Rama bajo prueba:** `feature/fsm-runtime-flow-flusso` · **Commit de referencia del plan:** `c155a563eb5fe2d36a9c68d9de651c0ce174f73e` · **Último checkpoint funcional antes de este lote:** `a84894c1c9874a32873191fb2b6e690e141c6848` · [CI 41404376030](https://github.com/mercurysama/Flujo/actions/runs/41404376030) **59/59 automatizadas aprobadas**. La CI **NO** es evidencia de aprobación manual.

**Estado de TODAS las pruebas de esta guía: PENDING.** Ninguna ejecución presencial, captura, vídeo, medición de interfaz física o prueba Android fue realizada al redactarla. **No usar el 2026-10-27 de Fluo Preview 1 como aprobación del Potok actual**: aquel resultado corresponde solo a carga y visualización inicial, no a estos escenarios.

## 0. Preparación sin riesgo para escenas originales

1. En Fedora, obtener **la rama y el commit exactos** del encabezado desde GitHub Desktop o un worktree independiente. Antes de cambiar ramas, comprobar que no se sobrescriben cambios locales. No trabajar sobre `main` ni sobre proyectos personales con datos importantes.
2. Abrir **una copia de prueba del proyecto** en Godot **4.7.2 estable** (o versión posterior compatible, anotando número completo), comprobar que el complemento `addons/vp_flujo/` está activado. No usar el dock heredado como sustituto de **Inspector → Fluo**.
3. Crear o duplicar una escena desechable `PotokManualQA` con un `PVController` y grafo schema 3. Registrar el nombre de la escena y una copia de seguridad; si el Inspector no permite crear la primera máquina sin ayuda, registrar **BLOCKED** para el recorrido de autoría y no escribir el `.tscn` manualmente para fabricar una aprobación.
4. Preparar una máquina `Patrulla`, estado `Reposo` y un segundo estado `Movimiento` **desde la interfaz** cuando sea posible; para pruebas de scroll, usar **una copia** con muchos estados, transiciones, nombres y notas largas. Para independencia, preparar otra escena/controlador `PotokAlternativo` y un Process/Timer de prueba.
5. En Android, abrir **la misma revisión del proyecto** en una instalación de Godot compatible y anotar la versión real, dispositivo, modo de entrada, orientación y tamaño aproximado de pantalla. No asumir que el Godot para Android coincide con Fedora; si no se puede cargar el proyecto, registrar bloqueo con pantalla/error. No prometer un APK/pre-release: esta fase no crea paquetes.
6. Ejecutar cada fila; anotar `PASS`, `FAIL`, `BLOCKED`, `N/A` **con motivo**, o conservar `PENDING`. Capturar al menos una evidencia vinculada al ID. Si un fallo destruye el contexto, reiniciar desde la copia desechable sin borrar el archivo de evidencia. Cada defecto requiere pasos mínimos y resultado observado, nunca una suposición.

## 1. Fedora — Godot escritorio, ratón y teclado físico

| ID | Escenario y pasos reproducibles | Resultado observable esperado | Estado |
|---|---|---|---|
| F01 | Inspector: seleccionar `PVController`, buscar **State Machines**; abrir máquina por **Enter** y después por doble clic | Abre el único Fluo contextual con Flow visible y máquina correcta; **sin lista Blocks duplicada** en Inspector | PENDING |
| F02 | Con máquina nueva/vacía, comprobar `Empty`; crear desde UI un primer estado `Reposo` y elegirlo como inicial | El borrador vacío no se rellena solo; el estado creado aparece **una vez**, señalado como inicial, con ID estable | PENDING |
| F03 **GATE** | En `Reposo`, abrir **Enter**, **Update**, **Exit** y buscar **Add block** en cada fase; añadir un bloque compatible en cada una, reordenarlos y guardar | Se pueden **crear y editar secuencias reales** en las tres fases solo con UI; no basta ver etiquetas Enter/Update/Exit. Si no aparece Add o no funciona: **BLOCKED, defecto bloqueante de Fase 7** | PENDING |
| F04 **GATE** | Crear segundo estado `Movimiento`; añadir transición `Reposo → Movimiento`, elegir destino, evento y prioridad mediante Flusso | Ambas filas y su transición son configurables desde interfaz; estados/destino mantienen identidad tras navegar | PENDING |
| F05 | Abrir propiedades de **Machine**, **State** y **Transition**; cambiar Name, Enabled/Note/Priority y pulsar **Revertir** por separado | Ediciones inmediatas, Revertir restaura la instantánea de **esa** sesión, sin cambiar el objeto de las otras; cerrar Fluo **no cancela** cambios | PENDING |
| F06 | Editar condición desde **Condition Tok #**; introducir Bool válido; probar **Cancel**, **Escape** y Confirm en pruebas independientes | Cancel/Escape descartan solo el borrador; Confirm guarda condición válida; no persiste ninguna condición incompleta | PENDING |
| F07 | En condición Tok o confirmación Delete, pulsar Escape dos veces | Primer Escape cierra diálogo sin borrar/guardar; el siguiente cierra Fluo y devuelve el foco a la fila del Inspector cuando sigue válida | PENDING |
| F08 | Con Flow enfocado, recorrer Up/Down, Ctrl+PageUp/PageDown, PageUp/PageDown, Alt+PageUp/PageDown y Alt+Shift+Page; probar nombres duplicados y ediciones de texto | Selección/Inspector sincronizados por ID, ciclo y retroceso de controles coherentes; edición de texto/otros controles no reciben atajos ajenos ni pierden foco | PENDING |
| F09 | Cambiar nombre/nota de estado y transición; realizar **dos ciclos Undo→Redo**; seleccionar otro estado y volver | Valores, selección y foco vuelven al control vivo equivalente, sin reenfocar elementos borrados ni modificar otro recurso | PENDING |
| F10 | Seleccionar transición; pulsar Delete y **Cancel**; repetir y confirmar; luego Undo/Redo | Cancel preserva todo; Confirm modifica exactamente la selección prevista y conserva referencias válidas; Undo/Redo son reversibles y no duplican elementos | PENDING |
| F11 | Llenar notas extensas y muchas transiciones; estrechar y ampliar ventana, cambiar Fluo de izquierda a derecha; desplazar ambos ejes | Scroll vertical/horizontal real; formulario Revertir, botón de cerrar y demás controles accesibles, sin solapamientos que impidan editar; ubicación conservada | PENDING |
| F12 | Abrir máquina, seleccionar otra escena/`PVController` desde SceneTree y volver; retirar temporalmente un controlador en copia de prueba | Fluo se cierra al cambiar o retirar el contexto; no aparecen formularios de otra escena ni se roba el foco; reapertura válida desde Inspector | PENDING |
| F13 | En **el mismo controlador**, abrir un **Process/Timer** desde Inspector, volver a State Machines | La ruta Ready sigue accesible; Fluo no mezcla propiedades Potok y Process/Timer ni introduce listas Inspector duplicadas | PENDING |
| F14 **GATE** | Guardar escena, cerrar y reabrir, volver a seleccionar la FSM; revisar orden Enter/Update/Exit, estados, transiciones, destinos y Tok; comparar ID persistentes con evidencia de archivo/versionado | El grafo sigue válido, con **mismos IDs y orden**; la vista y la edición continúan posibles. Cualquier regeneración silenciosa es FAIL | PENDING |
| F15 **GATE** | Ejecutar la escena de prueba creada solo desde UI: iniciar FSM de un estado, observar Enter/Update/Exit, emitir evento/transición al segundo estado | Semántica runtime visible corresponde a bloques y transición configurados; no requerir scripts escritos a mano para suplir una UI faltante | PENDING |

**Para F03, F04, F14 y F15 la ausencia de controles de autoría no se sustituye por datos creados mediante scripts o recursos prearmados.** El software puede superar todos los tests headless y aun así mantener estos escenarios en BLOCKED. En F08, probar `Alt+Shift` junto a las teclas Page que correspondan a la navegación instalada; registrar si alguna combinación queda capturada por el sistema operativo.

## 2. Android — interacción táctil, sin suponer teclado físico

| ID | Escenario y pasos reproducibles | Resultado observable esperado | Estado |
|---|---|---|---|
| A01 | Abrir proyecto/escena de prueba en Godot Android; comprobar plugin y `PVController` en Inspector | Carga correcta, sin errores bloqueantes ni dependencias de Fedora; anotar versión exacta y dispositivo | PENDING |
| A02 | **Vertical:** tocar la máquina en State Machines, doble toque si procede; seleccionar estados y transición | Inspector→Fluo se puede abrir y navegar por toque; no hay elementos indispensables completamente fuera de alcance | PENDING |
| A03 | **Horizontal:** repetir A02 tras girar dispositivo, con Fluo a izquierda y derecha | La disposición se recalcula, conserva selección/contexto válido y ofrece controles utilizables | PENDING |
| A04 | Con formularios/notas largos, deslizar vertical y horizontalmente, alcanzar **Transition Revertir** y cerrar Fluo | Scroll responde al dedo, sin tocar campos por accidente ni bloquearse; se puede llegar al último control y al cierre | PENDING |
| A05 | Editar Name, Note y Priority con teclado en pantalla, ocultarlo y volver al formulario | El teclado no tapa permanentemente el control editado ni corrompe entrada/foco; se puede confirmar la edición | PENDING |
| A06 | Abrir Condition Tok y Delete Confirmation, probar Confirm/Cancel/tocar fuera cuando aplique | Cancel no ejecuta cambios destructivos; tocar fuera no confirma por accidente; diálogos legibles y táctiles | PENDING |
| A07 | Cambiar campos y usar **Revertir**, Undo y Redo mediante controles disponibles | Valores y selección se restauran correctamente; si no existe control táctil de Undo/Redo, registrar BLOCKED/N/A motivado sin inventar gesto | PENDING |
| A08 | Cambiar de escena o controlador con Fluo abierto; volver a Inspector y reabrir | La antigua vista se descarta; no se reabre sola ni se mezclan datos; el foco y la entrada táctil siguen operativos | PENDING |
| A09 | Guardar/reabrir y cambiar vertical↔horizontal en mitad de una edición no destructiva | Datos, Tok, estados y orden persisten; no aparecen pérdidas de contexto ni controles inalcanzables | PENDING |
| A10 **GATE** | Repetir F03–F04 **mediante toques**, sin editar recursos manualmente | Se puede crear primer estado, bloques de las tres fases, segundo estado y transición a través de la interfaz táctil | PENDING |

**Teclado en Android:** solo repetir F08 si se conecta un teclado físico y se documenta; **no** atribuir a gestos o al teclado en pantalla equivalencia con Ctrl/Alt/Page sin comprobarla. No confundir carga/render del preview de octubre con aprobación de A01–A10 del commit actual.

## 3. Registro de pruebas: plantilla reproducible

Copiar **una ficha por ID observado** (sin alterar los renglones históricos de esta guía):

```text
ID: F__/A__
Resultado: PENDING | PASS | FAIL | BLOCKED | N/A (con motivo)
Fecha y hora (con zona): 
Evaluador:
Rama + SHA verificado:
Godot (versión completa):
Sistema: Fedora [versión] | Android [versión, dispositivo]
Orientación y resolución / tamaño ventana:
Escena y controlador de prueba:
Precondición:
Acciones efectuadas:
Esperado:
Observado:
Estado del foco/selección (si aplica):
Prueba de guardado/reapertura (si aplica):
Captura/vídeo/log y ruta o enlace:
Defecto/issue GitHub y pasos mínimos:
¿Afecta al cierre de Fase 7?: sí / no / por decidir
```

Para un FAIL, guardar la captura antes de reiniciar y enlazar un issue; para BLOCKED, registrar el control/recurso faltante y por qué no se puede continuar. N/A debe expresar una limitación real y justificada, no camuflar un fallo; PENDING significa **no observado**. No subir rutas privadas, credenciales ni datos de escenas personales.

## 4. Criterios y evidencia mínima

- **Fedora:** capturas o vídeo del Inspector con máquina elegida, Flow con estado inicial y fases, Flusso transición/Condition Tok/Revertir, dos ciclos Undo/Redo, scroll y recuperación tras cambio de controlador. Para persistencia, anotar los IDs con una comparación de copia versionada; un nombre igual no prueba ID igual.
- **Android:** vídeo/capturas en **ambas orientaciones**, evidencia del desplazamiento hasta el último campo, teclado en pantalla, confirmaciones reales, selección de estado y escena reabierta. Anotar limitaciones de hardware/entrada.
- **Gates de cierre:** F03, F04, F14, F15 y A10 requieren PASS observado para declarar la **autoría visual y táctil** completada; si el alcance de aceptación Android difiere, requiere decisión explícita del mantenedor y registro separado. La fase 7 también exige revisar F01–F13 y A01–A09: no se declara completa con solo gates verdes. `docs/fsm_implementation_plan.md` fase 7 (nueve puntos) sigue siendo la fuente de criterios funcionales.
- **Regresión automática:** último punto conocido: [CI 41404376030](https://github.com/mercurysama/Flujo/actions/runs/41404376030) 59/59 sobre el checkpoint de 7E-3B; registrar la CI del SHA realmente probado para nuevas rondas. Una CI verde solo acredita tests automatizados, no resultados manuales.
- **Aprobación:** el mantenedor revisa evidencia y defectos, acepta cada escenario explícitamente y decide si los fallos bloqueantes se convierten en nuevos microbloques. Ningún `PENDING` se convierte a PASS solo porque se haya redactado este documento.

## 5. Continuidad

**7E-4A está terminado cuando esta guía exista y las filas sigan PENDING honestamente.** **7E-4B** consolidará evidencias recibidas y la comparación explícita con los nueve requisitos originales; no anticipa ni inventa ejecución manual. La preparación de un pre-release Android pertenece al plan de empaquetado y no es prueba de aceptación por sí sola. No combinar esta guía con una modificación de runtime/modelo.

Todo es Flujo; todo fluye. 🌊
