# NidoLab — PixNido / References (EXP-01 through EXP-07)

**Branch:** `experiment/pixnido-servo-dock`
**Status:** EXP-01–08 experimental code; focus workspace ratio/reparent smoke and Linux Godot 4.7.2 headless CI passed; Fedora visual overlay and native Servo tests remain pending. Android integration is paused.
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
- PNL-09 (EXP-03 code): freely movable/resizable reference images, per-project storage and controls on selection.
- PNL-10 (EXP-04 code): optional HTML5 PixNido host via dynamically discovered godot-servo; the source app remains unchanged.
- PNL-11 (EXP-05 code, unverified): a Save button transfers PixNido PNG/WebP previews into project folders (default `res://assets/sprites/`) using a JS/GDScript bridge.

## EXP-01 implementation

This historical EXP-01 step implemented PNL-01 through PNL-06 as an **editor dock shell**. At that step, `+` was disabled; EXP-03 now enables it for file selection. Only one plugin is added; it registers two `EditorDock` instances and a minimal icon-only `CONTAINER_TOOLBAR` control. Re-registering the docks is used to swap default left/right slots; on that action Godot may reset manual placement.

**Important limitation (PNL-07):** `EditorDock` exposes dock positions but **not a guaranteed fractional editor width**. This step sets modest minimum sizes; it does *not* assert exact 1:2 sizing, horizontal adjacency, or slide animations. A controlled host-layout strategy must be validated before marking PNL-07 complete. The center editor remains a real Godot workspace, not a simulated empty panel.

## Manual acceptance checklist (Godot 4.7.2, Fedora; repeat on Android editor)

- [ ] Enable/open this experimental branch: Flujo's original dock still behaves normally, including F4.
- [ ] PixNido opens on the left, References starts hidden, and the global three-icon toolbar appears.
- [ ] Toggle either dock independently and close either via its own X.
- [ ] Show only References; PixNido remains closed.
- [ ] Swap sides with both open, then with only one open. Both panels retain their placeholder contents.
- [ ] Verify `+` opens an OS file picker with multi-selection and adds selected images.
- [ ] Check compact editor layout, tooltips and keyboard focus.
- [ ] Disable the test plugin; its docks and toolbar are fully removed.
- [ ] Check editor restart and reopen; EXP-02 should restore visibility and swapped sides.
- [ ] Capture editor load, existing model smoke test, and any warnings separately.

## Evidence and trace

PNL-01..06 → `addons/pixnido_panel_lab/plugin.gd`, `panel_dock.gd` → manual checklist above (not yet executed). PNL-07, PNL-10, and PNL-11 remain open; PNL-08 and PNL-09 have experimental code awaiting Godot verification. Rationale: an isolated optional plugin permits review without modifying Flujo's existing dock. Alternative rejected for now: forcibly reparenting editor-internal split containers to guarantee a ratio, because it risks breaking editor layouts across versions.

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

## EXP-03 — references board

- **PNL-09A:** `+` opens `EditorFileDialog` with multiple file selection on the local filesystem; supported extensions: PNG, JPG/JPEG, WebP, BMP. Files are read without modifying or copying them.
- **PNL-09B:** Clicking a reference selects it and reveals Close, Move, and Resize controls. The controls operate on the selected image only. Move and resize are pointer-drag interactions constrained to the board; selection raises an image to the foreground. Each reference keeps its independent visual coordinates and size.
- **PNL-09C:** Each image has a stable local `ref_N` ID. File path, geometry, stacking order and next ID are serialized as `reference_images` in the plugin's existing per-project editor layout, not in `res://` resources. Project-relative sources use `res://`; external files use local absolute paths inside unshared editor metadata.
- **PNL-09D:** Missing, oversize or unreadable sources display an explicit placeholder; entries remain editable/removable after reloading. The source is not silently deleted. A 32 MiB input-file cap and 4096-pixel display texture edge limit protect editor memory. The original image file is unchanged.
- **PNL-09E:** Reference features remain available without PixNido. The PixNido PWA and Flujo's existing runtime, Inspector, dock and F4 behavior are untouched.

