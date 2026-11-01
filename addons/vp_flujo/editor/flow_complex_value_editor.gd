@tool
## Reusable editor for Array, Dictionary, ResourceRef, Enum and Bitfield sources.
class_name FlowComplexValueEditor
extends PopupPanel


signal source_confirmed(source: FlowValueSource)
signal cancelled


const MAX_EDITOR_NESTING_DEPTH: int = 8

const CHILD_LITERAL_TYPES: Array[Variant.Type] = [
	Variant.Type.TYPE_BOOL,
	Variant.Type.TYPE_INT,
	Variant.Type.TYPE_FLOAT,
	Variant.Type.TYPE_STRING,
]

const CHILD_SOURCE_SCALAR: int = 2001
const CHILD_SOURCE_VARIABLE: int = 2002
const CHILD_SOURCE_OPERATION: int = 2003
const CHILD_SOURCE_CONDITION: int = 2004
const CHILD_SOURCE_ARRAY: int = 2005
const CHILD_SOURCE_DICTIONARY: int = 2006
const CHILD_SOURCE_RESOURCE: int = 2007
const CHILD_SOURCE_ENUM: int = 2008
const CHILD_SOURCE_BITFIELD: int = 2009

var _draft: FlowValueSource
var _graph: FlowGraph
var _context: Dictionary = {}
var _nesting_depth: int = 0
var _content: VBoxContainer
var _body: VBoxContainer
var _preview: Label
var _status: Label
var _confirm: Button
var _closing_for_action: bool = false
var _nested_editor: FlowComplexValueEditor
var _nested_replace: Callable = Callable()
var _variable_selector: FlowVariableSelector
var _operation_editor: FlowOperationEditor
var _condition_editor: FlowConditionEditor
var _pending_replace: Callable = Callable()
var _resource_dialog: EditorFileDialog


func _init() -> void:
	auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	name = &"FlowComplexValueEditor"
	min_size = Vector2i(620, 430)
	size = Vector2i(720, 560)
	close_requested.connect(_cancel)
	popup_hide.connect(_on_popup_hide)

	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override(&"margin_left", 14)
	margin.add_theme_constant_override(&"margin_top", 12)
	margin.add_theme_constant_override(&"margin_right", 14)
	margin.add_theme_constant_override(&"margin_bottom", 12)
	add_child(margin)

	_content = VBoxContainer.new()
	_content.add_theme_constant_override(&"separation", 8)
	margin.add_child(_content)

	var title: Label = Label.new()
	title.name = &"ComplexValueTitle"
	title.text = "Edit Structured Value"
	title.add_theme_font_size_override(&"font_size", 16)
	_content.add_child(title)

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content.add_child(scroll)

	_body = VBoxContainer.new()
	_body.name = &"ComplexValueBody"
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override(&"separation", 6)
	scroll.add_child(_body)

	_preview = Label.new()
	_preview.name = &"ComplexValuePreview"
	_preview.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content.add_child(_preview)

	_status = Label.new()
	_status.name = &"ComplexValueStatus"
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content.add_child(_status)

	var actions: HBoxContainer = HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_END
	var cancel_button: Button = Button.new()
	cancel_button.name = &"CancelComplexValue"
	cancel_button.text = "Cancel"
	cancel_button.pressed.connect(_cancel)
	actions.add_child(cancel_button)
	_confirm = Button.new()
	_confirm.name = &"ConfirmComplexValue"
	_confirm.text = "Confirm"
	_confirm.pressed.connect(_confirm_draft)
	actions.add_child(_confirm)
	_content.add_child(actions)

	_resource_dialog = EditorFileDialog.new()
	_resource_dialog.name = &"ComplexResourceDialog"
	_resource_dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILE
	_resource_dialog.access = EditorFileDialog.ACCESS_RESOURCES
	_resource_dialog.add_filter("*.*", "Project Resource")
	_resource_dialog.file_selected.connect(_on_resource_file_selected)
	add_child(_resource_dialog)

	_variable_selector = FlowVariableSelector.new()
	_variable_selector.name = &"NestedVariableSelector"
	_variable_selector.variable_selected.connect(_on_nested_variable_selected)
	_variable_selector.cancelled.connect(_on_nested_source_cancelled)
	add_child(_variable_selector)

	_operation_editor = FlowOperationEditor.new()
	_operation_editor.name = &"NestedOperationEditor"
	_operation_editor.operation_confirmed.connect(_on_nested_operation_confirmed)
	_operation_editor.cancelled.connect(_on_nested_source_cancelled)
	add_child(_operation_editor)

	_condition_editor = FlowConditionEditor.new()
	_condition_editor.name = &"NestedConditionEditor"
	_condition_editor.condition_confirmed.connect(_on_nested_condition_confirmed)
	_condition_editor.cancelled.connect(_on_nested_source_cancelled)
	add_child(_condition_editor)


