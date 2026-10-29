@tool
extends SceneTree

const FLUO_DRAWER_SCRIPT: Script = preload("res://addons/vp_flujo/editor/fluo_drawer.gd")

var _failures: Array[String] = []
var _base_control: Control
var _dock: VPFlujoDock
var _open_button: Button
var _drawer: Control
var _motion_shell: Control
var _drawer_panel: PanelContainer


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	await _frames()
	while EditorInterface.get_resource_filesystem().is_scanning():
		await process_frame
	_base_control = EditorInterface.get_base_control()
	_dock = get_root().find_child("VPFlujoDock", true, false) as VPFlujoDock
	if not _check(_base_control != null and _dock != null, "The editor base and existing VPFlujoDock are available."):
		await _finish()
		return

	_dock.show()
	await _frames(3)
	_open_button = _find_button(_dock, "Open Fluo (POC)")
	_check(_open_button != null and _open_button.visible, "The existing dock exposes Open Fluo (POC).")
	_check(
		_open_button != null and _open_button.size.x > 0.0 and _open_button.size.y > 0.0,
		"Open Fluo (POC) has a clickable dock presentation."
	)
	_check(_dock.get_variable_editor() != null, "The existing dock keeps its editor surface mounted.")
	var interaction_button: Button = _find_button(_dock, "Enter Flow (F4)")
	_check(interaction_button != null, "The existing Flow interaction button remains available.")
	_check(
		FlowInteractionCoordinator.create_default_shortcut().matches_event(_f4_event()),
		"The F4 shortcut remains registered independently of the Fluo button."
	)
	if _open_button == null:
		await _finish()
		return

	var drawers: Array[Control] = _find_drawers(_base_control)
	_check(drawers.size() == 1, "The plugin mounts exactly one FluoDrawer instance.")
	if drawers.is_empty():
		await _finish()
		return
	_drawer = drawers[0]
	var dock_width: float = _dock.custom_minimum_size.x
	_check(_drawer.get_parent() == _base_control, "FluoDrawer is mounted on the editor base as an overlay.")
	_check(is_zero_approx(dock_width), "The Fluo overlay does not assign permanent dock width.")
	_motion_shell = _drawer.get_node("DrawerMotionShell") as Control
	_drawer_panel = _drawer.get_node("DrawerMotionShell/DrawerPanel") as PanelContainer
	_check(_drawer.get_child_count() == 2, "The mounted drawer has exactly Backdrop and DrawerMotionShell.")
	_check(_motion_shell != null, "The mounted drawer has one MotionShell.")
	_check(_motion_shell != null and _motion_shell.get_child_count() == 1, "The mounted MotionShell has one DrawerPanel child.")
	_check(_drawer_panel != null and _drawer_panel.get_parent() == _motion_shell, "The mounted DrawerPanel is inside MotionShell.")
	_check(_neutral_offset_transform(), "The mounted MotionShell starts with a neutral offset transform.")

	_open_button.grab_focus()
	await _frames(2)
	_open_button.pressed.emit()
	_check(bool(_drawer.call("is_open")), "Open Fluo (POC) opens the mounted drawer.")
	_check(_drawer.visible, "Opening Fluo makes the overlay visible.")
	_check(_find_drawers(_base_control).size() == 1, "Opening Fluo does not create a second drawer.")
	_check(is_zero_approx(_dock.custom_minimum_size.x - dock_width), "Opening Fluo does not change dock width.")
	_check(_neutral_offset_transform(), "Opening leaves the mounted MotionShell visually neutral.")

	_open_button.pressed.emit()
	_check(bool(_drawer.call("is_open")), "Repeated Open Fluo (POC) reuses the open drawer.")
	_check(_find_drawers(_base_control).size() == 1, "Repeated opening keeps exactly one drawer instance.")
	_check(_motion_shell.get_child_count() == 1, "Repeated opening keeps exactly one DrawerPanel in the shell.")

	_drawer.call("set_right_side", true)
	_check(_shell_uses_right_layout(), "The mounted shell owns right-side logical placement.")
	_check(_neutral_offset_transform(), "Right-side switching remains visually neutral.")
	_check(_find_drawers(_base_control).size() == 1, "Side switching does not duplicate the mounted drawer.")
	_drawer.call("set_right_side", false)
	_check(_shell_uses_left_layout(), "The mounted shell can return to left-side logical placement.")
	_check(_neutral_offset_transform(), "Returning left leaves the transform neutral.")

	var escape: InputEventKey = InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	_drawer.call("_input", escape)
	_check(not bool(_drawer.call("is_open")), "Escape closes Fluo without changing the dock context.")
	_check(_open_button.has_focus(), "Escape restores focus to the previous dock control.")
	_check(_neutral_offset_transform(), "Escape close leaves no visible offset on the mounted shell.")

	_open_button.pressed.emit()
	var backdrop: Control = _drawer.get_node("Backdrop") as Control
	_check(
		backdrop != null and backdrop.mouse_filter == Control.MOUSE_FILTER_STOP,
		"The overlay backdrop consumes exterior editor input."
	)
	_check(
		backdrop != null and backdrop.get_signal_connection_list(&"gui_input").size() == 1,
		"The overlay keeps one exterior-click callback."
	)
	if backdrop != null:
		var exterior_click: InputEventMouseButton = InputEventMouseButton.new()
		exterior_click.button_index = MOUSE_BUTTON_LEFT
		exterior_click.pressed = true
		_drawer.call("_on_backdrop_gui_input", exterior_click)
		_check(not bool(_drawer.call("is_open")), "An exterior click closes Fluo.")

	await _finish()


