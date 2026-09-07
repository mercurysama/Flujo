@tool
extends SceneTree


var _failures: Array[String] = []
var _changes: int = 0
var _selection_emitter_inside_tree: bool = false
var _selection_event_count: int = 0

const TEMP_DIR_PATH: String = "res://.godot/flujo_tests"
const TEMP_HISTORY_SCENE_PATH: String = TEMP_DIR_PATH + "/flow_graph_editor_history.tscn"


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var undo_redo: EditorUndoRedoManager = EditorInterface.get_editor_undo_redo()
	if undo_redo == null:
		_failures.append("Editor undo/redo manager is unavailable.")
		_finish()
		return
	var history: UndoRedo = undo_redo.get_history_undo_redo(EditorUndoRedoManager.GLOBAL_HISTORY)
	var commands: FlowGraphEditorCommands = FlowGraphEditorCommands.new(undo_redo)
	commands.changed.connect(_on_changed)
	var controller: PVController = PVController.new()
	controller.flow_graph = null
	var inspector_plugin: PVControllerInspectorPlugin = PVControllerInspectorPlugin.new()
	_expect(inspector_plugin._can_handle(controller), "Inspector plugin recognizes PVController.")
	_expect(PVControllerInspectorPlugin.is_flow_graph_property(&"flow_graph"), "Inspector plugin intercepts exactly flow_graph.")
	_expect(not PVControllerInspectorPlugin.is_flow_graph_property(&"visual_program_enabled"), "Inspector plugin does not intercept unrelated properties.")
	var flow_graph_property: Dictionary = _find_property(controller.get_property_list(), &"flow_graph")
	_expect(flow_graph_property["type"] == TYPE_OBJECT, "FlowGraph property is reported as an object when null.")
	_expect(flow_graph_property["hint"] == PROPERTY_HINT_RESOURCE_TYPE, "FlowGraph property retains its resource-type hint when null.")
	_expect(flow_graph_property["hint_string"] == "FlowGraph", "FlowGraph property reports the FlowGraph resource type.")
	_expect((flow_graph_property["usage"] as int & PROPERTY_USAGE_EDITOR) != 0, "FlowGraph property remains editor-visible when null.")
	_expect(
		inspector_plugin._parse_property(
			controller,
			flow_graph_property["type"],
			"flow_graph",
			flow_graph_property["hint"],
			flow_graph_property["hint_string"],
			flow_graph_property["usage"],
			false
		),
		"Inspector plugin replaces the default editor for null flow_graph."
	)
	var inspector_property: FlowGraphInspectorProperty = FlowGraphInspectorProperty.new()
	inspector_property.configure(undo_redo)
	var inspector_scroll: ScrollContainer = ScrollContainer.new()
	inspector_scroll.custom_minimum_size = Vector2(420.0, 480.0)
	inspector_scroll.size = inspector_scroll.custom_minimum_size
	get_root().add_child(inspector_scroll)
	var inspector_column: VBoxContainer = VBoxContainer.new()
	inspector_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inspector_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inspector_scroll.add_child(inspector_column)
	inspector_column.add_child(inspector_property)
	inspector_property.set_object_and_property(controller, &"flow_graph")
	await process_frame
	await process_frame
	var create_graph_button: Button = _find_button(inspector_property, "Create Schema 2 Graph")
	_expect(create_graph_button != null and create_graph_button.visible, "Null FlowGraph builds a visible create button after ready without _update_property().")
	var inspector_content: Node = inspector_property.get_child(0)
	var initial_control_count: int = inspector_content.get_child_count()
	inspector_property.call(&"_rebuild_interface")
	inspector_property.call(&"_rebuild_interface")
	inspector_property.call(&"_rebuild_interface")
	_expect(inspector_content.get_child_count() == initial_control_count, "Repeated same-frame rebuilds keep a stable control count.")
	_expect(_count_buttons(inspector_property, "Create Schema 2 Graph") == 1, "Repeated same-frame rebuilds keep one create button.")
	create_graph_button = _find_button(inspector_property, "Create Schema 2 Graph")
	if create_graph_button != null:
		create_graph_button.emit_signal(&"pressed")
	await process_frame
	_expect(controller.flow_graph != null and controller.flow_graph.schema_version == FlowGraph.SCHEMA_VERSION_2, "Create button assigns a schema 2 graph.")
	history.undo()
	_expect(controller.flow_graph == null, "Create button undo restores null.")
	history.redo()
	_expect(controller.flow_graph != null, "Create button redo restores the graph.")
	inspector_property.call(&"_rebuild_interface")
	await process_frame
	_expect(_has_schema_2_category_order(inspector_property, "Add Process", "Processes"), "Processes renders button, category, then list.")
	_expect(_has_schema_2_category_order(inspector_property, "Add Variable", "Variables"), "Variables renders button, category, then list.")
	_expect(_has_schema_2_category_order(inspector_property, "Add State Machine", "State Machines"), "State Machines renders button, category, then list.")
	await _test_inspector_add_button_refresh(
		inspector_property,
		controller,
		history,
		"Add Process",
		"Processes",
		FlowGraphEditorCommands.Collection.PROCESSES
	)
	await _test_selection_rebuild_race(inspector_property, controller, history)
	await _test_inspector_add_button_refresh(
		inspector_property,
		controller,
		history,
		"Add Variable",
		"Variables",
		FlowGraphEditorCommands.Collection.VARIABLES
	)
	await _test_inspector_add_button_refresh(
		inspector_property,
		controller,
		history,
		"Add State Machine",
		"State Machines",
		FlowGraphEditorCommands.Collection.STATE_MACHINES
	)
	await _test_schema_2_list_height(
		inspector_property,
		controller,
		"Processes",
		FlowGraphEditorCommands.Collection.PROCESSES
	)
	await _test_schema_2_list_height(
		inspector_property,
		controller,
		"Variables",
		FlowGraphEditorCommands.Collection.VARIABLES
	)
	await _test_schema_2_list_height(
		inspector_property,
		controller,
		"State Machines",
		FlowGraphEditorCommands.Collection.STATE_MACHINES
	)
	await _test_inspector_rename_move_delete_collection(
		inspector_property,
		controller,
		history,
		"Processes",
		FlowGraphEditorCommands.Collection.PROCESSES
	)
	await _test_inspector_rename_move_delete_collection(
		inspector_property,
		controller,
		history,
		"Variables",
		FlowGraphEditorCommands.Collection.VARIABLES
	)
	await _test_inspector_rename_move_delete_collection(
		inspector_property,
		controller,
		history,
		"State Machines",
		FlowGraphEditorCommands.Collection.STATE_MACHINES
	)
	inspector_scroll.queue_free()
	controller.flow_graph = null
	_test_dock_visibility_conditions()
	_test_debug_instrumentation_removed()

	_expect(commands.create_schema_2_graph(controller), "A missing graph can be created.")
	var created_graph: FlowGraph = controller.flow_graph
	_expect(created_graph != null and created_graph.schema_version == FlowGraph.SCHEMA_VERSION_2, "Created graph is schema 2.")
	history.undo()
	_expect(controller.flow_graph == null, "Undo restores the missing graph reference.")
	history.redo()
	_expect(controller.flow_graph == created_graph, "Redo restores the same graph instance.")

	_expect(commands.add_resource(controller, FlowGraphEditorCommands.Collection.PROCESSES), "A process can be added.")
	var process: FlowProcess = created_graph.processes[0]
	var process_id: String = process.get_internal_id()
	_expect(process.display_name == "Flujo", "The first process receives the automatic visible name.")
	_expect(commands.rename_resource(controller, FlowGraphEditorCommands.Collection.PROCESSES, process_id, "Tick"), "A process can be renamed.")
	_expect(process.display_name == "Tick", "Rename is applied through the action.")
	history.undo()
	_expect(process.display_name == "Flujo", "Undo preserves the automatic process name and same instance.")
	history.redo()
	_expect(process.display_name == "Tick", "Redo preserves the process ID and instance.")
	_expect(commands.add_resource(controller, FlowGraphEditorCommands.Collection.PROCESSES), "A second process can be added.")
	var second_process: FlowProcess = created_graph.processes[1]
	_expect(commands.move_resource(controller, FlowGraphEditorCommands.Collection.PROCESSES, second_process.get_internal_id(), -1), "A process can move one position.")
	_expect(created_graph.processes[0] == second_process and created_graph.processes[1] == process, "Move keeps instances and order deterministically.")
	_expect(commands.delete_resource(controller, FlowGraphEditorCommands.Collection.PROCESSES, process_id), "An unreferenced process can be deleted.")
	_expect(created_graph.processes.size() == 1 and created_graph.processes[0] == second_process, "Delete removes the entry and keeps the remaining process order.")

	_expect(commands.add_resource(controller, FlowGraphEditorCommands.Collection.VARIABLES), "A variable can be added.")
	var global_variable: FlowVariableDefinition = created_graph.variables[0]
	_expect(global_variable.display_name == "Flujo", "The first variable receives the automatic visible name.")
	global_variable.scope = FlowVariableDefinition.Scope.GLOBAL
	_expect(commands.add_resource(controller, FlowGraphEditorCommands.Collection.STATE_MACHINES), "A state machine can be added.")
	_expect(created_graph.state_machines[0].display_name == "Flujo", "The first state machine receives the automatic visible name.")
	_expect(created_graph.state_machines[0] is FlowStateMachineDefinition, "Added state machine has the expected type.")
	_expect(commands.add_resource(controller, FlowGraphEditorCommands.Collection.VARIABLES), "A second variable can be added.")
	var reference_variable: FlowVariableDefinition = created_graph.variables[1]
	reference_variable.global_variable_id = global_variable.get_internal_id()
	_expect(not commands.delete_resource(controller, FlowGraphEditorCommands.Collection.VARIABLES, global_variable.get_internal_id()), "Deleting a referenced global variable is rejected.")
	_expect(created_graph.variables[0] == global_variable, "Rejected deletion does not mutate the graph.")
	_expect(not commands.get_last_diagnostics().is_empty(), "Rejected deletion exposes diagnostics.")
	_test_automatic_collection_names(commands)

	var legacy_graph: FlowGraph = FlowGraph.new()
	var legacy_process: FlowProcess = FlowProcess.new()
	legacy_graph.containers.append(legacy_process)
	controller.flow_graph = legacy_graph
	_expect(commands.migrate_to_schema_2(controller), "A valid legacy graph can be migrated.")
	var migrated_graph: FlowGraph = controller.flow_graph
	_expect(migrated_graph != legacy_graph and migrated_graph.schema_version == FlowGraph.SCHEMA_VERSION_2, "Migration replaces only with a valid schema 2 copy.")
	history.undo()
	_expect(controller.flow_graph == legacy_graph, "Undo restores the exact legacy graph instance.")
	history.redo()
	_expect(controller.flow_graph == migrated_graph, "Redo restores the same migrated graph instance.")
	_expect(_changes > 0, "Commands notify the presenter after actions.")
	var presentation: Dictionary = FlowGraphInspectorPresenter.present(migrated_graph)
	_expect(presentation["active_source"] == "Typed collections", "Presenter refreshes from the active schema 2 source.")
	_expect(not FlowGraphValidator.validate(migrated_graph).has_errors(), "Migrated graph stays valid without mixed sources.")
	await _test_scene_history_context(undo_redo)

	_finish()


