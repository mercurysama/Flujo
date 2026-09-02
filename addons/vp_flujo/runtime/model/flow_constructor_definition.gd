@tool
class_name FlowConstructorDefinition
extends Resource

@export_storage var _internal_id: String = FlowId.create()
@export var dependencies: Array[FlowDependencyDefinition] = []

func get_internal_id() -> String:
	return _internal_id

func duplicate_with_new_ids() -> FlowConstructorDefinition:
	var copy: FlowConstructorDefinition = duplicate(false) as FlowConstructorDefinition
	copy._internal_id = FlowId.create()
	copy.dependencies = []
	for dependency: FlowDependencyDefinition in dependencies:
		copy.dependencies.append(null if dependency == null else dependency.duplicate_with_new_id())
	return copy
