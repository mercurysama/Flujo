@tool
## Compact structured Expression editor. It edits a detached draft only.
class_name FlowExpressionEditor
extends PopupPanel


signal expression_confirmed(source: FlowExpressionValueSource)
signal cancelled


var _draft: FlowExpressionValueSource
var _graph: FlowGraph
var _schema: FlowChipFieldSchema
var _context: Dictionary = {}
var _operator_menu: OptionButton
var _operand_rows: Array[Dictionary] = []
var _preview_label: Label
var _feedback_label: Label
var _confirm_button: Button
var _variable_selector: FlowVariableSelector
var _variable_operand_index: int = -1
var _invalid_literal_inputs: Dictionary = {}
var _closing_for_action: bool = false


func _init() -> void:
	auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	name = &"FlowExpressionEditor"
	min_size = Vector2i(460, 240)
	size = Vector2i(520, 330)
	close_requested.connect(_on_close_requested)
	popup_hide.connect(_on_popup_hide)

	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override(&"margin_left", 12)
	margin.add_theme_constant_override(&"margin_top", 10)
	margin.add_theme_constant_override(&"margin_right", 12)
	margin.add_theme_constant_override(&"margin_bottom", 10)
	add_child(margin)
	var content: VBoxContainer = VBoxContainer.new()
	content.add_theme_constant_override(&"separation", 7)
	margin.add_child(content)

	var heading: Label = Label.new()
	heading.text = "Build Expression"
	content.add_child(heading)
	_operator_menu = OptionButton.new()
	_operator_menu.name = &"ExpressionOperator"
	_operator_menu.focus_mode = Control.FOCUS_ALL
	_operator_menu.item_selected.connect(_on_operator_selected)
	content.add_child(_operator_menu)

	var rows: VBoxContainer = VBoxContainer.new()
	rows.name = &"ExpressionOperands"
	rows.add_theme_constant_override(&"separation", 4)
	content.add_child(rows)

	_preview_label = Label.new()
	_preview_label.name = &"ExpressionPreview"
	_preview_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(_preview_label)
	_feedback_label = Label.new()
	_feedback_label.name = &"ExpressionFeedback"
	_feedback_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(_feedback_label)

	var actions: HBoxContainer = HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_END
	var cancel_button: Button = Button.new()
	cancel_button.name = &"CancelExpression"
	cancel_button.text = "Cancel"
	cancel_button.focus_mode = Control.FOCUS_ALL
	cancel_button.pressed.connect(_cancel)
	actions.add_child(cancel_button)
	_confirm_button = Button.new()
	_confirm_button.name = &"ConfirmExpression"
	_confirm_button.text = "Confirm"
	_confirm_button.focus_mode = Control.FOCUS_ALL
	_confirm_button.pressed.connect(_confirm)
	actions.add_child(_confirm_button)
	content.add_child(actions)

	_variable_selector = FlowVariableSelector.new()
	_variable_selector.variable_selected.connect(_on_variable_selected)
	_variable_selector.cancelled.connect(_on_variable_selector_cancelled)
	add_child(_variable_selector)


func open_for_expression(
		initial_source: FlowExpressionValueSource = null,
		graph: FlowGraph = null,
		anchor: Rect2 = Rect2(),
		context: Dictionary = {}
) -> void:
	_graph = graph
	_schema = context.get("schema", null) as FlowChipFieldSchema
	_context = context.duplicate()
	_draft = initial_source.duplicate_with_new_id() as FlowExpressionValueSource \
		if initial_source != null else _default_draft()
	_closing_for_action = false
	_populate_operator_menu()
	_rebuild_operand_rows()
	var position: Vector2i = Vector2i(int(anchor.position.x), int(anchor.position.y + anchor.size.y))
	popup(Rect2i(position, Vector2i(size)))
	call_deferred(&"_focus_default")


func get_draft() -> FlowExpressionValueSource:
	return _draft


func can_confirm() -> bool:
	return _validation_message().is_empty()


