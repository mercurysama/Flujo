@tool
class_name FlowGraphInspectorProperty
extends EditorProperty


const VISIBLE_LIST_ROWS: int = 5


var _content: VBoxContainer
var _commands: FlowGraphEditorCommands
var _selected_collection: FlowGraphEditorCommands.Collection = FlowGraphEditorCommands.Collection.PROCESSES
var _selected_id: String = ""
var _rename_input: LineEdit
var _rename_target_id: String = ""
var _rename_target_collection: FlowGraphEditorCommands.Collection = FlowGraphEditorCommands.Collection.PROCESSES
var _restore_selected_list_focus: bool = false
var _rebuild_queued: bool = false


## Supplies the editor undo/redo manager used by all model-changing controls.
func configure(undo_redo: EditorUndoRedoManager) -> void:
	_commands = FlowGraphEditorCommands.new(undo_redo)
	_commands.changed.connect(_request_rebuild)


func _init() -> void:
	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 6)
	add_child(_content)


func _ready() -> void:
	_request_rebuild()


func _update_property() -> void:
	_request_rebuild()


func _request_rebuild() -> void:
	if _rebuild_queued:
		return
	_rebuild_queued = true
	call_deferred(&"_rebuild_interface")


func _rebuild_interface() -> void:
	_rebuild_queued = false
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
		_render_schema_2_sections(sections, controller)
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


func _render_schema_2_sections(sections: Array, controller: PVController) -> void:
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
		if _section_contains_selection(section):
			_render_selected_actions(category, controller.flow_graph)


func _render_section(section: Dictionary, parent: Container) -> void:
	var title: Label = Label.new()
	title.text = section["title"]
	title.add_theme_font_size_override("font_size", 14)
	parent.add_child(title)

	var list: ItemList = ItemList.new()
	list.select_mode = ItemList.SELECT_SINGLE
	list.allow_reselect = true
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var selected_item_index: int = -1
	var entries: Array = section["entries"] as Array
	for entry: Dictionary in entries:
		var item_index: int = list.add_item(_format_entry(entry))
		list.set_item_metadata(item_index, entry)
		list.set_item_tooltip(item_index, "")
		if _entry_is_selected(entry):
			list.select(item_index)
			selected_item_index = item_index
	list.item_selected.connect(_on_item_selected.bind(list))
	parent.add_child(list)
	call_deferred(&"_fit_list_to_first_row", list)
	if selected_item_index >= 0 and _restore_selected_list_focus:
		_restore_selected_list_focus = false
		call_deferred(&"_focus_selected_list", list, selected_item_index, _selected_id)


func _render_selected_actions(parent: Container, graph: FlowGraph) -> void:
	var selection_actions: HBoxContainer = HBoxContainer.new()
	parent.add_child(selection_actions)
	_add_button_to(selection_actions, "Rename", _on_rename_pressed)
	_add_button_to(selection_actions, "Move Up", _on_move_up_pressed)
	_add_button_to(selection_actions, "Move Down", _on_move_down_pressed)
	_add_button_to(selection_actions, "Delete", _on_delete_pressed)
	if not _is_renaming_selection():
		return
	_rename_input = LineEdit.new()
	_rename_input.placeholder_text = "Display name"
	_rename_input.text = _selected_display_name(graph)
	_rename_input.text_submitted.connect(_on_rename_submitted)
	_rename_input.gui_input.connect(_on_rename_gui_input)
	parent.add_child(_rename_input)
	call_deferred(&"_focus_rename_input", _rename_input, _rename_target_id)


## Keeps every schema 2 list at five theme-sized rows while ItemList supplies scrolling for overflow.
func _fit_list_to_first_row(list: ItemList) -> void:
	if not is_instance_valid(list) or not list.is_inside_tree():
		return
	var minimum_height: float = _theme_list_top_inset(list) + _theme_item_row_height(list) * float(VISIBLE_LIST_ROWS)
	if list.item_count > 0:
		var first_row_rect: Rect2 = list.get_item_rect(0)
		if first_row_rect.size.y > 0.0:
			minimum_height = maxf(
				minimum_height,
				first_row_rect.end.y + first_row_rect.size.y * float(VISIBLE_LIST_ROWS - 1)
			)
	list.custom_minimum_size.y = minimum_height


func _theme_item_row_height(list: ItemList) -> float:
	var font: Font = list.get_theme_font(&"font")
	var font_size: int = list.get_theme_font_size(&"font_size")
	return font.get_height(font_size) + float(list.get_theme_constant(&"v_separation"))


