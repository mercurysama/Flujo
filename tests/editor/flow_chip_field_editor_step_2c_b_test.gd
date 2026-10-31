extends SceneTree


var _failures: Array[String] = []
var _host: Control
var _undo_redo: EditorUndoRedoManager


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	await _frames(2)
	_undo_redo = EditorInterface.get_editor_undo_redo()
	_check(_undo_redo != null, "Expression editor has one owning Akis history.")
	_host = Control.new()
	_host.size = Vector2(1000.0, 700.0)
	get_root().add_child(_host)
	await _test_expression_editor_usability()
	await _test_existing_expression_edit()
	await _test_float_save_load_round_trip()
	_host.queue_free()
	_finish()


func _test_hash_trigger_insert_and_undo() -> void:
	var graph: FlowGraph = _graph()
	var document: FlowStructuredDocument = _text_document("Before  after")
	var editor: FlowChipFieldEditor = _new_editor(_expression_schema(), document, graph)
	await _frames(2)
	var text: FlowTextSegment = document.segments[0] as FlowTextSegment
	editor.set_caret_position(text.segment_id, "Before ".length())
	var input: TextEdit = editor.get_text_control(text.segment_id)
	input.insert_text_at_caret("#")
	await _frames(2)
	var popup: FlowExpressionEditor = editor.get_expression_editor()
	_check(popup.visible, "Typing an unescaped # opens the Expression Editor.")
	var count: FlowVariableDefinition = graph.variables[0]
	popup.set_draft(FlowExpressionValueSource.new(
		&"add",
		[
			FlowVariableRefValueSource.new(count.get_internal_id(), count.value_type),
			FlowLiteralValueSource.new(FlowLiteralValueSource.TYPE_INT, 1),
		]
	))
	var confirm: Button = popup.find_child("ConfirmExpression", true, false) as Button
	_check(confirm != null and not confirm.disabled, "A valid typed signature enables Confirm.")
	if confirm != null:
		confirm.pressed.emit()
	await _frames(2)
	var expression: FlowExpressionSegment = _first_expression(document)
	_check(expression != null, "Confirm creates exactly one Expression Tok.")
	_check(expression != null and expression.get_chip_label() == "Count + 1",
		"Preview resolves graph variable names only as a presentation projection.")
	_check(expression != null and expression.get_slot_id() == "value" \
			and expression.get_slot_kind() == FlowChipSegment.SLOT_KIND_VARIADIC,
		"Expression insertion carries the declared variadic zone slot_id and slot kind.")
	_check(document.segments.size() == 3 and (document.segments[0] as FlowTextSegment).text == "Before ",
		"Expression insertion removes only the trigger and preserves the exact suffix boundary.")
	if expression != null:
		var tooltip: String = editor.get_chip_control(expression.segment_id).tooltip_text
		_check(tooltip.contains("Type: Expression") and tooltip.contains("Result Type: int") \
				and tooltip.contains("Inputs:"), "Expression tooltip exposes structured fields.")
	var history: UndoRedo = _history(document)
	history.undo()
	_check(_first_expression(document) == null and (document.segments[0] as FlowTextSegment).text == "Before  after",
		"Undo removes the one confirmed Expression action and restores text.")
	history.redo()
	_check(_first_expression(document) != null, "Redo restores the Expression Tok.")
	editor.queue_free()