func set_draft(source: FlowExpressionValueSource) -> void:
	_draft = source.duplicate_with_new_id() as FlowExpressionValueSource \
		if source != null else _default_draft()
	_populate_operator_menu()
	_rebuild_operand_rows()


func _default_draft() -> FlowExpressionValueSource:
	return FlowExpressionValueSource.new(
		FlowExpressionOperatorCatalog.OPERATOR_ADD,
		[
			FlowLiteralValueSource.new(FlowLiteralValueSource.TYPE_INT, 0),
			FlowLiteralValueSource.new(FlowLiteralValueSource.TYPE_INT, 0),
		]
	)


func _populate_operator_menu() -> void:
	if _operator_menu == null:
		return
	_operator_menu.clear()
	var selected: int = 0
	for operator_id: StringName in FlowExpressionOperatorCatalog.operator_ids():
		var index: int = _operator_menu.item_count
		_operator_menu.add_item(FlowExpressionOperatorCatalog.display_label(operator_id) \
			+ " (" + FlowExpressionOperatorCatalog.symbol(operator_id) + ")")
		_operator_menu.set_item_metadata(index, operator_id)
		if _draft != null and operator_id == _draft.operator_id:
			selected = index
	_operator_menu.select(selected)


func _rebuild_operand_rows() -> void:
	_operand_rows.clear()
	_invalid_literal_inputs.clear()
	var rows: VBoxContainer = find_child("ExpressionOperands", true, false) as VBoxContainer
	if rows == null:
		return
	for child: Node in rows.get_children():
		rows.remove_child(child)
		child.free()
	var operator_id: StringName = _selected_operator()
	var signatures: Array[Dictionary] = FlowExpressionOperatorCatalog.get_signatures(operator_id)
	for operand_index: int in 2:
		var row: HBoxContainer = HBoxContainer.new()
		row.name = "Operand%d" % operand_index
		var kind_menu: OptionButton = OptionButton.new()
		kind_menu.name = "Operand%dSourceKind" % operand_index
		kind_menu.add_item("Literal")
		kind_menu.set_item_metadata(0, FlowValueSource.SOURCE_KIND_LITERAL)
		kind_menu.add_item("Variable")
		kind_menu.set_item_metadata(1, FlowValueSource.SOURCE_KIND_VARIABLE_REF)
		kind_menu.item_selected.connect(_on_operand_kind_selected.bind(operand_index))
		row.add_child(kind_menu)
		var type_menu: OptionButton = OptionButton.new()
		type_menu.name = "Operand%dType" % operand_index
		type_menu.item_selected.connect(_on_operand_type_selected.bind(operand_index))
		row.add_child(type_menu)
		var value_editor: Control = _make_value_editor(operand_index, type_menu, signatures)
		if value_editor != null:
			row.add_child(value_editor)
		var choose: Button = _make_variable_button(operand_index)
		row.add_child(choose)
		rows.add_child(row)
		_operand_rows.append({
			"kind": kind_menu,
			"type": type_menu,
			"value": value_editor,
			"choose": choose,
		})
		_sync_operand_row(operand_index)
	_update_preview()


