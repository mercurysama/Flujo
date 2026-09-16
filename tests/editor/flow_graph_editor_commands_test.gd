@tool
extends SceneTree


var _failures: Array[String] = []
var _changes: int = 0
var _selection_emitter_inside_tree: bool = false
var _selection_event_count: int = 0

const TEMP_DIR_PATH: String = "res://.godot/flujo_tests"
const TEMP_HISTORY_SCENE_PATH: String = TEMP_DIR_PATH + "/flow_graph_editor_history.tscn"
const VP_FLUJO_DOCK_SCRIPT := preload("res://addons/vp_flujo/editor/vp_flujo_dock.gd")
const VP_FLUJO_PLUGIN_SCRIPT := preload("res://addons/vp_flujo/plugin.gd")
const FLOW_INTERACTION_COORDINATOR_SCRIPT := preload("res://addons/vp_flujo/editor/flow_interaction_coordinator.gd")


class CoordinatorTestDock extends VPFlujoDock:
	func activate_flow_interaction() -> void:
		show()
		call(&"_set_interaction_presentation", "Flow", "Leave Flow (F4)", false)


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
	var dock: Node = VP_FLUJO_DOCK_SCRIPT.new()
	dock.call(&"configure", undo_redo)
	get_root().add_child(dock)
	var dock_control: Control = dock as Control
	_expect(dock_control != null and is_zero_approx(dock_control.custom_minimum_size.x), "Flujo dock leaves width to the native editor layout instead of enforcing a permanent minimum.")
	if dock_control != null:
		dock_control.size.x = 160.0
	dock.call(&"set_controller", controller)
	var dock_property: FlowGraphInspectorProperty = dock.call(&"get_variable_editor") as FlowGraphInspectorProperty
	_expect(dock_property != null, "Flujo dock creates one schema 3 Variables editor.")
	if dock_property != null:
		inspector_property.schema_3_variable_selection_changed.connect(
			Callable(dock, &"set_variable_selection")
		)
		inspector_property.schema_3_variable_editor_focus_requested.connect(
			Callable(dock, &"focus_variable_editor")
		)
		dock.schema_3_variable_list_focus_requested.connect(
			Callable(inspector_property, &"focus_schema_3_variable_list")
		)
	await process_frame
	await process_frame
	_expect(dock_control != null and dock_control.size.x < 320.0 and is_zero_approx(dock_control.custom_minimum_size.x), "Flujo dock permits native SplitContainer reduction without resetting its layout.")
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
	await _test_schema_2_to_3_migration_action(inspector_property, dock_property, controller, history, undo_redo)
	await _test_schema_3_variable_inspector(inspector_property, dock_property, controller, history)
	await _test_schema_3_dock_controller_switch(dock, dock_property, controller)
	dock.call(&"set_controller", null)
	await process_frame
	dock.queue_free()
	inspector_scroll.queue_free()
	await process_frame
	await process_frame
	_expect(not is_instance_valid(dock), "The schema 3 dock is released before the editor test continues.")
	_expect(not is_instance_valid(inspector_scroll), "The inspector test host is released before the editor test continues.")
	await _test_plugin_variable_selection_relay(undo_redo)
	await _test_flow_interaction_coordinator(undo_redo)
	controller.flow_graph = null
	_test_dock_visibility_conditions()
	_test_debug_instrumentation_removed()
	_test_public_plugin_language()

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


func _find_delete_confirmation(root: Node) -> ConfirmationDialog:
	if root is ConfirmationDialog and root.name == &"FlowGraphDeleteConfirmation":
		return root as ConfirmationDialog
	for child: Node in root.get_children():
		var confirmation: ConfirmationDialog = _find_delete_confirmation(child)
		if confirmation != null:
			return confirmation
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

	var schema_3_graph: FlowGraph = FlowGraph.new()
	schema_3_graph.schema_version = FlowGraph.SCHEMA_VERSION_3
	schema_3_graph.constructor = FlowConstructorDefinition.new()
	var schema_3_variable: FlowVariableDefinition = FlowVariableDefinition.new()
	schema_3_variable.display_name = "Scene Variable"
	schema_3_variable.scope = FlowVariableDefinition.Scope.GLOBAL
	schema_3_variable.value_type = FlowVariableDefinition.ValueType.STRING
	schema_3_graph.variables = [schema_3_variable]
	scene_controller.flow_graph = schema_3_graph
	EditorInterface.save_scene()
	await process_frame
	global_version = global_history.get_version()
	var schema_3_updates: Array[Dictionary] = [
		{"property": &"display_name", "value": "Edited Scene Variable"},
		{"property": &"value_type", "value": FlowVariableDefinition.ValueType.COLOR},
		{"property": &"color_value", "value": Color(0.2, 0.4, 0.6, 1.0)},
		{"property": &"scope", "value": FlowVariableDefinition.Scope.LOCAL},
		{"property": &"binding", "value": FlowVariableDefinition.Binding.GLOBAL_REFERENCE},
		{"property": &"persistent", "value": true},
		{"property": &"user_note", "value": "Scene note"},
	]
	for update: Dictionary in schema_3_updates:
		previous_scene_version = scene_history.get_version()
		_expect(
			commands.set_variable_property(
				scene_controller,
				schema_3_variable.get_internal_id(),
				update["property"] as StringName,
				update["value"]
			),
			"Schema 3 variable property uses the opened scene history."
		)
		_expect(scene_history.get_version() > previous_scene_version, "Schema 3 variable edit advances scene history.")
		_expect(global_history.get_version() == global_version, "Schema 3 variable edit does not advance global history.")
		_expect(_is_temporary_scene_unsaved(), "Schema 3 variable edit marks the scene as unsaved.")
		scene_history.undo()
		scene_history.redo()
	_expect(schema_3_variable.display_name == "Edited Scene Variable", "Schema 3 scene history redoes Name.")
	_expect(schema_3_variable.value_type == FlowVariableDefinition.ValueType.COLOR, "Schema 3 scene history redoes Type.")
	_expect(schema_3_variable.color_value == Color(0.2, 0.4, 0.6, 1.0), "Schema 3 scene history redoes Value.")
	_expect(schema_3_variable.scope == FlowVariableDefinition.Scope.LOCAL, "Schema 3 scene history redoes Scope.")
	_expect(schema_3_variable.binding == FlowVariableDefinition.Binding.GLOBAL_REFERENCE, "Schema 3 scene history redoes Binding.")
	_expect(schema_3_variable.persistent and schema_3_variable.user_note == "Scene note", "Schema 3 scene history redoes Persistent and Note.")
	EditorInterface.save_scene()
	await process_frame
	_expect(not _is_temporary_scene_unsaved(), "Saving schema 3 variable edits clears native unsaved state.")

	var schema_2_graph: FlowGraph = FlowGraph.new()
	schema_2_graph.schema_version = FlowGraph.SCHEMA_VERSION_2
	var schema_2_variable: FlowVariableDefinition = FlowVariableDefinition.new()
	schema_2_variable.display_name = "Migration Context Variable"
	schema_2_variable.scope = FlowVariableDefinition.Scope.GLOBAL
	schema_2_graph.variables = [schema_2_variable]
	scene_controller.flow_graph = schema_2_graph
	EditorInterface.save_scene()
	await process_frame
	global_version = global_history.get_version()
	previous_scene_version = scene_history.get_version()
	_expect(commands.migrate_to_schema_3(scene_controller), "Schema 2 to 3 migration uses the opened scene history.")
	var schema_3_migrated: FlowGraph = scene_controller.flow_graph
	_expect(schema_3_migrated != schema_2_graph and schema_3_migrated.schema_version == FlowGraph.SCHEMA_VERSION_3, "Scene-context migration replaces schema 2 only with a schema 3 graph.")
	_expect(scene_history.get_version() > previous_scene_version and global_history.get_version() == global_version, "Schema 2 to 3 migration advances only the scene history.")
	_expect(_is_temporary_scene_unsaved(), "Schema 2 to 3 migration marks the opened scene as unsaved through native tracking.")
	scene_history.undo()
	_expect(scene_controller.flow_graph == schema_2_graph and scene_controller.flow_graph.schema_version == FlowGraph.SCHEMA_VERSION_2, "Scene-context migration Undo restores the exact schema 2 graph.")
	scene_history.redo()
	_expect(scene_controller.flow_graph == schema_3_migrated and scene_controller.flow_graph.schema_version == FlowGraph.SCHEMA_VERSION_3, "Scene-context migration Redo restores the schema 3 candidate.")
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
	_expect(delete_button != null, "Selection exposes a Delete control before confirmation coverage.")
	if delete_button == null:
		return
	var history_version: int = history.get_version()
	delete_button.emit_signal(&"pressed")
	await process_frame
	await process_frame
	var confirmation: ConfirmationDialog = _find_delete_confirmation(property)
	_expect(confirmation != null, "Delete opens a confirmation dialog before mutating the selected process.")
	_expect(controller.flow_graph.processes.size() == 1 and history.get_version() == history_version, "Opening Delete confirmation does not mutate the model or history.")
	if confirmation == null:
		return
	confirmation.emit_signal(&"canceled")
	await process_frame
	_expect(controller.flow_graph.processes.size() == 1 and history.get_version() == history_version, "Canceling Delete leaves the selected process and history unchanged.")
	delete_button = _find_button(property, "Delete")
	if delete_button == null:
		return
	delete_button.emit_signal(&"pressed")
	await process_frame
	confirmation = _find_delete_confirmation(property)
	if confirmation == null:
		return
	confirmation.emit_signal(&"confirmed")
	confirmation.emit_signal(&"confirmed")
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
	var history_version: int = history.get_version()
	delete_button.emit_signal(&"pressed")
	await process_frame
	var confirmation: ConfirmationDialog = _find_delete_confirmation(property)
	_expect(confirmation != null, "%s Delete opens an explicit confirmation dialog." % section_title)
	if confirmation == null:
		return
	_expect(not confirmation.title.contains(middle_id) and not confirmation.dialog_text.contains(middle_id), "%s Delete confirmation shows only the visible resource name, never its internal ID." % section_title)
	_expect(_collection_for_test(controller.flow_graph, collection).size() == 4 and history.get_version() == history_version, "%s Delete waits for confirmation without mutating the model or history." % section_title)
	confirmation.emit_signal(&"canceled")
	await process_frame
	_expect(_collection_for_test(controller.flow_graph, collection).size() == 4 and history.get_version() == history_version, "%s Delete cancel or Escape leaves the collection and history unchanged." % section_title)
	delete_button = _find_button(property, "Delete")
	if delete_button == null:
		return
	delete_button.emit_signal(&"pressed")
	await process_frame
	confirmation = _find_delete_confirmation(property)
	if confirmation == null:
		return
	confirmation.emit_signal(&"confirmed")
	confirmation.emit_signal(&"confirmed")
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


