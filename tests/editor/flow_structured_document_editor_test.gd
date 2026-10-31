extends SceneTree


class GenericTestChip extends FlowChipSegment:
	func get_chip_type() -> StringName:
		return &"test_chip"

	func get_chip_type_descriptor() -> FlowChipTypeDescriptor:
		var descriptor: FlowChipTypeDescriptor = FlowChipTypeDescriptor.new()
		descriptor.type_id = &"test_chip"
		descriptor.display_name = "Test chip"
		descriptor.category = &"test"
		descriptor.label_strategy = &"fixed"
		descriptor.semantic_style_role = &"literal"
		return descriptor

	func get_chip_label() -> String:
		return "custom"

	func get_chip_tooltip_data() -> FlowChipTooltipData:
		var data: FlowChipTooltipData = FlowChipTooltipData.new("Test chip")
		data.add_field("Kind", "generic")
		return data


var _failures: Array[String] = []
var _host: Control
var _editor: FlowStructuredDocumentEditor
var _document: FlowStructuredDocument
var _undo_redo: EditorUndoRedoManager
var _before: FlowTextSegment
var _literal: FlowLiteralValueSegment
var _after: FlowTextSegment


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	await _frames()
	_undo_redo = EditorInterface.get_editor_undo_redo()
	_check(_undo_redo != null, "K4 editor test has an EditorUndoRedoManager.")
	if _undo_redo == null:
		_finish()
		return

	_host = Control.new()
	_host.name = &"StructuredDocumentEditorTestHost"
	_host.size = Vector2(1000.0, 700.0)
	get_root().add_child(_host)
	_editor = FlowStructuredDocumentEditor.new()
	_editor.size = Vector2(900.0, 600.0)
	_host.add_child(_editor)
	_document = _make_document()
	_editor.configure(_document, _undo_redo)
	await _frames()

	_test_render_order()
	_test_polymorphic_chip_control()
	_test_label_and_tooltip()
	_test_selection()
	_test_value_edit_undo_redo()
	_test_type_change_undo()
	await _test_delete_undo_redo()
	await _test_insert_undo_redo()
	await _test_text_preservation()

	_document.segments.append(null)
	_editor.refresh()
	await _frames()
	_check(_editor.get_visual_elements().size() == 3, "Null segments are ignored without crashing or changing real order.")
	_finish()


func _make_document() -> FlowStructuredDocument:
	var document: FlowStructuredDocument = FlowStructuredDocument.new()
	_before = FlowTextSegment.new()
	_before.text = "Tengo "
	_literal = FlowLiteralValueSegment.new(FlowLiteralValueSegment.TYPE_INT, 3)
	_after = FlowTextSegment.new()
	_after.text = " vidas"
	document.segments = [_before, _literal, _after]
	return document


func _test_render_order() -> void:
	var elements: Array[Control] = _editor.get_visual_elements()
	_check(elements.size() == 3, "Structured document renders one visual element per non-null segment.")
	if elements.size() != 3:
		return
	_check(elements[0] == _editor.get_text_control(_before.get_segment_id()), "Text before the chip keeps its visual order.")
	_check(elements[1] == _editor.get_chip_control(_literal.get_segment_id()), "The middle segment is a real FlowChipControl.")
	_check(elements[2] == _editor.get_text_control(_after.get_segment_id()), "Text after the chip keeps its visual order.")


func _test_polymorphic_chip_control() -> void:
	var segment: GenericTestChip = GenericTestChip.new()
	var control: FlowChipControl = FlowChipControl.new()
	_host.add_child(control)
	control.set_segment(segment)
	_check(control.get_segment() is FlowChipSegment, "FlowChipControl accepts the FlowChipSegment contract.")
	_check(control.get_segment() != null and control.get_segment().get_chip_label() == "custom",
		"Generic chip behavior comes from the segment contract, not a literal subtype branch.")
	_check(control.get_semantic_style_role() == &"literal", "FlowChipControl consumes the descriptor semantic style role.")
	_check(control.tooltip_text.contains("Kind: generic"), "Generic chip tooltip fields are rendered structurally.")
	control.queue_free()


func _test_label_and_tooltip() -> void:
	var chip: FlowChipControl = _editor.get_chip_control(_literal.get_segment_id())
	_check(chip != null and chip.get_child(0) is Label, "The chip has a visible label control.")
	_check(chip != null and chip.get_child(0).text == "3", "Literal int 3 renders label 3.")
	_literal.value = 100
	_literal.value_type = FlowLiteralValueSegment.TYPE_INT
	chip.refresh()
	_check(chip.get_child(0).text == "100", "Literal int 100 renders label 100.")
	_check(chip.tooltip_text.contains("Type: Literal"), "Tooltip receives the structured Type field.")
	_check(chip.tooltip_text.contains("Value: 100"), "Tooltip receives the structured Value field.")
	_check(chip.tooltip_text.contains("Variant: int"), "Tooltip receives the structured Variant field.")
	_literal.value = 3


