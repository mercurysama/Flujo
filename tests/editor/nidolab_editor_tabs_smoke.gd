@tool
extends SceneTree

## Verify expandable editor tabs and reparenting, without native Servo.

const EDITOR_TABS := preload("res://addons/pixnido_panel_lab/editor_tabs.gd")
const FOCUS := preload("res://addons/pixnido_panel_lab/focus_workspace.gd")


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var failures: Array[String] = []
	var screen := Control.new()
	screen.size = Vector2(1200, 800)
	root.add_child(screen)

	var pix_home := VBoxContainer.new()
	screen.add_child(pix_home)
	var ref_home := VBoxContainer.new()
	screen.add_child(ref_home)
	var tabs: TabContainer = EDITOR_TABS.new()
	pix_home.add_child(tabs)
	tabs.size = Vector2(420, 650)
	var original: Control = tabs.call(&"get_pixnido_host")
	if tabs.get_tab_count() != 1 or not is_instance_valid(original):
		failures.append("Expected exactly one PixNido editor tab")
	if String(tabs.call(&"get_active_editor_id")) != "pixnido":
		failures.append("Wrong active editor ID")
	if tabs.get_tab_title(0) != "" or tabs.get_tab_icon(0) == null:
		failures.append("PixNido tab is not icon-only")
	if tabs.get_tab_tooltip(0).is_empty():
		failures.append("PixNido tab missing tooltip")

	var placeholder := Control.new()
	placeholder.name = "FutureEditor"
	if not bool(tabs.call(&"register_editor", &"future_editor", placeholder, &"Texture2D", "Future editor")):
		failures.append("Cannot register a future editor")
	if bool(tabs.call(&"register_editor", &"future_editor", Control.new(), &"Texture2D", "Duplicate")):
		failures.append("Duplicate editor IDs were accepted")
	if tabs.get_tab_count() != 2:
		failures.append("Registered editor tab did not appear")
	tabs.call(&"set_active_editor_id", &"future_editor")
	if String(tabs.call(&"get_active_editor_id")) != "future_editor":
		failures.append("Failed to select future editor")
	tabs.call(&"set_active_editor_id", &"pixnido")
	if tabs.call(&"get_pixnido_host") != original:
		failures.append("Switching editor tabs recreated PixNido")
	if not is_instance_valid(placeholder) or placeholder.get_parent() != tabs:
		failures.append("Future editor was unexpectedly removed")

	var references := Control.new()
	ref_home.add_child(references)
	var focus: Control = FOCUS.new()
	screen.add_child(focus)
	focus.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if not bool(focus.call(&"attach_contents", tabs, references, true, true, false)):
		failures.append("Unable to move tabbed PixNido into focus mode")
	await process_frame
	await process_frame
	if tabs.call(&"get_pixnido_host") != original:
		failures.append("Focus reparenting recreated the PixNido browser host")
	var widths: Vector2 = focus.call(&"get_pane_widths")
	focus.call(&"set_pane_visibility", &"references", false)
	await process_frame
	var hidden: Vector2 = focus.call(&"get_pane_widths")
	if absf(widths.x - hidden.x) > 1.0 or absf(widths.y - hidden.y) > 1.0:
		failures.append("Closing References changed editor tab width")
	focus.call(&"restore_contents")
	if tabs.get_parent() != pix_home or references.get_parent() != ref_home:
		failures.append("Exiting focus did not restore tab and reference bodies")
	if tabs.call(&"get_pixnido_host") != original:
		failures.append("Returning to Godot recreated PixNido")

	focus.queue_free()
	screen.queue_free()
	await process_frame
	if failures.is_empty():
		print("[NidoLab] Editor tabs smoke test passed")
		quit(0)
	else:
		for problem in failures:
			printerr("[NidoLab] " + problem)
		quit(1)
