@tool
extends SceneTree


const VIEWPORT_SIZE: Vector2i = Vector2i(1400, 850)
const LOGICAL_OFFSET: Vector2 = Vector2(340.0, 0.0)
const CONTROL_SIZE: Vector2 = Vector2(140.0, 76.0)


var _failures: Array[String] = []
var _viewport: SubViewport
var _host: Control
var _input_presses: int = 0
var _mouse_filter_child_presses: int = 0
var _mouse_filter_underlay_presses: int = 0


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	await _frames(2)
	_create_fixture()
	await _frames(4)

	await _test_enabled_and_position()
	await _test_visual_only_input()
	await _test_focus_preservation()
	await _test_mouse_filter()
	await _test_container_layout()
	await _test_scroll_container()
	await _test_neutral_rotation_and_scale()

	await _finish()


func _create_fixture() -> void:
	_viewport = SubViewport.new()
	_viewport.name = "FluoOffsetTransformCharacterizationViewport"
	_viewport.size = VIEWPORT_SIZE
	_viewport.gui_disable_input = false
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	get_root().add_child(_viewport)

	_host = Control.new()
	_host.name = "FluoOffsetTransformCharacterizationHost"
	_host.size = Vector2(VIEWPORT_SIZE)
	_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_viewport.add_child(_host)


func _test_enabled_and_position() -> void:
	var control: Control = _new_control(
		"DisabledOffsetTransformControl",
		Vector2(80.0, 72.0),
		CONTROL_SIZE
	)
	await _frames(2)

	var logical_transform: Transform2D = control.get_global_transform_with_canvas()
	control.offset_transform_position = LOGICAL_OFFSET
	control.offset_transform_rotation = 0.0
	control.offset_transform_scale = Vector2.ONE
	control.offset_transform_visual_only = false
	control.offset_transform_enabled = false
	await _frames(2)
	var disabled_transform: Transform2D = control.get_global_transform_with_canvas()
	_check(
		_transform_close(disabled_transform, logical_transform),
		"offset_transform_enabled=false leaves the effective transform unchanged after a non-zero position offset."
	)

	control.offset_transform_enabled = true
	await _frames(2)
	var enabled_transform: Transform2D = control.get_global_transform_with_canvas()
	_check(
		not _transform_close(enabled_transform, disabled_transform),
		"Enabling offset transforms changes the effective presentation transform rather than only returning a stored property."
	)
	_check(
		_vector_close(enabled_transform.origin - disabled_transform.origin, LOGICAL_OFFSET),
		"Enabled position offset moves the effective transform by the characterized offset; observed delta=%s." % (enabled_transform.origin - disabled_transform.origin)
	)
	_check(
		_vector_close(enabled_transform.x, disabled_transform.x) and _vector_close(enabled_transform.y, disabled_transform.y),
		"A neutral rotation and scale preserve the effective transform basis while position is offset."
	)


func _test_visual_only_input() -> void:
	var target: Button = Button.new()
	target.name = "VisualOnlyInputTarget"
	target.position = Vector2(100.0, 178.0)
	target.size = CONTROL_SIZE
	target.text = "Input target"
	target.focus_mode = Control.FOCUS_ALL
	target.mouse_filter = Control.MOUSE_FILTER_STOP
	target.pressed.connect(_on_input_target_pressed)
	_host.add_child(target)
	await _frames(3)

	var logical_transform: Transform2D = target.get_global_transform_with_canvas()
	var logical_point: Vector2 = logical_transform * (target.size * 0.5)
	target.offset_transform_position = LOGICAL_OFFSET
	target.offset_transform_rotation = 0.0
	target.offset_transform_scale = Vector2.ONE
	target.offset_transform_visual_only = false
	target.offset_transform_enabled = true
	await _frames(2)

	var rendered_transform_reference: Transform2D = target.get_global_transform_with_canvas()
	var visual_point: Vector2 = rendered_transform_reference * (target.size * 0.5)
	_check(
		_vector_close(rendered_transform_reference.origin - logical_transform.origin, LOGICAL_OFFSET),
		"The enabled offset produces the transformed presentation reference used by both visual-only modes; observed delta=%s." % (rendered_transform_reference.origin - logical_transform.origin)
	)
	target.offset_transform_visual_only = true
	await _frames(2)
	var visual_only_logical_transform: Transform2D = target.get_global_transform_with_canvas()
	_check(
		_transform_close(visual_only_logical_transform, logical_transform),
		"visual_only=true keeps the public logical transform at its original location while the presentation reference remains translated."
	)
	_check(
		logical_point.distance_to(visual_point) > CONTROL_SIZE.x,
		"The logical and transformed visual input probes are spatially separated for the real dispatch checks."
	)

	_input_presses = 0
	await _push_click(logical_point)
	_check(
		_input_presses == 1,
		"visual_only=true still receives a real click at the original logical region."
	)
	await _push_click(visual_point)
	_check(
		_input_presses == 1,
		"visual_only=true does not treat a click exclusively in the translated visual region as a logical hit."
	)

	target.offset_transform_visual_only = false
	await _frames(2)
	var non_visual_transform: Transform2D = target.get_global_transform_with_canvas()
	var non_visual_point: Vector2 = non_visual_transform * (target.size * 0.5)
	_check(
		_vector_close(non_visual_transform.origin - logical_transform.origin, LOGICAL_OFFSET),
		"visual_only=false keeps the transformed presentation position; observed visual delta=%s." % (non_visual_transform.origin - logical_transform.origin)
	)

	await _push_click(logical_point)
	_check(
		_input_presses == 1,
		"visual_only=false no longer accepts a click exclusively in the original logical region."
	)
	await _push_click(non_visual_point)
	_check(
		_input_presses == 2,
		"visual_only=false receives a real click at the transformed visual region."
	)


