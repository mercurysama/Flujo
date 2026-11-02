# Potok 7E-4A — Contrato de revisión humana Fedora/Android

**Fecha:** 2026-11-02. **Rama:** `feature/fsm-runtime-flow-flusso`. **Base:** `a84894c1c9874a32873191fb2b6e690e141c6848`; [CI 41404376030](https://github.com/mercurysama/Flujo/actions/runs/41404376030) **SUCCESS (59/59)**.

## Alcance aprobado

Entregar instrucciones **reproducibles**, con una matriz de resultados PENDING para evaluación **real** de Godot en Fedora y Android (ambas orientaciones), sobre la versión/commit exactos de Potok. Verificar lo que cabe observar con usuario y pantalla: selección en Inspector, aparición única de Fluo, representación de Flow, formularios de Flusso, Add de estados/transiciones/bloques por fase, Condition Tok, teclado, Cancel/Escape, Undo/Redo, Revertir, desplazamientos, foco, cambio de escena/controlador, guardado/reapertura y navegación Ready Process/Timer.

1. Separar **Fedora escritorio** (teclado/ratón, foco, ruta Inspector) de **Android** (toque/doble toque, desplazamiento y orientación vertical/horizontal; solo comprobar teclas si hay teclado físico). Dejar todos los estados **PENDING** hasta ejecutar pruebas en dispositivos reales. No inferir PASS de los tests `--headless`.
2. Incluir prueba obligatoria **de extremo a extremo**: una FSM de un estado y sus fases Enter/Update/Exit con Add de bloques desde UI, seguida de segundo estado, transición válida y guardado/reapertura. Si el control Add no existe, registrar **BLOCKED**; la mera proyección de nombres de fase no equivale a autoría. No modificar un `.tscn` a mano para simular aprobación visual.
3. Cada prueba documenta ID, plataforma, precondiciones, pasos, resultado observable, evidencia a capturar, estado, prioridad y espacio para defectos. Los resultados manuales pueden ser PASS, FAIL, BLOCKED, N/A justificado o PENDING. Registrar SHA, versión Godot, SO, orientación/resolución, fecha, persona que observó y enlace a evidencia antes de PASA.
4. Distinguir hitos históricos `docs/fluo_preview_01.md`: carga/render Android del 2026-10-27 **no** avala Potok 7E ni la matriz de interacción/touch. Tampoco corresponde aprobar dispositivos con pruebas headless de 7E-3A.
5. No crear releases/pre-releases ni modificar esquema, runtime, editor, tests, catálogo o `main`. Entregar solo documentación con hoja de recuperación y próximos pasos 7E-4B, respetando las aprobaciones explícitas.
6. Comprobar que el único cambio es documental y que el trabajo final tiene CI en la rama; no afirmar revisión visual sin capturas/observaciones.

**Skill/procedimiento:** `AGENTS.md`, Constitución, iteración, workflow, catálogo `FLUJO-BHV-FLUO-OPEN-001/EDIT-001/NAV-001/DRAWER-001`, `FLUJO-BHV-FOCUS-001`, `FLUJO-BHV-FLUO-ANDROID-001`, `docs/fluo_preview_01.md`, y los procedimientos versionados `$flujo-baseline`, `$flujo-prove`, `$flujo-fluo-maintenance`. La conexión GitHub no permite inspeccionar worktree Fedora ni invocar esas Skills locales; **READY/PASA formal no reclamado**.

**Éxito 7E-4A:** guía versionada, todos los renglones manuales honestamente PENDING, enlaces/evidencia exigidos y tarea de aceptación futura bien delimitada. **No equivale al cierre de la fase 7.**

Todo es Flujo; todo fluye. 🌊
