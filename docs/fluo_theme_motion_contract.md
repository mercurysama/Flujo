# Fluo Theme + Motion Contract

## Status and scope

This contract defines D2-A of the Flujo block ecosystem roadmap: the minimum Theme + Motion boundary that must exist before external block authoring becomes a stable end-to-end surface.

D2-A is documentation plus baseline verification only. It does not animate Fluo, does not refactor `fluo_drawer.gd`, does not connect external packages to Flow, does not implement generic Flusso, and does not change model, runtime, persistence or schemas.

The functional implementation belongs to D2-B and begins only after the existing Fluo behavior baseline is explicitly verified.

## D2 requirements

### FLUOMOTION-001 — Theme and Motion belong to the Fluo host

Theme, Motion, focus choreography and transition ownership belong to editor-side Fluo components.

A block package may describe data and presentation metadata allowed by later contracts, but it may not install an arbitrary Theme, create its own editor transition controller, or own Fluo focus.

### FLUOMOTION-002 — Model state is independent from presentation state

Motion state is editor-only and ephemeral.

Opening, closing, switching side, focus feedback or visual transitions must not modify:

- FlowGraph data;
- block IDs;
- container IDs;
- Inspector selection identity;
- Flusso session snapshots;
- package metadata;
- runtime execution state.

### FLUOMOTION-003 — Containers own logical layout

Godot `Container` nodes remain authoritative for layout of their child `Control` nodes.

D2 must not animate direct child `position`, offsets or size in a way that depends on surviving a Container relayout.

Logical layout and presentation transforms are separate concerns.

### FLUOMOTION-004 — Motion uses an explicit shell boundary

Any sliding/scaling transition of the complete drawer must act on a shell or wrapper whose movement is not immediately overwritten by a parent Container.

The internal Flow/Flusso content remains managed by Containers and ScrollContainers.

### FLUOMOTION-005 — offset transforms are presentation, not inferred layout

Godot 4.7 `Control.offset_transform_*` may be used for presentation only when its interaction semantics are explicitly tested.

No code may infer hitbox position, focus behavior or scroll behavior solely from the visual transform.

### FLUOMOTION-006 — visual-only transforms require separate input evidence

When `offset_transform_visual_only = true`, the visual transform does not move the input region.

Therefore it is unsuitable for an interactive moving drawer unless input is intentionally blocked/proxied during the transition or the clickable region is otherwise proven aligned.

### FLUOMOTION-007 — non-visual-only transforms require hitbox verification

When `offset_transform_visual_only = false`, input follows the transformed Control.

D2-B must verify actual mouse/touch event reception and not treat `get_global_rect()` alone as sufficient evidence.

### FLUOMOTION-008 — Current Fluo close hierarchy is protected

The existing hierarchy remains:

1. Escape closes Flusso first when open;
2. the next Escape closes Fluo;
3. the top close button closes Fluo;
4. an exterior click closes Fluo and is consumed;
5. valid previous focus may be restored.

Motion must not reorder these semantics.

### FLUOMOTION-009 — Current keyboard navigation is protected

D2 preserves the existing Flow/Flusso/Inspector navigation contract:

- Up/Down: native Flow movement;
- Ctrl+PageUp/PageDown: Flow block navigation;
- PageUp/PageDown: Inspector container navigation;
- Alt+PageUp/PageDown: Flusso control navigation;
- Shift reverses Alt navigation.

A transition must not strand focus on a detached Control.

### FLUOMOTION-010 — Side placement is semantic state, not animation state

Left/right placement remains the drawer's durable editor-side preference/state for the active surface.

Transition progress is separate and never becomes persistent model data.

Switching side must end with the same functional focus/input semantics as opening directly on that side.

### FLUOMOTION-011 — Backdrop remains an input barrier

The backdrop must continue to consume exterior interaction rather than leak clicks/touches to the Godot editor underneath.

Any transition input shield must preserve this invariant.

### FLUOMOTION-012 — Scroll remains native

The Fluo content continues to use native ScrollContainer behavior.

Motion must animate the shell, not manually reposition children owned by `ScrollContainer`.

