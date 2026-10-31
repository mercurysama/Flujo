extends SceneTree


var _failures: Array[String] = []
var _host: Control
var _undo_redo: EditorUndoRedoManager


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	# Finish editor layout restoration before creating document history actions.
	await _frames(24)
	_undo_redo = EditorInterface.get_editor_undo_redo()
	_check(_undo_redo != null, "Step 2C-A.1 has an EditorUndoRedoManager.")
	if _undo_redo == null:
		_finish()
		return
	_host = Control.new()
	_host.name = &"FlowChipFieldStep2CA1TestHost"
	_host.size = Vector2(1100.0, 800.0)
	get_root().add_child(_host)

	await _test_required_editable_and_policy_axes()
	await _test_variable_tok_activation_and_history()
	await _test_caret_restoration_and_literal_escapes()
	await _test_unified_document_history()

	_host.queue_free()
	_finish()


func _test_required_editable_and_policy_axes() -> void:
	var graph: FlowGraph = _graph_with_variables()
	var count_id: String = _variable_id(graph, "Count")
	var required_field: FlowChipFieldSchema = _variable_flexible_schema(
		[Variant.Type.TYPE_INT],
		1
	)
	required_field.variadic_slot_definition.required = true
	required_field.variadic_slot_definition.min_count = 1
	required_field.variadic_slot_definition.max_count = 1
	required_field.variadic_slot_definition.allow_delete = true
	required_field.variadic_slot_definition.allow_type_change = false
	required_field.variadic_slot_definition.allow_source_kind_change = false
	var required_document: FlowStructuredDocument = _variable_document(
		count_id,
		FlowVariableDefinition.ValueType.INT
	)
	var required_editor: FlowChipFieldEditor = _new_editor(
		required_field,
		required_document,
		graph
	)
	await _frames()
	var required_chip: FlowVariableRefSegment = _chips(required_document)[0] as FlowVariableRefSegment
	var required_control: FlowChipControl = required_editor.get_chip_control(
		required_chip.get_segment_id()
	)
	_check(required_field.variadic_slot_definition.required,
		"Required remains an occurrence/presence policy rather than an editability shortcut.")
	_check(required_field.variadic_slot_definition.editable,
		"A required Variable Tok remains editable when its explicit policy permits it.")
	_check(not required_field.variadic_slot_definition.can_delete(),
		"Required presence blocks deletion even when allow_delete is true.")
	_check(required_control != null and required_control.is_editable(),
		"An editable required Variable Tok remains visibly editable.")
	_check(required_control != null and required_control.is_type_locked(),
		"A single accepted value type is exposed as a type lock.")
	_check(required_control != null and required_control.is_source_kind_locked(),
		"A single accepted source kind is exposed as a source-kind lock.")
	if required_chip != null:
		required_editor.select_segment(required_chip.get_segment_id())
		_check(required_editor.find_child("FlowChipTypeSelector", true, false) == null,
			"Variable Tok never exposes a direct Variant.Type selector.")
		var required_declared_type: Label = required_editor.find_child(
			"VariableDeclaredType", true, false
		) as Label
		_check(required_declared_type != null and required_declared_type.text == "Declared Type: int",
			"Variable Tok presents the selected variable's declared type as read-only derived data.")
		_check(not required_editor.delete_selected_chip(),
			"Required deletion is rejected independently of Variable Tok editability.")
		_check(required_editor.open_variable_selector_for_segment(required_chip.get_segment_id()),
			"Reference editing remains available when type and source-kind axes are locked.")
		await _frames()
		required_editor.get_variable_selector().cancel()
		await _frames()
	_check(
		required_editor.find_child("TokTypeLock", true, false) != null
			and required_editor.find_child("TokSourceKindLock", true, false) != null,
		"The contextual editor reports type and source-kind constraints separately."
	)
	required_editor.queue_free()

	var immutable_field: FlowChipFieldSchema = _variable_flexible_schema(
		[Variant.Type.TYPE_INT],
		2
	)
	immutable_field.variadic_slot_definition.editable = false
	immutable_field.variadic_slot_definition.allow_delete = true
	var immutable_document: FlowStructuredDocument = _variable_document(
		count_id,
		FlowVariableDefinition.ValueType.INT
	)
	var immutable_editor: FlowChipFieldEditor = _new_editor(
		immutable_field,
		immutable_document,
		graph
	)
	await _frames()
	var immutable_chip: FlowVariableRefSegment = _chips(immutable_document)[0] as FlowVariableRefSegment
	var immutable_control: FlowChipControl = immutable_editor.get_chip_control(
		immutable_chip.get_segment_id()
	)
	immutable_editor.select_segment(immutable_chip.get_segment_id())
	await _frames(1)
	_check(immutable_control != null and not immutable_control.is_editable(),
		"The editable policy makes an existing Variable Tok immutable without changing required state.")
	_check(immutable_control != null and immutable_control.tooltip_text.contains("immutable"),
		"Immutable Variable Toks expose contextual visual/tooltip feedback.")
	var change_button: Button = immutable_editor.find_child("ChangeVariable", true, false) as Button
	_check(change_button != null and change_button.disabled,
		"The contextual Change Variable action is disabled for an immutable Tok.")
	_check(immutable_editor.delete_chip(immutable_chip.get_segment_id()),
		"allow_delete remains independent from editable for an optional immutable Tok.")
	immutable_editor.queue_free()

	var literal_field: FlowChipFieldSchema = _literal_flexible_schema(
		[Variant.Type.TYPE_INT, Variant.Type.TYPE_BOOL],
		2
	)
	literal_field.variadic_slot_definition.allow_type_change = false
	var literal_document: FlowStructuredDocument = FlowStructuredDocument.new()
	var literal_text: FlowTextSegment = FlowTextSegment.new()
	literal_text.text = "Value: "
	var literal_chip: FlowLiteralValueSegment = FlowLiteralValueSegment.new(
		FlowLiteralValueSource.TYPE_INT,
		0
	)
	literal_chip.set_slot_id("value")
	literal_chip.set_slot_kind(FlowChipSegment.SLOT_KIND_VARIADIC)
	literal_document.segments = [literal_text, literal_chip]
	var literal_editor: FlowChipFieldEditor = _new_editor(
		literal_field,
		literal_document,
		null
	)
	await _frames()
	literal_editor.select_segment(literal_chip.get_segment_id())
	var literal_control: FlowChipControl = literal_editor.get_chip_control(literal_chip.get_segment_id())
	_check(literal_control != null and literal_control.is_type_locked(),
		"The explicit type-change policy locks a literal Tok without making its value immutable.")
	_check(not literal_editor.change_selected_chip_type(Variant.Type.TYPE_BOOL),
		"A type-locked literal rejects a type replacement.")
	_check(literal_editor.get_feedback_text() == "This Tok's type is locked by the current schema.",
		"Type-lock rejection is distinct from immutable-content feedback.")
	_check(literal_editor.set_selected_chip_value(7),
		"A type-locked literal still accepts a value of its declared type.")
	literal_editor.queue_free()


