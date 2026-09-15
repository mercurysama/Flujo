@tool
class_name FlowGraphInspectorProperty
extends EditorProperty


const VISIBLE_LIST_ROWS: int = 5


## Reports the structural schema 3 variable selection to the editor coordinator.
signal schema_3_variable_selection_changed(
	controller: PVController,
	collection: FlowGraphEditorCommands.Collection,
	variable_id: String
)
signal schema_3_variable_editor_focus_requested(controller: PVController, variable_id: String)
signal schema_3_variable_list_focus_requested(controller: PVController, variable_id: String)

var _content: VBoxContainer
var _commands: FlowGraphEditorCommands
var _selected_collection: FlowGraphEditorCommands.Collection = FlowGraphEditorCommands.Collection.PROCESSES
var _selected_id: String = ""
var _rename_input: LineEdit
var _rename_target_id: String = ""
var _rename_target_collection: FlowGraphEditorCommands.Collection = FlowGraphEditorCommands.Collection.PROCESSES
var _restore_selected_list_focus: bool = false
var _schema_3_structural_action_containers: Dictionary = {}
var _rebuild_queued: bool = false
var _rebuild_generation: int = 0
var _variable_advanced_open: bool = false
var _variable_focus_control: StringName = &""
var _delete_confirmation: ConfirmationDialog
var _pending_delete_id: String = ""
var _pending_delete_collection: FlowGraphEditorCommands.Collection = FlowGraphEditorCommands.Collection.PROCESSES
var _dock_mode: bool = false
var _dock_controller: PVController
var _color_preview_id: String = ""
var _color_preview_original: Color = Color.WHITE
var _color_preview_value: Color = Color.WHITE


## Supplies the editor undo/redo manager used by all model-changing controls.
func configure(undo_redo: EditorUndoRedoManager) -> void:
	_commands = FlowGraphEditorCommands.new(undo_redo)
	_commands.changed.connect(_on_commands_changed)


func _on_commands_changed() -> void:
	_request_rebuild()


## Configures this editor as the schema 3 Variables surface hosted by the Flujo dock.
func configure_for_dock() -> void:
	_dock_mode = true


## Updates the dock-owned controller without retaining selection state from another scene object.
func set_dock_controller(controller: PVController) -> void:
	var next_controller: PVController = controller if is_instance_valid(controller) else null
	var current_controller: PVController = _dock_controller if is_instance_valid(_dock_controller) else null
	if current_controller == next_controller:
		return
	if current_controller != null and current_controller.is_inside_tree() \
			and current_controller.tree_exited.is_connected(_on_dock_controller_tree_exited):
		current_controller.tree_exited.disconnect(_on_dock_controller_tree_exited)
	_dock_controller = next_controller
	if _dock_controller != null and _dock_controller.is_inside_tree() \
			and not _dock_controller.tree_exited.is_connected(_on_dock_controller_tree_exited):
		_dock_controller.tree_exited.connect(_on_dock_controller_tree_exited)
	_selected_id = ""
	_rename_target_id = ""
	_variable_advanced_open = false
	_variable_focus_control = &""
	_restore_selected_list_focus = false
	_close_delete_confirmation()
	_request_rebuild()


func _on_dock_controller_tree_exited() -> void:
	set_dock_controller(null)


## Refreshes the current dock controller after a model replacement without changing selection ownership.
func refresh_dock_controller() -> void:
	if not _dock_mode:
		return
	if not is_instance_valid(_dock_controller):
		set_dock_controller(null)
		return
	_request_rebuild()


## Applies the Inspector-owned schema 3 variable selection to the dock editor.
func set_dock_variable_selection(
	controller: PVController,
	collection: FlowGraphEditorCommands.Collection,
	variable_id: String
) -> void:
	if not _dock_mode or _dock_controller != controller:
		return
	var next_id: String = variable_id if collection == FlowGraphEditorCommands.Collection.VARIABLES else ""
	if _selected_collection == collection and _selected_id == next_id:
		return
	_selected_collection = collection
	_selected_id = next_id
	_rename_target_id = ""
	_variable_advanced_open = false
	_variable_focus_control = &""
	_restore_selected_list_focus = false
	_close_delete_confirmation()
	_request_rebuild()


func _init() -> void:
	auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 6)
	add_child(_content)


func _ready() -> void:
	_request_rebuild()


func _update_property() -> void:
	_request_rebuild()


func _active_controller() -> PVController:
	if _dock_mode:
		return _dock_controller if is_instance_valid(_dock_controller) else null
	var controller: PVController = get_edited_object() as PVController
	return controller if is_instance_valid(controller) else null


func _request_rebuild() -> void:
	_rebuild_generation += 1
	if not _rebuild_queued:
		_queue_rebuild(_rebuild_generation)


func _queue_rebuild(generation: int) -> void:
	_rebuild_queued = true
	call_deferred(&"_rebuild_interface", generation)