func open_for_source(
		source: FlowValueSource,
		graph: FlowGraph = null,
		anchor: Rect2 = Rect2(),
		context: Dictionary = {}
) -> void:
	_graph = graph
	_context = context.duplicate()
	_nesting_depth = int(_context.get("complex_nesting_depth", 0))
	_draft = source.duplicate_with_new_id() if source != null else null
	_closing_for_action = false
	_nested_replace = Callable()
	_pending_replace = Callable()
	_rebuild()
	var popup_position: Vector2i = Vector2i(
		int(anchor.position.x),
		int(anchor.position.y + anchor.size.y)
	)
	popup(Rect2i(popup_position, Vector2i(size)))


func set_draft(source: FlowValueSource) -> void:
	_draft = source.duplicate_with_new_id() if source != null else null
	_rebuild()


func get_draft() -> FlowValueSource:
	return _draft


func can_confirm() -> bool:
	if _draft == null or not _draft.is_valid():
		return false
	if _draft is FlowResourceRefValueSource:
		return (_draft as FlowResourceRefValueSource).has_path()
	return true


func _rebuild() -> void:
	if _body == null:
		return
	for child: Node in _body.get_children():
		child.queue_free()
	if _draft == null:
		_status.text = "No structured source."
		_confirm.disabled = true
		_preview.text = ""
		return

	if _draft is FlowArrayValueSource:
		_build_array(_draft as FlowArrayValueSource)
	elif _draft is FlowDictionaryValueSource:
		_build_dictionary(_draft as FlowDictionaryValueSource)
	elif _draft is FlowResourceRefValueSource:
		_build_resource(_draft as FlowResourceRefValueSource)
	elif _draft is FlowEnumValueSource:
		_build_enum(_draft as FlowEnumValueSource)
	elif _draft is FlowBitfieldValueSource:
		_build_bitfield(_draft as FlowBitfieldValueSource)
	else:
		var unsupported: Label = Label.new()
		unsupported.text = "This source is not edited by FlowComplexValueEditor."
		_body.add_child(unsupported)

	_preview.text = "Preview: " + FlowValueSourcePreview.preview(_draft, _graph)
	_confirm.disabled = not can_confirm()
	_status.text = "Ready." if can_confirm() else "Complete the structured value before confirming."


func _build_array(source: FlowArrayValueSource) -> void:
	var heading: Label = Label.new()
	heading.text = "Array — %d elements" % source.elements.size()
	_body.add_child(heading)
	for index: int in source.elements.size():
		_body.add_child(_collection_value_row(
			source.elements[index],
			"[%d]" % index,
			_remove_array_element.bind(index),
			_replace_array_element.bind(index)
		))
	var actions: HBoxContainer = HBoxContainer.new()
	actions.add_child(_button("Add Scalar", _add_array_scalar))
	actions.add_child(_button("Add Array", _add_array_array))
	actions.add_child(_button("Add Dictionary", _add_array_dictionary))
	actions.add_child(_source_menu("Add Source…", _append_array_source))
	_body.add_child(actions)