func _test_schema_3_variable_inspector(
		inspector_property: FlowGraphInspectorProperty,
		dock_property: FlowGraphInspectorProperty,
		controller: PVController,
		history: UndoRedo
) -> void:
	var graph: FlowGraph = _schema_3_variable_fixture()
	var process: FlowProcess = FlowProcess.new()
	process.display_name = "Schema 3 Process"
	graph.processes = [process]
	var state_machine: FlowStateMachineDefinition = FlowStateMachineDefinition.new()
	state_machine.display_name = "Schema 3 State Machine"
	graph.state_machines = [state_machine]
	controller.flow_graph = graph
	inspector_property.call(&"_rebuild_interface")
	dock_property.refresh_dock_controller()
	await process_frame
	await process_frame
	_expect(_find_button(inspector_property, "Add Variable") != null, "Schema 3 Inspector owns the structural Add Variable action.")
	_expect(_find_button(inspector_property, "Add Process") != null and _find_button(inspector_property, "Add State Machine") != null, "Schema 3 Inspector keeps inherited Process and State Machine structural actions.")
	_expect(_section_rows_match_collection(inspector_property, "Processes", graph.processes) and _section_rows_match_collection(inspector_property, "State Machines", graph.state_machines), "Schema 3 Inspector presents inherited Process and State Machine collections.")
	_expect(_find_node_by_name(inspector_property, &"Schema3VariableEditor") == null, "Schema 3 Inspector does not duplicate variable option controls.")
	_expect(_find_button(dock_property, "Add Process") == null, "Schema 3 dock does not expose process authoring.")
	_expect(_find_button(dock_property, "Add State Machine") == null, "Schema 3 dock does not expose state-machine authoring.")
	_expect(_find_button(dock_property, "Add Variable") == null and _section_list(dock_property, "Variables") == null, "Schema 3 dock contains no structural Variables controls.")
	_expect(_section_rows_match_collection(inspector_property, "Variables", graph.variables), "Schema 3 Inspector variable rows use names without IDs.")
	var variable_list: ItemList = _section_list(inspector_property, "Variables")
	_expect(variable_list != null and variable_list.item_count == graph.variables.size(), "Schema 3 Inspector keeps nullable variable row order.")
	_expect(_has_label_containing(dock_property, "Select a Schema 3 Variable"), "Schema 3 dock gives an English instruction without a selection.")
	await _test_schema_3_selection_without_list_rebuild(
		inspector_property,
		dock_property,
		graph,
		history
	)
	var process_list: ItemList = _section_list(inspector_property, "Processes")
	if process_list != null:
		process_list.emit_signal(&"item_selected", 0)
		await process_frame
		await process_frame
		_expect(_has_label_containing(dock_property, "Select a Schema 3 Variable"), "Selecting a Process clears schema 3 Variable options.")
	var state_machine_list: ItemList = _section_list(inspector_property, "State Machines")
	if state_machine_list != null:
		state_machine_list.emit_signal(&"item_selected", 0)
		await process_frame
		await process_frame
		_expect(_has_label_containing(dock_property, "Select a Schema 3 Variable"), "Selecting a State Machine clears schema 3 Variable options.")
	if variable_list == null:
		return
	await _test_schema_3_keyboard_accessibility(inspector_property, dock_property, graph)
	await _test_schema_3_variable_escape_navigation(inspector_property, dock_property, graph)
	for value_type: int in range(FlowVariableDefinition.ValueType.BOOL, FlowVariableDefinition.ValueType.COLOR + 1):
		await _select_variable_row(inspector_property, value_type)
		var value_control: Control = _find_node_by_name(dock_property, _value_control_name(value_type)) as Control
		_expect(value_control != null and value_control.focus_mode != Control.FOCUS_NONE, "Schema 3 dock renders a focusable value control for type %d." % value_type)
		_expect(_count_named_nodes(dock_property, &"Schema3VariableEditor") == 1, "Schema 3 dock selection creates one variable editor.")

	var string_variable: FlowVariableDefinition = graph.variables[FlowVariableDefinition.ValueType.STRING]
	var original_name: String = string_variable.display_name
	await _select_variable_row(inspector_property, FlowVariableDefinition.ValueType.STRING)
	var name_input: LineEdit = _find_node_by_name(dock_property, &"VariableNameInput") as LineEdit
	var selected_list: ItemList = _section_list(inspector_property, "Variables")
	_expect(name_input != null and name_input.text == original_name and selected_list != null and selected_list.is_selected(FlowVariableDefinition.ValueType.STRING), "Schema 3 dock Name field follows the Inspector-owned selected row without requiring a focus transfer.")
	if name_input == null:
		return
	name_input.text = "Renamed Schema 3 Variable"
	name_input.emit_signal(&"text_submitted", name_input.text)
	await process_frame
	await process_frame
	_expect(string_variable.display_name == "Renamed Schema 3 Variable", "Schema 3 dock Name changes the selected stable-ID resource.")
	name_input = _find_node_by_name(dock_property, &"VariableNameInput") as LineEdit
	_expect(name_input != null and name_input.has_focus(), "Schema 3 Name Enter restores focus to the current dock field.")
	history.undo()
	await process_frame
	await process_frame
	_expect(string_variable.display_name == original_name, "Schema 3 dock Name undo restores the selected resource.")
	history.redo()
	await process_frame
	await process_frame
	_expect(string_variable.display_name == "Renamed Schema 3 Variable", "Schema 3 dock Name redo restores the edit.")
	name_input = _find_node_by_name(dock_property, &"VariableNameInput") as LineEdit
	if name_input == null:
		return
	name_input.text = "Cancelled Schema 3 Name"
	var cancel_name: InputEventKey = InputEventKey.new()
	cancel_name.pressed = true
	cancel_name.keycode = KEY_ESCAPE
	name_input.emit_signal(&"gui_input", cancel_name)
	await process_frame
	await process_frame
	selected_list = _section_list(inspector_property, "Variables")
	var cancelled_name_index: int = _item_index_for_internal_id(selected_list, string_variable.get_internal_id())
	_expect(string_variable.display_name == "Renamed Schema 3 Variable" and selected_list != null and cancelled_name_index >= 0 and selected_list.is_selected(cancelled_name_index) and selected_list.has_focus(), "Schema 3 dock Name Escape cancels without mutation and returns focus to the selected Inspector row.")
	var string_input: TextEdit = _find_node_by_name(dock_property, &"VariableStringValue") as TextEdit
	_expect(string_input != null and string_input.custom_minimum_size.y > 0.0, "Schema 3 dock String uses a visibly sized themed TextEdit.")
	if string_input == null:
		return
	var history_version: int = history.get_version()
	string_input.text = "first line\nsecond line"
	var enter_event: InputEventKey = InputEventKey.new()
	enter_event.pressed = true
	enter_event.keycode = KEY_ENTER
	string_input.emit_signal(&"gui_input", enter_event)
	_expect(string_variable.string_value == "", "Schema 3 dock Enter keeps multiline String edits in the temporary interface buffer.")
	var submit_string: InputEventKey = InputEventKey.new()
	submit_string.pressed = true
	submit_string.keycode = KEY_ENTER
	submit_string.ctrl_pressed = true
	string_input.emit_signal(&"gui_input", submit_string)
	await process_frame
	await process_frame
	_expect(string_variable.string_value == "first line\nsecond line" and history.get_version() == history_version + 1, "Schema 3 dock Ctrl+Enter commits one multiline String undo action.")
	string_input = _find_node_by_name(dock_property, &"VariableStringValue") as TextEdit
	_expect(string_input != null and string_input.has_focus(), "Schema 3 dock rebuild restores focus to the edited multiline value control.")
	history.undo()
	await process_frame
	await process_frame
	_expect(string_variable.string_value == "", "Schema 3 dock String undo restores its original value.")
	history.redo()
	await process_frame
	await process_frame
	_expect(string_variable.string_value == "first line\nsecond line", "Schema 3 dock String redo restores its submitted value.")
	string_input = _find_node_by_name(dock_property, &"VariableStringValue") as TextEdit
	if string_input == null:
		return
	string_input.text = "discarded text"
	var cancel_string: InputEventKey = InputEventKey.new()
	cancel_string.pressed = true
	cancel_string.keycode = KEY_ESCAPE
	string_input.emit_signal(&"gui_input", cancel_string)
	_expect(string_variable.string_value == "first line\nsecond line" and string_input.text == "first line\nsecond line", "Schema 3 dock String Escape discards its temporary buffer.")

	var int_variable: FlowVariableDefinition = graph.variables[FlowVariableDefinition.ValueType.INT]
	int_variable.bool_value = true
	int_variable.int_value = 73
	int_variable.string_value = "inactive value"
	await _select_variable_row(inspector_property, FlowVariableDefinition.ValueType.INT)
	var type_option: OptionButton = _find_node_by_name(dock_property, &"VariableTypeOption") as OptionButton
	_expect(type_option != null, "Schema 3 dock Type selector is visible for the selected variable.")
	if type_option == null:
		return
	_emit_option_selection(type_option, FlowVariableDefinition.ValueType.STRING)
	await process_frame
	await process_frame
	_expect(int_variable.value_type == FlowVariableDefinition.ValueType.STRING, "Schema 3 dock Type updates by stable ID.")
	_expect(int_variable.bool_value and int_variable.int_value == 73 and int_variable.string_value == "inactive value", "Schema 3 dock Type keeps inactive fields literal.")
	history.undo()
	await process_frame
	await process_frame
	_expect(int_variable.value_type == FlowVariableDefinition.ValueType.INT, "Schema 3 dock Type undo restores the previous canonical type.")
	history.redo()
	await process_frame
	await process_frame
	_expect(int_variable.value_type == FlowVariableDefinition.ValueType.STRING, "Schema 3 dock Type redo restores the new canonical type.")

	await _select_variable_row(inspector_property, FlowVariableDefinition.ValueType.BOOL)
	var advanced_toggle: Button = _find_node_by_name(dock_property, &"VariableAdvancedToggle") as Button
	_expect(advanced_toggle != null and not advanced_toggle.button_pressed, "Schema 3 dock advanced variable fields start collapsed.")
	if advanced_toggle == null:
		return
	advanced_toggle.emit_signal(&"toggled", true)
	await process_frame
	await process_frame
	var scope_option: OptionButton = _find_node_by_name(dock_property, &"VariableScopeOption") as OptionButton
	var binding_option: OptionButton = _find_node_by_name(dock_property, &"VariableBindingOption") as OptionButton
	var persistent_input: CheckBox = _find_node_by_name(dock_property, &"VariablePersistentCheckBox") as CheckBox
	var note_input: TextEdit = _find_node_by_name(dock_property, &"VariableNoteInput") as TextEdit
	_expect(scope_option != null and binding_option != null and persistent_input != null and note_input != null, "Schema 3 dock advanced fields render only after explicit expansion.")
	if scope_option == null or binding_option == null or persistent_input == null or note_input == null:
		return
	var bool_variable: FlowVariableDefinition = graph.variables[FlowVariableDefinition.ValueType.BOOL]
	_emit_option_selection(scope_option, FlowVariableDefinition.Scope.LOCAL)
	await process_frame
	await process_frame
	_expect(bool_variable.scope == FlowVariableDefinition.Scope.LOCAL, "Schema 3 dock Scope updates the selected variable.")
	scope_option = _find_node_by_name(dock_property, &"VariableScopeOption") as OptionButton
	_expect(scope_option != null and scope_option.has_focus(), "Schema 3 dock rebuild restores focus to the edited advanced control.")
	history.undo()
	history.redo()
	_expect(bool_variable.scope == FlowVariableDefinition.Scope.LOCAL, "Schema 3 dock Scope participates in undo and redo.")
	await _select_variable_row(inspector_property, FlowVariableDefinition.ValueType.BOOL)
	binding_option = _find_node_by_name(dock_property, &"VariableBindingOption") as OptionButton
	persistent_input = _find_node_by_name(dock_property, &"VariablePersistentCheckBox") as CheckBox
	note_input = _find_node_by_name(dock_property, &"VariableNoteInput") as TextEdit
	if binding_option == null or persistent_input == null or note_input == null:
		return
	_emit_option_selection(binding_option, FlowVariableDefinition.Binding.GLOBAL_REFERENCE)
	await process_frame
	await process_frame
	_expect(bool_variable.binding == FlowVariableDefinition.Binding.GLOBAL_REFERENCE, "Schema 3 Binding updates the selected variable.")
	await _select_variable_row(inspector_property, FlowVariableDefinition.ValueType.BOOL)
	persistent_input = _find_node_by_name(dock_property, &"VariablePersistentCheckBox") as CheckBox
	note_input = _find_node_by_name(dock_property, &"VariableNoteInput") as TextEdit
	if persistent_input == null or note_input == null:
		return
	persistent_input.emit_signal(&"toggled", true)
	await process_frame
	await process_frame
	_expect(bool_variable.persistent, "Schema 3 Persistent updates the selected variable.")
	await _select_variable_row(inspector_property, FlowVariableDefinition.ValueType.BOOL)
	note_input = _find_node_by_name(dock_property, &"VariableNoteInput") as TextEdit
	if note_input == null:
		return
	_expect(
		note_input.focus_mode != Control.FOCUS_NONE and note_input.custom_minimum_size.y > 0.0 \
			and note_input.size.y >= note_input.custom_minimum_size.y \
			and note_input.wrap_mode != TextEdit.LINE_WRAPPING_NONE,
		"Schema 3 Note uses a visibly sized multiline TextEdit."
	)
	note_input.grab_focus()
	_expect(note_input.has_focus(), "Schema 3 Note accepts native keyboard focus.")
	note_input.text = "Schema 3 note\n"
	var note_enter: InputEventKey = InputEventKey.new()
	note_enter.pressed = true
	note_enter.keycode = KEY_ENTER
	note_input.emit_signal(&"gui_input", note_enter)
	await process_frame
	_expect(note_input.text == "Schema 3 note\n" and bool_variable.user_note.is_empty(), "Schema 3 Note keeps its multiline Enter buffer without committing it.")
	var note_history_version: int = history.get_version()
	var submit_note: InputEventKey = InputEventKey.new()
	submit_note.pressed = true
	submit_note.keycode = KEY_ENTER
	submit_note.ctrl_pressed = true
	note_input.emit_signal(&"gui_input", submit_note)
	await process_frame
	await process_frame
	_expect(bool_variable.user_note == "Schema 3 note\n" and history.get_version() == note_history_version + 1, "Schema 3 Note applies only by its explicit Ctrl+Enter action.")
	note_input = _find_node_by_name(dock_property, &"VariableNoteInput") as TextEdit
	if note_input == null:
		return
	note_input.grab_focus()
	note_input.text = "Discarded note"
	var cancel_note: InputEventKey = InputEventKey.new()
	cancel_note.pressed = true
	cancel_note.keycode = KEY_ESCAPE
	note_input.emit_signal(&"gui_input", cancel_note)
	await process_frame
	await process_frame
	var note_list: ItemList = _section_list(inspector_property, "Variables")
	var note_row_index: int = _item_index_for_internal_id(note_list, bool_variable.get_internal_id())
	_expect(
		bool_variable.user_note == "Schema 3 note\n" and note_list != null and note_row_index >= 0 \
			and note_list.is_selected(note_row_index) and note_list.has_focus(),
		"Schema 3 Note Escape discards its buffer and returns to the selected Inspector row."
	)

	var color_variable: FlowVariableDefinition = graph.variables[FlowVariableDefinition.ValueType.COLOR]
	var original_color: Color = color_variable.color_value
	await _select_variable_row(inspector_property, FlowVariableDefinition.ValueType.COLOR)
	var color_button: ColorPickerButton = _find_node_by_name(dock_property, &"VariableColorValue") as ColorPickerButton
	_expect(color_button != null and color_button.is_inside_tree(), "Schema 3 dock parents the COLOR picker before it receives popup signals.")
	if color_button == null or not color_button.is_inside_tree():
		return
	var picker: ColorPicker = color_button.get_picker()
	_expect(picker != null and picker.is_inside_tree(), "Schema 3 creates the internal COLOR picker only after its button is inside the control tree.")
	if picker == null or not picker.is_inside_tree():
		return
	_expect(color_button.custom_minimum_size.y > 0.0 and color_button.size.y >= color_button.custom_minimum_size.y, "Schema 3 COLOR uses a theme-sized visible swatch instead of the default compact button geometry.")
	_expect(color_button.color == original_color, "Schema 3 COLOR swatch shows the confirmed color before its popup opens.")
	var first_preview_color: Color = Color(0.1, 0.3, 0.6, 1.0)
	var preview_color: Color = Color(0.2, 0.4, 0.8, 1.0)
	color_button.emit_signal(&"pressed")
	color_button.grab_focus()
	_expect(
		color_button.has_focus() and color_button.focus_mode != Control.FOCUS_NONE,
		"Schema 3 COLOR remains a native Tab/Shift+Tab focus target while its popup is open."
	)
	color_button.emit_signal(&"color_changed", first_preview_color)
	color_button.emit_signal(&"color_changed", preview_color)
	_expect(color_button.color == preview_color and color_variable.color_value == original_color, "COLOR updates the provisional swatch without creating an immediate model action.")
	var color_history_version: int = history.get_version()
	color_button.emit_signal(&"popup_closed")
	await process_frame
	await process_frame
	_expect(color_variable.color_value == preview_color and history.get_version() == color_history_version + 1, "Closing COLOR commits at most one Undo/Redo action.")
	var variable_list_after_color: ItemList = _section_list(inspector_property, "Variables")
	var color_row_index: int = _item_index_for_internal_id(variable_list_after_color, color_variable.get_internal_id())
	var confirmed_color_button: ColorPickerButton = _find_node_by_name(dock_property, &"VariableColorValue") as ColorPickerButton
	_expect(confirmed_color_button != null and confirmed_color_button.color == preview_color, "Schema 3 COLOR rebuilds its swatch with the confirmed color after closing the popup.")
	_expect(_count_named_nodes(dock_property, &"VariableColorValue") == 1, "Closing COLOR rebuilds one current swatch without duplicate controls.")
	_expect(
		variable_list_after_color != null and color_row_index >= 0 \
			and variable_list_after_color.is_selected(color_row_index),
		"Closing COLOR retains the stable-ID-selected Variable row without requiring keyboard focus."
	)
	_expect(
		variable_list_after_color == null or variable_list_after_color.focus_mode != Control.FOCUS_NONE,
		"The selected Variable list remains available to native Tab/Shift+Tab keyboard navigation."
	)
	_expect(
		variable_list_after_color == null or not variable_list_after_color.has_focus(),
		"Closing COLOR does not forcibly steal keyboard focus from Godot's natural popup flow."
	)
	history.undo()
	await process_frame
	await process_frame
	var undo_color_button: ColorPickerButton = _find_node_by_name(dock_property, &"VariableColorValue") as ColorPickerButton
	variable_list_after_color = _section_list(inspector_property, "Variables")
	color_row_index = _item_index_for_internal_id(variable_list_after_color, color_variable.get_internal_id())
	_expect(
		undo_color_button != null and undo_color_button.color == original_color \
			and variable_list_after_color != null and color_row_index >= 0 \
			and variable_list_after_color.is_selected(color_row_index),
		"COLOR Undo restores the swatch and the semantic stable-ID row selection."
	)
	_expect(
		variable_list_after_color == null or not variable_list_after_color.has_focus(),
		"COLOR Undo does not redirect keyboard focus to the structural Variable list."
	)
	history.redo()
	await process_frame
	await process_frame
	var redo_color_button: ColorPickerButton = _find_node_by_name(dock_property, &"VariableColorValue") as ColorPickerButton
	variable_list_after_color = _section_list(inspector_property, "Variables")
	color_row_index = _item_index_for_internal_id(variable_list_after_color, color_variable.get_internal_id())
	_expect(
		color_variable.color_value == preview_color and redo_color_button != null \
			and redo_color_button.color == preview_color and variable_list_after_color != null \
			and color_row_index >= 0 and variable_list_after_color.is_selected(color_row_index),
		"COLOR Redo restores the confirmed swatch and semantic stable-ID selection."
	)
	_expect(
		variable_list_after_color == null or not variable_list_after_color.has_focus(),
		"COLOR Redo does not redirect keyboard focus to the structural Variable list."
	)

	var invalid_variable: FlowVariableDefinition = graph.variables[8]
	var invalid_scope: int = invalid_variable.scope
	var invalid_binding: int = invalid_variable.binding
	var invalid_type: int = invalid_variable.value_type
	await _select_variable_row(inspector_property, 8)
	_expect(_find_node_by_name(dock_property, &"VariableInvalidValueType") != null, "Schema 3 dock preserves and displays an invalid type without repair.")
	_expect(invalid_variable.scope == invalid_scope and invalid_variable.binding == invalid_binding and invalid_variable.value_type == invalid_type, "Opening invalid schema 3 metadata does not normalize it.")
	type_option = _find_node_by_name(dock_property, &"VariableTypeOption") as OptionButton
	if type_option == null:
		return
	_emit_option_selection(type_option, FlowVariableDefinition.ValueType.BOOL)
	await process_frame
	await process_frame
	scope_option = _find_node_by_name(dock_property, &"VariableScopeOption") as OptionButton
	if scope_option == null:
		return
	_emit_option_selection(scope_option, FlowVariableDefinition.Scope.GLOBAL)
	await process_frame
	await process_frame
	binding_option = _find_node_by_name(dock_property, &"VariableBindingOption") as OptionButton
	if binding_option == null:
		return
	_emit_option_selection(binding_option, FlowVariableDefinition.Binding.OWN_VALUE)
	await process_frame
	await process_frame
	_expect(not FlowGraphValidator.validate(graph).has_errors(), "Explicit schema 3 enum replacements restore a valid graph without implicit repair.")

	await _select_variable_row(inspector_property, FlowVariableDefinition.ValueType.FLOAT)
	var selected_variable: FlowVariableDefinition = graph.variables[FlowVariableDefinition.ValueType.FLOAT]
	var selected_id: String = selected_variable.get_internal_id()
	var move_down: Button = _find_button(inspector_property, "Move Down")
	_expect(move_down != null, "Schema 3 Inspector selected variable exposes Move.")
	if move_down != null:
		move_down.emit_signal(&"pressed")
	await process_frame
	await process_frame
	var moved_variable_list: ItemList = _section_list(inspector_property, "Variables")
	var moved_variable_index: int = _item_index_for_internal_id(moved_variable_list, selected_id)
	_expect(
		moved_variable_list != null and moved_variable_index >= 0 \
			and moved_variable_list.is_selected(moved_variable_index),
		"Schema 3 Inspector Move preserves semantic stable-ID selection after rebuilding its row."
	)
	history.undo()
	await process_frame
	await process_frame
	var undo_moved_variable_list: ItemList = _section_list(inspector_property, "Variables")
	var undo_moved_variable_index: int = _item_index_for_internal_id(undo_moved_variable_list, selected_id)
	_expect(
		undo_moved_variable_list != null and undo_moved_variable_index >= 0 \
			and undo_moved_variable_list.is_selected(undo_moved_variable_index),
		"Schema 3 Inspector Move Undo preserves semantic stable-ID selection."
	)
	history.redo()
	await process_frame
	await process_frame
	moved_variable_list = _section_list(inspector_property, "Variables")
	moved_variable_index = _item_index_for_internal_id(moved_variable_list, selected_id)
	_expect(
		moved_variable_list != null and moved_variable_index >= 0 \
			and moved_variable_list.is_selected(moved_variable_index),
		"Schema 3 Inspector Move Redo preserves semantic stable-ID selection."
	)
	var delete_button: Button = _find_button(inspector_property, "Delete")
	_expect(delete_button != null, "Schema 3 Inspector selected variable exposes Delete.")
	if delete_button != null:
		delete_button.emit_signal(&"pressed")
		await process_frame
		var confirmation: ConfirmationDialog = _find_delete_confirmation(inspector_property)
		_expect(confirmation != null, "Schema 3 Inspector variable Delete waits for explicit confirmation.")
		if confirmation != null:
			_expect(not confirmation.title.contains(selected_id) and not confirmation.dialog_text.contains(selected_id), "Schema 3 dock variable Delete confirmation does not expose an internal ID.")
			confirmation.emit_signal(&"canceled")
			await process_frame
			_expect(_item_index_for_internal_id(_section_list(inspector_property, "Variables"), selected_id) >= 0, "Schema 3 Inspector Delete cancel preserves the selected variable.")
			delete_button = _find_button(inspector_property, "Delete")
			if delete_button == null:
				return
			delete_button.emit_signal(&"pressed")
			await process_frame
			confirmation = _find_delete_confirmation(inspector_property)
			if confirmation == null:
				return
			confirmation.emit_signal(&"confirmed")
	await process_frame
	await process_frame
	_expect(_item_index_for_internal_id(_section_list(inspector_property, "Variables"), selected_id) == -1, "Schema 3 Inspector Delete removes the selected variable without stale controls.")
	_expect(_find_node_by_name(dock_property, &"Schema3VariableEditor") == null, "Schema 3 dock Delete removes obsolete variable controls.")
	history.undo()
	await process_frame
	await process_frame
	_expect(_item_index_for_internal_id(_section_list(inspector_property, "Variables"), selected_id) >= 0, "Schema 3 Inspector Delete undo restores the stable-ID row.")
	inspector_property.call(&"_rebuild_interface")
	inspector_property.call(&"_rebuild_interface")
	await process_frame
	await process_frame
	_expect(_section_list_count(inspector_property, "Variables") == 1, "Schema 3 Inspector repeated rebuilds do not duplicate variable lists.")


