@tool
extends SceneTree


const MANUAL_FIXTURE_ROOT: String = "res://tests/fixtures/manual_block_sdk"
const AUTHORING_CONTEXT_SCRIPT: Script = preload(
	"res://addons/vp_flujo/editor/flow_editor_block_authoring_context.gd"
)


class StaleAuthoringContext extends RefCounted:
	var _delegate: RefCounted

	func _init(delegate: RefCounted) -> void:
		_delegate = delegate

	func get_entries() -> Variant:
		return _delegate.call(&"get_entries")

	func create_block(_authoring_id: String) -> Variant:
		return _delegate.call(&"create_block", "stale_package:missing")


var _failures: Array[String] = []
var _host: Control
var _controller: PVController
var _process: FlowProcess
var _property: FlowGraphInspectorProperty
var _history: UndoRedo


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	await _frames()
	while EditorInterface.get_resource_filesystem().is_scanning():
		await process_frame
	var undo_redo: EditorUndoRedoManager = EditorInterface.get_editor_undo_redo()
	if undo_redo == null:
		_failures.append("Editor undo/redo manager is unavailable.")
		_finish()
		return
	await _test_production_catalog(undo_redo)
	await _test_fixture_external_adds(undo_redo)
	await _test_stale_failure(undo_redo)
	_finish()


func _test_production_catalog(undo_redo: EditorUndoRedoManager) -> void:
	var context: RefCounted = AUTHORING_CONTEXT_SCRIPT.new() as RefCounted
	var entries: Array = context.call(&"get_entries") as Array
	_check(entries.size() == 4, "Production root exposes the three catalog built-ins and FPrint.")
	var expected_ids: Array[String] = ["print", "everything_flows", "custom_hello", "mercury.fprint:fprint"]
	var expected_names: Array[String] = ["Print", "Everything Flows", "Custom Hello", "FPrint"]
	for index: int in mini(entries.size(), expected_ids.size()):
		var entry: FlowEditorBlockCatalogEntry = entries[index] as FlowEditorBlockCatalogEntry
		_check(entry != null and entry.authoring_id == expected_ids[index],
			"Production catalog preserves the expected authoring ID at index %d." % index)
		_check(entry != null and entry.display_name == expected_names[index],
			"Production catalog preserves the expected display name at index %d." % index)

	var empty_blocks: Array[FlowBlock] = []
	await _mount_surface(undo_redo, null, empty_blocks, "Production")
	var editor: FlowReadyProcessEditor = _editor()
	var add_row: HBoxContainer = _node(editor, "AddBlockActions") as HBoxContainer
	_check(add_row != null and add_row.get_child_count() == 5,
		"Production Flow Add renders FPrint with the catalog buttons plus separate Call Method.")
	if add_row != null:
		for index: int in mini(add_row.get_child_count(), expected_ids.size()):
			var button: Button = add_row.get_child(index) as Button
			_check(button != null and button.text == "Add " + expected_names[index],
				"Production Add button %d uses the catalog display name." % index)
			_check(button != null and button.get_meta(&"authoring_id", "") == expected_ids[index],
				"Production Add button %d carries only its stable authoring ID." % index)
	var call_button: Button = _button(editor, "Add Call Method")
	_check(call_button != null and not call_button.has_meta(&"authoring_id"),
		"Add Call Method remains a separate non-catalog control.")
	_check(_count_named(_property, "AddBlockActions") == 1 and _count_named(_property, "ReadyBlocksList") == 1,
		"Production Flow keeps one Add surface and one block list.")
	var production_context: RefCounted = _property.get("_authoring_context") as RefCounted
	_check(_shared_context_is_preserved(production_context, editor),
		"Production commands and Flow share the same authoring context instance.")
	await _unmount_surface()