func _finish() -> void:
	if _failures.is_empty():
		print("[Flujo] FlowGraph editor commands test passed")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _on_changed() -> void:
	_changes += 1


func _record_selection_emitter_state(_item_index: int, list: ItemList) -> void:
	_selection_event_count += 1
	_selection_emitter_inside_tree = _selection_emitter_inside_tree or list.is_inside_tree()


func _find_property(properties: Array[Dictionary], property_name: String) -> Dictionary:
	for property: Dictionary in properties:
		if property["name"] == property_name:
			return property
	return {}


func _find_button(root: Node, button_text: String) -> Button:
	if root is Button and (root as Button).text == button_text:
		return root as Button
	for child: Node in root.get_children():
		var button: Button = _find_button(child, button_text)
		if button != null:
			return button
	return null


func _find_line_edit(root: Node) -> LineEdit:
	if root is LineEdit:
		return root as LineEdit
	for child: Node in root.get_children():
		var line_edit: LineEdit = _find_line_edit(child)
		if line_edit != null:
			return line_edit
	return null


func _count_buttons(root: Node, button_text: String) -> int:
	var count: int = 1 if root is Button and (root as Button).text == button_text else 0
	for child: Node in root.get_children():
		count += _count_buttons(child, button_text)
	return count


func _test_dock_visibility_conditions() -> void:
	var scene_inspector = preload("res://addons/vp_flujo/editor/pv_scene_inspector.gd").new(
		preload("res://addons/vp_flujo/runtime/pv_controller.gd")
	)
	var plugin_script: Script = preload("res://addons/vp_flujo/plugin.gd")
	var root: Node = Node.new()
	var parent: Node = Node.new()
	var controller_node: PVController = PVController.new()
	var sibling: Node = Node.new()
	root.add_child(parent)
	parent.add_child(controller_node)
	root.add_child(sibling)
	var controller_selection: Array[Node] = [controller_node]
	var parent_selection: Array[Node] = [parent]
	var sibling_selection: Array[Node] = [sibling]
	var empty_selection: Array[Node] = []
	var multiple_selection: Array[Node] = [parent, sibling]
	_expect(plugin_script._should_show_dock(controller_selection, root, scene_inspector), "Selecting PVController makes the dock visible.")
	_expect(plugin_script._should_show_dock(parent_selection, root, scene_inspector), "Selecting a parent containing PVController makes the dock visible.")
	_expect(not plugin_script._should_show_dock(sibling_selection, root, scene_inspector), "Selecting an unrelated sibling hides the dock.")
	_expect(plugin_script._should_show_dock(empty_selection, root, scene_inspector), "Empty selection falls back to a scene containing PVController.")
	_expect(not plugin_script._should_show_dock(multiple_selection, root, scene_inspector), "Multiple selection hides the dock.")
	root.queue_free()


