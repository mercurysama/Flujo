# PixNido Panel Lab — EXP-01 / EXP-02 / EXP-03 / EXP-04 / EXP-05

**Branch:** `experiment/pixnido-servo-dock`
**Status:** EXP-01–03 implementation proposed in the experimental branch; Godot 4.7.2 execution and visual approval pending.
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
