extends Node


func _has_diagnostic(result: FlowValidationResult, code: StringName) -> bool:
	for diagnostic: FlowDiagnostic in result.diagnostics:
		if diagnostic.code == code:
			return true

	return false


func _has_migration_diagnostic(result: FlowGraphMigrationResult, code: StringName) -> bool:
	for diagnostic: FlowDiagnostic in result.diagnostics:
		if diagnostic.code == code:
			return true

	return false


func _find_diagnostic(
		result: FlowValidationResult,
		code: StringName,
		element_path: String
) -> FlowDiagnostic:
	for diagnostic: FlowDiagnostic in result.diagnostics:
		if diagnostic.code == code and diagnostic.element_path == element_path:
			return diagnostic

	return null


func _assert_same_diagnostic_sequence(
		first_result: FlowValidationResult,
		second_result: FlowValidationResult
) -> void:
	assert(first_result.diagnostics.size() == second_result.diagnostics.size())
	for diagnostic_index: int in first_result.diagnostics.size():
		var first: FlowDiagnostic = first_result.diagnostics[diagnostic_index]
		var second: FlowDiagnostic = second_result.diagnostics[diagnostic_index]
		assert(first.code == second.code)
		assert(first.element_path == second.element_path)
		assert(first.related_id == second.related_id)


