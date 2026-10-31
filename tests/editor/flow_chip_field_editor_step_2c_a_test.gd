extends SceneTree


var _failures: Array[String] = []
var _host: Control
var _undo_redo: EditorUndoRedoManager


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	await _frames()
	_undo_redo = EditorInterface.get_editor_undo_redo()
	_check(_undo_redo != null, "Step 2C-A has an EditorUndoRedoManager.")
	if _undo_redo == null:
		_finish()
		return
	_host = Control.new()
	_host.name = &"FlowChipFieldStep2CATestHost"
	_host.size = Vector2(1100.0, 800.0)
	get_root().add_child(_host)

	await _test_selector_keyboard_navigation()
	await _test_at_selector_filtering_and_insertion()
	await _test_trigger_cancellation_and_escapes()
	await _test_fixed_replacement()
	await _test_hybrid_variable_insertion()
	await _test_variable_tok_editing()
	await _test_missing_variable_diagnostics()

	_host.queue_free()
	_finish()


func _test_selector_keyboard_navigation() -> void:
	var graph: FlowGraph = _graph_with_variables()
	var field: FlowChipFieldSchema = _variable_flexible_schema([
		Variant.Type.TYPE_BOOL,
		Variant.Type.TYPE_INT,
		Variant.Type.TYPE_STRING,
		Variant.Type.TYPE_VECTOR2,
	], 4)
	var document: FlowStructuredDocument = _text_document("")
	var editor: FlowChipFieldEditor = _new_editor(field, document, graph)
	await _frames()
	var text: FlowTextSegment = document.segments[0] as FlowTextSegment
	var input: TextEdit = editor.get_text_control(text.get_segment_id())
	input.insert_text_at_caret("@")
	await _frames()
	var selector: FlowVariableSelector = editor.get_variable_selector()
	var search: LineEdit = selector.find_child("VariableSearch", true, false) as LineEdit
	var list: ItemList = selector.get_variable_list()
	_check(search != null and selector.visible, "@ opens a selector with an immediately focused Search control.")
	if search == null:
		editor.queue_free()
		return
	_check(selector.get_viewport().gui_get_focus_owner() == search,
		"The variable selector gives Search keyboard focus without a mouse click.")
	search.text = "Count"
	search.text_changed.emit("Count")
	await _frames()
	_check(selector.get_visible_variable_ids() == [_variable_id(graph, "Count")],
		"Search filters the same compatible graph-variable collection used by the selector.")
	search.text = ""
	search.text_changed.emit("")
	await _frames()
	await _push_key(KEY_DOWN)
	_check(_selected_item_index(list) == 1, "Arrow Down selects the next visible variable from Search focus.")
	await _push_key(KEY_DOWN)
	_check(_selected_item_index(list) == 2, "A second Arrow Down advances the visible selection.")
	await _push_key(KEY_UP)
	_check(_selected_item_index(list) == 1, "Arrow Up selects the previous visible variable.")
	await _push_key(KEY_ENTER)
	await _frames()
	var chips: Array[FlowChipSegment] = _chips(document)
	_check(chips.size() == 1 and chips[0] is FlowVariableRefSegment,
		"Enter confirms the highlighted variable without requiring a list click.")
	editor.queue_free()


