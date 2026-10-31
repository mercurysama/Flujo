extends SceneTree


var _failures: Array[String] = []
var _host: Control
var _undo_redo: EditorUndoRedoManager


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	await _frames()
	_undo_redo = EditorInterface.get_editor_undo_redo()
	_check(_undo_redo != null, "Step 2B has an EditorUndoRedoManager.")
	if _undo_redo == null:
		_finish()
		return
	_host = Control.new()
	_host.name = &"FlowChipFieldStep2BTestHost"
	_host.size = Vector2(1100.0, 760.0)
	get_root().add_child(_host)

	await _test_continuous_text_unicode_and_history()
	await _test_literal_selector_and_caret_insertion()
	await _test_string_and_string_name_continuous_values()
	await _test_schema_filtering_fixed_and_hybrid()
	await _test_schema_restriction_feedback()

	_host.queue_free()
	_finish()


func _test_continuous_text_unicode_and_history() -> void:
	var document: FlowStructuredDocument = FlowStructuredDocument.new()
	var text: FlowTextSegment = FlowTextSegment.new()
	text.text = ""
	document.segments = [text]
	var editor: FlowChipFieldEditor = _new_editor(null, document)
	await _frames()
	var input: TextEdit = editor.get_text_control(text.get_segment_id())
	_check(input != null, "Step 2B uses one real TextEdit for continuous text input.")
	if input == null:
		editor.queue_free()
		return
	_check(editor.set_caret_position(text.get_segment_id(), 0), "Continuous test places the real caret.")
	await _frames(1)
	var history: UndoRedo = _history(document)
	var version_before: int = history.get_version()
	var phrase: String = "La vida es bella y mañana será mejor."
	for character: String in phrase:
		input.insert_text_at_caret(character)
		await _frames(1)
		_check(editor.get_text_control(text.get_segment_id()) == input,
			"The active TextEdit instance survives each native text change.")
		_check(get_root().gui_get_focus_owner() == input,
			"Focus remains on the active TextEdit during continuous input.")
	_check(text.text == phrase, "A complete phrase reaches the model without refocus.")
	_check(editor.get_caret_offset() == phrase.length(), "The caret remains at the native insertion offset.")
	_check(history.get_version() == version_before + 1,
		"Continuous text input is merged into one reasonable Undo action.")
	history.undo()
	_check(text.text.is_empty() and input.text.is_empty(),
		"Undo restores the exact text before continuous input.")
	history.redo()
	_check(text.text == phrase and input.text == phrase,
		"Redo restores the complete phrase without recreating the surface.")

	var unicode_text: String = "á é í ó ú Á É Í Ó Ú ñ Ñ ü Ü ¿ ¡ 日本 한글 🙂"
	input.select_all()
	input.insert_text_at_caret(unicode_text)
	await _frames(1)
	_check(text.text == unicode_text, "Spanish, CJK, Korean, and emoji input remain exact Unicode.")
	_check(editor.get_text_control(text.get_segment_id()) == input and input.has_focus(),
		"Unicode input keeps the same focused TextEdit control.")
	var pasted: String = "mañana será un buen día 🥲"
	input.select_all()
	input.insert_text_at_caret(pasted)
	await _frames(1)
	_check(text.text == pasted, "Paste-equivalent native insertion preserves the exact Unicode text.")
	_check(editor.get_caret_offset() == pasted.length(), "Paste-equivalent insertion leaves the caret at the end.")
	editor.queue_free()


