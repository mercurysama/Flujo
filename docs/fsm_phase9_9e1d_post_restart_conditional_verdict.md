# Potok 9E1-D — Dictamen posterior al PASS de reinicio entre procesos

**Fecha:** 2026-11-03. **Rama:** `feature/fsm-runtime-flow-flusso`. **Referencia funcional:** `eaa95cb9239fd37bb3a69d07298e5684dc7688c1`, [Actions 41722469207](https://github.com/mercurysama/Flujo/actions/runs/41722469207) **SUCCESS**. Documento de evidencia: [9R1-B](fsm_phase9_9r1b_two_process_restart_closeout.md).

## Decisión documentada

**9R1-A y 9R1-B: PASS automatizado y cierre documental.** El requisito de demostrar que un archivo `user://` sobrevive a terminar una ejecución de Godot y puede restaurarse explícitamente en una nueva ejecución ya está cubierto, con dos procesos OS independientes y configuración de IDs authored idéntica en la fixture. A guardó y B restauró el alias y payload `PERSISTENT`; no se regeneraron aliases transitorios ni se cargó automáticamente el snapshot. El paso CI específico y el job integral finalizaron `success`.

**Fase 9 / FSM-004: aceptación técnica todavía CONDICIONADA.** Este nuevo PASS cierra la brecha R1 de reinicio por procesos descrita en [9E1-A](fsm_phase9_9e1a_conditional_verdict.md) y [9E1-B](fsm_phase9_9e1b_restart_acceptance_protocol.md), pero no valida durabilidad de almacenamiento bajo fallos ni plataformas reales.

## Condiciones abiertas

- **F5–F7/F7R:** interrupciones y fallos exactos de backup, copia y rename; sin inyección de fallos en estos puntos, no dar por probado el rollback del último respaldo válido. Requiere contrato y autorización específica antes de intervenir en producción o añadir un seam de I/O.
- **F9:** política de destino previo corrupto sin aprobación. No sobrescribir ni reinterpretar respaldos automáticamente.
- **F10:** la restauración desde `.bak` no es automática por contrato v1; no introducir autoload ni recovery implícito sin aprobación.
- **Revisión humana:** 0/25 pruebas de fase 7, 15 Fedora y 10 Android, diferidas. Sin prueba física de reinicio del dispositivo, fallos de energía o almacenamiento Android.
- **Integración:** sin merge a `main`, publicación, prueba local Flatpak ni invocación formal de Skills `$flujo-baseline`/`$flujo-prove` en este cierre remoto.

## Siguiente decisión

Continuar con **9R2** solamente si el mantenedor aprueba la política F5/F7/F9 y el alcance de pruebas de fallos; hasta entonces, conservar los gates como **NOT RUN** y permitir planificación independiente de fase 10 con la deuda visible. Los pasos ya funcionales se preservan sin reimplementación. El catálogo marca `FLUJO-BHV-POTOK-SNAPSHOT-TWO-PROCESS-020` como `passing` únicamente por evidencia de ejecución, no por la existencia del test.

*Todo es Flujo; todo fluye.* 🌊
