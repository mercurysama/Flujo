@tool
class_name FlowMethodReturnDefinition
extends Resource


@export_storage var _internal_id: String = FlowId.create()
@export var display_name: String = "Return"
@export var value_type: FlowVariableDefinition.ValueType = FlowVariableDefinition.ValueType.BOOL


func get_internal_id() -> String:
	return _internal_id


func duplicate_with_new_id() -> FlowMethodReturnDefinition:
	var copy: FlowMethodReturnDefinition = duplicate(false) as FlowMethodReturnDefinition
	copy._internal_id = FlowId.create()
	return copy
