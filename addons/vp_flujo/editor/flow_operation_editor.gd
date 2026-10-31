@tool
## Structured editor for a detached Operation Tok draft.
class_name FlowOperationEditor
extends PopupPanel


signal operation_confirmed(source: FlowOperationValueSource)
signal cancelled


var _draft: FlowOperationValueSource
var _graph: FlowGraph
var _schema: FlowChipFieldSchema
var _context: Dictionary = {}
var _operator_menu: OptionButton
var _rows_box: VBoxContainer
var _rows: Array[Dictionary] = []
var _preview_label: Label
var _feedback_label: Label
var _confirm_button: Button
var _variable_selector: FlowVariableSelector
var _variable_operand_index: int = -1
var _invalid_literal_inputs: Dictionary = {}
var _closing_for_action: bool = false


func _init() -> void:
	auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	name = &"FlowOperationEditor"
	min_size = Vector2i(560, 300)
	size = Vector2i(640, 430)
	close_requested.connect(_cancel)
	popup_hide.connect(_on_popup_hide)

	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override(&"margin_left", 14)
	margin.add_theme_constant_override(&"margin_top", 12)
	margin.add_theme_constant_override(&"margin_right", 14)
	margin.add_theme_constant_override(&"margin_bottom", 12)
	add_child(margin)

	var content: VBoxContainer = VBoxContainer.new()
	content.add_theme_constant_override(&"separation", 8)
	margin.add_child(content)

	var heading: Label = Label.new()
	heading.text = "Build Operation"
	heading.add_theme_font_size_override(&"font_size", 16)
	content.add_child(heading)

	_operator_menu = OptionButton.new()
	_operator_menu.name = &"OperationOperator"
	_operator_menu.focus_mode = Control.FOCUS_ALL
	_operator_menu.custom_minimum_size.y = 36.0
	_operator_menu.item_selected.connect(_on_operator_selected)
	content.add_child(_operator_menu)

	_rows_box = VBoxContainer.new()
	_rows_box.name = &"OperationOperands"
	_rows_box.add_theme_constant_override(&"separation", 6)
	content.add_child(_rows_box)

	var preview_heading: Label = Label.new()
	preview_heading.text = "Preview"
	content.add_child(preview_heading)

	_preview_label = Label.new()
	_preview_label.name = &"OperationPreview"
	_preview_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_preview_label.custom_minimum_size.y = 34.0
	content.add_child(_preview_label)

	_feedback_label = Label.new()
	_feedback_label.name = &"OperationFeedback"
	_feedback_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(_feedback_label)

	var actions: HBoxContainer = HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_END
	var cancel_button: Button = Button.new()
	cancel_button.name = &"CancelOperation"
	cancel_button.text = "Cancel"
	cancel_button.focus_mode = Control.FOCUS_ALL
	cancel_button.pressed.connect(_cancel)
	actions.add_child(cancel_button)
	_confirm_button = Button.new()
	_confirm_button.name = &"ConfirmOperation"
	_confirm_button.text = "Confirm"
	_confirm_button.focus_mode = Control.FOCUS_ALL
	_confirm_button.pressed.connect(_confirm)
	actions.add_child(_confirm_button)
	content.add_child(actions)

	_variable_selector = FlowVariableSelector.new()
	_variable_selector.variable_selected.connect(_on_variable_selected)
	_variable_selector.cancelled.connect(_on_variable_selector_cancelled)
	add_child(_variable_selector)


func open_for_operation(
		source: FlowOperationValueSource,
		graph: FlowGraph,
		anchor_rect: Rect2,
		context: Dictionary = {}
) -> void:
	_graph = graph
	_context = context.duplicate()
	_schema = _context.get("schema", null) as FlowChipFieldSchema
	if source != null:
		_draft = source.duplicate(true) as FlowOperationValueSource
	else:
		_draft = FlowOperationValueSource.new(&"", [null, null])
	_invalid_literal_inputs.clear()
	_variable_operand_index = -1
	_closing_for_action = false
	_rebuild()
	position = Vector2i(anchor_rect.position)
	popup()
	call_deferred(&"_focus_default")