## Verifies actions for a controller owned by an opened scene use that scene's history.
func _test_scene_history_context(undo_redo: EditorUndoRedoManager) -> void:
	var directory_error: Error = DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TEMP_DIR_PATH))
	_expect(directory_error == OK, "The temporary scene directory is available for scene-history coverage.")
	if directory_error != OK:
		return
	var root: Node = Node.new()
	root.name = "FlowGraphEditorHistory"
	var controller: PVController = PVController.new()
	controller.name = "PVController"
	var legacy_graph: FlowGraph = FlowGraph.new()
	legacy_graph.containers.append(FlowProcess.new())
	controller.flow_graph = legacy_graph
	root.add_child(controller)
	controller.owner = root
	var packed_scene: PackedScene = PackedScene.new()
	var pack_error: Error = packed_scene.pack(root)
	_expect(pack_error == OK, "The scene-history fixture packs a PVController owned by its scene.")
	var save_error: Error = ResourceSaver.save(packed_scene, TEMP_HISTORY_SCENE_PATH)
	_expect(save_error == OK, "The scene-history fixture saves to the established temporary path.")
	root.free()
	if pack_error != OK or save_error != OK:
		return

	EditorInterface.open_scene_from_path(TEMP_HISTORY_SCENE_PATH)
	await process_frame
	await process_frame
	var scene_root: Node = EditorInterface.get_edited_scene_root()
	var scene_controller: PVController = scene_root.get_node_or_null(NodePath("PVController")) as PVController if scene_root != null else null
	_expect(scene_controller != null, "The opened temporary scene exposes its PVController context.")
	if scene_controller == null:
		await _remove_temporary_history_scene()
		return
	var history_id: int = undo_redo.get_object_history_id(scene_controller)
	var scene_history: UndoRedo = undo_redo.get_history_undo_redo(history_id)
	var global_history: UndoRedo = undo_redo.get_history_undo_redo(EditorUndoRedoManager.GLOBAL_HISTORY)
	_expect(history_id != EditorUndoRedoManager.GLOBAL_HISTORY, "The scene PVController has a non-global undo history.")
	_expect(scene_history != global_history, "The scene undo history is distinct from the global history.")
	if scene_history == null or global_history == null or history_id == EditorUndoRedoManager.GLOBAL_HISTORY:
		await _remove_temporary_history_scene()
		return
	var global_version: int = global_history.get_version()
	var scene_version: int = scene_history.get_version()
	var commands: FlowGraphEditorCommands = FlowGraphEditorCommands.new(undo_redo)

	_expect(commands.migrate_to_schema_2(scene_controller), "Migration registers against the opened scene context.")
	_expect(scene_controller.flow_graph.schema_version == FlowGraph.SCHEMA_VERSION_2, "Migration updates the controller in the opened scene.")
	_expect(scene_history.get_version() > scene_version, "Migration advances the scene history.")
	_expect(global_history.get_version() == global_version, "Migration does not advance global history.")
	_expect(_is_temporary_scene_unsaved(), "Migration marks the opened scene as unsaved through native undo tracking.")
	scene_history.undo()
	_expect(scene_controller.flow_graph.schema_version == 1, "Undo restores the schema 1 graph in scene history.")
	scene_history.redo()
	_expect(scene_controller.flow_graph.schema_version == FlowGraph.SCHEMA_VERSION_2, "Redo restores schema 2 through scene history.")
	EditorInterface.save_scene()
	await process_frame
	_expect(not _is_temporary_scene_unsaved(), "Saving clears native unsaved state at the scene-history version.")

	var original_process: FlowProcess = scene_controller.flow_graph.processes[0]
	var original_id: String = original_process.get_internal_id()
	var previous_scene_version: int = scene_history.get_version()
	_expect(commands.add_resource(scene_controller, FlowGraphEditorCommands.Collection.PROCESSES), "Add uses the opened scene history.")
	_expect(scene_history.get_version() > previous_scene_version and global_history.get_version() == global_version, "Add advances only scene history.")
	_expect(_is_temporary_scene_unsaved(), "Add marks the opened scene as unsaved.")
	previous_scene_version = scene_history.get_version()
	_expect(commands.rename_resource(scene_controller, FlowGraphEditorCommands.Collection.PROCESSES, original_id, "Renamed"), "Rename uses the opened scene history.")
	_expect(scene_history.get_version() > previous_scene_version and global_history.get_version() == global_version, "Rename advances only scene history.")
	var added_process: FlowProcess = scene_controller.flow_graph.processes[1]
	previous_scene_version = scene_history.get_version()
	_expect(commands.move_resource(scene_controller, FlowGraphEditorCommands.Collection.PROCESSES, added_process.get_internal_id(), -1), "Move uses the opened scene history.")
	_expect(scene_history.get_version() > previous_scene_version and global_history.get_version() == global_version, "Move advances only scene history.")
	previous_scene_version = scene_history.get_version()
	_expect(commands.delete_resource(scene_controller, FlowGraphEditorCommands.Collection.PROCESSES, original_id), "Delete uses the opened scene history.")
	_expect(scene_history.get_version() > previous_scene_version and global_history.get_version() == global_version, "Delete advances only scene history.")
	_expect(_is_temporary_scene_unsaved(), "Delete keeps the opened scene marked as unsaved.")

	scene_history.undo()
	scene_history.undo()
	scene_history.undo()
	scene_history.undo()
	_expect(scene_controller.flow_graph.processes.size() == 1, "Undo returns all collection changes to the saved scene state.")
	_expect(not _is_temporary_scene_unsaved(), "Undo to the saved version clears native unsaved state.")
	scene_history.redo()
	_expect(_is_temporary_scene_unsaved(), "Redo away from the saved version marks the scene unsaved again.")
	EditorInterface.save_scene()
	await process_frame
	_expect(not _is_temporary_scene_unsaved(), "Saving after redo clears native unsaved state again.")
	await _remove_temporary_history_scene()


