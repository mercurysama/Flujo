@tool
extends Control


var _harness: FlowStructuredDocumentEditorHarness


func _ready() -> void:
	if not Engine.is_editor_hint():
		return
	_harness = FlowStructuredDocumentEditorHarness.new()
	add_child(_harness)
	_harness.configure(EditorInterface.get_editor_undo_redo())
	_harness.popup_centered()