func _test_variable_tok_activation_and_history() -> void:
	var graph: FlowGraph = _graph_with_variables()
	var field: FlowChipFieldSchema = _variable_flexible_schema(
		[Variant.Type.TYPE_BOOL, Variant.Type.TYPE_INT],
		3
	)
	var document: FlowStructuredDocument = _variable_document(
		_variable_id(graph, "Count"),
		FlowVariableDefinition.ValueType.INT
	)
	var editor: FlowChipFieldEditor = _new_editor(field, document, graph)
	await _frames()
	var chip: FlowVariableRefSegment = _chips(document)[0] as FlowVariableRefSegment
	var chip_id: String = chip.get_segment_id()
	var source: FlowVariableRefValueSource = chip.get_value_source() as FlowVariableRefValueSource
	var source_id: String = source.get_source_id()
	var control: FlowChipControl = editor.get_chip_control(chip_id)
	_check(control != null, "Variable Tok editing uses the generic FlowChipControl instance.")
	if control == null:
		editor.queue_free()
		return
	control.select()
	_check(editor.get_selected_segment_id() == chip_id and control.is_selected(),
		"A click/select operation preserves Variable Tok selection by segment_id.")

	var history: UndoRedo = _history(document)
	var version_before: int = history.get_version()
	var double_click: InputEventMouseButton = InputEventMouseButton.new()
	double_click.button_index = MOUSE_BUTTON_LEFT
	double_click.pressed = true
	double_click.double_click = true
	double_click.position = control.get_global_rect().get_center()
	control._gui_input(double_click)
	await _frames()
	var selector: FlowVariableSelector = editor.get_variable_selector()
	var enabled_id: String = _variable_id(graph, "Enabled")
	_check(selector.visible and selector.get_current_variable_id() == source.variable_id,
		"Double-click opens the shared Variable selector with the current binding.")
	var enabled_index: int = _selector_index(selector, enabled_id)
	_check(enabled_index >= 0, "Variable Tok editing lists a compatible replacement by stable ID.")
	if enabled_index >= 0:
		selector.get_variable_list().item_activated.emit(enabled_index)
	await _frames()
	var changed: FlowVariableRefSegment = _chips(document)[0] as FlowVariableRefSegment
	var changed_source: FlowVariableRefValueSource = changed.get_value_source() as FlowVariableRefValueSource
	_check(changed.get_segment_id() == chip_id,
		"Double-click replacement preserves the Variable Tok segment_id.")
	_check(changed.get_slot_id() == chip.get_slot_id(),
		"Double-click replacement preserves the semantic slot_id.")
	_check(changed_source.get_source_id() == source_id,
		"Double-click replacement preserves the VariableRef source_id.")
	_check(changed_source.variable_id == enabled_id and changed_source.get_value_type() == Variant.Type.TYPE_BOOL,
		"Double-click replacement changes only the graph binding and declared type.")
	_check(history.get_version() == version_before + 1,
		"Variable Tok replacement is exactly one owning-document history action.")
	_check(editor.find_child("FlowChipTypeSelector", true, false) == null,
		"Changing a Variable Tok never turns its derived type into an editable control.")
	var changed_declared_type: Label = editor.find_child(
		"VariableDeclaredType", true, false
	) as Label
	_check(changed_declared_type != null and changed_declared_type.text == "Declared Type: bool",
		"Changing the reference updates the derived declared type projection.")
	history.undo()
	var undone: FlowVariableRefSegment = _chips(document)[0] as FlowVariableRefSegment
	var undone_source: FlowVariableRefValueSource = undone.get_value_source() as FlowVariableRefValueSource
	_check(undone.get_segment_id() == chip_id and undone_source.variable_id == source.variable_id,
		"Undo restores the original Variable Tok binding and identity.")
	history.redo()
	var redone: FlowVariableRefSegment = _chips(document)[0] as FlowVariableRefSegment
	var redone_source: FlowVariableRefValueSource = redone.get_value_source() as FlowVariableRefValueSource
	_check(redone.get_segment_id() == chip_id and redone_source.variable_id == enabled_id,
		"Redo restores the replacement Variable Tok binding and identity.")

	control = editor.get_chip_control(chip_id)
	var version_before_cancel: int = history.get_version()
	var enter: InputEventKey = InputEventKey.new()
	enter.keycode = KEY_ENTER
	enter.pressed = true
	control._gui_input(enter)
	await _frames()
	selector = editor.get_variable_selector()
	_check(selector.visible, "Enter opens Variable Tok editing without requiring a mouse double-click.")
	selector.cancel()
	await _frames()
	_check(history.get_version() == version_before_cancel,
		"Cancelling Variable Tok editing does not add a history action.")
	_check(get_root().gui_get_focus_owner() == editor.get_chip_control(chip_id),
		"Cancelling Variable Tok editing returns native focus to the same Tok.")
	editor.queue_free()


