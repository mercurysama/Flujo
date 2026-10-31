extends SceneTree


var _failures: Array[String] = []
var _host: Control
var _undo_redo: EditorUndoRedoManager


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	# Do not create the first action while the editor is still restoring its
	# layout; that startup work can legitimately invalidate editor histories.
	await _frames(24)
	_undo_redo = EditorInterface.get_editor_undo_redo()
	_check(_undo_redo != null, "Step 2C-A.2 has an EditorUndoRedoManager.")
	if _undo_redo == null:
		_finish()
		return
	_host = Control.new()
	_host.name = &"FlowChipFieldStep2CA2TestHost"
	_host.size = Vector2(1100.0, 800.0)
	get_root().add_child(_host)

	await _test_global_shortcuts_and_required_literal()
	await _test_string_and_string_name_line_edit_history()
	await _test_mixed_history_and_variable_projection()

	_host.queue_free()
	_finish()


func _test_global_shortcuts_and_required_literal() -> void:
	var field: FlowChipFieldSchema = _literal_schema(Variant.Type.TYPE_INT)
	var document: FlowStructuredDocument = FlowStructuredDocument.new()
	var text: FlowTextSegment = FlowTextSegment.new()
	text.text = "Akis text"
	var literal: FlowLiteralValueSegment = FlowLiteralValueSegment.new(
		FlowLiteralValueSource.TYPE_INT,
		0
	)
	literal.set_slot_id("value")
	literal.set_slot_kind(FlowChipSegment.SLOT_KIND_VARIADIC)
	document.segments = [text, literal]
	var editor: FlowChipFieldEditor = _new_editor(field, document, null)
	await _frames()
	editor.select_segment(literal.get_segment_id())
	_check(editor.set_selected_chip_value(25), "Required Literal Tok accepts value editing.")
	_check(not editor.delete_selected_chip(), "Required Literal Tok remains undeletable.")
	_check(editor.find_child("FlowChipTypeSelector", true, false) == null,
		"A type-locked Literal Tok does not expose a type-changing selector.")
	editor.set_caret_position(text.get_segment_id(), text.text.length())
	await _frames()
	await _push_shortcut(KEY_Z)
	await _frames()
	_check(literal.value == 0 and text.text == "Akis text",
		"Ctrl+Z follows the document history while focus is on Akis text.")
	await _push_shortcut(KEY_Z, true)
	await _frames()
	_check(literal.value == 25 and text.text == "Akis text",
		"Ctrl+Shift+Z redoes the last Tok action through the document history.")
	await _push_shortcut(KEY_Z)
	await _frames()
	_check(literal.value == 0, "A second Ctrl+Z can continue through the same document history.")
	await _push_shortcut(KEY_Y)
	await _frames()
	_check(literal.value == 25, "Ctrl+Y follows the same unified redo path.")
	editor.queue_free()


