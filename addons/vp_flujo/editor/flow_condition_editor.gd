@tool
## Visual editor for a detached Condition Tok draft.
class_name FlowConditionEditor
extends PopupPanel


signal condition_confirmed(source: FlowConditionValueSource)
signal cancelled


var _draft: FlowConditionValueSource
var _graph: FlowGraph
var _schema: FlowChipFieldSchema
var _context: Dictionary = {}
var _rows: Array[Dictionary] = []
var _rows_box: VBoxContainer
var _preview_label: Label
var _feedback_label: Label
var _confirm_button: Button
var _variable_selector: FlowVariableSelector
var _variable_row_index: int = -1
var _variable_side: String = ""
var _invalid_literal_inputs: Dictionary = {}
var _closing_for_action: bool = false


func _init() -> void:
	auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	name = &"FlowConditionEditor"
	min_size = Vector2i(560, 300)
	size = Vector2i(640, 460)
	close_requested.connect(_on_close_requested)
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
	heading.name = &"ConditionHeading"
	heading.text = "Build Condition"
	heading.add_theme_font_size_override(&"font_size", 16)
	content.add_child(heading)

	_rows_box = VBoxContainer.new()
	_rows_box.name = &"ConditionRows"
	_rows_box.add_theme_constant_override(&"separation", 6)
	content.add_child(_rows_box)

	var add_button: Button = Button.new()
	add_button.name = &"AddCondition"
	add_button.text = "+ Add condition"
	add_button.focus_mode = Control.FOCUS_ALL
	add_button.custom_minimum_size.y = 38.0
	add_button.pressed.connect(add_condition)
	content.add_child(add_button)

	var preview_heading: Label = Label.new()
	preview_heading.text = "Preview"
	content.add_child(preview_heading)
	_preview_label = Label.new()
	_preview_label.name = &"ConditionPreview"
	_preview_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_preview_label.custom_minimum_size.y = 34.0
	content.add_child(_preview_label)
	_feedback_label = Label.new()
	_feedback_label.name = &"ConditionFeedback"
	_feedback_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_feedback_label.add_theme_color_override(&"font_color", Color(1.0, 0.55, 0.35))
	content.add_child(_feedback_label)

	var actions: HBoxContainer = HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_END
	var cancel_button: Button = Button.new()
	cancel_button.name = &"CancelCondition"
	cancel_button.text = "Cancel"
	cancel_button.focus_mode = Control.FOCUS_ALL
	cancel_button.custom_minimum_size = Vector2(110.0, 38.0)
	cancel_button.pressed.connect(_cancel)
	actions.add_child(cancel_button)
	_confirm_button = Button.new()
	_confirm_button.name = &"ConfirmCondition"
	_confirm_button.text = "Confirm"
	_confirm_button.focus_mode = Control.FOCUS_ALL
	_confirm_button.custom_minimum_size = Vector2(110.0, 38.0)
	_confirm_button.pressed.connect(_confirm)
	actions.add_child(_confirm_button)
	content.add_child(actions)

	_variable_selector = FlowVariableSelector.new()
	_variable_selector.variable_selected.connect(_on_variable_selected)
	_variable_selector.cancelled.connect(_on_variable_selector_cancelled)
	add_child(_variable_selector)


func open_for_condition(
		initial_source: FlowConditionValueSource = null,
		graph: FlowGraph = null,
		anchor: Rect2 = Rect2(),
		context: Dictionary = {}
) -> void:
	_graph = graph
	_schema = context.get("schema", null) as FlowChipFieldSchema
	_context = context.duplicate()
	_draft = initial_source.duplicate_with_new_id() as FlowConditionValueSource \
		if initial_source != null else _default_draft()
	_closing_for_action = false
	_rebuild_rows()
	var position: Vector2i = Vector2i(int(anchor.position.x), int(anchor.position.y + anchor.size.y))
	popup(Rect2i(position, Vector2i(size)))
	call_deferred(&"_focus_default")


func get_draft() -> FlowConditionValueSource:
	return _draft


func set_draft(source: FlowConditionValueSource) -> void:
	_draft = source.duplicate_with_new_id() as FlowConditionValueSource \
		if source != null else _default_draft()
	_rebuild_rows()


func can_confirm() -> bool:
	return _validation_message().is_empty()


