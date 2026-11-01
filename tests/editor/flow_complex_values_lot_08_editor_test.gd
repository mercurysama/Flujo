extends SceneTree


var _failures: Array[String] = []
var _host: Control
var _undo_redo: EditorUndoRedoManager


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	await _frames(2)
	_undo_redo = EditorInterface.get_editor_undo_redo()
	_check(_undo_redo != null, "Complex editor has an Akis history.")
	_host = Control.new()
	_host.size = Vector2(1100.0, 760.0)
	get_root().add_child(_host)
	await _test_structured_menu_and_array_insert()
	await _test_fixed_complex_edit_identity()
	await _test_array_scalar_no_default()
	await _test_enum_requires_explicit_selection()
	await _test_resource_requires_path()
	await _test_schema_filters_structured_menu()
	_host.queue_free()
	_finish()


func _test_structured_menu_and_array_insert() -> void:
	var schema: FlowChipFieldSchema = _structured_schema()
	var document: FlowStructuredDocument = _text_document("")
	var editor: FlowChipFieldEditor = _new_editor(schema, document)
	await _frames(2)

	var add_button: Button = editor.find_child(
		"AddStructuredValue",
		true,
		false
	) as Button
	_check(add_button != null, "Akis exposes + Structured.")
	if add_button != null:
		add_button.pressed.emit()
	await _frames(1)

	var menu: PopupMenu = editor.find_child(
		"StructuredTypeSelector",
		true,
		false
	) as PopupMenu
	_check(menu != null and menu.item_count == 5,
		"Structured schema exposes Array, Dictionary, Resource, Enum and Bitfield.")
	if menu != null:
		menu.id_pressed.emit(FlowChipFieldEditor.STRUCTURED_MENU_ARRAY)
	await _frames(1)

	var complex: FlowComplexValueEditor = editor.get_complex_editor()
	_check(
		complex != null
			and complex.visible
			and complex.get_draft() is FlowArrayValueSource
			and complex.can_confirm(),
		"Choosing Array opens a detached empty Array draft."
	)
	var confirm: Button = complex.find_child("ConfirmComplexValue", true, false) as Button
	if confirm != null:
		confirm.pressed.emit()
	await _frames(2)

	var segment: FlowArraySegment = _first_array(document)
	_check(segment != null, "Confirm inserts one semantic Array Tok.")
	var history: UndoRedo = _history(document)
	history.undo()
	_check(_first_array(document) == null, "Undo removes inserted Array Tok.")
	history.redo()
	_check(_first_array(document) != null, "Redo restores inserted Array Tok.")
	editor.queue_free()


func _test_fixed_complex_edit_identity() -> void:
	var initial: FlowArrayValueSource = FlowArrayValueSource.new()
	var schema: FlowChipFieldSchema = _fixed_schema(
		Variant.Type.TYPE_ARRAY,
		FlowValueSource.SOURCE_KIND_ARRAY,
		initial,
		false
	)
	var creation: FlowChipFieldCreationResult = FlowChipFieldFactory.new().create(schema)
	_check(creation.document != null, "Factory creates fixed Array fixture.")
	if creation.document == null:
		return
	var document: FlowStructuredDocument = creation.document
	var segment: FlowArraySegment = _first_array(document)
	var original_segment_id: String = segment.segment_id
	var original_source_id: String = segment.get_value_source().source_id

	var editor: FlowChipFieldEditor = _new_editor(schema, document)
	await _frames(2)
	var chip: FlowChipControl = editor.get_chip_control(segment.segment_id)
	var enter: InputEventKey = InputEventKey.new()
	enter.keycode = KEY_ENTER
	enter.pressed = true
	chip._gui_input(enter)
	await _frames(1)
	var complex: FlowComplexValueEditor = editor.get_complex_editor()
	_check(complex.visible, "Enter on Array Tok opens structured editor.")
	complex.set_draft(FlowArrayValueSource.new([
		FlowLiteralValueSource.new(Variant.Type.TYPE_INT, 1),
		FlowLiteralValueSource.new(Variant.Type.TYPE_STRING, "two"),
	]))
	var confirm: Button = complex.find_child("ConfirmComplexValue", true, false) as Button
	if confirm != null:
		confirm.pressed.emit()
	await _frames(2)

	segment = _first_array(document)
	var source: FlowArrayValueSource = segment.get_value_source() as FlowArrayValueSource
	_check(
		segment.segment_id == original_segment_id
			and source.source_id == original_source_id
			and source.elements.size() == 2,
		"Editing Array preserves segment_id/source_id and changes structured content."
	)
	var history: UndoRedo = _history(document)
	history.undo()
	segment = _first_array(document)
	source = segment.get_value_source() as FlowArrayValueSource
	_check(source.elements.is_empty(), "Undo restores previous Array tree.")
	history.redo()
	segment = _first_array(document)
	source = segment.get_value_source() as FlowArrayValueSource
	_check(source.elements.size() == 2, "Redo restores edited Array tree.")
	editor.queue_free()