func get_draft() -> FlowOperationValueSource:
	return _draft


func set_draft(source: FlowOperationValueSource) -> void:
	_draft = source.duplicate_with_new_id() as FlowOperationValueSource 		if source != null else FlowOperationValueSource.new(&"", [null, null])
	_invalid_literal_inputs.clear()
	_rebuild()


func can_confirm() -> bool:
	return _draft != null and _validation_message().is_empty()


func _rebuild() -> void:
	_rebuild_operator_menu()
	_rebuild_rows()
	_update_preview()


func _rebuild_operator_menu() -> void:
	_operator_menu.clear()
	_operator_menu.add_item("Select operation...")
	_operator_menu.set_item_metadata(0, &"")
	var selected: int = 0
	for operator_id: StringName in FlowOperationOperatorCatalog.operator_ids():
		var index: int = _operator_menu.item_count
		_operator_menu.add_item(
			FlowOperationOperatorCatalog.display_label(operator_id)
			+ " (" + FlowOperationOperatorCatalog.symbol(operator_id) + ")"
		)
		_operator_menu.set_item_metadata(index, operator_id)
		if _draft != null and operator_id == _draft.operator_id:
			selected = index
	_operator_menu.select(selected)


func _rebuild_rows() -> void:
	_rows.clear()
	for child: Node in _rows_box.get_children():
		_rows_box.remove_child(child)
		child.queue_free()
	if _draft == null:
		return
	while _draft.operands.size() < 2:
		_draft.operands.append(null)
	for index: int in 2:
		var row: VBoxContainer = VBoxContainer.new()
		row.name = "Operand%d" % index
		var title: Label = Label.new()
		title.text = "Operand %s" % ("A" if index == 0 else "B")
		row.add_child(title)
		var line: HBoxContainer = HBoxContainer.new()
		row.add_child(line)

		var kind: OptionButton = OptionButton.new()
		kind.name = "Operand%dSourceKind" % index
		kind.focus_mode = Control.FOCUS_ALL
		kind.custom_minimum_size = Vector2(110.0, 36.0)
		kind.add_item("Select source...")
		kind.set_item_metadata(0, &"")
		kind.add_item("Variable")
		kind.set_item_metadata(1, FlowValueSource.SOURCE_KIND_VARIABLE_REF)
		kind.add_item("Literal")
		kind.set_item_metadata(2, FlowValueSource.SOURCE_KIND_LITERAL)
		var source: FlowValueSource = _draft.operands[index]
		if source is FlowVariableRefValueSource:
			kind.select(1)
		elif source is FlowLiteralValueSource:
			kind.select(2)
		else:
			kind.select(0)
		kind.item_selected.connect(_on_kind_selected.bind(index))
		line.add_child(kind)

		var choose: Button = null
		var badge: Label = null
		var type_menu: OptionButton = null
		var value_control: Control = null
		if source is FlowVariableRefValueSource:
			var variable_source: FlowVariableRefValueSource = source as FlowVariableRefValueSource
			choose = Button.new()
			choose.name = "Operand%dChooseVariable" % index
			choose.text = _variable_button_text(variable_source)
			choose.custom_minimum_size = Vector2(145.0, 36.0)
			choose.focus_mode = Control.FOCUS_ALL
			choose.pressed.connect(_open_variable_selector.bind(index, choose))
			line.add_child(choose)
			if not variable_source.variable_id.is_empty():
				badge = Label.new()
				badge.name = "Operand%dTypeBadge" % index
				var derived_type: Variant.Type = variable_source.get_value_type()
				if _graph != null:
					var definition: FlowVariableDefinition = variable_source.resolve_definition(_graph)
					if definition != null:
						derived_type = definition.get_declared_variant_type()
				badge.text = FlowChipTypeDescriptor.variant_type_display_name(derived_type)
				badge.tooltip_text = "Type comes from FlowGraph.variables"
				line.add_child(badge)
		elif source is FlowLiteralValueSource:
			var literal: FlowLiteralValueSource = source as FlowLiteralValueSource
			type_menu = OptionButton.new()
			type_menu.name = "Operand%dType" % index
			type_menu.focus_mode = Control.FOCUS_ALL
			type_menu.custom_minimum_size = Vector2(105.0, 36.0)
			type_menu.add_item("Select type...")
			type_menu.set_item_metadata(0, int(Variant.Type.TYPE_NIL))
			var current_type: Variant.Type = literal.get_value_type()
			for candidate: Variant.Type in _types_for_operand(index):
				var item: int = type_menu.item_count
				type_menu.add_item(FlowChipTypeDescriptor.variant_type_display_name(candidate))
				type_menu.set_item_metadata(item, int(candidate))
				if candidate == current_type:
					type_menu.select(item)
			if current_type == Variant.Type.TYPE_NIL:
				type_menu.select(0)
			type_menu.item_selected.connect(_on_type_selected.bind(index))
			line.add_child(type_menu)
			if FlowLiteralValueSource.is_allowed_type(current_type):
				value_control = _make_literal_editor(index, literal, current_type)
				if value_control != null:
					row.add_child(value_control)

		_rows_box.add_child(row)
		_rows.append({
			"container": row,
			"kind": kind,
			"choose": choose,
			"badge": badge,
			"type": type_menu,
			"value": value_control,
		})
	_refresh_operator_compatibility()