func _test_focus_preservation() -> void:
	var focus_target: Button = Button.new()
	focus_target.name = "OffsetTransformFocusTarget"
	focus_target.position = Vector2(80.0, 292.0)
	focus_target.size = CONTROL_SIZE
	focus_target.text = "Focus target"
	focus_target.focus_mode = Control.FOCUS_ALL
	focus_target.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_host.add_child(focus_target)
	await _frames(2)

	focus_target.grab_focus()
	await _frames(2)
	_check(
		_viewport.gui_get_focus_owner() == focus_target,
		"The focus fixture establishes the expected Control as SubViewport focus owner before transformation."
	)

	focus_target.offset_transform_position = LOGICAL_OFFSET
	focus_target.offset_transform_rotation = 0.0
	focus_target.offset_transform_scale = Vector2.ONE
	focus_target.offset_transform_enabled = true
	focus_target.offset_transform_visual_only = true
	await _frames(2)
	_check(
		_viewport.gui_get_focus_owner() == focus_target,
		"Applying an offset transform preserves the same focus owner."
	)

	focus_target.offset_transform_enabled = false
	await _frames(2)
	_check(
		_viewport.gui_get_focus_owner() == focus_target,
		"Disabling an offset transform does not silently replace the focus owner."
	)
	focus_target.offset_transform_position = Vector2.ZERO
	focus_target.offset_transform_rotation = 0.0
	focus_target.offset_transform_scale = Vector2.ONE
	await _frames(2)
	_check(
		_viewport.gui_get_focus_owner() == focus_target and is_instance_valid(_viewport.gui_get_focus_owner()),
		"Returning to the neutral transform preserves a valid focus owner."
	)


func _test_mouse_filter() -> void:
	var underlay: Button = Button.new()
	underlay.name = "MouseFilterUnderlay"
	underlay.position = Vector2(100.0, 414.0)
	underlay.size = Vector2(280.0, 76.0)
	underlay.text = "Underlay"
	underlay.z_index = 0
	underlay.mouse_filter = Control.MOUSE_FILTER_STOP
	underlay.pressed.connect(_on_mouse_filter_underlay_pressed)
	_host.add_child(underlay)

	var motion_shell: Control = Control.new()
	motion_shell.name = "MouseFilterMotionShell"
	motion_shell.position = underlay.position
	motion_shell.size = underlay.size
	motion_shell.z_index = 10
	motion_shell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_host.add_child(motion_shell)

	var child: Button = Button.new()
	child.name = "MouseFilterInteractiveChild"
	child.size = motion_shell.size
	child.text = "Interactive child"
	child.mouse_filter = Control.MOUSE_FILTER_STOP
	child.pressed.connect(_on_mouse_filter_child_pressed)
	motion_shell.add_child(child)
	await _frames(3)

	_check(
		motion_shell.mouse_filter == Control.MOUSE_FILTER_IGNORE,
		"The MotionShell-like parent uses MOUSE_FILTER_IGNORE."
	)
	_check(
		child.mouse_filter == Control.MOUSE_FILTER_STOP,
		"The interactive child uses MOUSE_FILTER_STOP."
	)

	_mouse_filter_child_presses = 0
	_mouse_filter_underlay_presses = 0
	var click_point: Vector2 = underlay.get_global_transform_with_canvas() * (underlay.size * 0.5)
	await _push_click(click_point)
	_check(
		_mouse_filter_child_presses == 1,
		"An IGNORE parent does not prevent its STOP child from receiving a real click."
	)
	_check(
		_mouse_filter_underlay_presses == 0,
		"The STOP child consumes the expected event instead of allowing it to reach the underlay."
	)