func add_condition() -> void:
	if _draft == null:
		_draft = _default_draft()
	_write_draft_from_rows()
	_draft.comparisons.append(_default_comparison())
	_draft.connectors.append(&"")
	_rebuild_rows()


func delete_condition(index: int) -> bool:
	if _draft == null or index <= 0 or index >= _draft.comparisons.size():
		return false
	_write_draft_from_rows()
	_draft.comparisons.remove_at(index)
	if index - 1 < _draft.connectors.size():
		_draft.connectors.remove_at(index - 1)
	_rebuild_rows()
	return true


func _default_draft() -> FlowConditionValueSource:
	return FlowConditionValueSource.new([_default_comparison()], [])


func _default_comparison() -> FlowConditionComparison:
	return FlowConditionComparison.new(&"", null, null)


func _rebuild_rows() -> void:
	if _rows_box == null:
		return
	_rows.clear()
	_invalid_literal_inputs.clear()
	for child: Node in _rows_box.get_children():
		_rows_box.remove_child(child)
		child.queue_free()
	if _draft == null or _draft.comparisons.is_empty():
		_draft = _default_draft()
	for index: int in _draft.comparisons.size():
		if index > 0:
			var connector: OptionButton = OptionButton.new()
			connector.name = "Connector%d" % index
			connector.focus_mode = Control.FOCUS_ALL
			connector.custom_minimum_size.y = 36.0
			connector.add_item("Select connector...")
			connector.set_item_metadata(0, &"")
			for connector_id: StringName in FlowConditionOperatorCatalog.connector_ids():
				var connector_index: int = connector.item_count
				connector.add_item(FlowConditionOperatorCatalog.connector_symbol(connector_id))
				connector.set_item_metadata(connector_index, connector_id)
			var connector_id: StringName = _draft.connectors[index - 1] \
				if index - 1 < _draft.connectors.size() else &""
			connector.select(_connector_menu_index(connector_id))
			connector.item_selected.connect(_on_connector_selected.bind(index - 1))
			_rows_box.add_child(connector)
		var row: Dictionary = _build_comparison_row(index, _draft.comparisons[index])
		_rows_box.add_child(row["container"] as Control)
		_rows.append(row)
	_update_preview()


func _build_comparison_row(index: int, comparison: FlowConditionComparison) -> Dictionary:
	var container: VBoxContainer = VBoxContainer.new()
	container.name = "ComparisonRow%d" % index
	container.add_theme_constant_override(&"separation", 3)
	var title: Label = Label.new()
	title.text = "Comparison %d" % (index + 1)
	container.add_child(title)
	var controls: HBoxContainer = HBoxContainer.new()
	controls.name = "ComparisonControls%d" % index
	controls.add_theme_constant_override(&"separation", 4)
	container.add_child(controls)
	var left: Dictionary = _build_operand_controls(index, "A", comparison.left_source)
	controls.add_child(left["container"] as Control)
	var operator: OptionButton = _build_operator_menu(index, comparison.operator_id)
	controls.add_child(operator)
	var right: Dictionary = _build_operand_controls(index, "B", comparison.right_source)
	controls.add_child(right["container"] as Control)
	if index > 0:
		var delete_button: Button = Button.new()
		delete_button.name = "DeleteComparison%d" % index
		delete_button.text = "Remove"
		delete_button.tooltip_text = "Remove this comparison"
		delete_button.focus_mode = Control.FOCUS_ALL
		delete_button.custom_minimum_size = Vector2(88.0, 36.0)
		delete_button.pressed.connect(delete_condition.bind(index))
		controls.add_child(delete_button)
	var row: Dictionary = {
		"container": container,
		"operator": operator,
		"left": left,
		"right": right,
	}
	return row


func _build_operator_menu(index: int, selected: StringName) -> OptionButton:
	var menu: OptionButton = OptionButton.new()
	menu.name = "ComparisonOperator%d" % index
	menu.focus_mode = Control.FOCUS_ALL
	menu.custom_minimum_size = Vector2(72.0, 36.0)
	menu.add_item("Select comparison...")
	menu.set_item_metadata(0, &"")
	var operands_known: bool = _comparison_operands_have_types(index)
	for operator_id: StringName in FlowConditionOperatorCatalog.comparison_ids():
		var item: int = menu.item_count
		menu.add_item(FlowConditionOperatorCatalog.symbol(operator_id))
		menu.set_item_metadata(item, operator_id)
		if operands_known and not _operator_is_compatible(index, operator_id):
			menu.set_item_disabled(item, true)
		if operator_id == selected:
			menu.select(item)
	if menu.selected < 0:
		menu.select(0)
	menu.item_selected.connect(_on_operator_selected.bind(index))
	return menu