## Exercises native keyboard delivery instead of directly selecting an ItemList row.
func _test_schema_3_keyboard_accessibility(
		inspector_property: FlowGraphInspectorProperty,
		dock_property: FlowGraphInspectorProperty,
		graph: FlowGraph
) -> void:
	var variable_list: ItemList = _section_list(inspector_property, "Variables")
	_expect(
		variable_list != null and variable_list.is_inside_tree() \
			and variable_list.focus_mode != Control.FOCUS_NONE,
		"Schema 3 Variables list is reachable by native keyboard focus before a row is selected."
	)
	if variable_list == null:
		return
	_expect(
		inspector_property.auto_translate_mode == Node.AUTO_TRANSLATE_MODE_DISABLED \
			and dock_property.auto_translate_mode == Node.AUTO_TRANSLATE_MODE_DISABLED,
		"Flujo Inspector and dock surfaces retain their English source text without Godot auto-translation."
	)
	variable_list.deselect_all()
	variable_list.grab_focus()
	_expect(variable_list.has_focus(), "Schema 3 Variables list accepts keyboard focus without a prior selection.")
	var list_instance_id: int = variable_list.get_instance_id()
	var inspector_scroll: ScrollContainer = _inspector_scroll_for(inspector_property)
	var scroll_before: int = inspector_scroll.scroll_vertical if inspector_scroll != null else 0
	var down_event: InputEventKey = InputEventKey.new()
	down_event.pressed = true
	down_event.keycode = KEY_DOWN
	Input.parse_input_event(down_event)
	await process_frame
	await process_frame
	variable_list = _section_list(inspector_property, "Variables")
	_expect(
		variable_list != null and variable_list.get_instance_id() == list_instance_id \
			and variable_list.is_selected(0) and variable_list.has_focus() \
			and (inspector_scroll == null or inspector_scroll.scroll_vertical == scroll_before),
		"Schema 3 Variables keyboard selection preserves its ItemList instance, focus, scroll, and selected row."
	)
	if variable_list == null:
		return
	var first_entry: Dictionary = variable_list.get_item_metadata(0) as Dictionary
	var first_id: String = first_entry.get("internal_id", "") as String
	_expect(
		not first_id.is_empty() and _find_node_by_name(dock_property, &"Schema3VariableEditor") != null,
		"Keyboard row selection publishes the stable ID to the Flujo panel."
	)
	variable_list.emit_signal(&"item_activated", 0)
	await process_frame
	await process_frame
	var entered_name_input: LineEdit = _find_node_by_name(dock_property, &"VariableNameInput") as LineEdit
	_expect(
		entered_name_input != null and entered_name_input.has_focus(),
		"Enter transfers focus from the selected schema 3 Variable row to its Name editor."
	)
	if entered_name_input != null:
		var escape_event: InputEventKey = InputEventKey.new()
		escape_event.pressed = true
		escape_event.keycode = KEY_ESCAPE
		entered_name_input.emit_signal(&"gui_input", escape_event)
		await process_frame
		await process_frame
		variable_list = _section_list(inspector_property, "Variables")
		var returned_index: int = _item_index_for_internal_id(variable_list, first_id)
		_expect(
			variable_list != null and returned_index >= 0 and variable_list.is_selected(returned_index) \
				and variable_list.has_focus(),
			"Escape after cancelling Name returns focus to the same stable-ID-selected Inspector row."
		)
	var first_variable: FlowVariableDefinition = graph.variables[0] as FlowVariableDefinition
	_expect(first_variable != null, "Schema 3 keyboard fixture retains its first typed Variable resource.")
	if first_variable == null:
		return
	var name_input: LineEdit = _find_node_by_name(dock_property, &"VariableNameInput") as LineEdit
	var type_option: OptionButton = _find_node_by_name(dock_property, &"VariableTypeOption") as OptionButton
	var value_control: Control = _find_node_by_name(
		dock_property,
		_value_control_name(first_variable.value_type)
	) as Control
	_expect(
		name_input != null and type_option != null and value_control != null \
			and name_input.focus_mode != Control.FOCUS_NONE \
			and type_option.focus_mode != Control.FOCUS_NONE \
			and value_control.focus_mode != Control.FOCUS_NONE,
		"Schema 3 Name, Type, and Value controls remain in native Tab/Shift+Tab navigation."
	)
	if name_input != null:
		name_input.grab_focus()
		var tab_event: InputEventKey = InputEventKey.new()
		tab_event.pressed = true
		tab_event.keycode = KEY_TAB
		Input.parse_input_event(tab_event)
		await process_frame
		var focus_owner: Control = get_root().gui_get_focus_owner() as Control
		_expect(
			focus_owner != null and focus_owner != name_input and focus_owner.is_inside_tree(),
			"Tab moves focus from Name through the current schema 3 editor without rebuilding it."
		)
		var reverse_tab_event: InputEventKey = InputEventKey.new()
		reverse_tab_event.pressed = true
		reverse_tab_event.keycode = KEY_TAB
		reverse_tab_event.shift_pressed = true
		Input.parse_input_event(reverse_tab_event)
		await process_frame
		focus_owner = get_root().gui_get_focus_owner() as Control
		_expect(
			focus_owner != null and focus_owner.is_inside_tree(),
			"Shift+Tab retains a valid focus owner in the current schema 3 editor."
		)