func _make_literal_editor(
		operand_index: int,
		literal: FlowLiteralValueSource,
		value_type: Variant.Type
) -> Control:
	match value_type:
		Variant.Type.TYPE_BOOL:
			var menu: OptionButton = OptionButton.new()
			menu.name = "Operand%dBoolValue" % operand_index
			menu.add_item("Select value...")
			menu.set_item_metadata(0, null)
			menu.add_item("true")
			menu.set_item_metadata(1, true)
			menu.add_item("false")
			menu.set_item_metadata(2, false)
			if literal != null and literal.is_valid():
				menu.select(1 if bool(literal.get_value()) else 2)
			menu.item_selected.connect(_on_bool_selected.bind(operand_index))
			return menu
		Variant.Type.TYPE_INT, Variant.Type.TYPE_FLOAT, Variant.Type.TYPE_STRING:
			var input: LineEdit = LineEdit.new()
			input.name = "Operand%dValue" % operand_index
			input.custom_minimum_size = Vector2(150.0, 36.0)
			input.placeholder_text = _literal_placeholder(value_type)
			input.text = _literal_text(literal, value_type)
			input.text_changed.connect(_on_text_literal_changed.bind(operand_index, value_type))
			return input
		Variant.Type.TYPE_VECTOR2, Variant.Type.TYPE_VECTOR2I:
			return _make_vector_editor(operand_index, literal, value_type, 2)
		Variant.Type.TYPE_VECTOR3, Variant.Type.TYPE_VECTOR3I:
			return _make_vector_editor(operand_index, literal, value_type, 3)
	return null


func _make_vector_editor(
		operand_index: int,
		literal: FlowLiteralValueSource,
		value_type: Variant.Type,
		dimensions: int
) -> Control:
	var box: HBoxContainer = HBoxContainer.new()
	box.name = "Operand%dVectorValue" % operand_index
	var values: Array[String] = []
	if literal != null and literal.is_valid():
		var value: Variant = literal.get_value()
		if value_type == Variant.Type.TYPE_VECTOR2:
			values = [str(value.x), str(value.y)]
		elif value_type == Variant.Type.TYPE_VECTOR2I:
			values = [str(value.x), str(value.y)]
		elif value_type == Variant.Type.TYPE_VECTOR3:
			values = [str(value.x), str(value.y), str(value.z)]
		elif value_type == Variant.Type.TYPE_VECTOR3I:
			values = [str(value.x), str(value.y), str(value.z)]
	for component: int in dimensions:
		var input: LineEdit = LineEdit.new()
		input.name = "Component%d" % component
		input.custom_minimum_size = Vector2(80.0, 36.0)
		input.placeholder_text = ["X", "Y", "Z"][component]
		if component < values.size():
			input.text = values[component]
		input.text_changed.connect(
			_on_vector_component_changed.bind(operand_index, value_type, box)
		)
		box.add_child(input)
	return box