func _test_at_selector_filtering_and_insertion() -> void:
	var graph: FlowGraph = _graph_with_variables()
	var field: FlowChipFieldSchema = _variable_flexible_schema([
		Variant.Type.TYPE_BOOL,
		Variant.Type.TYPE_INT,
		Variant.Type.TYPE_STRING,
		Variant.Type.TYPE_VECTOR2,
	], 4)
	var document: FlowStructuredDocument = FlowStructuredDocument.new()
	var text: FlowTextSegment = FlowTextSegment.new()
	text.text = "Hola  mundo"
	document.segments = [text]
	var editor: FlowChipFieldEditor = _new_editor(field, document, graph)
	await _frames()
	var input: TextEdit = editor.get_text_control(text.get_segment_id())
	_check(input != null, "@ trigger is driven by the existing native TextEdit.")
	if input == null:
		editor.queue_free()
		return
	editor.set_caret_position(text.get_segment_id(), "Hola ".length())
	input.insert_text_at_caret("@")
	await _frames()
	var selector: FlowVariableSelector = editor.get_variable_selector()
	_check(selector != null and selector.visible, "Typing an unescaped @ opens the variable selector.")
	if selector == null:
		editor.queue_free()
		return
	_check(selector.get_visible_variable_ids().size() == 4,
		"The @ selector starts with only schema-compatible graph variables.")

	var search: LineEdit = selector.find_child("VariableSearch", true, false) as LineEdit
	_check(search != null, "Variable selector provides a keyboard-search LineEdit.")
	if search != null:
		search.text = "Message"
		search.text_changed.emit("Message")
		await _frames(1)
		_check(selector.get_visible_variable_ids() == [_variable_id(graph, "Message")],
			"Variable selector search filters by display name without changing identity.")
		search.text_submitted.emit("Message")
	await _frames()
	var chips: Array[FlowChipSegment] = _chips(document)
	_check(chips.size() == 1 and chips[0] is FlowVariableRefSegment,
		"Selecting @ creates one structured VariableRef chip.")
	if chips.size() != 1:
		editor.queue_free()
		return
	var variable_segment: FlowVariableRefSegment = chips[0] as FlowVariableRefSegment
	var variable_source: FlowVariableRefValueSource = \
		variable_segment.get_value_source() as FlowVariableRefValueSource
	_check(variable_source != null and variable_source.variable_id == _variable_id(graph, "Message"),
		"VariableRef persists the selected variable ID, not its display name or index.")
	_check(variable_source != null and variable_source.get_value_type() == Variant.Type.TYPE_STRING,
		"VariableRef preserves the selected variable declared type.")
	_check(text.text == "Hola ", "Variable trigger removes only the trigger text before insertion.")
	_check(document.segments.size() == 3 and (document.segments[2] as FlowTextSegment).text == " mundo",
		"Variable insertion preserves the exact Unicode/text suffix at the caret.")
	_check(editor.get_chip_control(variable_segment.get_segment_id()) != null,
		"VariableRef reuses the generic FlowChipControl surface.")
	_check(editor.get_chip_control(variable_segment.get_segment_id()).tooltip_text.contains("ID:"),
		"VariableRef tooltip exposes structured stable-ID context.")

	var history: UndoRedo = _history(document)
	history.undo()
	_check(_chips(document).is_empty() and text.text == "Hola  mundo",
		"Undo removes the VariableRef and restores the exact pre-trigger text.")
	history.redo()
	var redone: FlowVariableRefSegment = _chips(document)[0] as FlowVariableRefSegment
	_check(redone.get_segment_id() == variable_segment.get_segment_id(),
		"Redo restores the same VariableRef segment_id.")

	graph.variables[1].display_name = "Mensaje"
	editor.refresh()
	await _frames()
	_check(editor.get_chip_control(variable_segment.get_segment_id()).get_child(0).text == "Mensaje",
		"Renaming a graph variable updates the chip label while preserving its ID reference.")
	editor.queue_free()


