@tool
class_name FlowMethodOutputDefinition
extends Resource

@export_storage var _internal_id: String = FlowId.create()
@export var display_name: String = "Output"
@export var value_type: FlowVariableDefinition.ValueType = FlowVariableDefinition.ValueType.BOOL

func get_internal_id() -> String:
	return _internal_id