func _types_for_operand(index: int) -> Array[Variant.Type]:
	var result: Array[Variant.Type] = []
	var operator_id: StringName = _draft.operator_id if _draft != null else &""
	var descriptors: Array[Dictionary] = []
	if operator_id.is_empty():
		for candidate_id: StringName in FlowOperationOperatorCatalog.operator_ids():
			descriptors.append_array(FlowOperationOperatorCatalog.get_signatures(candidate_id))
	else:
		descriptors = FlowOperationOperatorCatalog.get_signatures(operator_id)
	for signature: Dictionary in descriptors:
		var types: Array = signature.get("operand_types", []) as Array
		if index >= types.size():
			continue
		var candidate: Variant.Type = int(types[index])
		if not result.has(candidate):
			result.append(candidate)
	return result


func _on_operator_selected(selected: int) -> void:
	if _draft == null:
		return
	_draft.operator_id = StringName(_operator_menu.get_item_metadata(selected))
	_rebuild_rows()
	_update_preview()


func _on_kind_selected(_selected: int, operand_index: int) -> void:
	if _draft == null or operand_index < 0 or operand_index >= _draft.operands.size():
		return
	var kind: OptionButton = _rows[operand_index]["kind"] as OptionButton
	var source_kind: StringName = StringName(kind.get_item_metadata(kind.selected))
	if source_kind == FlowValueSource.SOURCE_KIND_VARIABLE_REF:
		_draft.operands[operand_index] = FlowVariableRefValueSource.new()
	elif source_kind == FlowValueSource.SOURCE_KIND_LITERAL:
		_draft.operands[operand_index] = FlowLiteralValueSource.new()
	else:
		_draft.operands[operand_index] = null
	_rebuild_rows()
	_update_preview()


func _on_type_selected(selected: int, operand_index: int) -> void:
	if _draft == null or selected <= 0:
		return
	var menu: OptionButton = _rows[operand_index]["type"] as OptionButton
	var value_type: Variant.Type = int(menu.get_item_metadata(selected))
	var current: FlowValueSource = _draft.operands[operand_index]
	var next: FlowLiteralValueSource = FlowLiteralValueSource.new(value_type, null)
	if current is FlowLiteralValueSource 			and current.get_value_type() == value_type 			and current.is_valid():
		next = FlowLiteralValueSource.new(value_type, current.get_value())
	_draft.operands[operand_index] = next
	_invalid_literal_inputs[operand_index] = true
	_rebuild_rows()
	_update_preview()


func _on_text_literal_changed(
		text: String,
		operand_index: int,
		value_type: Variant.Type
) -> void:
	var parsed: Variant = null
	var valid: bool = true
	match value_type:
		Variant.Type.TYPE_INT:
			valid = text.is_valid_int()
			if valid:
				parsed = int(text)
		Variant.Type.TYPE_FLOAT:
			valid = text.is_valid_float()
			if valid:
				parsed = float(text)
		Variant.Type.TYPE_STRING:
			parsed = text
	if valid:
		_draft.operands[operand_index] = FlowLiteralValueSource.new(value_type, parsed)
		_invalid_literal_inputs.erase(operand_index)
	else:
		_invalid_literal_inputs[operand_index] = true
	_update_preview()