func _build_operand_controls(
		row_index: int,
		side: String,
		source: FlowValueSource
) -> Dictionary:
	var box: VBoxContainer = VBoxContainer.new()
	box.name = "Operand%s%d" % [side, row_index]
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.custom_minimum_size.x = 150.0
	var line: HBoxContainer = HBoxContainer.new()
	line.name = "Operand%sHeader%d" % [side, row_index]
	box.add_child(line)
	var kind: OptionButton = OptionButton.new()
	kind.name = "Operand%sSourceKind%d" % [side, row_index]
	kind.focus_mode = Control.FOCUS_ALL
	kind.custom_minimum_size = Vector2(86.0, 36.0)
	kind.add_item("Select source...")
	kind.set_item_metadata(0, &"")
	kind.add_item("Variable")
	kind.set_item_metadata(1, FlowValueSource.SOURCE_KIND_VARIABLE_REF)
	kind.add_item("Literal")
	kind.set_item_metadata(2, FlowValueSource.SOURCE_KIND_LITERAL)
	var is_variable: bool = source is FlowVariableRefValueSource
	var is_literal: bool = source is FlowLiteralValueSource
	kind.select(1 if is_variable else (2 if is_literal else 0))
	kind.item_selected.connect(_on_operand_kind_selected.bind(row_index, side))
	line.add_child(kind)
	var value: Control = null
	var type_control: Control = null
	if is_variable:
		var variable_source: FlowVariableRefValueSource = source as FlowVariableRefValueSource
		var choose: Button = Button.new()
		choose.name = "Operand%sChooseVariable%d" % [side, row_index]
		choose.text = _variable_button_text(variable_source)
		choose.focus_mode = Control.FOCUS_ALL
		choose.custom_minimum_size = Vector2(132.0, 36.0)
		choose.pressed.connect(_open_variable_selector.bind(row_index, side, choose))
		line.add_child(choose)
		if not variable_source.variable_id.is_empty():
			var badge: Label = Label.new()
			badge.name = "Operand%sTypeBadge%d" % [side, row_index]
			var derived_type: Variant.Type = variable_source.get_value_type()
			if _graph != null:
				var definition: FlowVariableDefinition = variable_source.resolve_definition(_graph)
				if definition != null:
					derived_type = definition.get_declared_variant_type()
			badge.text = _type_name(derived_type)
			badge.tooltip_text = "Type comes from FlowGraph.variables"
			badge.custom_minimum_size.x = 52.0
			line.add_child(badge)
		value = choose
	elif is_literal:
		var literal: FlowLiteralValueSource = source as FlowLiteralValueSource
		var type_menu: OptionButton = OptionButton.new()
		type_menu.name = "Operand%sType%d" % [side, row_index]
		type_menu.focus_mode = Control.FOCUS_ALL
		type_menu.custom_minimum_size = Vector2(74.0, 36.0)
		type_menu.add_item("Select type...")
		type_menu.set_item_metadata(0, int(Variant.Type.TYPE_NIL))
		var current_type: Variant.Type = literal.get_value_type() if literal != null else Variant.Type.TYPE_NIL
		for candidate: Variant.Type in _types_for_operand(row_index, side, current_type):
			var item: int = type_menu.item_count
			type_menu.add_item(_type_name(candidate))
			type_menu.set_item_metadata(item, int(candidate))
			if candidate == current_type:
				type_menu.select(item)
		if type_menu.selected < 0:
			type_menu.select(0)
		type_menu.item_selected.connect(_on_operand_type_selected.bind(row_index, side))
		line.add_child(type_menu)
		type_control = type_menu
		value = _make_literal_editor(row_index, side, literal, current_type) \
			if FlowLiteralValueSource.is_allowed_type(current_type) else null
		if value != null:
			box.add_child(value)
	return {"container": box, "kind": kind, "type": type_control, "value": value}


