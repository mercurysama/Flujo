extends SceneTree


var _host: Control
var _editor: FlowChipFieldEditor
var _literal: FlowLiteralValueSegment
var _history: UndoRedo
var _failures: Array[String] = []


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	await _frames(24)
	var manager: EditorUndoRedoManager = EditorInterface.get_editor_undo_redo()
	_check(manager != null, "EditorUndoRedoManager is available.")
	if manager == null:
		_finish()
		return

	_host = Control.new()
	_host.size = Vector2(900.0, 600.0)
	get_root().add_child(_host)

	var document: FlowStructuredDocument = FlowStructuredDocument.new()
	var text: FlowTextSegment = FlowTextSegment.new()
	text.text = "Akis"
	_literal = FlowLiteralValueSegment.new(FlowLiteralValueSource.TYPE_INT, 0)
	document.segments = [text, _literal]

	_editor = FlowChipFieldEditor.new()
	_editor.size = Vector2(800.0, 500.0)
	_host.add_child(_editor)
	_editor.configure_field(null, document, manager, document)
	await _frames()
	_history = manager.get_history_undo_redo(manager.get_object_history_id(document))

	_editor.select_segment(_literal.get_segment_id())
	_check(_editor.set_selected_chip_value(25), "The probe creates one literal history action.")
	_editor.set_caret_position(text.get_segment_id(), text.text.length())
	await _frames()

	await _shortcut(KEY_Z)
	_check(_literal.value == 0, "Ctrl+Z undoes the action.")
	_check(_history.has_redo(), "Ctrl+Z leaves one redo action in the owning history.")

	await _shortcut(KEY_Z, true)
	_check(_literal.value == 25, "Ctrl+Shift+Z redoes the action.")

	await _shortcut(KEY_Z)
	_check(_literal.value == 0, "A later Ctrl+Z still undoes the action.")

	await _shortcut(KEY_Y)
	_check(_literal.value == 25, "Ctrl+Y redoes the action through the same history.")

	_editor.queue_free()
	_host.queue_free()
	_finish()


func _shortcut(keycode: Key, with_shift: bool = false) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.keycode = keycode
	event.ctrl_pressed = true
	event.shift_pressed = with_shift
	event.pressed = true
	get_root().push_input(event, true)
	await _frames(3)


func _frames(count: int = 4) -> void:
	for _index: int in count:
		await process_frame


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	_failures.append(message)
	push_error("[Flujo] shortcut phase probe failed: " + message)


func _finish() -> void:
	if _failures.is_empty():
		print("[Flujo] Shortcut cycle test passed")
	else:
		push_error("[Flujo] Shortcut cycle test failed: %d failures" % _failures.size())
	quit(0 if _failures.is_empty() else 1)
