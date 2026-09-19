@tool
## Migrates validated FlowGraph schema 1 data into an independent schema 2 graph.
class_name FlowGraphMigrator
extends RefCounted


## Migrates a schema 1 graph without modifying the source graph or its resources.
static func migrate_schema_1_to_2(source: FlowGraph) -> FlowGraphMigrationResult:
	var result: FlowGraphMigrationResult = FlowGraphMigrationResult.new()
	var source_validation: FlowValidationResult = FlowGraphValidator.validate(source)
	result.add_validation_result(source_validation)
	if source_validation.has_errors() or source == null:
		return result

	if source.schema_version != FlowGraph.CURRENT_SCHEMA_VERSION:
		_add_error(
			result,
			FlowDiagnostic.CODE_MIGRATION_SOURCE_SCHEMA,
			"FlowGraph migration requires schema version 1.",
			"graph"
		)
		return result

	var candidate: FlowGraph = FlowGraph.new()
	candidate._internal_id = source.get_internal_id()
	candidate.schema_version = FlowGraph.SCHEMA_VERSION_2
	var migrated_states: Array[FlowStateDefinition] = []
	var initial_state_count: int = 0
	var first_state_id: String = ""
	var marked_initial_state_id: String = ""

	for container: FlowBlockContainer in source.containers:
		if container is FlowProcess:
			candidate.processes.append(_copy_process(container as FlowProcess))
		else:
			candidate.processes.append(null)

		if container is FlowStateDefinition:
			var state_copy: FlowStateDefinition = _copy_state(container as FlowStateDefinition)
			migrated_states.append(state_copy)
			if first_state_id.is_empty():
				first_state_id = state_copy.get_internal_id()
			if state_copy.is_initial:
				initial_state_count += 1
				marked_initial_state_id = state_copy.get_internal_id()
		else:
			migrated_states.append(null)

	if initial_state_count > 1:
		_add_error(
			result,
			FlowDiagnostic.CODE_MULTIPLE_INITIAL_STATES,
			"Schema 1 graph contains multiple initial states.",
			"containers"
		)
		return result

	if not first_state_id.is_empty():
		var state_machine: FlowStateMachineDefinition = FlowStateMachineDefinition.new()
		state_machine.display_name = "Migrated States"
		state_machine.states = migrated_states
		if initial_state_count == 1:
			state_machine.initial_state_id = marked_initial_state_id
		else:
			state_machine.initial_state_id = first_state_id
		candidate.state_machines.append(state_machine)

	var candidate_validation: FlowValidationResult = FlowGraphValidator.validate(candidate)
	result.add_validation_result(candidate_validation)
	if candidate_validation.has_errors():
		return result

	result.migrated_graph = candidate
	return result


## Migrates a schema 2 graph without modifying the source graph or its resources.
static func migrate_schema_2_to_3(source: FlowGraph) -> FlowGraphMigrationResult:
	var result: FlowGraphMigrationResult = FlowGraphMigrationResult.new()
	var source_validation: FlowValidationResult = FlowGraphValidator.validate(source)
	result.add_validation_result(source_validation)
	if source_validation.has_errors() or source == null:
		return result

	if source.schema_version != FlowGraph.SCHEMA_VERSION_2:
		_add_error(
			result,
			FlowDiagnostic.CODE_MIGRATION_SOURCE_SCHEMA,
			"FlowGraph migration requires schema version 2.",
			"graph"
		)
		return result

	var candidate: FlowGraph = FlowGraph.new()
	candidate._internal_id = source.get_internal_id()
	candidate.schema_version = FlowGraph.SCHEMA_VERSION_3
	candidate.containers = []
	for process: FlowProcess in source.processes:
		candidate.processes.append(null if process == null else _copy_process(process))
	for variable: FlowVariableDefinition in source.variables:
		candidate.variables.append(null if variable == null else _copy_variable(variable))
	for state_machine: FlowStateMachineDefinition in source.state_machines:
		candidate.state_machines.append(
			null if state_machine == null else _copy_state_machine(state_machine)
		)
	candidate.constructor = FlowConstructorDefinition.new()
	candidate.methods = []

	var candidate_validation: FlowValidationResult = FlowGraphValidator.validate(candidate)
	result.add_validation_result(candidate_validation)
	if candidate_validation.has_errors():
		return result

	result.migrated_graph = candidate
	return result


## Preserves all schema 3 data; explicit consent makes legacy constructor payload inert.
static func migrate_schema_3_to_4(
		source: FlowGraph,
		confirm_legacy_payload: bool = false
) -> FlowGraphMigrationResult:
	var result: FlowGraphMigrationResult = FlowGraphMigrationResult.new()
	var source_validation: FlowValidationResult = FlowGraphValidator.validate(source)
	result.add_validation_result(source_validation)
	if source_validation.has_errors() or source == null:
		return result
	if source.schema_version != FlowGraph.SCHEMA_VERSION_3:
		_add_error(result, FlowDiagnostic.CODE_MIGRATION_SOURCE_SCHEMA, "FlowGraph migration requires schema version 3.", "graph")
		return result
	if not confirm_legacy_payload and (not source.constructor.blocks.is_empty() \
			or not source.constructor.dependencies.is_empty()):
		_add_error(result, FlowDiagnostic.CODE_MIGRATION_CONFIRMATION_REQUIRED,
			"Confirm preservation of constructor blocks and dependencies as inert legacy data.",
			"constructor", source.constructor.get_internal_id())
		return result
	# Include externally stored subresources as well as embedded ones; IDs are not renewed.
	var candidate: FlowGraph = source.duplicate_deep(Resource.DEEP_DUPLICATE_ALL) as FlowGraph
	candidate.schema_version = FlowGraph.SCHEMA_VERSION_4
	candidate.constructor.requirements = []
	var candidate_validation: FlowValidationResult = FlowGraphValidator.validate(candidate)
	result.add_validation_result(candidate_validation)
	if not candidate_validation.has_errors():
		result.migrated_graph = candidate
	return result