## Covers one-press Escape from each schema 3 Variable editor control family.
func _test_schema_3_variable_escape_navigation(
		inspector_property: FlowGraphInspectorProperty,
		dock_property: FlowGraphInspectorProperty,
		graph: FlowGraph
) -> void:
	var name_variable: FlowVariableDefinition = graph.variables[FlowVariableDefinition.ValueType.BOOL] as FlowVariableDefinition
	_expect(name_variable != null, "Schema 3 Escape fixture retains the Name Variable resource.")
	if name_variable == null:
		return
	await _select_variable_row(inspector_property, FlowVariableDefinition.ValueType.BOOL)
	var name_input: LineEdit = _find_node_by_name(dock_property, &"VariableNameInput") as LineEdit
	_expect(name_input != null, "Schema 3 Escape exposes Name for the selected stable-ID Variable.")
	if name_input == null:
		return
	var original_name: String = name_variable.display_name
	name_input.text = "Pending Escape Name"
	await _escape_to_selected_variable_list(inspector_property, name_input, name_variable.get_internal_id(), "Name")
	_expect(name_variable.display_name == original_name, "Schema 3 Name Escape discards its pending buffer without mutation.")

	await _select_variable_row(inspector_property, FlowVariableDefinition.ValueType.BOOL)
	var type_option: OptionButton = _find_node_by_name(dock_property, &"VariableTypeOption") as OptionButton
	_expect(type_option != null, "Schema 3 Escape exposes Type for the selected stable-ID Variable.")
	if type_option != null:
		await _escape_to_selected_variable_list(inspector_property, type_option, name_variable.get_internal_id(), "Type")
	_expect(name_variable.value_type == FlowVariableDefinition.ValueType.BOOL, "Schema 3 Type Escape does not create a replacement type action.")

	for value_type: int in range(FlowVariableDefinition.ValueType.BOOL, FlowVariableDefinition.ValueType.COLOR + 1):
		await _select_variable_row(inspector_property, value_type)
		var variable: FlowVariableDefinition = graph.variables[value_type] as FlowVariableDefinition
		_expect(variable != null, "Schema 3 Escape fixture retains the Value resource for type %d." % value_type)
		if variable == null:
			continue
		var value_control: Control = _find_node_by_name(dock_property, _value_control_name(value_type)) as Control
		_expect(value_control != null, "Schema 3 Escape exposes the Value control for type %d." % value_type)
		if value_control == null:
			continue
		if value_control is SpinBox:
			var spin_box: SpinBox = value_control as SpinBox
			var spin_line_edit: LineEdit = spin_box.get_line_edit()
			spin_line_edit.text = "999"
			await _escape_to_selected_variable_list(inspector_property, spin_line_edit, variable.get_internal_id(), "Value type %d" % value_type)
		elif value_control is TextEdit:
			var text_edit: TextEdit = value_control as TextEdit
			text_edit.text = "pending Escape value"
			await _escape_to_selected_variable_list(inspector_property, text_edit, variable.get_internal_id(), "Value type %d" % value_type)
		elif value_control is ColorPickerButton:
			var color_button: ColorPickerButton = value_control as ColorPickerButton
			color_button.emit_signal(&"pressed")
			color_button.emit_signal(&"popup_closed")
			await process_frame
			var color_list: ItemList = _section_list(inspector_property, "Variables")
			var color_index: int = _item_index_for_internal_id(color_list, variable.get_internal_id())
			_expect(
				color_list != null and color_index >= 0 and color_list.is_selected(color_index),
				"COLOR popup Escape-close context preserves its stable-ID row for the next Escape."
			)
			await _escape_to_selected_variable_list(inspector_property, color_button, variable.get_internal_id(), "COLOR Value")
		else:
			await _escape_to_selected_variable_list(inspector_property, value_control, variable.get_internal_id(), "Value type %d" % value_type)

	await _select_variable_row(inspector_property, FlowVariableDefinition.ValueType.BOOL)
	var advanced_toggle: Button = _find_node_by_name(dock_property, &"VariableAdvancedToggle") as Button
	_expect(advanced_toggle != null, "Schema 3 Escape exposes Advanced for the selected stable-ID Variable.")
	if advanced_toggle == null:
		return
	await _escape_to_selected_variable_list(inspector_property, advanced_toggle, name_variable.get_internal_id(), "Advanced")
	await _select_variable_row(inspector_property, FlowVariableDefinition.ValueType.BOOL)
	advanced_toggle = _find_node_by_name(dock_property, &"VariableAdvancedToggle") as Button
	if advanced_toggle == null:
		return
	advanced_toggle.emit_signal(&"toggled", true)
	await process_frame
	await process_frame
	var scope_option: OptionButton = _find_node_by_name(dock_property, &"VariableScopeOption") as OptionButton
	var binding_option: OptionButton = _find_node_by_name(dock_property, &"VariableBindingOption") as OptionButton
	var persistent_input: CheckBox = _find_node_by_name(dock_property, &"VariablePersistentCheckBox") as CheckBox
	var note_input: TextEdit = _find_node_by_name(dock_property, &"VariableNoteInput") as TextEdit
	_expect(
		scope_option != null and binding_option != null and persistent_input != null and note_input != null,
		"Schema 3 Escape exposes every focusable Advanced configuration control."
	)
	if scope_option == null or binding_option == null or persistent_input == null or note_input == null:
		return
	var original_scope: int = name_variable.scope
	var original_binding: int = name_variable.binding
	var original_persistent: bool = name_variable.persistent
	await _escape_to_selected_variable_list(inspector_property, scope_option, name_variable.get_internal_id(), "Scope")
	await _escape_to_selected_variable_list(inspector_property, binding_option, name_variable.get_internal_id(), "Binding")
	await _escape_to_selected_variable_list(inspector_property, persistent_input, name_variable.get_internal_id(), "Persistent")
	_expect(
		name_variable.scope == original_scope and name_variable.binding == original_binding \
			and name_variable.persistent == original_persistent,
		"Schema 3 Advanced Escape creates no configuration Undo/Redo action."
	)
	var original_note: String = name_variable.user_note
	note_input.text = "Pending Escape note"
	await _escape_to_selected_variable_list(inspector_property, note_input, name_variable.get_internal_id(), "Note")
	_expect(name_variable.user_note == original_note, "Schema 3 Note Escape discards its pending multiline buffer without mutation.")