func _make_literal_editor(
		row_index: int,
		side: String,
		literal: FlowLiteralValueSource,
		value_type: Variant.Type
) -> Control:
	match value_type:
		Variant.Type.TYPE_BOOL:
			var value_menu: OptionButton = OptionButton.new()
			value_menu.name = "Operand%sBoolValue%d" % [side, row_index]
			value_menu.focus_mode = Control.FOCUS_ALL
			value_menu.add_item("Select value...")
			value_menu.set_item_metadata(0, null)
			value_menu.add_item("true")
			value_menu.set_item_metadata(1, true)
			value_menu.add_item("false")
			value_menu.set_item_metadata(2, false)
			if literal != null and literal.is_valid() and bool(literal.get_value()):
				value_menu.select(1)
			elif literal != null and literal.is_valid():
				value_menu.select(2)
			value_menu.item_selected.connect(_on_bool_value_selected.bind(row_index, side))
			return value_menu
		Variant.Type.TYPE_INT, Variant.Type.TYPE_FLOAT, Variant.Type.TYPE_STRING:
			var input: LineEdit = LineEdit.new()
			input.name = "Operand%sValue%d" % [side, row_index]
			input.focus_mode = Control.FOCUS_ALL
			input.custom_minimum_size = Vector2(110.0, 36.0)
			input.placeholder_text = _literal_placeholder(value_type)
			input.text = _literal_text_value(literal, value_type)
			input.text_changed.connect(_on_literal_text_changed.bind(row_index, side, value_type))
			return input
	return null


func _types_for_operand(row_index: int, side: String, current: Variant.Type) -> Array[Variant.Type]:
	var result: Array[Variant.Type] = []
	var allowed: Array[Variant.Type] = [
		FlowLiteralValueSource.TYPE_INT,
		FlowLiteralValueSource.TYPE_FLOAT,
		FlowLiteralValueSource.TYPE_STRING,
		FlowLiteralValueSource.TYPE_BOOL,
	]
	var other: FlowValueSource = null
	var operator_id: StringName = &""
	if _draft != null and row_index < _draft.comparisons.size():
		var comparison: FlowConditionComparison = _draft.comparisons[row_index]
		other = comparison.right_source if side == "A" else comparison.left_source
		operator_id = comparison.operator_id
	var other_type: Variant.Type = other.get_value_type() if other != null else Variant.Type.TYPE_NIL
	if other_type == Variant.Type.TYPE_NIL or not FlowLiteralValueSource.is_allowed_type(other_type):
		other_type = Variant.Type.TYPE_NIL
	if operator_id.is_empty() or other_type == Variant.Type.TYPE_NIL:
		return allowed
	for descriptor: Dictionary in FlowConditionOperatorCatalog.get_descriptor(operator_id).get("signatures", []):
		var candidate: Variant.Type = descriptor.get("left_type", Variant.Type.TYPE_NIL) \
			if side == "A" else descriptor.get("right_type", Variant.Type.TYPE_NIL)
		var paired: Variant.Type = descriptor.get("right_type", Variant.Type.TYPE_NIL) \
			if side == "A" else descriptor.get("left_type", Variant.Type.TYPE_NIL)
		if paired == other_type and allowed.has(candidate) and not result.has(candidate):
			result.append(candidate)
	if current != Variant.Type.TYPE_NIL and allowed.has(current) and not result.has(current):
		result.append(current)
	return result


func _comparison_operands_have_types(row_index: int) -> bool:
	if _draft == null or row_index < 0 or row_index >= _draft.comparisons.size():
		return false
	var comparison: FlowConditionComparison = _draft.comparisons[row_index]
	return comparison != null and comparison.left_source != null \
		and comparison.right_source != null \
		and comparison.left_source.get_value_type() != Variant.Type.TYPE_NIL \
		and comparison.right_source.get_value_type() != Variant.Type.TYPE_NIL


func _operator_is_compatible(row_index: int, operator_id: StringName) -> bool:
	if not _comparison_operands_have_types(row_index):
		return true
	var comparison: FlowConditionComparison = _draft.comparisons[row_index]
	return not FlowConditionOperatorCatalog.find_signature(
		operator_id,
		comparison.left_source.get_value_type(),
		comparison.right_source.get_value_type()
	).is_empty()


func _connector_menu_index(connector_id: StringName) -> int:
	if connector_id == FlowConditionOperatorCatalog.CONNECTOR_AND:
		return 1
	if connector_id == FlowConditionOperatorCatalog.CONNECTOR_OR:
		return 2
	return 0