func _make_value_editor(
		operand_index: int,
		type_menu: OptionButton,
		signatures: Array[Dictionary]
) -> Control:
	var types: Array[Variant.Type] = _types_for_operand(signatures, operand_index)
	for value_type: Variant.Type in types:
		type_menu.add_item(FlowChipTypeDescriptor.variant_type_display_name(value_type))
		type_menu.set_item_metadata(type_menu.item_count - 1, int(value_type))
	var source: FlowValueSource = _draft.operands[operand_index] \
		if _draft != null and operand_index < _draft.operands.size() else null
	if source is FlowVariableRefValueSource:
		return null
	var value_type: Variant.Type = source.get_value_type() if source != null else _first_type(types)
	match value_type:
		FlowLiteralValueSource.TYPE_BOOL:
			var toggle: CheckButton = CheckButton.new()
			toggle.name = "Operand%dBoolValue" % operand_index
			toggle.focus_mode = Control.FOCUS_ALL
			toggle.text = "True" if _literal_bool_value(source) else "False"
			toggle.button_pressed = _literal_bool_value(source)
			toggle.toggled.connect(_on_bool_value_toggled.bind(operand_index))
			return toggle
		FlowLiteralValueSource.TYPE_INT, FlowLiteralValueSource.TYPE_FLOAT, FlowLiteralValueSource.TYPE_STRING:
			var input: LineEdit = LineEdit.new()
			input.name = "Operand%dValue" % operand_index
			input.focus_mode = Control.FOCUS_ALL
			input.custom_minimum_size.x = 120.0
			input.clear_button_enabled = value_type == FlowLiteralValueSource.TYPE_STRING
			input.placeholder_text = _literal_placeholder(value_type)
			input.text = _literal_text_value(source, value_type)
			input.text_changed.connect(_on_literal_text_changed.bind(operand_index, value_type))
			return input
	return null


func _make_variable_button(operand_index: int) -> Button:
	var button: Button = Button.new()
	button.name = "Operand%dChoose" % operand_index
	button.focus_mode = Control.FOCUS_ALL
	button.pressed.connect(_open_variable_selector.bind(operand_index, button))
	return button


func _sync_operand_row(index: int) -> void:
	if _draft == null or index < 0 or index >= _operand_rows.size():
		return
	var row: Dictionary = _operand_rows[index]
	var source: FlowValueSource = _draft.operands[index] if index < _draft.operands.size() else null
	var kind_menu: OptionButton = row["kind"] as OptionButton
	var type_menu: OptionButton = row["type"] as OptionButton
	var choose: Button = row["choose"] as Button
	var kind: StringName = source.get_source_kind() if source != null else FlowValueSource.SOURCE_KIND_LITERAL
	kind_menu.select(1 if kind == FlowValueSource.SOURCE_KIND_VARIABLE_REF else 0)
	for type_index: int in type_menu.item_count:
		if int(type_menu.get_item_metadata(type_index)) == int(source.get_value_type() if source != null else Variant.Type.TYPE_INT):
			type_menu.select(type_index)
			break
	var variable_source: FlowVariableRefValueSource = source as FlowVariableRefValueSource
	var is_variable: bool = variable_source != null
	type_menu.disabled = is_variable and not variable_source.variable_id.is_empty()
	choose.visible = is_variable
	if is_variable:
		if variable_source.variable_id.is_empty():
			choose.text = "Choose variable"
		else:
			choose.text = _variable_button_text(variable_source)
	_update_preview()


func _selected_operator() -> StringName:
	if _operator_menu == null or _operator_menu.selected < 0:
		return FlowExpressionOperatorCatalog.OPERATOR_ADD
	return StringName(_operator_menu.get_item_metadata(_operator_menu.selected))


func _types_for_operand(signatures: Array[Dictionary], index: int) -> Array[Variant.Type]:
	var result: Array[Variant.Type] = []
	for signature: Dictionary in signatures:
		var values: Array = signature.get("operand_types", []) as Array
		if index >= values.size():
			continue
		var candidate: Variant.Type = int(values[index])
		if not result.has(candidate):
			result.append(candidate)
	return result


func _on_operator_selected(_index: int) -> void:
	_write_draft_from_rows()
	_draft.operator_id = _selected_operator()
	_reconcile_operand_types()
	call_deferred(&"_rebuild_operand_rows")