func _on_bool_selected(selected: int, operand_index: int) -> void:
	if selected <= 0:
		_invalid_literal_inputs[operand_index] = true
		_update_preview()
		return
	var menu: OptionButton = _rows[operand_index]["value"] as OptionButton
	_draft.operands[operand_index] = FlowLiteralValueSource.new(
		Variant.Type.TYPE_BOOL,
		bool(menu.get_item_metadata(selected))
	)
	_invalid_literal_inputs.erase(operand_index)
	_update_preview()


func _on_vector_component_changed(
		_text: String,
		operand_index: int,
		value_type: Variant.Type,
		box: HBoxContainer
) -> void:
	var values: Array[float] = []
	for child: Node in box.get_children():
		var input: LineEdit = child as LineEdit
		if input == null:
			continue
		var integer_type: bool = value_type == Variant.Type.TYPE_VECTOR2I 			or value_type == Variant.Type.TYPE_VECTOR3I
		if integer_type and not input.text.is_valid_int():
			_invalid_literal_inputs[operand_index] = true
			_update_preview()
			return
		if not integer_type and not input.text.is_valid_float():
			_invalid_literal_inputs[operand_index] = true
			_update_preview()
			return
		values.append(float(input.text))
	var parsed: Variant
	match value_type:
		Variant.Type.TYPE_VECTOR2:
			parsed = Vector2(values[0], values[1])
		Variant.Type.TYPE_VECTOR2I:
			parsed = Vector2i(int(values[0]), int(values[1]))
		Variant.Type.TYPE_VECTOR3:
			parsed = Vector3(values[0], values[1], values[2])
		Variant.Type.TYPE_VECTOR3I:
			parsed = Vector3i(int(values[0]), int(values[1]), int(values[2]))
	_draft.operands[operand_index] = FlowLiteralValueSource.new(value_type, parsed)
	_invalid_literal_inputs.erase(operand_index)
	_update_preview()


func _open_variable_selector(operand_index: int, button: Button) -> void:
	if _graph == null or _draft == null:
		return
	_variable_operand_index = operand_index
	var allowed: Array[Variant.Type] = _types_for_operand(operand_index)
	var candidates: Array[FlowVariableDefinition] = []
	for variable: FlowVariableDefinition in _graph.variables:
		if variable != null and allowed.has(variable.get_declared_variant_type()):
			candidates.append(variable)
	var current: FlowVariableRefValueSource = 		_draft.operands[operand_index] as FlowVariableRefValueSource
	_variable_selector.open_for_variables(
		candidates,
		button.get_global_rect(),
		"",
		{
			"accepted_value_types": allowed,
			"current_variable_id": current.variable_id if current != null else "",
		}
	)


func _on_variable_selected(variable_id: String) -> void:
	if _graph == null or _draft == null or _variable_operand_index < 0:
		return
	for variable: FlowVariableDefinition in _graph.variables:
		if variable == null or variable.get_internal_id() != variable_id:
			continue
		var current: FlowVariableRefValueSource = 			_draft.operands[_variable_operand_index] as FlowVariableRefValueSource
		var next: FlowVariableRefValueSource = FlowVariableRefValueSource.new(
			variable_id,
			variable.value_type
		)
		if current != null:
			next.source_id = current.source_id
		_draft.operands[_variable_operand_index] = next
		_variable_operand_index = -1
		_rebuild_rows()
		_update_preview()
		return


func _on_variable_selector_cancelled() -> void:
	_variable_operand_index = -1