func _build_dictionary(source: FlowDictionaryValueSource) -> void:
	var heading: Label = Label.new()
	heading.text = "Dictionary — %d entries" % source.entries.size()
	_body.add_child(heading)
	for index: int in source.entries.size():
		var entry: FlowDictionaryEntry = source.entries[index]
		var row: VBoxContainer = VBoxContainer.new()
		var top: HBoxContainer = HBoxContainer.new()
		var key_input: LineEdit = LineEdit.new()
		key_input.name = "DictionaryKey%d" % index
		key_input.placeholder_text = "String key"
		key_input.text = entry.key if entry != null else ""
		key_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		key_input.text_changed.connect(_on_dictionary_key_changed.bind(index))
		top.add_child(key_input)
		top.add_child(_button("Remove", _remove_dictionary_entry.bind(index)))
		row.add_child(top)
		row.add_child(_collection_value_row(
			entry.value_source if entry != null else null,
			"Value",
			_clear_dictionary_value.bind(index),
			_replace_dictionary_value.bind(index)
		))
		_body.add_child(row)
	var actions: HBoxContainer = HBoxContainer.new()
	actions.add_child(_button("Add Entry", _add_dictionary_entry))
	_body.add_child(actions)


func _build_resource(source: FlowResourceRefValueSource) -> void:
	var type_label: Label = Label.new()
	type_label.text = "Expected Resource class"
	_body.add_child(type_label)
	var type_input: LineEdit = LineEdit.new()
	type_input.name = &"ResourceTypeHint"
	type_input.text = String(source.resource_type_hint)
	type_input.text_changed.connect(_on_resource_type_changed)
	_body.add_child(type_input)

	var path_label: Label = Label.new()
	path_label.text = "Resource path"
	_body.add_child(path_label)
	var path_row: HBoxContainer = HBoxContainer.new()
	var path_input: LineEdit = LineEdit.new()
	path_input.name = &"ResourcePath"
	path_input.text = source.resource_path
	path_input.placeholder_text = "res://..."
	path_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	path_input.text_changed.connect(_on_resource_path_changed)
	path_row.add_child(path_input)
	path_row.add_child(_button("Browse…", _browse_resource))
	_body.add_child(path_row)


func _build_enum(source: FlowEnumValueSource) -> void:
	_build_named_int_header("Enum name", String(source.enum_name), _on_enum_name_changed)
	for index: int in source.option_names.size():
		_body.add_child(_named_int_option_row(
			String(source.option_names[index]),
			source.option_values[index],
			_remove_enum_option.bind(index),
			_on_enum_option_name_changed.bind(index),
			_on_enum_option_value_changed.bind(index)
		))
	_body.add_child(_button("Add Option", _add_enum_option))
	var selected_label: Label = Label.new()
	selected_label.text = "Selected option"
	_body.add_child(selected_label)
	var selected: OptionButton = OptionButton.new()
	selected.name = &"EnumSelectedValue"
	selected.add_item("[Select option...]")
	selected.set_item_metadata(0, null)
	var selected_index: int = 0
	for index: int in source.option_names.size():
		var item: int = selected.item_count
		selected.add_item("%s = %d" % [source.option_names[index], source.option_values[index]])
		selected.set_item_metadata(item, source.option_values[index])
		if source.has_selection and source.option_values[index] == source.selected_value:
			selected_index = item
	selected.select(selected_index)
	selected.item_selected.connect(_on_enum_selected.bind(selected))
	_body.add_child(selected)


func _build_bitfield(source: FlowBitfieldValueSource) -> void:
	_build_named_int_header(
		"Bitfield name",
		String(source.bitfield_name),
		_on_bitfield_name_changed
	)
	for index: int in source.option_names.size():
		var option_row: HBoxContainer = _named_int_option_row(
			String(source.option_names[index]),
			source.option_values[index],
			_remove_bitfield_option.bind(index),
			_on_bitfield_option_name_changed.bind(index),
			_on_bitfield_option_value_changed.bind(index)
		)
		var enabled: CheckBox = CheckBox.new()
		enabled.name = "BitfieldEnabled%d" % index
		enabled.text = "Enabled"
		var flag: int = source.option_values[index]
		enabled.button_pressed = flag > 0 and (source.selected_mask & flag) == flag
		enabled.toggled.connect(_on_bitfield_enabled.bind(index))
		option_row.add_child(enabled)
		_body.add_child(option_row)
	_body.add_child(_button("Add Flag", _add_bitfield_option))