func _on_operand_kind_selected(_index: int, operand_index: int) -> void:
	_write_draft_from_rows()
	var kind_menu: OptionButton = _operand_rows[operand_index]["kind"] as OptionButton
	var kind: StringName = StringName(kind_menu.get_item_metadata(kind_menu.selected))
	var current: FlowValueSource = _draft.operands[operand_index] \
		if operand_index < _draft.operands.size() else null
	if kind == FlowValueSource.SOURCE_KIND_VARIABLE_REF:
		if not current is FlowVariableRefValueSource:
			_draft.operands[operand_index] = FlowVariableRefValueSource.new(
				"", _flow_value_type(_first_type(_types_for_operand(
					FlowExpressionOperatorCatalog.get_signatures(_selected_operator()), operand_index
				))))
	else:
		var value_type: Variant.Type = current.get_value_type() if current != null else Variant.Type.TYPE_INT
		if not FlowLiteralValueSource.is_allowed_type(value_type):
			value_type = _first_type(_types_for_operand(
				FlowExpressionOperatorCatalog.get_signatures(_selected_operator()), operand_index))
		_draft.operands[operand_index] = _literal_with_preserved_value(current, value_type)
	call_deferred(&"_rebuild_operand_rows")


func _on_operand_type_selected(_index: int, operand_index: int) -> void:
	var row: Dictionary = _operand_rows[operand_index]
	var type_menu: OptionButton = row["type"] as OptionButton
	var value_type: Variant.Type = int(type_menu.get_item_metadata(type_menu.selected))
	var kind_menu: OptionButton = row["kind"] as OptionButton
	if kind_menu.selected == 1:
		var current_variable: FlowVariableRefValueSource = \
			_draft.operands[operand_index] as FlowVariableRefValueSource
		var current_variable_id: String = current_variable.variable_id \
			if current_variable != null else ""
		_draft.operands[operand_index] = FlowVariableRefValueSource.new(
			current_variable_id,
			_flow_value_type(value_type)
		)
	else:
		_draft.operands[operand_index] = _literal_with_preserved_value(
			_draft.operands[operand_index], value_type
		)
	call_deferred(&"_rebuild_operand_rows")


func _open_variable_selector(operand_index: int, button: Button) -> void:
	if _graph == null:
		return
	_variable_operand_index = operand_index
	var candidates: Array[FlowVariableDefinition] = []
	var allowed: Array[Variant.Type] = _types_for_operand(
		FlowExpressionOperatorCatalog.get_signatures(_selected_operator()), operand_index
	)
	var current_source: FlowVariableRefValueSource = null
	if operand_index < _draft.operands.size():
		current_source = _draft.operands[operand_index] as FlowVariableRefValueSource
	if current_source != null and allowed.has(current_source.get_value_type()):
		allowed = [current_source.get_value_type()]
	for variable: FlowVariableDefinition in _graph.variables:
		if variable != null and (allowed.is_empty() or allowed.has(variable.get_declared_variant_type())):
			candidates.append(variable)
	_variable_selector.open_for_variables(
		candidates,
		button.get_global_rect(),
		"",
		{
			"accepted_value_types": allowed,
			"current_variable_id": _current_variable_id(operand_index),
		}
	)


func _on_variable_selected(variable_id: String) -> void:
	if _variable_operand_index < 0 or _graph == null:
		return
	for variable: FlowVariableDefinition in _graph.variables:
		if variable != null and variable.get_internal_id() == variable_id:
			var current_source: FlowVariableRefValueSource = \
				_draft.operands[_variable_operand_index] as FlowVariableRefValueSource
			var next_source: FlowVariableRefValueSource = FlowVariableRefValueSource.new(
				variable_id, variable.value_type
			)
			if current_source != null:
				next_source.source_id = current_source.source_id
			_draft.operands[_variable_operand_index] = next_source
			_variable_operand_index = -1
			_rebuild_operand_rows()
			return


func _on_variable_selector_cancelled() -> void:
	_variable_operand_index = -1