func _ready() -> void:
	await get_tree().process_frame

	var null_graph_result: FlowValidationResult = FlowGraphValidator.validate(null)
	assert(null_graph_result.has_errors())
	assert(_has_diagnostic(null_graph_result, FlowDiagnostic.CODE_NULL_GRAPH))

	var valid_graph: FlowGraph = FlowGraph.new()
	var valid_process: FlowProcess = FlowProcess.new()
	var valid_block: FlowBlock = FlowBlock.new()
	var valid_state: FlowStateDefinition = FlowStateDefinition.new()
	valid_process.blocks.append(valid_block)
	valid_process.blocks.append(null)
	valid_graph.containers.append(valid_process)
	valid_graph.containers.append(null)
	valid_graph.containers.append(valid_state)

	var valid_graph_id: String = valid_graph.get_internal_id()
	var valid_process_id: String = valid_process.get_internal_id()
	var valid_block_id: String = valid_block.get_internal_id()
	var valid_state_id: String = valid_state.get_internal_id()
	var valid_result: FlowValidationResult = FlowGraphValidator.validate(valid_graph)
	assert(not valid_result.has_errors())
	assert(valid_result.diagnostics.is_empty())
	assert(valid_graph.schema_version == FlowGraph.CURRENT_SCHEMA_VERSION)
	assert(valid_graph.get_internal_id() == valid_graph_id)
	assert(valid_graph.containers.size() == 3)
	assert(valid_graph.containers[0] == valid_process)
	assert(valid_graph.containers[1] == null)
	assert(valid_graph.containers[2] == valid_state)
	assert(valid_process.get_internal_id() == valid_process_id)
	assert(valid_process.blocks.size() == 2)
	assert(valid_process.blocks[0] == valid_block)
	assert(valid_process.blocks[1] == null)
	assert(valid_block.get_internal_id() == valid_block_id)
	assert(valid_state.get_internal_id() == valid_state_id)

	var unsupported_schema_graph: FlowGraph = FlowGraph.new()
	unsupported_schema_graph.schema_version = FlowGraph.SCHEMA_VERSION_2 + 1
	var unsupported_schema_result: FlowValidationResult = FlowGraphValidator.validate(
		unsupported_schema_graph
	)
	assert(unsupported_schema_result.has_errors())
	assert(_has_diagnostic(
		unsupported_schema_result,
		FlowDiagnostic.CODE_UNSUPPORTED_SCHEMA_VERSION
	))

	var empty_id_graph: FlowGraph = FlowGraph.new()
	empty_id_graph._internal_id = ""
	var empty_id_result: FlowValidationResult = FlowGraphValidator.validate(empty_id_graph)
	assert(_has_diagnostic(empty_id_result, FlowDiagnostic.CODE_EMPTY_INTERNAL_ID))

	var short_id_graph: FlowGraph = FlowGraph.new()
	short_id_graph._internal_id = "1234"
	var short_id_result: FlowValidationResult = FlowGraphValidator.validate(short_id_graph)
	assert(_has_diagnostic(short_id_result, FlowDiagnostic.CODE_INVALID_INTERNAL_ID_LENGTH))

	var non_hex_id_graph: FlowGraph = FlowGraph.new()
	non_hex_id_graph._internal_id = "zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz"
	var non_hex_id_result: FlowValidationResult = FlowGraphValidator.validate(non_hex_id_graph)
	assert(_has_diagnostic(non_hex_id_result, FlowDiagnostic.CODE_NON_HEXADECIMAL_INTERNAL_ID))

	var duplicate_id_graph: FlowGraph = FlowGraph.new()
	var duplicate_id_process: FlowProcess = FlowProcess.new()
	duplicate_id_process._internal_id = duplicate_id_graph.get_internal_id()
	duplicate_id_graph.containers.append(duplicate_id_process)
	var duplicate_id_result: FlowValidationResult = FlowGraphValidator.validate(duplicate_id_graph)
	assert(_has_diagnostic(duplicate_id_result, FlowDiagnostic.CODE_DUPLICATE_INTERNAL_ID))
	var duplicate_id_diagnostic: FlowDiagnostic = _find_diagnostic(
		duplicate_id_result,
		FlowDiagnostic.CODE_DUPLICATE_INTERNAL_ID,
		"containers[0]"
	)
	assert(duplicate_id_diagnostic != null)
	assert(duplicate_id_diagnostic.severity == FlowDiagnostic.Severity.ERROR)
	assert(not duplicate_id_diagnostic.message.is_empty())
	assert(duplicate_id_diagnostic.element_path == "containers[0]")
	assert(duplicate_id_diagnostic.related_id == duplicate_id_graph.get_internal_id())

	var duplicate_block_id_graph: FlowGraph = FlowGraph.new()
	var duplicate_block_id_process: FlowProcess = FlowProcess.new()
	var duplicate_id_block: FlowBlock = FlowBlock.new()
	duplicate_id_block._internal_id = duplicate_block_id_process.get_internal_id()
	duplicate_block_id_process.blocks.append(duplicate_id_block)
	duplicate_block_id_graph.containers.append(duplicate_block_id_process)
	var duplicate_block_id_result: FlowValidationResult = FlowGraphValidator.validate(
		duplicate_block_id_graph
	)
	assert(_has_diagnostic(
		duplicate_block_id_result,
		FlowDiagnostic.CODE_DUPLICATE_INTERNAL_ID
	))

	var repeated_instance_graph: FlowGraph = FlowGraph.new()
	var repeated_process: FlowProcess = FlowProcess.new()
	repeated_instance_graph.containers.append(repeated_process)
	repeated_instance_graph.containers.append(repeated_process)
	var repeated_instance_result: FlowValidationResult = FlowGraphValidator.validate(
		repeated_instance_graph
	)
	assert(_has_diagnostic(
		repeated_instance_result,
		FlowDiagnostic.CODE_REPEATED_RESOURCE_INSTANCE
	))

	var repeated_block_graph: FlowGraph = FlowGraph.new()
	var repeated_block_process: FlowProcess = FlowProcess.new()
	var repeated_block: FlowBlock = FlowBlock.new()
	repeated_block_process.blocks.append(repeated_block)
	repeated_block_process.blocks.append(null)
	repeated_block_process.blocks.append(repeated_block)
	repeated_block_graph.containers.append(repeated_block_process)
	var repeated_block_graph_id: String = repeated_block_graph.get_internal_id()
	var repeated_block_process_id: String = repeated_block_process.get_internal_id()
	var repeated_block_id: String = repeated_block.get_internal_id()
	var first_repeated_block_result: FlowValidationResult = FlowGraphValidator.validate(
		repeated_block_graph
	)
	var second_repeated_block_result: FlowValidationResult = FlowGraphValidator.validate(
		repeated_block_graph
	)
	_assert_same_diagnostic_sequence(
		first_repeated_block_result,
		second_repeated_block_result
	)
	var repeated_block_diagnostic: FlowDiagnostic = _find_diagnostic(
		first_repeated_block_result,
		FlowDiagnostic.CODE_REPEATED_RESOURCE_INSTANCE,
		"containers[0].blocks[2]"
	)
	assert(repeated_block_diagnostic != null)
	assert(repeated_block_diagnostic.severity == FlowDiagnostic.Severity.ERROR)
	assert(not repeated_block_diagnostic.message.is_empty())
	assert(repeated_block_diagnostic.element_path == "containers[0].blocks[2]")
	assert(repeated_block_diagnostic.related_id == repeated_block_id)
	assert(repeated_block_graph.get_internal_id() == repeated_block_graph_id)
	assert(repeated_block_graph.containers.size() == 1)
	assert(repeated_block_graph.containers[0] == repeated_block_process)
	assert(repeated_block_process.get_internal_id() == repeated_block_process_id)
	assert(repeated_block_process.blocks.size() == 3)
	assert(repeated_block_process.blocks[0] == repeated_block)
	assert(repeated_block_process.blocks[1] == null)
	assert(repeated_block_process.blocks[2] == repeated_block)
	assert(repeated_block.get_internal_id() == repeated_block_id)

	var unmigratable_graph: FlowGraph = FlowGraph.new()
	var unmigratable_container: FlowBlockContainer = FlowBlockContainer.new()
	unmigratable_graph.containers.append(unmigratable_container)
	var unmigratable_result: FlowValidationResult = FlowGraphValidator.validate(
		unmigratable_graph
	)
	assert(_has_diagnostic(
		unmigratable_result,
		FlowDiagnostic.CODE_UNMIGRATABLE_CONTAINER_TYPE
	))

	var original: FlowGraph = FlowGraph.new()

	var process: FlowProcess = FlowProcess.new()
	process.display_name = "Main Process"

	var block: FlowBlock = FlowBlock.new()
	block.display_name = "Print"
	process.blocks.append(block)

	var state: FlowStateDefinition = FlowStateDefinition.new()
	state.display_name = "Idle"
	state.is_initial = true

	original.containers.append(process)
	original.containers.append(null)
	original.containers.append(state)

	var copy: FlowGraph = original.duplicate_with_new_ids()

	assert(copy != original)
	assert(original.get_internal_id().length() == 32)
	assert(copy.get_internal_id().length() == 32)
	assert(process.get_internal_id().length() == 32)
	assert(block.get_internal_id().length() == 32)
	assert(state.get_internal_id().length() == 32)
	assert(copy.get_internal_id() != original.get_internal_id())
	assert(copy.containers.size() == 3)
	assert(copy.containers[0] is FlowProcess)
	assert(copy.containers[1] == null)
	assert(copy.containers[2] is FlowStateDefinition)

	var process_copy: FlowProcess = copy.containers[0] as FlowProcess
	var state_copy: FlowStateDefinition = copy.containers[2] as FlowStateDefinition

	assert(process_copy.get_internal_id().length() == 32)
	assert(state_copy.get_internal_id().length() == 32)
	assert(process_copy.get_internal_id() != process.get_internal_id())
	assert(state_copy.get_internal_id() != state.get_internal_id())
	assert(process_copy.display_name == "Main Process")
	assert(state_copy.display_name == "Idle")
	assert(state_copy.is_initial)
	assert(process_copy.blocks.size() == 1)
	assert(process_copy.blocks[0] != null)
	assert(process_copy.blocks[0].get_internal_id().length() == 32)
	assert(process_copy.blocks[0].get_internal_id() != block.get_internal_id())
	assert(process_copy.blocks[0].display_name == "Print")

	var first_controller: PVController = PVController.new()
	var second_controller: PVController = PVController.new()
	assert(first_controller.flow_graph != second_controller.flow_graph)
	first_controller.free()
	second_controller.free()

	var default_variable: FlowVariableDefinition = FlowVariableDefinition.new()
	assert(default_variable.get_internal_id().length() == 32)
	assert(default_variable.display_name == "Variable")
	assert(default_variable.scope == FlowVariableDefinition.Scope.LOCAL)
	assert(default_variable.binding == FlowVariableDefinition.Binding.OWN_VALUE)
	assert(default_variable.value_type == FlowVariableDefinition.ValueType.BOOL)
	assert(default_variable.bool_value == false)
	assert(default_variable.int_value == 0)
	assert(default_variable.float_value == 0.0)
	assert(default_variable.string_value == "")
	assert(default_variable.vector2_value == Vector2.ZERO)
	assert(default_variable.vector3_value == Vector3.ZERO)
	assert(default_variable.color_value == Color.WHITE)
	assert(default_variable.persistent == false)
	assert(default_variable.global_variable_id == "")
	assert(default_variable.owner_container_id == "")
	assert(default_variable.user_note == "")

	var global_variable: FlowVariableDefinition = FlowVariableDefinition.new()
	global_variable.display_name = "Player Position"
	global_variable.scope = FlowVariableDefinition.Scope.GLOBAL
	global_variable.binding = FlowVariableDefinition.Binding.OWN_VALUE
	global_variable.value_type = FlowVariableDefinition.ValueType.VECTOR3
	global_variable.vector3_value = Vector3(1.0, 2.0, 3.0)
	global_variable.persistent = true
	global_variable.user_note = "Tracks the player position."

	var global_variable_id: String = global_variable.get_internal_id()
	var global_variable_copy: FlowVariableDefinition = global_variable.duplicate_with_new_id()
	assert(global_variable_copy != global_variable)
	assert(global_variable_copy.get_internal_id().length() == 32)
	assert(global_variable_copy.get_internal_id() != global_variable_id)
	assert(global_variable.get_internal_id() == global_variable_id)
	assert(global_variable_copy.display_name == "Player Position")
	assert(global_variable_copy.scope == FlowVariableDefinition.Scope.GLOBAL)
	assert(global_variable_copy.binding == FlowVariableDefinition.Binding.OWN_VALUE)
	assert(global_variable_copy.value_type == FlowVariableDefinition.ValueType.VECTOR3)
	assert(global_variable_copy.vector3_value == Vector3(1.0, 2.0, 3.0))
	assert(global_variable_copy.persistent == true)
	assert(global_variable_copy.user_note == "Tracks the player position.")

	var global_reference: FlowVariableDefinition = FlowVariableDefinition.new()
	global_reference.scope = FlowVariableDefinition.Scope.LOCAL
	global_reference.binding = FlowVariableDefinition.Binding.GLOBAL_REFERENCE
	global_reference.value_type = FlowVariableDefinition.ValueType.VECTOR3
	global_reference.global_variable_id = global_variable_id
	global_reference.owner_container_id = process.get_internal_id()
	assert(global_reference.persistent == false)

	var global_reference_id: String = global_reference.get_internal_id()
	var global_reference_copy: FlowVariableDefinition = global_reference.duplicate_with_new_id()
	assert(global_reference_copy != global_reference)
	assert(global_reference_copy.get_internal_id().length() == 32)
	assert(global_reference_copy.get_internal_id() != global_reference_id)
	assert(global_reference_copy.global_variable_id == global_variable_id)
	assert(global_reference_copy.owner_container_id == process.get_internal_id())
	assert(global_reference_copy.scope == FlowVariableDefinition.Scope.LOCAL)
	assert(global_reference_copy.binding == FlowVariableDefinition.Binding.GLOBAL_REFERENCE)
	assert(global_reference_copy.value_type == FlowVariableDefinition.ValueType.VECTOR3)
	assert(global_reference_copy.persistent == false)
	assert(global_reference.get_internal_id() == global_reference_id)
	assert(global_reference.global_variable_id == global_variable_id)
	assert(global_reference.owner_container_id == process.get_internal_id())
	assert(global_reference.scope == FlowVariableDefinition.Scope.LOCAL)
	assert(global_reference.binding == FlowVariableDefinition.Binding.GLOBAL_REFERENCE)
	assert(global_reference.value_type == FlowVariableDefinition.ValueType.VECTOR3)
	assert(global_reference.persistent == false)

	var state_machine: FlowStateMachineDefinition = FlowStateMachineDefinition.new()
	var state_machine_id: String = state_machine.get_internal_id()
	assert(state_machine_id.length() == 32)
	assert(state_machine.display_name == "State Machine")
	assert(state_machine.enabled == true)
	assert(state_machine.user_note == "")
	assert(state_machine.states.is_empty())
	assert(state_machine.initial_state_id == "")
	assert(state_machine.get_initial_state() == null)

	state_machine.add_state(null)
	assert(state_machine.states.size() == 1)
	assert(state_machine.states[0] == null)
	assert(state_machine.initial_state_id == "")
	assert(state_machine.get_initial_state() == null)

	var idle_state: FlowStateDefinition = FlowStateDefinition.new()
	idle_state.display_name = "Idle"
	var idle_state_id: String = idle_state.get_internal_id()
	var idle_is_initial: bool = idle_state.is_initial
	state_machine.add_state(idle_state)
	assert(state_machine.states.size() == 2)
	assert(state_machine.states[1] == idle_state)
	assert(state_machine.initial_state_id == idle_state_id)
	assert(state_machine.get_initial_state() == idle_state)

	var run_state: FlowStateDefinition = FlowStateDefinition.new()
	run_state.display_name = "Run"
	var run_state_id: String = run_state.get_internal_id()
	var run_is_initial: bool = run_state.is_initial
	state_machine.add_state(run_state)
	assert(state_machine.states.size() == 3)
	assert(state_machine.states[2] == run_state)
	assert(state_machine.initial_state_id == idle_state_id)
	assert(state_machine.get_initial_state() == idle_state)

	assert(state_machine.set_initial_state_by_id("") == false)
	assert(state_machine.initial_state_id == idle_state_id)
	assert(state_machine.set_initial_state_by_id("missing_state") == false)
	assert(state_machine.initial_state_id == idle_state_id)
	assert(state_machine.set_initial_state_by_id(run_state_id) == true)
	assert(state_machine.initial_state_id == run_state_id)
	assert(state_machine.get_initial_state() == run_state)
	assert(idle_state.is_initial == idle_is_initial)
	assert(run_state.is_initial == run_is_initial)

	state_machine.display_name = "Movement"
	state_machine.enabled = false
	state_machine.user_note = "Controls movement states."

	var state_machine_copy: FlowStateMachineDefinition = state_machine.duplicate_with_new_ids()
	var idle_state_copy: FlowStateDefinition = state_machine_copy.states[1] as FlowStateDefinition
	var run_state_copy: FlowStateDefinition = state_machine_copy.states[2] as FlowStateDefinition
	assert(state_machine_copy != state_machine)
	assert(state_machine_copy.get_internal_id().length() == 32)
	assert(state_machine_copy.get_internal_id() != state_machine_id)
	assert(state_machine.get_internal_id() == state_machine_id)
	assert(state_machine_copy.display_name == "Movement")
	assert(state_machine_copy.enabled == false)
	assert(state_machine_copy.user_note == "Controls movement states.")
	assert(state_machine_copy.states.size() == 3)
	assert(state_machine_copy.states[0] == null)
	assert(idle_state_copy != idle_state)
	assert(run_state_copy != run_state)
	assert(idle_state_copy.get_internal_id().length() == 32)
	assert(run_state_copy.get_internal_id().length() == 32)
	assert(idle_state_copy.get_internal_id() != idle_state_id)
	assert(run_state_copy.get_internal_id() != run_state_id)
	assert(idle_state_copy.display_name == "Idle")
	assert(run_state_copy.display_name == "Run")
	assert(state_machine_copy.initial_state_id == run_state_copy.get_internal_id())
	assert(state_machine_copy.get_initial_state() == run_state_copy)
	assert(state_machine.display_name == "Movement")
	assert(state_machine.enabled == false)
	assert(state_machine.user_note == "Controls movement states.")
	assert(state_machine.states.size() == 3)
	assert(state_machine.states[0] == null)
	assert(state_machine.states[1] == idle_state)
	assert(state_machine.states[2] == run_state)
	assert(state_machine.initial_state_id == run_state_id)
	assert(state_machine.get_initial_state() == run_state)
	assert(idle_state.get_internal_id() == idle_state_id)
	assert(run_state.get_internal_id() == run_state_id)
	assert(idle_state.is_initial == idle_is_initial)
	assert(run_state.is_initial == run_is_initial)

	var state_machine_without_initial: FlowStateMachineDefinition = FlowStateMachineDefinition.new()
	var unassigned_state: FlowStateDefinition = FlowStateDefinition.new()
	state_machine_without_initial.states.append(unassigned_state)
	assert(state_machine_without_initial.initial_state_id == "")
	var state_machine_without_initial_copy: FlowStateMachineDefinition = state_machine_without_initial.duplicate_with_new_ids()
	var unassigned_state_copy: FlowStateDefinition = state_machine_without_initial_copy.states[0] as FlowStateDefinition
	assert(state_machine_without_initial_copy.initial_state_id == unassigned_state_copy.get_internal_id())
	assert(state_machine_without_initial_copy.get_initial_state() == unassigned_state_copy)

	var state_machine_with_invalid_initial: FlowStateMachineDefinition = FlowStateMachineDefinition.new()
	var invalid_initial_state: FlowStateDefinition = FlowStateDefinition.new()
	state_machine_with_invalid_initial.states.append(invalid_initial_state)
	state_machine_with_invalid_initial.initial_state_id = "missing_state"
	var state_machine_with_invalid_initial_copy: FlowStateMachineDefinition = state_machine_with_invalid_initial.duplicate_with_new_ids()
	assert(state_machine_with_invalid_initial_copy.initial_state_id == "")
	assert(state_machine_with_invalid_initial_copy.get_initial_state() == null)

	var schema_2_graph: FlowGraph = FlowGraph.new()
	schema_2_graph.schema_version = FlowGraph.SCHEMA_VERSION_2
	var schema_2_process: FlowProcess = FlowProcess.new()
	var schema_2_block: FlowBlock = FlowBlock.new()
	schema_2_process.blocks.append(schema_2_block)
	schema_2_process.blocks.append(null)
	schema_2_graph.processes.append(schema_2_process)
	schema_2_graph.processes.append(null)

	var schema_2_global: FlowVariableDefinition = FlowVariableDefinition.new()
	schema_2_global.scope = FlowVariableDefinition.Scope.GLOBAL
	var schema_2_local: FlowVariableDefinition = FlowVariableDefinition.new()
	schema_2_local.owner_container_id = schema_2_process.get_internal_id()
	schema_2_local.global_variable_id = schema_2_global.get_internal_id()
	schema_2_graph.variables.append(schema_2_global)
	schema_2_graph.variables.append(null)
	schema_2_graph.variables.append(schema_2_local)

	var schema_2_machine: FlowStateMachineDefinition = FlowStateMachineDefinition.new()
	schema_2_machine.add_state(null)
	var schema_2_state: FlowStateDefinition = FlowStateDefinition.new()
	var schema_2_state_block: FlowBlock = FlowBlock.new()
	schema_2_state.blocks.append(schema_2_state_block)
	schema_2_machine.add_state(schema_2_state)
	schema_2_graph.state_machines.append(schema_2_machine)
	schema_2_graph.state_machines.append(null)

	var schema_2_result: FlowValidationResult = FlowGraphValidator.validate(schema_2_graph)
	assert(not schema_2_result.has_errors())
	assert(schema_2_result.diagnostics.is_empty())
	assert(schema_2_graph.containers.is_empty())
	assert(schema_2_graph.processes.size() == 2)
	assert(schema_2_graph.processes[1] == null)
	assert(schema_2_graph.variables.size() == 3)
	assert(schema_2_graph.variables[1] == null)
	assert(schema_2_graph.state_machines.size() == 2)
	assert(schema_2_graph.state_machines[1] == null)

	var schema_2_graph_id: String = schema_2_graph.get_internal_id()
	var schema_2_process_id: String = schema_2_process.get_internal_id()
	var schema_2_block_id: String = schema_2_block.get_internal_id()
	var schema_2_global_id: String = schema_2_global.get_internal_id()
	var schema_2_local_id: String = schema_2_local.get_internal_id()
	var schema_2_machine_id: String = schema_2_machine.get_internal_id()
	var schema_2_state_id: String = schema_2_state.get_internal_id()
	var schema_2_state_block_id: String = schema_2_state_block.get_internal_id()
	var schema_2_copy: FlowGraph = schema_2_graph.duplicate_with_new_ids()
	var schema_2_process_copy: FlowProcess = schema_2_copy.processes[0] as FlowProcess
	var schema_2_global_copy: FlowVariableDefinition = schema_2_copy.variables[0] as FlowVariableDefinition
	var schema_2_local_copy: FlowVariableDefinition = schema_2_copy.variables[2] as FlowVariableDefinition
	var schema_2_machine_copy: FlowStateMachineDefinition = schema_2_copy.state_machines[0] as FlowStateMachineDefinition
	var schema_2_state_copy: FlowStateDefinition = schema_2_machine_copy.states[1] as FlowStateDefinition

	assert(schema_2_copy != schema_2_graph)
	assert(schema_2_copy.get_internal_id().length() == 32)
	assert(schema_2_copy.get_internal_id() != schema_2_graph_id)
	assert(schema_2_copy.schema_version == FlowGraph.SCHEMA_VERSION_2)
	assert(schema_2_copy.containers.is_empty())
	assert(schema_2_copy.processes.size() == 2)
	assert(schema_2_copy.processes[1] == null)
	assert(schema_2_copy.variables.size() == 3)
	assert(schema_2_copy.variables[1] == null)
	assert(schema_2_copy.state_machines.size() == 2)
	assert(schema_2_copy.state_machines[1] == null)
	assert(schema_2_process_copy != schema_2_process)
	assert(schema_2_process_copy.get_internal_id().length() == 32)
	assert(schema_2_process_copy.get_internal_id() != schema_2_process_id)
	assert(schema_2_process_copy.blocks.size() == 2)
	assert(schema_2_process_copy.blocks[1] == null)
	assert(schema_2_process_copy.blocks[0] != schema_2_block)
	assert(schema_2_process_copy.blocks[0].get_internal_id().length() == 32)
	assert(schema_2_process_copy.blocks[0].get_internal_id() != schema_2_block_id)
	assert(schema_2_global_copy != schema_2_global)
	assert(schema_2_global_copy.get_internal_id() != schema_2_global_id)
	assert(schema_2_local_copy != schema_2_local)
	assert(schema_2_local_copy.get_internal_id() != schema_2_local_id)
	assert(schema_2_local_copy.owner_container_id == schema_2_process_copy.get_internal_id())
	assert(schema_2_local_copy.global_variable_id == schema_2_global_copy.get_internal_id())
	assert(schema_2_machine_copy != schema_2_machine)
	assert(schema_2_machine_copy.get_internal_id() != schema_2_machine_id)
	assert(schema_2_machine_copy.states.size() == 2)
	assert(schema_2_machine_copy.states[0] == null)
	assert(schema_2_state_copy != schema_2_state)
	assert(schema_2_state_copy.get_internal_id() != schema_2_state_id)
	assert(schema_2_state_copy.blocks[0] != schema_2_state_block)
	assert(schema_2_state_copy.blocks[0].get_internal_id() != schema_2_state_block_id)
	assert(schema_2_machine_copy.initial_state_id == schema_2_state_copy.get_internal_id())
	assert(schema_2_machine_copy.get_initial_state() == schema_2_state_copy)
	assert(schema_2_graph.get_internal_id() == schema_2_graph_id)
	assert(schema_2_process.get_internal_id() == schema_2_process_id)
	assert(schema_2_block.get_internal_id() == schema_2_block_id)
	assert(schema_2_global.get_internal_id() == schema_2_global_id)
	assert(schema_2_local.get_internal_id() == schema_2_local_id)
	assert(schema_2_local.owner_container_id == schema_2_process_id)
	assert(schema_2_local.global_variable_id == schema_2_global_id)
	assert(schema_2_machine.get_internal_id() == schema_2_machine_id)
	assert(schema_2_state.get_internal_id() == schema_2_state_id)
	assert(schema_2_state_block.get_internal_id() == schema_2_state_block_id)

	var missing_reference_graph: FlowGraph = FlowGraph.new()
	missing_reference_graph.schema_version = FlowGraph.SCHEMA_VERSION_2
	var missing_reference_variable: FlowVariableDefinition = FlowVariableDefinition.new()
	missing_reference_variable.owner_container_id = "missing_owner"
	missing_reference_variable.global_variable_id = "missing_global"
	missing_reference_graph.variables.append(missing_reference_variable)
	var missing_reference_result: FlowValidationResult = FlowGraphValidator.validate(
		missing_reference_graph
	)
	assert(missing_reference_result.has_errors())
	assert(_has_diagnostic(
		missing_reference_result,
		FlowDiagnostic.CODE_MISSING_OWNER_CONTAINER_REFERENCE
	))
	assert(_has_diagnostic(
		missing_reference_result,
		FlowDiagnostic.CODE_MISSING_GLOBAL_VARIABLE_REFERENCE
	))
	assert(missing_reference_variable.owner_container_id == "missing_owner")
	assert(missing_reference_variable.global_variable_id == "missing_global")

	var invalid_reference_graph: FlowGraph = FlowGraph.new()
	invalid_reference_graph.schema_version = FlowGraph.SCHEMA_VERSION_2
	var invalid_reference_variable: FlowVariableDefinition = FlowVariableDefinition.new()
	var non_global_target: FlowVariableDefinition = FlowVariableDefinition.new()
	invalid_reference_variable.owner_container_id = non_global_target.get_internal_id()
	invalid_reference_variable.global_variable_id = non_global_target.get_internal_id()
	invalid_reference_graph.variables.append(invalid_reference_variable)
	invalid_reference_graph.variables.append(non_global_target)
	var invalid_reference_result: FlowValidationResult = FlowGraphValidator.validate(
		invalid_reference_graph
	)
	assert(_has_diagnostic(
		invalid_reference_result,
		FlowDiagnostic.CODE_INVALID_OWNER_CONTAINER_REFERENCE
	))
	assert(_has_diagnostic(
		invalid_reference_result,
		FlowDiagnostic.CODE_INVALID_GLOBAL_VARIABLE_REFERENCE
	))

	var mixed_sources_graph: FlowGraph = FlowGraph.new()
	mixed_sources_graph.schema_version = FlowGraph.SCHEMA_VERSION_2
	mixed_sources_graph.containers.append(FlowProcess.new())
	mixed_sources_graph.processes.append(FlowProcess.new())
	var mixed_sources_result: FlowValidationResult = FlowGraphValidator.validate(mixed_sources_graph)
	assert(_has_diagnostic(mixed_sources_result, FlowDiagnostic.CODE_MIXED_SCHEMA_SOURCES))

	var repeated_schema_2_graph: FlowGraph = FlowGraph.new()
	repeated_schema_2_graph.schema_version = FlowGraph.SCHEMA_VERSION_2
	var repeated_schema_2_process: FlowProcess = FlowProcess.new()
	repeated_schema_2_graph.processes.append(repeated_schema_2_process)
	repeated_schema_2_graph.processes.append(repeated_schema_2_process)
	var repeated_schema_2_result: FlowValidationResult = FlowGraphValidator.validate(
		repeated_schema_2_graph
	)
	assert(_has_diagnostic(
		repeated_schema_2_result,
		FlowDiagnostic.CODE_REPEATED_RESOURCE_INSTANCE
	))

	var migration_source: FlowGraph = FlowGraph.new()
	var migration_process: FlowProcess = FlowProcess.new()
	var migration_process_block: FlowBlock = FlowBlock.new()
	migration_process.blocks.append(migration_process_block)
	var migration_initial_state: FlowStateDefinition = FlowStateDefinition.new()
	migration_initial_state.is_initial = true
	var migration_initial_block: FlowBlock = FlowBlock.new()
	migration_initial_state.blocks.append(migration_initial_block)
	var migration_second_state: FlowStateDefinition = FlowStateDefinition.new()
	migration_source.containers.append(migration_process)
	migration_source.containers.append(null)
	migration_source.containers.append(migration_initial_state)
	migration_source.containers.append(migration_second_state)

	var migration_source_id: String = migration_source.get_internal_id()
	var migration_process_id: String = migration_process.get_internal_id()
	var migration_process_block_id: String = migration_process_block.get_internal_id()
	var migration_initial_state_id: String = migration_initial_state.get_internal_id()
	var migration_initial_block_id: String = migration_initial_block.get_internal_id()
	var migration_second_state_id: String = migration_second_state.get_internal_id()
	var migration_result: FlowGraphMigrationResult = FlowGraphMigrator.migrate_schema_1_to_2(
		migration_source
	)
	assert(migration_result.is_successful())
	assert(migration_result.diagnostics.is_empty())
	var migrated_graph: FlowGraph = migration_result.migrated_graph
	var migrated_process: FlowProcess = migrated_graph.processes[0] as FlowProcess
	var migrated_machine: FlowStateMachineDefinition = migrated_graph.state_machines[0] as FlowStateMachineDefinition
	var migrated_initial_state: FlowStateDefinition = migrated_machine.states[2] as FlowStateDefinition
	var migrated_second_state: FlowStateDefinition = migrated_machine.states[3] as FlowStateDefinition
	assert(migrated_graph != migration_source)
	assert(migrated_graph.schema_version == FlowGraph.SCHEMA_VERSION_2)
	assert(migrated_graph.get_internal_id() == migration_source_id)
	assert(migrated_graph.containers.is_empty())
	assert(migrated_graph.processes.size() == 4)
	assert(migrated_graph.processes[1] == null)
	assert(migrated_graph.processes[2] == null)
	assert(migrated_graph.processes[3] == null)
	assert(migrated_process != migration_process)
	assert(migrated_process.get_internal_id() == migration_process_id)
	assert(migrated_process.blocks[0] != migration_process_block)
	assert(migrated_process.blocks[0].get_internal_id() == migration_process_block_id)
	assert(migrated_graph.state_machines.size() == 1)
	assert(migrated_machine.display_name == "Migrated States")
	assert(migrated_machine.get_internal_id().length() == 32)
	assert(migrated_machine.get_internal_id() != migration_source_id)
	assert(migrated_machine.states.size() == 4)
	assert(migrated_machine.states[0] == null)
	assert(migrated_machine.states[1] == null)
	assert(migrated_initial_state != migration_initial_state)
	assert(migrated_initial_state.get_internal_id() == migration_initial_state_id)
	assert(migrated_initial_state.blocks[0] != migration_initial_block)
	assert(migrated_initial_state.blocks[0].get_internal_id() == migration_initial_block_id)
	assert(migrated_second_state != migration_second_state)
	assert(migrated_second_state.get_internal_id() == migration_second_state_id)
	assert(migrated_machine.initial_state_id == migration_initial_state_id)
	assert(migrated_machine.get_initial_state() == migrated_initial_state)
	var migrated_validation: FlowValidationResult = FlowGraphValidator.validate(migrated_graph)
	assert(not migrated_validation.has_errors())
	assert(migration_source.schema_version == FlowGraph.CURRENT_SCHEMA_VERSION)
	assert(migration_source.get_internal_id() == migration_source_id)
	assert(migration_source.containers.size() == 4)
	assert(migration_source.containers[0] == migration_process)
	assert(migration_source.containers[1] == null)
	assert(migration_source.containers[2] == migration_initial_state)
	assert(migration_source.containers[3] == migration_second_state)
	assert(migration_source.processes.is_empty())
	assert(migration_source.variables.is_empty())
	assert(migration_source.state_machines.is_empty())
	assert(migration_process.get_internal_id() == migration_process_id)
	assert(migration_process_block.get_internal_id() == migration_process_block_id)
	assert(migration_initial_state.get_internal_id() == migration_initial_state_id)
	assert(migration_initial_block.get_internal_id() == migration_initial_block_id)
	assert(migration_second_state.get_internal_id() == migration_second_state_id)

	var no_initial_source: FlowGraph = FlowGraph.new()
	no_initial_source.containers.append(null)
	var no_initial_state: FlowStateDefinition = FlowStateDefinition.new()
	no_initial_source.containers.append(no_initial_state)
	var no_initial_result: FlowGraphMigrationResult = FlowGraphMigrator.migrate_schema_1_to_2(
		no_initial_source
	)
	assert(no_initial_result.is_successful())
	var no_initial_machine: FlowStateMachineDefinition = no_initial_result.migrated_graph.state_machines[0] as FlowStateMachineDefinition
	var no_initial_state_copy: FlowStateDefinition = no_initial_machine.states[1] as FlowStateDefinition
	assert(no_initial_machine.initial_state_id == no_initial_state_copy.get_internal_id())
	assert(no_initial_machine.get_initial_state() == no_initial_state_copy)

	var multiple_initial_source: FlowGraph = FlowGraph.new()
	var first_multiple_initial_state: FlowStateDefinition = FlowStateDefinition.new()
	var second_multiple_initial_state: FlowStateDefinition = FlowStateDefinition.new()
	first_multiple_initial_state.is_initial = true
	second_multiple_initial_state.is_initial = true
	multiple_initial_source.containers.append(first_multiple_initial_state)
	multiple_initial_source.containers.append(second_multiple_initial_state)
	var multiple_initial_source_id: String = multiple_initial_source.get_internal_id()
	var multiple_initial_result: FlowGraphMigrationResult = FlowGraphMigrator.migrate_schema_1_to_2(
		multiple_initial_source
	)
	assert(not multiple_initial_result.is_successful())
	assert(multiple_initial_result.migrated_graph == null)
	assert(_has_migration_diagnostic(
		multiple_initial_result,
		FlowDiagnostic.CODE_MULTIPLE_INITIAL_STATES
	))
	assert(multiple_initial_source.get_internal_id() == multiple_initial_source_id)
	assert(multiple_initial_source.schema_version == FlowGraph.CURRENT_SCHEMA_VERSION)
	assert(multiple_initial_source.containers[0] == first_multiple_initial_state)
	assert(multiple_initial_source.containers[1] == second_multiple_initial_state)

	var unknown_container_source: FlowGraph = FlowGraph.new()
	var unknown_container: FlowBlockContainer = FlowBlockContainer.new()
	unknown_container_source.containers.append(unknown_container)
	var unknown_container_result: FlowGraphMigrationResult = FlowGraphMigrator.migrate_schema_1_to_2(
		unknown_container_source
	)
	assert(not unknown_container_result.is_successful())
	assert(_has_migration_diagnostic(
		unknown_container_result,
		FlowDiagnostic.CODE_UNMIGRATABLE_CONTAINER_TYPE
	))
	assert(unknown_container_source.containers[0] == unknown_container)
	assert(unknown_container_source.schema_version == FlowGraph.CURRENT_SCHEMA_VERSION)

	var invalid_migration_source: FlowGraph = FlowGraph.new()
	invalid_migration_source._internal_id = ""
	var invalid_migration_result: FlowGraphMigrationResult = FlowGraphMigrator.migrate_schema_1_to_2(
		invalid_migration_source
	)
	assert(not invalid_migration_result.is_successful())
	assert(_has_migration_diagnostic(
		invalid_migration_result,
		FlowDiagnostic.CODE_EMPTY_INTERNAL_ID
	))
	assert(invalid_migration_source._internal_id == "")
	assert(invalid_migration_source.schema_version == FlowGraph.CURRENT_SCHEMA_VERSION)

	var first_deterministic_failure: FlowGraphMigrationResult = FlowGraphMigrator.migrate_schema_1_to_2(
		multiple_initial_source
	)
	var second_deterministic_failure: FlowGraphMigrationResult = FlowGraphMigrator.migrate_schema_1_to_2(
		multiple_initial_source
	)
	assert(first_deterministic_failure.diagnostics.size() == second_deterministic_failure.diagnostics.size())
	for migration_diagnostic_index: int in first_deterministic_failure.diagnostics.size():
		var first_migration_diagnostic: FlowDiagnostic = first_deterministic_failure.diagnostics[migration_diagnostic_index]
		var second_migration_diagnostic: FlowDiagnostic = second_deterministic_failure.diagnostics[migration_diagnostic_index]
		assert(first_migration_diagnostic.code == second_migration_diagnostic.code)
		assert(first_migration_diagnostic.element_path == second_migration_diagnostic.element_path)
		assert(first_migration_diagnostic.related_id == second_migration_diagnostic.related_id)

	print("[Flujo] Model smoke test passed")
	await get_tree().process_frame
	get_tree().quit()