func _test_selection() -> void:
	var chip: FlowChipControl = _editor.get_chip_control(_literal.get_segment_id())
	chip.select()
	_check(_editor.get_selected_segment_id() == _literal.get_segment_id(), "Selection identity uses the chip segment_id.")
	_check(chip.is_selected(), "The selected chip exposes its selected visual state.")
	_check(_editor.get_segment_control(_literal.get_segment_id()) == chip, "Selection does not use an Array index as identity.")


func _test_value_edit_undo_redo() -> void:
	_editor.select_segment(_literal.get_segment_id())
	_check(_editor.set_selected_chip_value(5), "Changing an int chip value is accepted through the generic edit contract.")
	_check(_literal.value == 5 and _literal.get_chip_label() == "5", "Value edit updates model and label from 3 to 5.")
	_history().undo()
	_check(_literal.value == 3 and _literal.get_chip_label() == "3", "Undo restores the original literal value.")
	_history().redo()
	_check(_literal.value == 5 and _literal.get_chip_label() == "5", "Redo reapplies the literal value edit.")


func _test_type_change_undo() -> void:
	_check(_editor.change_selected_chip_type(FlowLiteralValueSegment.TYPE_FLOAT),
		"Changing int to float is an explicit generic type operation.")
	_check(_literal.value_type == FlowLiteralValueSegment.TYPE_FLOAT and _literal.value == 0.0,
		"Type change uses the descriptor default float value without silent conversion.")
	_history().undo()
	_check(_literal.value_type == FlowLiteralValueSegment.TYPE_INT and _literal.value == 5,
		"Undo restores both the original type and original value.")
	_history().redo()
	_check(_literal.value_type == FlowLiteralValueSegment.TYPE_FLOAT and _literal.value == 0.0,
		"Redo restores the same explicit type/default operation.")
	_history().undo()


func _test_delete_undo_redo() -> void:
	var literal_id: String = _literal.get_segment_id()
	_check(_editor.delete_selected_chip(), "Delete acts on the selected chip as one unit.")
	_check(_document.segments.size() == 2, "Delete removes the complete chip segment.")
	_check(_document.segments[0] == _before and _document.segments[1] == _after,
		"Delete preserves text before and after the chip.")
	_history().undo()
	_check(_document.segments.size() == 3 and _document.segments[1].get_segment_id() == literal_id,
		"Undo restores the exact deleted segment and ID at its original position.")
	_history().redo()
	_check(_document.segments.size() == 2 and _find_id(literal_id) == -1,
		"Redo removes the same complete chip again.")
	_history().undo()
	await _frames()
	_editor.select_segment(literal_id)


func _test_insert_undo_redo() -> void:
	_editor.set_current_position(_before.get_segment_id())
	var inserted_id: String = _editor.insert_value()
	_check(FlowId.is_valid(inserted_id), "+ Value creates a valid FlowId-backed literal chip.")
	_check(_document.segments.size() == 5 and _document.segments[1].get_segment_id() == inserted_id,
		"+ Value inserts at the current character caret position.")
	_check(_document.segments[1] is FlowLiteralValueSegment and (_document.segments[1] as FlowLiteralValueSegment).value == 0,
		"+ Value uses the safe int 0 initial value.")
	_history().undo()
	_check(_find_id(inserted_id) == -1, "Undo of + Value removes exactly the created chip.")
	_history().redo()
	_check(_find_id(inserted_id) == 1, "Redo of + Value restores the same segment ID and position.")
	_history().undo()


func _test_text_preservation() -> void:
	var exact_text: String = "  línea\n\tUnicode ñ 日本\n@ # $  "
	_editor.set_current_position(_after.get_segment_id())
	_check(_editor.set_text_segment_text(_after.get_segment_id(), exact_text), "Text segment accepts an explicit literal text edit.")
	_check(_after.text == exact_text, "Text edit preserves whitespace, multiline content, Unicode, and @/#/$ exactly.")
	_history().undo()
	_check(_after.text == " vidas", "Undo restores the previous exact text segment.")
	_history().redo()
	_check(_after.text == exact_text, "Redo restores the exact literal text without parsing symbols.")


func _find_id(segment_id: String) -> int:
	for index: int in _document.segments.size():
		var segment: FlowDocumentSegment = _document.segments[index]
		if segment != null and segment.get_segment_id() == segment_id:
			return index
	return -1


func _history() -> UndoRedo:
	return _undo_redo.get_history_undo_redo(_undo_redo.get_object_history_id(_document))


func _frames(count: int = 4) -> void:
	for _index: int in count:
		await process_frame


func _check(condition: bool, message: String) -> bool:
	if not condition:
		_failures.append(message)
		push_error(message)
	return condition


func _finish() -> void:
	if is_instance_valid(_host):
		_host.queue_free()
	if _failures.is_empty():
		print("[Flujo] Structured document editor K4 test passed")
	quit(0 if _failures.is_empty() else 1)
