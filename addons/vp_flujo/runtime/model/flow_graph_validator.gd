@tool
## Validates FlowGraph schema 1 and schema 2 deterministically without modifying it.
class_name FlowGraphValidator
extends RefCounted


## Validates a graph and returns all structured diagnostics in traversal order.
static func validate(graph: FlowGraph) -> FlowValidationResult:
	var result: FlowValidationResult = FlowValidationResult.new()
	if graph == null:
		_add_error(result, FlowDiagnostic.CODE_NULL_GRAPH, "FlowGraph is null.", "graph")
		return result

	var seen_instances: Dictionary[int, String] = {}
	var seen_ids: Dictionary[String, String] = {}
	var owner_container_ids: Dictionary[String, bool] = {}
	var global_variable_ids: Dictionary[String, bool] = {}
	var variables_to_validate: Array[FlowVariableDefinition] = []
	var variable_indices: Array[int] = []
	_validate_resource_identity(graph, "graph", result, seen_instances, seen_ids)

	if graph.schema_version != FlowGraph.CURRENT_SCHEMA_VERSION \
			and graph.schema_version != FlowGraph.SCHEMA_VERSION_2:
		_add_error(
			result,
			FlowDiagnostic.CODE_UNSUPPORTED_SCHEMA_VERSION,
			"Unsupported FlowGraph schema version: %d." % graph.schema_version,
			"graph"
		)

	_validate_schema_sources(graph, result)

	_validate_legacy_containers(
		graph.containers,
		result,
		seen_instances,
		seen_ids,
		owner_container_ids
	)
	_validate_processes(
		graph.processes,
		result,
		seen_instances,
		seen_ids,
		owner_container_ids
	)
	_validate_variables(
		graph.variables,
		result,
		seen_instances,
		seen_ids,
		global_variable_ids,
		variables_to_validate,
		variable_indices
	)
	_validate_state_machines(
		graph.state_machines,
		result,
		seen_instances,
		seen_ids,
		owner_container_ids
	)
	_validate_variable_references(
		variables_to_validate,
		variable_indices,
		owner_container_ids,
		global_variable_ids,
		seen_ids,
		result
	)

	return result


static func _has_schema_2_entries(graph: FlowGraph) -> bool:
	return not graph.processes.is_empty() \
		or not graph.variables.is_empty() \
		or not graph.state_machines.is_empty()


static func _validate_schema_sources(graph: FlowGraph, result: FlowValidationResult) -> void:
	if graph.schema_version == FlowGraph.CURRENT_SCHEMA_VERSION and _has_schema_2_entries(graph):
		_add_error(
			result,
			FlowDiagnostic.CODE_MIXED_SCHEMA_SOURCES,
			"FlowGraph schema 1 cannot contain schema 2 collections.",
			"graph"
		)
	elif graph.schema_version == FlowGraph.SCHEMA_VERSION_2 and not graph.containers.is_empty():
		_add_error(
			result,
			FlowDiagnostic.CODE_MIXED_SCHEMA_SOURCES,
			"FlowGraph schema 2 cannot contain legacy containers.",
			"graph"
		)


static func _validate_legacy_containers(
		containers: Array[FlowBlockContainer],
		result: FlowValidationResult,
		seen_instances: Dictionary[int, String],
		seen_ids: Dictionary[String, String],
		owner_container_ids: Dictionary[String, bool]
) -> void:
	for container_index: int in containers.size():
		var container: FlowBlockContainer = containers[container_index]
		if container == null:
			continue

		var container_path: String = "containers[%d]" % container_index
		if not _validate_resource_identity(
				container,
				container_path,
				result,
				seen_instances,
				seen_ids
		):
			continue

		if container is FlowProcess or container is FlowStateDefinition:
			owner_container_ids[container.get_internal_id()] = true
		else:
			_add_error(
				result,
				FlowDiagnostic.CODE_UNMIGRATABLE_CONTAINER_TYPE,
				"Container type cannot be migrated to FlowGraph schema 2.",
				container_path,
				container.get_internal_id()
			)

		_validate_blocks(container, container_path, result, seen_instances, seen_ids)


static func _validate_processes(
		processes: Array[FlowProcess],
		result: FlowValidationResult,
		seen_instances: Dictionary[int, String],
		seen_ids: Dictionary[String, String],
		owner_container_ids: Dictionary[String, bool]
) -> void:
	for process_index: int in processes.size():
		var process: FlowProcess = processes[process_index]
		if process == null:
			continue

		var process_path: String = "processes[%d]" % process_index
		if not _validate_resource_identity(
				process,
				process_path,
				result,
				seen_instances,
				seen_ids
		):
			continue

		owner_container_ids[process.get_internal_id()] = true
		_validate_blocks(process, process_path, result, seen_instances, seen_ids)