func _test_array_scalar_no_default() -> void:
	var complex: FlowComplexValueEditor = FlowComplexValueEditor.new()
	_host.add_child(complex)
	complex.open_for_source(FlowArrayValueSource.new(), null, Rect2(20, 20, 1, 1))
	await _frames(1)
	var add_scalar: Button = _button_with_text(complex, "Add Scalar")
	_check(add_scalar != null, "Array editor exposes Add Scalar.")
	if add_scalar != null:
		add_scalar.pressed.emit()
	await _frames(1)
	_check(
		not complex.can_confirm(),
		"New collection scalar has no implicit type/value."
	)
	var type_menu: OptionButton = _first_option_button(complex)
	_check(
		type_menu != null and type_menu.get_item_text(0) == "[Select type...]",
		"Collection scalar begins at explicit Select type."
	)
	if type_menu != null:
		type_menu.select(2)
		type_menu.item_selected.emit(2)
	await _frames(1)
	_check(complex.can_confirm(), "Choosing an explicit scalar type completes the Array.")
	complex.hide()
	complex.queue_free()


func _test_enum_requires_explicit_selection() -> void:
	var source: FlowEnumValueSource = FlowEnumValueSource.new(
		&"Mode",
		[&"A", &"B"],
		[0, 1],
		0,
		false
	)
	var complex: FlowComplexValueEditor = FlowComplexValueEditor.new()
	_host.add_child(complex)
	complex.open_for_source(source, null, Rect2(30, 30, 1, 1))
	await _frames(1)
	_check(not complex.can_confirm(), "Enum with options but no explicit selection cannot Confirm.")
	var selected: OptionButton = complex.find_child(
		"EnumSelectedValue",
		true,
		false
	) as OptionButton
	_check(selected != null and selected.selected == 0,
		"Enum UI remains on Select option even though value 0 exists.")
	if selected != null:
		selected.select(1)
		selected.item_selected.emit(1)
	await _frames(1)
	var draft: FlowEnumValueSource = complex.get_draft() as FlowEnumValueSource
	_check(
		complex.can_confirm()
			and draft.has_selection
			and draft.get_preview() == "Mode.A",
		"Explicit Enum selection enables Confirm and preserves semantic label."
	)
	complex.hide()
	complex.queue_free()


func _test_resource_requires_path() -> void:
	var complex: FlowComplexValueEditor = FlowComplexValueEditor.new()
	_host.add_child(complex)
	complex.open_for_source(
		FlowResourceRefValueSource.placeholder(&"Resource"),
		null,
		Rect2(40, 40, 1, 1)
	)
	await _frames(1)
	_check(not complex.can_confirm(), "Resource placeholder cannot Confirm without a path.")
	var path: LineEdit = complex.find_child("ResourcePath", true, false) as LineEdit
	if path != null:
		path.text = "res://example.tres"
		path.text_changed.emit(path.text)
	await _frames(1)
	_check(complex.can_confirm(), "Explicit Resource path enables authoring Confirm.")
	complex.hide()
	complex.queue_free()


func _test_schema_filters_structured_menu() -> void:
	var schema: FlowChipFieldSchema = FlowChipFieldSchema.new()
	schema.mode = FlowChipFieldSchema.Mode.FLEXIBLE
	schema.text_mode = FlowChipFieldSchema.TextMode.RUNTIME_CONTENT
	schema.accepted_value_types = [Variant.Type.TYPE_ARRAY]
	schema.accepted_source_kinds = [FlowValueSource.SOURCE_KIND_ARRAY]
	var slot: FlowChipSlotDefinition = FlowChipSlotDefinition.new("array", "Array")
	slot.repeatable = true
	slot.max_count = 2
	slot.accepted_value_types = [Variant.Type.TYPE_ARRAY]
	slot.accepted_source_kinds = [FlowValueSource.SOURCE_KIND_ARRAY]
	schema.variadic_slot_definition = slot
	schema.add_text_part("")
	schema.add_slot_part("array")

	var document: FlowStructuredDocument = _text_document("")
	var editor: FlowChipFieldEditor = _new_editor(schema, document)
	await _frames(2)
	var add_button: Button = editor.find_child("AddStructuredValue", true, false) as Button
	if add_button != null:
		add_button.pressed.emit()
	await _frames(1)
	var menu: PopupMenu = editor.find_child(
		"StructuredTypeSelector",
		true,
		false
	) as PopupMenu
	_check(
		menu != null
			and menu.item_count == 1
			and menu.get_item_id(0) == FlowChipFieldEditor.STRUCTURED_MENU_ARRAY,
		"+ Structured only exposes source kinds accepted by the active schema."
	)
	editor.queue_free()