func _test_unified_document_history() -> void:
	var graph: FlowGraph = _graph_with_variables()
	var literal_field: FlowChipFieldSchema = _literal_flexible_schema(
		[Variant.Type.TYPE_INT],
		1
	)
	literal_field.variadic_slot_definition.required = true
	literal_field.variadic_slot_definition.min_count = 1
	literal_field.variadic_slot_definition.max_count = 1
	literal_field.variadic_slot_definition.allow_delete = false
	literal_field.variadic_slot_definition.allow_type_change = false
	var literal_document: FlowStructuredDocument = FlowStructuredDocument.new()
	var literal_before: FlowTextSegment = FlowTextSegment.new()
	literal_before.text = "Texto Akis"
	var required_literal: FlowLiteralValueSegment = FlowLiteralValueSegment.new(
		FlowLiteralValueSource.TYPE_INT,
		0
	)
	required_literal.set_slot_id("value")
	required_literal.set_slot_kind(FlowChipSegment.SLOT_KIND_VARIADIC)
	literal_document.segments = [literal_before, required_literal]
	var literal_editor: FlowChipFieldEditor = _new_editor(
		literal_field,
		literal_document,
		graph
	)
	await _frames()
	literal_editor.select_segment(required_literal.get_segment_id())
	_check(literal_editor.set_selected_chip_value(25),
		"A required editable Literal Tok accepts a value change while remaining undeletable.")
	var literal_history: UndoRedo = _history(literal_document)
	literal_editor.set_caret_position(literal_before.get_segment_id(), literal_before.text.length())
	await _frames()
	await _push_shortcut(KEY_Z)
	await _frames()
	_check(required_literal.value == 0 and literal_before.text == "Texto Akis",
		"Document Undo restores a required Literal Tok even when focus is on Akis text.")
	await _push_shortcut(KEY_Y)
	await _frames()
	_check(required_literal.value == 25 and literal_before.text == "Texto Akis",
		"Ctrl+Y redoes the Literal Tok without changing focused Akis text.")
	_check(literal_history != null, "Literal and text actions share the owning document history.")
	literal_editor.queue_free()

	var string_field: FlowChipFieldSchema = _literal_flexible_schema(
		[Variant.Type.TYPE_STRING],
		1
	)
	string_field.variadic_slot_definition.required = true
	string_field.variadic_slot_definition.min_count = 1
	string_field.variadic_slot_definition.max_count = 1
	var string_document: FlowStructuredDocument = FlowStructuredDocument.new()
	var string_text: FlowTextSegment = FlowTextSegment.new()
	string_text.text = "Akis"
	var string_literal: FlowLiteralValueSegment = FlowLiteralValueSegment.new(
		FlowLiteralValueSource.TYPE_STRING,
		"original"
	)
	string_literal.set_slot_id("value")
	string_literal.set_slot_kind(FlowChipSegment.SLOT_KIND_VARIADIC)
	string_document.segments = [string_text, string_literal]
	var string_editor: FlowChipFieldEditor = _new_editor(string_field, string_document, graph)
	await _frames()
	string_editor.select_segment(string_literal.get_segment_id())
	var string_input: LineEdit = string_editor.find_child(
		"FlowChipTextValue", true, false
	) as LineEdit
	_check(string_input != null, "Literal String editing keeps its native LineEdit control.")
	if string_input != null:
		string_input.grab_focus()
		string_input.text = "edited"
		string_input.text_submitted.emit(string_input.text)
	await _frames()
	string_editor.set_caret_position(string_text.get_segment_id(), string_text.text.length())
	await _frames()
	await _push_shortcut(KEY_Z)
	await _frames()
	_check(string_literal.value == "original" and string_text.text == "Akis",
		"Unified Undo also bypasses native LineEdit history in favor of document history.")
	await _push_shortcut(KEY_Z, true)
	await _frames()
	_check(string_literal.value == "edited" and string_text.text == "Akis",
		"Ctrl+Shift+Z redoes a Literal String edit through document history (value=%s)." % String(string_literal.value))
	string_editor.queue_free()

	var variable_field: FlowChipFieldSchema = _variable_flexible_schema(
		[Variant.Type.TYPE_BOOL, Variant.Type.TYPE_INT],
		2
	)
	var mixed_document: FlowStructuredDocument = FlowStructuredDocument.new()
	var mixed_text: FlowTextSegment = FlowTextSegment.new()
	mixed_text.text = "texto original"
	var mixed_variable: FlowVariableRefSegment = FlowVariableRefSegment.new(
		FlowVariableRefValueSource.new(
			_variable_id(graph, "Count"),
			FlowVariableDefinition.ValueType.INT
		)
	)
	mixed_variable.set_slot_id("value")
	mixed_variable.set_slot_kind(FlowChipSegment.SLOT_KIND_VARIADIC)
	mixed_document.segments = [mixed_text, mixed_variable]
	var mixed_editor: FlowChipFieldEditor = _new_editor(variable_field, mixed_document, graph)
	await _frames()
	mixed_editor.set_caret_position(mixed_text.get_segment_id(), mixed_text.text.length())
	var mixed_input: TextEdit = mixed_editor.get_text_control(mixed_text.get_segment_id())
	if mixed_input != null:
		mixed_input.insert_text_at_caret(" + escrito")
	await _frames()
	_check(mixed_editor.change_variable_reference(
		mixed_variable.get_segment_id(),
		_variable_id(graph, "Enabled")
	), "Changing a VariableRef after text creates one chronological document action.")
	await _frames()
	mixed_editor.set_caret_position(mixed_text.get_segment_id(), mixed_text.text.length())
	await _frames()
	await _push_shortcut(KEY_Z)
	await _frames()
	var mixed_after_variable_undo: FlowVariableRefSegment = _chips(mixed_document)[0] as FlowVariableRefSegment
	_check(
		(mixed_after_variable_undo.get_value_source() as FlowVariableRefValueSource).variable_id
			== _variable_id(graph, "Count")
			and mixed_text.text == "texto original + escrito",
		"Mixed Undo first restores the last VariableRef action, not the focused TextEdit.")
	await _push_shortcut(KEY_Z)
	await _frames()
	_check(mixed_text.text == "texto original",
		"A second chronological Undo then restores the preceding text action.")
	await _push_shortcut(KEY_Y)
	await _frames()
	_check(mixed_text.text == "texto original + escrito",
		"Ctrl+Y redoes the earlier text action in chronological order.")
	await _push_shortcut(KEY_Y)
	await _frames()
	var mixed_after_redo: FlowVariableRefSegment = _chips(mixed_document)[0] as FlowVariableRefSegment
	_check(
		(mixed_after_redo.get_value_source() as FlowVariableRefValueSource).variable_id
			== _variable_id(graph, "Enabled"),
		"The second Redo reapplies the VariableRef binding in the same global order.")
	mixed_editor.queue_free()