func _rebuild_interface(generation: int = -1) -> void:
	if generation == -1:
		generation = _rebuild_generation
	if generation != _rebuild_generation:
		_rebuild_queued = false
		_queue_rebuild(_rebuild_generation)
		return
	_rebuild_queued = false
	var controller: PVController = _active_controller()
	var graph: FlowGraph = null
	if controller != null:
		graph = controller.flow_graph
	_render(FlowGraphInspectorPresenter.present(graph), controller, generation)


func _render(presentation: Dictionary, controller: PVController, generation: int) -> void:
	_schema_3_structural_action_containers.clear()
	for child: Node in _content.get_children():
		_content.remove_child(child)
		child.queue_free()

	var sections: Array = presentation["sections"] as Array
	if _dock_mode:
		_render_dock_schema_3_variable_options(controller, generation)
		return

	var summary: Label = Label.new()
	summary.text = "Schema %s — Active source: %s" % [
		presentation["schema_version"],
		presentation["active_source"],
	]
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content.add_child(summary)
	_render_actions(controller)

	if _uses_typed_collections(controller):
		_render_typed_sections(sections, controller, generation)
	else:
		for section: Dictionary in sections:
			_render_section(section, _content, generation)

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
	if _dock_mode or _commands == null or controller == null:
		return

	var graph: FlowGraph = controller.flow_graph
	if graph == null:
		_add_button("Create Schema 2 Graph", _on_create_graph_pressed)
		return
	if graph.schema_version == FlowGraph.CURRENT_SCHEMA_VERSION:
		_add_button("Migrate to Schema 2", _on_migrate_pressed)
		return
	if graph.schema_version == FlowGraph.SCHEMA_VERSION_2:
		_add_button("Migrate FlowGraph to Schema 3", _on_migrate_to_schema_3_pressed)
	if not _uses_typed_collections(controller):
		return


func _render_dock_schema_3_variable_options(controller: PVController, generation: int) -> void:
	if controller == null or controller.flow_graph == null \
			or controller.flow_graph.schema_version != FlowGraph.SCHEMA_VERSION_3 \
			or not controller.flow_graph.containers.is_empty():
		var message: Label = Label.new()
		message.text = "Select a Schema 3 Variable in the Godot Inspector to edit its options."
		message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_content.add_child(message)
		return
	var variable: FlowVariableDefinition = _selected_variable(controller.flow_graph)
	if variable == null:
		var message: Label = Label.new()
		message.text = "Select a Schema 3 Variable in the Godot Inspector to edit its options."
		message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_content.add_child(message)
		return
	_render_schema_3_variable_editor(_content, controller.flow_graph, generation)


func _render_typed_sections(sections: Array, controller: PVController, generation: int) -> void:
	for section: Dictionary in sections:
		var collection: FlowGraphEditorCommands.Collection = _section_collection(section["title"])
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
		_render_section(section, category, generation)
		if controller.flow_graph.schema_version == FlowGraph.SCHEMA_VERSION_3:
			var selection_actions: HBoxContainer = HBoxContainer.new()
			selection_actions.name = &"Schema3StructuralActions"
			category.add_child(selection_actions)
			_schema_3_structural_action_containers[collection] = selection_actions
			if _section_contains_selection(section):
				_render_schema_3_structural_actions(selection_actions)
		elif _section_contains_selection(section) and controller.flow_graph.schema_version == FlowGraph.SCHEMA_VERSION_2:
			_render_selected_actions(category, controller.flow_graph, generation)


func _render_section(section: Dictionary, parent: Container, generation: int) -> void:
	var title: Label = Label.new()
	title.text = section["title"]
	title.add_theme_font_size_override("font_size", 14)
	parent.add_child(title)

	var list: ItemList = ItemList.new()
	list.select_mode = ItemList.SELECT_SINGLE
	list.allow_reselect = true
	list.focus_mode = Control.FOCUS_ALL
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
	if _is_schema_3_graph() and _section_collection(section["title"]) == FlowGraphEditorCommands.Collection.VARIABLES:
		list.item_activated.connect(_on_schema_3_variable_item_activated.bind(list))
	list.gui_input.connect(_on_list_gui_input.bind(list))
	parent.add_child(list)
	call_deferred(&"_fit_list_to_first_row", list, generation)
	if _restore_selected_list_focus and _section_collection(section["title"]) == _selected_collection:
		_restore_selected_list_focus = false
		call_deferred(&"_focus_selected_list", list, selected_item_index, _selected_id, generation)


func _render_selected_actions(parent: Container, graph: FlowGraph, generation: int) -> void:
	var selection_actions: HBoxContainer = HBoxContainer.new()
	parent.add_child(selection_actions)
	_add_button_to(selection_actions, "Rename", _on_rename_pressed)
	_add_button_to(selection_actions, "Move Up", _on_move_up_pressed)
	_add_button_to(selection_actions, "Move Down", _on_move_down_pressed)
	_add_button_to(selection_actions, "Delete", _on_delete_pressed)
	if not _is_renaming_selection():
		return
	_rename_input = LineEdit.new()
	_rename_input.focus_mode = Control.FOCUS_ALL
	_rename_input.placeholder_text = "Display name"
	_rename_input.text = _selected_display_name(graph)
	_rename_input.text_submitted.connect(_on_rename_submitted)
	_rename_input.gui_input.connect(_on_rename_gui_input)
	parent.add_child(_rename_input)
	call_deferred(&"_focus_rename_input", _rename_input, _rename_target_id, generation)


