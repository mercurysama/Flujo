@tool
class_name FlowMethodDefinition
extends FlowBlockContainer

@export var parameters: Array[FlowMethodParameterDefinition] = []

func _init() -> void:
	display_name = "Method"

func duplicate_method_with_new_ids() -> FlowMethodDefinition:
	return duplicate_with_new_ids() as FlowMethodDefinition
