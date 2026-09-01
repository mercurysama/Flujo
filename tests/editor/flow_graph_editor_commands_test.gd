@tool
extends SceneTree


var _failures: Array[String] = []
var _changes: int = 0


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
	get_root().add_child(inspector_property)
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
	inspector_property.queue_free()
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

	_expect(commands.add_resource(created_graph, FlowGraphEditorCommands.Collection.PROCESSES), "A process can be added.")
	var process: FlowProcess = created_graph.processes[0]
	var process_id: String = process.get_internal_id()
	_expect(commands.rename_resource(created_graph, FlowGraphEditorCommands.Collection.PROCESSES, process_id, "Tick"), "A process can be renamed.")
	_expect(process.display_name == "Tick", "Rename is applied through the action.")
	history.undo()
	_expect(process.display_name == "_ready", "Undo preserves the same process instance.")
	history.redo()
	_expect(process.display_name == "Tick", "Redo preserves the process ID and instance.")
	_expect(commands.add_resource(created_graph, FlowGraphEditorCommands.Collection.PROCESSES), "A second process can be added.")
	var second_process: FlowProcess = created_graph.processes[1]
	_expect(commands.move_resource(created_graph, FlowGraphEditorCommands.Collection.PROCESSES, second_process.get_internal_id(), -1), "A process can move one position.")
	_expect(created_graph.processes[0] == second_process and created_graph.processes[1] == process, "Move keeps instances and order deterministically.")
	_expect(commands.delete_resource(created_graph, FlowGraphEditorCommands.Collection.PROCESSES, process_id), "An unreferenced process can be deleted.")
	_expect(created_graph.processes[1] == null, "Delete preserves the deliberate array slot.")

	_expect(commands.add_resource(created_graph, FlowGraphEditorCommands.Collection.VARIABLES), "A variable can be added.")
	var global_variable: FlowVariableDefinition = created_graph.variables[0]
	global_variable.scope = FlowVariableDefinition.Scope.GLOBAL
	_expect(commands.add_resource(created_graph, FlowGraphEditorCommands.Collection.STATE_MACHINES), "A state machine can be added.")
	_expect(created_graph.state_machines[0] is FlowStateMachineDefinition, "Added state machine has the expected type.")
	_expect(commands.add_resource(created_graph, FlowGraphEditorCommands.Collection.VARIABLES), "A second variable can be added.")
	var reference_variable: FlowVariableDefinition = created_graph.variables[1]
	reference_variable.global_variable_id = global_variable.get_internal_id()
	_expect(not commands.delete_resource(created_graph, FlowGraphEditorCommands.Collection.VARIABLES, global_variable.get_internal_id()), "Deleting a referenced global variable is rejected.")
	_expect(created_graph.variables[0] == global_variable, "Rejected deletion does not mutate the graph.")
	_expect(not commands.get_last_diagnostics().is_empty(), "Rejected deletion exposes diagnostics.")

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
	_expect(_collection_size(controller.flow_graph, collection) == previous_size + 1, "%s changes its model collection." % button_text)
	_expect(_visible_section_row_count(property, section_title) == previous_size + 1, "%s rebuilds the matching visible Inspector list." % button_text)
	history.undo()
	await process_frame
	_expect(_collection_size(controller.flow_graph, collection) == previous_size, "%s undo restores its model collection." % button_text)
	_expect(_visible_section_row_count(property, section_title) == previous_size, "%s undo refreshes the matching Inspector list." % button_text)
	history.redo()
	await process_frame
	_expect(_collection_size(controller.flow_graph, collection) == previous_size + 1, "%s redo restores its model collection." % button_text)
	_expect(_visible_section_row_count(property, section_title) == previous_size + 1, "%s redo refreshes the matching Inspector list." % button_text)
	var content: Node = property.get_child(0)
	var control_count: int = content.get_child_count()
	property.call(&"_rebuild_interface")
	property.call(&"_rebuild_interface")
	property.call(&"_rebuild_interface")
	_expect(content.get_child_count() == control_count, "%s repeated rebuilds keep a stable control count." % button_text)
	_expect(_visible_section_row_count(property, section_title) == previous_size + 1, "%s repeated rebuilds do not duplicate rows." % button_text)


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
	var title: Label = _find_label(property, section_title)
	if title == null:
		return -1
	var category: Node = title.get_parent()
	for child: Node in category.get_children():
		if child is ItemList:
			var list: ItemList = child as ItemList
			return list.item_count if list.is_visible_in_tree() else -1
	return -1


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
