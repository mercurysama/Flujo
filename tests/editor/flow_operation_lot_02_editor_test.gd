extends SceneTree


var _failures: Array[String] = []
var _host: Control
var _undo_redo: EditorUndoRedoManager


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	await _frames(2)
	_undo_redo = EditorInterface.get_editor_undo_redo()
	_check(_undo_redo != null, "Operation editor has one owning Akis history.")
	_host = Control.new()
	_host.size = Vector2(1000.0, 700.0)
	get_root().add_child(_host)
	await _test_tilde_trigger_insert_history()
	await _test_escape_and_reserved_dollar()
	await _test_existing_operation_edit()
	_host.queue_free()
	_finish()


func _test_tilde_trigger_insert_history() -> void:
	var graph: FlowGraph = _graph()
	var document: FlowStructuredDocument = _text_document("Before  after")
	var editor: FlowChipFieldEditor = _new_editor(_operation_schema(), document, graph)
	await _frames(2)
	var text: FlowTextSegment = document.segments[0] as FlowTextSegment
	editor.set_caret_position(text.segment_id, "Before ".length())
	var input: TextEdit = editor.get_text_control(text.segment_id)
	input.insert_text_at_caret("~")
	await _frames(2)

	var popup: FlowOperationEditor = editor.get_operation_editor()
	_check(popup != null and popup.visible, "Typing an unescaped ~ opens Operation Editor.")
	var empty: FlowOperationValueSource = popup.get_draft()
	_check(
		empty != null
			and empty.operator_id.is_empty()
			and empty.operands.size() == 2
			and empty.operands[0] == null
			and empty.operands[1] == null,
		"New Operation draft has no semantic defaults."
	)

	var count: FlowVariableDefinition = graph.variables[0]
	popup.set_draft(FlowOperationValueSource.new(
		&"add",
		[
			FlowVariableRefValueSource.new(count.get_internal_id(), count.value_type),
			FlowLiteralValueSource.new(Variant.Type.TYPE_INT, 1),
		]
	))
	await _frames(1)
	var confirm: Button = popup.find_child("ConfirmOperation", true, false) as Button
	_check(confirm != null and not confirm.disabled, "Valid Count + 1 enables Confirm.")
	if confirm != null:
		confirm.pressed.emit()
	await _frames(2)

	var operation: FlowOperationSegment = _first_operation(document)
	_check(operation != null, "Confirm creates one Operation Tok.")
	_check(
		operation != null and operation.get_chip_label() == "Count + 1",
		"Operation preview resolves the graph variable name."
	)
	_check(
		operation != null
			and operation.slot_id == "value"
			and operation.slot_kind == FlowChipSegment.SLOT_KIND_VARIADIC,
		"Operation insertion preserves variadic slot metadata."
	)
	_check(
		document.segments.size() == 3
			and (document.segments[0] as FlowTextSegment).text == "Before ",
		"Operation insertion removes only the ~ trigger."
	)

	var history: UndoRedo = _history(document)
	history.undo()
	_check(
		_first_operation(document) == null
			and (document.segments[0] as FlowTextSegment).text == "Before  after",
		"Undo removes the Operation action and restores exact text."
	)
	history.redo()
	_check(_first_operation(document) != null, "Redo restores Operation Tok.")
	editor.queue_free()


func _test_escape_and_reserved_dollar() -> void:
	var graph: FlowGraph = _graph()
	var escaped_document: FlowStructuredDocument = _text_document("")
	var escaped_editor: FlowChipFieldEditor = _new_editor(
		_operation_schema(),
		escaped_document,
		graph
	)
	await _frames(2)
	var escaped_text: FlowTextSegment = escaped_document.segments[0] as FlowTextSegment
	var escaped_input: TextEdit = escaped_editor.get_text_control(escaped_text.segment_id)
	escaped_input.insert_text_at_caret("\\~")
	await _frames(2)
	_check(
		escaped_text.text == "~" and not escaped_editor.get_operation_editor().visible,
		"\\~ becomes a literal ~ and does not open Operation Editor."
	)
	escaped_editor.queue_free()

	var dollar_document: FlowStructuredDocument = _text_document("")
	var dollar_editor: FlowChipFieldEditor = _new_editor(
		_operation_schema(),
		dollar_document,
		graph
	)
	await _frames(2)
	var dollar_text: FlowTextSegment = dollar_document.segments[0] as FlowTextSegment
	var dollar_input: TextEdit = dollar_editor.get_text_control(dollar_text.segment_id)
	dollar_input.insert_text_at_caret("$")
	await _frames(2)
	_check(
		dollar_text.text == "$" and not dollar_editor.get_operation_editor().visible,
		"$ remains literal/reserved in Lot 02."
	)
	dollar_editor.queue_free()


