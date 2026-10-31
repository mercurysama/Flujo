extends SceneTree


var _failures: Array[String] = []
var _host: Control
var _undo_redo: EditorUndoRedoManager


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	await _frames()
	_undo_redo = EditorInterface.get_editor_undo_redo()
	_check(_undo_redo != null, "Step 2A has an EditorUndoRedoManager.")
	if _undo_redo == null:
		_finish()
		return
	_host = Control.new()
	_host.name = &"FlowChipFieldStep2ATestHost"
	_host.size = Vector2(1100.0, 760.0)
	get_root().add_child(_host)
	await _test_inline_caret_and_undo()
	await _test_fixed_schema()
	await _test_flexible_schema()
	await _test_hybrid_schema()
	await _test_invalid_document_feedback()
	_host.queue_free()
	_finish()


func _test_inline_caret_and_undo() -> void:
	var document: FlowStructuredDocument = FlowStructuredDocument.new()
	var before: FlowTextSegment = FlowTextSegment.new()
	before.text = "Tengo  vidas"
	var after: FlowTextSegment = FlowTextSegment.new()
	after.text = ""
	document.segments = [before, after]
	var editor: FlowChipFieldEditor = _new_editor(null, document)
	await _frames()
	_check(editor.get_text_control(before.get_segment_id()) != null,
		"A text segment is represented by a real TextEdit caret surface.")
	var exact_offset: int = "Tengo ".length()
	_check(editor.set_caret_position(before.get_segment_id(), exact_offset),
		"The editor accepts an exact character caret position.")
	_check(editor.get_caret_offset() == exact_offset,
		"The caret offset remains a character position before insertion.")
	var source: FlowLiteralValueSource = FlowLiteralValueSource.new(
		FlowLiteralValueSource.TYPE_INT,
		3
	)
	var inserted_id: String = editor.insert_value_source_at_caret(source)
	await _frames()
	_check(FlowId.is_valid(inserted_id), "Insertion returns a stable segment_id.")
	_check(document.segments.size() == 4, "Insertion splits text around the exact caret.")
	var chip: FlowChipSegment = _find_chip(document, inserted_id)
	_check(chip != null and chip is FlowLiteralValueSegment,
		"The inserted semantic source becomes one generic chip segment.")
	_check(before.text == "Tengo ", "Text before the caret remains exact.")
	var following: FlowTextSegment = document.segments[2] as FlowTextSegment
	_check(following != null and following.text == " vidas",
		"Text after the caret remains exact and editable.")
	_check(editor.get_selected_segment_id() == inserted_id,
		"Insertion selects the complete chip by segment_id.")
	_check(editor.get_chip_control(inserted_id) != null,
		"The chip is rendered as the one reusable FlowChipControl.")
	_check(editor.get_chip_control(inserted_id).tooltip_text.contains("Type: Literal"),
		"The chip exposes structured tooltip Type data.")
	_check(editor.get_chip_control(inserted_id).tooltip_text.contains("Value: 3"),
		"The chip exposes structured tooltip Value data.")

	var history: UndoRedo = _history(document)
	_check(history != null, "Inline structural edits use the document history.")
	if history != null:
		history.undo()
		_check(document.segments.size() == 2 and before.text == "Tengo  vidas",
			"Undo restores the exact pre-insertion text and segment layout.")
		history.redo()
		_check(_find_chip(document, inserted_id) != null and before.text == "Tengo ",
			"Redo restores the same chip segment_id and split text.")

	editor.select_segment(inserted_id)
	_check(editor.set_selected_chip_value(9), "A selected literal chip accepts an exact typed value.")
	_check((chip as FlowLiteralValueSegment).value == 9,
		"The literal value edit updates the model without conversion.")
	if history != null:
		history.undo()
		_check((chip as FlowLiteralValueSegment).value == 3,
			"Undo restores the chip value while retaining the same segment resource.")
		history.redo()
		_check((chip as FlowLiteralValueSegment).value == 9,
			"Redo restores the edited typed value.")

	_check(editor.delete_selected_chip(), "Delete removes a selected chip as one unit.")
	_check(_find_chip(document, inserted_id) == null and before.text == "Tengo ",
		"Chip deletion does not delete adjacent text characters.")
	if history != null:
		history.undo()
		_check(_find_chip(document, inserted_id) != null,
			"Undo restores the deleted chip with its stable segment_id.")
		history.redo()
		_check(_find_chip(document, inserted_id) == null,
			"Redo deletes the same complete chip again.")

	editor.set_text_segment_text(before.get_segment_id(), "  línea\n\tUnicode: ñ 日本 @ # $  ")
	_check(before.text == "  línea\n\tUnicode: ñ 日本 @ # $  ",
		"Multiline Unicode and @/#/$ remain literal model text.")
	if history != null:
		history.undo()
		_check(before.text == "Tengo ", "Undo restores literal multiline text exactly.")
		history.redo()
		_check(before.text.contains("@ # $"), "Redo restores literal symbols without triggers.")

	editor.refresh()
	await _frames()
	_check(editor.get_selected_segment_id() == "",
		"Selection clears only when the selected segment no longer exists.")
	editor.queue_free()


