@tool
extends Button

## Native Godot drag source for one NidoLab task row.

var task_id: String = ""
var list_instance_id: int = 0


func _init() -> void:
	name = "DragTask"
	text = "⠿"
	tooltip_text = "Drag to reorder task"
	custom_minimum_size = Vector2(30, 30)
	focus_mode = Control.FOCUS_ALL


func _get_drag_data(_at_position: Vector2) -> Variant:
	if task_id.is_empty() or list_instance_id == 0:
		return null
	var preview := Label.new()
	preview.text = "Move task"
	set_drag_preview(preview)
	return {"kind": "nidolab_task", "task_id": task_id, "list_id": list_instance_id}