func _test_existing_operation_edit() -> void:
	var graph: FlowGraph = _graph()
	var source: FlowOperationValueSource = FlowOperationValueSource.new(
		&"add",
		[_int(2), _int(3)]
	)
	var segment: FlowOperationSegment = FlowOperationSegment.new(source)
	segment.slot_id = "value"
	segment.slot_kind = FlowChipSegment.SLOT_KIND_VARIADIC
	var document: FlowStructuredDocument = FlowStructuredDocument.new()
	document.segments = [FlowTextSegment.new(), segment]
	var editor: FlowChipFieldEditor = _new_editor(_operation_schema(), document, graph)
	await _frames(2)

	var chip: FlowChipControl = editor.get_chip_control(segment.segment_id)
	var enter: InputEventKey = InputEventKey.new()
	enter.keycode = KEY_ENTER
	enter.pressed = true
	chip._gui_input(enter)
	await _frames(2)
	var popup: FlowOperationEditor = editor.get_operation_editor()
	_check(popup.visible, "Enter on Operation Tok opens its editor.")

	popup.set_draft(FlowOperationValueSource.new(
		&"multiply",
		[_int(4), _int(5)]
	))
	await _frames(1)
	var confirm: Button = popup.find_child("ConfirmOperation", true, false) as Button
	if confirm != null:
		confirm.pressed.emit()
	await _frames(2)

	var edited: FlowOperationSegment = _first_operation(document)
	_check(
		edited != null
			and edited.segment_id == segment.segment_id
			and (edited.get_value_source() as FlowOperationValueSource).get_preview(graph) == "4 * 5",
		"Editing Operation preserves segment_id and changes semantic content."
	)
	var history: UndoRedo = _history(document)
	history.undo()
	var undone: FlowOperationSegment = _first_operation(document)
	_check(
		undone != null
			and (undone.get_value_source() as FlowOperationValueSource).get_preview(graph) == "2 + 3",
		"Undo restores previous Operation content."
	)
	history.redo()
	var redone: FlowOperationSegment = _first_operation(document)
	_check(
		redone != null
			and (redone.get_value_source() as FlowOperationValueSource).get_preview(graph) == "4 * 5",
		"Redo restores edited Operation content."
	)
	editor.queue_free()


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


func _operation_schema() -> FlowChipFieldSchema:
	var field: FlowChipFieldSchema = FlowChipFieldSchema.new()
	field.mode = FlowChipFieldSchema.Mode.FLEXIBLE
	field.text_mode = FlowChipFieldSchema.TextMode.RUNTIME_CONTENT
	field.accepted_value_types = [
		Variant.Type.TYPE_INT,
		Variant.Type.TYPE_FLOAT,
		Variant.Type.TYPE_STRING,
		Variant.Type.TYPE_VECTOR2,
		Variant.Type.TYPE_VECTOR3,
	]
	field.accepted_source_kinds = [FlowValueSource.SOURCE_KIND_OPERATION]
	field.flexible_max_count = 4
	var slot: FlowChipSlotDefinition = FlowChipSlotDefinition.new("value", "Value")
	slot.repeatable = true
	slot.max_count = 4
	slot.accepted_value_types = field.accepted_value_types.duplicate()
	slot.accepted_source_kinds = [FlowValueSource.SOURCE_KIND_OPERATION]
	field.variadic_slot_definition = slot
	field.add_text_part("")
	field.add_slot_part("value")
	return field


func _graph() -> FlowGraph:
	var graph: FlowGraph = FlowGraph.new()
	var count: FlowVariableDefinition = FlowVariableDefinition.new()
	count.display_name = "Count"
	count.value_type = FlowVariableDefinition.ValueType.INT
	count.int_value = 10
	var message: FlowVariableDefinition = FlowVariableDefinition.new()
	message.display_name = "Message"
	message.value_type = FlowVariableDefinition.ValueType.STRING
	message.string_value = "Hello"
	graph.variables = [count, message]
	return graph


func _text_document(value: String) -> FlowStructuredDocument:
	var document: FlowStructuredDocument = FlowStructuredDocument.new()
	var text: FlowTextSegment = FlowTextSegment.new()
	text.text = value
	document.segments = [text]
	return document


func _first_operation(document: FlowStructuredDocument) -> FlowOperationSegment:
	for segment: FlowDocumentSegment in document.segments:
		if segment is FlowOperationSegment:
			return segment as FlowOperationSegment
	return null


func _int(value: int) -> FlowLiteralValueSource:
	return FlowLiteralValueSource.new(Variant.Type.TYPE_INT, value)


func _history(document: FlowStructuredDocument) -> UndoRedo:
	return _undo_redo.get_history_undo_redo(
		_undo_redo.get_object_history_id(document)
	)


func _frames(count: int = 1) -> void:
	for _index: int in count:
		await process_frame


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
		push_error("[Flujo] Operation editor check failed: " + message)


func _finish() -> void:
	if _failures.is_empty():
		print("[Flujo] Operation Tok Lot 02 editor test passed")
	else:
		push_error(
			"[Flujo] Operation Tok Lot 02 editor test failed: %d failures" 				% _failures.size()
		)
	quit(0 if _failures.is_empty() else 1)
