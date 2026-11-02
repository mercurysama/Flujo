# Potok 7E-3A — Fluo native overflow, scrolling and editor resize

**Date:** 2026-11-02. **Branch:** `feature/fsm-runtime-flow-flusso`. **Baseline HEAD:** `78c05ff915cb93246227922a731481247137338a`; [GitHub Actions 41400006665](https://github.com/mercurysama/Flujo/actions/runs/41400006665) SUCCESS (57 steps).

## Existing context and boundary

`FluoDrawer` already owns the **single** `FluoEditorScroll` with native vertical scrolling, `follow_focus=true`, clipping and an existing `FluoEditorScrollContent` containing one `FlowGraphInspectorProperty`. Its horizontal mode is DISABLED. The drawer shell is 46% of its host width and has a distinct two-side placement contract, which **must not change in this lot**. The old per-row Flow lists are Godot native ItemLists, not separate competing scroll panels.

## Accepted 7E-3A measurable behavior

1. Use the **real** editor-only `FluoDrawer` and schema-3 Potok Flow/Flusso with 25 authored states, selected state with many actual transitions, long authored names/notes and actual machine/state/transition Revertir controls; no duplicate Inspector list or ad-hoc substitute editor.
2. Under a measurable wide viewport (1200×800) and a portrait-like narrow viewport (480×640), `FluoEditorScroll` remains within the Drawer panel (no negative size), clips content, owns a native vertical and horizontal scrollbar, and allows all overflowing content to be traversed; reaching the final transition control is possible. Horizontal scrolling must be **AUTO** (not permanently visible) so it only appears when actual content requires it. Vertical scrolling remains AUTO and continues to work. Do not force truncation/data loss to mask overflow.
3. On an actual narrow long-content case, the scrollbar must report an overflowing range and allow nonzero horizontal scroll, with native `scroll_horizontal` changing content position. Native vertical scroll must also have range and scroll to the bottom. Focusing the final actual `PotokTransitionRevert` when above the fold must bring it into view under existing `follow_focus` behavior. Reaching it must not mutate model values or IDs.
4. Resizing the host between desktop and portrait dimensions and toggling left/right must recompute `DrawerMotionShell`, `DrawerPanel`, `FluoEditorScroll` geometry/ranges without leaking old dimensions or creating duplicate controls; the same selected machine/state/edge and authored graph remain unchanged. The panel and clipping area stay finite, positive and bounded to shell. Keep existing offset-transform neutral, single drawer tree and 44×44 close button regression.
5. Headless geometry and scrollbar assertions are **engineering evidence, not visual human sign-off**. Do not claim actual Android touch/drag, responsive aesthetics, OS input method or keyboard review. Those belong to 7E-4.

## Scope / exact workflow

- Test-first characterization `tests/editor/flow_fsm_fluo_scroll_resize_test.gd`; wire one Godot 4.7.2 `--headless --editor --path . --script` focal into `.github/workflows/flujo-fsm.yml` without weakening previous 57 steps.
- Fix an evidenced overflow defect in **`addons/vp_flujo/editor/fluo_drawer.gd` only** unless the focal proves an unavoidable editor-child change. Preserve current side placement policy, ratio, keyboard/Alt/Escape/Revertir, runtime and persistent schemas. Never add duplicate Inspector Blocks list.
- Record red and green CI evidence, all prior Fluo/Ready/FSM regressions, whitespace/catalog gates, and recovery SHA in a result note and roadmap. Physical desktop and Android inspection remains PENDING.

## Skills and governance

Read `tools/agent_skills/flujo-baseline/SKILL.md`, `flujo-prove/SKILL.md`, `flujo-fluo-maintenance/SKILL.md`, `AGENTS.md`, Constitution, current iteration, development workflow, project memory, Fluo preview, phase-7 roadmap, 7E-2C result and `docs/behavior_catalog.json`. Adjacent IDs: `FLUJO-BHV-FLUO-DRAWER-001`, `FLUJO-BHV-FLUO-OFFSET-001`, `FLUJO-BHV-FLUO-NAV-001`, `FLUJO-BHV-FOCUS-001`. Baseline [CI 41400006665](https://github.com/mercurysama/Flujo/actions/runs/41400006665) finished successfully. GitHub connector does not invoke standalone local Skills or inspect the user's Fedora index/worktree: formal READY/PASA **not** claimed. Do not change `main`, `demo/main.tscn`, schemas or runtime, or release. Human approval remains pending.

**Next:** 7E-3B drawer close, host/controller context restoration. Then 7E-4 desktop/Android matrix and end-to-end phase-block Add journey gap audit.

Todo es Flujo; todo fluye. 🌊
