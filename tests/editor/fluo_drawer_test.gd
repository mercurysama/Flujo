@tool
extends SceneTree

const FLUO_DRAWER_SCRIPT: Script = preload("res://addons/vp_flujo/editor/fluo_drawer.gd")

var _failures: Array[String] = []
var _viewport: SubViewport
var _host: Control
var _sentinel: Button
var _focus_target: LineEdit
var _drawer: Control
var _motion_shell: Control
var _drawer_panel: PanelContainer
var _sentinel_clicks: int = 0
var _sentinel_key_events: int = 0


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	await _frames()
	while EditorInterface.get_resource_filesystem().is_scanning():
		await process_frame
	_create_fixture()
	await _frames(3)

	var backdrop: Control = _drawer.get_node("Backdrop") as Control
	_motion_shell = _drawer.get_node("DrawerMotionShell") as Control
	_drawer_panel = _drawer.get_node("DrawerMotionShell/DrawerPanel") as PanelContainer
	_check(not _drawer_is_open(), "Fluo starts closed.")
	_check(not _drawer.visible, "A closed Fluo is not visible.")
	_check(_drawer.get_child_count() == 2, "Fluo creates exactly Backdrop and DrawerMotionShell once.")
	_check(_drawer.get_child(0) == backdrop, "Backdrop is the first top-level Fluo child.")
	_check(_drawer.get_child(1) == _motion_shell, "DrawerMotionShell is the second top-level Fluo child.")
	_check(_motion_shell != null, "Fluo has one DrawerMotionShell.")
	_check(_motion_shell != null and _motion_shell.get_child_count() == 1, "DrawerMotionShell owns exactly one child.")
	_check(_drawer_panel != null and _drawer_panel.get_parent() == _motion_shell, "DrawerPanel is a child of DrawerMotionShell.")
	_check(_drawer_panel != null and _motion_shell.get_child(0) == _drawer_panel, "DrawerMotionShell's only child is DrawerPanel.")
	_check(backdrop != null and backdrop.mouse_filter == Control.MOUSE_FILTER_STOP, "Backdrop stops exterior mouse input.")
	_check(_motion_shell != null and _motion_shell.mouse_filter == Control.MOUSE_FILTER_IGNORE, "DrawerMotionShell ignores mouse input so its child remains interactive.")
	_check(_drawer_panel != null and _drawer_panel.mouse_filter == Control.MOUSE_FILTER_STOP, "DrawerPanel consumes its own input.")
	_check(_motion_shell != null and _motion_shell.z_index > backdrop.z_index, "DrawerMotionShell is layered above Backdrop.")
	_check(_drawer_panel != null and _drawer_panel.z_index > backdrop.z_index, "DrawerPanel keeps a relative z ordering above Backdrop through the shell.")
	_check(backdrop != null and backdrop.get_signal_connection_list(&"gui_input").size() == 1, "Backdrop has one input callback.")
	_check(_drawer.call("_motion_state_name") == &"CLOSED", "Initial editor-only motion state is CLOSED.")
	_check(_neutral_offset_transform(), "DrawerMotionShell starts with a neutral enabled offset transform.")
	_check(_shell_uses_left_layout(), "Left placement belongs to DrawerMotionShell.")
	_check(_panel_fills_shell(), "DrawerPanel fills DrawerMotionShell with zero offsets.")
	_check(_drawer_script_has_no_animation(), "D2-B2 creates no Tween or animation path.")

	await _push_click(_sentinel_global_position())
	_check(_sentinel_clicks == 1, "The sentinel receives a click while Fluo is closed.")

	_sentinel.grab_focus()
	await _frames(2)
	_open_drawer()
	_check(_drawer_is_open(), "Opening Fluo changes its public open state.")
	_check(_drawer.visible, "Opening Fluo makes the overlay visible.")
	_check(_drawer.call("_motion_state_name") == &"OPEN", "Opening completes synchronously in OPEN.")
	_check(_viewport.gui_get_focus_owner() == _sentinel, "Opening Fluo preserves the current focus owner.")
	_check(_drawer.get_child_count() == 2, "Opening Fluo does not duplicate top-level nodes.")
	var close_button: Button = _drawer.find_child("CloseFluoButton", true, false) as Button
	_check(close_button != null and close_button.text == "✕", "Fluo exposes a top close button.")
	_check(close_button != null and close_button.custom_minimum_size.x >= 44.0 and close_button.custom_minimum_size.y >= 44.0, "Fluo top close button keeps an Android-friendly touch target.")
	if close_button != null:
		close_button.pressed.emit()
	_check(not _drawer_is_open(), "Fluo top close button closes the drawer.")
	_open_drawer()
	_open_drawer()
	_check(_drawer.get_child_count() == 2 and _motion_shell.get_child_count() == 1, "Repeated opening does not duplicate nodes or callbacks.")

	_drawer.call("set_right_side", true)
	_check(_drawer.call("is_right_side"), "Open side switch changes the semantic side to right.")
	_check(_drawer.call("_motion_state_name") == &"OPEN", "Open side switch completes synchronously in OPEN.")
	_check(_shell_uses_right_layout(), "Right placement belongs to DrawerMotionShell.")
	_check(_panel_fills_shell(), "DrawerPanel continues to fill the shell after side switch.")
	_drawer.call("set_right_side", true)
	_check(_drawer.call("_motion_state_name") == &"OPEN", "Repeated side selection is a logical no-op while OPEN.")

	var clicks_before_exterior: int = _sentinel_clicks
	await _push_click(_sentinel_global_position())
	_check(not _drawer_is_open(), "A click outside the panel closes Fluo.")
	_check(_drawer.call("_motion_state_name") == &"CLOSED", "Exterior close completes synchronously in CLOSED.")
	_check(_sentinel_clicks == clicks_before_exterior, "The exterior click is consumed and does not reach the sentinel.")
	_check(_viewport.gui_get_focus_owner() == _sentinel, "Closing from an exterior click restores valid focus.")

	_drawer.call("set_right_side", false)
	_check(not _drawer.call("is_right_side") and _drawer.call("_motion_state_name") == &"CLOSED", "Closed side switch changes layout but remains CLOSED.")
	_check(_shell_uses_left_layout(), "Closed side switch restores left shell placement without opening Fluo.")

	_open_drawer()
	var key_events_before_escape: int = _sentinel_key_events
	await _push_key(KEY_ESCAPE)
	_check(not _drawer_is_open(), "Escape closes an open Fluo.")
	_check(_drawer.call("_motion_state_name") == &"CLOSED", "Escape close completes synchronously in CLOSED.")
	_check(_sentinel_key_events == key_events_before_escape, "Escape is consumed instead of reaching the focused control.")
	_check(_viewport.gui_get_focus_owner() == _sentinel, "Escape restores the valid previous focus.")

	_open_drawer()
	_close_drawer()
	_check(not _drawer_is_open(), "Explicit close closes Fluo.")
	_check(not _drawer.visible, "Explicit close hides the overlay.")
	_check(_drawer.call("_motion_state_name") == &"CLOSED", "Explicit close ends CLOSED.")
	_check(_neutral_offset_transform(), "Close leaves the shell transform neutral.")

	_motion_shell.offset_transform_enabled = false
	_motion_shell.offset_transform_position = Vector2(120.0, 0.0)
	_motion_shell.offset_transform_rotation = 0.4
	_motion_shell.offset_transform_scale = Vector2(1.2, 0.8)
	_motion_shell.offset_transform_visual_only = true
	_drawer.call("_reset_motion_state")
	_check(_neutral_offset_transform(), "The centralized reset restores every neutral shell transform setting.")

	for _index: int in 8:
		_open_drawer()
		_close_drawer()
	_check(_drawer.get_child_count() == 2 and _motion_shell.get_child_count() == 1, "Repeated open and close keeps one node hierarchy.")
	_check(backdrop.get_signal_connection_list(&"gui_input").size() == 1, "Repeated open and close keeps one backdrop callback.")
	_check(_drawer.call("_motion_state_name") == &"CLOSED", "Repeated close remains CLOSED and idempotent.")

	_focus_target.grab_focus()
	await _frames(2)
	_open_drawer()
	_focus_target.queue_free()
	await _frames(2)
	_close_drawer()
	_check(not _drawer_is_open(), "Closing after the saved focus control exits remains safe.")

	await _finish()


