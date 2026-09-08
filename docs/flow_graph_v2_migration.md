# FlowGraph Schema 2 Migration Contract

## Status and scope

Schema 1 uses only `FlowGraph.containers` as its source of truth. Schema 2 uses only `processes`, `variables`, and `state_machines` as its source of truth.

`FlowGraphMigrator.migrate_schema_1_to_2()` is implemented. This document records its contract and the remaining deferred work; it does not define runtime execution or future schema 3 behavior.

## Ownership and validation

- A persistent resource may belong to only one position in the model tree.
- A repeated resource instance is a validation error.
- Two resources with the same internal ID are a validation error.
- `owner_container_id` may reference only a `FlowProcess` or `FlowStateDefinition` that belongs to the same `FlowGraph`.
- `global_variable_id` may reference only a `GLOBAL` variable that belongs to the same `FlowGraph`.
- Missing reference targets are preserved rather than silently cleared and produce a diagnostic.
- Schema 1 rejects any non-empty schema 2 collection, and schema 2 rejects a non-empty `containers` collection, even when the incompatible collection contains only `null` positions.

## Atomic migration from schema 1

- Migration from schema 1 to schema 2 is atomic and does not modify the original graph if it fails.
- The migrator validates the source before constructing a candidate and validates the candidate before returning success.
- `FlowProcess` resources migrate to `processes` while preserving their IDs, order, and indexes. Positions not containing processes are represented by `null`.
- Independent `FlowStateDefinition` resources move into a state machine named `Migrated States` while preserving their IDs, order, and indexes. Positions not containing states are represented by `null`.
- If exactly one migrated state has `is_initial`, that state becomes the initial state.
- If no migrated state has `is_initial`, the first non-null state becomes the initial state.
- If multiple migrated states have `is_initial`, migration fails with a diagnostic.
- An unknown type derived from `FlowBlockContainer` causes migration to fail without modifying the original graph.
- After a successful migration, `containers` is empty and `schema_version` is 2.
- The state machine created during migration receives a new internal ID. All other valid internal IDs are preserved.

## Schema 2 duplication

- Duplicating a validated schema 2 graph creates new internal IDs and remaps references through one unambiguous `old-ID → new-ID` map.

## Deferred work

- Runtime execution remains deferred.
- Future schema evolution is defined separately by the [Constructor and Methods contract](constructor_methods_contract.md).
