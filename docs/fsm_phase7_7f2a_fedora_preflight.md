# Potok 7F-2A — Prevalidación de Fedora (sin modificar el proyecto)

**Preparación:** 2026-11-02. **Rama obligatoria:** `feature/fsm-runtime-flow-flusso`. **Objetivo:** recuperar el contexto visual y registrar la primera tanda **F01–F05** de [la matriz de 25 casos](fsm_phase7_7f2_manual_acceptance_matrix.md). **Estado inicial:** F01–F15, A01–A10 = **PENDING**. **No ejecutar este documento como un test automático** ni marcar PASS sin que una persona haya inspeccionado Godot.

## 1. Inventario seguro y solo lectura

En una terminal Fedora, situarse en el directorio real del checkout de Flujo elegido por el mantenedor (no se asume una ruta concreta) y ejecutar:

```bash
pwd
git rev-parse --show-toplevel
git branch --show-current
git rev-parse HEAD
git status --short
git diff --check
git log -1 --oneline --decorate
git worktree list
```

**Puerta:** la rama debe ser la de Potok y el estado local no debe contener cambios de otro trabajo que pudieran quedar mezclados. `git status --short` con entradas no es automáticamente un fallo: identificar qué está protegido, sin hacer stash/reset/clean/checkout automático. Si la rama local está desactualizada, **no ejecutar pull/reset** antes de revisar los cambios con el mantenedor. Registrar el SHA usado en cada captura; no afirmar que es idéntico a GitHub sin compararlo.

## 2. Godot 4.7.2, sin tocar archivos originales

Verificar el ejecutor según `AGENTS.md`:

```bash
command -v godot
godot --version
```

Si no hay binario nativo válido, usar **solo uno** de los comandos siguientes según el entorno real:

```bash
flatpak-spawn --host flatpak run org.godotengine.Godot --version
# o, fuera del sandbox de VS Code:
flatpak run org.godotengine.Godot --version
```

**Puerta:** salida de versión 4.7.2 estable (o variante compatible que el contrato acepte explícitamente). Si no se puede comprobar la versión, registrar BLOCKED: no inventar ejecutables o rutas. Abrir el proyecto que corresponde al mismo checkout, inspeccionar errores del editor y usar una **copia de escena de prueba** o un proyecto temporal, nunca `demo/main.tscn` ni trabajo del usuario. Las fixtures headless bajo `tests/editor/` no equivalen a escenas finales listas para interacción; crear una escena de pruebas desde el editor y guardar fuera de las escenas protegidas.

## 3. Primera tanda presencial — F01 a F05

| Caso | Acciones manuales observables | Evidencia necesaria | Estado inicial |
| --- | --- | --- | --- |
| **F01** | En Godot Inspector seleccionar un `PVController` con `FlowGraph` y una máquina de estado existente; abrir Fluo desde la fila de máquina con Enter y doble clic (cada variante por separado) | Capturas de Inspector antes y Fluo abierto; comprobar una sola superficie Flow, no una lista Blocks duplicada | PENDING |
| **F02** | Con una máquina de al menos dos estados, seleccionar alternativamente estado A y B y regresar a A | Capturas de Enter/Update/Exit en ambos estados, IDs de estado si están disponibles; no mezclar bloques | PENDING |
| **F03** | Usar una escena de prueba que tenga `null` deliberado en Enter junto con un bloque real | Captura del renglón `Empty` deshabilitado, y la lista antes/después de cambiar de estado; no desplazar el bloque | PENDING |
| **F04** | Desde Enter, pulsar `Add Print`; observar la fila seleccionada y el foco real de teclado | Captura de la nueva fila, selección y foco visible; único bloque creado por acción | PENDING |
| **F05** | Activar el Print con Enter y doble clic, cerrar Flusso y repetir | Capturas del panel de propiedad `text`, cierre y recuperación de selección/foco en el mismo bloque | PENDING |

Registrar cada ejecución con el formato de la matriz madre. **No registrar PASS** si la prueba solo se vio mediante CI o si faltaron los controles exigidos. Si falla, anotar el texto exacto del error y guardar pasos mínimos de reproducción antes de cualquier corrección.

## 4. Plantilla de lote y retorno

```text
Potok 7F-2A — Fedora
SHA local:
Rama:
Estado git antes:
Ejecutor/version Godot:
Escena de prueba (copia):
F01: PASS / FAIL / BLOCKED / NOT RUN — evidencia:
F02: PASS / FAIL / BLOCKED / NOT RUN — evidencia:
F03: PASS / FAIL / BLOCKED / NOT RUN — evidencia:
F04: PASS / FAIL / BLOCKED / NOT RUN — evidencia:
F05: PASS / FAIL / BLOCKED / NOT RUN — evidencia:
Logs/diagnósticos, si aparecen:
Estado git después:
```

**Microbloque siguiente:** analizar F01–F05 reales cuando haya evidencias; mientras tanto, el resto de la matriz **F06–F15** y **A01–A10** continúa PENDING. No se solicita ni presupone una aprobación general. No se efectuaron pruebas físicas remotas, ni escrituras al worktree Fedora, ni modificaciones en `main`.

*Todo es Flujo; todo fluye.* 🌊