func _test_literal_selector_and_caret_insertion() -> void:
	var field: FlowChipFieldSchema = _flexible_schema([
		FlowLiteralValueSource.TYPE_BOOL,
		FlowLiteralValueSource.TYPE_INT,
		FlowLiteralValueSource.TYPE_FLOAT,
		FlowLiteralValueSource.TYPE_STRING,
		FlowLiteralValueSource.TYPE_STRING_NAME,
	], 5)
	var creation: FlowChipFieldCreationResult = FlowChipFieldFactory.new().create(field)
	_check(creation.document != null, "FLEXIBLE Step 2B fixture creates a document.")
	if creation.document == null:
		return
	var editor: FlowChipFieldEditor = _new_editor(field, creation.document)
	await _frames()
	var text: FlowTextSegment = _first_text(creation.document)
	_check(text != null and editor.set_caret_position(text.get_segment_id(), text.text.length()),
		"Literal insertion starts from the exact text caret.")
	var available: Array[Variant.Type] = editor.get_insertable_literal_types()
	_check(available == [
		FlowLiteralValueSource.TYPE_BOOL,
		FlowLiteralValueSource.TYPE_INT,
		FlowLiteralValueSource.TYPE_FLOAT,
		FlowLiteralValueSource.TYPE_STRING,
		FlowLiteralValueSource.TYPE_STRING_NAME,
	], "The reusable selector exposes all five public literal types.")

	var add_button: Button = editor.find_child("AddValue", true, false) as Button
	var menu: PopupMenu = editor.find_child("LiteralTypeSelector", true, false) as PopupMenu
	_check(add_button != null and menu != null, "+ Value owns one reusable literal type PopupMenu.")
	if add_button != null and menu != null:
		add_button.pressed.emit()
		_check(menu.item_count == 5, "The + Value menu contains every compatible literal type.")
		_check(menu.get_item_text(0) == "Bool" and menu.get_item_text(1) == "Int" \
				and menu.get_item_text(2) == "Float" and menu.get_item_text(3) == "String" \
				and menu.get_item_text(4) == "StringName",
			"The literal selector labels Bool, Int, Float, String, and StringName.")
		menu.hide()

	var requested_types: Array[Variant.Type] = available.duplicate()
	for value_type: Variant.Type in requested_types:
		_check(not editor.insert_literal_type_at_caret(value_type).is_empty(),
			"The selector inserts literal type %s." % _type_name(value_type))
		await _frames(1)
	var chips: Array[FlowChipSegment] = _chips(creation.document)
	_check(chips.size() == 5, "FLEXIBLE contains one chip for each selected literal type.")
	if chips.size() == 5:
		_check((chips[0] as FlowLiteralValueSegment).value == false,
			"Bool insertion uses false as its safe default.")
		_check((chips[1] as FlowLiteralValueSegment).value == 0,
			"Int insertion uses 0 as its safe default.")
		_check((chips[2] as FlowLiteralValueSegment).value == 0.0,
			"Float insertion uses 0.0 as its safe default.")
		_check((chips[3] as FlowLiteralValueSegment).value == "",
			"String insertion uses an empty String as its safe default.")
		_check(typeof((chips[4] as FlowLiteralValueSegment).value) == Variant.Type.TYPE_STRING_NAME \
				and (chips[4] as FlowLiteralValueSegment).value == StringName(),
			"StringName insertion uses an empty StringName and retains its type.")
	var history: UndoRedo = _history(creation.document)
	var last_id: String = chips[4].get_segment_id()
	history.undo()
	_check(_find_segment(creation.document, last_id) == null,
		"Undo removes the inserted literal as one complete segment.")
	history.redo()
	_check(_find_segment(creation.document, last_id) != null,
		"Redo restores the same inserted literal segment_id.")
	editor.queue_free()

	var middle_document: FlowStructuredDocument = FlowStructuredDocument.new()
	var middle_text: FlowTextSegment = FlowTextSegment.new()
	middle_text.text = "Tengo  vidas"
	middle_document.segments = [middle_text]
	var middle_editor: FlowChipFieldEditor = _new_editor(field, middle_document)
	await _frames()
	_check(middle_editor.set_caret_position(middle_text.get_segment_id(), "Tengo ".length()),
		"Literal insertion accepts a middle caret position.")
	var middle_id: String = middle_editor.insert_literal_type_at_caret(FlowLiteralValueSource.TYPE_INT)
	_check(not middle_id.is_empty() and middle_text.text == "Tengo ",
		"Int insertion splits text before the exact caret.")
	var following: FlowTextSegment = middle_document.segments[2] as FlowTextSegment
	_check(following != null and following.text == " vidas",
		"Int insertion preserves the exact text after the caret.")
	middle_editor.queue_free()