func _create_fixture() -> void:
	_viewport = SubViewport.new()
	_viewport.name = "FluoDrawerTestViewport"
	_viewport.size = Vector2i(640, 360)
	_viewport.gui_disable_input = false
	get_root().add_child(_viewport)

	_host = Control.new()
	_host.name = "FluoDrawerTestHost"
	_host.position = Vector2.ZERO
	_host.size = Vector2(640.0, 360.0)
	_host.z_index = 1000
	_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_viewport.add_child(_host)

	_sentinel = Button.new()
	_sentinel.name = "ClickSentinel"
	_sentinel.text = "Sentinel"
	_sentinel.position = Vector2(16.0, 16.0)
	_sentinel.size = Vector2(140.0, 64.0)
	_sentinel.focus_mode = Control.FOCUS_ALL
	_sentinel.pressed.connect(_on_sentinel_pressed)
	_sentinel.gui_input.connect(_on_sentinel_gui_input)
	_host.add_child(_sentinel)

	_focus_target = LineEdit.new()
	_focus_target.name = "FocusTarget"
	_focus_target.position = Vector2(16.0, 100.0)
	_focus_target.size = Vector2(220.0, 32.0)
	_focus_target.focus_mode = Control.FOCUS_ALL
	_host.add_child(_focus_target)

	_drawer = FLUO_DRAWER_SCRIPT.new() as Control
	_host.add_child(_drawer)


