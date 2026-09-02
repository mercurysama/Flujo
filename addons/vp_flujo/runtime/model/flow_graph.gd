@tool
class_name FlowGraph
extends Resource

const CURRENT_SCHEMA_VERSION: int = 1
const SCHEMA_VERSION_2: int = 2
const SCHEMA_VERSION_3: int = 3

@export_storage var _internal_id: String = FlowId.create()
@export_storage var schema_version: int = CURRENT_SCHEMA_VERSION
@export var containers: Array[FlowBlockContainer] = []
@export var processes: Array[FlowProcess] = []
@export var variables: Array[FlowVariableDefinition] = []
@export var state_machines: Array[FlowStateMachineDefinition] = []
@export var constructor: FlowConstructorDefinition
@export var methods: Array[FlowMethodDefinition] = []

func get_internal_id() -> String:
	return _internal_id

## Duplicates a graph that has already passed FlowGraphValidator validation.
func duplicate_with_new_ids() -> FlowGraph:
	var copy: FlowGraph = FlowGraph.new()
	var id_map: Dictionary[String, String] = {}
	copy._internal_id = FlowId.create()
	id_map[_internal_id] = copy._internal_id
	copy.schema_version = schema_version

	if schema_version == CURRENT_SCHEMA_VERSION:
		for container: FlowBlockContainer in containers:
			if container == null:
				copy.containers.append(null)
			else:
				copy.containers.append(_duplicate_legacy_container(container, id_map))
	elif schema_version == SCHEMA_VERSION_2 or schema_version == SCHEMA_VERSION_3:
		for process: FlowProcess in processes:
			if process == null:
				copy.processes.append(null)
			else:
				copy.processes.append(_duplicate_process(process, id_map))

		for variable: FlowVariableDefinition in variables:
			if variable == null:
				copy.variables.append(null)
			else:
				copy.variables.append(_duplicate_variable(variable, id_map))

		for state_machine: FlowStateMachineDefinition in state_machines:
			if state_machine == null:
				copy.state_machines.append(null)
			else:
				copy.state_machines.append(_duplicate_state_machine(state_machine, id_map))

		_remap_variable_references(copy.variables, id_map)

		if schema_version == SCHEMA_VERSION_3:
			copy.constructor = _duplicate_constructor(constructor, id_map)
			for method: FlowMethodDefinition in methods:
				if method == null:
					copy.methods.append(null)
				else:
					copy.methods.append(_duplicate_method(method, id_map))
		_remap_state_machine_references(copy.state_machines, id_map)

	return copy


func _duplicate_legacy_container(
		container: FlowBlockContainer,
		id_map: Dictionary[String, String]
) -> FlowBlockContainer:
	if container is FlowProcess:
		return _duplicate_process(container as FlowProcess, id_map)
	if container is FlowStateDefinition:
		return _duplicate_state(container as FlowStateDefinition, id_map)

	var copy: FlowBlockContainer = container.duplicate_with_new_ids()
	id_map[container.get_internal_id()] = copy.get_internal_id()
	return copy


func _duplicate_process(
		process: FlowProcess,
		id_map: Dictionary[String, String]
) -> FlowProcess:
	var copy: FlowProcess = process.duplicate(false) as FlowProcess
	copy._internal_id = FlowId.create()
	id_map[process.get_internal_id()] = copy.get_internal_id()
	_duplicate_blocks(process, copy, id_map)
	return copy


func _duplicate_state(
		state: FlowStateDefinition,
		id_map: Dictionary[String, String]
) -> FlowStateDefinition:
	var copy: FlowStateDefinition = state.duplicate(false) as FlowStateDefinition
	copy._internal_id = FlowId.create()
	id_map[state.get_internal_id()] = copy.get_internal_id()
	_duplicate_blocks(state, copy, id_map)
	return copy


