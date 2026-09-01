@tool
## Produces a deterministic, read-only Editor Inspector representation of a FlowGraph.
class_name FlowGraphInspectorPresenter
extends RefCounted


## Returns schema, source, entries, IDs, and validation diagnostics without changing graph.
static func present(graph: FlowGraph) -> Dictionary:
	var presentation: Dictionary = {
		"schema_version": -1,
		"active_source": "No graph",
		"sections": [],
		"diagnostics": [],
	}
	var validation_result: FlowValidationResult = FlowGraphValidator.validate(graph)
	presentation["diagnostics"] = _present_diagnostics(validation_result)

	if graph == null:
		return presentation

	presentation["schema_version"] = graph.schema_version
	var sections: Array[Dictionary] = []
	var has_schema_2_entries: bool = not graph.processes.is_empty() \
		or not graph.variables.is_empty() \
		or not graph.state_machines.is_empty()
	if not graph.containers.is_empty() and has_schema_2_entries:
		presentation["active_source"] = "Mixed sources"
		sections.append(_present_containers(graph.containers))
		sections.append(_present_processes(graph.processes))
		sections.append(_present_variables(graph.variables))
		sections.append(_present_state_machines(graph.state_machines))
	elif graph.schema_version == FlowGraph.CURRENT_SCHEMA_VERSION:
		presentation["active_source"] = "Containers"
		sections.append(_present_containers(graph.containers))
	elif graph.schema_version == FlowGraph.SCHEMA_VERSION_2:
		presentation["active_source"] = "Typed collections"
		sections.append(_present_processes(graph.processes))
		sections.append(_present_variables(graph.variables))
		sections.append(_present_state_machines(graph.state_machines))
	else:
		presentation["active_source"] = "Unsupported schema"

	presentation["sections"] = sections
	return presentation


static func _present_containers(containers: Array[FlowBlockContainer]) -> Dictionary:
	var entries: Array[Dictionary] = []
	for index: int in containers.size():
		entries.append(_present_resource(index, containers[index]))
	return {"title": "Containers", "entries": entries}


static func _present_processes(processes: Array[FlowProcess]) -> Dictionary:
	var entries: Array[Dictionary] = []
	for index: int in processes.size():
		entries.append(_present_resource(index, processes[index]))
	return {"title": "Processes", "entries": entries}


static func _present_variables(variables: Array[FlowVariableDefinition]) -> Dictionary:
	var entries: Array[Dictionary] = []
	for index: int in variables.size():
		entries.append(_present_resource(index, variables[index]))
	return {"title": "Variables", "entries": entries}


static func _present_state_machines(
		state_machines: Array[FlowStateMachineDefinition]
) -> Dictionary:
	var entries: Array[Dictionary] = []
	for index: int in state_machines.size():
		entries.append(_present_resource(index, state_machines[index]))
	return {"title": "State Machines", "entries": entries}


static func _present_resource(index: int, resource: Resource) -> Dictionary:
	if resource == null:
		return {
			"index": index,
			"name": "Empty",
			"type": "Empty",
			"internal_id": "",
			"is_empty": true,
		}

	return {
		"index": index,
		"name": _get_display_name(resource),
		"type": _get_type_name(resource),
		"internal_id": _get_internal_id(resource),
		"is_empty": false,
	}


static func _present_diagnostics(validation_result: FlowValidationResult) -> Array[Dictionary]:
	var diagnostics: Array[Dictionary] = []
	for diagnostic: FlowDiagnostic in validation_result.diagnostics:
		diagnostics.append({
			"code": str(diagnostic.code),
			"severity": diagnostic.severity,
			"message": diagnostic.message,
			"element_path": diagnostic.element_path,
			"related_id": diagnostic.related_id,
		})
	return diagnostics


static func _get_display_name(resource: Resource) -> String:
	if resource is FlowBlockContainer:
		return (resource as FlowBlockContainer).display_name
	if resource is FlowVariableDefinition:
		return (resource as FlowVariableDefinition).display_name
	if resource is FlowStateMachineDefinition:
		return (resource as FlowStateMachineDefinition).display_name
	if resource is FlowBlock:
		return (resource as FlowBlock).display_name
	return resource.resource_name


static func _get_type_name(resource: Resource) -> String:
	if resource is FlowProcess:
		return "FlowProcess"
	if resource is FlowStateDefinition:
		return "FlowStateDefinition"
	if resource is FlowVariableDefinition:
		return "FlowVariableDefinition"
	if resource is FlowStateMachineDefinition:
		return "FlowStateMachineDefinition"
	if resource is FlowBlock:
		return "FlowBlock"
	if resource is FlowBlockContainer:
		return "FlowBlockContainer"
	return resource.get_class()


static func _get_internal_id(resource: Resource) -> String:
	if resource is FlowBlockContainer:
		return (resource as FlowBlockContainer).get_internal_id()
	if resource is FlowVariableDefinition:
		return (resource as FlowVariableDefinition).get_internal_id()
	if resource is FlowStateMachineDefinition:
		return (resource as FlowStateMachineDefinition).get_internal_id()
	if resource is FlowBlock:
		return (resource as FlowBlock).get_internal_id()
	return ""
