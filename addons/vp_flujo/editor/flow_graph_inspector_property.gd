@tool
class_name FlowGraphInspectorProperty
extends EditorProperty


var _content: VBoxContainer
var _commands: FlowGraphEditorCommands
var _selected_collection: FlowGraphEditorCommands.Collection = FlowGraphEditorCommands.Collection.PROCESSES
var _selected_id: String = ""
var _rename_input: LineEdit


## Supplies the editor undo/redo manager used by all model-changing controls.
func configure(undo_redo: EditorUndoRedoManager) -> void:
	_commands = FlowGraphEditorCommands.new(undo_redo)
	_commands.changed.connect(_rebuild_interface)


func _init() -> void:
	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 6)
	add_child(_content)


func _ready() -> void:
	call_deferred(&"_rebuild_interface")


func _update_property() -> void:
	_rebuild_interface()


func _rebuild_interface() -> void:
	var controller: PVController = get_edited_object() as PVController
	var graph: FlowGraph = null
	if controller != null:
		graph = controller.flow_graph
	_render(FlowGraphInspectorPresenter.present(graph), controller)


func _render(presentation: Dictionary, controller: PVController) -> void:
	for child: Node in _content.get_children():
		_content.remove_child(child)
		child.queue_free()

	var summary: Label = Label.new()
	summary.text = "Schema %s — Active source: %s" % [
		presentation["schema_version"],
		presentation["active_source"],
	]
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content.add_child(summary)
	_render_actions(controller)

	var sections: Array = presentation["sections"] as Array
	if _uses_schema_2_collections(controller):
		_render_schema_2_sections(sections)
	else:
		for section: Dictionary in sections:
			_render_section(section, _content)

	var diagnostics: Array = presentation["diagnostics"] as Array
	if not diagnostics.is_empty():
		var diagnostics_title: Label = Label.new()
		diagnostics_title.text = "Diagnostics"
		diagnostics_title.add_theme_font_size_override("font_size", 14)
		_content.add_child(diagnostics_title)
		for diagnostic: Dictionary in diagnostics:
			var diagnostic_label: Label = Label.new()
			diagnostic_label.text = "%s: %s (%s)" % [
				_severity_name(diagnostic["severity"]),
				diagnostic["message"],
				diagnostic["element_path"],
			]
			diagnostic_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			_content.add_child(diagnostic_label)

	if _commands != null:
		for diagnostic: FlowDiagnostic in _commands.get_last_diagnostics():
			var command_diagnostic: Label = Label.new()
			command_diagnostic.text = "%s: %s (%s)" % [
				_severity_name(diagnostic.severity),
				diagnostic.message,
				diagnostic.element_path,
			]
			command_diagnostic.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			_content.add_child(command_diagnostic)


func _render_actions(controller: PVController) -> void:
	if _commands == null or controller == null:
		return

	var graph: FlowGraph = controller.flow_graph
	if graph == null:
		_add_button("Create Schema 2 Graph", _on_create_graph_pressed)
		return
	if graph.schema_version == FlowGraph.CURRENT_SCHEMA_VERSION:
		_add_button("Migrate to Schema 2", _on_migrate_pressed)
		return
	if graph.schema_version != FlowGraph.SCHEMA_VERSION_2 or not graph.containers.is_empty():
		return

	if _selected_id.is_empty():
		return
	_rename_input = LineEdit.new()
	_rename_input.placeholder_text = "Display name"
	_rename_input.text = _selected_display_name(graph)
	_content.add_child(_rename_input)
	var selection_actions: HBoxContainer = HBoxContainer.new()
	_content.add_child(selection_actions)
	_add_button_to(selection_actions, "Rename", _on_rename_pressed)
	_add_button_to(selection_actions, "Move Up", _on_move_up_pressed)
	_add_button_to(selection_actions, "Move Down", _on_move_down_pressed)
	_add_button_to(selection_actions, "Delete", _on_delete_pressed)


func _render_schema_2_sections(sections: Array) -> void:
	for section: Dictionary in sections:
		var category: VBoxContainer = VBoxContainer.new()
		category.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_content.add_child(category)
		match section["title"]:
			"Processes":
				_add_button_to(category, "Add Process", _on_add_process_pressed)
			"Variables":
				_add_button_to(category, "Add Variable", _on_add_variable_pressed)
			"State Machines":
				_add_button_to(category, "Add State Machine", _on_add_state_machine_pressed)
		_render_section(section, category)


func _render_section(section: Dictionary, parent: Container) -> void:
	var title: Label = Label.new()
	title.text = section["title"]
	title.add_theme_font_size_override("font_size", 14)
	parent.add_child(title)

	var list: ItemList = ItemList.new()
	list.select_mode = ItemList.SELECT_SINGLE
	list.allow_reselect = true
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var entries: Array = section["entries"] as Array
	for entry: Dictionary in entries:
		var item_index: int = list.add_item(_format_entry(entry))
		list.set_item_metadata(item_index, entry)
	list.item_selected.connect(_on_item_selected.bind(list))
	parent.add_child(list)