func _test_trigger_cancellation_and_escapes() -> void:
	var graph: FlowGraph = _graph_with_variables()
	var field: FlowChipFieldSchema = _variable_flexible_schema([Variant.Type.TYPE_INT], 4)

	var cancel_document: FlowStructuredDocument = _text_document("")
	var cancel_editor: FlowChipFieldEditor = _new_editor(field, cancel_document, graph)
	await _frames()
	var cancel_text: FlowTextSegment = cancel_document.segments[0] as FlowTextSegment
	var cancel_input: TextEdit = cancel_editor.get_text_control(cancel_text.get_segment_id())
	cancel_input.insert_text_at_caret("@")
	await _frames()
	await _push_key(KEY_ESCAPE)
	_check(cancel_text.text.is_empty() and _chips(cancel_document).is_empty(),
		"Escape closes @ selection and removes the pending trigger without a chip.")
	cancel_editor.queue_free()

	var escaped_at_document: FlowStructuredDocument = _text_document("")
	var escaped_at_editor: FlowChipFieldEditor = _new_editor(field, escaped_at_document, graph)
	await _frames()
	var escaped_at_text: FlowTextSegment = escaped_at_document.segments[0] as FlowTextSegment
	var escaped_at_input: TextEdit = escaped_at_editor.get_text_control(escaped_at_text.get_segment_id())
	escaped_at_input.insert_text_at_caret("\\")
	escaped_at_input.insert_text_at_caret("@")
	await _frames()
	_check(escaped_at_text.text == "@" and not escaped_at_editor.get_variable_selector().visible,
		"The active escape \\@ becomes literal @ and does not open a selector.")
	escaped_at_editor.queue_free()

	var escaped_slash_document: FlowStructuredDocument = _text_document("")
	var escaped_slash_editor: FlowChipFieldEditor = _new_editor(field, escaped_slash_document, graph)
	await _frames()
	var escaped_slash_text: FlowTextSegment = escaped_slash_document.segments[0] as FlowTextSegment
	var escaped_slash_input: TextEdit = escaped_slash_editor.get_text_control(escaped_slash_text.get_segment_id())
	escaped_slash_input.insert_text_at_caret("\\")
	escaped_slash_input.insert_text_at_caret("\\")
	await _frames()
	_check(escaped_slash_text.text == "\\",
		"The active escape \\\\ becomes one literal backslash.")
	escaped_slash_editor.queue_free()

	var inactive_symbols_document: FlowStructuredDocument = _text_document("")
	var inactive_symbols_editor: FlowChipFieldEditor = _new_editor(
		field,
		inactive_symbols_document,
		graph
	)
	await _frames()
	var inactive_input: TextEdit = inactive_symbols_editor.get_text_control(
		(inactive_symbols_document.segments[0] as FlowTextSegment).get_segment_id()
	)
	inactive_input.insert_text_at_caret("$")
	await _frames()
	_check((inactive_symbols_document.segments[0] as FlowTextSegment).text == "$" \
			and not inactive_symbols_editor.get_variable_selector().visible \
			and not inactive_symbols_editor.get_expression_editor().visible,
		"$ remains literal and inactive in the Step 2C-A VariableRef surface; # is covered by Step 2C-B.")
	inactive_symbols_editor.queue_free()


func _test_fixed_replacement() -> void:
	var graph: FlowGraph = _graph_with_variables()
	var field: FlowChipFieldSchema = _fixed_variable_schema()
	var creation: FlowChipFieldCreationResult = FlowChipFieldFactory.new().create(field)
	_check(creation.document != null, "FIXED VariableRef replacement fixture creates its document.")
	if creation.document == null:
		return
	var editor: FlowChipFieldEditor = _new_editor(field, creation.document, graph)
	await _frames()
	var target: FlowChipSegment = _find_chip_by_slot(creation.document, "value")
	var preceding: FlowTextSegment = _first_text(creation.document)
	_check(target != null and preceding != null, "FIXED fixture exposes adjacent text and fixed chip.")
	if target == null or preceding == null:
		editor.queue_free()
		return
	var target_id: String = target.get_segment_id()
	var target_slot: String = target.get_slot_id()
	editor.set_caret_position(preceding.get_segment_id(), preceding.text.length())
	var input: TextEdit = editor.get_text_control(preceding.get_segment_id())
	input.insert_text_at_caret("@")
	await _frames()
	_check(editor.get_variable_selector().visible,
		"FIXED accepts @ at the text edge adjacent to its generated chip.")
	editor.get_variable_selector().get_variable_list().item_activated.emit(0)
	await _frames()
	var replaced: FlowChipSegment = _find_chip(creation.document, target_id)
	_check(replaced is FlowVariableRefSegment,
		"FIXED replaces the adjacent chip with VariableRef instead of inserting a new occurrence.")
	_check(replaced != null and replaced.get_segment_id() == target_id \
			and replaced.get_slot_id() == target_slot,
		"FIXED replacement preserves the original segment_id and slot_id.")
	_check(preceding.text == "Value: ", "FIXED replacement removes the trigger but preserves surrounding text.")
	var history: UndoRedo = _history(creation.document)
	history.undo()
	_check(_find_chip(creation.document, target_id) is FlowLiteralValueSegment,
		"Undo restores the original fixed chip subtype and identity.")
	history.redo()
	_check(_find_chip(creation.document, target_id) is FlowVariableRefSegment,
		"Redo reapplies fixed VariableRef replacement without changing identity.")
	editor.queue_free()