func _on_connector_selected(selected: int, index: int) -> void:
	if _draft == null or index < 0 or index >= _draft.connectors.size():
		return
	_draft.connectors[index] = StringName((_rows_box.get_node("Connector%d" % (index + 1)) as OptionButton).get_item_metadata(selected))
	_update_preview()


func _on_operator_selected(_selected: int, row_index: int) -> void:
	if _draft == null or row_index < 0 or row_index >= _draft.comparisons.size():
		return
	var menu: OptionButton = _rows[row_index]["operator"] as OptionButton
	_draft.comparisons[row_index].operator_id = StringName(menu.get_item_metadata(menu.selected))
	_rebuild_rows()


func _on_operand_kind_selected(_selected: int, row_index: int, side: String) -> void:
	if _draft == null or row_index < 0 or row_index >= _draft.comparisons.size():
		return
	var row: Dictionary = _rows[row_index]
	var kind: OptionButton = row["left"]["kind"] if side == "A" else row["right"]["kind"]
	var selected_kind: StringName = StringName(kind.get_item_metadata(kind.selected))
	var comparison: FlowConditionComparison = _draft.comparisons[row_index]
	var current: FlowValueSource = comparison.left_source if side == "A" else comparison.right_source
	var next: FlowValueSource
	if selected_kind == FlowValueSource.SOURCE_KIND_VARIABLE_REF:
		next = FlowVariableRefValueSource.new("", FlowVariableDefinition.ValueType.BOOL)
	elif selected_kind == FlowValueSource.SOURCE_KIND_LITERAL:
		next = FlowLiteralValueSource.new(Variant.Type.TYPE_NIL, null)
	else:
		next = null
	if side == "A":
		comparison.left_source = next
	else:
		comparison.right_source = next
	_rebuild_rows()


func _on_operand_type_selected(selected: int, row_index: int, side: String) -> void:
	if _draft == null or row_index < 0 or row_index >= _draft.comparisons.size():
		return
	if selected <= 0:
		return
	var row: Dictionary = _rows[row_index]
	var menu: OptionButton = row["left"]["type"] if side == "A" else row["right"]["type"]
	var value_type: Variant.Type = int(menu.get_item_metadata(selected))
	var comparison: FlowConditionComparison = _draft.comparisons[row_index]
	var current: FlowValueSource = comparison.left_source if side == "A" else comparison.right_source
	var next: FlowLiteralValueSource = _literal_with_preserved_value(current, value_type)
	if side == "A":
		comparison.left_source = next
	else:
		comparison.right_source = next
	_rebuild_rows()


func _on_literal_text_changed(text: String, row_index: int, side: String, value_type: Variant.Type) -> void:
	if _draft == null or row_index < 0 or row_index >= _draft.comparisons.size():
		return
	var parsed: Variant
	var valid: bool = true
	match value_type:
		Variant.Type.TYPE_INT:
			valid = text.is_valid_int()
			if valid: parsed = int(text)
		Variant.Type.TYPE_FLOAT:
			valid = text.is_valid_float()
			if valid: parsed = float(text)
		Variant.Type.TYPE_STRING:
			parsed = text
	if not valid:
		_invalid_literal_inputs["%d:%s" % [row_index, side]] = true
	else:
		_invalid_literal_inputs.erase("%d:%s" % [row_index, side])
		var comparison: FlowConditionComparison = _draft.comparisons[row_index]
		var next: FlowLiteralValueSource = FlowLiteralValueSource.new(value_type, parsed)
		if side == "A": comparison.left_source = next
		else: comparison.right_source = next
	_update_preview()


func _on_bool_value_selected(selected: int, row_index: int, side: String) -> void:
	if _draft == null or row_index < 0 or row_index >= _draft.comparisons.size():
		return
	var row: Dictionary = _rows[row_index]
	var value_menu: OptionButton = row["left"]["value"] if side == "A" else row["right"]["value"]
	if value_menu == null or selected <= 0:
		return
	var value: bool = bool(value_menu.get_item_metadata(selected))
	var comparison: FlowConditionComparison = _draft.comparisons[row_index]
	var next: FlowLiteralValueSource = FlowLiteralValueSource.new(FlowLiteralValueSource.TYPE_BOOL, value)
	if side == "A": comparison.left_source = next
	else: comparison.right_source = next
	_update_preview()