## Delivers Escape through the public Control signal and verifies stable-ID list restoration.
func _escape_to_selected_variable_list(
		inspector_property: FlowGraphInspectorProperty,
		control: Control,
		variable_id: String,
		control_label: String
) -> void:
	control.grab_focus()
	_expect(control.has_focus(), "Schema 3 %s accepts focus before Escape." % control_label)
	var escape_event: InputEventKey = InputEventKey.new()
	escape_event.pressed = true
	escape_event.keycode = KEY_ESCAPE
	control.emit_signal(&"gui_input", escape_event)
	await process_frame
	await process_frame
	var variable_list: ItemList = _section_list(inspector_property, "Variables")
	var item_index: int = _item_index_for_internal_id(variable_list, variable_id)
	_expect(
		variable_list != null and item_index >= 0 and variable_list.is_selected(item_index) \
			and variable_list.has_focus(),
		"Schema 3 %s Escape returns focus to the same stable-ID-selected Variables row." % control_label
	)


## Covers the mouse selection signal without replacing the mounted schema 3 ItemList.
func _test_schema_3_selection_without_list_rebuild(
		inspector_property: FlowGraphInspectorProperty,
		dock_property: FlowGraphInspectorProperty,
		graph: FlowGraph,
		history: UndoRedo
) -> void:
	var variable_list: ItemList = _section_list(inspector_property, "Variables")
	_expect(variable_list != null and variable_list.item_count >= 2, "Schema 3 selection fixture has two Variable rows.")
	if variable_list == null:
		return
	var selected_variable: FlowVariableDefinition = graph.variables[0] as FlowVariableDefinition
	_expect(selected_variable != null, "Schema 3 selection fixture retains its first Variable resource.")
	if selected_variable == null:
		return
	var inspector_scroll: ScrollContainer = _inspector_scroll_for(inspector_property)
	variable_list.grab_focus()
	await process_frame
	if inspector_scroll != null:
		var maximum_scroll: float = inspector_scroll.get_v_scroll_bar().max_value
		inspector_scroll.scroll_vertical = int(minf(24.0, maximum_scroll))
		await process_frame
	var list_instance_id: int = variable_list.get_instance_id()
	var scroll_before: int = inspector_scroll.scroll_vertical if inspector_scroll != null else 0
	variable_list.select(0)
	variable_list.emit_signal(&"item_selected", 0)
	await process_frame
	await process_frame
	var selected_list: ItemList = _section_list(inspector_property, "Variables")
	var selected_index: int = _item_index_for_internal_id(selected_list, selected_variable.get_internal_id())
	_expect(
		selected_list != null and selected_list.get_instance_id() == list_instance_id \
			and selected_list.has_focus() and selected_index >= 0 and selected_list.is_selected(selected_index) \
			and (inspector_scroll == null or inspector_scroll.scroll_vertical == scroll_before),
		"Schema 3 mouse selection preserves the mounted ItemList, its focus, scroll, and stable-ID row."
	)
	_expect(
		_find_node_by_name(dock_property, &"VariableNameInput") != null,
		"Schema 3 mouse selection publishes the stable ID to the Flujo panel without rebuilding the Inspector list."
	)
	var move_down: Button = _find_button(inspector_property, "Move Down")
	_expect(move_down != null, "Schema 3 selection updates only the selected row structural actions.")
	if move_down == null:
		return
	move_down.emit_signal(&"pressed")
	await process_frame
	await process_frame
	_expect(
		graph.variables[1] == selected_variable,
		"Schema 3 Move acts on the stable ID selected by the preserved ItemList."
	)
	history.undo()
	await process_frame
	await process_frame
	_expect(
		graph.variables[0] == selected_variable,
		"Schema 3 Move Undo restores the resource selected by stable ID."
	)