func _test_container_layout() -> void:
	var motion_shell: Control = _new_control(
		"ContainerMotionShell",
		Vector2(70.0, 532.0),
		Vector2(320.0, 180.0)
	)
	var container: VBoxContainer = VBoxContainer.new()
	container.name = "ContainerManagedContent"
	container.position = Vector2.ZERO
	container.size = motion_shell.size
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	motion_shell.add_child(container)

	var rows: Array[Control] = []
	for index: int in 3:
		var row: Button = Button.new()
		row.name = "ContainerRow%d" % index
		row.text = "Logical row %d" % index
		row.custom_minimum_size = Vector2(280.0, 44.0)
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		container.add_child(row)
		rows.append(row)
	await _frames(5)

	var logical_shell_transform: Transform2D = motion_shell.get_global_transform_with_canvas()
	var logical_container_position: Vector2 = container.position
	var logical_container_size: Vector2 = container.size
	var logical_row_positions: Array[Vector2] = []
	var logical_row_sizes: Array[Vector2] = []
	for row: Control in rows:
		logical_row_positions.append(row.position)
		logical_row_sizes.append(row.size)

	_check(
		rows[0].size.x > 0.0 and rows[1].position.y > rows[0].position.y and rows[2].position.y > rows[1].position.y,
		"The Container performs a real logical vertical layout for its child Controls."
	)

	motion_shell.offset_transform_position = LOGICAL_OFFSET
	motion_shell.offset_transform_rotation = 0.0
	motion_shell.offset_transform_scale = Vector2.ONE
	motion_shell.offset_transform_enabled = true
	motion_shell.offset_transform_visual_only = false
	await _frames(3)

	var transformed_shell: Transform2D = motion_shell.get_global_transform_with_canvas()
	_check(
		_vector_close(transformed_shell.origin - logical_shell_transform.origin, LOGICAL_OFFSET),
		"The outer shell presentation moves by the offset while its logical layout remains addressable."
	)
	_check(
		_vector_close(container.position, logical_container_position) and _vector_close(container.size, logical_container_size),
		"The Container keeps its logical position and size after the wrapper offset transform."
	)
	for index: int in rows.size():
		_check(
			_vector_close(rows[index].position, logical_row_positions[index]) \
				and _vector_close(rows[index].size, logical_row_sizes[index]),
			"Container-managed child %d keeps its logical position and size after the wrapper offset transform." % index
		)