static func _validate_variables(
		variables: Array[FlowVariableDefinition],
		result: FlowValidationResult,
		seen_instances: Dictionary[int, String],
		seen_ids: Dictionary[String, String],
		global_variable_ids: Dictionary[String, bool],
		variables_to_validate: Array[FlowVariableDefinition],
		variable_indices: Array[int]
) -> void:
	for variable_index: int in variables.size():
		var variable: FlowVariableDefinition = variables[variable_index]
		if variable == null:
			continue

		var variable_path: String = "variables[%d]" % variable_index
		if not _validate_resource_identity(
				variable,
				variable_path,
				result,
				seen_instances,
				seen_ids
		):
			continue

		variables_to_validate.append(variable)
		variable_indices.append(variable_index)
		if variable.scope == FlowVariableDefinition.Scope.GLOBAL:
			global_variable_ids[variable.get_internal_id()] = true


static func _validate_state_machines(
		state_machines: Array[FlowStateMachineDefinition],
		result: FlowValidationResult,
		seen_instances: Dictionary[int, String],
		seen_ids: Dictionary[String, String],
		owner_container_ids: Dictionary[String, bool]
) -> void:
	for machine_index: int in state_machines.size():
		var state_machine: FlowStateMachineDefinition = state_machines[machine_index]
		if state_machine == null:
			continue

		var machine_path: String = "state_machines[%d]" % machine_index
		if not _validate_resource_identity(
				state_machine,
				machine_path,
				result,
				seen_instances,
				seen_ids
		):
			continue

		for state_index: int in state_machine.states.size():
			var state: FlowStateDefinition = state_machine.states[state_index]
			if state == null:
				continue

			var state_path: String = "%s.states[%d]" % [machine_path, state_index]
			if not _validate_resource_identity(
					state,
					state_path,
					result,
					seen_instances,
					seen_ids
			):
				continue

			owner_container_ids[state.get_internal_id()] = true
			_validate_blocks(state, state_path, result, seen_instances, seen_ids)

		_validate_initial_state_reference(state_machine, machine_path, result)


static func _validate_initial_state_reference(
		state_machine: FlowStateMachineDefinition,
		machine_path: String,
		result: FlowValidationResult
) -> void:
	var state_ids: Dictionary[String, bool] = {}
	for state: FlowStateDefinition in state_machine.states:
		if state != null:
			state_ids[state.get_internal_id()] = true

	var reference_path: String = "%s.initial_state_id" % machine_path
	if state_ids.is_empty():
		if not state_machine.initial_state_id.is_empty():
			_add_error(
				result,
				FlowDiagnostic.CODE_INVALID_INITIAL_STATE_REFERENCE,
				"State machine has no states for its initial state reference.",
				reference_path,
				state_machine.initial_state_id
			)
		return

	if state_machine.initial_state_id.is_empty():
		_add_error(
			result,
			FlowDiagnostic.CODE_MISSING_INITIAL_STATE_REFERENCE,
			"State machine with states requires an initial state reference.",
			reference_path,
			state_machine.get_internal_id()
		)
		return

	if not state_ids.has(state_machine.initial_state_id):
		_add_error(
			result,
			FlowDiagnostic.CODE_INVALID_INITIAL_STATE_REFERENCE,
			"Initial state reference must resolve to a state in the same state machine.",
			reference_path,
			state_machine.initial_state_id
		)


static func _validate_blocks(
		container: FlowBlockContainer,
		container_path: String,
		result: FlowValidationResult,
		seen_instances: Dictionary[int, String],
		seen_ids: Dictionary[String, String]
) -> void:
	for block_index: int in container.blocks.size():
		var block: FlowBlock = container.blocks[block_index]
		if block != null:
			_validate_resource_identity(
				block,
				"%s.blocks[%d]" % [container_path, block_index],
				result,
				seen_instances,
				seen_ids
			)