func _test_fixed_schema() -> void:
	var field: FlowChipFieldSchema = _fixed_schema()
	var creation: FlowChipFieldCreationResult = FlowChipFieldFactory.new().create(field)
	_check(creation.is_successful(), "FIXED factory creates a valid neutral document.")
	if creation.document == null:
		return
	var editor: FlowChipFieldEditor = _new_editor(field, creation.document)
	await _frames()
	var chips: Array[FlowChipSegment] = _chips(creation.document)
	_check(chips.size() == 3, "FIXED shows all mandatory factory-generated chips.")
	_check(chips[0].get_slot_id() == "start" and chips[1].get_slot_id() == "condition" \
			and chips[2].get_slot_id() == "increment",
		"FIXED chips preserve semantic slot_id order.")
	var required_id: String = chips[0].get_segment_id()
	editor.select_segment(required_id)
	_check(not editor.delete_selected_chip(), "FIXED allow_delete=false blocks mandatory deletion.")
	_check(editor.get_feedback_text().contains("cannot be deleted"),
		"FIXED deletion rejection provides clear feedback.")
	_check(editor.set_selected_chip_value(7), "FIXED mandatory chips remain editable.")
	_check((chips[0] as FlowLiteralValueSegment).value == 7,
		"FIXED editing changes the literal value in its original slot.")
	editor.refresh()
	_check(editor.get_selected_segment_id() == required_id,
		"FIXED selection survives a layout reconstruction by segment_id.")
	editor.queue_free()


func _test_flexible_schema() -> void:
	var field: FlowChipFieldSchema = _flexible_schema()
	field.flexible_max_count = 2
	field.variadic_slot_definition.max_count = 2
	var creation: FlowChipFieldCreationResult = FlowChipFieldFactory.new().create(field)
	_check(creation.is_successful(), "FLEXIBLE factory creates its minimum empty zone.")
	if creation.document == null:
		return
	var editor: FlowChipFieldEditor = _new_editor(field, creation.document)
	await _frames()
	var text: FlowTextSegment = _first_text(creation.document)
	_check(text != null and editor.set_caret_position(text.get_segment_id(), text.text.length()),
		"FLEXIBLE insertion starts from a real text caret.")
	var first_id: String = editor.insert_value()
	var second_id: String = editor.insert_value()
	_check(not first_id.is_empty() and not second_id.is_empty() and first_id != second_id,
		"FLEXIBLE inserts independent chips at the caret.")
	_check(_chips(creation.document).size() == 2, "FLEXIBLE model count matches visible chips.")
	var before_count: int = creation.document.segments.size()
	var third_id: String = editor.insert_value()
	_check(third_id.is_empty(), "FLEXIBLE blocks insertion at max_count.")
	_check(creation.document.segments.size() == before_count,
		"A max_count rejection leaves the model unchanged.")
	_check(editor.get_feedback_text().contains("Maximum chip count"),
		"FLEXIBLE max_count rejection is visible feedback.")
	editor.select_segment(second_id)
	_check(editor.move_selected_chip(-1), "FLEXIBLE allows schema-authorized movement.")
	var history: UndoRedo = _history(creation.document)
	if history != null:
		history.undo()
		_check(_find_chip(creation.document, second_id) != null,
			"Undo preserves the moved chip identity.")
		history.redo()
		_check(_find_chip(creation.document, second_id) != null,
			"Redo reapplies movement without recreating the chip.")
	editor.select_segment(second_id)
	_check(editor.delete_selected_chip(), "FLEXIBLE allows deletion above its minimum.")
	_check(_find_chip(creation.document, second_id) == null,
		"FLEXIBLE deletion removes the complete token.")
	editor.queue_free()

	var minimum_field: FlowChipFieldSchema = _flexible_schema()
	minimum_field.flexible_min_count = 1
	minimum_field.variadic_slot_definition.min_count = 1
	minimum_field.variadic_slot_definition.initial_value_source = \
		FlowLiteralValueSource.new(FlowLiteralValueSource.TYPE_INT, 0)
	var minimum_creation: FlowChipFieldCreationResult = FlowChipFieldFactory.new().create(minimum_field)
	_check(minimum_creation.document != null and _chips(minimum_creation.document).size() == 1,
		"FLEXIBLE min_count generates its required minimum.")
	if minimum_creation.document != null:
		var minimum_editor: FlowChipFieldEditor = _new_editor(minimum_field, minimum_creation.document)
		await _frames()
		var minimum_chip: FlowChipSegment = _chips(minimum_creation.document)[0]
		minimum_editor.select_segment(minimum_chip.get_segment_id())
		_check(not minimum_editor.delete_selected_chip(),
			"FLEXIBLE blocks deletion at min_count.")
		minimum_editor.queue_free()


