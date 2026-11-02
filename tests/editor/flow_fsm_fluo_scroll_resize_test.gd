@tool
extends SceneTree

## Potok 7E-3A: actual native Fluo scroll range on long FSM data and host resize.
const WIDE: Vector2i = Vector2i(1200, 800)
const NARROW: Vector2i = Vector2i(480, 640)

var failures: Array[String] = []
var _viewport: SubViewport
var _host: Control
var _drawer: FluoDrawer
var _controller: PVController
var _graph: FlowGraph
var _machine: FlowStateMachineDefinition
var _state: FlowStateDefinition
var _edge: FlowStateTransitionDefinition
var _scroll: ScrollContainer
var _shell: Control
var _panel: PanelContainer


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	for _i: int in 5:
		await process_frame
	while EditorInterface.get_resource_filesystem().is_scanning():
		await process_frame

	var undo: EditorUndoRedoManager = EditorInterface.get_editor_undo_redo()
	if not _check(undo != null, "Editor history available"):
		quit(1)
		return

	_viewport = SubViewport.new()
	_viewport.name = "Potok7E3AViewport"
	_viewport.size = WIDE
	_viewport.gui_disable_input = false
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	get_root().add_child(_viewport)
	_host = Control.new()
	_host.name = "Potok7E3AHost"
	_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_host.size = Vector2(WIDE)
	_viewport.add_child(_host)

	_graph = FlowGraph.new()
	_graph.schema_version = FlowGraph.SCHEMA_VERSION_3
	_graph.constructor = FlowConstructorDefinition.new()
	_state = FlowStateDefinition.new()
	_state.display_name = "Selected state with long content"
	_state.user_note = "State " + "note content ".repeat(25)
	var states: Array[FlowStateDefinition] = [_state]
	for i: int in 24:
		var other := FlowStateDefinition.new()
		other.display_name = "Alternative state %02d — " % i + "abcdefghijklmnopqrstuvwxyz".repeat(5)
		states.append(other)

	var edges: Array[FlowStateTransitionDefinition] = []
	for i: int in 12:
		var edge := FlowStateTransitionDefinition.new()
		edge.display_name = "Transition %02d — " % i + "xyz".repeat(60)
		edge.trigger = FlowStateTransitionDefinition.Trigger.EVENT
		edge.event_name = StringName("event_%02d" % i)
		edge.target_state_id = states[(i + 1) % states.size()].get_internal_id()
		edge.user_note = "Long transition setting " + "notes ".repeat(40)
		edges.append(edge)
	_edge = edges[0]
	_state.transitions = edges

	var phase_blocks: Array[FlowBlock] = []
	for i: int in 12:
		var block := FlowPrintBlock.new()
		block.text = "Phase content %02d" % i
		phase_blocks.append(block)
	_state.enter_blocks = phase_blocks

	_machine = FlowStateMachineDefinition.new()
	_machine.display_name = "Long authoring settings — " + "ABCDEFGHIJKLMNOPQRSTUVWXYZ".repeat(18)
	_machine.states = states
	_machine.initial_state_id = _state.get_internal_id()
	_machine.user_note = "Long machine note " + "text ".repeat(50)
	_graph.state_machines = [_machine]
	_controller = PVController.new()
	_controller.name = "Controller"
	_controller.flow_graph = _graph
	_host.add_child(_controller)
	_check(not FlowGraphValidator.validate(_graph).has_errors(),
		"Long authored 25-state 12-edge schema-3 graph validates")

	_drawer = FluoDrawer.new()
	_host.add_child(_drawer)
	_drawer.configure(undo)
	_drawer.open_container(
		_controller, FlowGraphEditorCommands.Collection.STATE_MACHINES,
		_machine.get_internal_id()
	)
	await _frames(7)
	_scroll = _drawer.find_child("FluoEditorScroll", true, false) as ScrollContainer
	_shell = _drawer.get_node_or_null("DrawerMotionShell") as Control
	_panel = _drawer.get_node_or_null("DrawerMotionShell/DrawerPanel") as PanelContainer
	if not _check(_drawer.is_open() and _scroll != null and _shell != null
			and _panel != null, "Mounted actual Fluo drawer and native editor scroll exist"):
		await _finish()
		return
	_check(_drawer.find_child("FluoFlowEditor", true, false) != null
		and _drawer.find_child("PotokMachineProperties", true, false) != null
		and _drawer.find_child("PotokStateProperties", true, false) != null
		and _drawer.find_child("PotokTransitionProperties", true, false)
		and _drawer.find_child("PotokTransitionRevert", true, false) != null,
		"Real Potok machine/state/transition Flusso and Revertir fields render")
	_check(_scroll.vertical_scroll_mode == ScrollContainer.SCROLL_MODE_AUTO
		and _scroll.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_AUTO
		and _scroll.clip_contents and _scroll.follow_focus,
		"Native viewport enables AUTO vertical and horizontal overflow and focus-follow")
	_check(_scroll.get_v_scroll_bar() != null and
		_scroll.get_h_scroll_bar() != null,
		"Native scrollbars exist without substituting manual scroll controls")

	await _check_geometry("wide-left", WIDE, false)
	_check(await _can_scroll_vertical(), "Wide view can reach long authored content vertically")

	await _resize(NARROW)
	await _check_geometry("narrow-left", NARROW, false)
	_check(await _can_scroll_vertical(), "Portrait-width view retains real vertical scroll range")
	_check(await _can_scroll_horizontal(), "Portrait-width view scrolls overflowing content horizontally")
	var content: VBoxContainer = _drawer.find_child(
		"FluoEditorScrollContent", true, false
	) as VBoxContainer
	_check(content != null and content.get_child_count() == 1,
		"Single original Flow editor remains inside the native content container")

	_scroll.scroll_vertical = 0
	_scroll.scroll_horizontal = 0
	var list: ItemList = _drawer.find_child("PotokStateList", true, false) as ItemList
	var last: Button = _drawer.find_child("PotokTransitionRevert", true, false) as Button
	if _check(list != null and last != null and last.is_visible_in_tree(),
			"Selected state and final Revertir are native focusable controls"):
		list.grab_focus()
		await _frames(3)
		_scroll.scroll_vertical = 0
		await _frames(3)
		last.grab_focus()
		await _frames(5)
		_check(last.has_focus() and _scroll.scroll_vertical > 0,
			"Focus-follow reveals below-the-fold Transition Revertir after scrolling")

	_drawer.set_right_side(true)
	await _frames(4)
	await _check_geometry("narrow-right", NARROW, true)
	_check(await _can_scroll_vertical() and await _can_scroll_horizontal(),
		"Right-side placement retains horizontal/vertical scroll reachability")
	await _resize(WIDE)
	await _check_geometry("wide-right", WIDE, true)
	_drawer.set_right_side(false)
	await _frames(4)
	await _check_geometry("wide-left-returned", WIDE, false)

	var editor: FlowGraphInspectorProperty = _drawer.find_child(
		"FluoFlowEditor", true, false
	) as FlowGraphInspectorProperty
	_check(editor != null and String(editor.get("_selected_id")) == _machine.get_internal_id()
		and String(editor.get("_potok_selected_state_id")) == _state.get_internal_id()
		and String(editor.get("_potok_selected_transition_id")) == _edge.get_internal_id(),
		"Resize and side toggles preserve stable machine, state and edge IDs")
	_check(_graph.state_machines.size() == 1 and _machine.states.size() == 25
		and _state.transitions.size() == 12
		and _state.enter_blocks.size() == 12
		and not FlowGraphValidator.validate(_graph).has_errors(),
		"Scrolling, focus and resize never author or mutate FSM model data")
	await _finish()