func _collection_value_row(
		source: FlowValueSource,
		label_text: String,
		remove_action: Callable,
		replace_action: Callable
) -> Control:
	var row: HBoxContainer = HBoxContainer.new()
	var label: Label = Label.new()
	label.text = label_text
	label.custom_minimum_size.x = 70.0
	row.add_child(label)

	if source is FlowLiteralValueSource:
		var literal: FlowLiteralValueSource = source as FlowLiteralValueSource
		var type_menu: OptionButton = OptionButton.new()
		type_menu.add_item("[Select type...]")
		type_menu.set_item_metadata(0, int(Variant.Type.TYPE_NIL))
		var selected: int = 0
		for value_type: Variant.Type in CHILD_LITERAL_TYPES:
			var item: int = type_menu.item_count
			type_menu.add_item(FlowChipTypeDescriptor.variant_type_display_name(value_type))
			type_menu.set_item_metadata(item, int(value_type))
			if literal.get_value_type() == value_type:
				selected = item
		type_menu.select(selected)
		type_menu.item_selected.connect(
			_on_collection_literal_type_selected.bind(literal, type_menu)
		)
		row.add_child(type_menu)
		if literal.get_value_type() != Variant.Type.TYPE_NIL:
			var value_control: Control = _collection_literal_value_control(literal)
			if value_control != null:
				row.add_child(value_control)
	elif source != null:
		var preview: Label = Label.new()
		preview.text = FlowValueSourcePreview.preview(source, _graph)
		preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(preview)
		if _is_complex_source(source):
			row.add_child(_button("Edit", _open_nested_source.bind(source, replace_action)))
		elif source is FlowVariableRefValueSource:
			row.add_child(_button("Edit", _open_variable_source.bind(source, replace_action)))
		elif source is FlowOperationValueSource:
			row.add_child(_button("Edit", _open_operation_source.bind(source, replace_action)))
		elif source is FlowConditionValueSource:
			row.add_child(_button("Edit", _open_condition_source.bind(source, replace_action)))
	else:
		var missing: Label = Label.new()
		missing.text = "<unset>"
		missing.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(missing)

	if source == null or not source is FlowLiteralValueSource:
		var scalar: Button = _button(
			"Scalar",
			_replace_with_scalar.bind(replace_action)
		)
		row.add_child(scalar)
	row.add_child(_source_menu("Change…", replace_action))
	if remove_action.is_valid():
		row.add_child(_button("Remove", remove_action))
	return row


func _replace_with_scalar(replace_action: Callable) -> void:
	if replace_action.is_valid():
		replace_action.call(FlowLiteralValueSource.new())


func _source_menu(label_text: String, replace_action: Callable) -> MenuButton:
	var button: MenuButton = MenuButton.new()
	button.text = label_text
	var popup: PopupMenu = button.get_popup()
	popup.add_item("Scalar", CHILD_SOURCE_SCALAR)
	popup.add_item("Variable", CHILD_SOURCE_VARIABLE)
	popup.add_item("Operation", CHILD_SOURCE_OPERATION)
	popup.add_item("Condition", CHILD_SOURCE_CONDITION)
	popup.add_separator()
	popup.add_item("Array", CHILD_SOURCE_ARRAY)
	popup.add_item("Dictionary", CHILD_SOURCE_DICTIONARY)
	popup.add_item("Resource", CHILD_SOURCE_RESOURCE)
	popup.add_item("Enum", CHILD_SOURCE_ENUM)
	popup.add_item("Bitfield", CHILD_SOURCE_BITFIELD)
	var variable_index: int = popup.get_item_index(CHILD_SOURCE_VARIABLE)
	if variable_index >= 0:
		popup.set_item_disabled(
			variable_index,
			_graph == null or _graph.variables.is_empty()
		)
	if _nesting_depth >= MAX_EDITOR_NESTING_DEPTH:
		for item_id: int in [CHILD_SOURCE_ARRAY, CHILD_SOURCE_DICTIONARY]:
			var item_index: int = popup.get_item_index(item_id)
			if item_index >= 0:
				popup.set_item_disabled(item_index, true)
	popup.id_pressed.connect(
		_on_collection_source_selected.bind(replace_action, button)
	)
	return button