func _find_button(root: Node, button_text: String) -> Button:
	if root is Button and (root as Button).text == button_text:
		return root as Button
	for child: Node in root.get_children():
		var button: Button = _find_button(child, button_text)
		if button != null:
			return button
	return null


func _find_drawers(root: Node) -> Array[Control]:
	var drawers: Array[Control] = []
	if root.get_script() == FLUO_DRAWER_SCRIPT and root is Control:
		drawers.append(root as Control)
	for child: Node in root.get_children():
		drawers.append_array(_find_drawers(child))
	return drawers


func _f4_event() -> InputEventKey:
	var event: InputEventKey = InputEventKey.new()
	event.keycode = KEY_F4
	event.pressed = true
	return event


func _neutral_offset_transform() -> bool:
	return _motion_shell != null \
		and _motion_shell.offset_transform_enabled \
		and _motion_shell.offset_transform_position == Vector2.ZERO \
		and is_zero_approx(_motion_shell.offset_transform_rotation) \
		and _motion_shell.offset_transform_scale == Vector2.ONE \
		and not _motion_shell.offset_transform_visual_only


func _shell_uses_left_layout() -> bool:
	return _motion_shell != null \
		and is_zero_approx(_motion_shell.anchor_left) \
		and is_equal_approx(_motion_shell.anchor_right, 0.46) \
		and is_zero_approx(_motion_shell.anchor_top) \
		and is_equal_approx(_motion_shell.anchor_bottom, 1.0) \
		and _shell_offsets_are_zero()


func _shell_uses_right_layout() -> bool:
	return _motion_shell != null \
		and is_equal_approx(_motion_shell.anchor_left, 0.54) \
		and is_equal_approx(_motion_shell.anchor_right, 1.0) \
		and is_zero_approx(_motion_shell.anchor_top) \
		and is_equal_approx(_motion_shell.anchor_bottom, 1.0) \
		and _shell_offsets_are_zero()


func _shell_offsets_are_zero() -> bool:
	return _motion_shell != null \
		and is_zero_approx(_motion_shell.offset_left) \
		and is_zero_approx(_motion_shell.offset_top) \
		and is_zero_approx(_motion_shell.offset_right) \
		and is_zero_approx(_motion_shell.offset_bottom)


func _frames(count: int = 4) -> void:
	for _index: int in count:
		await process_frame


func _check(condition: bool, message: String) -> bool:
	if not condition:
		_failures.append(message)
		push_error(message)
	return condition


func _finish() -> void:
	if is_instance_valid(_drawer):
		_drawer.call("close")
	await _frames(3)
	if _failures.is_empty():
		print("[Flujo] Fluo drawer integration test passed")
	quit(0 if _failures.is_empty() else 1)