func _test_hybrid_schema() -> void:
	var field: FlowChipFieldSchema = _hybrid_schema()
	var creation: FlowChipFieldCreationResult = FlowChipFieldFactory.new().create(field)
	_check(creation.is_successful(), "HYBRID factory creates its required named slot.")
	if creation.document == null:
		return
	var editor: FlowChipFieldEditor = _new_editor(field, creation.document)
	await _frames()
	var required: FlowChipSegment = _find_chip_by_slot(creation.document, "required")
	_check(required != null, "HYBRID renders its mandatory named chip.")
	editor.select_segment(required.get_segment_id())
	_check(not editor.delete_selected_chip(), "HYBRID required allow_delete=false is enforced.")
	var text_segments: Array[FlowTextSegment] = _texts(creation.document)
	var optional_text: FlowTextSegment = text_segments.back() if not text_segments.is_empty() else null
	_check(optional_text != null and editor.set_caret_position(optional_text.get_segment_id(), optional_text.text.length()),
		"HYBRID optional zone shares the same caret field.")
	var optional_id: String = editor.insert_value()
	_check(not optional_id.is_empty(), "HYBRID inserts into the variadic zone.")
	var optional: FlowChipSegment = _find_chip(creation.document, optional_id)
	_check(optional != null and optional.get_slot_id() == "optional" \
			and optional.get_slot_kind() == FlowChipSegment.SLOT_KIND_VARIADIC,
		"HYBRID marks each variadic occurrence with its semantic zone.")
	editor.select_segment(optional_id)
	_check(editor.delete_selected_chip(), "HYBRID allows variadic deletion independently of required chips.")
	editor.queue_free()


func _test_invalid_document_feedback() -> void:
	var field: FlowChipFieldSchema = _fixed_schema()
	var creation: FlowChipFieldCreationResult = FlowChipFieldFactory.new().create(field)
	if creation.document == null:
		return
	var invalid: FlowStructuredDocument = creation.document.duplicate_preserving_ids()
	invalid.segments.insert(1, null)
	var editor: FlowChipFieldEditor = _new_editor(field, invalid)
	await _frames()
	_check(not editor.is_document_valid(), "Invalid schema/document data is surfaced visually.")
	_check(invalid.segments[1] == null, "Validation does not repair or delete invalid content.")
	editor.queue_free()


func _new_editor(
		field: FlowChipFieldSchema,
		document: FlowStructuredDocument
) -> FlowChipFieldEditor:
	var editor: FlowChipFieldEditor = FlowChipFieldEditor.new()
	editor.size = Vector2(1000.0, 600.0)
	_host.add_child(editor)
	editor.configure_field(field, document, _undo_redo, document)
	return editor