func _render_schema_3_structural_actions(selection_actions: Container) -> void:
	_add_button_to(selection_actions, "Move Up", _on_move_up_pressed)
	_add_button_to(selection_actions, "Move Down", _on_move_down_pressed)
	_add_button_to(selection_actions, "Delete", _on_delete_pressed)


## Updates only schema 3 selection actions so row selection keeps its ItemList mounted.
func _update_schema_3_structural_actions() -> void:
	for collection: int in _schema_3_structural_action_containers:
		var selection_actions: HBoxContainer = _schema_3_structural_action_containers[collection] as HBoxContainer
		if not is_instance_valid(selection_actions) or not selection_actions.is_inside_tree():
			continue
		for child: Node in selection_actions.get_children():
			selection_actions.remove_child(child)
			child.queue_free()
		if collection == _selected_collection:
			_render_schema_3_structural_actions(selection_actions)


## Renders the schema 3 variable-only editor inside the selected Variables category.
func _render_schema_3_variable_editor(parent: Container, graph: FlowGraph, generation: int) -> void:
	var variable: FlowVariableDefinition = _selected_variable(graph)
	if variable == null:
		return

	var editor: VBoxContainer = VBoxContainer.new()
	editor.name = &"Schema3VariableEditor"
	editor.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(editor)
	_add_variable_text_field(editor, "Name", &"VariableNameInput", variable.display_name, &"display_name")
	_add_variable_enum_field(
		editor,
		"Type",
		&"VariableTypeOption",
		variable.value_type,
		FlowVariableDefinition.ValueType,
		&"value_type"
	)
	_add_variable_value_field(editor, variable)
	var advanced_toggle: Button = Button.new()
	advanced_toggle.focus_mode = Control.FOCUS_ALL
	advanced_toggle.name = &"VariableAdvancedToggle"
	advanced_toggle.text = "Advanced ▾" if _variable_advanced_open else "Advanced ▸"
	advanced_toggle.toggle_mode = true
	advanced_toggle.button_pressed = _variable_advanced_open
	advanced_toggle.toggled.connect(_on_variable_advanced_toggled)
	advanced_toggle.gui_input.connect(_on_variable_control_gui_input.bind(advanced_toggle))
	editor.add_child(advanced_toggle)
	if not _variable_advanced_open:
		_focus_requested_variable_control(editor, variable.get_internal_id(), generation)
		return

	var advanced: VBoxContainer = VBoxContainer.new()
	advanced.name = &"VariableAdvancedFields"
	advanced.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	editor.add_child(advanced)
	_add_variable_enum_field(
		advanced,
		"Scope",
		&"VariableScopeOption",
		variable.scope,
		FlowVariableDefinition.Scope,
		&"scope"
	)
	_add_variable_enum_field(
		advanced,
		"Binding",
		&"VariableBindingOption",
		variable.binding,
		FlowVariableDefinition.Binding,
		&"binding"
	)
	var persistent: CheckBox = CheckBox.new()
	persistent.focus_mode = Control.FOCUS_ALL
	persistent.name = &"VariablePersistentCheckBox"
	persistent.text = "Persistent"
	persistent.button_pressed = variable.persistent
	persistent.toggled.connect(_on_variable_persistent_toggled.bind(variable.get_internal_id()))
	persistent.gui_input.connect(_on_variable_control_gui_input.bind(persistent))
	advanced.add_child(persistent)
	var note_label: Label = Label.new()
	note_label.text = "Note (Ctrl+Enter to apply)"
	advanced.add_child(note_label)
	var note: TextEdit = TextEdit.new()
	note.name = &"VariableNoteInput"
	note.focus_mode = Control.FOCUS_ALL
	note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	note.custom_minimum_size.y = _theme_text_edit_height(note, 3)
	note.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	note.text = variable.user_note
	note.gui_input.connect(_on_variable_note_gui_input.bind(note, variable.get_internal_id(), variable.user_note))
	advanced.add_child(note)
	_focus_requested_variable_control(editor, variable.get_internal_id(), generation)


func _add_variable_text_field(
		parent: Container,
		label_text: String,
		control_name: StringName,
		value: String,
		property_name: StringName
) -> void:
	var label: Label = Label.new()
	label.text = label_text
	parent.add_child(label)
	var input: LineEdit = LineEdit.new()
	input.name = control_name
	input.focus_mode = Control.FOCUS_ALL
	input.text = value
	input.text_submitted.connect(_on_variable_text_submitted.bind(property_name, control_name))
	input.gui_input.connect(_on_variable_text_gui_input.bind(input, value))
	parent.add_child(input)