func _on_collection_source_selected(
		item_id: int,
		replace_action: Callable,
		anchor: Control
) -> void:
	if not replace_action.is_valid():
		return
	match item_id:
		CHILD_SOURCE_SCALAR:
			replace_action.call(FlowLiteralValueSource.new())
			_rebuild()
		CHILD_SOURCE_VARIABLE:
			_open_variable_source(null, replace_action, anchor)
		CHILD_SOURCE_OPERATION:
			_open_operation_source(null, replace_action, anchor)
		CHILD_SOURCE_CONDITION:
			_open_condition_source(null, replace_action, anchor)
		CHILD_SOURCE_ARRAY:
			_open_new_complex_source(FlowArrayValueSource.new(), replace_action, anchor)
		CHILD_SOURCE_DICTIONARY:
			_open_new_complex_source(FlowDictionaryValueSource.new(), replace_action, anchor)
		CHILD_SOURCE_RESOURCE:
			_open_new_complex_source(
				FlowResourceRefValueSource.placeholder(&"Resource"),
				replace_action,
				anchor
			)
		CHILD_SOURCE_ENUM:
			_open_new_complex_source(FlowEnumValueSource.new(), replace_action, anchor)
		CHILD_SOURCE_BITFIELD:
			_open_new_complex_source(FlowBitfieldValueSource.new(), replace_action, anchor)


func _open_new_complex_source(
		source: FlowValueSource,
		replace_action: Callable,
		anchor: Control = null
) -> void:
	_nested_replace = replace_action
	var child_context: Dictionary = _context.duplicate()
	child_context["complex_nesting_depth"] = _nesting_depth + 1
	_ensure_nested_editor().open_for_source(
		source,
		_graph,
		anchor.get_global_rect() if is_instance_valid(anchor) else get_global_rect(),
		child_context
	)


func _open_variable_source(
		source: FlowValueSource,
		replace_action: Callable,
		anchor: Control = null
) -> void:
	if _graph == null or _graph.variables.is_empty():
		return
	_pending_replace = replace_action
	var context: Dictionary = {}
	if source is FlowVariableRefValueSource:
		context["current_variable_id"] = 			(source as FlowVariableRefValueSource).variable_id
	_variable_selector.open_for_variables(
		_graph.variables,
		anchor.get_global_rect() if is_instance_valid(anchor) else get_global_rect(),
		"",
		context
	)


func _open_operation_source(
		source: FlowValueSource,
		replace_action: Callable,
		anchor: Control = null
) -> void:
	_pending_replace = replace_action
	var operation: FlowOperationValueSource = source as FlowOperationValueSource
	var context: Dictionary = _context.duplicate()
	context["operation_nesting_depth"] = 		int(context.get("operation_nesting_depth", 0)) + 1
	_operation_editor.open_for_operation(
		operation,
		_graph,
		anchor.get_global_rect() if is_instance_valid(anchor) else get_global_rect(),
		context
	)


func _open_condition_source(
		source: FlowValueSource,
		replace_action: Callable,
		anchor: Control = null
) -> void:
	_pending_replace = replace_action
	_condition_editor.open_for_condition(
		source as FlowConditionValueSource,
		_graph,
		anchor.get_global_rect() if is_instance_valid(anchor) else get_global_rect(),
		_context
	)


func _on_nested_variable_selected(variable_id: String) -> void:
	if not _pending_replace.is_valid() or _graph == null:
		_pending_replace = Callable()
		return
	for variable: FlowVariableDefinition in _graph.variables:
		if variable != null and variable.get_internal_id() == variable_id:
			_pending_replace.call(
				FlowVariableRefValueSource.new(variable_id, variable.value_type)
			)
			break
	_pending_replace = Callable()
	_rebuild()


func _on_nested_operation_confirmed(source: FlowOperationValueSource) -> void:
	if _pending_replace.is_valid():
		_pending_replace.call(source)
	_pending_replace = Callable()
	_rebuild()


func _on_nested_condition_confirmed(source: FlowConditionValueSource) -> void:
	if _pending_replace.is_valid():
		_pending_replace.call(source)
	_pending_replace = Callable()
	_rebuild()