func _open_drawer() -> void:
	_drawer.call(&"open")


func _close_drawer() -> void:
	_drawer.call(&"close")


func _drawer_is_open() -> bool:
	return bool(_drawer.call(&"is_open"))


func _sentinel_global_position() -> Vector2:
	return _sentinel.global_position + Vector2(24.0, 24.0)


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


func _panel_fills_shell() -> bool:
	return _drawer_panel != null \
		and is_zero_approx(_drawer_panel.anchor_left) \
		and is_equal_approx(_drawer_panel.anchor_right, 1.0) \
		and is_zero_approx(_drawer_panel.anchor_top) \
		and is_equal_approx(_drawer_panel.anchor_bottom, 1.0) \
		and is_zero_approx(_drawer_panel.offset_left) \
		and is_zero_approx(_drawer_panel.offset_top) \
		and is_zero_approx(_drawer_panel.offset_right) \
		and is_zero_approx(_drawer_panel.offset_bottom)


func _drawer_script_has_no_animation() -> bool:
	var source: String = FileAccess.get_file_as_string("res://addons/vp_flujo/editor/fluo_drawer.gd")
	return not source.contains("create_tween") \
		and not source.contains("Tween") \
		and not source.contains("AnimationPlayer") \
		and not source.contains("Timer")


func _push_click(position: Vector2) -> void:
	var press: InputEventMouseButton = InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.position = position
	press.pressed = true
	_viewport.push_input(press, true)
	await process_frame
	var release: InputEventMouseButton = InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.position = position
	release.pressed = false
	_viewport.push_input(release, true)
	await process_frame


func _push_key(keycode: Key) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.keycode = keycode
	event.pressed = true
	_viewport.push_input(event, true)
	await process_frame


func _on_sentinel_pressed() -> void:
	_sentinel_clicks += 1


func _on_sentinel_gui_input(event: InputEvent) -> void:
	if event is InputEventKey:
		_sentinel_key_events += 1


func _frames(count: int = 3) -> void:
	for _index: int in count:
		await process_frame


func _check(condition: bool, message: String) -> bool:
	if not condition:
		_failures.append(message)
		push_error(message)
	return condition


func _finish() -> void:
	if is_instance_valid(_host):
		_host.queue_free()
	if is_instance_valid(_viewport):
		_viewport.queue_free()
	await _frames(4)
	if _failures.is_empty():
		print("[Flujo] Fluo drawer test passed")
	quit(0 if _failures.is_empty() else 1)