func _test_fixture_external_adds(undo_redo: EditorUndoRedoManager) -> void:
	var context: RefCounted = AUTHORING_CONTEXT_SCRIPT.new(MANUAL_FIXTURE_ROOT) as RefCounted
	var empty_blocks: Array[FlowBlock] = []
	await _mount_surface(undo_redo, context, empty_blocks, "ManualFixture")
	var editor: FlowReadyProcessEditor = _editor()
	var add_row: HBoxContainer = _node(editor, "AddBlockActions") as HBoxContainer
	var expected_names: Array[String] = ["Print", "Everything Flows", "Custom Hello", "Manual Output"]
	var expected_ids: Array[String] = ["print", "everything_flows", "custom_hello", "manual_output:output"]
	_check(add_row != null and add_row.get_child_count() == 5,
		"Fixture Flow Add appends Manual Output and keeps Call Method separate.")
	if add_row != null:
		for index: int in expected_ids.size():
			var button: Button = add_row.get_child(index) as Button
			_check(button != null and button.text == "Add " + expected_names[index],
				"Fixture Add preserves catalog order at index %d." % index)
			_check(button != null and button.get_meta(&"authoring_id", "") == expected_ids[index],
				"Fixture Add preserves the catalog identity at index %d." % index)
	_check(_button(editor, "Add Call Method") != null,
		"Fixture Add Call Method remains outside the catalog entries.")
	_check(_count_named(_property, "AddBlockActions") == 1 and _count_named(_property, "ReadyBlocksList") == 1,
		"Fixture Flow has no duplicate Add list or block list controls.")
	_check(_shared_context_is_preserved(context, editor),
		"Fixture commands and Flow share the injected authoring context instance.")

	var manual_button: Button = _authoring_button(editor, "manual_output:output")
	_check(manual_button != null, "Fixture exposes the Manual Output authoring button.")
	if manual_button == null:
		await _unmount_surface()
		return
	manual_button.pressed.emit()
	await _frames()
	var first_block: FlowBlock = _process.blocks[0] if _process.blocks.size() == 1 else null
	_check(first_block is FlowOutputBlock, "Manual Output Add creates an external output block.")
	_check(first_block != null and first_block.get_script().resource_path.ends_with(
		"/tests/fixtures/manual_block_sdk/manual_output/block.gd"
	), "Manual Output Add retains the fixture script.")
	var first_id: String = first_block.get_internal_id() if first_block != null else ""
	var list: ItemList = _node(_editor(), "ReadyBlocksList") as ItemList
	_check(not first_id.is_empty() and _selected_block_id(list) == first_id,
		"A successful external Add selects the new block by FlowId.")
	_check(list != null and list.has_focus(), "A successful external Add returns focus to Flow.")

	var second_editor: FlowReadyProcessEditor = _editor()
	var second_button: Button = _authoring_button(second_editor, "manual_output:output")
	_check(second_button != null, "The external catalog button survives the first Add rebuild.")
	if second_button != null:
		second_button.pressed.emit()
		await _frames()
	var second_block: FlowBlock = _process.blocks[1] if _process.blocks.size() == 2 else null
	_check(second_block != null and second_block != first_block,
		"Two external Adds create two independent instances.")
	_check(second_block != null and second_block.get_internal_id() != first_id,
		"Two external Adds receive distinct FlowIds.")
	_check(second_block != null and second_block.display_name == "Manual Output 1",
		"Two external Adds preserve the existing unique-name policy.")
	var second_list: ItemList = _node(_editor(), "ReadyBlocksList") as ItemList
	_check(second_block != null and _selected_block_id(second_list) == second_block.get_internal_id(),
		"The second successful external Add selects its own FlowId.")
	_check(second_list != null and second_list.has_focus(), "The second external Add preserves Flow focus.")
	await _unmount_surface()


func _test_stale_failure(undo_redo: EditorUndoRedoManager) -> void:
	var delegate: RefCounted = AUTHORING_CONTEXT_SCRIPT.new(MANUAL_FIXTURE_ROOT) as RefCounted
	var stale_context: RefCounted = StaleAuthoringContext.new(delegate) as RefCounted
	var existing: FlowPrintBlock = FlowPrintBlock.new()
	var existing_blocks: Array[FlowBlock] = [existing]
	await _mount_surface(undo_redo, stale_context, existing_blocks, "Stale")
	_check(
		_property.open_ready_block_details(
			_controller,
			FlowGraphEditorCommands.Collection.PROCESSES,
			_process.get_internal_id(),
			existing.get_internal_id()
		),
		"The stale test can select the existing block before clicking Add."
	)
	await _frames()
	var editor: FlowReadyProcessEditor = _editor()
	var stale_button: Button = _authoring_button(editor, "manual_output:output")
	_check(stale_button != null, "The stale test renders the previously available external entry.")
	var before_version: int = _history.get_version()
	var before_id: String = existing.get_internal_id()
	if stale_button != null:
		stale_button.pressed.emit()
		await _frames()
	_check(_process.blocks.size() == 1 and _process.blocks[0] == existing,
		"A stale external Add leaves the graph unchanged.")
	_check(_history.get_version() == before_version,
		"A stale external Add creates no undo action.")
	var list: ItemList = _node(_editor(), "ReadyBlocksList") as ItemList
	_check(_selected_block_id(list) == before_id and _property.get("_ready_block_id") == before_id,
		"A stale external Add preserves the previous selection and does not fall back.")
	await _unmount_surface()