func _collection_literal_value_control(source: FlowLiteralValueSource) -> Control:
	match source.get_value_type():
		Variant.Type.TYPE_BOOL:
			var toggle: CheckBox = CheckBox.new()
			toggle.button_pressed = bool(source.value)
			toggle.toggled.connect(_on_collection_bool_changed.bind(source))
			return toggle
		Variant.Type.TYPE_INT, Variant.Type.TYPE_FLOAT:
			var spin: SpinBox = SpinBox.new()
			spin.allow_greater = true
			spin.allow_lesser = true
			spin.step = 1.0 if source.get_value_type() == Variant.Type.TYPE_INT else 0.01
			spin.rounded = source.get_value_type() == Variant.Type.TYPE_INT
			spin.value = float(source.value)
			spin.value_changed.connect(_on_collection_number_changed.bind(source))
			return spin
		Variant.Type.TYPE_STRING:
			var input: LineEdit = LineEdit.new()
			input.text = String(source.value)
			input.text_changed.connect(_on_collection_string_changed.bind(source))
			return input
	return null


func _build_named_int_header(
		label_text: String,
		current: String,
		changed: Callable
) -> void:
	var label: Label = Label.new()
	label.text = label_text
	_body.add_child(label)
	var input: LineEdit = LineEdit.new()
	input.text = current
	input.text_changed.connect(changed)
	_body.add_child(input)


func _named_int_option_row(
		option_name: String,
		option_value: int,
		remove_action: Callable,
		name_changed: Callable,
		value_changed: Callable
) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	var name_input: LineEdit = LineEdit.new()
	name_input.text = option_name
	name_input.placeholder_text = "Name"
	name_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_input.text_changed.connect(name_changed)
	row.add_child(name_input)
	var value_input: SpinBox = SpinBox.new()
	value_input.allow_greater = true
	value_input.allow_lesser = true
	value_input.rounded = true
	value_input.step = 1.0
	value_input.value = option_value
	value_input.value_changed.connect(value_changed)
	row.add_child(value_input)
	row.add_child(_button("Remove", remove_action))
	return row


func _button(text_value: String, action: Callable) -> Button:
	var button: Button = Button.new()
	button.text = text_value
	button.pressed.connect(action)
	return button


func _is_complex_source(source: FlowValueSource) -> bool:
	return source is FlowArrayValueSource 		or source is FlowDictionaryValueSource 		or source is FlowResourceRefValueSource 		or source is FlowEnumValueSource 		or source is FlowBitfieldValueSource


func _ensure_nested_editor() -> FlowComplexValueEditor:
	if is_instance_valid(_nested_editor):
		return _nested_editor
	_nested_editor = FlowComplexValueEditor.new()
	_nested_editor.name = &"NestedComplexValueEditor"
	_nested_editor.source_confirmed.connect(_on_nested_source_confirmed)
	_nested_editor.cancelled.connect(_on_nested_source_cancelled)
	add_child(_nested_editor)
	return _nested_editor


func _open_nested_source(source: FlowValueSource, replace_action: Callable) -> void:
	_nested_replace = replace_action
	var child_context: Dictionary = _context.duplicate()
	child_context["complex_nesting_depth"] = _nesting_depth + 1
	_ensure_nested_editor().open_for_source(
		source,
		_graph,
		get_global_rect(),
		child_context
	)


func _on_nested_source_confirmed(source: FlowValueSource) -> void:
	if _nested_replace.is_valid():
		_nested_replace.call(source)
	_nested_replace = Callable()
	_rebuild()


func _on_nested_source_cancelled() -> void:
	_nested_replace = Callable()
	_pending_replace = Callable()


func _add_array_scalar() -> void:
	var source: FlowArrayValueSource = _draft as FlowArrayValueSource
	source.elements.append(FlowLiteralValueSource.new())
	_rebuild()


func _add_array_array() -> void:
	var source: FlowArrayValueSource = _draft as FlowArrayValueSource
	source.elements.append(FlowArrayValueSource.new())
	_rebuild()


func _add_array_dictionary() -> void:
	var source: FlowArrayValueSource = _draft as FlowArrayValueSource
	source.elements.append(FlowDictionaryValueSource.new())
	_rebuild()


func _append_array_source(source: FlowValueSource) -> void:
	var array: FlowArrayValueSource = _draft as FlowArrayValueSource
	if array == null or source == null:
		return
	array.elements.append(source)
	_rebuild()


func _remove_array_element(index: int) -> void:
	var source: FlowArrayValueSource = _draft as FlowArrayValueSource
	if source != null and index >= 0 and index < source.elements.size():
		source.elements.remove_at(index)
		_rebuild()