func _test_string_and_string_name_line_edit_history() -> void:
	var string_field: FlowChipFieldSchema = _literal_schema(Variant.Type.TYPE_STRING)
	var string_document: FlowStructuredDocument = FlowStructuredDocument.new()
	var string_text: FlowTextSegment = FlowTextSegment.new()
	string_text.text = "Akis"
	var string_literal: FlowLiteralValueSegment = FlowLiteralValueSegment.new(
		FlowLiteralValueSource.TYPE_STRING,
		"A"
	)
	string_literal.set_slot_id("value")
	string_literal.set_slot_kind(FlowChipSegment.SLOT_KIND_VARIADIC)
	string_document.segments = [string_text, string_literal]
	var string_editor: FlowChipFieldEditor = _new_editor(string_field, string_document, null)
	await _frames()
	string_editor.select_segment(string_literal.get_segment_id())
	var string_input: LineEdit = string_editor.find_child(
		"FlowChipTextValue", true, false
	) as LineEdit
	_check(string_input != null, "String Literal Tok exposes its contextual LineEdit.")
	if string_input != null:
		string_input.grab_focus()
		string_input.text = "B"
		string_input.text_changed.emit(string_input.text)
		string_input.text_submitted.emit(string_input.text)
	await _frames()
	_check(
		string_literal.value == "B"
			and string_literal.value_type == Variant.Type.TYPE_STRING
			and typeof(string_literal.value) == Variant.Type.TYPE_STRING,
		"LineEdit String editing keeps one exact String model value.")
	await _push_shortcut(KEY_Z)
	_check(
		string_literal.value == "A" and string_literal.value_type == Variant.Type.TYPE_STRING,
		"String Ctrl+Z restores A while LineEdit focus remains related to the Tok.")
	await _push_shortcut(KEY_Z, true)
	_check(
		string_literal.value == "B" and string_literal.value_type == Variant.Type.TYPE_STRING,
		"String Ctrl+Shift+Z restores B through the owning document history.")
	await _push_shortcut(KEY_Z)
	string_editor.set_caret_position(string_text.get_segment_id(), string_text.text.length())
	await _frames()
	_check(
		string_literal.value == "A",
		"String undo remains available after moving focus to Akis text.")
	await _push_shortcut(KEY_Y)
	_check(
		string_literal.value == "B"
			and typeof(string_literal.value) == Variant.Type.TYPE_STRING,
		"String Ctrl+Y restores B with focus on Akis text.")
	string_editor.select_segment(string_literal.get_segment_id())
	await _frames()
	string_input = string_editor.find_child("FlowChipTextValue", true, false) as LineEdit
	if string_input != null:
		string_input.grab_focus()
		string_input.text = "BC"
		string_input.text_changed.emit(string_input.text)
		string_input.text = "BCD"
		string_input.text_changed.emit(string_input.text)
		string_input.text_submitted.emit(string_input.text)
	await _frames()
	await _push_shortcut(KEY_Z)
	_check(
		string_literal.value == "B",
		"Continuous String LineEdit writing is one logical undo transition.")
	await _push_shortcut(KEY_Y)
	_check(
		string_literal.value == "BCD",
		"Continuous String LineEdit writing redoes the final value without native-history interference.")
	string_editor.queue_free()

	var string_name_field: FlowChipFieldSchema = _literal_schema(Variant.Type.TYPE_STRING_NAME)
	var string_name_document: FlowStructuredDocument = FlowStructuredDocument.new()
	var string_name_text: FlowTextSegment = FlowTextSegment.new()
	string_name_text.text = "Akis"
	var string_name_literal: FlowLiteralValueSegment = FlowLiteralValueSegment.new(
		FlowLiteralValueSource.TYPE_STRING_NAME,
		StringName("A")
	)
	string_name_literal.set_slot_id("value")
	string_name_literal.set_slot_kind(FlowChipSegment.SLOT_KIND_VARIADIC)
	string_name_document.segments = [string_name_text, string_name_literal]
	var string_name_editor: FlowChipFieldEditor = _new_editor(
		string_name_field,
		string_name_document,
		null
	)
	await _frames()
	string_name_editor.select_segment(string_name_literal.get_segment_id())
	var string_name_input: LineEdit = string_name_editor.find_child(
		"FlowChipTextValue", true, false
	) as LineEdit
	_check(string_name_input != null, "StringName Literal Tok exposes its contextual LineEdit.")
	if string_name_input != null:
		string_name_input.grab_focus()
		string_name_input.text = "B"
		string_name_editor.set_caret_position(
			string_name_text.get_segment_id(),
			string_name_text.text.length()
		)
	await _frames()
	_check(
		string_name_literal.value == StringName("B")
			and string_name_literal.value_type == Variant.Type.TYPE_STRING_NAME
			and typeof(string_name_literal.value) == Variant.Type.TYPE_STRING_NAME,
		"StringName editing preserves TYPE_STRING_NAME rather than converting to String.")
	await _push_shortcut(KEY_Z)
	_check(
		string_name_literal.value == StringName("A")
			and typeof(string_name_literal.value) == Variant.Type.TYPE_STRING_NAME,
		"StringName Ctrl+Z restores A with its declared Variant.Type.")
	await _push_shortcut(KEY_Y)
	_check(
		string_name_literal.value == StringName("B")
			and typeof(string_name_literal.value) == Variant.Type.TYPE_STRING_NAME,
		"StringName Ctrl+Y restores B with its declared Variant.Type.")
	string_name_editor.queue_free()

	var mixed_field: FlowChipFieldSchema = _literal_schema(Variant.Type.TYPE_STRING)
	var mixed_document: FlowStructuredDocument = FlowStructuredDocument.new()
	var mixed_text: FlowTextSegment = FlowTextSegment.new()
	mixed_text.text = "texto original"
	var mixed_literal: FlowLiteralValueSegment = FlowLiteralValueSegment.new(
		FlowLiteralValueSource.TYPE_STRING,
		"A"
	)
	mixed_literal.set_slot_id("value")
	mixed_literal.set_slot_kind(FlowChipSegment.SLOT_KIND_VARIADIC)
	mixed_document.segments = [mixed_text, mixed_literal]
	var mixed_editor: FlowChipFieldEditor = _new_editor(mixed_field, mixed_document, null)
	await _frames()
	mixed_editor.set_caret_position(mixed_text.get_segment_id(), mixed_text.text.length())
	var mixed_input: TextEdit = mixed_editor.get_text_control(mixed_text.get_segment_id())
	if mixed_input != null:
		mixed_input.insert_text_at_caret(" + escrito")
	await _frames()
	mixed_editor.select_segment(mixed_literal.get_segment_id())
	var mixed_value_input: LineEdit = mixed_editor.find_child(
		"FlowChipTextValue", true, false
	) as LineEdit
	if mixed_value_input != null:
		mixed_value_input.grab_focus()
		mixed_value_input.text = "B"
		mixed_value_input.text_changed.emit(mixed_value_input.text)
		mixed_value_input.text_submitted.emit(mixed_value_input.text)
	await _frames()
	mixed_editor.set_caret_position(mixed_text.get_segment_id(), mixed_text.text.length())
	await _frames()
	await _push_shortcut(KEY_Z)
	_check(
		mixed_literal.value == "A" and mixed_text.text == "texto original + escrito",
		"Mixed history first undoes the later String Tok action.")
	await _push_shortcut(KEY_Z)
	_check(mixed_text.text == "texto original", "Mixed history then undoes the preceding text action.")
	await _push_shortcut(KEY_Y)
	_check(mixed_text.text == "texto original + escrito", "Mixed history redoes text in chronological order.")
	await _push_shortcut(KEY_Y)
	_check(mixed_literal.value == "B", "Mixed history redoes the String Tok after the text action.")
	mixed_editor.queue_free()