static func _validate_variable_references(
		variables: Array[FlowVariableDefinition],
		variable_indices: Array[int],
		owner_container_ids: Dictionary[String, bool],
		global_variable_ids: Dictionary[String, bool],
		seen_ids: Dictionary[String, String],
		result: FlowValidationResult
) -> void:
	for variable_array_index: int in variables.size():
		var variable: FlowVariableDefinition = variables[variable_array_index]
		var variable_index: int = variable_indices[variable_array_index]
		var variable_path: String = "variables[%d]" % variable_index
		_validate_reference(
			variable.owner_container_id,
			owner_container_ids,
			seen_ids,
			result,
			"%s.owner_container_id" % variable_path,
			FlowDiagnostic.CODE_MISSING_OWNER_CONTAINER_REFERENCE,
			FlowDiagnostic.CODE_INVALID_OWNER_CONTAINER_REFERENCE,
			"owner container"
		)
		_validate_reference(
			variable.global_variable_id,
			global_variable_ids,
			seen_ids,
			result,
			"%s.global_variable_id" % variable_path,
			FlowDiagnostic.CODE_MISSING_GLOBAL_VARIABLE_REFERENCE,
			FlowDiagnostic.CODE_INVALID_GLOBAL_VARIABLE_REFERENCE,
			"global variable"
		)


static func _validate_reference(
		reference_id: String,
		valid_target_ids: Dictionary[String, bool],
		seen_ids: Dictionary[String, String],
		result: FlowValidationResult,
		element_path: String,
		missing_code: StringName,
		invalid_code: StringName,
		target_name: String
) -> void:
	if reference_id.is_empty() or valid_target_ids.has(reference_id):
		return

	var code: StringName = missing_code
	var message: String = "Referenced %s is missing from this FlowGraph." % target_name
	if seen_ids.has(reference_id):
		code = invalid_code
		message = "Referenced %s has an invalid type or scope." % target_name

	_add_error(result, code, message, element_path, reference_id)


static func _validate_resource_identity(
		resource: Resource,
		element_path: String,
		result: FlowValidationResult,
		seen_instances: Dictionary[int, String],
		seen_ids: Dictionary[String, String]
) -> bool:
	var instance_id: int = resource.get_instance_id()
	if seen_instances.has(instance_id):
		_add_error(
			result,
			FlowDiagnostic.CODE_REPEATED_RESOURCE_INSTANCE,
			"Resource instance is already used at %s." % seen_instances[instance_id],
			element_path,
			_get_internal_id(resource)
		)
		return false

	seen_instances[instance_id] = element_path
	var internal_id: String = _get_internal_id(resource)
	_validate_internal_id(internal_id, element_path, result)

	if not internal_id.is_empty():
		if seen_ids.has(internal_id):
			_add_error(
				result,
				FlowDiagnostic.CODE_DUPLICATE_INTERNAL_ID,
				"Internal ID is already used at %s." % seen_ids[internal_id],
				element_path,
				internal_id
			)
		else:
			seen_ids[internal_id] = element_path

	return true


static func _validate_internal_id(
		internal_id: String,
		element_path: String,
		result: FlowValidationResult
) -> void:
	if internal_id.is_empty():
		_add_error(result, FlowDiagnostic.CODE_EMPTY_INTERNAL_ID, "Internal ID is empty.", element_path)
		return

	if internal_id.length() != 32:
		_add_error(
			result,
			FlowDiagnostic.CODE_INVALID_INTERNAL_ID_LENGTH,
			"Internal ID must contain exactly 32 characters.",
			element_path,
			internal_id
		)

	for character_index: int in internal_id.length():
		if "0123456789abcdef".find(internal_id.substr(character_index, 1).to_lower()) == -1:
			_add_error(
				result,
				FlowDiagnostic.CODE_NON_HEXADECIMAL_INTERNAL_ID,
				"Internal ID must contain only hexadecimal characters.",
				element_path,
				internal_id
			)
			break


static func _get_internal_id(resource: Resource) -> String:
	if resource is FlowGraph:
		return (resource as FlowGraph).get_internal_id()
	if resource is FlowBlockContainer:
		return (resource as FlowBlockContainer).get_internal_id()
	if resource is FlowBlock:
		return (resource as FlowBlock).get_internal_id()
	if resource is FlowVariableDefinition:
		return (resource as FlowVariableDefinition).get_internal_id()
	if resource is FlowStateMachineDefinition:
		return (resource as FlowStateMachineDefinition).get_internal_id()
	return ""


static func _add_error(
		result: FlowValidationResult,
		code: StringName,
		message: String,
		element_path: String,
		related_id: String = ""
) -> void:
	result.add_diagnostic(FlowDiagnostic.new(
		code,
		FlowDiagnostic.Severity.ERROR,
		message,
		element_path,
		related_id
	))