func _test_hash_escape_and_cancel() -> void:
	var graph: FlowGraph = _graph()
	var escaped_document: FlowStructuredDocument = _text_document("")
	var escaped_editor: FlowChipFieldEditor = _new_editor(_expression_schema(), escaped_document, graph)
	await _frames(2)
	var escaped_input: TextEdit = escaped_editor.get_text_control(
		(escaped_document.segments[0] as FlowTextSegment).segment_id
	)
	escaped_input.insert_text_at_caret("\\#")
	await _frames(2)
	_check((escaped_document.segments[0] as FlowTextSegment).text == "#" \
			and not escaped_editor.get_expression_editor().visible,
		"\\# becomes a literal # and never opens the Expression Editor.")
	escaped_editor.queue_free()

	var cancel_document: FlowStructuredDocument = _text_document("Unicode ñ 日本")
	var cancel_editor: FlowChipFieldEditor = _new_editor(_expression_schema(), cancel_document, graph)
	await _frames(2)
	var cancel_text: FlowTextSegment = cancel_document.segments[0] as FlowTextSegment
	cancel_editor.set_caret_position(cancel_text.segment_id, "Unicode ".length())
	var cancel_input: TextEdit = cancel_editor.get_text_control(cancel_text.segment_id)
	cancel_input.insert_text_at_caret("#")
	await _frames(2)
	var version_before: int = _history(cancel_document).get_version()
	var cancel_button: Button = cancel_editor.get_expression_editor().find_child(
		"CancelExpression", true, false
	) as Button
	if cancel_button != null:
		cancel_button.pressed.emit()
	await _frames(2)
	_check(cancel_text.text == "Unicode ñ 日本" and cancel_editor.get_caret_offset() == "Unicode ".length(),
		"Expression cancellation restores Unicode text and the exact semantic caret.")
	_check(_history(cancel_document).get_version() == version_before,
		"Expression cancellation creates no history action.")
	cancel_editor.queue_free()


func _test_existing_expression_edit() -> void:
	var graph: FlowGraph = _graph()
	var source: FlowExpressionValueSource = FlowExpressionValueSource.new(
		&"greater_than", [_literal_int(2), _literal_int(0)]
	)
	var segment: FlowExpressionSegment = FlowExpressionSegment.new(source)
	segment.slot_id = "value"
	var document: FlowStructuredDocument = FlowStructuredDocument.new()
	document.segments = [FlowTextSegment.new(), segment]
	var editor: FlowChipFieldEditor = _new_editor(_expression_schema(), document, graph)
	await _frames(2)
	var chip: FlowChipControl = editor.get_chip_control(segment.segment_id)
	var enter: InputEventKey = InputEventKey.new()
	enter.keycode = KEY_ENTER
	enter.pressed = true
	chip._gui_input(enter)
	await _frames(2)
	_check(editor.get_expression_editor().visible, "Enter on an Expression Tok opens its editor.")
	var history: UndoRedo = _history(document)
	var version_before: int = history.get_version()
	var confirm: Button = editor.get_expression_editor().find_child(
		"ConfirmExpression", true, false
	) as Button
	editor.get_expression_editor().set_draft(FlowExpressionValueSource.new(
		&"greater_than", [
			FlowVariableRefValueSource.new(_variable_id(graph, "Health"), FlowVariableDefinition.ValueType.INT),
			_literal_int(0),
		]
	))
	var value: LineEdit = editor.get_expression_editor().find_child(
		"Operand1Value", true, false
	) as LineEdit
	if value != null:
		value.text = "10"
	if confirm != null:
		confirm.pressed.emit()
	await _frames(2)
	var edited: FlowExpressionSegment = _first_expression(document)
	_check(edited != null and edited.segment_id == segment.segment_id \
			and (edited.get_value_source() as FlowExpressionValueSource).get_preview(graph) == "Health > 10",
		"Editing an existing Tok changes its literal value and preserves segment_id.")
	_check(history.get_version() == version_before + 1, "Expression edit creates one history action.")
	history.undo()
	var undone: FlowExpressionSegment = _first_expression(document)
	_check(undone != null and (undone.get_value_source() as FlowExpressionValueSource).get_preview(graph) == "2 > 0",
		"Undo restores the original existing Expression Tok content.")
	history.redo()
	var redone: FlowExpressionSegment = _first_expression(document)
	_check(redone != null and (redone.get_value_source() as FlowExpressionValueSource).get_preview(graph) == "Health > 10",
		"Redo restores the edited Expression Tok content.")
	editor.queue_free()


