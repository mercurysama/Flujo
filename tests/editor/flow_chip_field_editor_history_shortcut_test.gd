extends SceneTree


var _host: Control
var _editor: FlowChipFieldEditor
var _literal: FlowLiteralValueSegment
var _failures: Array[String] = []


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	# Startup layout work can use the editor history. Begin document history
	# only after loading_editor_layout, matching the current history focals.
	await _frames(24)
	_host = Control.new()
	_host.size = Vector2(900.0, 600.0)
	get_root().add_child(_host)
	var field: FlowChipFieldSchema = FlowChipFieldSchema.new()
	field.mode = FlowChipFieldSchema.Mode.FLEXIBLE
	field.accepted_value_types = [Variant.Type.TYPE_INT]
	field.accepted_source_kinds = [FlowValueSource.SOURCE_KIND_LITERAL]
	field.flexible_max_count = 1
	var slot: FlowChipSlotDefinition = FlowChipSlotDefinition.new("value", "Value", true)
	slot.accepted_value_types = [Variant.Type.TYPE_INT]
	slot.accepted_source_kinds = [FlowValueSource.SOURCE_KIND_LITERAL]
	slot.min_count = 1
	slot.max_count = 1
	slot.allow_delete = false
	slot.allow_type_change = false
	field.variadic_slot_definition = slot
	field.add_text_part("Value: ")
	field.add_slot_part("value")
	var document: FlowStructuredDocument = FlowStructuredDocument.new()
	var text: FlowTextSegment = FlowTextSegment.new()
	text.text = "Akis"
	_literal = FlowLiteralValueSegment.new(FlowLiteralValueSource.TYPE_INT, 0)
	_literal.set_slot_id("value")
	_literal.set_slot_kind(FlowChipSegment.SLOT_KIND_VARIADIC)
	document.segments = [text, _literal]
	_editor = FlowChipFieldEditor.new()
	_editor.size = Vector2(800.0, 500.0)
	_host.add_child(_editor)
	var manager: EditorUndoRedoManager = EditorInterface.get_editor_undo_redo()
	_editor.configure_field(field, document, manager, document)
	await _frames()
	_editor.select_segment(_literal.get_segment_id())
	_check(_editor.set_selected_chip_value(25), "Literal action is recorded.")
	_editor.set_caret_position(text.get_segment_id(), text.text.length())
	await _frames()
	await _shortcut(KEY_Z)
	_check(_literal.value == 0, "Ctrl+Z undoes the Tok while text has focus.")
	await _shortcut(KEY_Z, true)
	_check(_literal.value == 25, "Ctrl+Shift+Z redoes exactly once.")
	await _shortcut(KEY_Z)
	_check(_literal.value == 0, "Ctrl+Z still works after Ctrl+Shift+Z.")
	await _shortcut(KEY_Y)
	_check(_literal.value == 25, "Ctrl+Y redoes exactly once.")
	_host.queue_free()
	if _failures.is_empty():
		print("[Flujo] Unified history shortcut test passed")
	else:
		for failure: String in _failures:
			push_error("[Flujo] " + failure)
		push_error("[Flujo] Unified history shortcut test failed")
	quit(0 if _failures.is_empty() else 1)


func _shortcut(keycode: Key, with_shift: bool = false) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.keycode = keycode
	event.ctrl_pressed = true
	event.shift_pressed = with_shift
	event.pressed = true
	get_root().push_input(event, true)
	await _frames(2)


func _frames(count: int = 4) -> void:
	for _index: int in count:
		await process_frame


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