func _test_string_and_string_name_continuous_values() -> void:
	var document: FlowStructuredDocument = FlowStructuredDocument.new()
	var literal: FlowLiteralValueSegment = FlowLiteralValueSegment.new(
		FlowLiteralValueSource.TYPE_STRING,
		""
	)
	document.segments = [literal]
	var editor: FlowChipFieldEditor = _new_editor(null, document)
	await _frames()
	editor.select_segment(literal.get_segment_id())
	var text_input: LineEdit = _value_line_edit(editor)
	_check(text_input != null, "String literal chips expose a native LineEdit value control.")
	if text_input == null:
		editor.queue_free()
		return
	text_input.grab_focus()
	var original_control: LineEdit = text_input
	var phrase: String = "los caminos de la vida"
	for character: String in phrase:
		text_input.insert_text_at_caret(character)
		text_input.text_changed.emit(text_input.text)
		await _frames(1)
		_check(_value_line_edit(editor) == original_control,
			"String editing keeps the same LineEdit for every character.")
		_check(get_root().gui_get_focus_owner() == original_control,
			"String editing keeps focus on the active LineEdit.")
	_check(literal.value == phrase and literal.value_type == FlowLiteralValueSource.TYPE_STRING,
		"String chips accept a complete phrase without per-character refocus.")

	var unicode_phrase: String = "mañana será increíble"
	text_input.select_all()
	text_input.text = unicode_phrase
	text_input.caret_column = unicode_phrase.length()
	text_input.text_changed.emit(text_input.text)
	await _frames(1)
	_check(literal.value == unicode_phrase, "String chips preserve Unicode text exactly.")
	_check(editor.change_selected_chip_type(FlowLiteralValueSource.TYPE_STRING_NAME),
		"String chips can explicitly change to StringName.")
	_check(literal.value_type == FlowLiteralValueSource.TYPE_STRING_NAME \
			and typeof(literal.value) == Variant.Type.TYPE_STRING_NAME,
		"StringName retains its own Variant.Type after type editing.")
	text_input = _value_line_edit(editor)
	_check(text_input != null, "StringName chips retain a native text value control.")
	if text_input != null:
		text_input.grab_focus()
		var name_text: String = "mañana será increíble"
		for character: String in name_text:
			text_input.insert_text_at_caret(character)
			text_input.text_changed.emit(text_input.text)
			await _frames(1)
			_check(_value_line_edit(editor) == text_input,
				"StringName editing keeps the same LineEdit for every character.")
		_check(literal.value == StringName(name_text),
			"StringName accepts a complete Unicode phrase without refocus.")
	editor.queue_free()