func _open_variable_selector(row_index: int, side: String, button: Button) -> void:
	if _graph == null or _draft == null or row_index < 0 or row_index >= _draft.comparisons.size():
		return
	_variable_row_index = row_index
	_variable_side = side
	var comparison: FlowConditionComparison = _draft.comparisons[row_index]
	var other: FlowValueSource = comparison.right_source if side == "A" else comparison.left_source
	var allowed: Array[Variant.Type] = []
	for descriptor: Dictionary in FlowConditionOperatorCatalog.get_descriptor(comparison.operator_id).get("signatures", []):
		var paired: Variant.Type = descriptor.get("right_type", Variant.Type.TYPE_NIL) if side == "A" else descriptor.get("left_type", Variant.Type.TYPE_NIL)
		if other == null or other.get_value_type() == paired:
			var candidate: Variant.Type = descriptor.get("left_type", Variant.Type.TYPE_NIL) if side == "A" else descriptor.get("right_type", Variant.Type.TYPE_NIL)
			if not allowed.has(candidate): allowed.append(candidate)
	var current: FlowVariableRefValueSource = (comparison.left_source if side == "A" else comparison.right_source) as FlowVariableRefValueSource
	_variable_selector.open_for_variables(
		_compatible_variables(allowed),
		Rect2(button.get_global_rect().position, Vector2(1.0, button.size.y)),
		"",
		{"accepted_value_types": allowed, "current_variable_id": current.variable_id if current != null else ""}
	)


func _compatible_variables(allowed: Array[Variant.Type]) -> Array[FlowVariableDefinition]:
	var result: Array[FlowVariableDefinition] = []
	if _graph == null: return result
	for variable: FlowVariableDefinition in _graph.variables:
		if variable == null: continue
		if allowed.is_empty() or allowed.has(variable.get_declared_variant_type()): result.append(variable)
	return result


func _on_variable_selected(variable_id: String) -> void:
	if _graph == null or _draft == null: return
	for variable: FlowVariableDefinition in _graph.variables:
		if variable == null or variable.get_internal_id() != variable_id: continue
		var comparison: FlowConditionComparison = _draft.comparisons[_variable_row_index]
		var current: FlowVariableRefValueSource = (comparison.left_source if _variable_side == "A" else comparison.right_source) as FlowVariableRefValueSource
		var next: FlowVariableRefValueSource = FlowVariableRefValueSource.new(variable_id, variable.value_type)
		if current != null: next.source_id = current.source_id
		if _variable_side == "A": comparison.left_source = next
		else: comparison.right_source = next
		_variable_row_index = -1
		_variable_side = ""
		_rebuild_rows()
		return


func _on_variable_selector_cancelled() -> void:
	_variable_row_index = -1
	_variable_side = ""


func _write_draft_from_rows() -> void:
	if _draft == null: return
	for index: int in mini(_rows.size(), _draft.comparisons.size()):
		var row: Dictionary = _rows[index]
		var menu: OptionButton = row["operator"] as OptionButton
		if menu != null and menu.selected >= 0:
			_draft.comparisons[index].operator_id = StringName(menu.get_item_metadata(menu.selected))
		for side: String in ["A", "B"]:
			var side_data: Dictionary = row["left"] if side == "A" else row["right"]
			var source: FlowValueSource = _draft.comparisons[index].left_source if side == "A" else _draft.comparisons[index].right_source
			var type_menu: OptionButton = side_data.get("type", null) as OptionButton
			var value_control: Control = side_data.get("value", null) as Control
			if type_menu == null or value_control == null or type_menu.selected < 0: continue
			var value_type: Variant.Type = int(type_menu.get_item_metadata(type_menu.selected))
			if value_control is LineEdit and value_type != Variant.Type.TYPE_STRING:
				var text: String = (value_control as LineEdit).text
				if value_type == Variant.Type.TYPE_INT and text.is_valid_int(): source = FlowLiteralValueSource.new(value_type, int(text))
				elif value_type == Variant.Type.TYPE_FLOAT and text.is_valid_float(): source = FlowLiteralValueSource.new(value_type, float(text))
			elif value_control is LineEdit:
				source = FlowLiteralValueSource.new(value_type, (value_control as LineEdit).text)
			elif value_control is OptionButton:
				var bool_menu: OptionButton = value_control as OptionButton
				if bool_menu.selected > 0:
					source = FlowLiteralValueSource.new(value_type, bool(bool_menu.get_item_metadata(bool_menu.selected)))
			if side == "A": _draft.comparisons[index].left_source = source
			else: _draft.comparisons[index].right_source = source
		if index > 0:
			var connector: OptionButton = _rows_box.get_node("Connector%d" % index) as OptionButton
			if connector != null and index - 1 < _draft.connectors.size():
				_draft.connectors[index - 1] = StringName(connector.get_item_metadata(connector.selected))