func _duplicate_blocks(
		source: FlowBlockContainer,
		target: FlowBlockContainer,
		id_map: Dictionary[String, String]
) -> void:
	target.blocks = []
	for block: FlowBlock in source.blocks:
		if block == null:
			target.blocks.append(null)
			continue

		var block_copy: FlowBlock = block.duplicate(false) as FlowBlock
		block_copy._internal_id = FlowId.create()
		id_map[block.get_internal_id()] = block_copy.get_internal_id()
		target.blocks.append(block_copy)


func _duplicate_variable(
		variable: FlowVariableDefinition,
		id_map: Dictionary[String, String]
) -> FlowVariableDefinition:
	var copy: FlowVariableDefinition = variable.duplicate(false) as FlowVariableDefinition
	copy._internal_id = FlowId.create()
	id_map[variable.get_internal_id()] = copy.get_internal_id()
	return copy


func _duplicate_state_machine(
		state_machine: FlowStateMachineDefinition,
		id_map: Dictionary[String, String]
) -> FlowStateMachineDefinition:
	var copy: FlowStateMachineDefinition = state_machine.duplicate(false) as FlowStateMachineDefinition
	copy._internal_id = FlowId.create()
	id_map[state_machine.get_internal_id()] = copy.get_internal_id()
	copy.states = []

	for state: FlowStateDefinition in state_machine.states:
		if state == null:
			copy.states.append(null)
		else:
			copy.states.append(_duplicate_state(state, id_map))

	return copy


func _duplicate_constructor(
		constructor_definition: FlowConstructorDefinition,
		id_map: Dictionary[String, String]
) -> FlowConstructorDefinition:
	var copy: FlowConstructorDefinition = constructor_definition.duplicate(false) as FlowConstructorDefinition
	copy._internal_id = FlowId.create()
	id_map[constructor_definition.get_internal_id()] = copy.get_internal_id()
	copy.dependencies = []
	for dependency: FlowDependencyDefinition in constructor_definition.dependencies:
		if dependency == null:
			copy.dependencies.append(null)
			continue
		var dependency_copy: FlowDependencyDefinition = dependency.duplicate(false) as FlowDependencyDefinition
		dependency_copy._internal_id = FlowId.create()
		id_map[dependency.get_internal_id()] = dependency_copy.get_internal_id()
		copy.dependencies.append(dependency_copy)
	return copy


func _duplicate_method(
		method: FlowMethodDefinition,
		id_map: Dictionary[String, String]
) -> FlowMethodDefinition:
	var copy: FlowMethodDefinition = method.duplicate(false) as FlowMethodDefinition
	copy._internal_id = FlowId.create()
	id_map[method.get_internal_id()] = copy.get_internal_id()
	_duplicate_blocks(method, copy, id_map)
	copy.parameters = []
	for parameter: FlowMethodParameterDefinition in method.parameters:
		if parameter == null:
			copy.parameters.append(null)
			continue
		var parameter_copy: FlowMethodParameterDefinition = parameter.duplicate(false) as FlowMethodParameterDefinition
		parameter_copy._internal_id = FlowId.create()
		id_map[parameter.get_internal_id()] = parameter_copy.get_internal_id()
		copy.parameters.append(parameter_copy)
	return copy
func _remap_variable_references(
		copy_variables: Array[FlowVariableDefinition],
		id_map: Dictionary[String, String]
) -> void:
	for variable: FlowVariableDefinition in copy_variables:
		if variable == null:
			continue

		variable.owner_container_id = _remap_reference(variable.owner_container_id, id_map)
		variable.global_variable_id = _remap_reference(variable.global_variable_id, id_map)


func _remap_state_machine_references(
		copy_state_machines: Array[FlowStateMachineDefinition],
		id_map: Dictionary[String, String]
) -> void:
	for state_machine: FlowStateMachineDefinition in copy_state_machines:
		if state_machine != null:
			state_machine.initial_state_id = _remap_reference(state_machine.initial_state_id, id_map)


func _remap_reference(
		original_id: String,
		id_map: Dictionary[String, String]
) -> String:
	if id_map.has(original_id):
		return id_map[original_id]
	return original_id