func _inspector_scroll_for(property: FlowGraphInspectorProperty) -> ScrollContainer:
	var column: Node = property.get_parent()
	return column.get_parent() as ScrollContainer if column != null else null


## Exercises the production Inspector-plugin-main-plugin-dock selection relay.
func _test_plugin_variable_selection_relay(undo_redo: EditorUndoRedoManager) -> void:
	var controller: PVController = PVController.new()
	controller.flow_graph = _schema_3_variable_fixture()
	get_root().add_child(controller)
	var relay_inspector: PVControllerInspectorPlugin = PVControllerInspectorPlugin.new()
	relay_inspector.set_undo_redo(undo_redo)
	var flow_graph_property: Dictionary = _find_property(controller.get_property_list(), &"flow_graph")
	_expect(
		relay_inspector._parse_property(
			controller,
			flow_graph_property["type"],
			"flow_graph",
			flow_graph_property["hint"],
			flow_graph_property["hint_string"],
			flow_graph_property["usage"],
			false
		),
		"The production Inspector plugin creates the FlowGraph relay property."
	)
	var inspector_property: FlowGraphInspectorProperty = relay_inspector.get("_active_flow_graph_property") as FlowGraphInspectorProperty
	_expect(inspector_property != null, "The production Inspector relay exposes its current FlowGraph property.")
	if inspector_property == null:
		controller.queue_free()
		return
	get_root().add_child(inspector_property)
	inspector_property.set_object_and_property(controller, &"flow_graph")
	var dock: Node = VP_FLUJO_DOCK_SCRIPT.new()
	dock.call(&"configure", undo_redo)
	get_root().add_child(dock)
	dock.set("_controller_presence_initialized", true)
	dock.set("_controller_present", true)
	var dock_control: Control = dock as Control
	_expect(dock_control != null and is_zero_approx(dock_control.custom_minimum_size.x), "The production relay dock retains native resize freedom.")
	if dock_control != null:
		dock_control.size.x = 160.0
	var main_plugin: EditorPlugin = VP_FLUJO_PLUGIN_SCRIPT.new()
	main_plugin.set(&"_dock", dock)
	main_plugin.set(&"_dock_controller", null)
	main_plugin.set(&"_controller_inspector_plugin", relay_inspector)
	relay_inspector.schema_3_variable_selection_changed.connect(
		Callable(main_plugin, &"_on_schema_3_variable_selection_changed")
	)
	relay_inspector.schema_3_variable_editor_focus_requested.connect(
		Callable(main_plugin, &"_on_schema_3_variable_editor_focus_requested")
	)
	inspector_property.call(&"_rebuild_interface")
	await process_frame
	await process_frame
	var variable_list: ItemList = _section_list(inspector_property, "Variables")
	_expect(variable_list != null and variable_list.item_count > 0, "The production relay property exposes a schema 3 Variables row.")
	if variable_list != null:
		variable_list.select(0)
		variable_list.emit_signal(&"item_selected", 0)
		await process_frame
		await process_frame
	var dock_property: FlowGraphInspectorProperty = dock.call(&"get_variable_editor") as FlowGraphInspectorProperty
	_expect(
		dock_property != null \
			and _find_node_by_name(dock_property, &"VariableNameInput") != null \
			and _find_node_by_name(dock_property, &"VariableTypeOption") != null \
			and _find_node_by_name(dock_property, &"VariableBoolValue") != null,
		"A public schema 3 selection crosses Inspector, plugin, and dock to render Name, Type, and Value."
	)
	if variable_list != null:
		variable_list.emit_signal(&"item_activated", 0)
		await process_frame
		await process_frame
	var name_input: LineEdit = _find_node_by_name(dock_property, &"VariableNameInput") as LineEdit
	_expect(name_input != null and name_input.has_focus(), "A public schema 3 activation crosses the production relay to focus Name.")
	_expect(dock_control != null and dock_control.size.x < 320.0, "The production dock can reduce below the retired 320-pixel initial width.")
	inspector_property.queue_free()
	dock.queue_free()
	controller.queue_free()
	main_plugin.free()
	await process_frame
	await process_frame


## Exercises the editor-only coordinator through its public shortcut and dock-button paths.
func _test_flow_interaction_coordinator(undo_redo: EditorUndoRedoManager) -> void:
	var host: Control = Control.new()
	host.name = &"FlowInteractionCoordinatorHost"
	host.size = Vector2(800.0, 600.0)
	get_root().add_child(host)
	var focus_before_flow: LineEdit = LineEdit.new()
	focus_before_flow.name = &"FocusBeforeFlow"
	focus_before_flow.focus_mode = Control.FOCUS_ALL
	host.add_child(focus_before_flow)
	var temporary_editor_focus: Button = Button.new()
	temporary_editor_focus.name = &"TemporaryGodotEditorFocus"
	temporary_editor_focus.focus_mode = Control.FOCUS_ALL
	temporary_editor_focus.text = "Temporary editor focus"
	host.add_child(temporary_editor_focus)
	var controller_a: PVController = _new_interaction_controller("Coordinator A")
	var controller_b: PVController = _new_interaction_controller("Coordinator B")
	host.add_child(controller_a)
	host.add_child(controller_b)
	var dock: VPFlujoDock = CoordinatorTestDock.new()
	dock.configure(undo_redo)
	get_root().add_child(dock)
	dock.show()
	dock.set_controller(controller_a)
	var variable_a: FlowVariableDefinition = controller_a.flow_graph.variables[0] as FlowVariableDefinition
	var variable_b: FlowVariableDefinition = controller_b.flow_graph.variables[0] as FlowVariableDefinition
	_expect(variable_a != null and variable_b != null, "Interaction coordinator fixtures expose valid schema 3 Variables.")
	if variable_a == null or variable_b == null:
		dock.queue_free()
		host.queue_free()
		await process_frame
		return
	dock.set_variable_selection(
		controller_a,
		FlowGraphEditorCommands.Collection.VARIABLES,
		variable_a.get_internal_id()
	)
	await process_frame
	await process_frame
	var coordinator: FlowInteractionCoordinator = FLOW_INTERACTION_COORDINATOR_SCRIPT.new(dock)
	var shortcut: Shortcut = FlowInteractionCoordinator.create_default_shortcut()
	var f4_pressed: InputEventKey = InputEventKey.new()
	f4_pressed.pressed = true
	f4_pressed.keycode = KEY_F4
	var f4_released: InputEventKey = InputEventKey.new()
	f4_released.pressed = false
	f4_released.keycode = KEY_F4
	var f4_echo: InputEventKey = InputEventKey.new()
	f4_echo.pressed = true
	f4_echo.echo = true
	f4_echo.keycode = KEY_F4

	_expect(
		not coordinator.handle_shortcut(f4_pressed, shortcut, get_root()),
		"F4 remains unconsumed when no exact PVController is selected."
	)
	_expect(
		not coordinator.handle_shortcut(f4_released, shortcut, get_root())
			and not coordinator.handle_shortcut(f4_echo, shortcut, get_root()),
		"Only a deliberate non-repeated F4 key press changes Flujo interaction."
	)
	coordinator.set_selected_controller(controller_a)
	focus_before_flow.grab_focus()
	_expect(focus_before_flow.has_focus(), "Flow records a focusable Godot control before F4 enters interaction.")
	_expect(
		coordinator.handle_shortcut(f4_pressed, shortcut, get_root()),
		"F4 enters FLOW for the exactly selected PVController."
	)
	await process_frame
	await process_frame
	var dock_editor: FlowGraphInspectorProperty = dock.get_variable_editor()
	var interaction_label: Label = _find_node_by_name(dock, &"FlowInteractionState") as Label
	var interaction_button: Button = _find_node_by_name(dock, &"FlowInteractionToggle") as Button
	_expect(
		coordinator.get_state() == FlowInteractionCoordinator.State.FLOW \
			and dock_editor != null and dock_editor.visible \
			and interaction_label != null and interaction_label.text == "Interaction: Flow" \
			and interaction_button != null and interaction_button.text == "Leave Flow (F4)",
		"FLOW exposes the dock editing surface and its accessible state indicator."
	)
	_expect(
		coordinator.handle_shortcut(f4_pressed, shortcut, get_root()),
		"The same F4 transition leaves FLOW."
	)
	await process_frame
	await process_frame
	_expect(
		coordinator.get_state() == FlowInteractionCoordinator.State.GODOT and focus_before_flow.has_focus(),
		"Leaving FLOW safely restores the prior valid Godot focus target."
	)

	var invalid_focus_target: LineEdit = LineEdit.new()
	invalid_focus_target.name = &"InvalidWeakFocusTarget"
	invalid_focus_target.focus_mode = Control.FOCUS_ALL
	host.add_child(invalid_focus_target)
	invalid_focus_target.grab_focus()
	_expect(coordinator.handle_shortcut(f4_pressed, shortcut, get_root()), "FLOW can begin before a prior focus target is released.")
	await process_frame
	invalid_focus_target.queue_free()
	await process_frame
	_expect(coordinator.handle_shortcut(f4_pressed, shortcut, get_root()), "FLOW can end after its weak focus target becomes invalid.")
	await process_frame
	_expect(
		coordinator.get_state() == FlowInteractionCoordinator.State.GODOT,
		"An invalid WeakRef skips restoration without retaining Flow interaction."
	)

	_expect(coordinator.handle_shortcut(f4_pressed, shortcut, get_root()), "FLOW re-enters for a selected controller.")
	await process_frame
	temporary_editor_focus.grab_focus()
	await process_frame
	_expect(
		coordinator.is_flow_active(),
		"Temporary focus outside Flujo does not end FLOW while hierarchy selection is unchanged."
	)
	coordinator.set_selected_controller(controller_b)
	await process_frame
	_expect(
		coordinator.get_state() == FlowInteractionCoordinator.State.GODOT,
		"Selecting another PVController ends FLOW without applying a focus-restoration transition."
	)
	dock.set_controller(controller_b)
	dock.set_variable_selection(
		controller_b,
		FlowGraphEditorCommands.Collection.VARIABLES,
		variable_b.get_internal_id()
	)
	coordinator.set_selected_controller(controller_b)
	await process_frame
	await process_frame
	_expect(coordinator.handle_shortcut(f4_pressed, shortcut, get_root()), "A second selected PVController enters its own FLOW context.")
	await process_frame
	coordinator.update_playing_scene(true, get_root())
	_expect(
		coordinator.get_state() == FlowInteractionCoordinator.State.GAME \
			and dock_editor != null and not dock_editor.visible \
			and interaction_label != null and interaction_label.text == "Interaction: Game" \
			and interaction_button != null and interaction_button.disabled,
		"Actual editor play state suspends only Flujo editing and announces GAME."
	)
	_expect(
		not coordinator.handle_shortcut(f4_pressed, shortcut, get_root()),
		"F4 is never consumed by Flujo while GAME is active."
	)
	temporary_editor_focus.grab_focus()
	coordinator.update_playing_scene(false, get_root())
	await process_frame
	_expect(
		coordinator.get_state() == FlowInteractionCoordinator.State.FLOW \
			and dock_editor != null and dock_editor.visible \
			and temporary_editor_focus.has_focus(),
		"Leaving GAME restores valid FLOW visibility without stealing current Godot focus."
	)
	coordinator.update_playing_scene(true, get_root())
	coordinator.set_selected_controller(null)
	coordinator.update_playing_scene(false, get_root())
	await process_frame
	_expect(
		coordinator.get_state() == FlowInteractionCoordinator.State.GODOT and dock_editor != null and not dock_editor.visible,
		"A lost hierarchy selection prevents stale FLOW restoration after GAME."
	)

	var dock_button_handler: Callable = Callable(coordinator, &"toggle_flow_interaction").bind(get_root())
	dock.interaction_toggle_requested.connect(dock_button_handler)
	dock.set_controller(controller_a)
	dock.set_variable_selection(
		controller_a,
		FlowGraphEditorCommands.Collection.VARIABLES,
		variable_a.get_internal_id()
	)
	coordinator.set_selected_controller(controller_a)
	await process_frame
	await process_frame
	if interaction_button != null:
		interaction_button.emit_signal(&"pressed")
		await process_frame
		_expect(
			coordinator.get_state() == FlowInteractionCoordinator.State.FLOW,
			"The public dock button follows the same GODOT-to-FLOW transition as F4."
		)
		interaction_button.emit_signal(&"pressed")
		await process_frame
		_expect(
			coordinator.get_state() == FlowInteractionCoordinator.State.GODOT,
			"The public dock button follows the same FLOW-to-GODOT transition as F4."
		)
	else:
		_expect(false, "The Flow interaction button is available for the equivalent public transition.")
	if dock.interaction_toggle_requested.is_connected(dock_button_handler):
		dock.interaction_toggle_requested.disconnect(dock_button_handler)
	coordinator.set_selected_controller(controller_a)
	_expect(coordinator.handle_shortcut(f4_pressed, shortcut, get_root()), "FLOW starts before coordinator shutdown cleanup.")
	coordinator.shutdown()
	await process_frame
	_expect(
		coordinator.get_state() == FlowInteractionCoordinator.State.GODOT and dock_editor != null and not dock_editor.visible,
		"Coordinator shutdown clears editor interaction without retaining a dock shortcut path."
	)
	dock.queue_free()
	host.queue_free()
	await process_frame
	await process_frame
	_expect(not is_instance_valid(dock) and not is_instance_valid(host), "Coordinator fixtures release dock and controller controls cleanly.")


