# Iteration 6 — Closeout and Postmortem

## References and verified dates

- Integration PR: [#8](https://github.com/mercurysama/Flujo/pull/8).
- Iteration branch head: `0f529d054f51ca681fe141e80f2dc113e121b4f2` (`chore: remove obsolete manual test scripts`).
- Integration commit: `06d759cf3c53bae95fbf2c022873cbef4d7db94e` (`Merge pull request #8 from mercurysama/feature/iteracion-06-constructor-metodos`).
- **Start:** 2026-09-02T00:25:46-06:00 — `5e0076531c1f44680845e7d742c6d2e996682469`, the first reachable commit after the merge-base with Iteration 5, `1bd134efaf6039a24d4ad325aaa2cec0c207690a`.
- **Branch close:** 2026-09-07T21:35:46-06:00 — `0f529d054f51ca681fe141e80f2dc113e121b4f2`.
- **Integration:** 2026-09-07T22:01:55-06:00 — `06d759cf3c53bae95fbf2c022873cbef4d7db94e`.

These are Git-recorded repository events. Iteration 6 is not a published stable release, so no Release Chronicle or publication date is recorded here.

## Initial objectives and delivered scope

Iteration 6 set out to establish reusable structural definitions without adding runtime execution or schema 3 authoring UI. It delivered:

- Schema 3 as a deterministic persistent structure, while retaining schema 1 and schema 2 as explicit, incompatible source representations.
- `FlowConstructorDefinition` as a specialized `FlowBlockContainer`, with inherited ordered nullable blocks and ordered nullable `FlowDependencyDefinition` resources.
- Reusable `FlowMethodDefinition` resources, typed `FlowMethodParameterDefinition` declarations, and one optional typed `FlowMethodReturnDefinition` per method.
- Atomic schema 2 → 3 migration that validates its source before construction, deep-copies existing schema 2 definitions, preserves valid IDs, references, order, and `null` positions, and creates one empty constructor and an empty methods collection.
- Persistent `FlowMethodCallBlock` references by stable `method_id`, valid in schema 3 constructor, method, process, and state block collections.
- Canonical 32-character hexadecimal ID validation through `FlowId.is_valid()`, deterministic diagnostics, graph-wide identity checks, and deep duplication using one old-ID → new-ID map.
- ResourceSaver and PackedScene persistence coverage for schema 3 definitions, method calls, and optional return declarations.

The schema 2 Inspector was also stabilized late in the iteration: lists reserve five theme-sized rows and scroll from the sixth; rebuilding is deferred and coalesced; selection, Rename, Delete, Move, Undo/Redo, automatic `Flujo` names, and scene-local undo history are covered. Explicit Delete removes the selected entry by stable ID while preserving unrelated deliberate `null` positions.

## Technical decisions and outcomes

### Model, migration, validation, and duplication

Schema 3 extends rather than synchronizes schema 2 collections. This retained one source of truth per schema and avoided implicit conversion or hidden compatibility paths. The atomic 2 → 3 migration was chosen over in-place mutation so a rejected source or candidate cannot corrupt the original graph.

Methods, parameters, return declarations, dependencies, blocks, and calls participate in deterministic identity validation. `FlowMethodCallBlock` stores only `method_id`; names, indexes, direct method resources, nodes, paths, and callables were rejected as identities. `FlowMethodReturnDefinition` reuses `FlowVariableDefinition.ValueType` rather than introducing a second type taxonomy. Duplication reserves identities before reference remapping, which makes valid internal remapping independent of traversal order while leaving unknown, malformed, empty, or ambiguous values unchanged for diagnostics.

Alternatives rejected included parallel constructor block storage, name- or index-based references, in-place migration, an independent return-type enum, and eager repair of invalid IDs. Each would either create a second source of truth, break stable references, weaken diagnostic evidence, or mutate authored invalid data.

### Inspector stabilization

The Inspector work remained limited to schema 2 collections. The fix retained `ItemList` scrolling rather than growing the Inspector indefinitely, derives row height from Godot theme metrics rather than fixed pixels, and exposes only visible names or `Empty`, never internal IDs in row labels or tooltips.

Selection now requests a deferred rebuild instead of rebuilding during the row signal. Deferred layout checks that a list is still valid and inside the tree before measuring it. Rename is scoped by collection and stable ID, opens inside its category, selects existing text, commits on Enter, cancels on Escape, and restores focus to the selected row. All model actions use the edited `PVController` as the `EditorUndoRedoManager` context, so they belong to the edited scene history rather than the Global history and participate in Godot's native dirty-state tracking.

## Problems, causes, and lessons

- **Structural ownership needed to be explicit.** Constructor blocks required inheritance from `FlowBlockContainer`, not a parallel collection. The resulting model keeps inherited identity and block invariants in one place.
- **Isolated method duplication needed a complete inventory first.** Earlier remapping could treat malformed or repeated IDs as map entries. The final policy centralizes validity in `FlowId.is_valid()`, counts owned IDs before reserving them, and preserves invalid or ambiguous values literally.
- **The schema 2 Inspector could mutate data without visible rows.** An `ItemList` with no paintable vertical minimum size hid newly added rows. Theme-derived five-row geometry and a focused visual regression made the expected layout testable.
- **Rebuilding controls during selection created stale-control risk.** A deferred measurement could reach a removed list without a viewport. Coalesced rebuilding and `is_instance_valid()` plus `is_inside_tree()` guards remove that path.
- **Global undo history did not mark the edited scene dirty.** Actions lacked a scene-owned custom context. Passing the actual `PVController` to Godot's undo manager restores scene-local history, native dirty state, and save-point behavior without a parallel flag or automatic save.
- **Manual scripts and scene artifacts obscured repository state.** Obsolete root scripts were removed only after consumer searches, and temporary test scenes remain under the established ignored test directory and are deleted by the tests.

The main lesson is that persistent identity, UI lifetime, and editor history context are separate invariants. Passing model tests alone did not prove their visible or scene-owned behavior; focused editor tests and approved manual review were necessary.

## Verification and review evidence

Automated coverage included `git diff --check`, Godot 4.7.2 headless editor loading, the model smoke test, the editor command regression, and the ResourceSaver/PackedScene persistence regression. The editor regression covers schema migration, Add, Rename, Move, Delete, Undo/Redo, null preservation, row visibility, rapid selection/rebuild behavior, duplicate-control avoidance, automatic names, and a real temporary scene's non-Global undo history and dirty-state transitions.

Manual visual review was approved for schema 2 empty lists, Add in every category, selection, Rename with Enter and Escape, Move and Delete, Undo/Redo, five rows and scrolling, save/reopen, scene dirty indicator, save prompt, and a console without the prior layout or Global-undo symptoms. Headless tests supported but did not replace that review.

Environmental warnings from headless Godot shutdown, including the accepted scan-thread warning and resource/RID cleanup diagnostics, were recorded separately from project assertions. The required tests completed successfully; no project test failure is recorded by the integration evidence.

## Deliberately deferred scope and next-cycle recommendations

Iteration 6 did not implement `FlowMethodArgumentBinding`, value sources, `FlowMethodReturnBlock`, argument or return transport, literals, assignments, implicit conversions, recursion or call-cycle validation, dependency bindings, runtime state, execution, schema 3 Inspector authoring, visual connections, or shortcuts. A return definition is metadata, not runtime return behavior.

The next cycle should first receive an approved numbered plan. Its planning should preserve the existing schema 3 boundaries, decide only the minimum value-source and argument-binding representation required by the contract, and add runtime or visual behavior only after its ownership, persistence, validation, and per-`PVController` state boundaries are specified. Follow-up technical debt includes a reproducible aggregate verification command, CI coverage for the headless checks, and continued multiplatform validation on Fedora and Windows.

## Engineering flow metrics

| Field | Evidence |
| --- | --- |
| Requirement / task | Iteration 6 closeout / documentation handoff |
| Start / completion | 2026-09-02T00:25:46-06:00 / 2026-09-07T22:01:55-06:00 |
| Validated commit / review time | `0f529d054f51ca681fe141e80f2dc113e121b4f2` / not measured |
| Change size | 18 reachable branch commits; 41 files, +3527, -418 from Iteration 5 merge-base to branch head |
| Tests | headless load, model smoke, editor regression, and persistence regression recorded as passed; failed count not measured across the whole iteration |
| First validation / corrections | not measured / not measured from Git history alone |
| Audit findings / later regressions | not measured as aggregate / no later regression recorded before integration |
| Visual review | required and approved |
| Manual interventions / blockers | Fedora Godot executor selection, Inspector visual review, and manual-artifact cleanup are recorded in repository history; durations not measured |
| AI tool or model / source | ChatGPT and Codex as optional assistance / user-provided and system-reported context; model details not measured |
| Voluntary credits | not measured |
| Iteration bottleneck / corrective action | late Inspector geometry, callback lifetime, and scene-history defects / focused regressions and scene-context actions |

Metrics are evidence for improving the workflow, not quotas or individual rankings. ChatGPT and Codex are optional tools; Flujo remains provider-independent and authorized human review retains final authority. Fedora with Godot 4.7.2 is the primary environment, and Windows remains a compatible platform.

Todo es Flujo; todo fluye. 🌊