func _add_variable_enum_field(
		parent: Container,
		label_text: String,
		control_name: StringName,
		value: int,
		enum_values: Dictionary,
		property_name: StringName
) -> void:
	var label: Label = Label.new()
	label.text = label_text
	parent.add_child(label)
	var option: OptionButton = OptionButton.new()
	option.name = control_name
	option.focus_mode = Control.FOCUS_ALL
	var selected_index: int = -1
	var contains_value: bool = false
	for enum_value: int in enum_values.values():
		if enum_value == value:
			contains_value = true
			break
	if not contains_value:
		option.add_item("Invalid (%d)" % value, -1000000)
		option.set_item_disabled(0, true)
		selected_index = 0
	for enum_name: String in enum_values:
		var enum_value: int = enum_values[enum_name]
		option.add_item(enum_name, enum_value)
		if enum_value == value:
			selected_index = option.item_count - 1
	option.select(selected_index)
	option.item_selected.connect(_on_variable_option_selected.bind(option, property_name, control_name))
	option.gui_input.connect(_on_variable_control_gui_input.bind(option))
	parent.add_child(option)


func _add_variable_value_field(parent: Container, variable: FlowVariableDefinition) -> void:
	var label: Label = Label.new()
	label.text = "Value"
	parent.add_child(label)
	if not FlowVariableDefinition.is_valid_value_type(variable.value_type):
		var invalid: Label = Label.new()
		invalid.name = &"VariableInvalidValueType"
		invalid.text = "Invalid type (%d). Choose a valid Type to edit a value." % variable.value_type
		invalid.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		parent.add_child(invalid)
		return
	match variable.value_type:
		FlowVariableDefinition.ValueType.BOOL:
			var bool_input: CheckBox = CheckBox.new()
			bool_input.name = &"VariableBoolValue"
			bool_input.focus_mode = Control.FOCUS_ALL
			bool_input.text = "Enabled"
			bool_input.button_pressed = variable.bool_value
			bool_input.toggled.connect(_on_variable_value_changed.bind(&"bool_value", variable.get_internal_id(), bool_input.name))
			bool_input.gui_input.connect(_on_variable_control_gui_input.bind(bool_input))
			parent.add_child(bool_input)
		FlowVariableDefinition.ValueType.INT:
			_add_variable_spin_box(parent, &"VariableIntValue", float(variable.int_value), 1.0, &"int_value", variable.get_internal_id())
		FlowVariableDefinition.ValueType.FLOAT:
			_add_variable_spin_box(parent, &"VariableFloatValue", variable.float_value, 0.1, &"float_value", variable.get_internal_id())
		FlowVariableDefinition.ValueType.STRING:
			_add_variable_string_field(parent, variable)
		FlowVariableDefinition.ValueType.VECTOR2:
			_add_variable_vector_field(parent, variable.get_internal_id(), Vector3(variable.vector2_value.x, variable.vector2_value.y, 0.0), 2)
		FlowVariableDefinition.ValueType.VECTOR3:
			_add_variable_vector_field(parent, variable.get_internal_id(), variable.vector3_value, 3)
		FlowVariableDefinition.ValueType.COLOR:
			var color_input: ColorPickerButton = ColorPickerButton.new()
			color_input.name = &"VariableColorValue"
			color_input.focus_mode = Control.FOCUS_ALL
			color_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			color_input.color = variable.color_value
			color_input.pressed.connect(_on_color_picker_opened.bind(color_input, variable.get_internal_id(), variable.color_value))
			color_input.color_changed.connect(_on_color_picker_preview.bind(color_input, variable.get_internal_id()))
			color_input.popup_closed.connect(_on_color_picker_closed.bind(color_input, variable.get_internal_id()))
			color_input.gui_input.connect(_on_variable_control_gui_input.bind(color_input))
			parent.add_child(color_input)
			color_input.custom_minimum_size.y = _theme_color_swatch_height(color_input)


func _on_color_picker_opened(button: ColorPickerButton, variable_id: String, original_value: Color) -> void:
	_color_preview_id = variable_id
	_color_preview_original = original_value
	_color_preview_value = button.color


func _on_color_picker_preview(value: Color, button: ColorPickerButton, variable_id: String) -> void:
	if _color_preview_id != variable_id:
		return
	_color_preview_value = value
	button.color = value


func _on_color_picker_closed(button: ColorPickerButton, variable_id: String) -> void:
	if _color_preview_id != variable_id:
		return
	var preview: Color = _color_preview_value
	_color_preview_id = ""
	if preview != _color_preview_original:
		_commit_color_preview.call_deferred(button, variable_id, preview, _rebuild_generation)


