extends SceneTree


class ProbeEditor extends FlowChipFieldEditor:
	func _input(event: InputEvent) -> void:
		if event is InputEventKey:
			var key: InputEventKey = event as InputEventKey
			print(
				"[Flujo] history probe input key=%s pressed=%s ctrl=%s shift=%s focus=%s value=%s"
				% [
					key.keycode,
					key.pressed,
					key.ctrl_pressed,
					key.shift_pressed,
					get_viewport().gui_get_focus_owner(),
					_probe_value(),
				]
			)
		super._input(event)

	func _probe_value() -> String:
		var selected: FlowChipSegment = _selected_chip()
		return String(selected.get_editable_value()) if selected != null else "<none>"


var _failures: Array[String] = []
var _host: Control
var _manager: EditorUndoRedoManager


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	# Godot may still be restoring the editor layout during the first frames;
	# create document history only after that startup phase has completed.
	await _frames(24)
	_manager = EditorInterface.get_editor_undo_redo()
	_check(_manager != null, "The history probe has an EditorUndoRedoManager.")
	if _manager == null:
		_finish()
		return
	_host = Control.new()
	_host.size = Vector2(1000.0, 700.0)
	get_root().add_child(_host)

	var document: FlowStructuredDocument = FlowStructuredDocument.new()
	var text: FlowTextSegment = FlowTextSegment.new()
	text.text = "native"
	var literal: FlowLiteralValueSegment = FlowLiteralValueSegment.new(
		FlowLiteralValueSource.TYPE_STRING,
		""
	)
	document.segments = [text, literal]
	var editor: ProbeEditor = ProbeEditor.new()
	editor.size = Vector2(900.0, 600.0)
	_host.add_child(editor)
	editor.configure_field(null, document, _manager, document)
	await _frames()
	editor.select_segment(literal.get_segment_id())
	_check(editor.set_selected_chip_value("A"), "The probe records one literal action.")
	editor.set_caret_position(text.get_segment_id(), text.text.length())
	await _frames()
	var input: TextEdit = editor.get_text_control(text.get_segment_id())
	_check(input != null and input.has_focus(), "TextEdit owns focus before shortcuts.")

	await _shortcut(KEY_Z)
	_check(literal.value == "" and text.text == "native", "Ctrl+Z undoes the latest Akis action.")
	await _shortcut(KEY_Y)
	_check(literal.value == "A" and text.text == "native", "Ctrl+Y redoes exactly one Akis action.")
	if input != null:
		input.insert_text_at_caret("!")
		await _frames()
		_check(text.text == "native!", "TextEdit native insertion reaches the document.")

	var value_input: LineEdit = editor.find_child("FlowChipTextValue", true, false) as LineEdit
	_check(value_input == null, "The unfocused literal detail editor is not active.")
	editor.select_segment(literal.get_segment_id())
	await _frames()
	value_input = editor.find_child("FlowChipTextValue", true, false) as LineEdit
	_check(value_input != null, "String Literal Tok exposes native LineEdit editing.")
	if value_input != null:
		value_input.grab_focus()
		value_input.caret_column = value_input.text.length()
		value_input.insert_text_at_caret("B")
		value_input.text_changed.emit(value_input.text)
		await _frames()
		_check(literal.value == "AB", "LineEdit native insertion reaches the Literal Tok.")

	editor.queue_free()
	_host.queue_free()
	_finish()


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
	if condition:
		return
	_failures.append(message)
	push_error("[Flujo] unified history focal failed: " + message)


func _finish() -> void:
	if _failures.is_empty():
		print("[Flujo] Unified history focal passed")
	else:
		push_error("[Flujo] Unified history focal failed: %d failures" % _failures.size())
	quit(0 if _failures.is_empty() else 1)
