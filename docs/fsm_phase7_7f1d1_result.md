# Potok 7F-1D1 — Jornada nativa integrada (Add → Edit → Move → Duplicate → Delete)

**Fecha:** 2026-11-02. **Rama:** `feature/fsm-runtime-flow-flusso`. **Estado:** prueba integrada automatizada, no aceptación visual humana.

## Baseline y microcommits

- Baseline `bbc8d763e8a998b1c38a7763ddc3715ab0e8561e`, [CI 41518184412](https://github.com/mercurysama/Flujo/actions/runs/41518184412) SUCCESS.
- Contrato de recorrido `docs/fsm_phase7_7f1d_contract.md`, commit `e8d163bf78e77e66c6c3123a43284d5ea33cfe2b`.
- Prueba nativa inicial `tests/editor/flow_fsm_phase_user_journey_test.gd` en commit `d92b786160938b556892265f5293f253758a2288`; registro CI `f55cb6b32b74a75d7dbe2beeeb992252ccdc8e47`; versión inicial de Add/Edit/Close/Move pasó focalmente.
- Ampliación `2d3ed5ca3a099726d0451ac8b8c2d30d9a4bc732`: añade Duplicate, Delete con Cancel/Confirm y Undo/Redo; [Actions 41521035360](https://github.com/mercurysama/Flujo/actions/runs/41521035360) falló por **alcance de variable en el propio test**, no por aserción de código productivo.
- Fix mínimo de test `822cf9bae3e824310d964b8b8f41920e98b14215`: declara el bloque `added` antes del contexto condicional para acceder a él al continuar el mismo recorrido.
- **GREEN confirmado:** [Actions 41521212041](https://github.com/mercurysama/Flujo/actions/runs/41521212041), **completed SUCCESS 72/72 pasos, 0 fallos**, sobre commit `822cf9bae3e824310d964b8b8f41920e98b14215`. Incluye el recorrido completo ampliado y regresiones Godot 4.7.2.

## Prueba y comportamiento

La prueba navega con el editor existente hasta Fluo, usa `PotokPhaseEnterAdd0` para agregar `FlowPrintBlock` desde el catálogo, selecciona por ID estable, activa su Flusso y edita texto mediante `TextEdit` nativo. Luego cierra Flusso sin descartar la edición, mueve el bloque adyacente, comprueba el hueco `null`, duplica el bloque editado, comprueba ID nuevo y texto copiado. Finalmente abre Delete; Cancel conserva colección e historial; Confirm elimina solamente la copia, Undo restaura el mismo recurso e ID, Redo restablece el orden. Se preserva Update, y el grafo valida.

Este test **consolida una jornada de usuario**, no reemplaza los tests específicos de SDK, escenas, teclado, foco, Enter/Update/Exit, Ready/Timer/Tok ni el resto del workflow. No se modificaron los comandos de producción ni el esquema.

## Continuidad

A continuación, **7F-1D2**: jornada con SDK externo, contexto obsoleto y controladores distintos; luego 7F-1D3 persistencia y 7F-1D4 auditoría de aceptación. Mantener 15 Fedora + 10 Android = **25 pruebas humanas pendientes**, sin afirmar pruebas físicas ni merge a `main`.

*Todo es Flujo; todo fluye.* 🌊