func _test_expression_editor_usability() -> void:
	var graph: FlowGraph = _graph()
	var schema: FlowChipFieldSchema = _expression_schema()
	var popup: FlowExpressionEditor = FlowExpressionEditor.new()
	_host.add_child(popup)
	popup.open_for_expression(
		FlowExpressionValueSource.new(
			&"add", [_literal_int(0), _literal_int(1)]
		),
		graph,
		Rect2(40.0, 40.0, 10.0, 10.0),
		{"schema": schema, "slot": schema.variadic_slot_definition}
	)
	await _frames(2)
	var int_editor: LineEdit = popup.find_child("Operand1Value", true, false) as LineEdit
	_check(int_editor != null, "int Literal renders an editable value field.")
	if int_editor != null:
		int_editor.text = "25"
		int_editor.text_changed.emit("25")
	_check(popup.get_draft().get_preview(graph) == "0 + 25",
		"Editing an int Literal updates the detached draft and preview immediately.")
	popup.set_draft(FlowExpressionValueSource.new(
		&"add", [
			FlowLiteralValueSource.new(FlowLiteralValueSource.TYPE_FLOAT, 0.0),
			FlowLiteralValueSource.new(FlowLiteralValueSource.TYPE_FLOAT, 1.5),
		]
	))
	var float_editor: LineEdit = popup.find_child("Operand1Value", true, false) as LineEdit
	_check(float_editor != null, "float Literal renders an editable value field.")
	if float_editor != null:
		float_editor.text = "-2.25"
		float_editor.text_changed.emit("-2.25")
	_check(popup.get_draft().get_preview(graph) == "0.0 + -2.25",
		"Editing a float Literal accepts decimal and negative values.")
	popup.set_draft(FlowExpressionValueSource.new(
		&"add", [_literal_int(0), _literal_int(25)]
	))
	await _frames(1)

	var kind_menu: OptionButton = popup.find_child("Operand0SourceKind", true, false) as OptionButton
	if kind_menu != null:
		kind_menu.select(1)
		kind_menu.item_selected.emit(1)
	await _frames(1)
	var choose: Button = popup.find_child("Operand0Choose", true, false) as Button
	_check(choose != null and choose.visible and choose.text == "Choose variable",
		"Selecting Variable rebuilds the same row and shows Choose variable immediately.")
	if choose != null:
		choose.pressed.emit()
		await _frames(1)
		var selector: FlowVariableSelector = popup.find_child("FlowVariableSelector", true, false) as FlowVariableSelector
		_check(selector != null and selector.get_variable_list().item_count > 0,
			"Variable source opens the compatible variable selector without another UI change.")
		if selector != null:
			var visible_ids: Array[String] = selector.get_visible_variable_ids()
			_check(visible_ids.has(_variable_id(graph, "Count")) \
					and visible_ids.has(_variable_id(graph, "Health")) \
					and not visible_ids.has(_variable_id(graph, "Enabled")) \
					and not visible_ids.has(_variable_id(graph, "Message")),
				"Variable selector keeps only variables compatible with the active int signature.")
			_select_variable(selector, "Count", graph)
		await _frames(1)
	var count_source: FlowVariableRefValueSource = \
		popup.get_draft().operands[0] as FlowVariableRefValueSource
	_check(count_source != null and not count_source.source_id.is_empty() \
				and count_source.variable_id == _variable_id(graph, "Count") \
				and count_source.declared_value_type == FlowVariableDefinition.ValueType.INT,
		"Choosing Count writes one valid graph-owned VariableRef source into the draft.")
	_check(popup.get_draft().get_preview(graph) == "Count + 25",
		"Choosing a compatible variable updates the expression preview.")
	var change_choose: Button = popup.find_child("Operand0Choose", true, false) as Button
	if change_choose != null:
		change_choose.pressed.emit()
		await _frames(1)
		var selector_again: FlowVariableSelector = popup.find_child(
			"FlowVariableSelector", true, false
		) as FlowVariableSelector
		_check(selector_again != null and selector_again.visible,
			"The current VariableRef row reopens the reusable selector for a binding change.")
		if selector_again != null:
			_select_variable(selector_again, "Health", graph)
		await _frames(1)
	_check(popup.get_draft().get_preview(graph) == "Health + 25",
		"Choosing Health replaces the same draft operand without changing the literal.")

	popup.set_draft(FlowExpressionValueSource.new(
		&"greater_than", [
			FlowVariableRefValueSource.new(_variable_id(graph, "Health"), FlowVariableDefinition.ValueType.INT),
			_literal_int(0),
		]
	))
	var health_value: LineEdit = popup.find_child("Operand1Value", true, false) as LineEdit
	if health_value != null:
		health_value.text = "10"
		health_value.text_changed.emit("10")
	_check(popup.get_draft().get_preview(graph) == "Health > 10",
		"Health > 0 can edit its int Literal value to Health > 10.")

	popup.set_draft(FlowExpressionValueSource.new(
		&"and", [
			FlowVariableRefValueSource.new(_variable_id(graph, "Enabled"), FlowVariableDefinition.ValueType.BOOL),
			FlowVariableRefValueSource.new(_variable_id(graph, "Visible"), FlowVariableDefinition.ValueType.BOOL),
		]
	))
	_check(popup.get_draft().get_preview(graph) == "Enabled AND Visible" and popup.can_confirm(),
		"Enabled AND Visible is constructible with two compatible VariableRef operands.")

	popup.set_draft(FlowExpressionValueSource.new(
		&"add", [
			FlowVariableRefValueSource.new(_variable_id(graph, "Message"), FlowVariableDefinition.ValueType.STRING),
			FlowLiteralValueSource.new(FlowLiteralValueSource.TYPE_STRING, "!"),
		]
	))
	var string_value: LineEdit = popup.find_child("Operand1Value", true, false) as LineEdit
	var unicode_value: String = "¡Hola! 😀 @#$\\"
	_check(string_value != null, "String Literal renders an editable text field.")
	if string_value != null:
		string_value.text = unicode_value
		string_value.text_changed.emit(unicode_value)
	_check(popup.get_draft().get_preview(graph) == 'Message + "¡Hola! 😀 @#$\\"',
		"String Literal accepts Unicode and @/#/$/backslash as content and previews with quotes.")

	popup.set_draft(FlowExpressionValueSource.new(
		&"equal", [_literal_bool(false), _literal_bool(false)]
	))
	var bool_value: CheckButton = popup.find_child("Operand0BoolValue", true, false) as CheckButton
	_check(bool_value != null, "bool Literal renders a clear toggle control.")
	if bool_value != null:
		bool_value.button_pressed = true
		bool_value.toggled.emit(true)
	_check((popup.get_draft().operands[0] as FlowLiteralValueSource).get_value() == true,
		"bool Literal toggle updates the detached draft.")
	popup.hide()
	popup.queue_free()