func _refresh_operator_compatibility() -> void:
	if _operator_menu == null or _draft == null:
		return
	var left: FlowValueSource = _draft.operands[0] if _draft.operands.size() > 0 else null
	var right: FlowValueSource = _draft.operands[1] if _draft.operands.size() > 1 else null
	if left == null or right == null 			or left.get_value_type() == Variant.Type.TYPE_NIL 			or right.get_value_type() == Variant.Type.TYPE_NIL:
		for index: int in range(1, _operator_menu.item_count):
			_operator_menu.set_item_disabled(index, false)
		return
	for index: int in range(1, _operator_menu.item_count):
		var operator_id: StringName = StringName(_operator_menu.get_item_metadata(index))
		var operand_types: Array[Variant.Type] = [
			left.get_value_type(),
			right.get_value_type(),
		]
		var signature: Dictionary = FlowOperationOperatorCatalog.find_signature(
			operator_id,
			operand_types
		)
		_operator_menu.set_item_disabled(index, signature.is_empty())


func _validation_message() -> String:
	if _draft == null:
		return "Operation draft is missing."
	if _draft.operator_id.is_empty():
		return "Select an operation."
	if _draft.operands.size() != 2:
		return "Operation requires two operands."
	for index: int in 2:
		var source: FlowValueSource = _draft.operands[index]
		if source == null:
			return "Select a source for operand %s." % ("A" if index == 0 else "B")
		if source is FlowVariableRefValueSource 				and (source as FlowVariableRefValueSource).variable_id.is_empty():
			return "Choose a variable for operand %s." % ("A" if index == 0 else "B")
		if source is FlowLiteralValueSource and not source.is_valid():
			return "Complete the literal value for operand %s." % ("A" if index == 0 else "B")
	if not _invalid_literal_inputs.is_empty():
		return "Enter a valid literal value."
	var result: FlowValidationResult = FlowValidationResult.new()
	_draft.validate_structure(result, "operation")
	_draft.validate_against_graph(result, "operation", _graph)
	if result.has_errors() and not result.diagnostics.is_empty():
		return (result.diagnostics[0] as FlowDiagnostic).message
	if _schema != null:
		if not _schema.accepts_source_kind(FlowValueSource.SOURCE_KIND_OPERATION):
			return "The current schema does not accept Operation sources."
		if not _schema.accepts_value_type(_draft.get_value_type()):
			return "Operation result type is not accepted by the current schema."
	var slot: FlowChipSlotDefinition = _context.get("slot", null) as FlowChipSlotDefinition
	if slot != null:
		if not slot.accepts_source_kind(FlowValueSource.SOURCE_KIND_OPERATION) 				or not slot.accepts_value_type(_draft.get_value_type()):
			return "Operation result is incompatible with the current slot."
	return ""


func _update_preview() -> void:
	if _draft == null:
		return
	_preview_label.text = _draft.get_preview(_graph)
	_feedback_label.text = _validation_message()
	_confirm_button.disabled = not _feedback_label.text.is_empty()


func _confirm() -> void:
	_update_preview()
	if not can_confirm():
		return
	_closing_for_action = true
	operation_confirmed.emit(_draft.duplicate(true) as FlowOperationValueSource)
	hide()


func _cancel() -> void:
	_closing_for_action = false
	hide()


func _on_popup_hide() -> void:
	if not _closing_for_action:
		cancelled.emit()
	_closing_for_action = false


func _focus_default() -> void:
	if visible and _operator_menu != null:
		_operator_menu.grab_focus()


func _variable_button_text(source: FlowVariableRefValueSource) -> String:
	if source == null or source.variable_id.is_empty():
		return "Choose variable..."
	if _graph != null:
		var definition: FlowVariableDefinition = source.resolve_definition(_graph)
		if definition != null:
			return definition.display_name
	return "<missing>"


func _literal_text(
		source: FlowLiteralValueSource,
		value_type: Variant.Type
) -> String:
	if source != null and source.get_value_type() == value_type and source.is_valid():
		return str(source.get_value())
	return ""


func _literal_placeholder(value_type: Variant.Type) -> String:
	match value_type:
		Variant.Type.TYPE_INT:
			return "Integer"
		Variant.Type.TYPE_FLOAT:
			return "Decimal"
		Variant.Type.TYPE_STRING:
			return "Text"
	return "Value"
