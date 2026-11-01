# FSM preflight — build blocker on inherited branch

**Date:** 2026-11-01  
**Branch:** `feature/fsm-runtime-flow-flusso`  
**Baseline run:** [GitHub Actions #41333387600](https://github.com/mercurysama/Flujo/actions/runs/41333387600)  
**Before correction:** editor headless load PASS (exit 0), behavior catalog validator PASS (exit 0), model mist FAIL (exit 1); subsequent Ready/navigation checks SKIPPED.

## Finding

`FlowResourceRefValueSource` extends `Resource` and declared a new serialized `resource_path`, conflicting with Godot's inherited native `Resource.resource_path`. Godot 4.7.2 reported a redefinition parse error, followed by dependent-script compile failures. This is an inherited issue independent of the new FSM plan.

## Smallest correction

Rename the authored ResourceRef target field to `referenced_path` in the concrete model source and its generic editor/chip projections. Keep the target path, type hint, validation, resolution and UI semantics. The rename is deliberately confined to the four affected files and must receive model/complex-value regression evidence.

**Compatibility note:** historical serialized `resource_path` values (if any exist from an alternate Godot editor) are not migrated by this patch. Do not silently claim lossless migration. An explicit data migration must be approved if real legacy serialized files are found.

## Testing record

Baseline run #41333387600 is **FAIL** and remains a historical FAIL. A subsequent CI run must establish a new baseline; never retroactively mark the old run as passing. If the model mist still fails, investigate each remaining failure separately before FSM model integration.

Todo es Flujo; todo fluye. 🌊
