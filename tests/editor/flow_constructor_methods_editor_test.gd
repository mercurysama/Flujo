@tool
extends SceneTree

const TEMP_PATH: String = "res://.godot/flujo_tests/constructor_methods_editor.tscn"
const REOPEN_PATH: String = "res://.godot/flujo_tests/constructor_methods_delete_reopen.tscn"
const PLUGIN: Script = preload("res://addons/vp_flujo/plugin.gd")
var _failures: Array[String] = []
var _host: HBoxContainer
var _plugin: EditorPlugin
var _inspector: PVControllerInspectorPlugin
var _property: FlowGraphInspectorProperty
var _dock: VPFlujoDock
var _controller: PVController
var _history: UndoRedo


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	await _frames()
	while EditorInterface.get_resource_filesystem().is_scanning():
		await process_frame
	var fixture: PVController = PVController.new()
	fixture.name = "ConstructorMethodsFixture"
	fixture.flow_graph.schema_version = 3
	fixture.flow_graph.constructor = FlowConstructorDefinition.new()
	var packed: PackedScene = PackedScene.new()
	_check(packed.pack(fixture) == OK, "Pack focal fixture.")
	fixture.free()
	_check(DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.godot/flujo_tests")) == OK, "Create focal directory.")
	if not _check(ResourceSaver.save(packed, TEMP_PATH) == OK, "Save focal fixture."):
		_finish()
		return
	EditorInterface.open_scene_from_path(TEMP_PATH)
	await _frames()
	_controller = EditorInterface.get_edited_scene_root() as PVController
	if not _check(_controller != null and _controller.scene_file_path == TEMP_PATH, "Edit only the temporary controller."):
		_finish()
		return
	var manager: EditorUndoRedoManager = EditorInterface.get_editor_undo_redo()
	_history = manager.get_history_undo_redo(manager.get_object_history_id(_controller))
	_host = HBoxContainer.new()
	_host.size = Vector2(1100, 1000)
	get_root().add_child(_host)
	_inspector = PVControllerInspectorPlugin.new()
	_inspector.set_undo_redo(manager)
	_inspector._parse_property(_controller, TYPE_OBJECT, "flow_graph", PROPERTY_HINT_RESOURCE_TYPE, "FlowGraph", PROPERTY_USAGE_DEFAULT, false)
	_property = _inspector.get("_active_flow_graph_property") as FlowGraphInspectorProperty
	if not _check(_property != null, "Production Inspector creates the property."):
		await _cleanup()
		return
	_property.custom_minimum_size.x = 400
	_host.add_child(_property)
	_property.set_object_and_property(_controller, &"flow_graph")
	_controller.property_list_changed.connect(Callable(_property, &"update_property"))
	_dock = VPFlujoDock.new()
	_dock.configure(manager)
	_dock.custom_minimum_size.x = 600
	_host.add_child(_dock)
	_dock.set("_controller_presence_initialized", true)
	_dock.set("_controller_present", true)
	_plugin = PLUGIN.new()
	_plugin.set("_dock", _dock)
	_plugin.set("_controller_inspector_plugin", _inspector)
	_inspector.schema_3_variable_selection_changed.connect(Callable(_plugin, &"_on_schema_3_variable_selection_changed"))
	_inspector.schema_3_variable_editor_focus_requested.connect(Callable(_plugin, &"_on_schema_3_variable_editor_focus_requested"))
	_dock.schema_3_variable_list_focus_requested.connect(Callable(_plugin, &"_on_schema_3_variable_list_focus_requested"))
	_dock.schema_3_delete_selection_recovery_requested.connect(Callable(_plugin, &"_on_schema_3_delete_selection_recovery_requested"))
	await _frames()
	await _exercise()
	await _cleanup()


func _exercise() -> void:
	var titles: Array[String] = []
	for section: Dictionary in FlowGraphInspectorPresenter.present(_controller.flow_graph)["sections"]:
		titles.append(section.title)
	_check(titles == ["Constructor", "Processes", "Timers", "State Machines", "Methods", "Variables"], "Required schema 3 collection order.")
	if not _select("Constructor", 0):
		return
	await _frames()
	_check(_button(_property, "Add Constructor") == null and _button(_dock, "Delete Constructor") == null and _button(_dock, "Move Constructor Up") == null, "Constructor is unique and cannot be added, moved or deleted.")
	_check(_button(_dock, "Add Call Method") == null, "Constructor cannot author method calls.")
	var constructor_id: String = _controller.flow_graph.constructor.get_internal_id()
	if not _press(_dock, "Add Print"):
		return
	await _frames()
	_check(_controller.flow_graph.constructor.blocks.size() == 1 and _property.find_child("ReadyPrintText", true, false) == null, "Constructor blocks are configured only in Flujo.")
	for index: int in 3:
		if not _press(_property, "Add Method"):
			return
		await _frames()
	var methods: Array[FlowMethodDefinition] = _controller.flow_graph.methods
	if not _check(methods.size() == 3, "Three methods created."):
		return
	_check(methods[0].display_name == "Flujo" and methods[1].display_name == "Flujo 1" and methods[2].display_name == "Flujo 2", "Methods have independent first-available names.")
	if not _select("Methods", 0):
		return
	await _frames()
	var list: ItemList = _list("Methods")
	var mounted_id: int = list.get_instance_id()
	list.item_selected.emit(0)
	list.item_activated.emit(0)
	await _frames()
	var name_input: LineEdit = _dock.find_child("ReadyProcessName", true, false) as LineEdit
	if not _check(name_input != null and name_input.has_focus(), "Method activation reaches Name through the production relay."):
		return
	_check(_list("Methods").get_instance_id() == mounted_id, "Selection keeps the Inspector list mounted.")
	_check(_button(_dock, "Add Call Method") == null, "Methods cannot author nested calls.")
	name_input.text_submitted.emit("Reusable")
	await _frames()
	if not _press(_dock, "Add Print"):
		return
	await _frames()
	var blocks: ItemList = _dock.find_child("ReadyBlocksList", true, false) as ItemList
	if not _check(blocks != null and blocks.item_count == 1, "Method owns a block list."):
		return
	blocks.gui_input.emit(_key(KEY_F2))
	await _frames()
	var block_name: LineEdit = _dock.find_child("ReadyBlockName", true, false) as LineEdit
	if not _check(block_name != null and block_name.has_focus() and block_name.get_selected_text() == block_name.text, "F2 selects the complete Method block name."):
		return
	block_name.text = "Draft"
	block_name.gui_input.emit(_key(KEY_ESCAPE))
	await _frames()
	blocks = _dock.find_child("ReadyBlocksList", true, false) as ItemList
	_check(blocks != null and blocks.has_focus() and methods[0].blocks[0].display_name == "Print", "Escape cancels and returns to the same Method block.")
	if not _press(_property, "Add Process"):
		return
	await _frames()
	if not _press(_dock, "Add Call Method"):
		return
	await _frames()
	var target: OptionButton = _dock.find_child("ReadyMethodTarget", true, false) as OptionButton
	if not _check(target != null and target.item_count == 4, "Call Method selector lists method names plus unresolved placeholder."):
		return
	target.item_selected.emit(1)
	await _frames()
	var call: FlowMethodCallBlock = _controller.flow_graph.processes[0].blocks[0] as FlowMethodCallBlock
	if not _check(call != null and call.method_id == methods[0].get_internal_id(), "Call Method stores stable target ID."):
		return
	var target_id: String = call.method_id
	if not _select("Methods", 0):
		return
	await _frames()
	name_input = _dock.find_child("ReadyProcessName", true, false) as LineEdit
	if not _check(name_input != null, "Method Name remains available."):
		return
	name_input.text_submitted.emit("Renamed")
	await _frames()
	_check(call.method_id == target_id and methods[0].display_name == "Renamed", "Renaming preserves callers.")
	_history.undo()
	await _frames()
	_check(methods[0].display_name == "Reusable" and call.method_id == target_id, "Rename Undo retains target ID.")
	_history.redo()
	await _frames()
	if not _press(_dock, "Delete Method"):
		return
	var confirmation: ConfirmationDialog = _dock.find_child("FlowGraphDeleteConfirmation", true, false) as ConfirmationDialog
	if not _check(confirmation != null, "Method Delete requires confirmation."):
		return
	confirmation.confirmed.emit()
	await _frames()
	_check(_controller.flow_graph.methods.size() == 2 and call.method_id == target_id, "Delete preserves dangling references for diagnostics.")
	_check(FlowGraphValidator.validate(_controller.flow_graph).has_errors(), "Deleted target is diagnosed.")
	_history.undo()
	await _frames()
	_check(_controller.flow_graph.methods.size() == 3 and _controller.flow_graph.methods[0].get_internal_id() == target_id, "Delete Undo restores exact method identity.")
	if not _press(_property, "Add Timer"):
		return
	await _frames()
	_check(_button(_dock, "Add Call Method") != null, "Timer exposes Call Method too.")
	_check(_controller.flow_graph.constructor.get_internal_id() == constructor_id, "All editor actions preserve the unique constructor.")
	_check(_dock.find_children("ReadyBlocksList", "", true, false).size() == 1, "No duplicate dock block lists.")
	await _exercise_consecutive_deletes(target_id)
	await _exercise_delete_selection_recovery()


func _exercise_consecutive_deletes(first_method_id: String) -> void:
	if not _select_id("Methods", first_method_id):
		return
	await _frames()
	if not _confirm_collection_delete("Delete Method", first_method_id, FlowGraphEditorCommands.Collection.METHODS):
		return
	await _frames()
	_check(_controller.flow_graph.methods.size() == 2, "First Method deletion leaves its stable call reference diagnosable.")
	var second_method_id: String = _controller.flow_graph.methods[0].get_internal_id()
	if not _select_id("Methods", second_method_id):
		return
	await _frames()
	if not _press(_dock, "Delete Method"):
		return
	var confirmation: ConfirmationDialog = _dock.find_child("FlowGraphDeleteConfirmation", true, false) as ConfirmationDialog
	if not _check(confirmation != null, "Second Method Delete opens a fresh confirmation while the graph has a pre-existing diagnostic."):
		return
	confirmation.canceled.emit()
	await _frames()
	_check(_controller.flow_graph.methods.size() == 2, "Cancel preserves the second Method and creates no deletion.")
	if not _confirm_collection_delete("Delete Method", second_method_id, FlowGraphEditorCommands.Collection.METHODS):
		return
	await _frames()
	_check(_controller.flow_graph.methods.size() == 1, "A second consecutive Method deletion is not blocked by the earlier dangling reference.")
	_history.undo()
	await _frames()
	_check(_controller.flow_graph.methods.size() == 2 and _controller.flow_graph.methods[0].get_internal_id() == second_method_id, "Delete Undo restores the exact second Method.")
	_history.redo()
	await _frames()
	_check(_controller.flow_graph.methods.size() == 1, "Delete Redo removes the same second Method again.")
	if not _press(_property, "Add Variable"):
		return
	await _frames()
	var variable_id: String = _controller.flow_graph.variables[0].get_internal_id()
	if not _select_id("Variables", variable_id):
		return
	await _frames()
	if not _confirm_collection_delete("Delete Variable", variable_id, FlowGraphEditorCommands.Collection.VARIABLES):
		return
	await _frames()
	_check(_controller.flow_graph.variables.is_empty(), "Variable deletion proceeds while the pre-existing method diagnostic remains.")
	var process_id: String = _controller.flow_graph.processes[0].get_internal_id()
	if not _select_id("Processes", process_id):
		return
	await _frames()
	if not _confirm_collection_delete("Delete Process", process_id, FlowGraphEditorCommands.Collection.PROCESSES):
		return
	await _frames()
	_check(_controller.flow_graph.processes.size() == 1 and _controller.flow_graph.processes[0] is FlowTimerDefinition, "Process deletion removes exactly the selected caller.")
	var timer_id: String = _controller.flow_graph.processes[0].get_internal_id()
	if not _select_id("Timers", timer_id):
		return
	await _frames()
	if not _confirm_collection_delete("Delete Timer", timer_id, FlowGraphEditorCommands.Collection.PROCESSES):
		return
	await _frames()
	_check(_controller.flow_graph.processes.is_empty(), "Timer deletion remains available after preceding collection deletions.")
	if not _press(_property, "Add State Machine") or not _press(_property, "Add State Machine"):
		return
	await _frames()
	var persisted_controller: PVController = PVController.new()
	persisted_controller.name = "DeleteReopenFixture"
	persisted_controller.flow_graph = _controller.flow_graph
	var packed: PackedScene = PackedScene.new()
	if not _check(packed.pack(persisted_controller) == OK and ResourceSaver.save(packed, REOPEN_PATH) == OK, "Save the graph before reopening for another deletion."):
		persisted_controller.free()
		return
	persisted_controller.free()
	var reopened_scene: PackedScene = ResourceLoader.load(REOPEN_PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
	var reopened: PVController = reopened_scene.instantiate() as PVController if reopened_scene != null else null
	if not _check(reopened != null and reopened.flow_graph.state_machines.size() == 2, "Reopen the saved graph with both State Machines."):
		if reopened != null:
			reopened.free()
		return
	get_root().add_child(reopened)
	var reopened_commands: FlowGraphEditorCommands = FlowGraphEditorCommands.new(EditorInterface.get_editor_undo_redo())
	var state_id: String = reopened.flow_graph.state_machines[0].get_internal_id()
	_check(reopened_commands.delete_resource(reopened, FlowGraphEditorCommands.Collection.STATE_MACHINES, state_id), "State Machine deletion remains available after save and reopen.")
	_check(reopened.flow_graph.state_machines.size() == 1 and reopened.flow_graph.state_machines[0].get_internal_id() != state_id, "Reopened deletion removes exactly the selected State Machine.")
	reopened.queue_free()
	await _frames()


func _exercise_delete_selection_recovery() -> void:
	await _install_delete_selection_fixture(false)
	var graph: FlowGraph = _controller.flow_graph
	var referenced_method: FlowMethodDefinition = graph.methods[1]
	var referenced_method_id: String = referenced_method.get_internal_id()
	var caller: FlowMethodCallBlock = graph.processes[0].blocks[0] as FlowMethodCallBlock
	if not await _delete_resource_and_assert_selection("Methods", 1, "Delete Method", graph.methods[2].get_internal_id(), referenced_method_id):
		return
	_check(caller != null and caller.method_id == referenced_method_id and FlowGraphValidator.validate(graph).has_errors(), "Deleting a referenced Method preserves its stable call ID for diagnostics.")

	await _install_delete_selection_fixture(false)
	graph = _controller.flow_graph
	if not await _delete_resource_and_assert_selection("Processes", 0, "Delete Process", _process_at(graph, false, 1).get_internal_id(), _process_at(graph, false, 0).get_internal_id()):
		return

	await _install_delete_selection_fixture(false)
	graph = _controller.flow_graph
	if not await _delete_resource_and_assert_selection("Timers", 1, "Delete Timer", _process_at(graph, true, 2).get_internal_id(), _process_at(graph, true, 1).get_internal_id()):
		return

	await _install_delete_selection_fixture(false)
	graph = _controller.flow_graph
	if not await _delete_resource_and_assert_selection("Variables", 2, "Delete Variable", graph.variables[1].get_internal_id(), graph.variables[2].get_internal_id()):
		return

	await _install_delete_selection_fixture(true)
	graph = _controller.flow_graph
	var only_variable_id: String = graph.variables[0].get_internal_id()
	if not _select("Variables", 0):
		return
	await _frames()
	if not _confirm_collection_delete("Delete Variable", only_variable_id, FlowGraphEditorCommands.Collection.VARIABLES):
		return
	await _frames()
	var empty_variable_list: ItemList = _list("Variables")
	_check(
		graph.variables.is_empty() and _selected_list_id(empty_variable_list).is_empty() \
			and _dock.find_child("Schema3VariableEditor", true, false) == null \
			and empty_variable_list != null and empty_variable_list.has_focus(),
		"Deleting the only Variable clears the dock and returns focus to its empty structural list without retaining an invalid ID."
	)
	_history.undo()
	await _frames()
	_check(_selected_list_id(_list("Variables")) == only_variable_id, "Undo restores and selects the only deleted Variable.")
	_history.redo()
	await _frames()
	_check(_selected_list_id(_list("Variables")).is_empty(), "Redo clears the only deleted Variable selection again.")

	await _install_delete_selection_fixture(false)
	for title: String in ["Constructor", "Processes", "Timers", "Methods"]:
		if not _select(title, 0):
			return
		await _frames()
		var blocks: ItemList = _dock.find_child("ReadyBlocksList", true, false) as ItemList
		if not _check(blocks != null and blocks.item_count == 3, title + " exposes three blocks for deletion recovery."):
			return
		var deleted_block_id: String = blocks.get_item_metadata(1) as String
		var replacement_block_id: String = blocks.get_item_metadata(2) as String
		blocks.select(1)
		blocks.item_selected.emit(1)
		await _frames()
		if not _press(_dock, "Delete Block"):
			return
		var confirmation: ConfirmationDialog = _dock.find_child("ReadyBlockDeleteConfirmation", true, false) as ConfirmationDialog
		if not _check(confirmation != null, title + " block deletion requires confirmation."):
			return
		confirmation.confirmed.emit()
		await _frames()
		blocks = _dock.find_child("ReadyBlocksList", true, false) as ItemList
		_check(blocks != null and _selected_list_id(blocks) == replacement_block_id and blocks.has_focus(), title + " block Delete selects and focuses the same-index replacement.")
		_history.undo()
		await _frames()
		blocks = _dock.find_child("ReadyBlocksList", true, false) as ItemList
		_check(blocks != null and _selected_list_id(blocks) == deleted_block_id, title + " block Undo restores and selects the recovered block.")
		_history.redo()
		await _frames()
		blocks = _dock.find_child("ReadyBlocksList", true, false) as ItemList
		_check(blocks != null and _selected_list_id(blocks) == replacement_block_id, title + " block Redo selects the replacement again.")


func _install_delete_selection_fixture(only_variable: bool) -> void:
	var graph: FlowGraph = FlowGraph.new()
	graph.schema_version = FlowGraph.SCHEMA_VERSION_3
	graph.constructor = _container_with_blocks(FlowConstructorDefinition.new(), "Constructor") as FlowConstructorDefinition
	for index: int in 3:
		var process: FlowProcess = _container_with_blocks(FlowProcess.new(), "Process %d" % index) as FlowProcess
		graph.processes.append(process)
		var timer: FlowTimerDefinition = _container_with_blocks(FlowTimerDefinition.new(), "Timer %d" % index) as FlowTimerDefinition
		graph.processes.append(timer)
		var method: FlowMethodDefinition = _container_with_blocks(FlowMethodDefinition.new(), "Method %d" % index) as FlowMethodDefinition
		graph.methods.append(method)
		if not only_variable or index == 0:
			var variable: FlowVariableDefinition = FlowVariableDefinition.new()
			variable.display_name = "Variable %d" % index
			graph.variables.append(variable)
	var call: FlowMethodCallBlock = FlowMethodCallBlock.new()
	call.method_id = graph.methods[1].get_internal_id()
	graph.processes[0].blocks[0] = call
	_check(
		(graph.processes[0].blocks[0] as FlowMethodCallBlock) != null \
			and (graph.processes[0].blocks[0] as FlowMethodCallBlock).method_id == graph.methods[1].get_internal_id(),
		"Delete-selection fixture keeps three blocks and puts the stable Method call first."
	)
	_controller.flow_graph = graph
	_dock.set_variable_selection(_controller, FlowGraphEditorCommands.Collection.VARIABLES, "")
	_controller.notify_property_list_changed()
	await _frames()


func _container_with_blocks(container: FlowBlockContainer, display_name: String) -> FlowBlockContainer:
	container.display_name = display_name
	for index: int in 3:
		var block: FlowPrintBlock = FlowPrintBlock.new()
		block.display_name = "Block %d" % index
		container.blocks.append(block)
	return container


func _process_at(graph: FlowGraph, timers: bool, view_index: int) -> FlowProcess:
	var found: int = 0
	for process: FlowProcess in graph.processes:
		if process != null and (process is FlowTimerDefinition) == timers:
			if found == view_index:
				return process
			found += 1
	return null


func _delete_resource_and_assert_selection(
		title: String,
		index: int,
		button_text: String,
		expected_replacement_id: String,
		deleted_id: String
) -> bool:
	if not _select(title, index):
		return false
	await _frames()
	if not _confirm_collection_delete(button_text, deleted_id, _property.get("_selected_collection")):
		return false
	await _frames()
	var list: ItemList = _list(title)
	if not _check(list != null and _selected_list_id(list) == expected_replacement_id and list.has_focus(), title + " Delete selects and focuses the stable same-index replacement."):
		return false
	_check(_dock.find_child("ReadyProcessEditor", true, false) != null or _dock.find_child("Schema3VariableEditor", true, false) != null, title + " Delete updates dock content for the replacement selection.")
	_history.undo()
	await _frames()
	if not _check(_selected_list_id(_list(title)) == deleted_id, title + " Undo restores and selects the recovered stable ID."):
		return false
	_history.redo()
	await _frames()
	return _check(_selected_list_id(_list(title)) == expected_replacement_id, title + " Redo selects the stable replacement again.")


func _selected_list_id(list: ItemList) -> String:
	if list == null:
		return ""
	for item_index: int in list.item_count:
		if not list.is_selected(item_index):
			continue
		var metadata: Variant = list.get_item_metadata(item_index)
		if metadata is Dictionary:
			return (metadata as Dictionary).get("internal_id", "") as String
		return metadata as String
	return ""


func _confirm_collection_delete(button_text: String, expected_id: String, expected_collection: FlowGraphEditorCommands.Collection) -> bool:
	if not _press(_dock, button_text):
		return false
	var editor: FlowGraphInspectorProperty = _dock.get_variable_editor()
	var confirmation: ConfirmationDialog = _dock.find_child("FlowGraphDeleteConfirmation", true, false) as ConfirmationDialog
	if not _check(confirmation != null, button_text + " opens its confirmation."):
		return false
	_check(editor.get("_dock_controller") == _controller, "Delete confirmation retains the active controller.")
	_check(editor.get("_selected_id") == expected_id and editor.get("_pending_delete_id") == expected_id, "Delete confirmation captures the stable selected ID.")
	_check(editor.get("_selected_collection") == expected_collection and editor.get("_pending_delete_collection") == expected_collection, "Delete confirmation captures the selected collection.")
	_check(confirmation.confirmed.is_connected(Callable(editor, &"_on_delete_confirmed")), "Delete confirmation has one live confirmed callback.")
	_check(confirmation.canceled.is_connected(Callable(editor, &"_on_delete_cancelled")), "Delete confirmation has one live canceled callback.")
	confirmation.confirmed.emit()
	_check(editor.get("_pending_delete_id") == "" and editor.get("_delete_confirmation") == null, "Confirmed Delete consumes all pending confirmation state.")
	return true


func _frames() -> void:
	for index: int in 4:
		await process_frame


func _key(code: Key) -> InputEventKey:
	var event: InputEventKey = InputEventKey.new()
	event.pressed = true
	event.keycode = code
	return event


func _button(root: Node, label: String) -> Button:
	if root is Button and (root as Button).text == label:
		return root as Button
	for child: Node in root.get_children():
		var found: Button = _button(child, label)
		if found != null:
			return found
	return null


func _press(root: Node, label: String) -> bool:
	var button: Button = _button(root, label)
	if not _check(button != null, "Button exists: " + label):
		return false
	button.pressed.emit()
	return true


func _list(title: String) -> ItemList:
	for label: Node in _property.find_children("*", "Label", true, false):
		if (label as Label).text == title:
			for child: Node in label.get_parent().get_children():
				if child is ItemList:
					return child as ItemList
	return null


func _select(title: String, index: int) -> bool:
	var list: ItemList = _list(title)
	if not _check(list != null and index < list.item_count, "Selectable row in " + title):
		return false
	list.select(index)
	list.item_selected.emit(index)
	return true


func _select_id(title: String, internal_id: String) -> bool:
	var list: ItemList = _list(title)
	if not _check(list != null, "Collection list exists: " + title):
		return false
	for index: int in list.item_count:
		var entry: Dictionary = list.get_item_metadata(index) as Dictionary
		if entry.get("internal_id", "") == internal_id:
			list.select(index)
			list.item_selected.emit(index)
			return true
	return _check(false, "Stable-ID row exists in " + title)


func _check(condition: bool, message: String) -> bool:
	if not condition:
		_failures.append(message)
		push_error(message)
	return condition


func _cleanup() -> void:
	if is_instance_valid(_dock):
		_dock.set_controller(null)
	if is_instance_valid(_host):
		_host.queue_free()
	await _frames()
	if is_instance_valid(_plugin):
		_plugin.set("_dock", null)
		_plugin.set("_controller_inspector_plugin", null)
		_plugin.free()
	_inspector = null
	if is_instance_valid(_controller) and EditorInterface.get_edited_scene_root() == _controller and _controller.scene_file_path == TEMP_PATH:
		EditorInterface.save_scene()
		EditorInterface.close_scene()
	await _frames()
	_finish()


func _finish() -> void:
	for path: String in [TEMP_PATH, REOPEN_PATH]:
		if FileAccess.file_exists(path):
			_check(DirAccess.remove_absolute(ProjectSettings.globalize_path(path)) == OK, "Remove focal scene: " + path)
	if _failures.is_empty():
		print("[Flujo] Constructor and Methods editor focal passed")
	quit(0 if _failures.is_empty() else 1)
