@tool
extends SceneTree

const FLUO_DRAWER_SCRIPT: Script = preload("res://addons/vp_flujo/editor/fluo_drawer.gd")

var _failures: Array[String] = []
var _base_control: Control
var _drawer: FluoDrawer
var _motion_shell: Control
var _drawer_panel: PanelContainer
var _fixture: PVController
var _focus_trigger: Button


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	await _frames()
	while EditorInterface.get_resource_filesystem().is_scanning():
		await process_frame
	_base_control = EditorInterface.get_base_control()
	if not _check(_base_control != null, "The Godot editor base is available."):
		await _finish()
		return

	var plugin_source: String = FileAccess.get_file_as_string("res://addons/vp_flujo/plugin.gd")
	_check(
		get_root().find_child("VPFlujoDock", true, false) == null \
			and not plugin_source.contains("add_dock(") \
			and not plugin_source.contains("remove_dock("),
		"The legacy VPFlujoDock is neither mounted nor registered by the plugin."
	)
	_check(
		plugin_source.contains('add_tool_menu_item("Open Fluo"') \
			and plugin_source.contains("_on_fluo_open_requested"),
		"The Open Fluo editor command remains available without the legacy dock."
	)
	_check(
		FlowInteractionCoordinator.create_default_shortcut().matches_event(_f4_event()),
		"The F4 shortcut remains registered independently of the legacy dock."
	)

	var drawers: Array[FluoDrawer] = _find_drawers(_base_control)
	_check(drawers.size() == 1, "The plugin mounts exactly one FluoDrawer instance.")
	if drawers.is_empty():
		await _finish()
		return
	_drawer = drawers[0]
	_check(_drawer.get_parent() == _base_control, "FluoDrawer is mounted on the editor base as an overlay.")
	_check(_drawer.find_child("FluoFlowEditor", true, false) != null, "Fluo owns the mounted Flow editor surface.")
	_check(_find_node(_drawer, "InspectorBlocksList") == null, "Fluo does not add a duplicate Blocks list to the Inspector.")

	_motion_shell = _drawer.get_node("DrawerMotionShell") as Control
	_drawer_panel = _drawer.get_node("DrawerMotionShell/DrawerPanel") as PanelContainer
	_check(_drawer.get_child_count() == 2, "The mounted drawer has exactly Backdrop and DrawerMotionShell.")
	_check(_motion_shell != null, "The mounted drawer has one MotionShell.")
	_check(_motion_shell != null and _motion_shell.get_child_count() == 1, "The mounted MotionShell has one DrawerPanel child.")
	_check(_drawer_panel != null and _drawer_panel.get_parent() == _motion_shell, "The mounted DrawerPanel is inside MotionShell.")
	_check(_neutral_offset_transform(), "The mounted MotionShell starts with a neutral offset transform.")

	_focus_trigger = Button.new()
	_focus_trigger.name = &"OpenFluoTestFocusTrigger"
	_focus_trigger.focus_mode = Control.FOCUS_ALL
	_focus_trigger.text = "Open Fluo"
	_base_control.add_child(_focus_trigger)
	_focus_trigger.grab_focus()
	_drawer.open()
	_check(bool(_drawer.call("is_open")), "Open Fluo opens the mounted drawer.")
	_check(_drawer.visible, "Opening Fluo makes the overlay visible.")
	_check(_find_drawers(_base_control).size() == 1, "Opening Fluo does not create a second drawer.")
	_check(_neutral_offset_transform(), "Opening leaves the mounted MotionShell visually neutral.")

	_drawer.open()
	_check(bool(_drawer.call("is_open")), "Repeated Open Fluo reuses the open drawer.")
	_check(_find_drawers(_base_control).size() == 1, "Repeated opening keeps exactly one drawer instance.")
	_check(_motion_shell.get_child_count() == 1, "Repeated opening keeps exactly one DrawerPanel in the shell.")

	_drawer.set_right_side(true)
	_check(_shell_uses_right_layout(), "The mounted shell owns right-side logical placement.")
	_check(_neutral_offset_transform(), "Right-side switching remains visually neutral.")
	_drawer.set_right_side(false)
	_check(_shell_uses_left_layout(), "The mounted shell can return to left-side logical placement.")
	_check(_neutral_offset_transform(), "Returning left leaves the transform neutral.")

	var escape: InputEventKey = InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	_drawer.call("_input", escape)
	_check(not bool(_drawer.call("is_open")), "Escape closes Fluo without a legacy dock context.")
	_check(_focus_trigger.has_focus(), "Escape restores focus to the prior editor control.")
	_check(_neutral_offset_transform(), "Escape close leaves no visible offset on the mounted shell.")

	await _exercise_flow_and_flusso()

	_drawer.open()
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


