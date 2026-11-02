# Potok 7F-1D2A — Jornada SDK externo por tres fases

**Fecha:** 2026-11-02. **Rama:** `feature/fsm-runtime-flow-flusso`. **Baseline:** `0b1aabb9900589ba251fe14d09c10980c18beaed` y [CI 41521795353](https://github.com/mercurysama/Flujo/actions/runs/41521795353) SUCCESS.

## Prueba integrada

- Commit `2be0fc54b092047c221c4c2986dd153ae944a8a3`: `tests/editor/flow_fsm_sdk_three_phase_journey_test.gd`.
- Commit `dd55fce5ba2a419505d8669c8168f7409602c52b`: nueva entrada focal en `.github/workflows/flujo-fsm.yml`.
- **GREEN confirmado:** [Actions 41522433103](https://github.com/mercurysama/Flujo/actions/runs/41522433103), **completed SUCCESS 73/73 pasos, cero fallos**, commit `dd55fce5ba2a419505d8669c8168f7409602c52b`, incluida la prueba focal SDK y regresiones Godot 4.7.2.

## Recorrido

Usa el catálogo de autoría externo `tests/fixtures/property_descriptors`, entrada real `manual_output:output`, sin duplicar el editor. Para Enter, Update y Exit agrega mediante botón nativo, abre el mismo Flusso, edita el descriptor `message` (TextEdit), duplica el bloque desde la fase correspondiente y verifica que ambos recursos tienen IDs distintos pero conservan script SDK y mensaje editado. Comprueba el hueco `null` de Enter. Cambia a otro estado con la lista nativa e invoca un botón antiguo: no se escribe en el nuevo estado ni se agrega acción al UndoRedo. El grafo completo pasa `FlowGraphValidator`.

## Próximos microbloques

**7F-1D2B**: extender protección de callbacks caducos a otro `PVController`, máquina y Flusso (descriptores de sesión, Revertir), además de UndoRedo de propiedades tipadas; test focal y regresión. **7F-1D2C**: cierre de jornada SDK con confirmación Delete, UndoRedo e integridad de script al guardar/recargar, si no queda suficientemente cubierto por 7F-1D3. No afirmar prueba de dispositivos. La matriz humana sigue 15 Fedora + 10 Android **PENDING**, `main` permanece intacta.

*Todo es Flujo; todo fluye.* 🌊