func _is_temporary_scene_unsaved() -> bool:
	for scene_path: String in EditorInterface.get_unsaved_scenes():
		if scene_path == TEMP_HISTORY_SCENE_PATH:
			return true
	return false


func _remove_temporary_history_scene() -> void:
	EditorInterface.save_scene()
	EditorInterface.close_scene()
	await process_frame
	await process_frame
	var remove_error: Error = DirAccess.remove_absolute(ProjectSettings.globalize_path(TEMP_HISTORY_SCENE_PATH))
	_expect(remove_error == OK and not FileAccess.file_exists(TEMP_HISTORY_SCENE_PATH), "The temporary scene-history fixture is removed after the test.")


func _test_automatic_collection_names(commands: FlowGraphEditorCommands) -> void:
	for collection: FlowGraphEditorCommands.Collection in [
		FlowGraphEditorCommands.Collection.PROCESSES,
		FlowGraphEditorCommands.Collection.VARIABLES,
		FlowGraphEditorCommands.Collection.STATE_MACHINES,
	]:
		var graph: FlowGraph = FlowGraph.new()
		graph.schema_version = FlowGraph.SCHEMA_VERSION_2
		var controller: PVController = PVController.new()
		controller.flow_graph = graph
		_set_automatic_name_fixture(graph, collection)
		_expect(commands.add_resource(controller, collection), "%s accepts a deterministic automatic name after a collision." % _collection_title(collection))
		var values: Array = _collection_for_test(graph, collection)
		var first_added: Resource = values[3] as Resource
		_expect(_test_display_name(first_added) == "Flujo 2", "%s chooses the first available suffix and ignores null positions." % _collection_title(collection))
		var first_added_id: String = _test_resource_id(first_added)
		_expect(commands.add_resource(controller, collection), "%s accepts the next automatic name." % _collection_title(collection))
		values = _collection_for_test(graph, collection)
		_expect(_test_display_name(values[4] as Resource) == "Flujo 4", "%s chooses the next missing suffix deterministically." % _collection_title(collection))
		_expect(commands.delete_resource(controller, collection, first_added_id), "%s deletes the selected automatic-name resource by stable ID." % _collection_title(collection))
		values = _collection_for_test(graph, collection)
		_expect(values.size() == 4 and values[1] == null, "%s Delete preserves its unrelated null position." % _collection_title(collection))
		_expect(commands.add_resource(controller, collection), "%s can create a replacement after Delete." % _collection_title(collection))
		values = _collection_for_test(graph, collection)
		_expect(_test_display_name(values.back() as Resource) == "Flujo 2", "%s reuses the first available name after Delete." % _collection_title(collection))


func _set_automatic_name_fixture(graph: FlowGraph, collection: FlowGraphEditorCommands.Collection) -> void:
	match collection:
		FlowGraphEditorCommands.Collection.PROCESSES:
			var first_process: FlowProcess = FlowProcess.new()
			first_process.display_name = "Flujo"
			var third_process: FlowProcess = FlowProcess.new()
			third_process.display_name = "Flujo 3"
			graph.processes = [first_process, null, third_process]
		FlowGraphEditorCommands.Collection.VARIABLES:
			var first_variable: FlowVariableDefinition = FlowVariableDefinition.new()
			first_variable.display_name = "Flujo"
			var third_variable: FlowVariableDefinition = FlowVariableDefinition.new()
			third_variable.display_name = "Flujo 3"
			graph.variables = [first_variable, null, third_variable]
		FlowGraphEditorCommands.Collection.STATE_MACHINES:
			var first_machine: FlowStateMachineDefinition = FlowStateMachineDefinition.new()
			first_machine.display_name = "Flujo"
			var third_machine: FlowStateMachineDefinition = FlowStateMachineDefinition.new()
			third_machine.display_name = "Flujo 3"
			graph.state_machines = [first_machine, null, third_machine]