## Publishes only the final candidate after both existing and new migration steps succeed.
static func migrate_schema_2_to_4(source: FlowGraph) -> FlowGraphMigrationResult:
	var first: FlowGraphMigrationResult = migrate_schema_2_to_3(source)
	if not first.is_successful():
		return first
	var second: FlowGraphMigrationResult = migrate_schema_3_to_4(first.migrated_graph)
	var result: FlowGraphMigrationResult = FlowGraphMigrationResult.new()
	result.diagnostics.append_array(first.diagnostics)
	result.diagnostics.append_array(second.diagnostics)
	if second.is_successful():
		result.migrated_graph = second.migrated_graph
	return result


## Schema 5 is persistent only. Legacy definitions and scene bindings are not executed.
static func migrate_schema_4_to_5(source: FlowGraph) -> FlowGraphMigrationResult:
	var result: FlowGraphMigrationResult = FlowGraphMigrationResult.new()
	var validation: FlowValidationResult = FlowGraphValidator.validate(source)
	result.add_validation_result(validation)
	if source == null or validation.has_errors():
		return result
	if source.schema_version != FlowGraph.SCHEMA_VERSION_4:
		_add_error(result, FlowDiagnostic.CODE_MIGRATION_SOURCE_SCHEMA, "FlowGraph migration requires schema version 4.", "graph")
		return result
	var candidate: FlowGraph = source.duplicate_deep(Resource.DEEP_DUPLICATE_ALL) as FlowGraph
	candidate.schema_version = FlowGraph.SCHEMA_VERSION_5
	candidate.base_class_id = ""
	candidate.class_attributes = []
	candidate.constructor.attributes = []
	for method: FlowMethodDefinition in candidate.methods:
		if method == null:
			continue
		method.outputs = []
		if method.return_definition != null:
			var output: FlowMethodOutputDefinition = FlowMethodOutputDefinition.new()
			output._internal_id = method.return_definition.get_internal_id()
			output.display_name = method.return_definition.display_name
			output.value_type = method.return_definition.value_type
			method.outputs.append(output)
		method.return_definition = null
	for record: Dictionary in FlowSchema5Model.owned_records(candidate):
		if record.resource is FlowMethodCallBlock:
			var call: FlowMethodCallBlock = record.resource
			var reference: FlowMethodReferenceDefinition = FlowMethodReferenceDefinition.new()
			reference.target_class_id = candidate.get_internal_id()
			reference.target_id = call.method_id
			call.method_reference = reference
			call.method_id = ""
	var candidate_validation: FlowValidationResult = FlowGraphValidator.validate(candidate)
	result.add_validation_result(candidate_validation)
	if not candidate_validation.has_errors():
		result.migrated_graph = candidate
	return result


static func migrate_schema_3_to_5(source: FlowGraph, confirm_legacy_payload: bool = false) -> FlowGraphMigrationResult:
	var first: FlowGraphMigrationResult = migrate_schema_3_to_4(source, confirm_legacy_payload)
	if not first.is_successful():
		return first
	var last: FlowGraphMigrationResult = migrate_schema_4_to_5(first.migrated_graph)
	last.diagnostics = first.diagnostics + last.diagnostics
	return last


static func migrate_schema_2_to_5(source: FlowGraph, confirm_legacy_payload: bool = false) -> FlowGraphMigrationResult:
	var first: FlowGraphMigrationResult = migrate_schema_2_to_3(source)
	if not first.is_successful():
		return first
	var last: FlowGraphMigrationResult = migrate_schema_3_to_5(first.migrated_graph, confirm_legacy_payload)
	last.diagnostics = first.diagnostics + last.diagnostics
	return last


static func _copy_process(source: FlowProcess) -> FlowProcess:
	var copy: FlowProcess = source.duplicate(false) as FlowProcess
	copy._internal_id = source.get_internal_id()
	_copy_blocks(source, copy)
	return copy


static func _copy_state(source: FlowStateDefinition) -> FlowStateDefinition:
	var copy: FlowStateDefinition = source.duplicate(false) as FlowStateDefinition
	copy._internal_id = source.get_internal_id()
	_copy_blocks(source, copy)
	return copy


static func _copy_blocks(source: FlowBlockContainer, target: FlowBlockContainer) -> void:
	target.blocks = []
	for block: FlowBlock in source.blocks:
		if block == null:
			target.blocks.append(null)
		else:
			target.blocks.append(_copy_block(block))


static func _copy_block(source: FlowBlock) -> FlowBlock:
	var copy: FlowBlock = source.duplicate(false) as FlowBlock
	copy._internal_id = source.get_internal_id()
	return copy


static func _copy_variable(source: FlowVariableDefinition) -> FlowVariableDefinition:
	var copy: FlowVariableDefinition = source.duplicate(false) as FlowVariableDefinition
	copy._internal_id = source.get_internal_id()
	return copy


static func _copy_state_machine(
		source: FlowStateMachineDefinition
) -> FlowStateMachineDefinition:
	var copy: FlowStateMachineDefinition = source.duplicate(false) as FlowStateMachineDefinition
	copy._internal_id = source.get_internal_id()
	copy.states = []
	for state: FlowStateDefinition in source.states:
		copy.states.append(null if state == null else _copy_state(state))
	return copy


static func _add_error(
		result: FlowGraphMigrationResult,
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