func _commit_color_preview(
	button: ColorPickerButton,
	variable_id: String,
	preview: Color,
	generation: int
) -> void:
	if generation != _rebuild_generation or not is_instance_valid(button) or not button.is_inside_tree():
		return
	var controller: PVController = _active_controller()
	if controller == null or controller.flow_graph == null \
			or _selected_id != variable_id or _selected_variable(controller.flow_graph) == null:
		return
	_update_variable(variable_id, &"color_value", preview, button.name)


func _add_variable_string_field(parent: Container, variable: FlowVariableDefinition) -> void:
	var input: TextEdit = TextEdit.new()
	input.name = &"VariableStringValue"
	input.focus_mode = Control.FOCUS_ALL
	input.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	input.custom_minimum_size.y = _theme_text_edit_height(input, 3)
	input.text = variable.string_value
	input.gui_input.connect(_on_variable_string_gui_input.bind(
		input,
		variable.get_internal_id(),
		variable.string_value
	))
	parent.add_child(input)


func _add_variable_spin_box(
		parent: Container,
		control_name: StringName,
		value: float,
		step: float,
		property_name: StringName,
		variable_id: String
) -> void:
	var input: SpinBox = SpinBox.new()
	input.name = control_name
	input.focus_mode = Control.FOCUS_ALL
	input.step = step
	input.rounded = property_name == &"int_value"
	input.allow_greater = true
	input.allow_lesser = true
	input.value = value
	input.value_changed.connect(_on_variable_value_changed.bind(property_name, variable_id, control_name))
	input.gui_input.connect(_on_variable_spin_box_gui_input.bind(input))
	input.get_line_edit().gui_input.connect(_on_variable_spin_box_gui_input.bind(input))
	parent.add_child(input)


func _add_variable_vector_field(parent: Container, variable_id: String, value: Vector3, components: int) -> void:
	var labels: PackedStringArray = ["X", "Y", "Z"]
	for component: int in components:
		var input: SpinBox = SpinBox.new()
		input.name = StringName("VariableVector%sValue" % labels[component])
		input.focus_mode = Control.FOCUS_ALL
		input.tooltip_text = labels[component]
		input.step = 0.1
		input.allow_greater = true
		input.allow_lesser = true
		input.value = value[component]
		input.value_changed.connect(_on_variable_vector_component_changed.bind(variable_id, component, components, input.name))
		input.gui_input.connect(_on_variable_spin_box_gui_input.bind(input))
		input.get_line_edit().gui_input.connect(_on_variable_spin_box_gui_input.bind(input))
		parent.add_child(input)


func _on_variable_advanced_toggled(open: bool) -> void:
	_variable_advanced_open = open
	_request_rebuild()


func _on_variable_text_submitted(value: String, property_name: StringName, control_name: StringName) -> void:
	_restore_selected_list_focus = not _dock_mode
	_variable_focus_control = control_name if _dock_mode else &""
	_update_selected_variable(property_name, value, control_name)
	if not _dock_mode:
		_variable_focus_control = &""


func _on_variable_text_gui_input(event: InputEvent, input: LineEdit, original_value: String) -> void:
	if _is_escape_press(event):
		input.text = original_value
		_return_variable_escape_to_list(event, input)


func _on_variable_string_gui_input(
		event: InputEvent,
		input: TextEdit,
		variable_id: String,
		original_value: String
) -> void:
	if _is_escape_press(event):
		input.text = original_value
		_return_variable_escape_to_list(event, input)
		return
	if not event is InputEventKey:
		return
	var key_event: InputEventKey = event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	if key_event.keycode == KEY_ENTER and key_event.ctrl_pressed:
		_update_variable(variable_id, &"string_value", input.text, input.name)
		input.accept_event()


func _on_variable_option_selected(index: int, option: OptionButton, property_name: StringName, control_name: StringName) -> void:
	if index < 0 or option.is_item_disabled(index):
		return
	_update_selected_variable(property_name, option.get_item_id(index), control_name)


func _on_variable_value_changed(value: Variant, property_name: StringName, variable_id: String, control_name: StringName) -> void:
	_update_variable(variable_id, property_name, value, control_name)


## Returns Escape from immediate-value controls to the Inspector-owned selected row.
func _on_variable_control_gui_input(event: InputEvent, control: Control) -> void:
	if _is_escape_press(event):
		_return_variable_escape_to_list(event, control)


## Clears uncommitted SpinBox text before returning to the Inspector-owned selected row.
func _on_variable_spin_box_gui_input(event: InputEvent, input: SpinBox) -> void:
	if not _is_escape_press(event):
		return
	input.get_line_edit().text = str(input.value)
	_return_variable_escape_to_list(event, input)


func _on_variable_vector_component_changed(
		value: float,
		variable_id: String,
		component: int,
		components: int,
		control_name: StringName
) -> void:
	var variable: FlowVariableDefinition = _selected_variable_from_controller(variable_id)
	if variable == null:
		return
	if components == 2:
		var vector2_value: Vector2 = variable.vector2_value
		vector2_value[component] = value
		_update_variable(variable_id, &"vector2_value", vector2_value, control_name)
		return
	var vector3_value: Vector3 = variable.vector3_value
	vector3_value[component] = value
	_update_variable(variable_id, &"vector3_value", vector3_value, control_name)


