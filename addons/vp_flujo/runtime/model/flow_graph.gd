class_name FlowGraph
extends Resource

const CURRENT_SCHEMA_VERSION: int = 1

@export_storage var _internal_id: String = FlowId.create()
@export_storage var schema_version: int = CURRENT_SCHEMA_VERSION
@export var containers: Array[FlowBlockContainer] = []

func get_internal_id() -> String:
	return _internal_id

func duplicate_with_new_ids() -> FlowGraph:
	var copy: FlowGraph = FlowGraph.new()
	copy._internal_id = FlowId.create()
	copy.schema_version = schema_version

	for container: FlowBlockContainer in containers:
		if container == null:
			copy.containers.append(null)
		else:
			copy.containers.append(container.duplicate_with_new_ids())

	return copy