func _test_caret_restoration_and_literal_escapes() -> void:
	var graph: FlowGraph = _graph_with_variables()
	var field: FlowChipFieldSchema = _variable_flexible_schema([Variant.Type.TYPE_INT], 2)
	var document: FlowStructuredDocument = _text_document("uno dos")
	var editor: FlowChipFieldEditor = _new_editor(field, document, graph)
	await _frames()
	var text: FlowTextSegment = document.segments[0] as FlowTextSegment
	var input: TextEdit = editor.get_text_control(text.get_segment_id())
	var anchor_offset: int = "uno ".length()
	editor.set_caret_position(text.get_segment_id(), anchor_offset)
	var history: UndoRedo = _history(document)
	var version_before: int = history.get_version()
	input.insert_text_at_caret("@")
	await _frames()
	_check(editor.get_variable_selector().visible, "An unescaped @ opens the pending Variable selector.")
	editor.get_variable_selector().cancel()
	await _frames()
	_check(text.text == "uno dos", "Cancelling @ removes only the pending trigger and restores exact text.")
	_check(editor.get_caret_segment_id() == text.get_segment_id() and editor.get_caret_offset() == anchor_offset,
		"Cancelling @ restores the semantic text segment and local caret offset.")
	_check(get_root().gui_get_focus_owner() == editor.get_text_control(text.get_segment_id()),
		"Cancelling @ restores native TextEdit focus after popup focus transition.")
	_check(history.get_version() == version_before,
		"Cancelling @ creates no undo action.")
	editor.queue_free()

	var escaped_document: FlowStructuredDocument = _text_document("")
	var escaped_editor: FlowChipFieldEditor = _new_editor(field, escaped_document, graph)
	await _frames()
	var escaped_input: TextEdit = escaped_editor.get_text_control(
		(escaped_document.segments[0] as FlowTextSegment).get_segment_id()
	)
	escaped_input.insert_text_at_caret("\\")
	escaped_input.insert_text_at_caret("@")
	await _frames()
	_check((escaped_document.segments[0] as FlowTextSegment).text == "@"
			and not escaped_editor.get_variable_selector().visible,
		"The active \\@ escape produces literal @ without activating a selector.")
	escaped_input = escaped_editor.get_text_control(
		(escaped_document.segments[0] as FlowTextSegment).get_segment_id()
	)
	escaped_input.insert_text_at_caret(" $")
	await _frames()
	_check((escaped_document.segments[0] as FlowTextSegment).text.contains("$")
			and not escaped_editor.get_variable_selector().visible
			and not escaped_editor.get_expression_editor().visible,
		"$ remains literal and inactive in the Step 2C-A.1 VariableRef surface; # is covered by Step 2C-B.")
	escaped_editor.queue_free()


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


