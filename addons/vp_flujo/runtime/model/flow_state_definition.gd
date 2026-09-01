@tool
class_name FlowStateDefinition
extends FlowBlockContainer

@export var is_initial: bool = false

func _init() -> void:
	display_name = "State"

func duplicate_state_with_new_ids() -> FlowStateDefinition:
	return duplicate_with_new_ids() as FlowStateDefinition