func _collection_title(collection: FlowGraphEditorCommands.Collection) -> String:
	match collection:
		FlowGraphEditorCommands.Collection.PROCESSES:
			return "Processes"
		FlowGraphEditorCommands.Collection.VARIABLES:
			return "Variables"
		FlowGraphEditorCommands.Collection.STATE_MACHINES:
			return "State Machines"
	return "Collection"


func _has_schema_2_category_order(property: FlowGraphInspectorProperty, button_text: String, title_text: String) -> bool:
	var button: Button = _find_button(property, button_text)
	if button == null:
		return false
	var category: Node = button.get_parent()
	if not category is VBoxContainer or category.get_child_count() != 3:
		return false
	var title: Label = category.get_child(1) as Label
	var list: ItemList = category.get_child(2) as ItemList
	return category.get_child(0) == button and title != null and title.text == title_text and list != null


func _test_inspector_add_button_refresh(
		property: FlowGraphInspectorProperty,
		controller: PVController,
		history: UndoRedo,
		button_text: String,
		section_title: String,
		collection: FlowGraphEditorCommands.Collection
) -> void:
	var previous_size: int = _collection_size(controller.flow_graph, collection)
	var add_button: Button = _find_button(property, button_text)
	_expect(add_button != null and add_button.visible, "%s is visible before adding." % button_text)
	if add_button == null:
		return
	add_button.emit_signal(&"pressed")
	await process_frame
	await process_frame
	_expect(_collection_size(controller.flow_graph, collection) == previous_size + 1, "%s changes its model collection." % button_text)
	if previous_size == 0:
		var added_values: Array = _collection_for_test(controller.flow_graph, collection)
		_expect(_test_display_name(added_values.back() as Resource) == "Flujo", "%s assigns the first automatic visible name." % button_text)
	_expect(_visible_section_row_count(property, section_title) == previous_size + 1, "%s rebuilds the matching visible Inspector list." % button_text)
	_expect(_has_visible_first_section_row(property, section_title), "%s renders its first row inside the visible list area." % button_text)
	history.undo()
	await process_frame
	await process_frame
	_expect(_collection_size(controller.flow_graph, collection) == previous_size, "%s undo restores its model collection." % button_text)
	_expect(_visible_section_row_count(property, section_title) == previous_size, "%s undo refreshes the matching Inspector list." % button_text)
	_expect(_section_list_count(property, section_title) == 1, "%s undo leaves one empty list without stale controls." % button_text)
	history.redo()
	await process_frame
	await process_frame
	_expect(_collection_size(controller.flow_graph, collection) == previous_size + 1, "%s redo restores its model collection." % button_text)
	_expect(_visible_section_row_count(property, section_title) == previous_size + 1, "%s redo refreshes the matching Inspector list." % button_text)
	_expect(_has_visible_first_section_row(property, section_title), "%s redo restores a visible first row." % button_text)
	var content: Node = property.get_child(0)
	var control_count: int = content.get_child_count()
	property.call(&"_rebuild_interface")
	property.call(&"_rebuild_interface")
	property.call(&"_rebuild_interface")
	await process_frame
	await process_frame
	_expect(content.get_child_count() == control_count, "%s repeated rebuilds keep a stable control count." % button_text)
	_expect(_visible_section_row_count(property, section_title) == previous_size + 1, "%s repeated rebuilds do not duplicate rows." % button_text)
	_expect(_section_list_count(property, section_title) == 1, "%s repeated rebuilds keep one list for its category." % button_text)
	_expect(_has_visible_first_section_row(property, section_title), "%s repeated rebuilds keep its row visible." % button_text)


func _test_schema_2_list_height(
		property: FlowGraphInspectorProperty,
		controller: PVController,
		section_title: String,
		collection: FlowGraphEditorCommands.Collection
) -> void:
	var stable_height: float = -1.0
	for count: int in 7:
		_set_collection_fixture_size(controller.flow_graph, collection, count)
		property.call(&"_rebuild_interface")
		await process_frame
		await process_frame
		var list: ItemList = _section_list(property, section_title)
		_expect(list != null and list.item_count == count, "%s exposes exactly %d rows for its height fixture." % [section_title, count])
		if list == null:
			return
		var height: float = list.custom_minimum_size.y
		if count == 0:
			stable_height = height
		else:
			_expect(is_equal_approx(height, stable_height), "%s keeps the same theme-derived height from zero through six rows." % section_title)
		_expect(height > 0.0, "%s reserves visible theme-derived space from its empty state." % section_title)
		if count > 0:
			_expect(_has_visible_first_section_row(property, section_title), "%s keeps its first row visible at %d entries." % [section_title, count])
		if count >= 5:
			var fifth_row_rect: Rect2 = list.get_item_rect(4)
			_expect(fifth_row_rect.size.y > 0.0 and fifth_row_rect.end.y <= list.size.y, "%s keeps five complete rows visible." % section_title)
		var scroll_bar: VScrollBar = list.get_v_scroll_bar()
		if count <= 5:
			_expect(scroll_bar.max_value <= scroll_bar.page, "%s does not scroll before a sixth row exists." % section_title)
		if count == 6:
			_expect(scroll_bar.max_value > scroll_bar.page, "%s uses ItemList scrolling after five visible rows." % section_title)