func _test_mixed_history_and_variable_projection() -> void:
	var graph: FlowGraph = _graph_with_variables()
	var field: FlowChipFieldSchema = _variable_schema()
	var document: FlowStructuredDocument = FlowStructuredDocument.new()
	var text: FlowTextSegment = FlowTextSegment.new()
	text.text = "texto original"
	var variable: FlowVariableRefSegment = FlowVariableRefSegment.new(
		FlowVariableRefValueSource.new(
			_variable_id(graph, "Count"),
			FlowVariableDefinition.ValueType.INT
		)
	)
	variable.set_slot_id("value")
	variable.set_slot_kind(FlowChipSegment.SLOT_KIND_VARIADIC)
	document.segments = [text, variable]
	var editor: FlowChipFieldEditor = _new_editor(field, document, graph)
	await _frames()
	_check(editor.find_child("FlowChipTypeSelector", true, false) == null,
		"Variable Tok has no direct Variant.Type editor.")
	var declared: Label
	editor.select_segment(variable.get_segment_id())
	declared = editor.find_child("VariableDeclaredType", true, false) as Label
	_check(declared != null and declared.text == "Declared Type: int",
		"Variable Tok displays its type as read-only derived information.")
	_check(editor.open_variable_selector_for_segment(variable.get_segment_id()),
		"Change Variable opens the shared filtered selector.")
	await _frames()
	var selector: FlowVariableSelector = editor.get_variable_selector()
	_check(selector.get_visible_variable_ids().has(_variable_id(graph, "Enabled")),
		"Variable selector includes a compatible bool reference.")
	_check(not selector.get_visible_variable_ids().has(_variable_id(graph, "Message")),
		"Variable selector filters out an incompatible String reference.")
	selector.cancel()
	await _frames()

	editor.set_caret_position(text.get_segment_id(), text.text.length())
	var input: TextEdit = editor.get_text_control(text.get_segment_id())
	if input != null:
		input.insert_text_at_caret(" + escrito")
	await _frames()
	_check(editor.change_variable_reference(
		variable.get_segment_id(),
		_variable_id(graph, "Enabled")
	), "Change Variable records one structural document action.")
	await _frames()
	editor.set_caret_position(text.get_segment_id(), text.text.length())
	await _frames()
	await _push_shortcut(KEY_Z)
	await _frames()
	var undone: FlowVariableRefSegment = _find_variable_segment(document, variable.get_segment_id())
	_check(
		undone != null
			and (undone.get_value_source() as FlowVariableRefValueSource).variable_id
				== _variable_id(graph, "Count")
			and text.text == "texto original + escrito",
		"Mixed Ctrl+Z restores VariableRef before touching the focused text.")
	await _push_shortcut(KEY_Z)
	await _frames()
	_check(text.text == "texto original",
		"The next Ctrl+Z restores the preceding text action chronologically.")
	await _push_shortcut(KEY_Y)
	await _frames()
	_check(text.text == "texto original + escrito",
		"Redo restores the text action before the later VariableRef action.")
	await _push_shortcut(KEY_Y)
	await _frames()
	var redone: FlowVariableRefSegment = _find_variable_segment(document, variable.get_segment_id())
	_check(
		redone != null
			and (redone.get_value_source() as FlowVariableRefValueSource).variable_id
				== _variable_id(graph, "Enabled"),
		"The second Redo restores the changed VariableRef binding.")
	editor.queue_free()