func _test_hybrid_variable_insertion() -> void:
	var graph: FlowGraph = _graph_with_variables()
	var field: FlowChipFieldSchema = _hybrid_variable_schema()
	var creation: FlowChipFieldCreationResult = FlowChipFieldFactory.new().create(field)
	_check(creation.document != null, "HYBRID VariableRef fixture creates its required structure.")
	if creation.document == null:
		return
	var editor: FlowChipFieldEditor = _new_editor(field, creation.document, graph)
	await _frames()
	var texts: Array[FlowTextSegment] = _texts(creation.document)
	var optional_text: FlowTextSegment = texts.back() if not texts.is_empty() else null
	_check(optional_text != null, "HYBRID exposes a variadic-zone text caret.")
	if optional_text == null:
		editor.queue_free()
		return
	editor.set_caret_position(optional_text.get_segment_id(), optional_text.text.length())
	var input: TextEdit = editor.get_text_control(optional_text.get_segment_id())
	input.insert_text_at_caret("@")
	await _frames()
	_check(editor.get_variable_selector().visible,
		"HYBRID opens @ only in its variadic zone.")
	editor.get_variable_selector().get_variable_list().item_activated.emit(0)
	await _frames()
	var chips: Array[FlowChipSegment] = _chips(creation.document)
	var variable_chip: FlowVariableRefSegment = chips.back() as FlowVariableRefSegment
	_check(variable_chip != null and variable_chip.get_slot_id() == "optional" \
			and variable_chip.get_slot_kind() == FlowChipSegment.SLOT_KIND_VARIADIC,
		"HYBRID inserts VariableRef into the declared variadic slot.")
	editor.queue_free()


