@tool
class_name FlowBlockContainer
extends Resource


@export_storage var _internal_id: String = FlowId.create()

@export var display_name: String = "Container"
@export var enabled: bool = true
@export_multiline var user_note: String = ""
@export var blocks: Array[FlowBlock] = []


func get_internal_id() -> String:
	return _internal_id


func duplicate_with_new_ids() -> FlowBlockContainer:
	var copy: FlowBlockContainer = duplicate(false) as FlowBlockContainer
	copy._internal_id = FlowId.create()
	copy.blocks = []

	for block: FlowBlock in blocks:
		if block == null:
			copy.blocks.append(null)
		else:
			copy.blocks.append(block.duplicate_with_new_id())

	return copy
