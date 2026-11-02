# Potok 7F-1C2E — Cierre de integración estructural y persistencia de escena

**Fecha:** 2026-11-02. **Rama:** `feature/fsm-runtime-flow-flusso`. **Baseline:** `b406c690835aeac054d13d4684cf46f586ece275`, [Actions 41516183343](https://github.com/mercurysama/Flujo/actions/runs/41516183343) SUCCESS. Esta etapa es de pruebas, no añade funciones al runtime, esquema o UI.

## Implementación y evidencia

- `a52e00c7396b964f9338a1f2272c6473c1c83cfb`: test de regresión `tests/editor/flow_fsm_phase_structure_roundtrip_test.gd`, ejecutado con Godot 4.7.2 headless + EditorUndoRedoManager.
- `fd9204edd55a5acba163027597c10793884842fe`: entrada de prueba en `.github/workflows/flujo-fsm.yml`; se conserva todo el catálogo de tests precedentes.
- [Actions 41517598801](https://github.com/mercurysama/Flujo/actions/runs/41517598801): ejecución que debe confirmar el cierre GREEN completo. La prueba focal de persistencia pasó; consultar conclusión y conteo final para registrar suite total.

## Cobertura

El test crea un grafo esquema 3 con máquina, estado principal y hermano, slots `null` en Enter, bloque integrado Update, bloque externo del SDK en Exit y Ready independiente. Ejecuta mediante comandos de producción: Move de Enter, Duplicate de Enter con ID nuevo, Delete de un bloque Enter seguido de Undo/Redo; Duplicate de Update; Duplicate, Move y Delete del bloque externo en Exit. Comprueba orden físico, IDs originales y nuevos, propiedades persistentes, aislamiento de hermano y Ready, y `FlowGraphValidator`.

Después empaqueta la escena con `PackedScene.pack`, la guarda en `.godot/flujo_tests/potok_7f1c2e_structure_roundtrip.tscn`, la reabre mediante `ResourceLoader.CACHE_MODE_IGNORE` e instancia el `PVController` persistente. Verifica IDs y orden de todas las fases, huecos nulos, independencia de las copias, script externo y mensaje, estado hermano, Ready y validación del grafo. Limpia archivo temporal.

## Alcance de las cinco subfases

- **7F-1C2A**: Move adyacente, sin traspasar null, UndoRedo.
- **7F-1C2B**: Duplicate con ID distinto, deep copy de FlowBlock, script SDK, UndoRedo.
- **7F-1C2C**: Delete exacto, UndoRedo con referencia/ID original.
- **7F-1C2D**: botones nativos en Fluo, confirmación y Escape/Cancelar, selección y foco por ID.
- **7F-1C2E**: test real de persistencia tras operaciones múltiples y regresión histórica.

**No constituye aceptación visual:** siguen pendientes las **15 pruebas Fedora y 10 Android**. La cobertura de paquetes externos no es universal ni supone soporte visual completo para `FlowStructuredDocument`. No se ejecutó auditoría local de worktree Fedora ni hubo cambios a `main`. El siguiente bloque es **7F-1D**, recorrido funcional consolidado; después **7F-2**, aceptación visual y pruebas físicas.

*Todo es Flujo; todo fluye.* 🌊
