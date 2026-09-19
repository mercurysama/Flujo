@tool
## Ownership traversal for schema 5 only. References contain IDs, not owned targets.
class_name FlowSchema5Model
extends RefCounted

static func owned_records(root: Resource) -> Array[Dictionary]:
	var records: Array[Dictionary] = []
	var visited: Dictionary[int, bool] = {}
	_collect(root, "graph", records, visited)
	return records

static func _collect(value: Resource, path: String, records: Array[Dictionary], visited: Dictionary[int, bool]) -> void:
	if value == null or not value.has_method("get_internal_id"):
		return
	records.append({"resource": value, "path": path})
	if visited.has(value.get_instance_id()):
		return
	visited[value.get_instance_id()] = true
	for property: Dictionary in value.get_property_list():
		if not (int(property.usage) & PROPERTY_USAGE_STORAGE) or property.name == &"script":
			continue
		var child: Variant = value.get(property.name)
		var child_path: String = String(property.name) if path == "graph" else path + "." + String(property.name)
		if child is Resource:
			_collect(child as Resource, child_path, records, visited)
		elif child is Array:
			for index: int in child.size():
				if child[index] is Resource:
					_collect(child[index] as Resource, "%s[%d]" % [child_path, index], records, visited)

static func has_owned_reference(root: Resource) -> bool:
	for record: Dictionary in owned_records(root):
		if record.resource is FlowReferenceDefinition:
			return true
	return false

## Inventory first: one map, no overwritten reservations, invalid IDs remain literal.
static func duplicate_owned(source: Resource) -> Resource:
	var counts: Dictionary[String, int] = {}
	for record: Dictionary in owned_records(source):
		var original: Resource = record.resource
		var original_id: String = String(original.call(&"get_internal_id"))
		counts[original_id] = counts.get(original_id, 0) + 1
	var id_map: Dictionary[String, String] = {}
	for original_id: String in counts:
		if counts[original_id] == 1 and FlowId.is_valid(original_id):
			id_map[original_id] = FlowId.create()
	var copy: Resource = source.duplicate_deep(Resource.DEEP_DUPLICATE_ALL)
	var visited: Dictionary[int, bool] = {}
	for record: Dictionary in owned_records(copy):
		var value: Resource = record.resource
		if visited.has(value.get_instance_id()):
			continue
		visited[value.get_instance_id()] = true
		var original_id: String = String(value.call(&"get_internal_id"))
		value.set("_internal_id", id_map.get(original_id, original_id))
		if value is FlowReferenceDefinition:
			var reference: FlowReferenceDefinition = value as FlowReferenceDefinition
			if id_map.has(reference.target_class_id) or not source is FlowGraph:
				reference.target_id = id_map.get(reference.target_id, reference.target_id)
			reference.target_class_id = id_map.get(reference.target_class_id, reference.target_class_id)
		elif value is FlowVariableDefinition:
			var variable: FlowVariableDefinition = value as FlowVariableDefinition
			variable.owner_container_id = id_map.get(variable.owner_container_id, variable.owner_container_id)
			variable.global_variable_id = id_map.get(variable.global_variable_id, variable.global_variable_id)
		elif value is FlowStateMachineDefinition:
			var machine: FlowStateMachineDefinition = value as FlowStateMachineDefinition
			machine.initial_state_id = id_map.get(machine.initial_state_id, machine.initial_state_id)
		elif value is FlowMethodCallBlock:
			var call: FlowMethodCallBlock = value as FlowMethodCallBlock
			call.method_id = id_map.get(call.method_id, call.method_id)
		elif value is FlowGraph:
			var graph: FlowGraph = value as FlowGraph
			graph.base_class_id = id_map.get(graph.base_class_id, graph.base_class_id)
	return copy
