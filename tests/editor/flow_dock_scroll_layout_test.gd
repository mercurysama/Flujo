@tool
extends SceneTree


var _failures: Array[String] = []
var _host: PanelContainer
var _dock: VPFlujoDock
var _controller: PVController


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	await _frames()
	while EditorInterface.get_resource_filesystem().is_scanning():
		await process_frame

	_controller = PVController.new()
	_controller.name = &"FlowDockScrollFixture"
	var graph: FlowGraph = FlowGraph.new()
	graph.schema_version = FlowGraph.SCHEMA_VERSION_3
	graph.constructor = FlowConstructorDefinition.new()
	var process: FlowProcess = FlowProcess.new()
	process.display_name = "Scrollable Ready"
	for index: int in 8:
		var block: FlowPrintBlock = FlowPrintBlock.new()
		block.display_name = "Print %d" % index
		block.text = "Line %d" % index
		process.blocks.append(block)
	graph.processes = [process]
	_controller.flow_graph = graph
	get_root().add_child(_controller)

	_host = PanelContainer.new()
	_host.name = &"ShortDockHost"
	_host.position = Vector2(8.0, 8.0)
	_host.size = Vector2(360.0, 240.0)
	get_root().add_child(_host)
	_dock = VPFlujoDock.new()
	_dock.configure(EditorInterface.get_editor_undo_redo())
	_host.add_child(_dock)
	_dock.set_controller(_controller)
	_dock.set_variable_selection(
		_controller,
		FlowGraphEditorCommands.Collection.PROCESSES,
		process.get_internal_id()
	)
	await _frames(5)

	var block_list: ItemList = _dock.find_child("ReadyBlocksList", true, false) as ItemList
	if not _check(block_list != null and block_list.item_count == 8, "The short dock mounts the complete Ready block list."):
		await _finish()
		return
	block_list.select(0)
	block_list.item_selected.emit(0)
	await _frames(3)

	var scroll: ScrollContainer = _dock.find_child("FlowDockEditorScroll", true, false) as ScrollContainer
	var scrollable_content: VBoxContainer = _dock.find_child("FlowDockScrollableContent", true, false) as VBoxContainer
	var print_input: TextEdit = _dock.find_child("ReadyPrintText", true, false) as TextEdit
	if not _check(scroll != null, "The Flujo dock owns one vertical editor ScrollContainer."):
		await _finish()
		return
	_check(
		scroll.vertical_scroll_mode == ScrollContainer.SCROLL_MODE_AUTO \
			and scroll.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED,
		"The dock uses native automatic vertical scrolling without a horizontal width constraint."
	)
	_check(scroll.focus_mode == Control.FOCUS_ALL and scroll.follow_focus, "The native scroll surface supports keyboard focus and focused-child tracking.")
	_check(scrollable_content != null and print_input != null, "All block configuration, including the final Print editor, is inside the scroll surface.")
	if print_input == null:
		await _finish()
		return

	var scroll_count: int = 0
	for candidate: Node in _dock.find_children("*", "ScrollContainer", true, false):
		if candidate is ScrollContainer:
			scroll_count += 1
	_check(scroll_count == 1, "The dock uses one scroll surface for the complete configuration area.")

	var vertical_bar: VScrollBar = scroll.get_v_scroll_bar()
	_check(vertical_bar != null and vertical_bar.is_visible_in_tree(), "A vertical scrollbar becomes visible when configuration exceeds the dock height.")
	if vertical_bar == null:
		await _finish()
		return
	_check(vertical_bar.max_value > vertical_bar.page, "Scrollable content produces a vertical range larger than the visible page.")
	var initial_input_y: float = print_input.global_position.y
	var target_scroll: int = int(ceil(vertical_bar.max_value - vertical_bar.page))
	scroll.scroll_vertical = target_scroll
	await _frames(3)
	var viewport_rect: Rect2 = scroll.get_global_rect()
	var input_rect: Rect2 = print_input.get_global_rect()
	_check(scroll.scroll_vertical > 0, "The native vertical scroll position changes under constrained layout.")
	_check(print_input.global_position.y < initial_input_y, "Scrolling moves the final configuration controls through the viewport.")
	_check(
		input_rect.position.y >= viewport_rect.position.y - 1.0 \
			and input_rect.end.y <= viewport_rect.end.y + 1.0,
		"The final Print editor can be brought fully inside the visible scroll area."
	)

	await _finish()


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
	if is_instance_valid(_controller):
		_controller.queue_free()
	await _frames(5)
	if _failures.is_empty():
		print("[Flujo] Flow dock scroll layout test passed")
	quit(0 if _failures.is_empty() else 1)