func _fixed_schema() -> FlowChipFieldSchema:
	var field: FlowChipFieldSchema = FlowChipFieldSchema.new()
	field.mode = FlowChipFieldSchema.Mode.FIXED
	field.text_mode = FlowChipFieldSchema.TextMode.DOCUMENTATION
	field.slots = [
		_required_slot("start", FlowLiteralValueSource.TYPE_INT, 0),
		_required_slot("condition", FlowLiteralValueSource.TYPE_BOOL, true),
		_required_slot("increment", FlowLiteralValueSource.TYPE_INT, 1),
	]
	field.add_text_part("Inicio: ")
	field.add_slot_part("start")
	field.add_text_part(" Condición: ")
	field.add_slot_part("condition")
	field.add_text_part(" Incremento: ")
	field.add_slot_part("increment")
	return field


func _flexible_schema() -> FlowChipFieldSchema:
	var field: FlowChipFieldSchema = FlowChipFieldSchema.new()
	field.mode = FlowChipFieldSchema.Mode.FLEXIBLE
	field.text_mode = FlowChipFieldSchema.TextMode.DOCUMENTATION
	field.flexible_min_count = 0
	field.flexible_max_count = 3
	field.accepted_value_types = [FlowLiteralValueSource.TYPE_INT]
	field.accepted_source_kinds = [FlowValueSource.SOURCE_KIND_LITERAL]
	field.variadic_slot_definition = FlowChipSlotDefinition.new("value", "Value", false)
	field.variadic_slot_definition.repeatable = true
	field.variadic_slot_definition.max_count = 3
	field.variadic_slot_definition.accepted_value_types = [FlowLiteralValueSource.TYPE_INT]
	field.variadic_slot_definition.accepted_source_kinds = [FlowValueSource.SOURCE_KIND_LITERAL]
	field.add_text_part("Valores: ")
	field.add_slot_part("value")
	return field


func _hybrid_schema() -> FlowChipFieldSchema:
	var field: FlowChipFieldSchema = FlowChipFieldSchema.new()
	field.mode = FlowChipFieldSchema.Mode.HYBRID
	field.text_mode = FlowChipFieldSchema.TextMode.DOCUMENTATION
	field.accepted_value_types = [FlowLiteralValueSource.TYPE_INT]
	field.accepted_source_kinds = [FlowValueSource.SOURCE_KIND_LITERAL]
	field.slots = [_required_slot("required", FlowLiteralValueSource.TYPE_INT, 0)]
	field.variadic_slot_definition = FlowChipSlotDefinition.new("optional", "Optional", false)
	field.variadic_slot_definition.repeatable = true
	field.variadic_slot_definition.max_count = 2
	field.variadic_slot_definition.accepted_value_types = [FlowLiteralValueSource.TYPE_INT]
	field.variadic_slot_definition.accepted_source_kinds = [FlowValueSource.SOURCE_KIND_LITERAL]
	field.add_text_part("Obligatorio: ")
	field.add_slot_part("required")
	field.add_text_part(" Opcionales: ")
	field.add_slot_part("optional")
	return field


func _required_slot(
		slot_id: String,
		value_type: Variant.Type,
		value: Variant
) -> FlowChipSlotDefinition:
	var slot: FlowChipSlotDefinition = FlowChipSlotDefinition.new(slot_id, slot_id, true)
	slot.accepted_value_types = [value_type]
	slot.accepted_source_kinds = [FlowValueSource.SOURCE_KIND_LITERAL]
	slot.initial_value_source = FlowLiteralValueSource.new(value_type, value)
	slot.allow_delete = false
	slot.allow_reorder = false
	slot.min_count = 1
	slot.max_count = 1
	return slot


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


func _frames(count: int = 4) -> void:
	for _index: int in count:
		await process_frame


func _check(condition: bool, message: String) -> bool:
	if condition:
		return true
	_failures.append(message)
	push_error("[Flujo] Step 2A check failed: " + message)
	return false


func _finish() -> void:
	if _failures.is_empty():
		print("[Flujo] Flow chip field Step 2A test passed")
	else:
		push_error("[Flujo] Flow chip field Step 2A test failed: %d failures" % _failures.size())
	quit(0 if _failures.is_empty() else 1)