func _test_schema_filtering_fixed_and_hybrid() -> void:
	var fixed: FlowChipFieldSchema = _fixed_schema()
	var fixed_creation: FlowChipFieldCreationResult = FlowChipFieldFactory.new().create(fixed)
	_check(fixed_creation.document != null, "FIXED fixture creates its required chips.")
	if fixed_creation.document != null:
		var fixed_editor: FlowChipFieldEditor = _new_editor(fixed, fixed_creation.document)
		await _frames()
		var fixed_button: Button = fixed_editor.find_child("AddValue", true, false) as Button
		_check(fixed_editor.get_insertable_literal_types().is_empty() and fixed_button.disabled,
			"FIXED does not expose an additional literal insertion selector.")
		var fixed_chips: Array[FlowChipSegment] = _chips(fixed_creation.document)
		_check(fixed_chips.size() == 3 \
				and (fixed_chips[0] as FlowLiteralValueSegment).value_type == FlowLiteralValueSource.TYPE_INT \
				and (fixed_chips[1] as FlowLiteralValueSegment).value_type == FlowLiteralValueSource.TYPE_BOOL \
				and (fixed_chips[2] as FlowLiteralValueSegment).value_type == FlowLiteralValueSource.TYPE_INT,
			"FIXED generated chips retain their schema-declared types.")
		fixed_editor.select_segment(fixed_chips[0].get_segment_id())
		_check(fixed_editor.find_child("FlowChipTypeSelector", true, false) == null,
			"FIXED required chips do not show a meaningless single-type selector.")
		fixed_editor.queue_free()

	var filtered: FlowChipFieldSchema = _flexible_schema([
		FlowLiteralValueSource.TYPE_INT,
		FlowLiteralValueSource.TYPE_STRING_NAME,
	], 2)
	var filtered_creation: FlowChipFieldCreationResult = FlowChipFieldFactory.new().create(filtered)
	if filtered_creation.document != null:
		var filtered_editor: FlowChipFieldEditor = _new_editor(filtered, filtered_creation.document)
		await _frames()
		var filtered_text: FlowTextSegment = _first_text(filtered_creation.document)
		filtered_editor.set_caret_position(filtered_text.get_segment_id(), filtered_text.text.length())
		var filtered_types: Array[Variant.Type] = filtered_editor.get_insertable_literal_types()
		_check(filtered_types == [FlowLiteralValueSource.TYPE_INT, FlowLiteralValueSource.TYPE_STRING_NAME],
			"The literal selector filters types incompatible with the field schema.")
		var filtered_button: Button = filtered_editor.find_child("AddValue", true, false) as Button
		var filtered_menu: PopupMenu = filtered_editor.find_child("LiteralTypeSelector", true, false) as PopupMenu
		if filtered_button != null and filtered_menu != null:
			filtered_button.pressed.emit()
			_check(filtered_menu.item_count == 2 \
					and filtered_menu.get_item_text(0) == "Int" \
					and filtered_menu.get_item_text(1) == "StringName",
				"The + Value selector derives its options from accepted literal types.")
			filtered_menu.hide()
		var filtered_before: int = filtered_creation.document.segments.size()
		_check(filtered_editor.insert_literal_type_at_caret(FlowLiteralValueSource.TYPE_FLOAT).is_empty(),
			"An incompatible literal type is rejected before chip creation.")
		_check(filtered_creation.document.segments.size() == filtered_before,
			"Rejected schema types leave the document unchanged.")
		filtered_editor.queue_free()

	var hybrid: FlowChipFieldSchema = _hybrid_schema()
	var hybrid_creation: FlowChipFieldCreationResult = FlowChipFieldFactory.new().create(hybrid)
	_check(hybrid_creation.document != null, "HYBRID fixture creates its required structure.")
	if hybrid_creation.document != null:
		var hybrid_editor: FlowChipFieldEditor = _new_editor(hybrid, hybrid_creation.document)
		await _frames()
		var hybrid_texts: Array[FlowTextSegment] = _texts(hybrid_creation.document)
		var optional_text: FlowTextSegment = hybrid_texts.back() if not hybrid_texts.is_empty() else null
		_check(optional_text != null, "HYBRID exposes a text caret for its optional zone.")
		if optional_text != null:
			hybrid_editor.set_caret_position(optional_text.get_segment_id(), optional_text.text.length())
			_check(hybrid_editor.get_insertable_literal_types() == [
				FlowLiteralValueSource.TYPE_BOOL,
				FlowLiteralValueSource.TYPE_INT,
			], "HYBRID exposes only field-and-slot-compatible types in its optional zone.")
			var optional_id: String = hybrid_editor.insert_literal_type_at_caret(FlowLiteralValueSource.TYPE_BOOL)
			_check(not optional_id.is_empty() and (_find_segment(hybrid_creation.document, optional_id) as FlowChipSegment).get_slot_id() == "optional",
				"HYBRID inserts a selected literal only into its variadic slot.")
		var required_text: FlowTextSegment = _texts(hybrid_creation.document)[0]
		hybrid_editor.set_caret_position(required_text.get_segment_id(), 0)
		_check(hybrid_editor.get_insertable_literal_types().is_empty(),
			"HYBRID does not offer additional literals outside its optional zone.")
		hybrid_editor.queue_free()