func _new_interaction_controller(variable_name: String) -> PVController:
	var graph: FlowGraph = FlowGraph.new()
	graph.schema_version = FlowGraph.SCHEMA_VERSION_3
	graph.constructor = FlowConstructorDefinition.new()
	var variable: FlowVariableDefinition = FlowVariableDefinition.new()
	variable.display_name = variable_name
	variable.scope = FlowVariableDefinition.Scope.GLOBAL
	graph.variables = [variable]
	var controller: PVController = PVController.new()
	controller.flow_graph = graph
	return controller


func _test_public_plugin_language() -> void:
	var plugin_configuration: String = FileAccess.get_file_as_string("res://addons/vp_flujo/plugin.cfg")
	_expect(
		plugin_configuration.contains('description="Pre-alpha visual programming foundation for Godot."'),
		"Plugin metadata presents an English pre-alpha description."
	)
	_expect(plugin_configuration.contains('author="Flujo Project"'), "Plugin metadata presents its author in English.")
	var sources: Array[String] = [
		FileAccess.get_file_as_string("res://addons/vp_flujo/plugin.gd"),
		FileAccess.get_file_as_string("res://addons/vp_flujo/editor/pv_scene_inspector.gd"),
		FileAccess.get_file_as_string("res://addons/vp_flujo/runtime/pv_controller.gd"),
	]
	for source: String in sources:
		_expect(
			not source.contains("Punto de") and not source.contains("Actuará") \
				and not source.contains("Servicio que conoce"),
			"Mechanically translatable plugin comments remain in English."
		)


func _test_schema_3_dock_controller_switch(
		dock: Node,
		dock_property: FlowGraphInspectorProperty,
		previous_controller: PVController
) -> void:
	var stable_content: Node = dock_property.get_child(0)
	var stable_control_count: int = stable_content.get_child_count()
	for ignored: int in 100:
		dock.call(&"set_controller", previous_controller)
	await process_frame
	await process_frame
	_expect(stable_content.get_child_count() == stable_control_count, "One hundred identical controller assignments keep one effective dock binding and rebuild.")
	var common_control: Control = Control.new()
	get_root().add_child(common_control)
	common_control.queue_free()
	await process_frame
	await process_frame
	_expect(stable_content.get_child_count() == stable_control_count, "Adding and removing ordinary controls does not rebuild the dock options surface.")
	var scene_inspector = preload("res://addons/vp_flujo/editor/pv_scene_inspector.gd").new(
		preload("res://addons/vp_flujo/runtime/pv_controller.gd")
	)
	var plugin_script: Script = preload("res://addons/vp_flujo/plugin.gd")
	_expect(not plugin_script._is_relevant_scene_tree_change(Control.new(), scene_inspector), "Plugin ignores ordinary control tree changes.")
	_expect(plugin_script._is_relevant_scene_tree_change(PVController.new(), scene_inspector), "Plugin observes tree changes that add or remove a PVController.")
	var connection: Callable = Callable(dock, &"_on_controller_property_list_changed")
	_expect(previous_controller.property_list_changed.is_connected(connection), "Dock links the active controller exactly once.")
	var second_controller: PVController = PVController.new()
	var second_graph: FlowGraph = FlowGraph.new()
	second_graph.schema_version = FlowGraph.SCHEMA_VERSION_3
	second_graph.constructor = FlowConstructorDefinition.new()
	var second_variable: FlowVariableDefinition = FlowVariableDefinition.new()
	second_variable.display_name = "Second Controller Variable"
	second_graph.variables = [second_variable]
	second_controller.flow_graph = second_graph
	dock.call(&"set_controller", second_controller)
	await process_frame
	await process_frame
	_expect(_section_list(dock_property, "Variables") == null and _find_node_by_name(dock_property, &"Schema3VariableEditor") == null, "Changing the active PVController clears stale dock variable controls.")
	_expect(_count_named_nodes(dock, &"Schema3VariablesDockEditor") == 1, "Dock keeps exactly one mutable schema 3 Variables editor across controller changes.")
	_expect(not previous_controller.property_list_changed.is_connected(connection) and second_controller.property_list_changed.is_connected(connection), "Changing controller disconnects the previous signal and keeps one connection to the new controller.")
	dock.call(&"set_controller", null)
	await process_frame
	await process_frame
	_expect(_section_list(dock_property, "Variables") == null and _has_label_containing(dock_property, "Select a Schema 3 Variable"), "Losing the active controller clears the dock options.")
	_expect(not second_controller.property_list_changed.is_connected(connection), "Clearing the dock disconnects the previous controller exactly once.")
	dock.call(&"set_controller", previous_controller)
	await process_frame
	await process_frame
	_expect(_section_list(dock_property, "Variables") == null and _has_label_containing(dock_property, "Select a Schema 3 Variable"), "Restoring the active controller keeps the dock empty until a current Inspector selection arrives.")
	var controller_a: PVController = PVController.new()
	controller_a.flow_graph = _schema_3_variable_fixture()
	get_root().add_child(controller_a)
	dock.call(&"set_controller", controller_a)
	controller_a.queue_free()
	await process_frame
	await process_frame
	_expect(_section_list(dock_property, "Variables") == null and _has_label_containing(dock_property, "Select a Schema 3 Variable"), "A controller released before its deferred rebuild leaves the dock empty without stale access.")
	var controller_b: PVController = PVController.new()
	controller_b.flow_graph = _schema_3_variable_fixture()
	get_root().add_child(controller_b)
	var pending_controller_a: PVController = PVController.new()
	pending_controller_a.flow_graph = _schema_3_variable_fixture()
	get_root().add_child(pending_controller_a)
	dock.call(&"set_controller", pending_controller_a)
	dock.call(&"set_controller", controller_b)
	await process_frame
	await process_frame
	_expect(_section_list(dock_property, "Variables") == null and _has_label_containing(dock_property, "Select a Schema 3 Variable"), "A pending controller A rebuild cannot replace the current controller B dock options.")
	dock.call(&"set_controller", null)
	await process_frame
	await process_frame
	_expect(_section_list(dock_property, "Variables") == null, "A pending rebuild followed by null leaves no stale Variables controls.")
	controller_b.queue_free()
	pending_controller_a.queue_free()


