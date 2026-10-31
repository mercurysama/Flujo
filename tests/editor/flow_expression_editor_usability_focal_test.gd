extends SceneTree


const SAVE_ROOT: String = "res://.godot/flujo_tests/expression_editor_focal"
const SAVE_PATH: String = SAVE_ROOT + "/float_document.tres"

var _failures: Array[String] = []
var _host: Control
var _confirmed_source: FlowExpressionValueSource


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	await _frames(24)
	_host = Control.new()
	_host.size = Vector2(1000.0, 700.0)
	get_root().add_child(_host)
	var graph: FlowGraph = _graph()
	var popup: FlowExpressionEditor = FlowExpressionEditor.new()
	_host.add_child(popup)
	popup.expression_confirmed.connect(_on_expression_confirmed)
	popup.open_for_expression(
		FlowExpressionValueSource.new(&"add", [
			FlowLiteralValueSource.new(FlowLiteralValueSource.TYPE_FLOAT, 0.0),
			FlowLiteralValueSource.new(FlowLiteralValueSource.TYPE_FLOAT, 0.0),
		]),
		graph,
		Rect2(40.0, 40.0, 10.0, 10.0)
	)
	await _frames(2)
	var float_input: LineEdit = popup.find_child("Operand1Value", true, false) as LineEdit
	_check(float_input != null, "Float Literal exposes a LineEdit.")
	if float_input != null:
		_set_text(float_input, "1.5")
		_check(popup.get_draft().get_preview(graph) == "0.0 + 1.5",
			"Float preview updates to 1.5 without integer conversion.")
		_set_text(float_input, "-2.25")
		_check(popup.get_draft().get_preview(graph) == "0.0 + -2.25",
			"Float preview updates to -2.25 without resetting to zero.")
		_set_text(float_input, "0.01")
		_check(popup.get_draft().get_preview(graph) == "0.0 + 0.01",
			"Float preview preserves the decimal 0.01.")
		var edited: FlowLiteralValueSource = popup.get_draft().operands[1] as FlowLiteralValueSource
		_check(edited != null and edited.get_value_type() == FlowLiteralValueSource.TYPE_FLOAT \
				and edited.get_value() == 0.01,
			"Float draft stores a Variant float after text_changed.")

	# Operations are driven by the catalog; no new editor implementation
	# or parallel type selector should be necessary.
	var operator_menu: OptionButton = popup.find_child("ExpressionOperator", true, false) as OptionButton
	var found: Dictionary = {}
	if operator_menu != null:
		for menu_index: int in operator_menu.item_count:
			found[String(operator_menu.get_item_metadata(menu_index))] = true
	for new_id: String in ["subtract", "multiply", "divide", "modulo", "concat"]:
		_check(found.has(new_id), "Expression UI lists the new %s operation." % new_id)
	var float_source: FlowExpressionValueSource = popup.get_draft().duplicate_with_new_id() \
		as FlowExpressionValueSource
	_check(float_source.is_valid(), "The edited float expression remains confirmable.")
	var confirm: Button = popup.find_child("ConfirmExpression", true, false) as Button
	if confirm != null:
		confirm.pressed.emit()
	await _frames(1)
	_check(_confirmed_source != null and _confirmed_source.get_preview(graph) == "0.0 + 0.01",
		"Confirm emits the edited float source without loss of precision.")
	if _confirmed_source != null:
		popup.open_for_expression(_confirmed_source, graph, Rect2(40.0, 40.0, 10.0, 10.0))
		await _frames(1)
		_check(popup.get_draft().get_preview(graph) == "0.0 + 0.01",
			"Reopening the confirmed draft keeps the exact float preview.")
	popup.set_draft(FlowExpressionValueSource.new(&"add", [
		FlowLiteralValueSource.new(FlowLiteralValueSource.TYPE_INT, 0),
		FlowLiteralValueSource.new(FlowLiteralValueSource.TYPE_INT, 25),
	]))
	await _frames(1)
	var kind: OptionButton = popup.find_child("Operand0SourceKind", true, false) as OptionButton
	if kind != null:
		kind.select(1)
		kind.item_selected.emit(1)
	await _frames(1)
	var choose: Button = popup.find_child("Operand0Choose", true, false) as Button
	_check(choose != null and choose.visible and choose.text == "Choose variable",
		"Variable source reactively exposes Choose variable.")
	if choose != null:
		choose.pressed.emit()
	await _frames(1)
	var selector: FlowVariableSelector = popup.find_child("FlowVariableSelector", true, false) as FlowVariableSelector
	_check(selector != null and selector.visible, "Compatible variable selector opens immediately.")
	if selector != null:
		var visible_ids: Array[String] = selector.get_visible_variable_ids()
		_check(visible_ids.has(_variable_id(graph, "Count")) \
				and visible_ids.has(_variable_id(graph, "Health")) \
				and not visible_ids.has(_variable_id(graph, "Enabled")) \
				and not visible_ids.has(_variable_id(graph, "Message")),
			"Int signature filters out bool and String variables.")
		_select_variable(selector, "Count", graph)
	await _frames(1)
	var count_source: FlowVariableRefValueSource = \
		popup.get_draft().operands[0] as FlowVariableRefValueSource
	_check(count_source != null and FlowId.is_valid(count_source.source_id) \
				and count_source.variable_id == _variable_id(graph, "Count") \
				and count_source.declared_value_type == FlowVariableDefinition.ValueType.INT,
		"Count selection binds source_id, variable_id, and declared int type.")
	_check(popup.get_draft().get_preview(graph) == "Count + 25" and popup.can_confirm(),
		"Count resolves immediately to Count + 25 and remains confirmable.")
	var count_source_id: String = count_source.source_id
	var change_button: Button = popup.find_child("Operand0Choose", true, false) as Button
	if change_button != null:
		change_button.pressed.emit()
	await _frames(1)
	var selector_again: FlowVariableSelector = popup.find_child(
		"FlowVariableSelector", true, false
	) as FlowVariableSelector
	_check(selector_again != null and selector_again.visible,
		"The rebuilt VariableRef row reopens the selector.")
	if selector_again != null:
		_select_variable(selector_again, "Health", graph)
	await _frames(1)
	var health_source: FlowVariableRefValueSource = \
		popup.get_draft().operands[0] as FlowVariableRefValueSource
	_check(health_source != null and health_source.source_id == count_source_id \
				and popup.get_draft().get_preview(graph) == "Health + 25",
		"Changing Count to Health updates preview and preserves source identity.")
	await _test_variable_change_history(graph)

	var float_segment: FlowExpressionSegment = FlowExpressionSegment.new(float_source)
	float_segment.slot_id = "value"
	float_segment.slot_kind = FlowChipSegment.SLOT_KIND_VARIADIC
	var document: FlowStructuredDocument = FlowStructuredDocument.new()
	document.segments = [float_segment]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SAVE_ROOT))
	_check(ResourceSaver.save(document, SAVE_PATH) == OK, "Float focal saves through ResourceSaver.")
	var loaded: FlowStructuredDocument = ResourceLoader.load(
		SAVE_PATH, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP
	) as FlowStructuredDocument
	var loaded_segment: FlowExpressionSegment = \
		loaded.segments[0] as FlowExpressionSegment if loaded != null else null
	var loaded_source: FlowExpressionValueSource = \
		loaded_segment.get_value_source() as FlowExpressionValueSource \
		if loaded_segment != null else null
	_check(loaded_source != null and loaded_source.get_preview() == "0.0 + 0.01" \
				and (loaded_source.operands[1] as FlowLiteralValueSource).get_value() == 0.01,
		"ResourceLoader preserves the float draft and regenerated preview.")
	popup.queue_free()
	_host.queue_free()
	_finish()


