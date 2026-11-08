# PixNido Panel Lab — EXP-01 / EXP-02

**Branch:** `experiment/pixnido-servo-dock`
**Status:** EXP-01 / EXP-02 code prepared; Godot 4.7.2 execution and visual approval pending.
**Isolation:** independent editor plugin at `addons/pixnido_panel_lab/`; no changes to `addons/vp_flujo/`, its runtime, F4 shortcut, or persistent model.

## Approved interaction contract

- PNL-01: PixNido and References are independent editor panels.
- PNL-02: PixNido is open by default; References is closed by default.
- PNL-03: Three icon-only editor toolbar buttons: PixNido toggle, swap sides, References toggle.
- PNL-04: Each panel has its own close button. References has a `+` button.
- PNL-05: Swapping reverses initial left/right slots without destroying either panel instance.
- PNL-06: References may be used even when PixNido is closed.
- PNL-07: Target widths are PixNido 1/3 and References 2/3 of the available horizontal space, **including when one is hidden**; unused space remains available to Godot.
- PNL-08 (EXP-02 code prepared): keyboard shortcuts, animated inner-panel content, and per-project editor layout persistence.
- PNL-09 (future): freely movable/resizable reference images, per-project storage and controls on selection.
- PNL-10 (future): HTML5 PixNido via a compatible WebView/Servo extension; avoid modifying PixNido's source app.
- PNL-11 (future): sprite export to project paths, default `res://assets/sprites/`, via a vetted JS-to-GDScript bridge.

## EXP-01 implementation

This step implements PNL-01 through PNL-06 as an **editor dock shell**. The `+` is deliberately disabled until image ingestion exists, preventing a misleading no-op action. Only one plugin is added; it registers two `EditorDock` instances and a minimal icon-only `CONTAINER_TOOLBAR` control. Re-registering the docks is used to swap default left/right slots; on that action Godot may reset manual placement.

**Important limitation (PNL-07):** `EditorDock` exposes dock positions but **not a guaranteed fractional editor width**. This step sets modest minimum sizes; it does *not* assert exact 1:2 sizing, horizontal adjacency, or slide animations. A controlled host-layout strategy must be validated before marking PNL-07 complete. The center editor remains a real Godot workspace, not a simulated empty panel.

## Manual acceptance checklist (Godot 4.7.2, Fedora; repeat on Android editor)

- [ ] Enable/open this experimental branch: Flujo's original dock still behaves normally, including F4.
- [ ] PixNido opens on the left, References starts hidden, and the global three-icon toolbar appears.
- [ ] Toggle either dock independently and close either via its own X.
- [ ] Show only References; PixNido remains closed.
- [ ] Swap sides with both open, then with only one open. Both panels retain their placeholder contents.
- [ ] Verify `+` is visible and disabled; no file dialog or fake reference is created.
- [ ] Check compact editor layout, tooltips and keyboard focus.
- [ ] Disable the test plugin; its docks and toolbar are fully removed.
- [ ] Check editor restart and reopen; EXP-02 should restore visibility and swapped sides.
- [ ] Capture editor load, existing model smoke test, and any warnings separately.

## Evidence and trace

PNL-01..06 → `addons/pixnido_panel_lab/plugin.gd`, `panel_dock.gd` → manual checklist above (not yet executed). PNL-07..11 remain open. Rationale: an isolated optional plugin permits review without modifying Flujo's existing dock. Alternative rejected for now: forcibly reparenting editor-internal split containers to guarantee a ratio, because it risks breaking editor layouts across versions.

**Tests:** Cannot claim execution without a Godot 4.7.2 runtime. CI/manual verification required.
**Metrics:** test duration: not measured; defects: unknown; review time: not measured.

## EXP-02 — keyboard, transition, session persistence

- **PNL-08A:** Ctrl+Alt+P toggles PixNido; Ctrl+Alt+R toggles References; Ctrl+Alt+I swaps sides. The plugin uses Node._shortcut_input; conflicts and input focus must be tested. Flujo F4 remains unchanged.
- **PNL-08B:** Smooth 0.16-second Tween of content alpha and horizontal offset (20 pixels) inside each dock. Rapid repeated toggles kill prior transitions. The native Godot dock/tab/splitter does not physically slide; animating editor internals is deferred.
- **PNL-08C:** EditorPlugin._get_window_layout / _set_window_layout save pixnido_open, references_open, and swapped to Godot's per-project editor_layout.cfg. Every user toggle, X, or swap calls queue_save_layout; no separate configuration or runtime files are created.
- **Compatibility:** Session state is project/editor-local. Swapping docks re-registers their default slots, which may reset user-dragged placements. The precise 1:2 width ratio (PNL-07) is unimplemented.

### EXP-02 verification (still pending Godot 4.7.2)

- [ ] Open, close and swap with toolbar icons, X buttons and all three shortcuts.
- [ ] Toggle rapidly while fading/sliding, with one or both docks open.
- [ ] Restart Godot and verify panel visibility and swapped sides are restored.
- [ ] Confirm References can remain open by itself.
- [ ] Check shortcut collisions, focus handling and layout behavior on Fedora / Android.
- [ ] Run headless editor import and existing model smoke test; run git diff --check.
- [ ] Review editor startup logs, visual UI, plugin disable/re-enable, and unchanged Flujo F4.

Trace: PNL-08A/08C → addons/pixnido_panel_lab/plugin.gd; PNL-08B → addons/pixnido_panel_lab/panel_dock.gd. Rationale: native editor layout persistence is preferable to machine-specific configuration paths; internal-content Tweens are less invasive than altering editor splitters. Test metrics remain not measured; runtime verification is not claimed.