func _new_editor(
	field: FlowChipFieldSchema,
	document: FlowStructuredDocument,
	graph: FlowGraph
) -> FlowChipFieldEditor:
	var editor: FlowChipFieldEditor = FlowChipFieldEditor.new()
	editor.size = Vector2(1000.0, 620.0)
	_host.add_child(editor)
	editor.configure_field(field, document, _undo_redo, document)
	if graph != null:
		editor.set_variable_graph(graph)
	return editor


func _literal_schema(value_type: Variant.Type) -> FlowChipFieldSchema:
	var field: FlowChipFieldSchema = FlowChipFieldSchema.new()
	field.mode = FlowChipFieldSchema.Mode.FLEXIBLE
	field.text_mode = FlowChipFieldSchema.TextMode.DOCUMENTATION
	field.accepted_value_types = [value_type]
	field.accepted_source_kinds = [FlowValueSource.SOURCE_KIND_LITERAL]
	field.flexible_max_count = 1
	var slot: FlowChipSlotDefinition = FlowChipSlotDefinition.new("value", "Value", true)
	slot.accepted_value_types = [value_type]
	slot.accepted_source_kinds = [FlowValueSource.SOURCE_KIND_LITERAL]
	slot.repeatable = true
	slot.min_count = 1
	slot.max_count = 1
	slot.allow_delete = false
	slot.allow_type_change = false
	field.variadic_slot_definition = slot
	field.add_text_part("Value: ")
	field.add_slot_part("value")
	return field


func _variable_schema() -> FlowChipFieldSchema:
	var field: FlowChipFieldSchema = FlowChipFieldSchema.new()
	field.mode = FlowChipFieldSchema.Mode.FLEXIBLE
	field.text_mode = FlowChipFieldSchema.TextMode.DOCUMENTATION
	field.accepted_value_types = [Variant.Type.TYPE_BOOL, Variant.Type.TYPE_INT]
	field.accepted_source_kinds = [FlowValueSource.SOURCE_KIND_VARIABLE_REF]
	field.flexible_max_count = 1
	var slot: FlowChipSlotDefinition = FlowChipSlotDefinition.new("value", "Value", false)
	slot.accepted_value_types = [Variant.Type.TYPE_BOOL, Variant.Type.TYPE_INT]
	slot.accepted_source_kinds = [FlowValueSource.SOURCE_KIND_VARIABLE_REF]
	slot.repeatable = true
	slot.max_count = 1
	field.variadic_slot_definition = slot
	field.add_text_part("Value: ")
	field.add_slot_part("value")
	return field


func _graph_with_variables() -> FlowGraph:
	var graph: FlowGraph = FlowGraph.new()
	graph.variables = [
		_variable("Count", FlowVariableDefinition.ValueType.INT),
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


func _find_variable_segment(
		document: FlowStructuredDocument,
		segment_id: String
) -> FlowVariableRefSegment:
	for segment: FlowDocumentSegment in document.segments:
		if segment != null and segment.get_segment_id() == segment_id:
			return segment as FlowVariableRefSegment
	return null


func _push_shortcut(keycode: Key, with_shift: bool = false) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.keycode = keycode
	event.ctrl_pressed = true
	event.shift_pressed = with_shift
	event.pressed = true
	get_root().push_input(event, true)
	await _frames(1)


func _frames(count: int = 4) -> void:
	for _index: int in count:
		await process_frame


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	_failures.append(message)
	push_error("[Flujo] Step 2C-A.2 check failed: " + message)


func _finish() -> void:
	if _failures.is_empty():
		print("[Flujo] Flow chip field Step 2C-A.2 test passed")
	else:
		push_error("[Flujo] Flow chip field Step 2C-A.2 test failed: %d failures" % _failures.size())
	quit(0 if _failures.is_empty() else 1)