func _test_variable_change_history(graph: FlowGraph) -> void:
	var document: FlowStructuredDocument = FlowStructuredDocument.new()
	var segment: FlowExpressionSegment = FlowExpressionSegment.new(
		FlowExpressionValueSource.new(&"add", [
			FlowVariableRefValueSource.new(_variable_id(graph, "Count"), FlowVariableDefinition.ValueType.INT),
			FlowLiteralValueSource.new(FlowLiteralValueSource.TYPE_INT, 25),
		])
	)
	segment.slot_id = "value"
	segment.slot_kind = FlowChipSegment.SLOT_KIND_VARIADIC
	document.segments = [segment]
	var editor: FlowChipFieldEditor = FlowChipFieldEditor.new()
	editor.size = Vector2(900.0, 600.0)
	_host.add_child(editor)
	var manager: EditorUndoRedoManager = EditorInterface.get_editor_undo_redo()
	editor.configure_field(null, document, manager, document)
	editor.set_variable_graph(graph)
	await _frames(2)
	_check(editor._on_expression_edit_requested(segment.segment_id),
		"Existing Expression Tok opens for variable binding edit.")
	await _frames(1)
	var popup: FlowExpressionEditor = editor.get_expression_editor()
	popup.set_draft(FlowExpressionValueSource.new(&"add", [
		FlowVariableRefValueSource.new(_variable_id(graph, "Health"), FlowVariableDefinition.ValueType.INT),
		FlowLiteralValueSource.new(FlowLiteralValueSource.TYPE_INT, 25),
	]))
	var confirm: Button = popup.find_child("ConfirmExpression", true, false) as Button
	if confirm != null:
		confirm.pressed.emit()
	await _frames(2)
	var changed: FlowExpressionSegment = document.segments[0] as FlowExpressionSegment
	_check((changed.get_value_source() as FlowExpressionValueSource).get_preview(graph) == "Health + 25",
		"Confirmed Count to Health edit is persisted in the document.")
	var history: UndoRedo = manager.get_history_undo_redo(manager.get_object_history_id(document))
	history.undo()
	_check((document.segments[0] as FlowExpressionSegment).get_value_source().get_preview(graph) == "Count + 25",
		"Undo restores the Count binding.")
	history.redo()
	_check((document.segments[0] as FlowExpressionSegment).get_value_source().get_preview(graph) == "Health + 25",
		"Redo restores the Health binding and literal.")
	editor.queue_free()