func _test_variable_tok_editing() -> void:
	var graph: FlowGraph = _graph_with_variables()
	var field: FlowChipFieldSchema = _variable_flexible_schema([
		Variant.Type.TYPE_BOOL,
		Variant.Type.TYPE_INT,
	], 4)
	var document: FlowStructuredDocument = _text_document("Value: ")
	var editor: FlowChipFieldEditor = _new_editor(field, document, graph)
	await _frames()
	var text: FlowTextSegment = document.segments[0] as FlowTextSegment
	editor.set_caret_position(text.get_segment_id(), text.text.length())
	var count_id: String = _variable_id(graph, "Count")
	var enabled_id: String = _variable_id(graph, "Enabled")
	var segment_id: String = editor.insert_variable_ref_at_caret(count_id)
	await _frames()
	var variable_segment: FlowVariableRefSegment = _find_chip(document, segment_id) as FlowVariableRefSegment
	_check(variable_segment != null, "A Variable Tok can be selected through the generic chip editor.")
	if variable_segment == null:
		editor.queue_free()
		return
	var chip: FlowChipControl = editor.get_chip_control(segment_id)
	chip.select()
	_check(editor.get_selected_segment_id() == segment_id and chip.is_selected(),
		"A simple click/selection keeps Variable Tok identity at segment_id.")
	var source_kind_label: Label = editor.find_child("VariableSourceKind", true, false) as Label
	var id_label: Label = editor.find_child("VariableID", true, false) as Label
	_check(source_kind_label != null and source_kind_label.text == "Source: Variable",
		"The contextual editor reports VariableRef source information instead of exposing an editable label.")
	_check(id_label != null and id_label.text.contains(count_id),
		"The contextual editor reports the stable variable ID.")
	var history: UndoRedo = _history(document)
	var version_before_change: int = history.get_version()
	var double_click: InputEventMouseButton = InputEventMouseButton.new()
	double_click.button_index = MOUSE_BUTTON_LEFT
	double_click.pressed = true
	double_click.double_click = true
	double_click.position = chip.get_global_rect().get_center()
	chip._gui_input(double_click)
	await _frames()
	var selector: FlowVariableSelector = editor.get_variable_selector()
	_check(selector.visible and selector.get_current_variable_id() == count_id,
		"Double-click opens the same variable selector with the current VariableRef selected.")
	var context: Dictionary = selector.get_selector_context()
	_check(context.get("schema", null) == field and context.get("slot", null) != null,
		"Variable editing passes schema and slot context to the reusable selector.")
	var enabled_index: int = _selector_index(selector, enabled_id)
	_check(enabled_index >= 0, "Variable editing lists only schema-compatible graph variables.")
	if enabled_index >= 0:
		selector.get_variable_list().item_activated.emit(enabled_index)
	await _frames()
	var changed: FlowVariableRefSegment = _find_chip(document, segment_id) as FlowVariableRefSegment
	var changed_source: FlowVariableRefValueSource = \
		changed.get_value_source() as FlowVariableRefValueSource if changed != null else null
	_check(changed != null and changed.get_segment_id() == segment_id,
		"Changing a Variable Tok preserves segment_id and its document location.")
	_check(changed != null and changed.get_slot_id() == variable_segment.get_slot_id(),
		"Changing a Variable Tok preserves slot_id.")
	_check(changed_source != null and changed_source.variable_id == enabled_id \
			and changed_source.get_value_type() == Variant.Type.TYPE_BOOL,
		"Changing a Variable Tok updates variable_id and declared type through the selector.")
	_check(history.get_version() == version_before_change + 1,
		"Changing a Variable Tok creates exactly one undoable action after popup focus transition.")
	history.undo()
	var undone: FlowVariableRefSegment = _find_chip(document, segment_id) as FlowVariableRefSegment
	var undone_source: FlowVariableRefValueSource = \
		undone.get_value_source() as FlowVariableRefValueSource if undone != null else null
	_check(undone_source != null and undone_source.variable_id == count_id,
		"Undo restores the original VariableRef binding without changing segment identity.")
	history.redo()
	var redone: FlowVariableRefSegment = _find_chip(document, segment_id) as FlowVariableRefSegment
	var redone_source: FlowVariableRefValueSource = \
		redone.get_value_source() as FlowVariableRefValueSource if redone != null else null
	_check(redone_source != null and redone_source.variable_id == enabled_id,
		"Redo restores the replacement VariableRef binding.")
	graph.variables[0].display_name = "Active"
	editor.refresh()
	await _frames()
	var renamed: FlowVariableRefSegment = _find_chip(document, segment_id) as FlowVariableRefSegment
	_check(renamed != null and renamed.get_chip_label() == "Active" \
			and (renamed.get_value_source() as FlowVariableRefValueSource).variable_id == enabled_id,
		"Renaming a graph variable changes presentation only and keeps the stable binding ID.")
	var version_before_cancel: int = history.get_version()
	chip = editor.get_chip_control(segment_id)
	var enter: InputEventKey = InputEventKey.new()
	enter.keycode = KEY_ENTER
	enter.pressed = true
	chip._gui_input(enter)
	await _frames()
	_check(selector.visible, "Enter on a selected Variable Tok opens its selector for editing.")
	await _push_key(KEY_ESCAPE)
	var cancelled: FlowVariableRefSegment = _find_chip(document, segment_id) as FlowVariableRefSegment
	var cancelled_source: FlowVariableRefValueSource = \
		cancelled.get_value_source() as FlowVariableRefValueSource if cancelled != null else null
	_check(cancelled_source != null and cancelled_source.variable_id == enabled_id \
			and history.get_version() == version_before_cancel,
		"Cancelling Variable Tok editing preserves the binding and creates no Undo action.")
	editor.queue_free()


