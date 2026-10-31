@tool
## Ephemeral runtime context used by FlowValueSource resolution.
class_name FlowValueResolutionContext
extends RefCounted


var graph: FlowGraph = null
var _variable_values: Dictionary = {}


func _init(new_graph: FlowGraph = null) -> void:
	graph = new_graph


func set_variable_value(variable_id: String, runtime_value: Variant) -> void:
	_variable_values[variable_id] = runtime_value


func erase_variable_value(variable_id: String) -> void:
	_variable_values.erase(variable_id)


func has_variable_value(variable_id: String) -> bool:
	return _variable_values.has(variable_id)


func get_variable_value(variable_id: String) -> Variant:
	return _variable_values.get(variable_id, null)


func clear_runtime_values() -> void:
	_variable_values.clear()