func _on_variable_persistent_toggled(value: bool, variable_id: String) -> void:
	_update_variable(variable_id, &"persistent", value, &"VariablePersistentCheckBox")


func _on_variable_note_gui_input(
		event: InputEvent,
		input: TextEdit,
		variable_id: String,
		original_value: String
) -> void:
	if _is_escape_press(event):
		input.text = original_value
		_return_variable_escape_to_list(event, input)
		return
	if not event is InputEventKey:
		return
	var key_event: InputEventKey = event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	if key_event.keycode == KEY_ENTER and key_event.ctrl_pressed:
		_update_variable(variable_id, &"user_note", input.text, input.name)
		input.accept_event()


func _update_selected_variable(property_name: StringName, value: Variant, control_name: StringName) -> void:
	_update_variable(_selected_id, property_name, value, control_name)


func _update_variable(variable_id: String, property_name: StringName, value: Variant, control_name: StringName) -> bool:
	var controller: PVController = _active_controller()
	if controller == null or _commands == null:
		return false
	_variable_focus_control = control_name
	if not _commands.set_variable_property(controller, variable_id, property_name, value):
		_variable_focus_control = &""
		return false
	return true


func _selected_variable(graph: FlowGraph) -> FlowVariableDefinition:
	for variable: FlowVariableDefinition in graph.variables:
		if variable != null and variable.get_internal_id() == _selected_id:
			return variable
	return null


func _selected_variable_from_controller(variable_id: String) -> FlowVariableDefinition:
	var controller: PVController = _active_controller()
	if controller == null or controller.flow_graph == null:
		return null
	for variable: FlowVariableDefinition in controller.flow_graph.variables:
		if variable != null and variable.get_internal_id() == variable_id:
			return variable
	return null


func _focus_requested_variable_control(editor: Control, variable_id: String, generation: int) -> void:
	if variable_id != _selected_id or _variable_focus_control.is_empty():
		return
	var focus_control: Control = editor.find_child(String(_variable_focus_control), true, false) as Control
	if focus_control != null:
		call_deferred(&"_focus_variable_control", focus_control, variable_id, _variable_focus_control, generation)


func _focus_variable_control(control: Control, variable_id: String, control_name: StringName, generation: int) -> void:
	if generation == _rebuild_generation \
			and variable_id == _selected_id and control_name == _variable_focus_control \
			and _can_grab_focus(control):
		control.grab_focus()
	if generation == _rebuild_generation:
		_variable_focus_control = &""


## Handles only an explicit Enter request from the selected Inspector variable row.
func focus_selected_variable_editor(controller: PVController, variable_id: String) -> void:
	if not _dock_mode or controller != _active_controller() or variable_id != _selected_id:
		return
	var input: Control = _content.find_child("VariableNameInput", true, false) as Control
	if input != null:
		_variable_focus_control = &"VariableNameInput"
		call_deferred(&"_focus_variable_control", input, variable_id, &"VariableNameInput", _rebuild_generation)
		return
	_variable_focus_control = &"VariableNameInput"
	_request_rebuild()


## Requests Inspector focus only after Escape cancels a dock text buffer.
func _request_inspector_variable_list_focus() -> void:
	var controller: PVController = _active_controller()
	if _dock_mode and controller != null and not _selected_id.is_empty():
		emit_signal(&"schema_3_variable_list_focus_requested", controller, _selected_id)


## Returns true only for a single non-repeated Escape key press.
func _is_escape_press(event: InputEvent) -> bool:
	if not event is InputEventKey:
		return false
	var key_event: InputEventKey = event as InputEventKey
	return key_event.pressed and not key_event.echo and key_event.keycode == KEY_ESCAPE


## Cancels a dock-local edit without changing the Inspector's stable-ID selection.
func _return_variable_escape_to_list(_event: InputEvent, control: Control) -> void:
	control.accept_event()
	if _dock_mode:
		_request_inspector_variable_list_focus()
	else:
		_restore_selected_list_focus = true
		_request_rebuild()


func _can_grab_focus(control: Control) -> bool:
	return is_instance_valid(control) \
		and control.is_inside_tree() \
		and control.is_visible_in_tree() \
		and control.focus_mode != Control.FOCUS_NONE


func _theme_text_edit_height(input: TextEdit, lines: int) -> float:
	var font: Font = input.get_theme_font(&"font")
	var font_size: int = input.get_theme_font_size(&"font_size")
	var normal: StyleBox = input.get_theme_stylebox(&"normal")
	return font.get_height(font_size) * float(lines) + normal.get_margin(SIDE_TOP) + normal.get_margin(SIDE_BOTTOM)