func _test_schema_restriction_feedback() -> void:
	var maximum_field: FlowChipFieldSchema = _flexible_schema([
		FlowLiteralValueSource.TYPE_INT,
	], 1)
	var maximum_creation: FlowChipFieldCreationResult = FlowChipFieldFactory.new().create(maximum_field)
	if maximum_creation.document != null:
		var maximum_editor: FlowChipFieldEditor = _new_editor(maximum_field, maximum_creation.document)
		await _frames()
		var maximum_text: FlowTextSegment = _texts(maximum_creation.document).back()
		maximum_editor.set_caret_position(maximum_text.get_segment_id(), maximum_text.text.length())
		_check(not maximum_editor.insert_literal_type_at_caret(FlowLiteralValueSource.TYPE_INT).is_empty(),
			"The schema permits the first literal before its maximum.")
		var maximum_button: Button = maximum_editor.find_child("AddValue", true, false) as Button
		if maximum_button != null:
			maximum_button.pressed.emit()
		_check(maximum_editor.get_literal_insertion_feedback() == "Maximum chip count reached (1).",
			"+ Value distinguishes a reached max_count from an empty type intersection.")
		_check(maximum_editor.get_feedback_text() == "Maximum chip count reached (1).",
			"Maximum chip count feedback is visible after + Value is pressed.")
		maximum_editor.queue_free()

	var invalid_position_field: FlowChipFieldSchema = _hybrid_schema()
	var invalid_position_creation: FlowChipFieldCreationResult = FlowChipFieldFactory.new().create(invalid_position_field)
	if invalid_position_creation.document != null:
		var invalid_position_editor: FlowChipFieldEditor = _new_editor(
			invalid_position_field,
			invalid_position_creation.document
		)
		await _frames()
		var required_text: FlowTextSegment = _texts(invalid_position_creation.document)[0]
		invalid_position_editor.set_caret_position(required_text.get_segment_id(), 0)
		var invalid_position_button: Button = invalid_position_editor.find_child(
			"AddValue", true, false
		) as Button
		if invalid_position_button != null:
			invalid_position_button.pressed.emit()
		_check(invalid_position_editor.get_feedback_text() == "A chip cannot be inserted at this position.",
			"+ Value distinguishes an invalid caret or schema zone.")
		invalid_position_editor.queue_free()

	var incompatible_field: FlowChipFieldSchema = _flexible_schema([
		Variant.Type.TYPE_OBJECT,
	], 2)
	var incompatible_creation: FlowChipFieldCreationResult = FlowChipFieldFactory.new().create(incompatible_field)
	if incompatible_creation.document != null:
		var incompatible_editor: FlowChipFieldEditor = _new_editor(
			incompatible_field,
			incompatible_creation.document
		)
		await _frames()
		var incompatible_text: FlowTextSegment = _texts(incompatible_creation.document).back()
		incompatible_editor.set_caret_position(incompatible_text.get_segment_id(), incompatible_text.text.length())
		var incompatible_button: Button = incompatible_editor.find_child("AddValue", true, false) as Button
		if incompatible_button != null:
			incompatible_button.pressed.emit()
		_check(incompatible_editor.get_feedback_text() == "No compatible literal type is available here.",
			"+ Value distinguishes an empty schema-compatible literal intersection.")
		incompatible_editor.queue_free()

	var source_filtered_field: FlowChipFieldSchema = _flexible_schema([
		FlowLiteralValueSource.TYPE_INT,
	], 2)
	source_filtered_field.accepted_source_kinds = [FlowValueSource.SOURCE_KIND_VARIABLE_REF]
	source_filtered_field.variadic_slot_definition.accepted_source_kinds = [
		FlowValueSource.SOURCE_KIND_VARIABLE_REF,
	]
	var source_filtered_creation: FlowChipFieldCreationResult = FlowChipFieldFactory.new().create(source_filtered_field)
	if source_filtered_creation.document != null:
		var source_filtered_editor: FlowChipFieldEditor = _new_editor(
			source_filtered_field,
			source_filtered_creation.document
		)
		await _frames()
		_check(source_filtered_editor.get_insertable_literal_types().is_empty(),
			"The literal selector excludes source kinds that the schema does not accept.")
		_check(source_filtered_editor.get_literal_insertion_feedback() == "No compatible literal type is available here.",
			"Rejected literal source kinds use the no-compatible-type feedback.")
		source_filtered_editor.queue_free()

	var unlimited_field: FlowChipFieldSchema = _flexible_schema([
		FlowLiteralValueSource.TYPE_INT,
	], FlowChipFieldSchema.UNLIMITED_COUNT)
	var unlimited_creation: FlowChipFieldCreationResult = FlowChipFieldFactory.new().create(unlimited_field)
	if unlimited_creation.document != null:
		var unlimited_editor: FlowChipFieldEditor = _new_editor(unlimited_field, unlimited_creation.document)
		await _frames()
		var unlimited_text: FlowTextSegment = _texts(unlimited_creation.document).back()
		unlimited_editor.set_caret_position(unlimited_text.get_segment_id(), unlimited_text.text.length())
		_check(not unlimited_editor.insert_literal_type_at_caret(FlowLiteralValueSource.TYPE_INT).is_empty(),
			"An unlimited schema accepts a literal without inventing a UI maximum.")
		_check(unlimited_editor.get_literal_insertion_feedback().is_empty(),
			"An unlimited schema remains available after insertion.")
		unlimited_editor.queue_free()

	var minimum_field: FlowChipFieldSchema = _flexible_schema([
		FlowLiteralValueSource.TYPE_INT,
	], 3)
	minimum_field.flexible_min_count = 2
	minimum_field.variadic_slot_definition.min_count = 0
	minimum_field.variadic_slot_definition.initial_value_source = \
		FlowLiteralValueSource.new(FlowLiteralValueSource.TYPE_INT, 0)
	var minimum_creation: FlowChipFieldCreationResult = FlowChipFieldFactory.new().create(minimum_field)
	_check(minimum_creation.document != null and _chips(minimum_creation.document).size() == 2,
		"The schema flexible minimum creates its required initial chips.")
	if minimum_creation.document != null:
		var minimum_editor: FlowChipFieldEditor = _new_editor(minimum_field, minimum_creation.document)
		await _frames()
		var minimum_chip: FlowChipSegment = _chips(minimum_creation.document)[0]
		minimum_editor.select_segment(minimum_chip.get_segment_id())
		_check(not minimum_editor.delete_selected_chip(),
			"The editor respects the schema flexible minimum even when the slot minimum is lower.")
		minimum_editor.queue_free()