func _write_draft_from_rows() -> void:
	if _draft == null:
		return
	for index: int in mini(_operand_rows.size(), 2):
		var row: Dictionary = _operand_rows[index]
		var kind_menu: OptionButton = row["kind"] as OptionButton
		var type_menu: OptionButton = row["type"] as OptionButton
		if kind_menu.selected == 1:
			continue
		if type_menu.selected < 0:
			continue
		var value_type: Variant.Type = int(type_menu.get_item_metadata(type_menu.selected))
		var current: FlowValueSource = _draft.operands[index] if index < _draft.operands.size() else null
		var value_editor: Control = row["value"] as Control
		_apply_literal_editor_value(index, value_editor, value_type, current)


func _literal_with_preserved_value(
		current: FlowValueSource,
		value_type: Variant.Type
) -> FlowLiteralValueSource:
	var value: Variant = FlowChipTypeDescriptor.default_value_for_type(value_type)
	if current is FlowLiteralValueSource and current.get_value_type() == value_type \
			and (current as FlowLiteralValueSource).is_valid():
		value = current.get_value()
	return FlowLiteralValueSource.new(value_type, value)


func _apply_literal_editor_value(
		index: int,
		value_editor: Control,
		value_type: Variant.Type,
		current: FlowValueSource
) -> void:
	if value_editor is CheckButton:
		_draft.operands[index] = FlowLiteralValueSource.new(
			value_type, (value_editor as CheckButton).button_pressed
		)
		return
	if value_editor is LineEdit:
		var text: String = (value_editor as LineEdit).text
		if _set_literal_from_text(index, value_type, text):
			return
	_draft.operands[index] = _literal_with_preserved_value(current, value_type)


func _on_literal_text_changed(text: String, operand_index: int, value_type: Variant.Type) -> void:
	if _draft == null or operand_index < 0 or operand_index >= _draft.operands.size():
		return
	if _set_literal_from_text(operand_index, value_type, text):
		_invalid_literal_inputs.erase(operand_index)
	else:
		_invalid_literal_inputs[operand_index] = true
	_update_preview()


func _on_bool_value_toggled(pressed: bool, operand_index: int) -> void:
	if _draft == null or operand_index < 0 or operand_index >= _draft.operands.size():
		return
	_draft.operands[operand_index] = FlowLiteralValueSource.new(
		FlowLiteralValueSource.TYPE_BOOL, pressed
	)
	var row: Dictionary = _operand_rows[operand_index]
	var toggle: CheckButton = row["value"] as CheckButton
	if toggle != null:
		toggle.text = "True" if pressed else "False"
	_update_preview()


func _set_literal_from_text(index: int, value_type: Variant.Type, text: String) -> bool:
	var value: Variant
	match value_type:
		FlowLiteralValueSource.TYPE_INT:
			if not text.is_valid_int():
				return false
			value = int(text)
		FlowLiteralValueSource.TYPE_FLOAT:
			if not text.is_valid_float():
				return false
			value = float(text)
		FlowLiteralValueSource.TYPE_STRING:
			value = text
	_ensure_operand_count(index)
	_draft.operands[index] = FlowLiteralValueSource.new(value_type, value)
	return true
	return false


func _ensure_operand_count(index: int) -> void:
	while _draft.operands.size() <= index:
		_draft.operands.append(null)


func _reconcile_operand_types() -> void:
	var signatures: Array[Dictionary] = FlowExpressionOperatorCatalog.get_signatures(_selected_operator())
	for index: int in mini(_draft.operands.size(), 2):
		var allowed: Array[Variant.Type] = _types_for_operand(signatures, index)
		var source: FlowValueSource = _draft.operands[index]
		if source != null and allowed.has(source.get_value_type()):
			continue
		var value_type: Variant.Type = _first_type(allowed)
		if source is FlowVariableRefValueSource:
			_draft.operands[index] = FlowVariableRefValueSource.new("", _flow_value_type(value_type))
		else:
			_draft.operands[index] = _literal_with_preserved_value(source, value_type)


func _first_type(types: Array[Variant.Type]) -> Variant.Type:
	return types[0] if not types.is_empty() else FlowLiteralValueSource.TYPE_INT