## Gives the color swatch two theme-sized text rows without hard-coded pixels.
func _theme_color_swatch_height(button: ColorPickerButton) -> float:
	var font: Font = button.get_theme_font(&"font")
	var font_size: int = button.get_theme_font_size(&"font_size")
	var normal: StyleBox = button.get_theme_stylebox(&"normal")
	var themed_height: float = font.get_height(font_size) * 2.0 \
		+ normal.get_margin(SIDE_TOP) + normal.get_margin(SIDE_BOTTOM)
	return maxf(button.get_minimum_size().y, themed_height)


## Keeps every typed-collection list at five theme-sized rows while ItemList supplies scrolling for overflow.
func _fit_list_to_first_row(list: ItemList, generation: int) -> void:
	if generation != _rebuild_generation or not is_instance_valid(list) or not list.is_inside_tree():
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


func _section_collection(title: String) -> FlowGraphEditorCommands.Collection:
	if title == "Variables":
		return FlowGraphEditorCommands.Collection.VARIABLES
	if title == "State Machines":
		return FlowGraphEditorCommands.Collection.STATE_MACHINES
	return FlowGraphEditorCommands.Collection.PROCESSES


func _entry_is_selected(entry: Dictionary) -> bool:
	return not _selected_id.is_empty() \
		and entry["internal_id"] == _selected_id \
		and _collection_for_type(entry["type"]) == _selected_collection


func _is_renaming_selection() -> bool:
	return not _rename_target_id.is_empty() \
		and _rename_target_id == _selected_id \
		and _rename_target_collection == _selected_collection


func _uses_typed_collections(controller: PVController) -> bool:
	return controller != null \
		and controller.flow_graph != null \
		and (controller.flow_graph.schema_version == FlowGraph.SCHEMA_VERSION_2 \
			or controller.flow_graph.schema_version == FlowGraph.SCHEMA_VERSION_3) \
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
	button.focus_mode = Control.FOCUS_ALL
	button.text = label
	button.pressed.connect(callback)
	_content.add_child(button)


func _add_button_to(parent: Container, label: String, callback: Callable) -> void:
	var button: Button = Button.new()
	button.focus_mode = Control.FOCUS_ALL
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
	if _is_schema_3_graph():
		_restore_selected_list_focus = false
		if _selected_collection == FlowGraphEditorCommands.Collection.VARIABLES:
			_publish_schema_3_variable_selection()
		else:
			_clear_schema_3_variable_selection()
		_update_schema_3_structural_actions()
		return
	_restore_selected_list_focus = true
	if _selected_collection == FlowGraphEditorCommands.Collection.VARIABLES:
		_publish_schema_3_variable_selection()
	else:
		_clear_schema_3_variable_selection()
	_request_rebuild()


func _on_list_gui_input(event: InputEvent, list: ItemList) -> void:
	if not event is InputEventKey:
		return
	var key_event: InputEventKey = event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	if key_event.keycode == KEY_ESCAPE:
		if _is_schema_3_variable_list(list):
			var selected_items: PackedInt32Array = list.get_selected_items()
			if selected_items.size() == 1:
				list.select(selected_items[0])
				list.accept_event()


## Uses ItemList's public activation signal so native Enter and mouse activation share one path.
func _on_schema_3_variable_item_activated(item_index: int, list: ItemList) -> void:
	if not _is_schema_3_variable_list(list):
		return
	var entry: Dictionary = list.get_item_metadata(item_index) as Dictionary
	var variable_id: String = entry.get("internal_id", "") as String
	var controller: PVController = _active_controller()
	if controller == null or variable_id.is_empty() or variable_id != _selected_id:
		return
	emit_signal(&"schema_3_variable_editor_focus_requested", controller, variable_id)


func _is_schema_3_variable_list(list: ItemList) -> bool:
	return not _dock_mode and list != null and _is_schema_3_graph() \
		and _selected_collection == FlowGraphEditorCommands.Collection.VARIABLES


func _is_schema_3_graph() -> bool:
	var controller: PVController = _active_controller()
	return controller != null and controller.flow_graph != null \
		and controller.flow_graph.schema_version == FlowGraph.SCHEMA_VERSION_3


func _publish_schema_3_variable_selection() -> void:
	if _dock_mode or _selected_collection != FlowGraphEditorCommands.Collection.VARIABLES:
		return
	var controller: PVController = _active_controller()
	if controller == null or controller.flow_graph == null \
			or controller.flow_graph.schema_version != FlowGraph.SCHEMA_VERSION_3:
		return
	emit_signal(
		&"schema_3_variable_selection_changed",
		controller,
		_selected_collection,
		_selected_id
	)


func _clear_schema_3_variable_selection() -> void:
	if _dock_mode:
		return
	var controller: PVController = _active_controller()
	if controller == null:
		return
	emit_signal(
		&"schema_3_variable_selection_changed",
		controller,
		FlowGraphEditorCommands.Collection.VARIABLES,
		""
	)


func _on_create_graph_pressed() -> void:
	var controller: PVController = _active_controller()
	if _commands.create_schema_2_graph(controller):
		_selected_id = ""
		_rename_target_id = ""