func _new_editor(field: FlowChipFieldSchema, document: FlowStructuredDocument) -> FlowChipFieldEditor:
	var editor: FlowChipFieldEditor = FlowChipFieldEditor.new()
	editor.size = Vector2(1000.0, 600.0)
	_host.add_child(editor)
	editor.configure_field(field, document, _undo_redo, document)
	return editor


func _flexible_schema(accepted_types: Array[Variant.Type], maximum: int) -> FlowChipFieldSchema:
	var field: FlowChipFieldSchema = FlowChipFieldSchema.new()
	field.mode = FlowChipFieldSchema.Mode.FLEXIBLE
	field.text_mode = FlowChipFieldSchema.TextMode.DOCUMENTATION
	field.flexible_min_count = 0
	field.flexible_max_count = maximum
	field.accepted_value_types = accepted_types
	field.accepted_source_kinds = [FlowValueSource.SOURCE_KIND_LITERAL]
	field.variadic_slot_definition = FlowChipSlotDefinition.new("value", "Value", false)
	field.variadic_slot_definition.repeatable = true
	field.variadic_slot_definition.max_count = maximum
	field.variadic_slot_definition.accepted_value_types = accepted_types
	field.variadic_slot_definition.accepted_source_kinds = [FlowValueSource.SOURCE_KIND_LITERAL]
	field.add_text_part("Values: ")
	field.add_slot_part("value")
	return field


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