func _test_missing_variable_diagnostics() -> void:
	var graph: FlowGraph = _graph_with_variables()
	var missing_source: FlowVariableRefValueSource = FlowVariableRefValueSource.new(
		FlowId.create(),
		FlowVariableDefinition.ValueType.INT
	)
	var missing_segment: FlowVariableRefSegment = FlowVariableRefSegment.new(missing_source)
	var document: FlowStructuredDocument = FlowStructuredDocument.new()
	document.segments = [missing_segment]
	var editor: FlowChipFieldEditor = _new_editor(null, document, graph)
	await _frames()
	var result: FlowValidationResult = editor.get_validation_result()
	_check(_has_code(result, FlowDiagnostic.CODE_VARIABLE_REFERENCE_MISSING),
		"The editor surfaces a missing graph variable as a structured diagnostic.")
	_check(editor.get_chip_control(missing_segment.get_segment_id()).is_invalid(),
		"Missing VariableRef chips receive the generic invalid visual state.")
	var repair_history: UndoRedo = _history(document)
	var repair_version: int = repair_history.get_version()
	_check(editor.open_variable_selector_for_segment(missing_segment.get_segment_id()),
		"An unresolved VariableRef can open the selector for explicit repair.")
	await _frames()
	var repair_selector: FlowVariableSelector = editor.get_variable_selector()
	var count_index: int = _selector_index(repair_selector, _variable_id(graph, "Count"))
	if count_index >= 0:
		repair_selector.get_variable_list().item_activated.emit(count_index)
	await _frames()
	var repaired: FlowVariableRefSegment = \
		_find_chip(document, missing_segment.get_segment_id()) as FlowVariableRefSegment
	var repaired_source: FlowVariableRefValueSource = \
		repaired.get_value_source() as FlowVariableRefValueSource if repaired != null else null
	_check(repaired_source != null and repaired_source.variable_id == _variable_id(graph, "Count"),
		"Missing VariableRef repair changes only the reference after explicit user selection.")
	_check(not _has_code(editor.get_validation_result(), FlowDiagnostic.CODE_VARIABLE_REFERENCE_MISSING),
		"Explicit VariableRef repair clears the unresolved diagnostic without automatic substitution.")
	_check(repair_history.get_version() == repair_version + 1,
		"Explicit VariableRef repair records one undoable binding change.")
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
	editor.set_variable_graph(graph)
	return editor