func _variable_flexible_schema(
		accepted_types: Array[Variant.Type],
		maximum: int
) -> FlowChipFieldSchema:
	var field: FlowChipFieldSchema = FlowChipFieldSchema.new()
	field.mode = FlowChipFieldSchema.Mode.FLEXIBLE
	field.text_mode = FlowChipFieldSchema.TextMode.DOCUMENTATION
	field.accepted_value_types = accepted_types
	field.accepted_source_kinds = [FlowValueSource.SOURCE_KIND_VARIABLE_REF]
	field.flexible_max_count = maximum
	var slot: FlowChipSlotDefinition = FlowChipSlotDefinition.new("value", "Value", false)
	slot.repeatable = true
	slot.max_count = maximum
	slot.accepted_value_types = accepted_types
	slot.accepted_source_kinds = [FlowValueSource.SOURCE_KIND_VARIABLE_REF]
	field.variadic_slot_definition = slot
	field.add_text_part("Values: ")
	field.add_slot_part("value")
	return field


func _literal_flexible_schema(
		accepted_types: Array[Variant.Type],
		maximum: int
) -> FlowChipFieldSchema:
	var field: FlowChipFieldSchema = FlowChipFieldSchema.new()
	field.mode = FlowChipFieldSchema.Mode.FLEXIBLE
	field.text_mode = FlowChipFieldSchema.TextMode.DOCUMENTATION
	field.accepted_value_types = accepted_types
	field.accepted_source_kinds = [FlowValueSource.SOURCE_KIND_LITERAL]
	field.flexible_max_count = maximum
	var slot: FlowChipSlotDefinition = FlowChipSlotDefinition.new("value", "Value", false)
	slot.repeatable = true
	slot.max_count = maximum
	slot.accepted_value_types = accepted_types
	slot.accepted_source_kinds = [FlowValueSource.SOURCE_KIND_LITERAL]
	field.variadic_slot_definition = slot
	field.add_text_part("Values: ")
	field.add_slot_part("value")
	return field


