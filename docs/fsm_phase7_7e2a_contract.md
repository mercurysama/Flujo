# Potok 7E-2A — Keyboard state/machine navigation and focus ownership

**Date:** 2026-11-01 local / 2026-11-02 UTC. **Branch:** `feature/fsm-runtime-flow-flusso`. **Baseline:** `c89d6d44fac1dd43ed09213b788c4295ce0ef162` and [CI 41394826608](https://github.com/mercurysama/Flujo/actions/runs/41394826608), SUCCESS (49 steps).

## Narrow scope and prior behavior

Original phase-7 keyboard/focus item 7, within the existing Inspector → Fluo → Flow FSM view. 7B already established native Inspector ItemList Enter/double-click activation, stable-ID state rows, Up/Down ItemList selection signal, Ctrl+PageUp/PageDown state movement, plain PageUp/PageDown machine movement with Inspector synchronization, and Escape return to Inspector. 7E-2A strengthens **keyboard routing/focus characterization** and repeatability; does not redefine established shortcut mappings.

Protect and distinguish: Inspector machine stable ID and selection, Potok Flow state stable ID/focus, Flusso controls, and the untouched persistent `FlowGraph`. Duplicate visible state names are valid: selection follows internal IDs, not labels or row indexes.

## Automated acceptance

1. Use actual editor `FluoDrawer` + its `FlowGraphInspectorProperty` for a valid schema-3 controller with two machines, one with three states including two with identical display names, one with an empty state list. Assert initial Flow `PotokStateList` receives keyboard focus after opening and its selected row corresponds to the stable state ID.
2. Drive the existing Potok state ItemList **native selection signal** (used by Up/Down) and keyboard `FluoDrawer._input` routing for Ctrl+PageUp/PageDown; verify circular order, stable IDs, actual Flow focus restoration after rebuilding, no machine selection change, and no transition/graph mutation. After external authored array reorder + refresh, selected ID still maps to the correct row. Native physical Up/Down input delivery still needs desktop manual acceptance; emitting the public selection signal alone is not physical-key proof.
3. When Flow is focused, plain PageUp/PageDown traverses authored machines by ID and emits `schema_3_container_navigation_changed` for Inspector synchronization; Empty draft does not create states; the Flow entry list regains focus after view rebuild. Machine selection excludes sibling Ready process routes.
4. When a Flusso Potok LineEdit has text focus, **plain** PageUp/PageDown must not switch machines; **Ctrl+PageUp/PageDown** still navigates states and restores Flow focus. Unsupported Ctrl+Alt+PageUp/PageDown must not navigate states or machines. When a foreign editor control outside Fluo owns focus, plain/Ctrl Page events routed to Fluo must not steal foreign focus or change FSM selection.
5. Existing Inspector activation relay and Escape semantics remain unmodified; especially, do **not** introduce a global Escape focus guard, which would invalidate previously accepted Fluo overlay behavior. Test and document these boundaries separately from 7E-2B Escape/Revertir/Alt traversal, 7E-2C Undo/Redo selection recovery, or human UI review.
6. Run one `--headless --editor --path . --script` focal in Godot 4.7.2, plus all configured FSM/model/Ready/navigation/catalog/editor regressions and latest-commit whitespace gate in `.github/workflows/flujo-fsm.yml`.

## Safety/authorization

Start with a test-only characterization; modify existing editor code **only if a demonstrated failing focal reveals a real bug within this approved routing boundary**, in a separate small commit, without weakening assertions. Do not change runtime, schema, persistent model, F4, dock or Android packaging, `main`, `demo/main.tscn`, or previous tests. Human desktop keyboard and Android remain pending.

## Skills and evidence

Read `tools/agent_skills/flujo-baseline/SKILL.md`, `tools/agent_skills/flujo-prove/SKILL.md`, `tools/agent_skills/flujo-fluo-maintenance/SKILL.md`, `AGENTS.md`, Constitution, workflow, `docs/current_iteration.md`, `docs/project_memory.md`, `docs/fluo_preview_01.md`, 7B contract and behavior catalog. Relevant entries: `FLUJO-BHV-FOCUS-001`, `FLUJO-BHV-FLUO-NAV-001`, `FLUJO-BHV-FLUO-OPEN-001`, `FLUJO-BHV-FLUO-EDIT-001`; the prior headless 7B and Fluo focals pass on CI 41394826608. No GitHub connector action directly invokes repository-local agent Skills or audits user's Fedora Git worktree, so formal Skill outcomes `READY` and `PASA` are not claimed.

**Next:** 7E-2B Flusso focus/Revertir/Escape after green focused CI. Record actual constraints and manual acceptance gaps.

Todo es Flujo; todo fluye. 🌊