func _uses_schema_2_collections(controller: PVController) -> bool:
	return controller != null \
		and controller.flow_graph != null \
		and controller.flow_graph.schema_version == FlowGraph.SCHEMA_VERSION_2 \
		and controller.flow_graph.containers.is_empty()


func _format_entry(entry: Dictionary) -> String:
	var internal_id: String = entry["internal_id"]
	var id_text: String = "No ID" if internal_id.is_empty() else "ID: %s" % internal_id
	return "[%d] %s — %s\n%s" % [
		entry["index"],
		entry["type"],
		entry["name"],
		id_text,
	]


func _severity_name(severity: int) -> String:
	if severity == FlowDiagnostic.Severity.ERROR:
		return "Error"
	if severity == FlowDiagnostic.Severity.WARNING:
		return "Warning"
	return "Info"


func _add_button(label: String, callback: Callable) -> void:
	var button: Button = Button.new()
	button.text = label
	button.pressed.connect(callback)
	_content.add_child(button)


func _add_button_to(parent: Container, label: String, callback: Callable) -> void:
	var button: Button = Button.new()
	button.text = label
	button.pressed.connect(callback)
	parent.add_child(button)


func _on_item_selected(item_index: int, list: ItemList) -> void:
	var entry: Dictionary = list.get_item_metadata(item_index) as Dictionary
	var internal_id: String = entry["internal_id"]
	if internal_id.is_empty():
		return
	_selected_id = internal_id
	_selected_collection = _collection_for_type(entry["type"])
	_rebuild_interface()


func _on_create_graph_pressed() -> void:
	var controller: PVController = get_edited_object() as PVController
	if _commands.create_schema_2_graph(controller):
		_selected_id = ""


func _on_migrate_pressed() -> void:
	var controller: PVController = get_edited_object() as PVController
	if _commands.migrate_to_schema_2(controller):
		_selected_id = ""


func _on_add_process_pressed() -> void:
	_add_resource(FlowGraphEditorCommands.Collection.PROCESSES)


func _on_add_variable_pressed() -> void:
	_add_resource(FlowGraphEditorCommands.Collection.VARIABLES)


func _on_add_state_machine_pressed() -> void:
	_add_resource(FlowGraphEditorCommands.Collection.STATE_MACHINES)


func _add_resource(collection: FlowGraphEditorCommands.Collection) -> void:
	var controller: PVController = get_edited_object() as PVController
	if controller != null and _commands.add_resource(controller.flow_graph, collection):
		_selected_id = ""


func _on_rename_pressed() -> void:
	var controller: PVController = get_edited_object() as PVController
	if controller != null and _rename_input != null:
		_commands.rename_resource(controller.flow_graph, _selected_collection, _selected_id, _rename_input.text)


func _on_move_up_pressed() -> void:
	_move_selected(-1)


func _on_move_down_pressed() -> void:
	_move_selected(1)


func _move_selected(direction: int) -> void:
	var controller: PVController = get_edited_object() as PVController
	if controller != null:
		_commands.move_resource(controller.flow_graph, _selected_collection, _selected_id, direction)


func _on_delete_pressed() -> void:
	var controller: PVController = get_edited_object() as PVController
	if controller != null and _commands.delete_resource(controller.flow_graph, _selected_collection, _selected_id):
		_selected_id = ""


func _selected_display_name(graph: FlowGraph) -> String:
	var values: Array = []
	match _selected_collection:
		FlowGraphEditorCommands.Collection.PROCESSES:
			values = graph.processes
		FlowGraphEditorCommands.Collection.VARIABLES:
			values = graph.variables
		FlowGraphEditorCommands.Collection.STATE_MACHINES:
			values = graph.state_machines
	for value: Variant in values:
		if value is Resource and _resource_id(value as Resource) == _selected_id:
			if value is FlowBlockContainer:
				return (value as FlowBlockContainer).display_name
			if value is FlowVariableDefinition:
				return (value as FlowVariableDefinition).display_name
			if value is FlowStateMachineDefinition:
				return (value as FlowStateMachineDefinition).display_name
	_selected_id = ""
	return ""


func _collection_for_type(type_name: String) -> FlowGraphEditorCommands.Collection:
	if type_name == "FlowVariableDefinition":
		return FlowGraphEditorCommands.Collection.VARIABLES
	if type_name == "FlowStateMachineDefinition":
		return FlowGraphEditorCommands.Collection.STATE_MACHINES
	return FlowGraphEditorCommands.Collection.PROCESSES


func _resource_id(resource: Resource) -> String:
	if resource is FlowBlockContainer:
		return (resource as FlowBlockContainer).get_internal_id()
	if resource is FlowVariableDefinition:
		return (resource as FlowVariableDefinition).get_internal_id()
	if resource is FlowStateMachineDefinition:
		return (resource as FlowStateMachineDefinition).get_internal_id()
	return ""