func _update_preview() -> void:
	if _draft == null: return
	_preview_label.text = _draft.get_preview(_graph)
	_feedback_label.text = _validation_message()
	_confirm_button.disabled = not _feedback_label.text.is_empty()


func _validation_message() -> String:
	if _draft == null: return "Condition draft is missing."
	if not _invalid_literal_inputs.is_empty(): return "Enter a valid literal value."
	var result: FlowValidationResult = _draft.validate_condition(_graph)
	for diagnostic: FlowDiagnostic in result.diagnostics:
		if diagnostic.code == FlowDiagnostic.CODE_CONDITION_SIGNATURE_INCOMPATIBLE:
			var comparison: FlowConditionComparison = _comparison_for_path(diagnostic.element_path)
			if comparison != null:
				return "Cannot compare %s with %s using %s." % [
					_type_name(comparison.left_source.get_value_type()),
					_type_name(comparison.right_source.get_value_type()),
					FlowConditionOperatorCatalog.symbol(comparison.operator_id),
				]
		if diagnostic.severity == FlowDiagnostic.Severity.ERROR: return diagnostic.message
	return ""


func _comparison_for_path(path: String) -> FlowConditionComparison:
	for index: int in _draft.comparisons.size():
		if path.contains("comparisons[%d]" % index): return _draft.comparisons[index]
	return null


func _confirm() -> void:
	_write_draft_from_rows()
	_update_preview()
	if not can_confirm(): return
	_closing_for_action = true
	condition_confirmed.emit(_draft.duplicate_with_new_id() as FlowConditionValueSource)
	hide()


func _cancel() -> void:
	_closing_for_action = false
	hide()


func _on_close_requested() -> void:
	_cancel()


func _on_popup_hide() -> void:
	if not _closing_for_action: cancelled.emit()
	_closing_for_action = false


func _focus_default() -> void:
	if visible and not _rows.is_empty():
		var kind: OptionButton = _rows[0]["left"]["kind"] as OptionButton
		if kind != null: kind.grab_focus()


func _literal_with_preserved_value(current: FlowValueSource, value_type: Variant.Type) -> FlowLiteralValueSource:
	var value: Variant = null
	if current is FlowLiteralValueSource and current.get_value_type() == value_type and (current as FlowLiteralValueSource).is_valid():
		value = (current as FlowLiteralValueSource).get_value()
	return FlowLiteralValueSource.new(value_type, value)


func _literal_bool_value(source: FlowLiteralValueSource) -> bool:
	return source != null and source.get_value_type() == Variant.Type.TYPE_BOOL and bool(source.get_value())


func _literal_text_value(source: FlowLiteralValueSource, value_type: Variant.Type) -> String:
	if source != null and source.get_value_type() == value_type and source.is_valid():
		return str(source.get_value())
	return ""


func _literal_placeholder(value_type: Variant.Type) -> String:
	match value_type:
		Variant.Type.TYPE_INT: return "Integer"
		Variant.Type.TYPE_FLOAT: return "Decimal"
		Variant.Type.TYPE_STRING: return "Text"
	return "Value"


func _variable_button_text(source: FlowVariableRefValueSource) -> String:
	if source == null or source.variable_id.is_empty(): return "Choose variable..."
	if _graph != null:
		var definition: FlowVariableDefinition = source.resolve_definition(_graph)
		if definition != null: return definition.display_name
	return "<missing>"


func _type_name(value_type: Variant.Type) -> String:
	return FlowChipTypeDescriptor.variant_type_display_name(value_type)


func _value_type_enum(value_type: Variant.Type) -> FlowVariableDefinition.ValueType:
	match value_type:
		Variant.Type.TYPE_BOOL: return FlowVariableDefinition.ValueType.BOOL
		Variant.Type.TYPE_INT: return FlowVariableDefinition.ValueType.INT
		Variant.Type.TYPE_FLOAT: return FlowVariableDefinition.ValueType.FLOAT
		Variant.Type.TYPE_STRING: return FlowVariableDefinition.ValueType.STRING
	return FlowVariableDefinition.ValueType.BOOL