func _exercise_flow_and_flusso() -> void:
	_fixture = PVController.new()
	_fixture.name = &"FluoIntegrationFixture"
	var graph: FlowGraph = FlowGraph.new()
	graph.schema_version = FlowGraph.SCHEMA_VERSION_3
	graph.constructor = FlowConstructorDefinition.new()
	var process: FlowProcess = FlowProcess.new()
	process.display_name = "Integration Process"
	graph.processes = [process]
	_fixture.flow_graph = graph
	_base_control.add_child(_fixture)
	_drawer.open_container(
		_fixture,
		FlowGraphEditorCommands.Collection.PROCESSES,
		process.get_internal_id()
	)
	await _frames(3)

	var editor: FlowReadyProcessEditor = _drawer.find_child("ReadyProcessEditor", true, false) as FlowReadyProcessEditor
	_check(editor != null, "Flow renders inside the primary Fluo surface.")
	var add_fprint: Button = _find_button(editor, "Add FPrint")
	_check(add_fprint != null, "Flow Add exposes FPrint through the normal catalog path.")
	if add_fprint == null:
		return
	add_fprint.pressed.emit()
	await _frames(3)
	_check(process.blocks.size() == 1 and process.blocks[0] is FlowOutputBlock, "Flow Add still creates a generic output block.")
	editor = _drawer.find_child("ReadyProcessEditor", true, false) as FlowReadyProcessEditor
	var blocks: ItemList = editor.find_child("ReadyBlocksList", true, false) as ItemList if editor != null else null
	_check(blocks != null and blocks.item_count == 1, "Flow keeps the added FPrint row visible.")
	if blocks == null:
		return
	blocks.item_activated.emit(0)
	await _frames(3)
	var options: PanelContainer = _drawer.find_child("BlockOptionsPanel", true, false) as PanelContainer
	_check(options != null and options.visible, "Flusso opens from the selected Flow block.")
	_check(_drawer.find_child("GenericPropertyText_prefix", true, false) != null, "Flusso renders FPrint through the generic property surface.")


func _find_button(root: Node, button_text: String) -> Button:
	if root == null:
		return null
	if root is Button and (root as Button).text == button_text:
		return root as Button
	for child: Node in root.get_children():
		var button: Button = _find_button(child, button_text)
		if button != null:
			return button
	return null


func _find_node(root: Node, node_name: String) -> Node:
	if root == null:
		return null
	if root.name == node_name:
		return root
	return root.find_child(node_name, true, false)


func _find_drawers(root: Node) -> Array[FluoDrawer]:
	var drawers: Array[FluoDrawer] = []
	if root.get_script() == FLUO_DRAWER_SCRIPT and root is FluoDrawer:
		drawers.append(root as FluoDrawer)
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
		_drawer.close()
	if is_instance_valid(_fixture):
		_fixture.queue_free()
	if is_instance_valid(_focus_trigger):
		_focus_trigger.queue_free()
	await _frames(3)
	if _failures.is_empty():
		print("[Flujo] Fluo drawer integration test passed")
	quit(0 if _failures.is_empty() else 1)