func _variable_document(
		variable_id: String,
		value_type: FlowVariableDefinition.ValueType
) -> FlowStructuredDocument:
	var document: FlowStructuredDocument = FlowStructuredDocument.new()
	var segment: FlowVariableRefSegment = FlowVariableRefSegment.new(
		FlowVariableRefValueSource.new(variable_id, value_type)
	)
	segment.set_slot_id("value")
	segment.set_slot_kind(FlowChipSegment.SLOT_KIND_VARIADIC)
	document.segments = [segment]
	return document


func _text_document(value: String) -> FlowStructuredDocument:
	var document: FlowStructuredDocument = FlowStructuredDocument.new()
	var text: FlowTextSegment = FlowTextSegment.new()
	text.text = value
	document.segments = [text]
	return document


func _graph_with_variables() -> FlowGraph:
	var graph: FlowGraph = FlowGraph.new()
	graph.variables = [
		_variable("Enabled", FlowVariableDefinition.ValueType.BOOL),
		_variable("Count", FlowVariableDefinition.ValueType.INT),
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


func _chips(document: FlowStructuredDocument) -> Array[FlowChipSegment]:
	var result: Array[FlowChipSegment] = []
	for segment: FlowDocumentSegment in document.segments:
		if segment is FlowChipSegment:
			result.append(segment as FlowChipSegment)
	return result


func _history(document: FlowStructuredDocument) -> UndoRedo:
	return _undo_redo.get_history_undo_redo(_undo_redo.get_object_history_id(document))


func _selector_index(selector: FlowVariableSelector, variable_id: String) -> int:
	var list: ItemList = selector.get_variable_list()
	for index: int in list.item_count:
		if String(list.get_item_metadata(index)) == variable_id:
			return index
	return -1


func _frames(count: int = 4) -> void:
	for _index: int in count:
		await process_frame


func _push_shortcut(keycode: Key, with_shift: bool = false) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.keycode = keycode
	event.ctrl_pressed = true
	event.shift_pressed = with_shift
	event.pressed = true
	get_root().push_input(event, true)
	await _frames(1)


func _check(condition: bool, message: String) -> bool:
	if condition:
		return true
	_failures.append(message)
	push_error("[Flujo] Step 2C-A.1 check failed: " + message)
	return false


func _finish() -> void:
	if _failures.is_empty():
		print("[Flujo] Flow chip field Step 2C-A.1 test passed")
	else:
		push_error("[Flujo] Flow chip field Step 2C-A.1 test failed: %d failures" % _failures.size())
	quit(0 if _failures.is_empty() else 1)