func _test_schema_2_to_3_migration_action(
		inspector_property: FlowGraphInspectorProperty,
		dock_property: FlowGraphInspectorProperty,
		controller: PVController,
		history: UndoRedo,
		undo_redo: EditorUndoRedoManager
) -> void:
	var source: FlowGraph = FlowGraph.new()
	source.schema_version = FlowGraph.SCHEMA_VERSION_2
	var source_variable: FlowVariableDefinition = FlowVariableDefinition.new()
	source_variable.display_name = "Migrated Variable"
	source_variable.scope = FlowVariableDefinition.Scope.GLOBAL
	source_variable.value_type = FlowVariableDefinition.ValueType.STRING
	source_variable.string_value = "schema 2 value"
	source.variables = [source_variable, null]
	controller.flow_graph = source
	inspector_property.call(&"_rebuild_interface")
	dock_property.refresh_dock_controller()
	await process_frame
	await process_frame
	var migrate_button: Button = _find_button(inspector_property, "Migrate FlowGraph to Schema 3")
	_expect(migrate_button != null and migrate_button.visible, "Schema 2 exposes a visible English action to migrate to Schema 3.")
	if migrate_button == null:
		return
	var history_version: int = history.get_version()
	migrate_button.emit_signal(&"pressed")
	await process_frame
	await process_frame
	var migrated: FlowGraph = controller.flow_graph
	_expect(migrated != source and migrated != null and migrated.schema_version == FlowGraph.SCHEMA_VERSION_3, "Confirming the migration action replaces schema 2 only with a schema 3 candidate.")
	_expect(source.schema_version == FlowGraph.SCHEMA_VERSION_2 and source.variables[0] == source_variable and source_variable.string_value == "schema 2 value", "Schema 2 migration leaves its source graph and variable literal data intact.")
	_expect(history.get_version() == history_version + 1, "Schema 2 to 3 migration creates exactly one undoable scene-history action.")
	if migrated == null:
		return
	_expect(migrated.variables.size() == 2 and migrated.variables[1] == null, "Schema 2 to 3 migration preserves variable order and deliberate null positions.")
	var migrated_variable: FlowVariableDefinition = migrated.variables[0] as FlowVariableDefinition
	_expect(migrated_variable != null and migrated_variable != source_variable and migrated_variable.get_internal_id() == source_variable.get_internal_id() and migrated_variable.string_value == "schema 2 value", "Schema 2 to 3 migration deep-copies preserved typed variable data and IDs.")
	inspector_property.call(&"_rebuild_interface")
	await process_frame
	_expect(_find_node_by_name(inspector_property, &"Schema3VariableEditor") == null and _find_button(inspector_property, "Add Variable") != null, "Schema 3 Inspector rebuilds its structural Variables surface without option controls.")
	var variable_list: ItemList = _section_list(inspector_property, "Variables")
	_expect(variable_list != null and variable_list.item_count == 2, "Migrated schema 3 graph rebuilds its Inspector Variables list.")
	if variable_list == null:
		return
	variable_list.emit_signal(&"item_selected", 0)
	await process_frame
	await process_frame
	_expect(_find_node_by_name(dock_property, &"VariableNameInput") != null, "Migrated schema 3 variable exposes Name editing in the Flujo dock.")
	_expect(_find_node_by_name(dock_property, &"VariableTypeOption") != null, "Migrated schema 3 variable exposes Type editing in the Flujo dock.")
	_expect(_find_node_by_name(dock_property, &"VariableStringValue") != null, "Migrated schema 3 variable exposes its active Value editing in the Flujo dock.")
	_expect(_find_node_by_name(dock_property, &"VariableAdvancedToggle") != null, "Migrated schema 3 variable exposes Advanced editing in the Flujo dock.")
	history.undo()
	await process_frame
	await process_frame
	_expect(controller.flow_graph == source and controller.flow_graph.schema_version == FlowGraph.SCHEMA_VERSION_2, "Migration Undo restores the exact schema 2 source graph.")
	history.redo()
	await process_frame
	await process_frame
	_expect(controller.flow_graph == migrated and controller.flow_graph.schema_version == FlowGraph.SCHEMA_VERSION_3, "Migration Redo restores the same schema 3 candidate.")

	var invalid_source: FlowGraph = FlowGraph.new()
	invalid_source.schema_version = FlowGraph.SCHEMA_VERSION_2
	var invalid_variable: FlowVariableDefinition = FlowVariableDefinition.new()
	invalid_variable.scope = 99
	invalid_source.variables = [invalid_variable]
	controller.flow_graph = invalid_source
	inspector_property.call(&"_rebuild_interface")
	await process_frame
	await process_frame
	migrate_button = _find_button(inspector_property, "Migrate FlowGraph to Schema 3")
	if migrate_button == null:
		_expect(false, "An invalid schema 2 graph still exposes migration so deterministic diagnostics can be presented.")
		return
	history_version = history.get_version()
	migrate_button.emit_signal(&"pressed")
	await process_frame
	await process_frame
	_expect(controller.flow_graph == invalid_source and invalid_source.schema_version == FlowGraph.SCHEMA_VERSION_2 and invalid_variable.scope == 99, "Rejected schema 2 to 3 migration preserves the invalid source literally.")
	_expect(history.get_version() == history_version, "Rejected schema 2 to 3 migration does not create an undo action.")
	_expect(_has_label_containing(inspector_property, "variables[0].scope"), "Rejected schema 2 to 3 migration displays the deterministic diagnostic path.")
	var direct_commands: FlowGraphEditorCommands = FlowGraphEditorCommands.new(undo_redo)
	_expect(not direct_commands.migrate_to_schema_3(controller), "Schema 2 to 3 migration command rejects the same invalid source deterministically.")
	var diagnostics: Array[FlowDiagnostic] = direct_commands.get_last_diagnostics()
	_expect(not diagnostics.is_empty() and diagnostics[0].code == FlowDiagnostic.CODE_INVALID_VARIABLE_SCOPE and diagnostics[0].element_path == "variables[0].scope" and diagnostics[0].related_id == invalid_variable.get_internal_id(), "Rejected schema 2 to 3 migration retains deterministic diagnostics for the Inspector.")


func _schema_3_variable_fixture() -> FlowGraph:
	var graph: FlowGraph = FlowGraph.new()
	graph.schema_version = FlowGraph.SCHEMA_VERSION_3
	graph.constructor = FlowConstructorDefinition.new()
	for value_type: int in range(FlowVariableDefinition.ValueType.BOOL, FlowVariableDefinition.ValueType.COLOR + 1):
		var variable: FlowVariableDefinition = FlowVariableDefinition.new()
		variable.display_name = "Schema 3 %d" % value_type
		variable.scope = FlowVariableDefinition.Scope.GLOBAL
		variable.value_type = value_type
		graph.variables.append(variable)
	graph.variables.append(null)
	var invalid_variable: FlowVariableDefinition = FlowVariableDefinition.new()
	invalid_variable.display_name = "Invalid Metadata"
	invalid_variable.scope = 99
	invalid_variable.binding = -1
	invalid_variable.value_type = 99
	graph.variables.append(invalid_variable)
	return graph


func _select_variable_row(property: FlowGraphInspectorProperty, index: int) -> void:
	var list: ItemList = _section_list(property, "Variables")
	if list == null or index < 0 or index >= list.item_count:
		_expect(false, "Schema 3 variable selection has a current in-range list row.")
		return
	list.select(index)
	list.emit_signal(&"item_selected", index)
	await process_frame
	await process_frame


func _value_control_name(value_type: int) -> StringName:
	match value_type:
		FlowVariableDefinition.ValueType.BOOL: return &"VariableBoolValue"
		FlowVariableDefinition.ValueType.INT: return &"VariableIntValue"
		FlowVariableDefinition.ValueType.FLOAT: return &"VariableFloatValue"
		FlowVariableDefinition.ValueType.STRING: return &"VariableStringValue"
		FlowVariableDefinition.ValueType.VECTOR2: return &"VariableVectorXValue"
		FlowVariableDefinition.ValueType.VECTOR3: return &"VariableVectorZValue"
		FlowVariableDefinition.ValueType.COLOR: return &"VariableColorValue"
	return &""


func _find_node_by_name(root: Node, node_name: StringName) -> Node:
	if root.name == node_name:
		return root
	for child: Node in root.get_children():
		var found: Node = _find_node_by_name(child, node_name)
		if found != null:
			return found
	return null


func _count_named_nodes(root: Node, node_name: StringName) -> int:
	var count: int = 1 if root.name == node_name else 0
	for child: Node in root.get_children():
		count += _count_named_nodes(child, node_name)
	return count


func _emit_option_selection(option: OptionButton, item_id: int) -> void:
	for index: int in option.item_count:
		if option.get_item_id(index) == item_id:
			option.emit_signal(&"item_selected", index)
			return
	_expect(false, "Variable option contains the requested canonical enum value.")


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


func _has_label_containing(root: Node, text: String) -> bool:
	if root is Label and (root as Label).text.contains(text):
		return true
	for child: Node in root.get_children():
		if _has_label_containing(child, text):
			return true
	return false


func _test_debug_instrumentation_removed() -> void:
	var sources: Array[String] = [
		FileAccess.get_file_as_string("res://addons/vp_flujo/plugin.gd"),
		FileAccess.get_file_as_string("res://addons/vp_flujo/editor/pv_controller_inspector_plugin.gd"),
		FileAccess.get_file_as_string("res://addons/vp_flujo/editor/flow_graph_inspector_property.gd"),
		FileAccess.get_file_as_string("res://addons/vp_flujo/editor/vp_flujo_dock.gd"),
	]
	for source: String in sources:
		_expect(not source.contains("InspectorDebug") and not source.contains("DockDebug"), "Temporary debug output is removed.")
		_expect(not source.contains("DEBUG_INSPECTOR") and not source.contains("DEBUG_DOCK"), "Temporary debug constants are removed.")
		_expect(not source.contains("VariableRoute") and not source.contains("DEBUG_VARIABLE_ROUTE"), "Temporary selection-route tracing is removed.")