func _on_migrate_pressed() -> void:
	var controller: PVController = _active_controller()
	if _commands.migrate_to_schema_2(controller):
		_selected_id = ""
		_rename_target_id = ""


func _on_migrate_to_schema_3_pressed() -> void:
	var controller: PVController = _active_controller()
	if _commands.migrate_to_schema_3(controller):
		_selected_id = ""
		_rename_target_id = ""
		_variable_advanced_open = false
		_variable_focus_control = &""
		_clear_schema_3_variable_selection()


func _on_add_process_pressed() -> void:
	_add_resource(FlowGraphEditorCommands.Collection.PROCESSES)


func _on_add_variable_pressed() -> void:
	_add_resource(FlowGraphEditorCommands.Collection.VARIABLES)


func _on_add_state_machine_pressed() -> void:
	_add_resource(FlowGraphEditorCommands.Collection.STATE_MACHINES)


func _add_resource(collection: FlowGraphEditorCommands.Collection) -> void:
	var controller: PVController = _active_controller()
	if controller != null and _commands.add_resource(controller, collection):
		_selected_id = ""
		_rename_target_id = ""
		if collection == FlowGraphEditorCommands.Collection.VARIABLES:
			_clear_schema_3_variable_selection()


func _on_rename_pressed() -> void:
	if not _selected_id.is_empty():
		_rename_target_id = _selected_id
		_rename_target_collection = _selected_collection
		_request_rebuild()


func _on_rename_submitted(_display_name: String) -> void:
	var controller: PVController = _active_controller()
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


func _focus_rename_input(input: LineEdit, target_id: String, generation: int) -> void:
	if generation == _rebuild_generation and target_id == _rename_target_id and _can_grab_focus(input):
		input.grab_focus()
		input.select_all()


func _focus_selected_list(list: ItemList, item_index: int, selected_id: String, generation: int) -> void:
	if generation == _rebuild_generation and _can_grab_focus(list):
		if selected_id == _selected_id and item_index >= 0:
			list.select(item_index)
		list.grab_focus()


## Returns to the stable-ID-selected schema 3 row only after a deliberate dock Escape.
func focus_schema_3_variable_list(controller: PVController, variable_id: String) -> void:
	if _dock_mode or controller != _active_controller() or variable_id != _selected_id:
		return
	if not _is_schema_3_graph() or _selected_collection != FlowGraphEditorCommands.Collection.VARIABLES:
		return
	_restore_selected_list_focus = true
	_request_rebuild()


func _on_move_up_pressed() -> void:
	_move_selected(-1)


func _on_move_down_pressed() -> void:
	_move_selected(1)


func _move_selected(direction: int) -> void:
	var controller: PVController = _active_controller()
	if controller != null:
		_restore_selected_list_focus = not _is_schema_3_graph()
		if not _commands.move_resource(controller, _selected_collection, _selected_id, direction):
			_restore_selected_list_focus = false


func _on_delete_pressed() -> void:
	var controller: PVController = _active_controller()
	if controller == null or controller.flow_graph == null or _selected_id.is_empty():
		return
	var display_name: String = _selected_display_name(controller.flow_graph)
	if display_name.is_empty():
		return
	_show_delete_confirmation(display_name)


func _show_delete_confirmation(display_name: String) -> void:
	_close_delete_confirmation()
	_pending_delete_id = _selected_id
	_pending_delete_collection = _selected_collection
	_delete_confirmation = ConfirmationDialog.new()
	_delete_confirmation.name = &"FlowGraphDeleteConfirmation"
	_delete_confirmation.title = "Delete \"%s\"?" % display_name
	_delete_confirmation.dialog_text = "Delete \"%s\"? This cannot be undone without Undo." % display_name
	_delete_confirmation.get_ok_button().text = "Delete"
	_delete_confirmation.confirmed.connect(_on_delete_confirmed)
	_delete_confirmation.canceled.connect(_on_delete_cancelled)
	add_child(_delete_confirmation)
	_delete_confirmation.popup_centered()


func _on_delete_confirmed() -> void:
	var delete_id: String = _pending_delete_id
	var delete_collection: FlowGraphEditorCommands.Collection = _pending_delete_collection
	_close_delete_confirmation()
	var controller: PVController = _active_controller()
	if controller != null and _commands.delete_resource(controller, delete_collection, delete_id):
		_selected_id = ""
		_rename_target_id = ""
		_restore_selected_list_focus = true
		if delete_collection == FlowGraphEditorCommands.Collection.VARIABLES:
			_clear_schema_3_variable_selection()


func _on_delete_cancelled() -> void:
	_close_delete_confirmation()
	_restore_selected_list_focus = not _is_schema_3_graph()
	_request_rebuild()


func _close_delete_confirmation() -> void:
	_pending_delete_id = ""
	if is_instance_valid(_delete_confirmation):
		_delete_confirmation.queue_free()
	_delete_confirmation = null


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