func _test_selection_rebuild_race(
		property: FlowGraphInspectorProperty,
		controller: PVController,
		history: UndoRedo
) -> void:
	var selected_list: ItemList = _section_list(property, "Processes")
	_expect(selected_list != null and selected_list.item_count == 1, "Selection test starts with one process row.")
	if selected_list == null:
		return
	_selection_emitter_inside_tree = false
	_selection_event_count = 0
	selected_list.item_selected.connect(_record_selection_emitter_state.bind(selected_list))
	selected_list.emit_signal(&"item_selected", 0)
	selected_list.emit_signal(&"item_selected", 0)
	_expect(_selection_event_count == 2, "Rapid selections emit both row events.")
	_expect(_selection_emitter_inside_tree and selected_list.is_inside_tree(), "Selection leaves the emitting list in the tree until the deferred rebuild.")
	_expect(_find_button(property, "Rename") == null, "Selection controls are not rebuilt synchronously during the row event.")
	await process_frame
	await process_frame
	var current_list: ItemList = _section_list(property, "Processes")
	_expect(current_list != null and current_list != selected_list and current_list.is_inside_tree(), "Selection rebuilds the process list after the row event.")
	_expect(current_list != null and current_list.is_selected(0), "Deferred selection rebuild preserves the process selection by stable ID.")
	_expect(_find_button(property, "Rename") != null and _find_button(property, "Delete") != null, "Selection rebuilds row editing controls.")
	_expect(_find_line_edit(property) == null, "Selection exposes Rename before opening its edit field.")
	_expect(_visible_section_row_count(property, "Processes") == 1, "The rebuilt process list keeps one row after selection.")
	_expect(_has_visible_first_section_row(property, "Processes"), "The rebuilt process row remains fully visible after selection.")
	_expect(_section_list_count(property, "Processes") == 1, "Selection does not duplicate process lists.")
	var delete_button: Button = _find_button(property, "Delete")
	if delete_button != null:
		delete_button.emit_signal(&"pressed")
	await process_frame
	await process_frame
	_expect(controller.flow_graph.processes.is_empty(), "Delete removes the selected process entry without creating a null slot.")
	_expect(_section_list_count(property, "Processes") == 1, "Delete leaves one process list.")
	history.undo()
	await process_frame
	await process_frame
	_expect(_has_visible_first_section_row(property, "Processes"), "Undo restores a visible selected process row.")
	history.redo()
	await process_frame
	await process_frame
	_expect(_visible_section_row_count(property, "Processes") == 0, "Redo removes the selected process row again without creating an empty row.")
	history.undo()
	await process_frame
	await process_frame
	_expect(_has_visible_first_section_row(property, "Processes"), "Undo after redo restores the process row without duplicate lists.")