func _replace_array_element(source: FlowValueSource, index: int) -> void:
	var array: FlowArrayValueSource = _draft as FlowArrayValueSource
	if array == null or index < 0 or index >= array.elements.size():
		return
	var old: FlowValueSource = array.elements[index]
	if old != null and source != null:
		source.source_id = old.source_id
	array.elements[index] = source
	_rebuild()


func _add_dictionary_entry() -> void:
	var source: FlowDictionaryValueSource = _draft as FlowDictionaryValueSource
	source.entries.append(FlowDictionaryEntry.new("", FlowLiteralValueSource.new()))
	_rebuild()


func _remove_dictionary_entry(index: int) -> void:
	var source: FlowDictionaryValueSource = _draft as FlowDictionaryValueSource
	if source != null and index >= 0 and index < source.entries.size():
		source.entries.remove_at(index)
		_rebuild()


func _clear_dictionary_value(index: int) -> void:
	var source: FlowDictionaryValueSource = _draft as FlowDictionaryValueSource
	if source != null and index >= 0 and index < source.entries.size():
		source.entries[index].value_source = null
		_rebuild()


func _replace_dictionary_value(source: FlowValueSource, index: int) -> void:
	var dictionary: FlowDictionaryValueSource = _draft as FlowDictionaryValueSource
	if dictionary == null or index < 0 or index >= dictionary.entries.size():
		return
	var old: FlowValueSource = dictionary.entries[index].value_source
	if old != null and source != null:
		source.source_id = old.source_id
	dictionary.entries[index].value_source = source
	_rebuild()


func _on_dictionary_key_changed(value: String, index: int) -> void:
	var source: FlowDictionaryValueSource = _draft as FlowDictionaryValueSource
	if source != null and index >= 0 and index < source.entries.size():
		source.entries[index].key = value
		_refresh_preview_and_confirm()


func _on_collection_literal_type_selected(
		index: int,
		source: FlowLiteralValueSource,
		menu: OptionButton
) -> void:
	if index < 0 or index >= menu.item_count:
		return
	var value_type: Variant.Type = int(menu.get_item_metadata(index)) as Variant.Type
	source.value_type = value_type
	source.value = FlowChipTypeDescriptor.default_value_for_type(value_type) 		if value_type != Variant.Type.TYPE_NIL else null
	_rebuild()


func _on_collection_bool_changed(value: bool, source: FlowLiteralValueSource) -> void:
	source.value = value
	_refresh_preview_and_confirm()


func _on_collection_number_changed(value: float, source: FlowLiteralValueSource) -> void:
	source.value = int(value) 		if source.get_value_type() == Variant.Type.TYPE_INT else value
	_refresh_preview_and_confirm()


func _on_collection_string_changed(value: String, source: FlowLiteralValueSource) -> void:
	source.value = value
	_refresh_preview_and_confirm()


func _on_resource_type_changed(value: String) -> void:
	var source: FlowResourceRefValueSource = _draft as FlowResourceRefValueSource
	if source != null:
		source.resource_type_hint = StringName(value)
		_refresh_preview_and_confirm()


func _on_resource_path_changed(value: String) -> void:
	var source: FlowResourceRefValueSource = _draft as FlowResourceRefValueSource
	if source != null:
		source.resource_path = value
		_refresh_preview_and_confirm()


func _browse_resource() -> void:
	if _resource_dialog != null:
		_resource_dialog.popup_centered_ratio(0.75)


func _on_resource_file_selected(path: String) -> void:
	var source: FlowResourceRefValueSource = _draft as FlowResourceRefValueSource
	if source != null:
		source.resource_path = path
		_rebuild()


func _add_enum_option() -> void:
	var source: FlowEnumValueSource = _draft as FlowEnumValueSource
	source.option_names.append(&"")
	source.option_values.append(0)
	_rebuild()


func _remove_enum_option(index: int) -> void:
	var source: FlowEnumValueSource = _draft as FlowEnumValueSource
	if source != null and index >= 0 and index < source.option_names.size():
		source.option_names.remove_at(index)
		source.option_values.remove_at(index)
		_rebuild()


func _on_enum_name_changed(value: String) -> void:
	var source: FlowEnumValueSource = _draft as FlowEnumValueSource
	if source != null:
		source.enum_name = StringName(value)
		_refresh_preview_and_confirm()


