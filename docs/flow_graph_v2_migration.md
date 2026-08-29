# FlowGraph Schema 2 Migration Contract

## Scope

- Schema 1 uses only `FlowGraph.containers` as its source of truth.
- Schema 2 will use only `processes`, `variables`, and `state_machines` as its source of truth.
- This document defines planned behavior only. It does not implement migration, runtime changes, UI, or Inspector support.

## Ownership and Validation

- A persistent resource may belong to only one position in the model tree.
- A repeated resource instance is a validation error.
- Two resources with the same internal ID are a validation error.
- `owner_container_id` may reference only a `FlowProcess` or `FlowStateDefinition` that belongs to the same `FlowGraph`.
- `global_variable_id` may reference only a `GLOBAL` variable that belongs to the same `FlowGraph`.
- Missing reference targets are preserved rather than silently cleared and produce a diagnostic.

## Atomic Migration from Schema 1

- Migration from schema 1 to schema 2 must be atomic and must not modify the original graph if it fails.
- `FlowProcess` resources migrate to `processes` while preserving their IDs, order, and indexes. Positions not containing processes are represented by `null`.
- Independent `FlowStateDefinition` resources move into a state machine named `Migrated States` while preserving their IDs, order, and indexes. Positions not containing states are represented by `null`.
- If exactly one migrated state has `is_initial`, that state becomes the initial state.
- If no migrated state has `is_initial`, the first non-null state becomes the initial state.
- If multiple migrated states have `is_initial`, migration fails with a diagnostic.
- An unknown type derived from `FlowBlockContainer` causes migration to fail without modifying the original graph.
- After a successful migration, `containers` is empty and `schema_version` is 2.
- The state machine created during migration receives a new internal ID. All other valid internal IDs are preserved.

## Schema 2 Duplication

- Duplicating a schema 2 graph creates new internal IDs and remaps references through one unambiguous `old-ID → new-ID` map.

## Deferred Work

- Migration implementation is deferred.
- Runtime changes are deferred.
- UI and Inspector changes are deferred.