func _structured_schema() -> FlowChipFieldSchema:
	var field: FlowChipFieldSchema = FlowChipFieldSchema.new()
	field.mode = FlowChipFieldSchema.Mode.FLEXIBLE
	field.text_mode = FlowChipFieldSchema.TextMode.RUNTIME_CONTENT
	field.accepted_value_types = [
		Variant.Type.TYPE_ARRAY,
		Variant.Type.TYPE_DICTIONARY,
		Variant.Type.TYPE_OBJECT,
		Variant.Type.TYPE_INT,
	]
	field.accepted_source_kinds = [
		FlowValueSource.SOURCE_KIND_ARRAY,
		FlowValueSource.SOURCE_KIND_DICTIONARY,
		FlowValueSource.SOURCE_KIND_RESOURCE_REF,
		FlowValueSource.SOURCE_KIND_ENUM,
		FlowValueSource.SOURCE_KIND_BITFIELD,
	]
	field.flexible_max_count = 5
	var slot: FlowChipSlotDefinition = FlowChipSlotDefinition.new("structured", "Structured")
	slot.repeatable = true
	slot.max_count = 5
	slot.accepted_value_types = field.accepted_value_types.duplicate()
	slot.accepted_source_kinds = field.accepted_source_kinds.duplicate()
	field.variadic_slot_definition = slot
	field.add_text_part("")
	field.add_slot_part("structured")
	return field


func _fixed_schema(
		value_type: Variant.Type,
		source_kind: StringName,
		source: FlowValueSource,
		reference_policy: bool
) -> FlowChipFieldSchema:
	var field: FlowChipFieldSchema = FlowChipFieldSchema.new()
	field.mode = FlowChipFieldSchema.Mode.FIXED
	field.text_mode = FlowChipFieldSchema.TextMode.DISABLED
	field.accepted_value_types = [value_type]
	field.accepted_source_kinds = [source_kind]
	var slot: FlowChipSlotDefinition = FlowChipSlotDefinition.new("value", "Value", true)
	slot.accepted_value_types = [value_type]
	slot.accepted_source_kinds = [source_kind]
	slot.initial_value_source = source
	slot.min_count = 1
	slot.max_count = 1
	slot.allow_delete = false
	slot.allow_content_change = not reference_policy
	slot.allow_reference_change = reference_policy
	field.slots = [slot]
	field.add_slot_part("value")
	return field


func _new_editor(
		schema: FlowChipFieldSchema,
		document: FlowStructuredDocument
) -> FlowChipFieldEditor:
	var editor: FlowChipFieldEditor = FlowChipFieldEditor.new()
	editor.size = Vector2(960.0, 600.0)
	_host.add_child(editor)
	editor.configure_field(schema, document, _undo_redo, document)
	return editor


func _text_document(value: String) -> FlowStructuredDocument:
	var document: FlowStructuredDocument = FlowStructuredDocument.new()
	var text: FlowTextSegment = FlowTextSegment.new()
	text.text = value
	document.segments = [text]
	return document


func _first_array(document: FlowStructuredDocument) -> FlowArraySegment:
	for candidate: FlowDocumentSegment in document.segments:
		if candidate is FlowArraySegment:
			return candidate as FlowArraySegment
	return null


func _button_with_text(root: Node, text_value: String) -> Button:
	for child: Node in root.find_children("*", "Button", true, false):
		var button: Button = child as Button
		if button != null and button.text == text_value:
			return button
	return null


func _first_option_button(root: Node) -> OptionButton:
	for child: Node in root.find_children("*", "OptionButton", true, false):
		var menu: OptionButton = child as OptionButton
		if menu != null:
			return menu
	return null


func _history(document: FlowStructuredDocument) -> UndoRedo:
	return _undo_redo.get_history_undo_redo(
		_undo_redo.get_object_history_id(document)
	)


func _frames(count: int = 1) -> void:
	for _index: int in count:
		await process_frame


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	_failures.append(message)
	push_error("[Flujo] Lot 08 complex editor check failed: " + message)


func _finish() -> void:
	if _failures.is_empty():
		print("[Flujo] Lot 08 complex editor test passed")
	else:
		push_error(
			"[Flujo] Lot 08 editor test failed: %d failures" % _failures.size()
		)
	quit(0 if _failures.is_empty() else 1)
