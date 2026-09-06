@tool
class_name FlowMethodCallBlock
extends FlowBlock


@export_storage var method_id: String = ""


func _init() -> void:
	display_name = "Call Method"


func duplicate_with_new_id() -> FlowBlock:
	var copy: FlowMethodCallBlock = duplicate(false) as FlowMethodCallBlock
	copy._internal_id = FlowId.create()
	return copy