func _select_variable(selector: FlowVariableSelector, name: String, graph: FlowGraph) -> void:
	var list: ItemList = selector.get_variable_list()
	for index: int in list.item_count:
		var variable_id: String = String(list.get_item_metadata(index))
		if _variable_name(graph, variable_id) == name:
			list.select(index)
			list.item_activated.emit(index)
			return


func _variable_name(graph: FlowGraph, variable_id: String) -> String:
	for variable: FlowVariableDefinition in graph.variables:
		if variable != null and variable.get_internal_id() == variable_id:
			return variable.display_name
	return ""


func _variable_id(graph: FlowGraph, name: String) -> String:
	for variable: FlowVariableDefinition in graph.variables:
		if variable != null and variable.display_name == name:
			return variable.get_internal_id()
	return ""


func _new_editor(
		field: FlowChipFieldSchema,
		document: FlowStructuredDocument,
		graph: FlowGraph
) -> FlowChipFieldEditor:
	var editor: FlowChipFieldEditor = FlowChipFieldEditor.new()
	editor.size = Vector2(900.0, 560.0)
	_host.add_child(editor)
	editor.configure_field(field, document, _undo_redo, document)
	editor.set_variable_graph(graph)
	return editor


func _expression_schema() -> FlowChipFieldSchema:
	var field: FlowChipFieldSchema = FlowChipFieldSchema.new()
	field.mode = FlowChipFieldSchema.Mode.FLEXIBLE
	field.text_mode = FlowChipFieldSchema.TextMode.RUNTIME_CONTENT
	field.accepted_value_types = [
		Variant.Type.TYPE_BOOL,
		Variant.Type.TYPE_INT,
		Variant.Type.TYPE_FLOAT,
		Variant.Type.TYPE_STRING,
	]
	field.accepted_source_kinds = [FlowValueSource.SOURCE_KIND_EXPRESSION]
	field.flexible_max_count = 4
	var slot: FlowChipSlotDefinition = FlowChipSlotDefinition.new("value", "Value")
	slot.repeatable = true
	slot.max_count = 4
	slot.accepted_value_types = field.accepted_value_types.duplicate()
	slot.accepted_source_kinds = [FlowValueSource.SOURCE_KIND_EXPRESSION]
	field.variadic_slot_definition = slot
	field.add_text_part("")
	field.add_slot_part("value")
	return field


