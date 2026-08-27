class_name FlowBlock
extends Resource


@export_storage var _internal_id: String = FlowId.create()

@export var display_name: String = "Block"
@export var enabled: bool = true
@export_multiline var user_note: String = ""


func get_internal_id() -> String:
	return _internal_id


func duplicate_with_new_id() -> FlowBlock:
	var copy: FlowBlock = duplicate(true) as FlowBlock
	copy._internal_id = FlowId.create()
	return copy
