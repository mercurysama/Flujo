@tool
class_name FlowDependencyDefinition
extends Resource

@export_storage var _internal_id: String = FlowId.create()
@export var display_name: String = "Dependency"
@export var enabled: bool = true
@export_multiline var user_note: String = ""
@export var required_class_name: StringName = &"Node"
@export var required: bool = true

func get_internal_id() -> String:
	return _internal_id

func duplicate_with_new_id() -> FlowDependencyDefinition:
	var copy: FlowDependencyDefinition = duplicate(false) as FlowDependencyDefinition
	copy._internal_id = FlowId.create()
	return copy