func _test_inspector_rename_move_delete_collection(
		property: FlowGraphInspectorProperty,
		controller: PVController,
		history: UndoRedo,
		section_title: String,
		collection: FlowGraphEditorCommands.Collection
) -> void:
	var fixture: Dictionary = _set_delete_fixture(controller.flow_graph, collection)
	var first: Resource = fixture["first"] as Resource
	var middle: Resource = fixture["middle"] as Resource
	var last: Resource = fixture["last"] as Resource
	property.call(&"_rebuild_interface")
	await process_frame
	await process_frame
	var list: ItemList = _section_list(property, section_title)
	var middle_id: String = _test_resource_id(middle)
	var middle_index: int = _item_index_for_internal_id(list, middle_id)
	_expect(list != null and list.item_count == 4, "%s fixture exposes three resources and one existing null position." % section_title)
	_expect(middle_index == 2, "%s B resource retains its original index before Rename." % section_title)
	_expect(_section_rows_match_collection(property, section_title, _collection_for_test(controller.flow_graph, collection)), "%s visible rows match the fixture model without exposing IDs." % section_title)
	if list == null or middle_index == -1:
		return
	list.emit_signal(&"item_selected", middle_index)
	await process_frame
	await process_frame
	var rename_input: LineEdit = _find_line_edit(property)
	var rename_button: Button = _find_button(property, "Rename")
	_expect(rename_input == null, "%s selection keeps Rename closed until its button is activated." % section_title)
	_expect(rename_button != null and rename_button.visible, "%s selection exposes the real Rename button." % section_title)
	if rename_button == null:
		return
	rename_button.emit_signal(&"pressed")
	await process_frame
	await process_frame
	rename_input = _find_line_edit(property)
	_expect(rename_input != null and rename_input.text == "B", "%s Rename opens with the selected resource name." % section_title)
	_expect(rename_input != null and rename_input.has_focus(), "%s Rename field receives keyboard focus automatically." % section_title)
	_expect(rename_input != null and rename_input.get_selected_text() == "B", "%s Rename selects the current name so typing replaces it." % section_title)
	_expect(rename_input != null and rename_input.get_parent() == _section_list(property, section_title).get_parent(), "%s Rename field remains in the selected category." % section_title)
	if rename_input == null:
		return
	var enter_name: String = "%s Enter" % section_title
	rename_input.text = enter_name
	rename_input.emit_signal(&"text_submitted", enter_name)
	await process_frame
	await process_frame
	_expect(_test_display_name(middle) == enter_name, "%s Enter renames the resource found by its stable ID." % section_title)
	_expect(_section_rows_match_collection(property, section_title, _collection_for_test(controller.flow_graph, collection)), "%s Enter rebuilds the visible row without exposing IDs." % section_title)
	list = _section_list(property, section_title)
	_expect(list != null and list.is_selected(_item_index_for_internal_id(list, middle_id)), "%s Enter preserves the visible selection after rebuilding." % section_title)
	_expect(_find_line_edit(property) == null, "%s Enter closes the Rename field after confirmation." % section_title)
	_expect(list != null and list.has_focus(), "%s Enter returns keyboard focus to the selected row." % section_title)
	history.undo()
	await process_frame
	await process_frame
	_expect(_test_display_name(middle) == "B", "%s Rename undo restores the previous name." % section_title)
	history.redo()
	await process_frame
	await process_frame
	_expect(_test_display_name(middle) == enter_name, "%s Rename redo restores the submitted name." % section_title)
	rename_button = _find_button(property, "Rename")
	if rename_button == null:
		return
	rename_button.emit_signal(&"pressed")
	await process_frame
	await process_frame
	rename_input = _find_line_edit(property)
	if rename_input == null:
		return
	rename_input.text = "%s Cancelled" % section_title
	var escape_event: InputEventKey = InputEventKey.new()
	escape_event.pressed = true
	escape_event.keycode = KEY_ESCAPE
	rename_input.emit_signal(&"gui_input", escape_event)
	await process_frame
	await process_frame
	_expect(_test_display_name(middle) == enter_name, "%s Escape cancels Rename without mutating the resource." % section_title)
	_expect(_find_line_edit(property) == null, "%s Escape closes Rename after restoring the committed name." % section_title)
	list = _section_list(property, section_title)
	_expect(list != null and list.is_selected(_item_index_for_internal_id(list, middle_id)), "%s Escape preserves the visible selection after rebuilding." % section_title)
	_expect(list != null and list.has_focus(), "%s Escape returns keyboard focus to the selected row." % section_title)
	var move_down_button: Button = _find_button(property, "Move Down")
	_expect(move_down_button != null and move_down_button.visible, "%s selection exposes Move Down after Rename." % section_title)
	if move_down_button == null:
		return
	move_down_button.emit_signal(&"pressed")
	await process_frame
	await process_frame
	var after_move: Array = _collection_for_test(controller.flow_graph, collection)
	_expect(after_move.size() == 4 and after_move[0] == first and after_move[1] == null and after_move[2] == last and after_move[3] == middle, "%s Move Down changes exactly selected B while preserving the unrelated null position." % section_title)
	_expect(_test_resource_id(after_move[3] as Resource) == middle_id, "%s Move Down preserves B's stable ID." % section_title)
	_expect(_section_rows_match_collection(property, section_title, after_move), "%s Move Down keeps visible rows aligned with the model." % section_title)
	var delete_button: Button = _find_button(property, "Delete")
	_expect(delete_button != null and delete_button.visible, "%s selection exposes a valid Delete control." % section_title)
	if delete_button == null:
		return
	delete_button.emit_signal(&"pressed")
	await process_frame
	await process_frame
	var after_delete: Array = _collection_for_test(controller.flow_graph, collection)
	_expect(after_delete.size() == 3, "%s Delete removes one collection entry instead of adding a null slot." % section_title)
	_expect(after_delete[0] == first and after_delete[1] == null and after_delete[2] == last, "%s Delete removes selected B after Move while preserving the unrelated null position." % section_title)
	_expect(_item_index_for_internal_id(_section_list(property, section_title), middle_id) == -1, "%s Delete removes the deleted ID from visible rows." % section_title)
	_expect(_find_button(property, "Rename") == null and _find_button(property, "Delete") == null, "%s Delete clears stale selection controls." % section_title)
	_expect(_section_rows_match_collection(property, section_title, after_delete), "%s visible rows equal the compacted model after Delete." % section_title)
	_expect(_section_list_count(property, section_title) == 1, "%s Delete does not duplicate its list." % section_title)
	history.undo()
	await process_frame
	await process_frame
	var after_undo: Array = _collection_for_test(controller.flow_graph, collection)
	_expect(after_undo.size() == 4, "%s Undo restores the collection size." % section_title)
	_expect(after_undo[0] == first and after_undo[1] == null and after_undo[2] == last and after_undo[3] == middle, "%s Undo restores the moved resource, ID order, and the unrelated null position exactly." % section_title)
	_expect(_test_resource_id(after_undo[3] as Resource) == middle_id, "%s Undo restores the deleted resource's stable ID." % section_title)
	_expect(_section_rows_match_collection(property, section_title, after_undo), "%s Undo restores matching visible rows without IDs or synthetic empty rows." % section_title)
	history.undo()
	await process_frame
	await process_frame
	var after_move_undo: Array = _collection_for_test(controller.flow_graph, collection)
	_expect(after_move_undo.size() == 4 and after_move_undo[0] == first and after_move_undo[1] == null and after_move_undo[2] == middle and after_move_undo[3] == last, "%s Move undo restores A, null, B, C in the original order." % section_title)
	history.redo()
	await process_frame
	await process_frame
	history.redo()
	await process_frame
	await process_frame
	var after_redo: Array = _collection_for_test(controller.flow_graph, collection)
	_expect(after_redo.size() == 3 and after_redo[0] == first and after_redo[1] == null and after_redo[2] == last, "%s Redo removes the same middle resource again." % section_title)
	_expect(_section_rows_match_collection(property, section_title, after_redo), "%s Redo keeps visible rows equal to the compacted model." % section_title)
	history.undo()
	await process_frame
	await process_frame
	_expect(_has_visible_first_section_row(property, section_title), "%s final Undo retains a complete visible row." % section_title)


func _set_collection_fixture_size(
		graph: FlowGraph,
		collection: FlowGraphEditorCommands.Collection,
		count: int
) -> void:
	match collection:
		FlowGraphEditorCommands.Collection.PROCESSES:
			var processes: Array[FlowProcess] = []
			for index: int in count:
				var process: FlowProcess = FlowProcess.new()
				process.display_name = "Process %d" % index
				processes.append(process)
			graph.processes = processes
		FlowGraphEditorCommands.Collection.VARIABLES:
			var variables: Array[FlowVariableDefinition] = []
			for index: int in count:
				var variable: FlowVariableDefinition = FlowVariableDefinition.new()
				variable.display_name = "Variable %d" % index
				variables.append(variable)
			graph.variables = variables
		FlowGraphEditorCommands.Collection.STATE_MACHINES:
			var state_machines: Array[FlowStateMachineDefinition] = []
			for index: int in count:
				var state_machine: FlowStateMachineDefinition = FlowStateMachineDefinition.new()
				state_machine.display_name = "State Machine %d" % index
				state_machines.append(state_machine)
			graph.state_machines = state_machines