func _test_scroll_container() -> void:
	var motion_shell: Control = _new_control(
		"ScrollMotionShell",
		Vector2(70.0, 250.0),
		Vector2(360.0, 210.0)
	)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.name = "NativeScrollContainer"
	scroll.size = motion_shell.size
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.mouse_filter = Control.MOUSE_FILTER_IGNORE
	motion_shell.add_child(scroll)

	var content: VBoxContainer = VBoxContainer.new()
	content.name = "LargeScrollContent"
	content.custom_minimum_size = Vector2(340.0, 900.0)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scroll.add_child(content)
	for index: int in 18:
		var row: Label = Label.new()
		row.name = "ScrollRow%d" % index
		row.text = "Scrollable logical row %d" % index
		row.custom_minimum_size = Vector2(340.0, 44.0)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.add_child(row)
	await _frames(6)

	scroll.scroll_vertical = 0
	await _frames(2)
	var vertical_bar: VScrollBar = scroll.get_v_scroll_bar()
	if not _check(vertical_bar != null, "The ScrollContainer exposes its native vertical scrollbar."):
		return

	var logical_content_position: Vector2 = content.position
	var logical_content_size: Vector2 = content.size
	var logical_scroll_size: Vector2 = scroll.size
	var range_max: float = vertical_bar.max_value
	var range_page: float = vertical_bar.page
	var logical_shell_transform: Transform2D = motion_shell.get_global_transform_with_canvas()
	_check(
		range_max > range_page,
		"The large content produces a native vertical scroll range; max=%f page=%f." % [range_max, range_page]
	)
	_check(
		vertical_bar.is_visible_in_tree(),
		"The native vertical scrollbar is visible for the overflowing logical content."
	)

	motion_shell.offset_transform_position = LOGICAL_OFFSET
	motion_shell.offset_transform_rotation = 0.0
	motion_shell.offset_transform_scale = Vector2.ONE
	motion_shell.offset_transform_enabled = true
	motion_shell.offset_transform_visual_only = false
	await _frames(3)

	var transformed_shell: Transform2D = motion_shell.get_global_transform_with_canvas()
	_check(
		_vector_close(transformed_shell.origin - logical_shell_transform.origin, LOGICAL_OFFSET),
		"The ScrollContainer wrapper presents at the offset position."
	)
	_check(
		_vector_close(content.position, logical_content_position) \
			and _vector_close(content.size, logical_content_size) \
			and _vector_close(scroll.size, logical_scroll_size),
		"Wrapper presentation does not alter ScrollContainer or content logical geometry."
	)
	_check(
		_is_close(vertical_bar.max_value, range_max) and _is_close(vertical_bar.page, range_page),
		"Wrapper presentation does not alter the native scrollbar range/page; max=%f page=%f." % [vertical_bar.max_value, vertical_bar.page]
	)

	var target_scroll: int = maxi(1, int(floor(range_max - range_page)))
	scroll.scroll_vertical = target_scroll
	await _frames(3)
	_check(
		scroll.scroll_vertical > 0,
		"Native ScrollContainer scrolling still changes scroll_vertical after the wrapper offset transform."
	)
	_check(
		content.position.y < logical_content_position.y - 0.5,
		"Native ScrollContainer scrolling still moves logical content through its viewport."
	)


func _test_neutral_rotation_and_scale() -> void:
	var control: Control = _new_control(
		"NeutralOffsetTransformResetControl",
		Vector2(520.0, 72.0),
		CONTROL_SIZE
	)
	await _frames(2)
	var logical_transform: Transform2D = control.get_global_transform_with_canvas()
	_check(
		is_zero_approx(control.offset_transform_rotation) and _vector_close(control.offset_transform_scale, Vector2.ONE),
		"Neutral offset-transform values are rotation 0.0 and scale Vector2.ONE."
	)

	control.offset_transform_enabled = true
	control.offset_transform_position = LOGICAL_OFFSET
	control.offset_transform_rotation = 0.0
	control.offset_transform_scale = Vector2.ONE
	control.offset_transform_visual_only = true
	await _frames(2)
	control.offset_transform_position = Vector2.ZERO
	control.offset_transform_rotation = 0.0
	control.offset_transform_scale = Vector2.ONE
	await _frames(2)
	_check(
		_transform_close(control.get_global_transform_with_canvas(), logical_transform),
		"Resetting position to zero with rotation 0.0 and scale Vector2.ONE restores the neutral effective transform."
	)


func _new_control(node_name: String, control_position: Vector2, control_size: Vector2) -> Control:
	var control: Control = Control.new()
	control.name = node_name
	control.position = control_position
	control.size = control_size
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_host.add_child(control)
	return control


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
	await _frames(2)


func _on_input_target_pressed() -> void:
	_input_presses += 1


func _on_mouse_filter_child_pressed() -> void:
	_mouse_filter_child_presses += 1


func _on_mouse_filter_underlay_pressed() -> void:
	_mouse_filter_underlay_presses += 1


func _frames(count: int = 3) -> void:
	for _index: int in count:
		await process_frame


func _vector_close(first: Vector2, second: Vector2, tolerance: float = 0.05) -> bool:
	return first.distance_to(second) <= tolerance


func _transform_close(first: Transform2D, second: Transform2D, tolerance: float = 0.05) -> bool:
	return _vector_close(first.origin, second.origin, tolerance) \
		and _vector_close(first.x, second.x, tolerance) \
		and _vector_close(first.y, second.y, tolerance)


func _is_close(first: float, second: float, tolerance: float = 0.05) -> bool:
	return absf(first - second) <= tolerance


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
		print("[Flujo] Fluo offset transform characterization test passed")
	quit(0 if _failures.is_empty() else 1)