### EXP-03 manual acceptance

- [ ] Add 1 image and multiple selected images using +, including from outside `res://`.
- [ ] Select an image: see its three icon controls; click another to transfer selection and bring it forward.
- [ ] Drag move and resize handles, overlap two images, close one without deleting the image file.
- [ ] Save, restart Godot, and verify paths, positions, dimensions, and stacking order.
- [ ] Move/delete a source file, restart, verify missing-image placeholder persists and can be removed.
- [ ] Test a corrupt image and an image greater than 32 MiB; neither should crash the editor.
- [ ] Test reference-only mode, swapping dock sides, and rapid panel toggles with images present.
- [ ] Check UI at small dock widths and on Fedora/Android with touch and mouse.
- [ ] Run existing headless editor import and Flujo model smoke tests; inspect errors separately.

**Open risks:** exact 1:2 sizing PNL-07 and real HTML5 embedding PNL-10 remain pending; pointer controls and `EditorFileDialog` require actual editor review. External image paths are intentionally **local** and will not travel to a teammate's computer. Editor layout is not a substitute for sharing image assets; project-included images should be used when collaboration is needed.

**Trace:** PNL-09A → `addons/pixnido_panel_lab/panel_dock.gd`; PNL-09B/D → `reference_board.gd` and `reference_item.gd`; PNL-09C/E → `plugin.gd` and `reference_board.gd`. Automated runtime checks not executed until a matching Godot 4.7.2 executable is available. Engineering metrics: runtime duration not measured; defects unknown; visual review pending.

## EXP-04 — optional PixNido HTML5 host

- **PNL-10A:** The PixNido dock now provides an address field and icon-only Open button. The initial URL is the publicly documented PixNido 1.0.0 production address, `https://pixnido.pages.dev/`. It is **not opened automatically**: the user explicitly starts the browser, so the experiment does not require an external network service to load Flujo.
- **PNL-10B:** An alternate project-local entry point `res://.../index.html` is also accepted; the HTML and its relative assets must be copied into that directory by the developer. The adapter converts it to a `file://` URL in editor mode. This is editor-only; exported PCK builds would need the upstream `local_pages.gd` extraction mechanism.
- **PNL-10C:** `ClassDB.class_exists("ServoWebView")` and the adapter script are checked **before** loading the native-dependent script. Missing native binaries produce an informational status, not a hard parser dependency in this plugin. `servo_texture_rect.gd` (from the upstream distribution) handles input, touch, texture updates, resizing, and platform shader handling; we do not reimplement it.
- **PNL-10D:** The existing native view is destroyed before replacing it (upstream says simultaneous ServoWebView nodes are not well tested). The optional URL is saved in the same per-project editor layout configuration as panel visibility and reference positions. Re-opening Godot restores the address only; it does not make a network request without a click.
- **PNL-10E:** No upstream native binaries, external source copies, secrets, or credentials are checked in. Neither the published PixNido PWA nor Flujo's `addons/vp_flujo/` files are changed.

### Installation for a real editor test