func _graph_with_variables() -> FlowGraph:
	var graph: FlowGraph = FlowGraph.new()
	graph.variables = [
		_variable("Enabled", FlowVariableDefinition.ValueType.BOOL),
		_variable("Message", FlowVariableDefinition.ValueType.STRING),
		_variable("Count", FlowVariableDefinition.ValueType.INT),
		_variable("Position", FlowVariableDefinition.ValueType.VECTOR2),
		_variable("Color", FlowVariableDefinition.ValueType.COLOR),
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


func _fixed_variable_schema() -> FlowChipFieldSchema:
	var field: FlowChipFieldSchema = FlowChipFieldSchema.new()
	field.mode = FlowChipFieldSchema.Mode.FIXED
	field.text_mode = FlowChipFieldSchema.TextMode.DOCUMENTATION
	field.accepted_value_types = [Variant.Type.TYPE_INT]
	field.accepted_source_kinds = [
		FlowValueSource.SOURCE_KIND_LITERAL,
		FlowValueSource.SOURCE_KIND_VARIABLE_REF,
	]
	var slot: FlowChipSlotDefinition = FlowChipSlotDefinition.new("value", "Value", true)
	slot.accepted_value_types = [Variant.Type.TYPE_INT]
	slot.accepted_source_kinds = [
		FlowValueSource.SOURCE_KIND_LITERAL,
		FlowValueSource.SOURCE_KIND_VARIABLE_REF,
	]
	slot.initial_value_source = FlowLiteralValueSource.new(FlowLiteralValueSource.TYPE_INT, 0)
	slot.allow_delete = false
	slot.allow_reorder = false
	slot.min_count = 1
	slot.max_count = 1
	field.slots = [slot]
	field.add_text_part("Value: ")
	field.add_slot_part("value")
	return field


func _hybrid_variable_schema() -> FlowChipFieldSchema:
	var field: FlowChipFieldSchema = FlowChipFieldSchema.new()
	field.mode = FlowChipFieldSchema.Mode.HYBRID
	field.text_mode = FlowChipFieldSchema.TextMode.DOCUMENTATION
	field.accepted_value_types = [Variant.Type.TYPE_INT, Variant.Type.TYPE_BOOL]
	field.accepted_source_kinds = [
		FlowValueSource.SOURCE_KIND_LITERAL,
		FlowValueSource.SOURCE_KIND_VARIABLE_REF,
	]
	var required: FlowChipSlotDefinition = FlowChipSlotDefinition.new("required", "Required", true)
	required.accepted_value_types = [Variant.Type.TYPE_INT]
	required.accepted_source_kinds = [FlowValueSource.SOURCE_KIND_LITERAL]
	required.initial_value_source = FlowLiteralValueSource.new(FlowLiteralValueSource.TYPE_INT, 0)
	required.allow_delete = false
	required.allow_reorder = false
	required.min_count = 1
	required.max_count = 1
	field.slots = [required]
	var optional: FlowChipSlotDefinition = FlowChipSlotDefinition.new("optional", "Optional", false)
	optional.repeatable = true
	optional.max_count = 2
	optional.accepted_value_types = [Variant.Type.TYPE_INT, Variant.Type.TYPE_BOOL]
	optional.accepted_source_kinds = [FlowValueSource.SOURCE_KIND_VARIABLE_REF]
	field.variadic_slot_definition = optional
	field.add_text_part("Required: ")
	field.add_slot_part("required")
	field.add_text_part(" Optional: ")
	field.add_slot_part("optional")
	return field


func _text_document(value: String) -> FlowStructuredDocument:
	var document: FlowStructuredDocument = FlowStructuredDocument.new()
	var text: FlowTextSegment = FlowTextSegment.new()
	text.text = value
	document.segments = [text]
	return document


func _first_text(document: FlowStructuredDocument) -> FlowTextSegment:
	for segment: FlowDocumentSegment in document.segments:
		if segment is FlowTextSegment:
			return segment as FlowTextSegment
	return null


func _texts(document: FlowStructuredDocument) -> Array[FlowTextSegment]:
	var result: Array[FlowTextSegment] = []
	for segment: FlowDocumentSegment in document.segments:
		if segment is FlowTextSegment:
			result.append(segment as FlowTextSegment)
	return result


func _chips(document: FlowStructuredDocument) -> Array[FlowChipSegment]:
	var result: Array[FlowChipSegment] = []
	for segment: FlowDocumentSegment in document.segments:
		if segment is FlowChipSegment:
			result.append(segment as FlowChipSegment)
	return result


func _find_chip(document: FlowStructuredDocument, segment_id: String) -> FlowChipSegment:
	for segment: FlowDocumentSegment in document.segments:
		if segment != null and segment.get_segment_id() == segment_id:
			return segment as FlowChipSegment
	return null


func _find_chip_by_slot(document: FlowStructuredDocument, slot_id: String) -> FlowChipSegment:
	for chip: FlowChipSegment in _chips(document):
		if chip.get_slot_id() == slot_id:
			return chip
	return null


func _history(document: FlowStructuredDocument) -> UndoRedo:
	return _undo_redo.get_history_undo_redo(_undo_redo.get_object_history_id(document))


func _selector_index(selector: FlowVariableSelector, variable_id: String) -> int:
	var list: ItemList = selector.get_variable_list()
	for index: int in list.item_count:
		if String(list.get_item_metadata(index)) == variable_id:
			return index
	return -1


func _selected_item_index(list: ItemList) -> int:
	var selected: PackedInt32Array = list.get_selected_items()
	return selected[0] if not selected.is_empty() else -1


func _has_code(result: FlowValidationResult, code: StringName) -> bool:
	for diagnostic: FlowDiagnostic in result.diagnostics:
		if diagnostic.code == code:
			return true
	return false


func _frames(count: int = 4) -> void:
	for _index: int in count:
		await process_frame


func _push_key(keycode: Key) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.keycode = keycode
	event.pressed = true
	get_root().push_input(event, true)
	await _frames(1)


func _check(condition: bool, message: String) -> bool:
	if condition:
		return true
	_failures.append(message)
	push_error("[Flujo] Step 2C-A check failed: " + message)
	return false


func _finish() -> void:
	if _failures.is_empty():
		print("[Flujo] Flow chip field Step 2C-A test passed")
	else:
		push_error("[Flujo] Flow chip field Step 2C-A test failed: %d failures" % _failures.size())
	quit(0 if _failures.is_empty() else 1)