func _resize(dimensions: Vector2i) -> void:
	_viewport.size = dimensions
	_host.size = Vector2(dimensions)
	await _frames(6)


func _check_geometry(stage: String, dimensions: Vector2i, right: bool) -> void:
	await _frames(4)
	var expected_width: float = float(dimensions.x) * 0.46
	var expected_left: float = float(dimensions.x) - expected_width if right else 0.0
	_check(absf(_shell.size.x - expected_width) <= 2.0 and
		absf(_shell.position.x - expected_left) <= 2.0 and
		absf(_shell.size.y - float(dimensions.y)) <= 2.0,
		stage + ": shell preserves existing 46% width and logical side placement")
	_check(_panel.size.x > 0.0 and _panel.size.y > 0.0 and
		_panel.size.x <= _shell.size.x + 2.0 and
		_panel.size.y <= _shell.size.y + 2.0,
		stage + ": native DrawerPanel fits finite positive shell bounds")
	_check(_scroll.size.x > 0.0 and _scroll.size.y > 0.0 and
		_scroll.size.x <= _panel.size.x + 2.0 and
		_scroll.size.y <= _panel.size.y + 2.0,
		stage + ": scroll viewport fits the resized drawer panel")
	_check(_drawer.find_child("CloseFluoButton", true, false) != null and
		(_drawer.find_child("CloseFluoButton", true, false) as Button).custom_minimum_size == Vector2(44.0, 44.0),
		stage + ": accessible close target remains unchanged after layout")
	_check(_shell.offset_transform_position == Vector2.ZERO and
		_shell.offset_transform_scale == Vector2.ONE and
		is_zero_approx(_shell.offset_transform_rotation),
		stage + ": motion transform remains neutral after resize")
	_check(_drawer.get_child_count() == 2 and _shell.get_child_count() == 1,
		stage + ": no duplicate backdrop or drawer panel")


func _can_scroll_vertical() -> bool:
	var bar: VScrollBar = _scroll.get_v_scroll_bar()
	if bar == null or bar.max_value <= bar.page + 1.0:
		return false
	_scroll.scroll_vertical = 0
	await _frames(2)
	_scroll.scroll_vertical = int(minf(bar.max_value - bar.page, 350.0))
	await _frames(3)
	return _scroll.scroll_vertical > 0


func _can_scroll_horizontal() -> bool:
	var bar: HScrollBar = _scroll.get_h_scroll_bar()
	if bar == null or bar.max_value <= bar.page + 1.0:
		return false
	_scroll.scroll_horizontal = 0
	await _frames(2)
	_scroll.scroll_horizontal = int(minf(bar.max_value - bar.page, 200.0))
	await _frames(3)
	return _scroll.scroll_horizontal > 0


func _frames(count: int) -> void:
	for _i: int in count:
		await process_frame


func _check(ok: bool, message: String) -> bool:
	if not ok:
		failures.append(message)
		push_error("[Flujo] Potok 7E-3A: " + message)
	return ok


func _finish() -> void:
	if _drawer != null:
		_drawer.close()
		_drawer.set_controller(null)
		_drawer.queue_free()
	if _viewport != null:
		_viewport.queue_free()
	await _frames(4)
	if failures.is_empty():
		print("[Flujo] Potok 7E-3A native scroll, overflow and resize passed")
	quit(0 if failures.is_empty() else 1)