func _theme_list_top_inset(list: ItemList) -> float:
	var panel: StyleBox = list.get_theme_stylebox(&"panel")
	return panel.get_margin(SIDE_TOP)


func _section_contains_selection(section: Dictionary) -> bool:
	for entry: Dictionary in section["entries"] as Array:
		if _entry_is_selected(entry):
			return true
	return false


func _entry_is_selected(entry: Dictionary) -> bool:
	return not _selected_id.is_empty() \
		and entry["internal_id"] == _selected_id \
		and _collection_for_type(entry["type"]) == _selected_collection


func _is_renaming_selection() -> bool:
	return not _rename_target_id.is_empty() \
		and _rename_target_id == _selected_id \
		and _rename_target_collection == _selected_collection


func _uses_schema_2_collections(controller: PVController) -> bool:
	return controller != null \
		and controller.flow_graph != null \
		and controller.flow_graph.schema_version == FlowGraph.SCHEMA_VERSION_2 \
		and controller.flow_graph.containers.is_empty()


func _format_entry(entry: Dictionary) -> String:
	if entry["is_empty"]:
		return "Empty"
	return entry["name"]


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
	_rename_target_id = ""
	_restore_selected_list_focus = false
	_request_rebuild()


func _on_create_graph_pressed() -> void:
	var controller: PVController = get_edited_object() as PVController
	if _commands.create_schema_2_graph(controller):
		_selected_id = ""
		_rename_target_id = ""


func _on_migrate_pressed() -> void:
	var controller: PVController = get_edited_object() as PVController
	if _commands.migrate_to_schema_2(controller):
		_selected_id = ""
		_rename_target_id = ""


func _on_add_process_pressed() -> void:
	_add_resource(FlowGraphEditorCommands.Collection.PROCESSES)


func _on_add_variable_pressed() -> void:
	_add_resource(FlowGraphEditorCommands.Collection.VARIABLES)


func _on_add_state_machine_pressed() -> void:
	_add_resource(FlowGraphEditorCommands.Collection.STATE_MACHINES)


func _add_resource(collection: FlowGraphEditorCommands.Collection) -> void:
	var controller: PVController = get_edited_object() as PVController
	if controller != null and _commands.add_resource(controller, collection):
		_selected_id = ""
		_rename_target_id = ""


func _on_rename_pressed() -> void:
	if not _selected_id.is_empty():
		_rename_target_id = _selected_id
		_rename_target_collection = _selected_collection
		_request_rebuild()


func _on_rename_submitted(_display_name: String) -> void:
	var controller: PVController = get_edited_object() as PVController
	if controller == null or _rename_input == null or not _is_renaming_selection():
		return
	var display_name: String = _rename_input.text
	_close_rename_editor()
	if not _commands.rename_resource(controller, _selected_collection, _selected_id, display_name):
		_request_rebuild()


func _on_rename_gui_input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	var key_event: InputEventKey = event as InputEventKey
	if not key_event.pressed or key_event.echo or key_event.keycode != KEY_ESCAPE:
		return
	if _rename_input != null and _is_renaming_selection():
		_close_rename_editor()


func _close_rename_editor() -> void:
	_rename_target_id = ""
	_restore_selected_list_focus = not _selected_id.is_empty()
	_request_rebuild()


func _focus_rename_input(input: LineEdit, target_id: String) -> void:
	if target_id == _rename_target_id and is_instance_valid(input) and input.is_inside_tree():
		input.grab_focus()
		input.select_all()


func _focus_selected_list(list: ItemList, item_index: int, selected_id: String) -> void:
	if selected_id == _selected_id and is_instance_valid(list) and list.is_inside_tree():
		list.select(item_index)
		list.grab_focus()


func _on_move_up_pressed() -> void:
	_move_selected(-1)


func _on_move_down_pressed() -> void:
	_move_selected(1)


func _move_selected(direction: int) -> void:
	var controller: PVController = get_edited_object() as PVController
	if controller != null:
		_commands.move_resource(controller, _selected_collection, _selected_id, direction)


func _on_delete_pressed() -> void:
	var controller: PVController = get_edited_object() as PVController
	if controller != null and _commands.delete_resource(controller, _selected_collection, _selected_id):
		_selected_id = ""
		_rename_target_id = ""
		_restore_selected_list_focus = false


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
