@tool
class_name FlowMethodParameterDefinition
extends Resource

@export_storage var _internal_id: String = FlowId.create()
@export var display_name: String = "Parameter"
@export var value_type: FlowVariableDefinition.ValueType = FlowVariableDefinition.ValueType.BOOL

func get_internal_id() -> String:
	return _internal_id

func duplicate_with_new_id() -> FlowMethodParameterDefinition:
	var copy: FlowMethodParameterDefinition = duplicate(false) as FlowMethodParameterDefinition
	copy._internal_id = FlowId.create()
	return copy