1. Obtain the latest compatible upstream package from [shiena/godot-servo releases](https://github.com/shiena/godot-servo/releases). Upstream **v1.0.1** is a documented example; check the actual release and required Godot compatibility.
2. Copy the complete `addons/godot_servo/` directory (including `bin/` with platform-native binaries) into this experimental project. Keep exactly **one** `godot_servo.gdextension` manifest; do not keep duplicate manifests.
3. Restart **Godot 4.7.2** and check whether `ServoWebView` registers successfully.
4. Open the PixNido panel and press its Play/Open icon. Loading `https://pixnido.pages.dev/` requires internet; `res://.../index.html` requires a previously copied PWA directory.
5. Inspect the graphics backend with `ServoWebView.get_backend_name()` if troubleshooting; Fedora Compatibility may use CPU readback and Android Compatibility needs the external-sampler shader (handled by upstream TextureRect script).

### EXP-04 limitations and acceptance

- [ ] Without godot-servo installed, open the editor: no script parse errors; the panel shows actionable information when Open is clicked.
- [ ] After installing the extension, load PixNido 1.0.0, render its full responsive UI inside the dock, draw and switch tools.
- [ ] Verify keyboard focus, mouse and multitouch (not just a static texture); test resizing and orientation changes.
- [ ] Close and reopen panel; swap sides while PixNido is active, verifying it does not create a second native view.
- [ ] Test with local HTML and correctly packaged relative assets if offline usage is needed.
- [ ] Restart editor and verify source URL persistence; no automatic request on restart.
- [ ] Confirm References remain independent and Flujo F4, runtime and Inspector are unchanged.
- [ ] Run native Godot 4.7.2 editor load, smoke test and `git diff --check`; inspect error and warning logs separately.

**Explicit limitations:** `godot-servo` does **not** currently expose HTML file/color pickers, which PixNido uses; embedded import and color selection may fail until adapted. PNL-11's GDScript-to-JavaScript export bridge, including default `res://assets/sprites/`, is **not implemented** in EXP-04. The extension is experimental and large; Linux, Android and platform-specific render paths must be measured in real hardware. No successful launch is claimed without the native package and Godot editor execution.

**Trace:** PNL-10A/B/C/D → `addons/pixnido_panel_lab/pixnido_servo_host.gd`, `panel_dock.gd`, and `plugin.gd`. PNL-10E → changed-file audit. Source provenance: `mercurysama/Anki-tools`, branch `release/pixel-art-editor-pwa`, `projects/pixel-art-editor/pwa/RELEASE_1_0_0.md`, and upstream `shiena/godot-servo` documentation. Engineering metrics: Godot execution not measured, rendering performance not measured, visual review pending.

## EXP-05 — PNG / WebP sprite exports to the project

**New editor controls:** PixNido's dock now offers an icon-only Save button and an icon-only Folder button. The destination defaults to `res://assets/sprites/`. Selecting another destination is restricted to `EditorFileDialog.ACCESS_RESOURCES` and saved per project in the same editor layout as the panel configuration. Existing sprite files are never overwritten.

**User flow:** Open PixNido, generate a PNG/WebP export using PixNido's own existing interface (including sprite sheets or animated formats), then press Save in the Godot dock. Godot captures the exported preview image and writes it directly into the selected project folder. **No automatic filesystem writes** occur solely because a web page generates a preview; Save is an explicit user action. The destination is automatic, not the save trigger.

**Protocol:** The optional `ServoWebView.load_finished` callback evaluates the local `pixnido_export_bridge.js` into the loaded page. The script reads `#exportPreviewImage.src` only on the Save request. `godot.emit` sends `pixnido.export.begin`, `chunk` and `end` messages in strict order. A random token identifies each request; Godot requests each 8192-character Base64 chunk separately, caps total size at 32 MiB, rejects out-of-sequence packets, and times out stalled transfers after 120 seconds. The native writer validates MIME/signature and filename, refuses paths outside `res://`, creates the selected folder and uses unique timestamped names.

**Scope and risks:** The published `Anki-tools` PixNido PWA remains unchanged; the bridge depends on its current `exportPreviewImage` and `projectName` DOM identifiers. Godot-servo must be installed as a compatible native extension. Its real behavior in the editor, input flow and integration of `evaluate_javascript` have **not yet been executed or measured** on Godot 4.7.2. The renderer adapter from EXP-04 may also need editor `@tool` compatibility review; this is a blocker to declare end-to-end integration finished. Data URLs and chunked transfer for large animated WebP/APNG need real tests, not merely signature validation.

### EXP-05 acceptance

- [ ] Godot 4.7.2 headless import and original Flujo smoke tests; classify warnings separately.
- [ ] With no godot-servo package, opening the experiment does not crash Flujo.
- [ ] With the package installed, export PNG and sprite-sheet PNG; Save creates a valid file at `res://assets/sprites/`.
- [ ] Repeat with static WebP, animated WebP and APNG and verify file bytes against actual previews.
- [ ] Save twice without overwriting; choose another project directory and restart editor to verify persistence.
- [ ] Check missing preview, malformed chunks, invalid MIME/path, oversize export and timeout: no partial files.
- [ ] Verify References-only mode, side switching, keyboard shortcuts and preservation of Flujo F4.
- [ ] Run `git diff --check` and record visual review on Fedora and Android.

**Trace:** PNL-11 → `pixnido_export_bridge.js` (JS protocol), `pixnido_servo_host.gd` (native integration and UI), `sprite_export_writer.gd` (confined safe writing), `panel_dock.gd` + `plugin.gd` (directory persistence). **Validation:** repository static review only; execution time and real platform outcomes not measured. No edits to `addons/vp_flujo/` or production PixNido.

### EXP-05 focal test added

- `tests/editor/pixnido_export_writer_smoke.gd`: creates a 2×2 PNG in memory, exercises path traversal denial, MIME/signature rejection, unique filenames, byte-for-byte save verification, and cleanup under `res://.godot/pixnido_writer_test/`. Run with `godot --headless --editor --path . --script res://tests/editor/pixnido_export_writer_smoke.gd` in Godot 4.7.2. **Not executed in this environment.**
- The JavaScript bridge source was parsed/executed in a standalone JS harness with a stub Godot event sink: one 20,000-character Base64 payload produced 3 chunks (8192 + 8192 + 3616 characters) and one end message; a concurrent duplicate start was rejected. This **does not** prove the native Servo event transport, disk writer or editor UI works.

## EXP-06 — CI and manual editor validation

**Scope:** Validate the optional PixNido panel addon before any integration into `main`; no modifications to Flujo runtime, Inspector, F4, production PixNido, or persistent Flow schemas.

### Verified automated evidence (2026-11-08)

- GitHub Actions run [42524147510](https://github.com/mercurysama/Flujo/actions/runs/42524147510) completed **success** for commit `09a77a3c58bbff5afb6b5c47b2ecbf7cd3c378a7`.
- `tests/editor/pixnido_export_bridge.test.cjs` passed on Node 22. Tests cover chunking, token/order, duplicate transfer, invalid/missing/oversized preview, and cancellation.
- Official Linux Godot **4.7.2.stable.official.ed1daf0bf** downloaded in CI; the editor project loaded headlessly with no additional `ERROR:` diagnostics compared with a baseline run disabling only the PixNido lab plugin.
- `tests/editor/pixnido_export_writer_smoke.gd` printed `[PixNido] Sprite export writer smoke test passed`, exercising a generated PNG, refusing traversal/invalid MIME and ensuring distinct output names with byte-for-byte checks.
- Existing model regression printed `[Flujo] Model smoke test passed`. `git diff --check` passed.
- Fixed the editor-only dock initialization regression: closing a newly registered dock too early caused an internal `SplitContainerMultiDragger` out-of-range error. Waiting two process frames before initial visibility restoration removed the extra error in CI. The comparative baseline is maintained in the workflow to detect recurrences.
- Added `servo_editor_texture_rect.gd`, an optional `@tool` texture/input adapter for browser rendering inside Godot's **editor**. The upstream helper script is useful at runtime but is not explicitly editor-tool-enabled. Its actual native behavior has not been tested without a Servo extension package.
- Short-lived warnings such as `Scan thread aborted...` were observed on planned headless editor shutdown. Running the writer's `SceneTree` test with `--editor --script` also produced cleanup/resource-leak diagnostics; the workflow now runs this specific test with `--headless --path . --script` to avoid starting a redundant editor UI.

### Reproducible commands

From the experimental Git checkout on Fedora (select the installed 4.7.2 executable, or replace `godot` below with `flatpak run org.godotengine.Godot`):

```bash
godot --version
git diff --check
node tests/editor/pixnido_export_bridge.test.cjs
godot --headless --editor --path . --quit-after 5
godot --headless --path . --script res://tests/editor/pixnido_export_writer_smoke.gd
godot --headless --path . tests/model/flow_model_smoke_test.tscn
```

### Mandatory interactive review — Fedora

- [ ] Open Godot 4.7.2's actual editor and verify PixNido-only default state, References-only mode, both visible, and both hidden.
- [ ] Toggle, close and swap panels rapidly; test `Ctrl+Alt+P`, `Ctrl+Alt+R`, `Ctrl+Alt+I` without stealing Flujo F4.
- [ ] Add multiple reference images; select, drag, resize, close, reopen and restart. Verify persisted paths, dimensions, layering and missing-image placeholders.
- [ ] Confirm layout ratios **PixNido 1/3, References 2/3**; **not implemented yet** by native `EditorDock`, so do not mark accepted until a separate layout approach is approved.
- [ ] Obtain a compatible **Linux** godot-servo release, install its entire `addons/godot_servo/` tree and exactly one manifest; restart editor and inspect the native class registration.
- [ ] Open PixNido 1.0.0 inside the dock. Test drawing, UI responsiveness, keyboard, mouse, pan/zoom, clipboard, menu dialogs and resizing. Watch whether native HTML file/color pickers are unsupported.
- [ ] Generate static PNG/WebP, sprite sheet PNG, animated WebP and APNG inside PixNido. Click Godot Save and verify valid files under `res://assets/sprites/`; save twice, change the folder, restart and check persistence.
- [ ] Confirm no browser page can save without a user click and no file paths outside the Godot project can be selected.
- [ ] Disable/uninstall the optional plugin and verify Flujo's existing editor, model/runtime and F4 behavior remain intact.

### Mandatory interactive review — Android

- [ ] Confirm the actual Godot Android editor version and whether the compatible `godot-servo` arm64 native extension can load in that environment.
- [ ] Repeat reference-only usability, touch placement/resizing, panel swapping, physical-keyboard shortcuts, and orientation changes.
- [ ] If Servo loads, verify mobile browser texture, touch/pointer forwarding, visual output with Compatibility renderer, responsive width and actual export writes in the Android editor's project storage.
- [ ] Record package installation limitations and failures without silently substituting a web export or a Fedora result.

### Open blockers

1. **Native Servo is not packaged/installed in this branch.** HTML5 rendering, browser permissions/dialogs and end-to-end export still require hardware validation.
2. **PNL-07 (exact fractional layout)** is not yet implemented: the native `EditorDock` API controls slots, not guaranteed editor width ratios.
3. **Full slide animation** of the native dock is not implemented; only dock content transitions.
4. **UI tests on Fedora and Android** are not performed by the headless CI; no human visual approval is claimed.

**Decision:** Keep `experiment/pixnido-servo-dock` isolated. Do not merge into `main` until the interactive checks and the 1:2 layout requirement are resolved or explicitly re-scoped by the maintainer. Runtime metrics and Android outcomes are unknown.

## EXP-07 — NidoLab identity and keyboard-friendly compact panels

**Name:** `NidoLab` is the provisional identity of this *optional, independent* editor utility, not a Flujo glossary term or part of Flujo's runtime. The two panels retain their existing titles `PixNido` and `References`; existing internal paths, dock keys, layout persistence keys and public URL remain unchanged for compatibility.

- **PNL-12A, compact PixNido UI:** separate the source URL row from the sprite export actions. The row widths should remain usable in a narrow Godot dock; full file destinations are preserved in tooltips. Retain the existing three icon-only **global** toolbar buttons and all shortcuts.
- **PNL-12B, optional Servo:** present a read-only installed/missing status based on native-class detection, with an explicit user-action link to the upstream releases. Never download binaries silently or package native Servo libraries in Flujo/NidoLab.
- **PNL-12C, References keyboard:** allow focus-guarded arrow-key nudge of the selected image, Shift+arrow to resize, Delete to remove the selected reference and Escape to deselect. Do not steal keys from Godot when the board lacks focus. Only changes to the selected image should be persisted.
- **PNL-12D, layout integrity:** keep independent dock visibility, close, swap and persistence semantics; no changes under `addons/vp_flujo/`, no new runtime dependencies or changed F4 behavior.
- **PNL-07 remains pending:** Godot 4.7.2's documented `EditorDock` API exposes placement, visibility and floating layouts but **no controlled proportional width**. Do not manipulate private editor splitters to fake the 1:2 widths; measure real behavior manually before deciding on an alternative.

### EXP-07 acceptance

- [ ] On Linux Godot 4.7.2, load NidoLab with no Servo extension: helpful status, accessible manual-install action, no automatic network request.
- [ ] In narrow left/right docks, URL editor, Play, Save, Folder, and status remain usable without horizontal overflow.
- [ ] Open References alone; select one image, nudge using arrows, resize using Shift+arrows, delete and deselect with keyboard.
- [ ] Switch focus to Godot's script editor and confirm its arrow/Delete/ESC keys remain unaffected.
- [ ] Reopen editor and ensure the prior session's panel configuration, paths, image coordinates and stacking order persist.
- [ ] Linux CI: `git diff --check`, editor startup against baseline, writer smoke, JS bridge, and original Flujo model smoke.
- [ ] Manual visual review remains necessary; do not mark exact width ratios or live Servo rendering as verified.

**Implementation rationale:** visible, optional dependencies and compact controls help keep this egg independent of Flujo. Alternatives rejected: copying Servo native binaries into the repository, adding a fourth toolbar action, changing serialized dock identifiers, or setting widths via undocumented editor nodes. **Trace:** PNL-12A/B → `pixnido_servo_host.gd`; PNL-12C → `reference_board.gd`; PNL-12D → `panel_dock.gd`, `plugin.cfg`; verification via existing CI plus manual checklist. Engineering time, performance and Windows compatibility: not measured.

### EXP-07 validation evidence — 2026-11-08

- <https://github.com/mercurysama/Flujo/actions/runs/42527867134> — GitHub Actions completed **success** for `45d2f76ef64ba0409feb60d73925afd80b59e10a`; both jobs passed (JavaScript bridge protocol/whitespace and Godot 4.7.2 editor baseline comparison, sprite writer, Flujo model smoke).
- Implemented plugin display name **NidoLab** without renaming the `addons/pixnido_panel_lab/` source directory, dock layout keys, saved settings or the two dock titles. The plugin remains independently disableable; `main` and `addons/vp_flujo/` untouched.
- PixNido URL remains in its own row; output action icons are in a separate row. Servo detection is read-only; the Get Servo button opens the official releases page only when clicked and only in the missing-addon state. No bundled binaries or automatic downloads.
- ReferenceCanvas now focuses on selection and supports arrow-key movement (1 px), Shift+arrow resize (10 px), Delete and Escape; all require board focus. This prevents global shortcut interception in principle, but keyboard focus transition and visual behavior **still need a real Fedora review**.
- Headless editor startup reported `Scan thread aborted...` during planned shutdown; no additional editor `ERROR:` messages were found compared with baseline. These do not validate GUI usability.
- Android integration is paused by maintainer preference, not removed: do not count Android installation, screen, performance or touch tests as accepted.
- The requested 1:2 dock width ratio remains **unimplemented and unverified** because Godot's public `EditorDock` API does not expose proportional sizing. Do not manipulate private splitter objects as a shortcut.

**EXP-07 engineering flow:** code change on isolated branch, GitHub CI success; Fedora native Servo, Android, visual metrics and proportional sizing not measured. Next review: Fedora Godot UI and manual Servo installation, then decide whether to keep native dock sizing user-adjustable or adopt a documented custom arrangement.

## EXP-08 — NidoLab full-editor focus workspace (supersedes the side-dock-only assumption)

**User clarification (2026-11-08):** When actively editing pixel art, NidoLab **should cover Godot's interface**, rather than leaving the editor in the middle of two docks. The goal is uninterrupted drawing with easy, reversible return to Godot. The existing independently usable editor docks remain available outside focus mode.

- **PNL-13A:** Add a dedicated **NidoLab Focus** entry action (Ctrl+Alt+N plus toolbar icon). This must be user-initiated, not restored automatically on startup. A visible **Back to Godot** control, plus the same shortcut, always exits. No trapping users in the overlay.
- **PNL-13B:** Full-rect opaque editor-workspace overlay, parented to `EditorInterface.get_base_control()` as a child, never freeing or reparenting Godot's editor controls. It covers all dock/editor UI while active. The contained PixNido and References widgets are **reparented from our own two dock children**, so active work and reference positions are preserved without recreating the browser.
- **PNL-13C:** In focus mode, a stable two-column split assigns 1/3 of available width to PixNido and 2/3 to References. Both zones remain opaque even when their panel is hidden: only the NidoLab workspace is visible, not a hole revealing Godot. Swap panes, close/show each independently and add references without leaving the workspace. The ratio is a focus-mode goal, not a guarantee for Godot's native side docks.
- **PNL-13D:** Exiting or disabling the plugin restores each original widget to its original add-on parent, preserving editor layout state. No changes to the runtime, F4, native Servo package, or the public PixNido PWA. Close/open/swap state persists in the regular dock layout; the temporary overlay does **not** auto-launch on restart.
- **PNL-13E:** Run headless editor and model smoke regressions, a focused node-reparent/layout test where possible, and manual real-editor tests later in Fedora. Keep Android suspended.

**Decision:** Prefer a standalone opaque NidoLab overlay over private `SplitContainer` manipulation or a separate OS-level popup Window. The editor's public `EditorInterface.get_base_control()` gives a stable place for adding a user-owned Control; this is experimental and still requires visual stacking/focus verification. The overlay itself does not need native Servo.

**Acceptance:** [ ] toolbar and Ctrl+Alt+N enter, [ ] NidoLab covers Godot without a visible gap, [ ] PixNido/References display side by side at 1:2 widths, [ ] hide/show/swap work, [ ] returning to Godot retains browser session and reference positions, [ ] exit and plugin disable cannot orphan controls, [ ] no extra editor errors or Flujo regressions, [ ] Fedora visual approval. CI success alone is insufficient.

### EXP-08 implementation and verification — 2026-11-08

- `addons/pixnido_panel_lab/focus_workspace.gd`: a dedicated opaque `PanelContainer` covering the editor's `EditorInterface.get_base_control()`. It contains two independently hideable columns with stretch ratios 1:2. Controls named PixNido and References are moved from their addon-owned dock containers into these columns; swapping reorders only the owned columns; neither `EditorDock` nor Godot editor internals are reparented.
- `addons/pixnido_panel_lab/plugin.gd`: new focus action in the editor toolbar and Ctrl+Alt+N shortcut. Escape from focus uses the explicit `Back to Godot` button or the shortcut; no automatic focus launch at startup. Restores original addon children before removing the overlay on exit/plugin disable. Existing dock visibility/swap preferences still apply outside focus mode.
- `addons/pixnido_panel_lab/panel_dock.gd`: exposes only its own content widget and reference image picker for the temporary overlay.
- `tests/editor/nidolab_focus_smoke.gd`: headless test uses dummy addon bodies to verify reparenting, exact 1:2 width ratio to tolerance, swap order, hide/show and reparent restoration after closing.
- [GitHub Actions run 42529479346](https://github.com/mercurysama/Flujo/actions/runs/42529479346) **SUCCESS**: JavaScript bridge and diff checks, Godot 4.7.2 editor import relative to the no-NidoLab baseline, writer smoke, NidoLab focus smoke (`[NidoLab] Focus workspace smoke test passed`) and Flujo model smoke. Expected editor shutdown warning `Scan thread aborted...` observed; no new editor `ERROR:` lines relative to baseline.
- **Manual Fedora review remains open:** confirm this child overlay actually covers all editor UI (no gaps) and appears above the editor menus/docks at multiple window sizes, the native Servo browser is interactive, modal file pickers appear in front, and `Back to Godot` restores keyboard/mouse focus and the active PixNido/References session. Headless layout checks alone cannot prove these UI points.
- **Compatibility:** native dock widths are still controlled by Godot; the 1:2 width is implemented for the opaque focus overlay, not for normal side docks. Android remains on pause. No native Servo binaries are bundled.

## EXP-09 — icon-only References tabs, movable notes and drag-reorder tasks

**Updated user interaction contract (2026-11-08):**
- **PNL-14A:** Opening PixNido is an explicit entry into the NidoLab focus workspace. Both PixNido and References are shown, side by side. References can be hidden independently. **PixNido always keeps exactly its original one-third width** when References is hidden: the right two-thirds remain a blank opaque NidoLab region, never reveal Godot and never resize PixNido. When References is opened independently, the original two-thirds column remains its width, with the first third blank. References can also be opened on its own from Godot without starting PixNido or loading Servo. Returning to Godot must not auto-open PixNido. Existing shortcuts are preserved; Ctrl+Alt+N remains an alternative focus toggle.
- **PNL-14B:** References now contains exactly three icon-only tabs in order: image references, text notes, tasks. Tabs use tooltip labels for accessible meaning, not visible tab words. Existing image-reference data and behavior are preserved.
- **PNL-14C:** Text notes are individual movable, resizable and closeable cards on their own canvas, with editable multiline text. Images and notes do not interfere with each other. Each note has a persistent ID and canvas geometry.
- **PNL-14D:** Tasks have a plus action to create a task, a checkbox that strikes the task's text when checked, and a right-hand three-dots options menu with Edit, Move up/down (keyboard fallback) and Delete. Tasks support pointer drag-and-drop reorder and preserve order, identity, text and completion across sessions.
- **PNL-14E:** Save notes, task order/check state, and active tab in project-local editor layout using independent keys. Preserve the original `reference_images` schema version 1 without silently migrating or deleting old references. Keep everything under the optional NidoLab addon; Android and Servo runtime testing remain paused/pending.

**Implementation plan:** Add `notes_board.gd` + `note_card.gd` and `task_list.gd` + `task_row.gd` (+ dedicated drag handle). Compose three tabs in `reference_hub.gd` with the existing `reference_board.gd` intact. Redirect dock state and add-image command through hub; store data in distinct editor-layout keys. Rework focus entry and pane hide/reopen semantics without manipulating Godot editor internals.

**Acceptance:** [ ] Opening PixNido enters focus with both panes, [ ] hiding References leaves PixNido at exactly one third and the remaining two thirds opaque/empty, [ ] independent References-only launch, [ ] icon-only tabs in specified order, [ ] note creation/edit/drag/resize/remove, [ ] task checkbox strikethrough and 3-dots menu, [ ] reorder via drag-and-drop, [ ] state persists on restart, [ ] original reference images preserved, [ ] Linux Godot 4.7.2 headless and smoke regressions passed, [ ] Fedora visual validation pending. **Trace:** PNL-14A → plugin/focus workspace; 14B → reference_hub; 14C → notes board/card; 14D → task list/row/handle; 14E → layout and tests. No bundled Servo binaries; no changes to Flujo's runtime.

**EXP-09 maintainer sizing correction:** NidoLab panes **must not auto-expand when the other pane is closed**. Preserve PixNido=1/3 and References=2/3 in focus mode, including with only one visible. The unused column remains an opaque, empty workspace; no editor UI shows through. This overrides the earlier proposed expansion on hide.