func _graph() -> FlowGraph:
	var graph: FlowGraph = FlowGraph.new()
	graph.variables = [
		_test_variable("Count", FlowVariableDefinition.ValueType.INT),
		_test_variable("Health", FlowVariableDefinition.ValueType.INT),
		_test_variable("Enabled", FlowVariableDefinition.ValueType.BOOL),
		_test_variable("Visible", FlowVariableDefinition.ValueType.BOOL),
		_test_variable("Message", FlowVariableDefinition.ValueType.STRING),
	]
	return graph


func _test_variable(name: String, value_type: FlowVariableDefinition.ValueType) -> FlowVariableDefinition:
	var variable: FlowVariableDefinition = FlowVariableDefinition.new()
	variable.display_name = name
	variable.value_type = value_type
	return variable


func _text_document(value: String) -> FlowStructuredDocument:
	var document: FlowStructuredDocument = FlowStructuredDocument.new()
	var text: FlowTextSegment = FlowTextSegment.new()
	text.text = value
	document.segments = [text]
	return document


func _first_expression(document: FlowStructuredDocument) -> FlowExpressionSegment:
	for segment: FlowDocumentSegment in document.segments:
		if segment is FlowExpressionSegment:
			return segment as FlowExpressionSegment
	return null


func _test_float_save_load_round_trip() -> void:
	var source: FlowExpressionValueSource = FlowExpressionValueSource.new(
		&"add", [
			FlowLiteralValueSource.new(FlowLiteralValueSource.TYPE_FLOAT, 0.01),
			FlowLiteralValueSource.new(FlowLiteralValueSource.TYPE_FLOAT, -2.25),
		]
	)
	var segment: FlowExpressionSegment = FlowExpressionSegment.new(source)
	segment.slot_id = "value"
	segment.slot_kind = FlowChipSegment.SLOT_KIND_VARIADIC
	var document: FlowStructuredDocument = FlowStructuredDocument.new()
	document.segments = [segment]
	var root: String = "res://.godot/flujo_tests/expression_editor_focal"
	var path: String = root + "/float_document.tres"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(root))
	_check(ResourceSaver.save(document, path) == OK,
		"Float focal saves through ResourceSaver.")
	var loaded: FlowStructuredDocument = ResourceLoader.load(
		path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP
	) as FlowStructuredDocument
	var loaded_segment: FlowExpressionSegment = \
		loaded.segments[0] as FlowExpressionSegment if loaded != null else null
	var loaded_source: FlowExpressionValueSource = \
		loaded_segment.get_value_source() as FlowExpressionValueSource \
		if loaded_segment != null else null
	_check(loaded_source != null and loaded_source.get_preview() == "0.01 + -2.25" \
				and (loaded_source.operands[0] as FlowLiteralValueSource).get_value() == 0.01 \
				and (loaded_source.operands[1] as FlowLiteralValueSource).get_value() == -2.25,
		"Float focal reload preserves 0.01 and -2.25 exactly as float operands.")


func _literal_int(value: int) -> FlowLiteralValueSource:
	return FlowLiteralValueSource.new(FlowLiteralValueSource.TYPE_INT, value)


func _literal_bool(value: bool) -> FlowLiteralValueSource:
	return FlowLiteralValueSource.new(FlowLiteralValueSource.TYPE_BOOL, value)


func _history(document: FlowStructuredDocument) -> UndoRedo:
	return _undo_redo.get_history_undo_redo(_undo_redo.get_object_history_id(document))


func _frames(count: int = 1) -> void:
	for _index: int in count:
		await process_frame


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
		push_error("[Flujo] Expression editor check failed: " + message)


func _finish() -> void:
	if _failures.is_empty():
		print("[Flujo] Flow Expression Step 2C-B editor test passed")
	else:
		push_error("[Flujo] Flow Expression Step 2C-B editor test failed: %d failures" % _failures.size())
	quit(0 if _failures.is_empty() else 1)
