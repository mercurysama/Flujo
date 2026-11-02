# Potok 7F-1D — Recorrido funcional integral recuperable

**Fecha:** 2026-11-02. **Rama exclusiva:** `feature/fsm-runtime-flow-flusso`. **Baseline:** `bbc8d763e8a998b1c38a7763ddc3715ab0e8561e` y [Actions 41518184412](https://github.com/mercurysama/Flujo/actions/runs/41518184412), SUCCESS. **Este documento es contrato de pruebas, no aceptación humana.**

## Objetivo y límites

Reproducir en Godot 4.7.2 el flujo del usuario **Inspector → Fluo → máquina → estado → Enter/Update/Exit → Add → seleccionar/abrir Flusso → editar → Revertir/Close → Move/Duplicate/Delete con confirmación → Undo/Redo → guardar escena y reabrir**. Usar el mismo `FluoFlowEditor` existente; evitar widgets duplicados, índices persistidos, escrituras fuera de la fase, recursos `null` alterados o historial falso. Conservar Ready, Timer, Tok, SDK externo, schema 3 y todos los tests previos. No tocar `main`, runtime, esquema ni demo.

## Microbloques con puertas verificables

### 7F-1D1 — Jornada nativa del usuario y selección por ID
- Crear prueba editor integrada de navegación de la máquina y selección del estado, añadir bloque nativo desde el catálogo, abrir su Flusso por activación, editar texto, cerrar y recuperar foco en la lista, duplicar y mover con selección estable, borrar con Cancel y Confirm, Undo/Redo. Contemplar huecos `null` y fases hermanas.
- Añadir focal a workflow sin sustituir pruebas previas. Si la ruta existente satisface el contrato: test GREEN sin cambio productivo. Si se detecta defecto, guardarlo como RED, reparar mínimamente y volver a ejecutar.
- Evidencia independiente, SHA y CI; no declarar aprobado sin suite concluida.

### 7F-1D2 — Jornada SDK externo y contexto obsoleto
- Recorrido por las tres fases con paquete externo `manual_output`; validar autoría por catálogo, descriptores tipados, UndoRedo, Revertir, copiado profundo y script. Rechazar callbacks antiguos, cambio de controlador/estado/máquina y controles liberados. Prueba focal independiente y regresión.

### 7F-1D3 — Jornada de persistencia y recuperación
- Encadenar edición real de Flusso + acciones estructurales de UI, UndoRedo y guardado/reapertura mediante PackedScene + CACHE_MODE_IGNORE, IDs y huecos `null`, orden y texto. Integrar con Ready, Timer y Condition Tok si aparecen en el flujo nativo sin añadir soporte fuera de alcance.

### 7F-1D4 — Auditoría de integración y matriz para aceptación
- Validar catálogo `docs/behavior_catalog.json`, contrato de navegación y seguridad, resultados de GitHub Actions, matriz de casos manuales y accesibilidad de teclado/foco; preparar entrega reproducible 7F-2 para Fedora y Android. No fingir aceptación en dispositivos.

## Puertas

CI headless no equivale a interacción visual física ni a una auditoría local de Fedora. La matriz pendiente es **15 casos Fedora + 10 Android**. Las Skills en `tools/agent_skills/` pueden leerse y usarse como checklists de GitHub, sin declarar ejecución autónoma de Fedora. Cualquier falla real obliga a detener aprobación y generar reporte RED con reproducción exacta antes del fix.

**Próximo microbloque después del contrato:** `7F-1D1`, jornada nativa mínima por prueba integrada. Todo es Flujo; todo fluye. 🌊