func _hybrid_schema() -> FlowChipFieldSchema:
	var field: FlowChipFieldSchema = FlowChipFieldSchema.new()
	field.mode = FlowChipFieldSchema.Mode.HYBRID
	field.text_mode = FlowChipFieldSchema.TextMode.DOCUMENTATION
	field.accepted_value_types = [FlowLiteralValueSource.TYPE_BOOL, FlowLiteralValueSource.TYPE_INT]
	field.accepted_source_kinds = [FlowValueSource.SOURCE_KIND_LITERAL]
	field.slots = [_required_slot("required", FlowLiteralValueSource.TYPE_INT, 0)]
	field.variadic_slot_definition = FlowChipSlotDefinition.new("optional", "Optional", false)
	field.variadic_slot_definition.repeatable = true
	field.variadic_slot_definition.max_count = 2
	field.variadic_slot_definition.accepted_value_types = [
		FlowLiteralValueSource.TYPE_BOOL,
		FlowLiteralValueSource.TYPE_INT,
		FlowLiteralValueSource.TYPE_FLOAT,
	]
	field.variadic_slot_definition.accepted_source_kinds = [FlowValueSource.SOURCE_KIND_LITERAL]
	field.add_text_part("Obligatorio: ")
	field.add_slot_part("required")
	field.add_text_part(" Opcionales: ")
	field.add_slot_part("optional")
	return field


func _required_slot(slot_id: String, value_type: Variant.Type, value: Variant) -> FlowChipSlotDefinition:
	var slot: FlowChipSlotDefinition = FlowChipSlotDefinition.new(slot_id, slot_id, true)
	slot.accepted_value_types = [value_type]
	slot.accepted_source_kinds = [FlowValueSource.SOURCE_KIND_LITERAL]
	slot.initial_value_source = FlowLiteralValueSource.new(value_type, value)
	slot.allow_delete = false
	slot.allow_reorder = false
	slot.min_count = 1
	slot.max_count = 1
	return slot


func _value_line_edit(editor: FlowChipFieldEditor) -> LineEdit:
	return editor.find_child("FlowChipTextValue", true, false) as LineEdit


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


func _find_segment(document: FlowStructuredDocument, segment_id: String) -> FlowDocumentSegment:
	for segment: FlowDocumentSegment in document.segments:
		if segment != null and segment.get_segment_id() == segment_id:
			return segment
	return null


func _history(document: FlowStructuredDocument) -> UndoRedo:
	return _undo_redo.get_history_undo_redo(_undo_redo.get_object_history_id(document))


func _type_name(value_type: Variant.Type) -> String:
	return FlowChipTypeDescriptor.variant_type_display_name(value_type)


func _frames(count: int = 4) -> void:
	for _index: int in count:
		await process_frame


func _check(condition: bool, message: String) -> bool:
	if condition:
		return true
	_failures.append(message)
	push_error("[Flujo] Step 2B check failed: " + message)
	return false


func _finish() -> void:
	if _failures.is_empty():
		print("[Flujo] Flow chip field Step 2B test passed")
	else:
		push_error("[Flujo] Flow chip field Step 2B test failed: %d failures" % _failures.size())
	quit(0 if _failures.is_empty() else 1)