Long content, mouse wheel and touch pan remain independently testable behaviors.

### FLUOMOTION-013 — Focus is assigned only after usable geometry exists

Opening or rebuilding may not grab focus merely because a visual tween started.

Focus assignment/restoration happens only when the intended target exists, is inside the tree, visible, focusable and belongs to the current semantic context.

### FLUOMOTION-014 — Transition cancellation is deterministic

A transition must be safely cancellable by:

- closing Fluo;
- changing controller/container;
- rebuilding Flow/Flusso;
- switching side;
- plugin teardown.

No tween may retain or invoke a freed Control.

### FLUOMOTION-015 — Minimum transition state machine

The minimum editor-side states are:

- `closed`;
- `opening`;
- `open`;
- `switching_side`;
- `closing`.

The exact class/API is not fixed by D2-A. D2-B may implement the smallest representation that preserves these semantics.

### FLUOMOTION-016 — Reduced-motion boundary exists before polish

The Motion owner must have one policy boundary capable of selecting normal versus reduced motion.

D2 does not require final UX settings or platform integration, but block scripts must never encode their own duration/easing.

### FLUOMOTION-017 — Theme uses semantic roles

The Theme boundary must support semantic roles/states rather than block-specific styling branches.

At minimum the future host must be able to distinguish:

- shell/panel;
- Flow row;
- Flusso field;
- button;
- diagnostic;
- selected;
- focused;
- selected without focus;
- disabled;
- error/warning.

Exact colors, fonts and art direction remain polish.

### FLUOMOTION-018 — Public UI remains compatible with Godot editor theming

Fluo may derive from or adapt the active editor Theme.

D2 must not hard-code a package-owned global Theme or require a specific editor color scheme.

### FLUOMOTION-019 — Existing Preview 1 behavior is baseline evidence

Before D2-B modifies production code, the following existing behavior areas must be freshly baselined:

- `FLUJO-BHV-FLUO-OPEN-001`;
- `FLUJO-BHV-FLUO-EDIT-001`;
- `FLUJO-BHV-FLUO-NAV-001`;
- `FLUJO-BHV-FLUO-DRAWER-001`.

Android load/render evidence remains historical/manual and is not treated as complete interaction evidence.

### FLUOMOTION-020 — D2-B must characterize offset-transform interaction

Before or together with the first production Motion change, D2-B adds focused automated characterization for:

- `offset_transform_enabled`;
- `offset_transform_position`;
- `offset_transform_scale` where used;
- `offset_transform_visual_only`;
- mouse hit location;
- focus ownership;
- `mouse_filter`;
- shell layout under Containers;
- ScrollContainer child layout.

Touch remains manual/device evidence unless Godot's test environment provides a faithful touch path.

### FLUOMOTION-021 — D2-B changes must be behavior-preserving first

The first implementation step extracts/introduces Theme/Motion ownership without intentionally changing the public Preview 1 behavior.

Visible animation may be introduced only after the ownership boundary and tests are stable.

### FLUOMOTION-022 — Final durations and easing are explicitly deferred

D2 does not freeze:

- final duration;
- final easing curve;
- bounce/overshoot;
- shadows;
- opacity choreography;
- decorative microanimations.

Those belong to D8 polish as long as they respect this contract.

## D2-A acceptance

D2-A is accepted when:

1. this numbered contract is present;
2. `current_iteration.md` and `project_memory.md` reference it;
3. the current Fluo focal baselines execute before production changes;
4. the behavior catalog validator passes;
5. model smoke and headless editor load are recorded separately;
6. `demo/main.tscn` remains untouched by D2;
7. no `addons/vp_flujo/` file changes in D2-A;
8. no commit is created without maintainer acceptance.

## D2-B gate

D2-B may begin only after the project workflow explicitly invokes `$flujo-baseline` for the Fluo Theme/Motion scope and returns `READY` or `NEW BEHAVIOR` with the existing affected behavior baselines passing.

D2-B ends only after `$flujo-prove` evaluates the completed change; headless automation does not replace manual visual review.

Everything is Flow; everything flows. 🌊