func _literal_bool_value(source: FlowValueSource) -> bool:
	return source is FlowLiteralValueSource and bool((source as FlowLiteralValueSource).get_value())


func _literal_text_value(source: FlowValueSource, value_type: Variant.Type) -> String:
	if source is FlowLiteralValueSource and (source as FlowLiteralValueSource).get_value_type() == value_type:
		return str((source as FlowLiteralValueSource).get_value())
	return str(FlowChipTypeDescriptor.default_value_for_type(value_type))


func _literal_placeholder(value_type: Variant.Type) -> String:
	match value_type:
		FlowLiteralValueSource.TYPE_INT:
			return "Integer value"
		FlowLiteralValueSource.TYPE_FLOAT:
			return "Float value"
		FlowLiteralValueSource.TYPE_STRING:
			return "String value"
	return "Literal value"


func _current_variable_id(index: int) -> String:
	if _draft == null or index < 0 or index >= _draft.operands.size():
		return ""
	var variable_source: FlowVariableRefValueSource = _draft.operands[index] as FlowVariableRefValueSource
	return variable_source.variable_id if variable_source != null else ""


func _variable_button_text(source: FlowVariableRefValueSource) -> String:
	if source == null or source.variable_id.is_empty():
		return "Choose variable"
	if _graph != null:
		var variable: FlowVariableDefinition = source.resolve_definition(_graph)
		if variable != null:
			return "Change variable: %s" % variable.display_name
	return "Change variable (missing)"


func _update_preview() -> void:
	if _draft == null:
		return
	_preview_label.text = "Preview: " + _draft.get_preview(_graph)
	_feedback_label.text = _validation_message()
	_confirm_button.disabled = not _feedback_label.text.is_empty()


func _validation_message() -> String:
	if _draft == null:
		return "Expression draft is missing."
	if not _invalid_literal_inputs.is_empty():
		return "Enter a valid value for every Literal operand."
	var result: FlowValidationResult = FlowValidationResult.new()
	_draft.validate_structure(result, "expression")
	if result.has_errors() and not result.diagnostics.is_empty():
		return (result.diagnostics[0] as FlowDiagnostic).message
	if _schema != null:
		if not _schema.accepts_source_kind(FlowValueSource.SOURCE_KIND_EXPRESSION):
			return "The current schema does not accept Expression sources."
		if not _schema.accepts_value_type(_draft.get_value_type()):
			return "Expression result type is not accepted by the current schema."
	var slot: FlowChipSlotDefinition = _context.get("slot", null) as FlowChipSlotDefinition
	if slot != null and (not slot.accepts_source_kind(FlowValueSource.SOURCE_KIND_EXPRESSION) \
			or not slot.accepts_value_type(_draft.get_value_type())):
		return "Expression result is incompatible with the current slot."
	return ""


func _confirm() -> void:
	_write_draft_from_rows()
	_update_preview()
	if not can_confirm():
		return
	_closing_for_action = true
	expression_confirmed.emit(_draft.duplicate_with_new_id() as FlowExpressionValueSource)
	hide()


func _cancel() -> void:
	_closing_for_action = false
	hide()


func _on_close_requested() -> void:
	_cancel()


func _on_popup_hide() -> void:
	if not _closing_for_action:
		cancelled.emit()
	_closing_for_action = false


func _focus_default() -> void:
	if visible and _operator_menu != null:
		_operator_menu.grab_focus()


func _flow_value_type(value_type: Variant.Type) -> FlowVariableDefinition.ValueType:
	match value_type:
		Variant.Type.TYPE_BOOL:
			return FlowVariableDefinition.ValueType.BOOL
		Variant.Type.TYPE_INT:
			return FlowVariableDefinition.ValueType.INT
		Variant.Type.TYPE_FLOAT:
			return FlowVariableDefinition.ValueType.FLOAT
		Variant.Type.TYPE_STRING:
			return FlowVariableDefinition.ValueType.STRING
	return FlowVariableDefinition.ValueType.BOOL
