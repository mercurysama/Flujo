@tool
extends SceneTree

## Headless focus-workspace acceptance without Servo or editor-native controls.
const WORKSPACE := preload("res://addons/pixnido_panel_lab/focus_workspace.gd")


func _initialize() -> void:
	call_deferred(&"_run_focal")


func _run_focal() -> void:
	var failures: Array[String] = []
	var base := Control.new()
	base.name = "FakeEditorRoot"
	base.size = Vector2(1200.0, 800.0)
	root.add_child(base)

	var pix_home := VBoxContainer.new()
	pix_home.name = "PixDockContent"
	base.add_child(pix_home)
	var refs_home := VBoxContainer.new()
	refs_home.name = "RefsDockContent"
	base.add_child(refs_home)

	var pix := Control.new()
	pix.name = "PixNidoBody"
	pix.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pix_home.add_child(pix)
	var references := Control.new()
	references.name = "ReferenceBoard"
	references.size_flags_vertical = Control.SIZE_EXPAND_FILL
	refs_home.add_child(references)

	var focus: Control = WORKSPACE.new()
	base.add_child(focus)
	focus.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var attached: bool = bool(focus.call(&"attach_contents", pix, references, true, true, false))
	if not attached:
		failures.append("Could not attach NidoLab contents")
	if pix.get_parent() == pix_home or references.get_parent() == refs_home:
		failures.append("Contents were not transferred into the overlay")

	await process_frame
	await process_frame
	var widths: Vector2 = focus.call(&"get_pane_widths")
	if widths.x <= 0.0 or widths.y <= 0.0:
		failures.append("Focus panes have no measurable width")
	elif absf(widths.y / widths.x - 2.0) > 0.15:
		failures.append("Focus 1:2 width ratio differs: " + str(widths))

	focus.call(&"set_swapped", true)
	var split: Node = focus.get_node("WorkspaceLayout/FocusColumns")
	if split.get_child(0).name != "ReferencesColumn":
		failures.append("Swapping panel sides failed")

	focus.call(&"set_pane_visibility", &"pixnido", false)
	if pix.visible:
		failures.append("PixNido body was not hidden")
	focus.call(&"set_pane_visibility", &"pixnido", true)
	if not pix.visible:
		failures.append("PixNido body was not restored")

	focus.call(&"restore_contents")
	if pix.get_parent() != pix_home or references.get_parent() != refs_home:
		failures.append("Closing focus view orphaned addon widgets")
	if not pix.visible or not references.visible:
		failures.append("Pane widgets remained hidden after restoration")
	if bool(focus.call(&"is_attached")):
		failures.append("Focus workspace still marked as attached")

	focus.queue_free()
	await process_frame
	if not is_instance_valid(pix) or not is_instance_valid(references):
		failures.append("Focus view cleanup unexpectedly freed the original widgets")
	base.queue_free()
	if failures.is_empty():
		print("[NidoLab] Focus workspace smoke test passed")
		quit(0)
	else:
		for failure in failures:
			printerr("[NidoLab] " + failure)
		quit(1)