func _set_delete_fixture(graph: FlowGraph, collection: FlowGraphEditorCommands.Collection) -> Dictionary:
	match collection:
		FlowGraphEditorCommands.Collection.PROCESSES:
			var first_process: FlowProcess = FlowProcess.new()
			first_process.display_name = "A"
			var middle_process: FlowProcess = FlowProcess.new()
			middle_process.display_name = "B"
			var last_process: FlowProcess = FlowProcess.new()
			last_process.display_name = "C"
			graph.processes = [first_process, null, middle_process, last_process]
			return {"first": first_process, "middle": middle_process, "last": last_process}
		FlowGraphEditorCommands.Collection.VARIABLES:
			var first_variable: FlowVariableDefinition = FlowVariableDefinition.new()
			first_variable.display_name = "A"
			first_variable.scope = FlowVariableDefinition.Scope.GLOBAL
			var middle_variable: FlowVariableDefinition = FlowVariableDefinition.new()
			middle_variable.display_name = "B"
			middle_variable.scope = FlowVariableDefinition.Scope.GLOBAL
			var last_variable: FlowVariableDefinition = FlowVariableDefinition.new()
			last_variable.display_name = "C"
			last_variable.scope = FlowVariableDefinition.Scope.GLOBAL
			graph.variables = [first_variable, null, middle_variable, last_variable]
			return {"first": first_variable, "middle": middle_variable, "last": last_variable}
		FlowGraphEditorCommands.Collection.STATE_MACHINES:
			var first_machine: FlowStateMachineDefinition = FlowStateMachineDefinition.new()
			first_machine.display_name = "A"
			var middle_machine: FlowStateMachineDefinition = FlowStateMachineDefinition.new()
			middle_machine.display_name = "B"
			var last_machine: FlowStateMachineDefinition = FlowStateMachineDefinition.new()
			last_machine.display_name = "C"
			graph.state_machines = [first_machine, null, middle_machine, last_machine]
			return {"first": first_machine, "middle": middle_machine, "last": last_machine}
	return {}


func _collection_for_test(graph: FlowGraph, collection: FlowGraphEditorCommands.Collection) -> Array:
	match collection:
		FlowGraphEditorCommands.Collection.PROCESSES:
			return graph.processes
		FlowGraphEditorCommands.Collection.VARIABLES:
			return graph.variables
		FlowGraphEditorCommands.Collection.STATE_MACHINES:
			return graph.state_machines
	return []


func _item_index_for_internal_id(list: ItemList, internal_id: String) -> int:
	if list == null:
		return -1
	for index: int in list.item_count:
		var entry: Dictionary = list.get_item_metadata(index) as Dictionary
		if entry["internal_id"] == internal_id:
			return index
	return -1


func _section_rows_match_collection(property: FlowGraphInspectorProperty, section_title: String, values: Array) -> bool:
	var list: ItemList = _section_list(property, section_title)
	if list == null or list.item_count != values.size():
		return false
	for index: int in values.size():
		var text: String = list.get_item_text(index)
		var tooltip: String = list.get_item_tooltip(index)
		if values[index] == null:
			if text != "Empty" or not tooltip.is_empty():
				return false
			continue
		var resource: Resource = values[index] as Resource
		if text != _test_display_name(resource) or not tooltip.is_empty():
			return false
	return true


func _test_resource_id(resource: Resource) -> String:
	if resource is FlowBlockContainer:
		return (resource as FlowBlockContainer).get_internal_id()
	if resource is FlowVariableDefinition:
		return (resource as FlowVariableDefinition).get_internal_id()
	if resource is FlowStateMachineDefinition:
		return (resource as FlowStateMachineDefinition).get_internal_id()
	return ""


func _test_display_name(resource: Resource) -> String:
	if resource is FlowBlockContainer:
		return (resource as FlowBlockContainer).display_name
	if resource is FlowVariableDefinition:
		return (resource as FlowVariableDefinition).display_name
	if resource is FlowStateMachineDefinition:
		return (resource as FlowStateMachineDefinition).display_name
	return ""


func _collection_size(graph: FlowGraph, collection: FlowGraphEditorCommands.Collection) -> int:
	match collection:
		FlowGraphEditorCommands.Collection.PROCESSES:
			return graph.processes.size()
		FlowGraphEditorCommands.Collection.VARIABLES:
			return graph.variables.size()
		FlowGraphEditorCommands.Collection.STATE_MACHINES:
			return graph.state_machines.size()
	return -1


func _visible_section_row_count(property: FlowGraphInspectorProperty, section_title: String) -> int:
	var list: ItemList = _section_list(property, section_title)
	return list.item_count if list != null and list.is_visible_in_tree() else -1


func _has_visible_first_section_row(property: FlowGraphInspectorProperty, section_title: String) -> bool:
	var list: ItemList = _section_list(property, section_title)
	if list == null or not list.is_visible_in_tree() or list.item_count == 0:
		return false
	var first_row_rect: Rect2 = list.get_item_rect(0)
	return first_row_rect.size.x > 0.0 \
		and first_row_rect.size.y > 0.0 \
		and first_row_rect.position.y >= 0.0 \
		and first_row_rect.end.y <= list.size.y


func _section_list_count(property: FlowGraphInspectorProperty, section_title: String) -> int:
	var title: Label = _find_label(property, section_title)
	if title == null:
		return 0
	var count: int = 0
	for child: Node in title.get_parent().get_children():
		if child is ItemList:
			count += 1
	return count


func _section_list(property: FlowGraphInspectorProperty, section_title: String) -> ItemList:
	var title: Label = _find_label(property, section_title)
	if title == null:
		return null
	for child: Node in title.get_parent().get_children():
		if child is ItemList:
			return child as ItemList
	return null


func _find_label(root: Node, label_text: String) -> Label:
	if root is Label and (root as Label).text == label_text:
		return root as Label
	for child: Node in root.get_children():
		var label: Label = _find_label(child, label_text)
		if label != null:
			return label
	return null


func _test_debug_instrumentation_removed() -> void:
	var sources: Array[String] = [
		FileAccess.get_file_as_string("res://addons/vp_flujo/plugin.gd"),
		FileAccess.get_file_as_string("res://addons/vp_flujo/editor/pv_controller_inspector_plugin.gd"),
		FileAccess.get_file_as_string("res://addons/vp_flujo/editor/flow_graph_inspector_property.gd"),
	]
	for source: String in sources:
		_expect(not source.contains("InspectorDebug") and not source.contains("DockDebug"), "Temporary debug output is removed.")
		_expect(not source.contains("DEBUG_INSPECTOR") and not source.contains("DEBUG_DOCK"), "Temporary debug constants are removed.")
