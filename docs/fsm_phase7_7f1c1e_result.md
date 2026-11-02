# Potok 7F-1C1E — Integración SDK y escena editable

**Fecha:** 2026-11-02. **Rama:** `feature/fsm-runtime-flow-flusso`. **Ámbito:** cierre de regresión automatizada para Flusso de bloques en fase (7F-1C1), no aceptación visual.

## Base y microcommits

- Base `be5b736cf87ae181651febad9e3a354116c081aa` validada por [Actions 41492174870](https://github.com/mercurysama/Flujo/actions/runs/41492174870), SUCCESS.
- Test focal `d4bcca55053ea30ff196be2b3d8ed97a86ec33f1`: `tests/editor/flow_fsm_phase_sdk_roundtrip_test.gd`.
- CI `048ef4f728a8c6c9190c7b2a02f3584b0d458244` incorpora test con timeout 110 s y conserva todos los test anteriores.
- Ampliación focal `e4dded207ab8a5a54b4ed3555f646e89a1be443f`: captura y reversión de sesión SDK y campos no elegibles.
- Ejecución final exigida: [Actions 41495516898](https://github.com/mercurysama/Flujo/actions/runs/41495516898). Confirmar conclusión y número de pasos desde GitHub antes de marcar el checkpoint técnico como GREEN.

## Evidencia focal

El test utiliza el catálogo de autoría de `tests/fixtures/property_descriptors` con el SDK externo real `manual_output:output` y sus metadatos. Crea un bloque externo en `state.enter_blocks`, junto a un hueco `null`; mantiene un bloque integrado en `blocks` (Update), otro en `exit_blocks` y un proceso Ready independiente. Abre Inspector → Fluo → Enter → Flusso del bloque por el `ItemList` nativo.

Comprueba los controles `message` multiline, `boolean_value`, `ranged_int` y `enum_value`, edita los cuatro por UI, comprueba cambios directos y UndoRedo del enum. Valida que `unsupported_vector` y `storage_only` no se muestren como propiedades authorables. La sesión `Revertir` restaura los valores de apertura con una acción UndoRedo; Undo de Revertir restaura lo editado. Verifica preservación de ID estable, fases hermanas, null, proceso Ready y ausencia de errores de validador. Empaqueta y guarda escena a `.godot/flujo_tests/potok_7f1c1e_sdk_roundtrip.tscn`, reabre por `ResourceLoader.CACHE_MODE_IGNORE` y comprueba los valores SDK, IDs y arrays de fase. Limpia archivo temporal.

## Alcance aprobado y deuda

- Fase 7F-1C1A: contrato contextual.
- 7F-1C1B: activación mediante Enter/doble clic; selección simple mantiene Flusso cerrado.
- 7F-1C1C: propiedades escalares tipadas, recurso fase-exacto, UndoRedo.
- 7F-1C1D: sesión, Revertir, Escape, foco en ID.
- 7F-1C1E: auditoría focal con SDK real y scene roundtrip integrada a la regresión.

La cobertura **no** equivale a todos los tipos de paquete externo; los controles de `FlowStructuredDocument` todavía carecen de implementación en fase y la validación de interacción física en Fedora y Android permanece pendiente: 15 + 10 = 25 casos humanos **PENDING**. No se modificó `main`, el runtime, el esquema persistente ni se ejecutaron autonomamente Skills remotas. El CI demuestra ejecución remota, no auditoría del worktree Fedora.

**Siguiente microbloque:** 7F-1C2A, contrato y caracterización test-first para Move/Duplicate/Delete dentro de una fase, antes de 7F-1C2B/C. Mantener granularidad, IDs estables, `null` y fases estrictas.

*Todo es Flujo; todo fluye.* 🌊