func _mount_surface(
		undo_redo: EditorUndoRedoManager,
		authoring_context: RefCounted,
		existing_blocks: Array[FlowBlock],
		label: String
) -> void:
	_host = Control.new()
	_host.name = "FlowReadyAuthoringTest" + label
	_host.size = Vector2(1200.0, 900.0)
	get_root().add_child(_host)
	_process = FlowProcess.new()
	_process.display_name = "Ready Test"
	_process.blocks = existing_blocks
	_controller = PVController.new()
	_controller.name = "FlowReadyAuthoringController" + label
	var graph: FlowGraph = FlowGraph.new()
	graph.schema_version = FlowGraph.SCHEMA_VERSION_3
	graph.constructor = FlowConstructorDefinition.new()
	graph.processes = [_process]
	_controller.flow_graph = graph
	_host.add_child(_controller)
	_property = FlowGraphInspectorProperty.new()
	_property.configure(undo_redo, authoring_context)
	_property.configure_for_fluo()
	_property.size = Vector2(900.0, 800.0)
	_host.add_child(_property)
	_property.set_dock_controller(_controller)
	_property.set_dock_variable_selection(
		_controller,
		FlowGraphEditorCommands.Collection.PROCESSES,
		_process.get_internal_id()
	)
	_history = undo_redo.get_history_undo_redo(undo_redo.get_object_history_id(_controller))
	await _frames()


func _unmount_surface() -> void:
	if is_instance_valid(_host):
		_host.queue_free()
	await _frames()
	_host = null
	_controller = null
	_process = null
	_property = null
	_history = null


func _editor() -> FlowReadyProcessEditor:
	return _property.find_child("ReadyProcessEditor", true, false) as FlowReadyProcessEditor


func _shared_context_is_preserved(expected: RefCounted, editor: FlowReadyProcessEditor) -> bool:
	if _property == null or editor == null or expected == null:
		return false
	var commands: FlowGraphEditorCommands = _property.get("_commands") as FlowGraphEditorCommands
	return _property.get("_authoring_context") == expected \
		and commands != null \
		and commands.get("_authoring_context") == expected \
		and editor.get("_authoring_context") == expected


func _authoring_button(editor: FlowReadyProcessEditor, authoring_id: String) -> Button:
	if editor == null:
		return null
	var add_row: HBoxContainer = _node(editor, "AddBlockActions") as HBoxContainer
	if add_row == null:
		return null
	for child: Node in add_row.get_children():
		if child is Button and child.get_meta(&"authoring_id", "") == authoring_id:
			return child as Button
	return null


func _button(root: Node, text: String) -> Button:
	if root == null:
		return null
	if root is Button and (root as Button).text == text:
		return root as Button
	for child: Node in root.get_children():
		var result: Button = _button(child, text)
		if result != null:
			return result
	return null


func _node(root: Node, node_name: String) -> Node:
	if root == null:
		return null
	if root.name == node_name:
		return root
	return root.find_child(node_name, true, false)


func _selected_block_id(list: ItemList) -> String:
	if list == null:
		return ""
	var selected: PackedInt32Array = list.get_selected_items()
	if selected.size() != 1:
		return ""
	return list.get_item_metadata(selected[0]) as String


func _count_named(root: Node, node_name: String) -> int:
	if root == null:
		return 0
	var count: int = 1 if root.name == node_name else 0
	for child: Node in root.get_children():
		count += _count_named(child, node_name)
	return count


func _frames(count: int = 4) -> void:
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
	await _frames(3)
	if _failures.is_empty():
		print("[Flujo] Flow Ready authoring editor test passed")
	quit(0 if _failures.is_empty() else 1)