func _on_expression_confirmed(source: FlowExpressionValueSource) -> void:
	_confirmed_source = source


func _set_text(input: LineEdit, value: String) -> void:
	input.text = value
	input.text_changed.emit(value)


func _select_variable(selector: FlowVariableSelector, name: String, graph: FlowGraph) -> void:
	for index: int in selector.get_variable_list().item_count:
		var variable_id: String = String(selector.get_variable_list().get_item_metadata(index))
		if _variable_name(graph, variable_id) == name:
			selector.get_variable_list().select(index)
			selector.get_variable_list().item_activated.emit(index)
			return


func _graph() -> FlowGraph:
	var graph: FlowGraph = FlowGraph.new()
	graph.variables = [
		_variable("Count", FlowVariableDefinition.ValueType.INT),
		_variable("Health", FlowVariableDefinition.ValueType.INT),
		_variable("Enabled", FlowVariableDefinition.ValueType.BOOL),
		_variable("Message", FlowVariableDefinition.ValueType.STRING),
	]
	return graph


func _variable(name: String, value_type: FlowVariableDefinition.ValueType) -> FlowVariableDefinition:
	var variable: FlowVariableDefinition = FlowVariableDefinition.new()
	variable.display_name = name
	variable.value_type = value_type
	return variable


func _variable_id(graph: FlowGraph, name: String) -> String:
	for variable: FlowVariableDefinition in graph.variables:
		if variable != null and variable.display_name == name:
			return variable.get_internal_id()
	return ""


func _variable_name(graph: FlowGraph, variable_id: String) -> String:
	for variable: FlowVariableDefinition in graph.variables:
		if variable != null and variable.get_internal_id() == variable_id:
			return variable.display_name
	return ""


func _frames(count: int = 1) -> void:
	for _index: int in count:
		await process_frame


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	_failures.append(message)
	push_error("[Flujo] Expression usability focal failed: " + message)


func _finish() -> void:
	if _failures.is_empty():
		print("[Flujo] Expression usability focal passed")
	else:
		push_error("[Flujo] Expression usability focal failed: %d failures" % _failures.size())
	quit(0 if _failures.is_empty() else 1)