func _on_enum_option_name_changed(value: String, index: int) -> void:
	var source: FlowEnumValueSource = _draft as FlowEnumValueSource
	if source != null and index >= 0 and index < source.option_names.size():
		source.option_names[index] = StringName(value)
		_refresh_preview_and_confirm()


func _on_enum_option_value_changed(value: float, index: int) -> void:
	var source: FlowEnumValueSource = _draft as FlowEnumValueSource
	if source != null and index >= 0 and index < source.option_values.size():
		source.option_values[index] = int(value)
		_rebuild()


func _on_enum_selected(index: int, menu: OptionButton) -> void:
	if index <= 0 or index >= menu.item_count:
		return
	var source: FlowEnumValueSource = _draft as FlowEnumValueSource
	if source != null:
		source.selected_value = int(menu.get_item_metadata(index))
		source.has_selection = true
		_refresh_preview_and_confirm()


func _add_bitfield_option() -> void:
	var source: FlowBitfieldValueSource = _draft as FlowBitfieldValueSource
	source.option_names.append(&"")
	source.option_values.append(0)
	_rebuild()


func _remove_bitfield_option(index: int) -> void:
	var source: FlowBitfieldValueSource = _draft as FlowBitfieldValueSource
	if source != null and index >= 0 and index < source.option_names.size():
		source.option_names.remove_at(index)
		source.option_values.remove_at(index)
		_rebuild()


func _on_bitfield_name_changed(value: String) -> void:
	var source: FlowBitfieldValueSource = _draft as FlowBitfieldValueSource
	if source != null:
		source.bitfield_name = StringName(value)
		_refresh_preview_and_confirm()


func _on_bitfield_option_name_changed(value: String, index: int) -> void:
	var source: FlowBitfieldValueSource = _draft as FlowBitfieldValueSource
	if source != null and index >= 0 and index < source.option_names.size():
		source.option_names[index] = StringName(value)
		_refresh_preview_and_confirm()


func _on_bitfield_option_value_changed(value: float, index: int) -> void:
	var source: FlowBitfieldValueSource = _draft as FlowBitfieldValueSource
	if source != null and index >= 0 and index < source.option_values.size():
		var old_flag: int = source.option_values[index]
		var enabled: bool = old_flag > 0 and (source.selected_mask & old_flag) == old_flag
		if enabled:
			source.selected_mask &= ~old_flag
		source.option_values[index] = int(value)
		if enabled and int(value) > 0:
			source.selected_mask |= int(value)
		_rebuild()


func _on_bitfield_enabled(enabled: bool, index: int) -> void:
	var source: FlowBitfieldValueSource = _draft as FlowBitfieldValueSource
	if source == null or index < 0 or index >= source.option_values.size():
		return
	var flag: int = source.option_values[index]
	if flag <= 0:
		return
	if enabled:
		source.selected_mask |= flag
	else:
		source.selected_mask &= ~flag
	_refresh_preview_and_confirm()


func _refresh_preview_and_confirm() -> void:
	if _preview != null and _draft != null:
		_preview.text = "Preview: " + FlowValueSourcePreview.preview(_draft, _graph)
	if _confirm != null:
		_confirm.disabled = not can_confirm()
	if _status != null:
		_status.text = "Ready." if can_confirm() else "Complete the structured value before confirming."


func _confirm_draft() -> void:
	if not can_confirm():
		_refresh_preview_and_confirm()
		return
	_closing_for_action = true
	source_confirmed.emit(_draft.duplicate_with_new_id())
	hide()


func _cancel() -> void:
	if is_instance_valid(_nested_editor) and _nested_editor.visible:
		_nested_editor.hide()
	if is_instance_valid(_variable_selector) and _variable_selector.visible:
		_variable_selector.hide()
	if is_instance_valid(_operation_editor) and _operation_editor.visible:
		_operation_editor.hide()
	if is_instance_valid(_condition_editor) and _condition_editor.visible:
		_condition_editor.hide()
	_nested_replace = Callable()
	_pending_replace = Callable()
	_closing_for_action = false
	hide()


func _on_popup_hide() -> void:
	if not _closing_for_action:
		cancelled.emit()
	_closing_for_action = false
