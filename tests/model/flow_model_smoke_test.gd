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


func _test_method_call_foundation() -> void:
	var graph: FlowGraph = FlowGraph.new()
	graph.schema_version = FlowGraph.SCHEMA_VERSION_3
	graph.constructor = FlowConstructorDefinition.new()

	var target_method: FlowMethodDefinition = FlowMethodDefinition.new()
	target_method.display_name = "Target Method"
	var caller_method: FlowMethodDefinition = FlowMethodDefinition.new()
	caller_method.display_name = "Caller Method"

	var constructor_call: FlowMethodCallBlock = FlowMethodCallBlock.new()
	constructor_call.method_id = target_method.get_internal_id()
	graph.constructor.blocks = [constructor_call, null]

	var process: FlowProcess = FlowProcess.new()
	var process_call: FlowMethodCallBlock = FlowMethodCallBlock.new()
	process_call.method_id = target_method.get_internal_id()
	process.blocks = [null, process_call]
	graph.processes = [process, null]

	var state: FlowStateDefinition = FlowStateDefinition.new()
	var state_call: FlowMethodCallBlock = FlowMethodCallBlock.new()
	state_call.method_id = target_method.get_internal_id()
	state.blocks = [state_call, null]
	var state_machine: FlowStateMachineDefinition = FlowStateMachineDefinition.new()
	state_machine.states = [null, state]
	state_machine.initial_state_id = state.get_internal_id()
	graph.state_machines = [state_machine]

	var method_call: FlowMethodCallBlock = FlowMethodCallBlock.new()
	method_call.method_id = target_method.get_internal_id()
	caller_method.blocks = [method_call, null]
	var self_call: FlowMethodCallBlock = FlowMethodCallBlock.new()
	self_call.method_id = target_method.get_internal_id()
	target_method.blocks = [null, self_call]
	graph.methods = [caller_method, null, target_method]

	var graph_id: String = graph.get_internal_id()
	var target_method_id: String = target_method.get_internal_id()
	var constructor_call_id: String = constructor_call.get_internal_id()
	var process_call_id: String = process_call.get_internal_id()
	var state_call_id: String = state_call.get_internal_id()
	var method_call_id: String = method_call.get_internal_id()
	var self_call_id: String = self_call.get_internal_id()
	var validation: FlowValidationResult = FlowGraphValidator.validate(graph)
	assert(not validation.has_errors())
	assert(validation.diagnostics.is_empty())
	assert(graph.methods[2] == target_method)
	assert(self_call.method_id == target_method_id)

	var copy: FlowGraph = graph.duplicate_with_new_ids()
	var target_method_copy: FlowMethodDefinition = copy.methods[2]
	var constructor_call_copy: FlowMethodCallBlock = copy.constructor.blocks[0]
	var process_call_copy: FlowMethodCallBlock = copy.processes[0].blocks[1]
	var state_call_copy: FlowMethodCallBlock = copy.state_machines[0].states[1].blocks[0]
	var method_call_copy: FlowMethodCallBlock = copy.methods[0].blocks[0]
	var self_call_copy: FlowMethodCallBlock = target_method_copy.blocks[1]
	assert(copy != graph)
	assert(copy.get_internal_id() != graph_id)
	assert(copy.processes.size() == 2 and copy.processes[1] == null)
	assert(copy.processes[0].blocks.size() == 2 and copy.processes[0].blocks[0] == null)
	assert(copy.state_machines[0].states.size() == 2 and copy.state_machines[0].states[0] == null)
	assert(copy.constructor.blocks.size() == 2 and copy.constructor.blocks[1] == null)
	assert(copy.methods.size() == 3 and copy.methods[1] == null)
	assert(copy.methods[0].blocks.size() == 2 and copy.methods[0].blocks[1] == null)
	assert(target_method_copy.blocks.size() == 2 and target_method_copy.blocks[0] == null)
	for call_copy: FlowMethodCallBlock in [
		constructor_call_copy,
		process_call_copy,
		state_call_copy,
		method_call_copy,
		self_call_copy,
	]:
		assert(call_copy is FlowMethodCallBlock)
		assert(call_copy.method_id == target_method_copy.get_internal_id())
	assert(target_method_copy.get_internal_id() != target_method_id)
	assert(constructor_call_copy != constructor_call and constructor_call_copy.get_internal_id() != constructor_call_id)
	assert(process_call_copy != process_call and process_call_copy.get_internal_id() != process_call_id)
	assert(state_call_copy != state_call and state_call_copy.get_internal_id() != state_call_id)
	assert(method_call_copy != method_call and method_call_copy.get_internal_id() != method_call_id)
	assert(self_call_copy != self_call and self_call_copy.get_internal_id() != self_call_id)
	constructor_call_copy.method_id = caller_method.get_internal_id()
	constructor_call_copy.display_name = "Changed Copy"
	assert(constructor_call.method_id == target_method_id)
	assert(constructor_call.display_name == "Call Method")
	assert(graph.get_internal_id() == graph_id)
	assert(not FlowGraphValidator.validate(graph).has_errors())

	var unknown_graph: FlowGraph = FlowGraph.new()
	unknown_graph.schema_version = FlowGraph.SCHEMA_VERSION_3
	unknown_graph.constructor = FlowConstructorDefinition.new()
	var unknown_call: FlowMethodCallBlock = FlowMethodCallBlock.new()
	unknown_call.method_id = "unknown_method_id"
	unknown_graph.constructor.blocks = [null, unknown_call]
	var unknown_copy: FlowGraph = unknown_graph.duplicate_with_new_ids()
	assert(unknown_copy.constructor.blocks[0] == null)
	assert(unknown_copy.constructor.blocks[1] is FlowMethodCallBlock)
	assert(unknown_copy.constructor.blocks[1] != unknown_call)
	assert(unknown_copy.constructor.blocks[1].get_internal_id() != unknown_call.get_internal_id())
	assert((unknown_copy.constructor.blocks[1] as FlowMethodCallBlock).method_id == "unknown_method_id")
	assert(unknown_call.method_id == "unknown_method_id")

	var diagnostic_graph: FlowGraph = FlowGraph.new()
	diagnostic_graph.schema_version = FlowGraph.SCHEMA_VERSION_3
	diagnostic_graph.constructor = FlowConstructorDefinition.new()
	var diagnostic_process: FlowProcess = FlowProcess.new()
	var empty_process_call: FlowMethodCallBlock = FlowMethodCallBlock.new()
	diagnostic_process.blocks = [empty_process_call]
	diagnostic_graph.processes = [diagnostic_process]
	var diagnostic_state: FlowStateDefinition = FlowStateDefinition.new()
	var missing_state_call: FlowMethodCallBlock = FlowMethodCallBlock.new()
	missing_state_call.method_id = "missing_method_id"
	diagnostic_state.blocks = [missing_state_call]
	var diagnostic_machine: FlowStateMachineDefinition = FlowStateMachineDefinition.new()
	diagnostic_machine.states = [diagnostic_state]
	diagnostic_machine.initial_state_id = diagnostic_state.get_internal_id()
	diagnostic_graph.state_machines = [diagnostic_machine]
	var wrong_type_constructor_call: FlowMethodCallBlock = FlowMethodCallBlock.new()
	wrong_type_constructor_call.method_id = diagnostic_process.get_internal_id()
	diagnostic_graph.constructor.blocks = [wrong_type_constructor_call]
	var diagnostic_method: FlowMethodDefinition = FlowMethodDefinition.new()
	diagnostic_method.display_name = "Diagnostic Caller"
	var empty_method_call: FlowMethodCallBlock = FlowMethodCallBlock.new()
	diagnostic_method.blocks = [empty_method_call]
	var diagnostic_target: FlowMethodDefinition = FlowMethodDefinition.new()
	diagnostic_target.display_name = "Diagnostic Target"
	diagnostic_graph.methods = [diagnostic_method, diagnostic_target]
	var first_diagnostic_result: FlowValidationResult = FlowGraphValidator.validate(diagnostic_graph)
	var second_diagnostic_result: FlowValidationResult = FlowGraphValidator.validate(diagnostic_graph)
	_assert_same_diagnostic_sequence(first_diagnostic_result, second_diagnostic_result)
	assert(first_diagnostic_result.diagnostics.size() == 4)
	var expected_codes: Array[StringName] = [
		FlowDiagnostic.CODE_EMPTY_METHOD_REFERENCE,
		FlowDiagnostic.CODE_MISSING_METHOD_REFERENCE,
		FlowDiagnostic.CODE_INVALID_METHOD_REFERENCE,
		FlowDiagnostic.CODE_EMPTY_METHOD_REFERENCE,
	]
	var expected_paths: Array[String] = [
		"processes[0].blocks[0].method_id",
		"state_machines[0].states[0].blocks[0].method_id",
		"constructor.blocks[0].method_id",
		"methods[0].blocks[0].method_id",
	]
	var expected_related_ids: Array[String] = [
		empty_process_call.get_internal_id(),
		"missing_method_id",
		diagnostic_process.get_internal_id(),
		empty_method_call.get_internal_id(),
	]
	for diagnostic_index: int in first_diagnostic_result.diagnostics.size():
		var diagnostic: FlowDiagnostic = first_diagnostic_result.diagnostics[diagnostic_index]
		assert(diagnostic.code == expected_codes[diagnostic_index])
		assert(diagnostic.element_path == expected_paths[diagnostic_index])
		assert(diagnostic.related_id == expected_related_ids[diagnostic_index])
	assert(empty_process_call.method_id == "")
	assert(missing_state_call.method_id == "missing_method_id")
	assert(wrong_type_constructor_call.method_id == diagnostic_process.get_internal_id())
	assert(empty_method_call.method_id == "")

	for incompatible_schema: int in [FlowGraph.CURRENT_SCHEMA_VERSION, FlowGraph.SCHEMA_VERSION_2]:
		var incompatible_graph: FlowGraph = FlowGraph.new()
		incompatible_graph.schema_version = incompatible_schema
		var incompatible_process: FlowProcess = FlowProcess.new()
		var incompatible_call: FlowMethodCallBlock = FlowMethodCallBlock.new()
		incompatible_call.method_id = "preserved_incompatible_method"
		incompatible_process.blocks = [incompatible_call]
		if incompatible_schema == FlowGraph.CURRENT_SCHEMA_VERSION:
			incompatible_graph.containers = [incompatible_process]
		else:
			incompatible_graph.processes = [incompatible_process]
		var incompatible_first: FlowValidationResult = FlowGraphValidator.validate(incompatible_graph)
		var incompatible_second: FlowValidationResult = FlowGraphValidator.validate(incompatible_graph)
		_assert_same_diagnostic_sequence(incompatible_first, incompatible_second)
		assert(incompatible_first.diagnostics.size() == 1)
		var incompatible_diagnostic: FlowDiagnostic = incompatible_first.diagnostics[0]
		assert(incompatible_diagnostic.code == FlowDiagnostic.CODE_METHOD_CALL_INCOMPATIBLE_SCHEMA)
		assert(incompatible_diagnostic.element_path == (
			"containers[0].blocks[0]"
			if incompatible_schema == FlowGraph.CURRENT_SCHEMA_VERSION
			else "processes[0].blocks[0]"
		))
		assert(incompatible_diagnostic.related_id == incompatible_call.get_internal_id())
		assert(incompatible_call.method_id == "preserved_incompatible_method")

	var resource_path: String = "res://.godot/flow_method_call_regression.tres"
	assert(ResourceSaver.save(graph, resource_path) == OK)
	var loaded_graph: FlowGraph = ResourceLoader.load(
		resource_path,
		"",
		ResourceLoader.CACHE_MODE_IGNORE
	) as FlowGraph
	assert(loaded_graph != null)
	assert(loaded_graph.constructor.blocks[0] is FlowMethodCallBlock)
	assert((loaded_graph.constructor.blocks[0] as FlowMethodCallBlock).method_id == loaded_graph.methods[2].get_internal_id())
	assert(loaded_graph.methods[0].blocks[0] is FlowMethodCallBlock)
	assert(not FlowGraphValidator.validate(loaded_graph).has_errors())
	assert(DirAccess.remove_absolute(ProjectSettings.globalize_path(resource_path)) == OK)
	assert(not FileAccess.file_exists(ProjectSettings.globalize_path(resource_path)))


func _test_method_return_definition() -> void:
	var graph: FlowGraph = FlowGraph.new()
	graph.schema_version = FlowGraph.SCHEMA_VERSION_3
	graph.constructor = FlowConstructorDefinition.new()
	var method_without_return: FlowMethodDefinition = FlowMethodDefinition.new()
	method_without_return.display_name = "No Return"
	var method_with_return: FlowMethodDefinition = FlowMethodDefinition.new()
	method_with_return.display_name = "Typed Return"
	var return_definition: FlowMethodReturnDefinition = FlowMethodReturnDefinition.new()
	return_definition.display_name = "Result"
	return_definition.value_type = FlowVariableDefinition.ValueType.VECTOR3
	method_with_return.return_definition = return_definition
	graph.methods = [method_without_return, null, method_with_return]

	var graph_id: String = graph.get_internal_id()
	var method_with_return_id: String = method_with_return.get_internal_id()
	var return_id: String = return_definition.get_internal_id()
	var valid_result: FlowValidationResult = FlowGraphValidator.validate(graph)
	assert(not valid_result.has_errors())
	assert(method_without_return.return_definition == null)
	assert(method_with_return.return_definition == return_definition)
	assert(return_definition.value_type == FlowVariableDefinition.ValueType.VECTOR3)
	assert(return_definition.value_type != FlowVariableDefinition.ValueType.BOOL)

	var copy: FlowGraph = graph.duplicate_with_new_ids()
	var method_copy: FlowMethodDefinition = copy.methods[2]
	assert(copy != graph)
	assert(copy.get_internal_id() != graph_id)
	assert(copy.methods.size() == 3 and copy.methods[1] == null)
	assert(copy.methods[0].return_definition == null)
	assert(method_copy is FlowMethodDefinition)
	assert(method_copy.get_internal_id() != method_with_return_id)
	assert(method_copy.return_definition is FlowMethodReturnDefinition)
	assert(method_copy.return_definition != return_definition)
	assert(method_copy.return_definition.get_internal_id() != return_id)
	assert(method_copy.return_definition.display_name == "Result")
	assert(method_copy.return_definition.value_type == FlowVariableDefinition.ValueType.VECTOR3)
	method_copy.return_definition.display_name = "Copied Result"
	assert(return_definition.display_name == "Result")
	assert(graph.get_internal_id() == graph_id)
	assert(method_with_return.get_internal_id() == method_with_return_id)
	assert(return_definition.get_internal_id() == return_id)
	assert(not FlowGraphValidator.validate(graph).has_errors())

	var empty_id_graph: FlowGraph = FlowGraph.new()
	empty_id_graph.schema_version = FlowGraph.SCHEMA_VERSION_3
	empty_id_graph.constructor = FlowConstructorDefinition.new()
	var empty_id_method: FlowMethodDefinition = FlowMethodDefinition.new()
	empty_id_method.display_name = "Empty Return ID"
	var empty_id_return: FlowMethodReturnDefinition = FlowMethodReturnDefinition.new()
	empty_id_return._internal_id = ""
	empty_id_method.return_definition = empty_id_return
	empty_id_graph.methods = [empty_id_method]
	var empty_id_first: FlowValidationResult = FlowGraphValidator.validate(empty_id_graph)
	var empty_id_second: FlowValidationResult = FlowGraphValidator.validate(empty_id_graph)
	_assert_same_diagnostic_sequence(empty_id_first, empty_id_second)
	assert(empty_id_first.diagnostics.size() == 1)
	assert(empty_id_first.diagnostics[0].code == FlowDiagnostic.CODE_EMPTY_INTERNAL_ID)
	assert(empty_id_first.diagnostics[0].element_path == "methods[0].return_definition")
	assert(empty_id_first.diagnostics[0].related_id == "")
	assert(empty_id_method.return_definition == empty_id_return)
	assert(empty_id_return.get_internal_id() == "")

	var duplicate_id_graph: FlowGraph = FlowGraph.new()
	duplicate_id_graph.schema_version = FlowGraph.SCHEMA_VERSION_3
	duplicate_id_graph.constructor = FlowConstructorDefinition.new()
	var duplicate_id_method: FlowMethodDefinition = FlowMethodDefinition.new()
	duplicate_id_method.display_name = "Duplicate Return ID"
	var duplicate_id_return: FlowMethodReturnDefinition = FlowMethodReturnDefinition.new()
	duplicate_id_return._internal_id = duplicate_id_method.get_internal_id()
	duplicate_id_method.return_definition = duplicate_id_return
	duplicate_id_graph.methods = [duplicate_id_method]
	var duplicate_id_first: FlowValidationResult = FlowGraphValidator.validate(duplicate_id_graph)
	var duplicate_id_second: FlowValidationResult = FlowGraphValidator.validate(duplicate_id_graph)
	_assert_same_diagnostic_sequence(duplicate_id_first, duplicate_id_second)
	assert(duplicate_id_first.diagnostics.size() == 1)
	assert(duplicate_id_first.diagnostics[0].code == FlowDiagnostic.CODE_DUPLICATE_INTERNAL_ID)
	assert(duplicate_id_first.diagnostics[0].element_path == "methods[0].return_definition")
	assert(duplicate_id_first.diagnostics[0].related_id == duplicate_id_method.get_internal_id())
	assert(duplicate_id_method.return_definition == duplicate_id_return)

	var repeated_instance_graph: FlowGraph = FlowGraph.new()
	repeated_instance_graph.schema_version = FlowGraph.SCHEMA_VERSION_3
	repeated_instance_graph.constructor = FlowConstructorDefinition.new()
	var repeated_return: FlowMethodReturnDefinition = FlowMethodReturnDefinition.new()
	var first_method: FlowMethodDefinition = FlowMethodDefinition.new()
	first_method.display_name = "First Return Owner"
	first_method.return_definition = repeated_return
	var second_method: FlowMethodDefinition = FlowMethodDefinition.new()
	second_method.display_name = "Second Return Owner"
	second_method.return_definition = repeated_return
	repeated_instance_graph.methods = [first_method, second_method]
	var repeated_first: FlowValidationResult = FlowGraphValidator.validate(repeated_instance_graph)
	var repeated_second: FlowValidationResult = FlowGraphValidator.validate(repeated_instance_graph)
	_assert_same_diagnostic_sequence(repeated_first, repeated_second)
	assert(repeated_first.diagnostics.size() == 1)
	assert(repeated_first.diagnostics[0].code == FlowDiagnostic.CODE_REPEATED_RESOURCE_INSTANCE)
	assert(repeated_first.diagnostics[0].element_path == "methods[1].return_definition")
	assert(repeated_first.diagnostics[0].related_id == repeated_return.get_internal_id())
	assert(first_method.return_definition == repeated_return)
	assert(second_method.return_definition == repeated_return)

	for incompatible_schema: int in [FlowGraph.CURRENT_SCHEMA_VERSION, FlowGraph.SCHEMA_VERSION_2]:
		var incompatible_graph: FlowGraph = FlowGraph.new()
		incompatible_graph.schema_version = incompatible_schema
		var incompatible_method: FlowMethodDefinition = FlowMethodDefinition.new()
		incompatible_method.return_definition = FlowMethodReturnDefinition.new()
		incompatible_graph.methods = [incompatible_method]
		var incompatible_result: FlowValidationResult = FlowGraphValidator.validate(incompatible_graph)
		assert(_has_diagnostic(incompatible_result, FlowDiagnostic.CODE_MIXED_SCHEMA_SOURCES))
		assert(incompatible_method.return_definition is FlowMethodReturnDefinition)

	var migration_source: FlowGraph = FlowGraph.new()
	migration_source.schema_version = FlowGraph.SCHEMA_VERSION_2
	var migration_result: FlowGraphMigrationResult = FlowGraphMigrator.migrate_schema_2_to_3(migration_source)
	assert(migration_result.is_successful())
	assert(migration_result.migrated_graph != null)
	assert(migration_result.migrated_graph.methods.is_empty())
	assert(migration_result.migrated_graph.constructor != null)
	assert(migration_source.methods.is_empty())

	var resource_path: String = "res://.godot/flow_method_return_regression.tres"
	assert(ResourceSaver.save(graph, resource_path) == OK)
	var loaded_graph: FlowGraph = ResourceLoader.load(
		resource_path,
		"",
		ResourceLoader.CACHE_MODE_IGNORE
	) as FlowGraph
	assert(loaded_graph != null)
	assert(loaded_graph.methods.size() == 3 and loaded_graph.methods[1] == null)
	assert(loaded_graph.methods[0].return_definition == null)
	assert(loaded_graph.methods[2].return_definition is FlowMethodReturnDefinition)
	assert(loaded_graph.methods[2].return_definition.get_internal_id() == return_id)
	assert(loaded_graph.methods[2].return_definition.display_name == "Result")
	assert(loaded_graph.methods[2].return_definition.value_type == FlowVariableDefinition.ValueType.VECTOR3)
	assert(not FlowGraphValidator.validate(loaded_graph).has_errors())
	assert(DirAccess.remove_absolute(ProjectSettings.globalize_path(resource_path)) == OK)
	assert(not FileAccess.file_exists(ProjectSettings.globalize_path(resource_path)))


func _test_flow_id_validation() -> void:
	var generated_id: String = FlowId.create()
	assert(FlowId.is_valid(generated_id))
	assert(not FlowId.is_valid(""))
	assert(not FlowId.is_valid("1234"))
	assert(not FlowId.is_valid("zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz"))

	var malformed_graph: FlowGraph = FlowGraph.new()
	malformed_graph._internal_id = "z"
	var first_result: FlowValidationResult = FlowGraphValidator.validate(malformed_graph)
	var second_result: FlowValidationResult = FlowGraphValidator.validate(malformed_graph)
	_assert_same_diagnostic_sequence(first_result, second_result)
	assert(first_result.diagnostics.size() == 2)
	assert(first_result.diagnostics[0].code == FlowDiagnostic.CODE_INVALID_INTERNAL_ID_LENGTH)
	assert(first_result.diagnostics[0].element_path == "graph")
	assert(first_result.diagnostics[0].related_id == "z")
	assert(first_result.diagnostics[1].code == FlowDiagnostic.CODE_NON_HEXADECIMAL_INTERNAL_ID)
	assert(first_result.diagnostics[1].element_path == "graph")
	assert(first_result.diagnostics[1].related_id == "z")


func _test_isolated_method_invalid_id_duplication() -> void:
	var malformed_method: FlowMethodDefinition = FlowMethodDefinition.new()
	malformed_method._internal_id = "malformed_method_id"
	var malformed_call: FlowMethodCallBlock = FlowMethodCallBlock.new()
	malformed_call.method_id = malformed_method.get_internal_id()
	malformed_method.blocks = [malformed_call]
	var malformed_copy: FlowMethodDefinition = malformed_method.duplicate_method_with_new_ids()
	assert(malformed_copy.get_internal_id() == "malformed_method_id")
	assert(malformed_copy.blocks[0] is FlowMethodCallBlock)
	assert(malformed_copy.blocks[0] != malformed_call)
	assert((malformed_copy.blocks[0] as FlowMethodCallBlock).method_id == "malformed_method_id")
	assert(malformed_method.get_internal_id() == "malformed_method_id")
	assert(malformed_call.method_id == "malformed_method_id")
	var malformed_graph: FlowGraph = FlowGraph.new()
	malformed_graph.schema_version = FlowGraph.SCHEMA_VERSION_3
	malformed_graph.constructor = FlowConstructorDefinition.new()
	malformed_graph.methods = [malformed_copy]
	var malformed_first: FlowValidationResult = FlowGraphValidator.validate(malformed_graph)
	var malformed_second: FlowValidationResult = FlowGraphValidator.validate(malformed_graph)
	_assert_same_diagnostic_sequence(malformed_first, malformed_second)
	assert(malformed_first.diagnostics.size() == 2)
	assert(malformed_first.diagnostics[0].code == FlowDiagnostic.CODE_INVALID_INTERNAL_ID_LENGTH)
	assert(malformed_first.diagnostics[0].element_path == "methods[0]")
	assert(malformed_first.diagnostics[0].related_id == "malformed_method_id")
	assert(malformed_first.diagnostics[1].code == FlowDiagnostic.CODE_NON_HEXADECIMAL_INTERNAL_ID)
	assert(malformed_first.diagnostics[1].element_path == "methods[0]")
	assert(malformed_first.diagnostics[1].related_id == "malformed_method_id")

	var empty_method: FlowMethodDefinition = FlowMethodDefinition.new()
	empty_method._internal_id = ""
	var empty_call: FlowMethodCallBlock = FlowMethodCallBlock.new()
	empty_call.method_id = ""
	empty_method.blocks = [empty_call]
	var empty_copy: FlowMethodDefinition = empty_method.duplicate_method_with_new_ids()
	assert(empty_copy.get_internal_id() == "")
	assert((empty_copy.blocks[0] as FlowMethodCallBlock).method_id == "")
	assert(empty_copy.blocks[0] != empty_call)
	assert(empty_method.get_internal_id() == "")
	assert(empty_call.method_id == "")
	var empty_graph: FlowGraph = FlowGraph.new()
	empty_graph.schema_version = FlowGraph.SCHEMA_VERSION_3
	empty_graph.constructor = FlowConstructorDefinition.new()
	empty_graph.methods = [empty_copy]
	var empty_first: FlowValidationResult = FlowGraphValidator.validate(empty_graph)
	var empty_second: FlowValidationResult = FlowGraphValidator.validate(empty_graph)
	_assert_same_diagnostic_sequence(empty_first, empty_second)
	assert(empty_first.diagnostics.size() == 2)
	assert(empty_first.diagnostics[0].code == FlowDiagnostic.CODE_EMPTY_INTERNAL_ID)
	assert(empty_first.diagnostics[0].element_path == "methods[0]")
	assert(empty_first.diagnostics[1].code == FlowDiagnostic.CODE_EMPTY_METHOD_REFERENCE)
	assert(empty_first.diagnostics[1].element_path == "methods[0].blocks[0].method_id")

	var ambiguous_id: String = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
	var first_order_method: FlowMethodDefinition = FlowMethodDefinition.new()
	first_order_method._internal_id = ambiguous_id
	var first_order_call: FlowMethodCallBlock = FlowMethodCallBlock.new()
	first_order_call.method_id = ambiguous_id
	var first_order_block: FlowBlock = FlowBlock.new()
	first_order_block._internal_id = ambiguous_id
	first_order_method.blocks = [first_order_call, first_order_block]
	var second_order_method: FlowMethodDefinition = FlowMethodDefinition.new()
	second_order_method._internal_id = ambiguous_id
	var second_order_block: FlowBlock = FlowBlock.new()
	second_order_block._internal_id = ambiguous_id
	var second_order_call: FlowMethodCallBlock = FlowMethodCallBlock.new()
	second_order_call.method_id = ambiguous_id
	second_order_method.blocks = [second_order_block, second_order_call]
	var first_order_copy: FlowMethodDefinition = first_order_method.duplicate_method_with_new_ids()
	var second_order_copy: FlowMethodDefinition = second_order_method.duplicate_method_with_new_ids()
	assert(first_order_copy.get_internal_id() == ambiguous_id)
	assert(first_order_copy.blocks[1].get_internal_id() == ambiguous_id)
	assert((first_order_copy.blocks[0] as FlowMethodCallBlock).method_id == ambiguous_id)
	assert(second_order_copy.get_internal_id() == ambiguous_id)
	assert(second_order_copy.blocks[0].get_internal_id() == ambiguous_id)
	assert((second_order_copy.blocks[1] as FlowMethodCallBlock).method_id == ambiguous_id)
	assert(first_order_copy.blocks[0] != first_order_call)
	assert(first_order_copy.blocks[1] != first_order_block)
	assert(second_order_copy.blocks[0] != second_order_block)
	assert(second_order_copy.blocks[1] != second_order_call)
	first_order_copy.blocks[1].display_name = "Copied Ambiguous Block"
	assert(first_order_block.display_name == "Block")
	var ambiguous_graph: FlowGraph = FlowGraph.new()
	ambiguous_graph.schema_version = FlowGraph.SCHEMA_VERSION_3
	ambiguous_graph.constructor = FlowConstructorDefinition.new()
	ambiguous_graph.methods = [first_order_copy]
	var ambiguous_first: FlowValidationResult = FlowGraphValidator.validate(ambiguous_graph)
	var ambiguous_second: FlowValidationResult = FlowGraphValidator.validate(ambiguous_graph)
	_assert_same_diagnostic_sequence(ambiguous_first, ambiguous_second)
	assert(ambiguous_first.diagnostics.size() == 1)
	assert(ambiguous_first.diagnostics[0].code == FlowDiagnostic.CODE_DUPLICATE_INTERNAL_ID)
	assert(ambiguous_first.diagnostics[0].element_path == "methods[0].blocks[1]")
	assert(ambiguous_first.diagnostics[0].related_id == ambiguous_id)


func _test_isolated_method_duplication() -> void:
	var original: FlowMethodDefinition = FlowMethodDefinition.new()
	original.display_name = "Independent Method"
	original.enabled = false
	original.user_note = "Original method note"
	var first_parameter: FlowMethodParameterDefinition = FlowMethodParameterDefinition.new()
	first_parameter.display_name = "First Parameter"
	first_parameter.value_type = FlowVariableDefinition.ValueType.INT
	var second_parameter: FlowMethodParameterDefinition = FlowMethodParameterDefinition.new()
	second_parameter.display_name = "Second Parameter"
	second_parameter.value_type = FlowVariableDefinition.ValueType.COLOR
	original.parameters = [first_parameter, null, second_parameter]
	var return_definition: FlowMethodReturnDefinition = FlowMethodReturnDefinition.new()
	return_definition.display_name = "Method Result"
	return_definition.value_type = FlowVariableDefinition.ValueType.STRING
	original.return_definition = return_definition
	var self_call: FlowMethodCallBlock = FlowMethodCallBlock.new()
	self_call.display_name = "Self Call"
	self_call.method_id = original.get_internal_id()
	var regular_block: FlowBlock = FlowBlock.new()
	regular_block.display_name = "Regular Block"
	var external_call: FlowMethodCallBlock = FlowMethodCallBlock.new()
	external_call.display_name = "External Call"
	external_call.method_id = "external_method_id"
	original.blocks = [null, self_call, regular_block, external_call, null]

	var original_id: String = original.get_internal_id()
	var first_parameter_id: String = first_parameter.get_internal_id()
	var second_parameter_id: String = second_parameter.get_internal_id()
	var return_id: String = return_definition.get_internal_id()
	var self_call_id: String = self_call.get_internal_id()
	var regular_block_id: String = regular_block.get_internal_id()
	var external_call_id: String = external_call.get_internal_id()
	var first_copy: FlowMethodDefinition = original.duplicate_method_with_new_ids()
	var second_copy: FlowMethodDefinition = original.duplicate_method_with_new_ids()

	assert(first_copy is FlowMethodDefinition)
	assert(first_copy != original and second_copy != original and second_copy != first_copy)
	assert(first_copy.display_name == "Independent Method")
	assert(not first_copy.enabled)
	assert(first_copy.user_note == "Original method note")
	assert(first_copy.get_internal_id() != original_id)
	assert(second_copy.get_internal_id() != original_id)
	assert(second_copy.get_internal_id() != first_copy.get_internal_id())
	assert(first_copy.parameters.size() == 3 and first_copy.parameters[1] == null)
	assert(first_copy.parameters[0] is FlowMethodParameterDefinition)
	assert(first_copy.parameters[2] is FlowMethodParameterDefinition)
	assert(first_copy.parameters[0] != first_parameter)
	assert(first_copy.parameters[2] != second_parameter)
	assert(first_copy.parameters[0].get_internal_id() != first_parameter_id)
	assert(first_copy.parameters[2].get_internal_id() != second_parameter_id)
	assert(first_copy.parameters[0].value_type == FlowVariableDefinition.ValueType.INT)
	assert(first_copy.parameters[2].value_type == FlowVariableDefinition.ValueType.COLOR)
	assert(first_copy.return_definition is FlowMethodReturnDefinition)
	assert(first_copy.return_definition != return_definition)
	assert(first_copy.return_definition.get_internal_id() != return_id)
	assert(first_copy.return_definition.display_name == "Method Result")
	assert(first_copy.return_definition.value_type == FlowVariableDefinition.ValueType.STRING)
	assert(first_copy.blocks.size() == 5 and first_copy.blocks[0] == null and first_copy.blocks[4] == null)
	assert(first_copy.blocks[1] is FlowMethodCallBlock)
	assert(first_copy.blocks[2] is FlowBlock)
	assert(first_copy.blocks[3] is FlowMethodCallBlock)
	assert(first_copy.blocks[1] != self_call)
	assert(first_copy.blocks[2] != regular_block)
	assert(first_copy.blocks[3] != external_call)
	assert(first_copy.blocks[1].get_internal_id() != self_call_id)
	assert(first_copy.blocks[2].get_internal_id() != regular_block_id)
	assert(first_copy.blocks[3].get_internal_id() != external_call_id)
	assert((first_copy.blocks[1] as FlowMethodCallBlock).method_id == first_copy.get_internal_id())
	assert((first_copy.blocks[3] as FlowMethodCallBlock).method_id == "external_method_id")

	var reserved_ids: Dictionary[String, bool] = {}
	for resource: Resource in [
		original,
		first_parameter,
		second_parameter,
		return_definition,
		self_call,
		regular_block,
		external_call,
	]:
		var resource_id: String = String(resource.get("_internal_id"))
		assert(not resource_id.is_empty())
		assert(not reserved_ids.has(resource_id))
		reserved_ids[resource_id] = true
	for resource: Resource in [
		first_copy,
		first_copy.parameters[0],
		first_copy.parameters[2],
		first_copy.return_definition,
		first_copy.blocks[1],
		first_copy.blocks[2],
		first_copy.blocks[3],
	]:
		var resource_id: String = String(resource.get("_internal_id"))
		assert(not resource_id.is_empty())
		assert(not reserved_ids.has(resource_id))
		reserved_ids[resource_id] = true
	for resource: Resource in [
		second_copy,
		second_copy.parameters[0],
		second_copy.parameters[2],
		second_copy.return_definition,
		second_copy.blocks[1],
		second_copy.blocks[2],
		second_copy.blocks[3],
	]:
		var resource_id: String = String(resource.get("_internal_id"))
		assert(not resource_id.is_empty())
		assert(not reserved_ids.has(resource_id))
		reserved_ids[resource_id] = true

	first_copy.display_name = "Copied Method"
	first_copy.parameters[0].display_name = "Copied Parameter"
	first_copy.return_definition.display_name = "Copied Return"
	first_copy.blocks[2].display_name = "Copied Block"
	(first_copy.blocks[1] as FlowMethodCallBlock).method_id = "changed_copy_reference"
	assert(original.display_name == "Independent Method")
	assert(first_parameter.display_name == "First Parameter")
	assert(return_definition.display_name == "Method Result")
	assert(regular_block.display_name == "Regular Block")
	assert(self_call.method_id == original_id)
	assert(external_call.method_id == "external_method_id")
	assert(original.get_internal_id() == original_id)
	assert(first_parameter.get_internal_id() == first_parameter_id)
	assert(second_parameter.get_internal_id() == second_parameter_id)
	assert(return_definition.get_internal_id() == return_id)
	assert(self_call.get_internal_id() == self_call_id)
	assert(regular_block.get_internal_id() == regular_block_id)
	assert(external_call.get_internal_id() == external_call_id)


func _make_method_return_identity_collision_case(category: String) -> Dictionary:
	var graph: FlowGraph = FlowGraph.new()
	graph.schema_version = FlowGraph.SCHEMA_VERSION_3
	graph.constructor = FlowConstructorDefinition.new()
	var method: FlowMethodDefinition = FlowMethodDefinition.new()
	method.display_name = "Return Collision Owner"
	var return_definition: FlowMethodReturnDefinition = FlowMethodReturnDefinition.new()
	method.return_definition = return_definition
	graph.methods = [method]
	var target: Resource = graph

	match category:
		"graph":
			target = graph
		"constructor":
			target = graph.constructor
		"dependency":
			var dependency: FlowDependencyDefinition = FlowDependencyDefinition.new()
			dependency.display_name = "Collision Dependency"
			graph.constructor.dependencies = [dependency]
			target = dependency
		"block":
			var block: FlowBlock = FlowBlock.new()
			graph.constructor.blocks = [block]
			target = block
		"process":
			var process: FlowProcess = FlowProcess.new()
			graph.processes = [process]
			target = process
		"variable":
			var variable: FlowVariableDefinition = FlowVariableDefinition.new()
			graph.variables = [variable]
			target = variable
		"state_machine":
			var state_machine: FlowStateMachineDefinition = FlowStateMachineDefinition.new()
			graph.state_machines = [state_machine]
			target = state_machine
		"state":
			var state: FlowStateDefinition = FlowStateDefinition.new()
			var state_machine: FlowStateMachineDefinition = FlowStateMachineDefinition.new()
			state_machine.states = [state]
			state_machine.initial_state_id = state.get_internal_id()
			graph.state_machines = [state_machine]
			target = state
		"method":
			target = method
		"parameter":
			var parameter: FlowMethodParameterDefinition = FlowMethodParameterDefinition.new()
			parameter.display_name = "Collision Parameter"
			method.parameters = [parameter]
			target = parameter

	return {
		"graph": graph,
		"return_definition": return_definition,
		"target": target,
	}


func _test_method_return_global_identity_collisions() -> void:
	var categories: Array[String] = [
		"graph",
		"constructor",
		"dependency",
		"block",
		"process",
		"variable",
		"state_machine",
		"state",
		"method",
		"parameter",
	]
	var seen_graph_instances: Dictionary[int, bool] = {}
	var seen_return_instances: Dictionary[int, bool] = {}
	var seen_target_instances: Dictionary[int, bool] = {}
	for category: String in categories:
		var case_data: Dictionary = _make_method_return_identity_collision_case(category)
		var graph: FlowGraph = case_data["graph"] as FlowGraph
		var return_definition: FlowMethodReturnDefinition = case_data["return_definition"] as FlowMethodReturnDefinition
		var target: Resource = case_data["target"] as Resource
		var target_id: String = String(target.get("_internal_id"))
		var original_return_id: String = return_definition.get_internal_id()
		assert(not seen_graph_instances.has(graph.get_instance_id()))
		assert(not seen_return_instances.has(return_definition.get_instance_id()))
		assert(not seen_target_instances.has(target.get_instance_id()))
		seen_graph_instances[graph.get_instance_id()] = true
		seen_return_instances[return_definition.get_instance_id()] = true
		seen_target_instances[target.get_instance_id()] = true
		assert(not target_id.is_empty())
		assert(target_id != original_return_id)
		assert(not FlowGraphValidator.validate(graph).has_errors())

		return_definition._internal_id = target_id
		var first_result: FlowValidationResult = FlowGraphValidator.validate(graph)
		var second_result: FlowValidationResult = FlowGraphValidator.validate(graph)
		_assert_same_diagnostic_sequence(first_result, second_result)
		assert(first_result.diagnostics.size() == 1)
		var diagnostic: FlowDiagnostic = first_result.diagnostics[0]
		assert(diagnostic.code == FlowDiagnostic.CODE_DUPLICATE_INTERNAL_ID)
		assert(diagnostic.element_path == "methods[0].return_definition")
		assert(diagnostic.related_id == target_id)
		assert(return_definition.get_internal_id() == target_id)
		assert(String(target.get("_internal_id")) == target_id)
		assert(graph.methods[0].return_definition == return_definition)


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
	unsupported_schema_graph.schema_version = FlowGraph.SCHEMA_VERSION_3 + 1
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
	assert(original.constructor == null and copy.constructor == null)

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
	assert(schema_2_graph.constructor == null and schema_2_copy.constructor == null)
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

	var schema_1_processes_source: FlowGraph = FlowGraph.new()
	schema_1_processes_source.processes.append(FlowProcess.new())
	var schema_1_processes_result: FlowValidationResult = FlowGraphValidator.validate(
		schema_1_processes_source
	)
	assert(_has_diagnostic(
		schema_1_processes_result,
		FlowDiagnostic.CODE_MIXED_SCHEMA_SOURCES
	))

	var schema_1_variables_source: FlowGraph = FlowGraph.new()
	schema_1_variables_source.variables.append(FlowVariableDefinition.new())
	var schema_1_variables_result: FlowValidationResult = FlowGraphValidator.validate(
		schema_1_variables_source
	)
	assert(_has_diagnostic(
		schema_1_variables_result,
		FlowDiagnostic.CODE_MIXED_SCHEMA_SOURCES
	))

	var schema_1_machines_source: FlowGraph = FlowGraph.new()
	schema_1_machines_source.state_machines.append(FlowStateMachineDefinition.new())
	var schema_1_machines_result: FlowValidationResult = FlowGraphValidator.validate(
		schema_1_machines_source
	)
	assert(_has_diagnostic(
		schema_1_machines_result,
		FlowDiagnostic.CODE_MIXED_SCHEMA_SOURCES
	))

	var schema_1_null_processes_source: FlowGraph = FlowGraph.new()
	schema_1_null_processes_source.processes.append(null)
	var schema_1_null_processes_result: FlowValidationResult = FlowGraphValidator.validate(
		schema_1_null_processes_source
	)
	assert(_has_diagnostic(
		schema_1_null_processes_result,
		FlowDiagnostic.CODE_MIXED_SCHEMA_SOURCES
	))

	var schema_1_null_variables_source: FlowGraph = FlowGraph.new()
	schema_1_null_variables_source.variables.append(null)
	var schema_1_null_variables_result: FlowValidationResult = FlowGraphValidator.validate(
		schema_1_null_variables_source
	)
	assert(_has_diagnostic(
		schema_1_null_variables_result,
		FlowDiagnostic.CODE_MIXED_SCHEMA_SOURCES
	))

	var schema_1_null_machines_source: FlowGraph = FlowGraph.new()
	schema_1_null_machines_source.state_machines.append(null)
	var schema_1_null_machines_result: FlowValidationResult = FlowGraphValidator.validate(
		schema_1_null_machines_source
	)
	assert(_has_diagnostic(
		schema_1_null_machines_result,
		FlowDiagnostic.CODE_MIXED_SCHEMA_SOURCES
	))

	var schema_2_containers_source: FlowGraph = FlowGraph.new()
	schema_2_containers_source.schema_version = FlowGraph.SCHEMA_VERSION_2
	schema_2_containers_source.containers.append(null)
	var schema_2_containers_result: FlowValidationResult = FlowGraphValidator.validate(
		schema_2_containers_source
	)
	assert(_has_diagnostic(
		schema_2_containers_result,
		FlowDiagnostic.CODE_MIXED_SCHEMA_SOURCES
	))
	var schema_1_constructor_source: FlowGraph = FlowGraph.new()
	var schema_1_constructor: FlowConstructorDefinition = FlowConstructorDefinition.new()
	schema_1_constructor_source.constructor = schema_1_constructor
	var schema_1_constructor_graph_id: String = schema_1_constructor_source.get_internal_id()
	var schema_1_constructor_result: FlowValidationResult = FlowGraphValidator.validate(schema_1_constructor_source)
	var schema_1_constructor_diagnostic: FlowDiagnostic = _find_diagnostic(schema_1_constructor_result, FlowDiagnostic.CODE_MIXED_SCHEMA_SOURCES, "graph")
	assert(schema_1_constructor_diagnostic != null)
	assert(schema_1_constructor_source.constructor == schema_1_constructor)
	assert(schema_1_constructor_source.get_internal_id() == schema_1_constructor_graph_id)

	var schema_1_null_methods_source: FlowGraph = FlowGraph.new()
	schema_1_null_methods_source.methods.append(null)
	var schema_1_null_methods_result: FlowValidationResult = FlowGraphValidator.validate(schema_1_null_methods_source)
	var schema_1_null_methods_diagnostic: FlowDiagnostic = _find_diagnostic(schema_1_null_methods_result, FlowDiagnostic.CODE_MIXED_SCHEMA_SOURCES, "graph")
	assert(schema_1_null_methods_diagnostic != null)
	assert(schema_1_null_methods_source.methods.size() == 1)
	assert(schema_1_null_methods_source.methods[0] == null)

	var schema_2_constructor_source: FlowGraph = FlowGraph.new()
	schema_2_constructor_source.schema_version = FlowGraph.SCHEMA_VERSION_2
	var schema_2_constructor: FlowConstructorDefinition = FlowConstructorDefinition.new()
	schema_2_constructor_source.constructor = schema_2_constructor
	var schema_2_constructor_result: FlowValidationResult = FlowGraphValidator.validate(schema_2_constructor_source)
	var schema_2_constructor_diagnostic: FlowDiagnostic = _find_diagnostic(schema_2_constructor_result, FlowDiagnostic.CODE_MIXED_SCHEMA_SOURCES, "graph")
	assert(schema_2_constructor_diagnostic != null)
	assert(schema_2_constructor_source.constructor == schema_2_constructor)
	assert(schema_2_constructor_source.schema_version == FlowGraph.SCHEMA_VERSION_2)

	var schema_2_null_methods_source: FlowGraph = FlowGraph.new()
	schema_2_null_methods_source.schema_version = FlowGraph.SCHEMA_VERSION_2
	schema_2_null_methods_source.methods.append(null)
	var schema_2_null_methods_result: FlowValidationResult = FlowGraphValidator.validate(schema_2_null_methods_source)
	var schema_2_null_methods_diagnostic: FlowDiagnostic = _find_diagnostic(schema_2_null_methods_result, FlowDiagnostic.CODE_MIXED_SCHEMA_SOURCES, "graph")
	assert(schema_2_null_methods_diagnostic != null)
	assert(schema_2_null_methods_source.methods.size() == 1)
	assert(schema_2_null_methods_source.methods[0] == null)
	assert(schema_2_null_methods_source.schema_version == FlowGraph.SCHEMA_VERSION_2)


	var incompatible_migration_process: FlowProcess = schema_1_processes_source.processes[0]
	var incompatible_migration_graph_id: String = schema_1_processes_source.get_internal_id()
	var incompatible_migration_result: FlowGraphMigrationResult = FlowGraphMigrator.migrate_schema_1_to_2(
		schema_1_processes_source
	)
	assert(not incompatible_migration_result.is_successful())
	assert(incompatible_migration_result.migrated_graph == null)
	assert(_has_migration_diagnostic(
		incompatible_migration_result,
		FlowDiagnostic.CODE_MIXED_SCHEMA_SOURCES
	))
	assert(schema_1_processes_source.get_internal_id() == incompatible_migration_graph_id)
	assert(schema_1_processes_source.processes[0] == incompatible_migration_process)
	_assert_same_diagnostic_sequence(
		schema_1_processes_result,
		FlowGraphValidator.validate(schema_1_processes_source)
	)

	var empty_state_machine_graph: FlowGraph = FlowGraph.new()
	empty_state_machine_graph.schema_version = FlowGraph.SCHEMA_VERSION_2
	var empty_state_machine: FlowStateMachineDefinition = FlowStateMachineDefinition.new()
	empty_state_machine_graph.state_machines.append(empty_state_machine)
	var empty_state_machine_result: FlowValidationResult = FlowGraphValidator.validate(
		empty_state_machine_graph
	)
	assert(not empty_state_machine_result.has_errors())

	var valid_initial_state_graph: FlowGraph = FlowGraph.new()
	valid_initial_state_graph.schema_version = FlowGraph.SCHEMA_VERSION_2
	var valid_initial_state_machine: FlowStateMachineDefinition = FlowStateMachineDefinition.new()
	var valid_initial_state: FlowStateDefinition = FlowStateDefinition.new()
	valid_initial_state_machine.states.append(valid_initial_state)
	valid_initial_state_machine.initial_state_id = valid_initial_state.get_internal_id()
	valid_initial_state_graph.state_machines.append(valid_initial_state_machine)
	assert(not FlowGraphValidator.validate(valid_initial_state_graph).has_errors())

	var empty_initial_id_graph: FlowGraph = FlowGraph.new()
	empty_initial_id_graph.schema_version = FlowGraph.SCHEMA_VERSION_2
	var empty_initial_id_machine: FlowStateMachineDefinition = FlowStateMachineDefinition.new()
	empty_initial_id_machine.states.append(FlowStateDefinition.new())
	empty_initial_id_graph.state_machines.append(empty_initial_id_machine)
	var empty_initial_id_result: FlowValidationResult = FlowGraphValidator.validate(empty_initial_id_graph)
	var empty_initial_id_diagnostic: FlowDiagnostic = _find_diagnostic(
		empty_initial_id_result,
		FlowDiagnostic.CODE_MISSING_INITIAL_STATE_REFERENCE,
		"state_machines[0].initial_state_id"
	)
	assert(empty_initial_id_diagnostic != null)
	assert(empty_initial_id_diagnostic.related_id == empty_initial_id_machine.get_internal_id())
	assert(empty_initial_id_machine.initial_state_id == "")

	var missing_initial_id_graph: FlowGraph = FlowGraph.new()
	missing_initial_id_graph.schema_version = FlowGraph.SCHEMA_VERSION_2
	var missing_initial_id_machine: FlowStateMachineDefinition = FlowStateMachineDefinition.new()
	missing_initial_id_machine.states.append(FlowStateDefinition.new())
	missing_initial_id_machine.initial_state_id = "missing_state"
	missing_initial_id_graph.state_machines.append(missing_initial_id_machine)
	var missing_initial_id_result: FlowValidationResult = FlowGraphValidator.validate(missing_initial_id_graph)
	var missing_initial_id_diagnostic: FlowDiagnostic = _find_diagnostic(
		missing_initial_id_result,
		FlowDiagnostic.CODE_INVALID_INITIAL_STATE_REFERENCE,
		"state_machines[0].initial_state_id"
	)
	assert(missing_initial_id_diagnostic != null)
	assert(missing_initial_id_diagnostic.related_id == "missing_state")
	assert(missing_initial_id_machine.initial_state_id == "missing_state")

	var foreign_initial_id_graph: FlowGraph = FlowGraph.new()
	foreign_initial_id_graph.schema_version = FlowGraph.SCHEMA_VERSION_2
	var first_foreign_machine: FlowStateMachineDefinition = FlowStateMachineDefinition.new()
	var first_foreign_state: FlowStateDefinition = FlowStateDefinition.new()
	first_foreign_machine.states.append(first_foreign_state)
	var second_foreign_machine: FlowStateMachineDefinition = FlowStateMachineDefinition.new()
	var second_foreign_state: FlowStateDefinition = FlowStateDefinition.new()
	second_foreign_machine.states.append(second_foreign_state)
	first_foreign_machine.initial_state_id = second_foreign_state.get_internal_id()
	second_foreign_machine.initial_state_id = second_foreign_state.get_internal_id()
	foreign_initial_id_graph.state_machines.append(first_foreign_machine)
	foreign_initial_id_graph.state_machines.append(second_foreign_machine)
	var foreign_initial_id_result: FlowValidationResult = FlowGraphValidator.validate(foreign_initial_id_graph)
	var foreign_initial_id_diagnostic: FlowDiagnostic = _find_diagnostic(
		foreign_initial_id_result,
		FlowDiagnostic.CODE_INVALID_INITIAL_STATE_REFERENCE,
		"state_machines[0].initial_state_id"
	)
	assert(foreign_initial_id_diagnostic != null)
	assert(foreign_initial_id_diagnostic.related_id == second_foreign_state.get_internal_id())
	assert(first_foreign_machine.initial_state_id == second_foreign_state.get_internal_id())

	var empty_machine_reference_graph: FlowGraph = FlowGraph.new()
	empty_machine_reference_graph.schema_version = FlowGraph.SCHEMA_VERSION_2
	var empty_machine_reference: FlowStateMachineDefinition = FlowStateMachineDefinition.new()
	empty_machine_reference.initial_state_id = "missing_state"
	empty_machine_reference_graph.state_machines.append(empty_machine_reference)
	var empty_machine_reference_result: FlowValidationResult = FlowGraphValidator.validate(
		empty_machine_reference_graph
	)
	var empty_machine_reference_diagnostic: FlowDiagnostic = _find_diagnostic(
		empty_machine_reference_result,
		FlowDiagnostic.CODE_INVALID_INITIAL_STATE_REFERENCE,
		"state_machines[0].initial_state_id"
	)
	assert(empty_machine_reference_diagnostic != null)
	assert(empty_machine_reference_diagnostic.related_id == "missing_state")
	assert(empty_machine_reference.initial_state_id == "missing_state")
	_assert_same_diagnostic_sequence(
		empty_machine_reference_result,
		FlowGraphValidator.validate(empty_machine_reference_graph)
	)

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

	var presenter_schema_1_graph: FlowGraph = FlowGraph.new()
	var presenter_schema_1_process: FlowProcess = FlowProcess.new()
	presenter_schema_1_process.display_name = "Presenter Process"
	var presenter_schema_1_state: FlowStateDefinition = FlowStateDefinition.new()
	presenter_schema_1_state.display_name = "Presenter State"
	presenter_schema_1_graph.containers.append(presenter_schema_1_process)
	presenter_schema_1_graph.containers.append(null)
	presenter_schema_1_graph.containers.append(presenter_schema_1_state)
	var presenter_schema_1: Dictionary = FlowGraphInspectorPresenter.present(presenter_schema_1_graph)
	var presenter_schema_1_repeat: Dictionary = FlowGraphInspectorPresenter.present(presenter_schema_1_graph)
	var presenter_schema_1_sections: Array = presenter_schema_1["sections"] as Array
	var presenter_containers: Dictionary = presenter_schema_1_sections[0] as Dictionary
	var presenter_container_entries: Array = presenter_containers["entries"] as Array
	var presenter_first_container: Dictionary = presenter_container_entries[0] as Dictionary
	var presenter_empty_container: Dictionary = presenter_container_entries[1] as Dictionary
	var presenter_last_container: Dictionary = presenter_container_entries[2] as Dictionary
	assert(presenter_schema_1 == presenter_schema_1_repeat)
	assert(presenter_schema_1["schema_version"] == FlowGraph.CURRENT_SCHEMA_VERSION)
	assert(presenter_schema_1["active_source"] == "Containers")
	assert(presenter_schema_1_sections.size() == 1)
	assert(presenter_containers["title"] == "Containers")
	assert(presenter_first_container["index"] == 0)
	assert(presenter_first_container["name"] == "Presenter Process")
	assert(presenter_first_container["type"] == "FlowProcess")
	assert(presenter_first_container["internal_id"] == presenter_schema_1_process.get_internal_id())
	assert(presenter_first_container["is_empty"] == false)
	assert(presenter_empty_container["index"] == 1)
	assert(presenter_empty_container["name"] == "Empty")
	assert(presenter_empty_container["type"] == "Empty")
	assert(presenter_empty_container["internal_id"] == "")
	assert(presenter_empty_container["is_empty"] == true)
	assert(presenter_last_container["index"] == 2)
	assert(presenter_last_container["name"] == "Presenter State")
	assert(presenter_last_container["type"] == "FlowStateDefinition")
	assert(presenter_schema_1_graph.containers[0] == presenter_schema_1_process)
	assert(presenter_schema_1_graph.containers[1] == null)
	assert(presenter_schema_1_graph.containers[2] == presenter_schema_1_state)

	var presenter_schema_2_graph: FlowGraph = FlowGraph.new()
	presenter_schema_2_graph.schema_version = FlowGraph.SCHEMA_VERSION_2
	var presenter_schema_2_process: FlowProcess = FlowProcess.new()
	presenter_schema_2_process.display_name = "Typed Process"
	var presenter_schema_2_variable: FlowVariableDefinition = FlowVariableDefinition.new()
	presenter_schema_2_variable.display_name = "Typed Variable"
	var presenter_schema_2_machine: FlowStateMachineDefinition = FlowStateMachineDefinition.new()
	presenter_schema_2_machine.display_name = "Typed Machine"
	presenter_schema_2_graph.processes.append(presenter_schema_2_process)
	presenter_schema_2_graph.processes.append(null)
	presenter_schema_2_graph.variables.append(null)
	presenter_schema_2_graph.variables.append(presenter_schema_2_variable)
	presenter_schema_2_graph.state_machines.append(presenter_schema_2_machine)
	presenter_schema_2_graph.state_machines.append(null)
	var presenter_schema_2: Dictionary = FlowGraphInspectorPresenter.present(presenter_schema_2_graph)
	var presenter_schema_2_sections: Array = presenter_schema_2["sections"] as Array
	var presenter_processes: Dictionary = presenter_schema_2_sections[0] as Dictionary
	var presenter_variables: Dictionary = presenter_schema_2_sections[1] as Dictionary
	var presenter_machines: Dictionary = presenter_schema_2_sections[2] as Dictionary
	var presenter_process_entries: Array = presenter_processes["entries"] as Array
	var presenter_variable_entries: Array = presenter_variables["entries"] as Array
	var presenter_machine_entries: Array = presenter_machines["entries"] as Array
	assert(presenter_schema_2["schema_version"] == FlowGraph.SCHEMA_VERSION_2)
	assert(presenter_schema_2["active_source"] == "Typed collections")
	assert(presenter_schema_2_sections.size() == 3)
	assert(presenter_processes["title"] == "Processes")
	assert(presenter_variables["title"] == "Variables")
	assert(presenter_machines["title"] == "State Machines")
	assert((presenter_process_entries[0] as Dictionary)["internal_id"] == presenter_schema_2_process.get_internal_id())
	assert((presenter_process_entries[1] as Dictionary)["name"] == "Empty")
	assert((presenter_variable_entries[0] as Dictionary)["is_empty"] == true)
	assert((presenter_variable_entries[1] as Dictionary)["name"] == "Typed Variable")
	assert((presenter_variable_entries[1] as Dictionary)["internal_id"] == presenter_schema_2_variable.get_internal_id())
	assert((presenter_machine_entries[0] as Dictionary)["name"] == "Typed Machine")
	assert((presenter_machine_entries[0] as Dictionary)["internal_id"] == presenter_schema_2_machine.get_internal_id())
	assert((presenter_machine_entries[1] as Dictionary)["name"] == "Empty")
	assert(presenter_schema_2_graph.containers.is_empty())
	assert(presenter_schema_2_graph.processes[0] == presenter_schema_2_process)
	assert(presenter_schema_2_graph.variables[1] == presenter_schema_2_variable)
	assert(presenter_schema_2_graph.state_machines[0] == presenter_schema_2_machine)

	var presenter_invalid_graph: FlowGraph = FlowGraph.new()
	presenter_invalid_graph._internal_id = ""
	var presenter_invalid: Dictionary = FlowGraphInspectorPresenter.present(presenter_invalid_graph)
	var presenter_diagnostics: Array = presenter_invalid["diagnostics"] as Array
	assert(presenter_diagnostics.size() == 1)
	assert((presenter_diagnostics[0] as Dictionary)["code"] == "empty_internal_id")
	assert(presenter_invalid_graph._internal_id == "")

	var schema_3_graph: FlowGraph = FlowGraph.new()
	schema_3_graph.schema_version = FlowGraph.SCHEMA_VERSION_3
	var schema_3_constructor: FlowConstructorDefinition = FlowConstructorDefinition.new()
	schema_3_constructor.display_name = "Constructor Flow"
	schema_3_constructor.enabled = false
	schema_3_constructor.user_note = "Constructor note"
	var schema_3_constructor_block: FlowBlock = FlowBlock.new()
	schema_3_constructor_block.display_name = "Constructor Block"
	schema_3_constructor.blocks = [schema_3_constructor_block, null]
	var dependency_a: FlowDependencyDefinition = FlowDependencyDefinition.new()
	dependency_a.display_name = "Collider"
	var dependency_b: FlowDependencyDefinition = FlowDependencyDefinition.new()
	dependency_b.display_name = "Target"
	schema_3_constructor.dependencies = [dependency_a, null, dependency_b]
	schema_3_graph.constructor = schema_3_constructor
	var schema_3_method: FlowMethodDefinition = FlowMethodDefinition.new()
	schema_3_method.display_name = "Apply Damage"
	var schema_3_parameter: FlowMethodParameterDefinition = FlowMethodParameterDefinition.new()
	schema_3_parameter.display_name = "Amount"
	schema_3_parameter.value_type = FlowVariableDefinition.ValueType.INT
	var schema_3_block: FlowBlock = FlowBlock.new()
	schema_3_block.display_name = "Damage Block"
	schema_3_method.blocks = [schema_3_block, null]
	schema_3_method.parameters = [schema_3_parameter, null]
	schema_3_graph.methods = [schema_3_method, null]
	var schema_3_variable: FlowVariableDefinition = FlowVariableDefinition.new()
	schema_3_variable.value_type = FlowVariableDefinition.ValueType.INT
	schema_3_graph.variables = [schema_3_variable, null]
	var schema_3_validation: FlowValidationResult = FlowGraphValidator.validate(schema_3_graph)
	assert(not schema_3_validation.has_errors())
	var schema_3_graph_id: String = schema_3_graph.get_internal_id()
	var schema_3_constructor_id: String = schema_3_constructor.get_internal_id()
	var schema_3_constructor_block_id: String = schema_3_constructor_block.get_internal_id()
	var dependency_a_id: String = dependency_a.get_internal_id()
	var dependency_b_id: String = dependency_b.get_internal_id()
	var schema_3_method_id: String = schema_3_method.get_internal_id()
	var schema_3_parameter_id: String = schema_3_parameter.get_internal_id()
	var schema_3_block_id: String = schema_3_block.get_internal_id()
	var schema_3_first_validation: FlowValidationResult = FlowGraphValidator.validate(schema_3_graph)
	var schema_3_second_validation: FlowValidationResult = FlowGraphValidator.validate(schema_3_graph)
	_assert_same_diagnostic_sequence(schema_3_first_validation, schema_3_second_validation)
	assert(schema_3_graph.constructor == schema_3_constructor)
	assert(schema_3_constructor is FlowBlockContainer)
	assert(schema_3_constructor.display_name == "Constructor Flow")
	assert(not schema_3_constructor.enabled)
	assert(schema_3_constructor.user_note == "Constructor note")
	assert(schema_3_constructor.blocks.size() == 2)
	assert(schema_3_constructor.blocks[0] == schema_3_constructor_block)
	assert(schema_3_constructor.blocks[1] == null)
	assert(schema_3_graph.constructor.dependencies[1] == null)
	assert(schema_3_graph.methods[1] == null)
	assert(schema_3_method.parameters[1] == null)
	var schema_3_copy: FlowGraph = schema_3_graph.duplicate_with_new_ids()
	assert(schema_3_copy.get_internal_id() != schema_3_graph_id)
	assert(schema_3_copy.constructor != schema_3_constructor)
	assert(schema_3_copy.constructor is FlowConstructorDefinition)
	assert(schema_3_copy.constructor is FlowBlockContainer)
	assert(schema_3_copy.constructor.get_internal_id() != schema_3_constructor_id)
	assert(schema_3_copy.constructor.display_name == "Constructor Flow")
	assert(not schema_3_copy.constructor.enabled)
	assert(schema_3_copy.constructor.user_note == "Constructor note")
	assert(schema_3_copy.constructor.blocks.size() == 2)
	assert(schema_3_copy.constructor.blocks[0] != schema_3_constructor_block)
	assert(schema_3_copy.constructor.blocks[0] is FlowBlock)
	assert(schema_3_copy.constructor.blocks[0].get_internal_id() != schema_3_constructor_block_id)
	assert(schema_3_copy.constructor.blocks[0].display_name == "Constructor Block")
	assert(schema_3_copy.constructor.blocks[1] == null)
	assert(schema_3_copy.constructor.dependencies[0] != dependency_a)
	assert(schema_3_copy.constructor.dependencies[0].get_internal_id() != dependency_a_id)
	assert(schema_3_copy.constructor.dependencies[1] == null)
	assert(schema_3_copy.constructor.dependencies[2] != dependency_b)
	assert(schema_3_copy.constructor.dependencies[2] is FlowDependencyDefinition)
	assert(schema_3_copy.constructor.dependencies[2].get_internal_id() != dependency_b_id)
	assert(schema_3_copy.constructor.dependencies[2].display_name == "Target")
	assert(schema_3_copy.methods[0] != schema_3_method)
	assert(schema_3_copy.methods[0].get_internal_id() != schema_3_method_id)
	assert(schema_3_copy.methods[0].parameters[0] != schema_3_parameter)
	assert(schema_3_copy.methods[0].parameters[0].get_internal_id() != schema_3_parameter_id)
	assert(schema_3_copy.methods[0].blocks[0] != schema_3_block)
	assert(schema_3_copy.methods[0].blocks[0].get_internal_id() != schema_3_block_id)
	assert(schema_3_copy.methods[0].parameters[1] == null and schema_3_copy.methods[1] == null)
	assert(schema_3_graph.get_internal_id() == schema_3_graph_id and dependency_a.get_internal_id() == dependency_a_id)
	schema_3_copy.constructor.display_name = "Copied Constructor"
	schema_3_copy.constructor.blocks[0].display_name = "Copied Block"
	schema_3_copy.constructor.dependencies[0].display_name = "Copied Dependency"
	assert(schema_3_constructor.display_name == "Constructor Flow")
	assert(schema_3_constructor_block.display_name == "Constructor Block")
	assert(dependency_a.display_name == "Collider")
	var schema_3_mixed_sources: FlowGraph = FlowGraph.new()
	schema_3_mixed_sources.schema_version = FlowGraph.SCHEMA_VERSION_3
	schema_3_mixed_sources.constructor = FlowConstructorDefinition.new()
	schema_3_mixed_sources.containers.append(FlowProcess.new())
	assert(_has_diagnostic(FlowGraphValidator.validate(schema_3_mixed_sources), FlowDiagnostic.CODE_MIXED_SCHEMA_SOURCES))
	var schema_3_invalid: FlowGraph = FlowGraph.new()
	schema_3_invalid.schema_version = FlowGraph.SCHEMA_VERSION_3
	schema_3_invalid.constructor = FlowConstructorDefinition.new()
	var invalid_dependency: FlowDependencyDefinition = FlowDependencyDefinition.new()
	invalid_dependency.display_name = " "
	invalid_dependency.required_class_name = &""
	schema_3_invalid.constructor.dependencies = [invalid_dependency, invalid_dependency]
	var invalid_method: FlowMethodDefinition = FlowMethodDefinition.new()
	invalid_method.display_name = ""
	var invalid_parameter: FlowMethodParameterDefinition = FlowMethodParameterDefinition.new()
	invalid_parameter.display_name = " "
	invalid_method.parameters = [invalid_parameter, invalid_parameter]
	schema_3_invalid.methods = [invalid_method]
	var schema_3_invalid_validation: FlowValidationResult = FlowGraphValidator.validate(schema_3_invalid)
	assert(_has_diagnostic(schema_3_invalid_validation, FlowDiagnostic.CODE_EMPTY_DISPLAY_NAME))
	assert(_has_diagnostic(schema_3_invalid_validation, FlowDiagnostic.CODE_EMPTY_REQUIRED_CLASS_NAME))
	assert(_has_diagnostic(schema_3_invalid_validation, FlowDiagnostic.CODE_REPEATED_RESOURCE_INSTANCE))
	assert(invalid_dependency.required_class_name == &"")
	assert(FlowVariableDefinition.ValueType.BOOL == 0 and FlowVariableDefinition.ValueType.COLOR == 6)
	assert(schema_3_variable.value_type == FlowVariableDefinition.ValueType.INT)
	assert(schema_3_parameter.value_type == FlowVariableDefinition.ValueType.INT)
	assert(schema_3_variable.value_type == schema_3_parameter.value_type)
	var value_type_regression_path: String = "res://.godot/flow_value_type_schema_3_regression.tres"
	assert(ResourceSaver.save(schema_3_graph, value_type_regression_path) == OK)
	var loaded_schema_3_graph: FlowGraph = load(value_type_regression_path) as FlowGraph
	assert(loaded_schema_3_graph != null)
	assert(loaded_schema_3_graph.constructor is FlowBlockContainer)
	assert(loaded_schema_3_graph.constructor.display_name == "Constructor Flow")
	assert(not loaded_schema_3_graph.constructor.enabled)
	assert(loaded_schema_3_graph.constructor.user_note == "Constructor note")
	assert(loaded_schema_3_graph.constructor.blocks.size() == 2)
	assert(loaded_schema_3_graph.constructor.blocks[0] is FlowBlock)
	assert(loaded_schema_3_graph.constructor.blocks[0].display_name == "Constructor Block")
	assert(loaded_schema_3_graph.constructor.blocks[1] == null)
	assert(loaded_schema_3_graph.constructor.dependencies.size() == 3)
	assert(loaded_schema_3_graph.constructor.dependencies[0].display_name == "Collider")
	assert(loaded_schema_3_graph.constructor.dependencies[1] == null)
	assert(loaded_schema_3_graph.constructor.dependencies[2].display_name == "Target")
	assert(loaded_schema_3_graph.variables[0].value_type == FlowVariableDefinition.ValueType.INT)
	assert(loaded_schema_3_graph.methods[0].parameters[0].value_type == FlowVariableDefinition.ValueType.INT)
	assert(not FlowGraphValidator.validate(loaded_schema_3_graph).has_errors())
	var loaded_schema_3_copy: FlowGraph = loaded_schema_3_graph.duplicate_with_new_ids()
	assert(loaded_schema_3_copy.variables[0].value_type == FlowVariableDefinition.ValueType.INT)
	assert(loaded_schema_3_copy.methods[0].parameters[0].value_type == FlowVariableDefinition.ValueType.INT)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(value_type_regression_path))

	var duplicate_names_graph: FlowGraph = FlowGraph.new()
	duplicate_names_graph.schema_version = FlowGraph.SCHEMA_VERSION_3
	duplicate_names_graph.constructor = FlowConstructorDefinition.new()
	var first_named_dependency: FlowDependencyDefinition = FlowDependencyDefinition.new()
	var second_named_dependency: FlowDependencyDefinition = FlowDependencyDefinition.new()
	second_named_dependency.display_name = first_named_dependency.display_name
	duplicate_names_graph.constructor.dependencies = [first_named_dependency, second_named_dependency]
	var first_named_method: FlowMethodDefinition = FlowMethodDefinition.new()
	var second_named_method: FlowMethodDefinition = FlowMethodDefinition.new()
	second_named_method.display_name = first_named_method.display_name
	var first_named_parameter: FlowMethodParameterDefinition = FlowMethodParameterDefinition.new()
	var second_named_parameter: FlowMethodParameterDefinition = FlowMethodParameterDefinition.new()
	second_named_parameter.display_name = first_named_parameter.display_name
	first_named_method.parameters = [first_named_parameter, second_named_parameter]
	duplicate_names_graph.methods = [first_named_method, second_named_method]
	assert(_has_diagnostic(FlowGraphValidator.validate(duplicate_names_graph), FlowDiagnostic.CODE_DUPLICATE_DISPLAY_NAME))

	var duplicate_schema_3_id_graph: FlowGraph = FlowGraph.new()
	duplicate_schema_3_id_graph.schema_version = FlowGraph.SCHEMA_VERSION_3
	duplicate_schema_3_id_graph.constructor = FlowConstructorDefinition.new()
	var duplicate_schema_3_dependency: FlowDependencyDefinition = FlowDependencyDefinition.new()
	duplicate_schema_3_dependency._internal_id = duplicate_schema_3_id_graph.get_internal_id()
	duplicate_schema_3_id_graph.constructor.dependencies = [duplicate_schema_3_dependency]
	assert(_has_diagnostic(FlowGraphValidator.validate(duplicate_schema_3_id_graph), FlowDiagnostic.CODE_DUPLICATE_INTERNAL_ID))

	var invalid_constructor_blocks_graph: FlowGraph = FlowGraph.new()
	invalid_constructor_blocks_graph.schema_version = FlowGraph.SCHEMA_VERSION_3
	invalid_constructor_blocks_graph.constructor = FlowConstructorDefinition.new()
	var empty_id_constructor_block: FlowBlock = FlowBlock.new()
	empty_id_constructor_block._internal_id = ""
	var repeated_constructor_block: FlowBlock = FlowBlock.new()
	var duplicate_id_constructor_block: FlowBlock = FlowBlock.new()
	duplicate_id_constructor_block._internal_id = repeated_constructor_block.get_internal_id()
	invalid_constructor_blocks_graph.constructor.blocks = [
		empty_id_constructor_block,
		null,
		repeated_constructor_block,
		repeated_constructor_block,
		duplicate_id_constructor_block,
	]
	var first_invalid_constructor_blocks_result: FlowValidationResult = FlowGraphValidator.validate(
		invalid_constructor_blocks_graph
	)
	var second_invalid_constructor_blocks_result: FlowValidationResult = FlowGraphValidator.validate(
		invalid_constructor_blocks_graph
	)
	_assert_same_diagnostic_sequence(
		first_invalid_constructor_blocks_result,
		second_invalid_constructor_blocks_result
	)
	assert(first_invalid_constructor_blocks_result.diagnostics.size() == 3)
	var empty_constructor_block_diagnostic: FlowDiagnostic = first_invalid_constructor_blocks_result.diagnostics[0]
	var repeated_constructor_block_diagnostic: FlowDiagnostic = first_invalid_constructor_blocks_result.diagnostics[1]
	var duplicate_constructor_block_diagnostic: FlowDiagnostic = first_invalid_constructor_blocks_result.diagnostics[2]
	assert(empty_constructor_block_diagnostic.code == FlowDiagnostic.CODE_EMPTY_INTERNAL_ID)
	assert(empty_constructor_block_diagnostic.element_path == "constructor.blocks[0]")
	assert(empty_constructor_block_diagnostic.related_id == "")
	assert(repeated_constructor_block_diagnostic.code == FlowDiagnostic.CODE_REPEATED_RESOURCE_INSTANCE)
	assert(repeated_constructor_block_diagnostic.element_path == "constructor.blocks[3]")
	assert(repeated_constructor_block_diagnostic.related_id == repeated_constructor_block.get_internal_id())
	assert(duplicate_constructor_block_diagnostic.code == FlowDiagnostic.CODE_DUPLICATE_INTERNAL_ID)
	assert(duplicate_constructor_block_diagnostic.element_path == "constructor.blocks[4]")
	assert(duplicate_constructor_block_diagnostic.related_id == repeated_constructor_block.get_internal_id())

	var invalid_constructor_dependencies_graph: FlowGraph = FlowGraph.new()
	invalid_constructor_dependencies_graph.schema_version = FlowGraph.SCHEMA_VERSION_3
	invalid_constructor_dependencies_graph.constructor = FlowConstructorDefinition.new()
	var invalid_constructor_dependency: FlowDependencyDefinition = FlowDependencyDefinition.new()
	invalid_constructor_dependency.display_name = " "
	invalid_constructor_dependency.required_class_name = &""
	invalid_constructor_dependencies_graph.constructor.dependencies = [null, invalid_constructor_dependency]
	var first_invalid_constructor_dependencies_result: FlowValidationResult = FlowGraphValidator.validate(
		invalid_constructor_dependencies_graph
	)
	var second_invalid_constructor_dependencies_result: FlowValidationResult = FlowGraphValidator.validate(
		invalid_constructor_dependencies_graph
	)
	_assert_same_diagnostic_sequence(
		first_invalid_constructor_dependencies_result,
		second_invalid_constructor_dependencies_result
	)
	assert(first_invalid_constructor_dependencies_result.diagnostics.size() == 2)
	var empty_constructor_dependency_name_diagnostic: FlowDiagnostic = first_invalid_constructor_dependencies_result.diagnostics[0]
	var empty_constructor_dependency_class_diagnostic: FlowDiagnostic = first_invalid_constructor_dependencies_result.diagnostics[1]
	assert(empty_constructor_dependency_name_diagnostic.code == FlowDiagnostic.CODE_EMPTY_DISPLAY_NAME)
	assert(empty_constructor_dependency_name_diagnostic.element_path == "constructor.dependencies[1]")
	assert(empty_constructor_dependency_name_diagnostic.related_id == invalid_constructor_dependency.get_internal_id())
	assert(empty_constructor_dependency_class_diagnostic.code == FlowDiagnostic.CODE_EMPTY_REQUIRED_CLASS_NAME)
	assert(empty_constructor_dependency_class_diagnostic.element_path == "constructor.dependencies[1].required_class_name")
	assert(empty_constructor_dependency_class_diagnostic.related_id == invalid_constructor_dependency.get_internal_id())
	assert(invalid_constructor_dependencies_graph.constructor.dependencies[0] == null)
	assert(invalid_constructor_dependencies_graph.constructor.dependencies[1] == invalid_constructor_dependency)

	var cross_container_block_graph: FlowGraph = FlowGraph.new()
	cross_container_block_graph.schema_version = FlowGraph.SCHEMA_VERSION_3
	cross_container_block_graph.constructor = FlowConstructorDefinition.new()
	var cross_container_block: FlowBlock = FlowBlock.new()
	cross_container_block_graph.constructor.blocks = [cross_container_block, null]
	var cross_container_method: FlowMethodDefinition = FlowMethodDefinition.new()
	cross_container_method.display_name = "Cross Container Method"
	cross_container_method.blocks = [cross_container_block]
	cross_container_block_graph.methods = [cross_container_method]
	var first_cross_container_block_result: FlowValidationResult = FlowGraphValidator.validate(
		cross_container_block_graph
	)
	var second_cross_container_block_result: FlowValidationResult = FlowGraphValidator.validate(
		cross_container_block_graph
	)
	_assert_same_diagnostic_sequence(first_cross_container_block_result, second_cross_container_block_result)
	assert(first_cross_container_block_result.diagnostics.size() == 1)
	var cross_container_block_diagnostic: FlowDiagnostic = first_cross_container_block_result.diagnostics[0]
	assert(cross_container_block_diagnostic.code == FlowDiagnostic.CODE_REPEATED_RESOURCE_INSTANCE)
	assert(cross_container_block_diagnostic.element_path == "methods[0].blocks[0]")
	assert(cross_container_block_diagnostic.related_id == cross_container_block.get_internal_id())
	assert(cross_container_block_graph.constructor.blocks[0] == cross_container_block)
	assert(cross_container_block_graph.constructor.blocks[1] == null)
	assert(cross_container_method.blocks[0] == cross_container_block)

	var schema_2_to_3_source: FlowGraph = FlowGraph.new()
	schema_2_to_3_source.schema_version = FlowGraph.SCHEMA_VERSION_2
	var schema_2_to_3_process: FlowProcess = FlowProcess.new()
	var schema_2_to_3_block: FlowBlock = FlowBlock.new()
	schema_2_to_3_process.blocks = [schema_2_to_3_block, null]
	var schema_2_to_3_global: FlowVariableDefinition = FlowVariableDefinition.new()
	schema_2_to_3_global.scope = FlowVariableDefinition.Scope.GLOBAL
	var schema_2_to_3_local: FlowVariableDefinition = FlowVariableDefinition.new()
	schema_2_to_3_local.owner_container_id = schema_2_to_3_process.get_internal_id()
	schema_2_to_3_local.global_variable_id = schema_2_to_3_global.get_internal_id()
	var schema_2_to_3_machine: FlowStateMachineDefinition = FlowStateMachineDefinition.new()
	var schema_2_to_3_state: FlowStateDefinition = FlowStateDefinition.new()
	var schema_2_to_3_state_block: FlowBlock = FlowBlock.new()
	schema_2_to_3_state.blocks = [null, schema_2_to_3_state_block]
	schema_2_to_3_machine.states = [schema_2_to_3_state, null]
	schema_2_to_3_machine.initial_state_id = schema_2_to_3_state.get_internal_id()
	schema_2_to_3_source.processes = [schema_2_to_3_process, null]
	schema_2_to_3_source.variables = [schema_2_to_3_global, null, schema_2_to_3_local]
	schema_2_to_3_source.state_machines = [null, schema_2_to_3_machine]
	assert(not FlowGraphValidator.validate(schema_2_to_3_source).has_errors())
	var schema_2_to_3_source_id: String = schema_2_to_3_source.get_internal_id()
	var schema_2_to_3_result: FlowGraphMigrationResult = FlowGraphMigrator.migrate_schema_2_to_3(
		schema_2_to_3_source
	)
	assert(schema_2_to_3_result.is_successful())
	assert(schema_2_to_3_result.diagnostics.is_empty())
	var schema_2_to_3_candidate: FlowGraph = schema_2_to_3_result.migrated_graph
	var schema_2_to_3_process_copy: FlowProcess = schema_2_to_3_candidate.processes[0]
	var schema_2_to_3_global_copy: FlowVariableDefinition = schema_2_to_3_candidate.variables[0]
	var schema_2_to_3_local_copy: FlowVariableDefinition = schema_2_to_3_candidate.variables[2]
	var schema_2_to_3_machine_copy: FlowStateMachineDefinition = schema_2_to_3_candidate.state_machines[1]
	var schema_2_to_3_state_copy: FlowStateDefinition = schema_2_to_3_machine_copy.states[0]
	assert(schema_2_to_3_candidate != schema_2_to_3_source)
	assert(schema_2_to_3_candidate.schema_version == FlowGraph.SCHEMA_VERSION_3)
	assert(schema_2_to_3_candidate.get_internal_id() == schema_2_to_3_source_id)
	assert(schema_2_to_3_candidate.containers.is_empty())
	assert(schema_2_to_3_candidate.processes.size() == 2 and schema_2_to_3_candidate.processes[1] == null)
	assert(schema_2_to_3_candidate.variables.size() == 3 and schema_2_to_3_candidate.variables[1] == null)
	assert(schema_2_to_3_candidate.state_machines.size() == 2 and schema_2_to_3_candidate.state_machines[0] == null)
	assert(schema_2_to_3_process_copy != schema_2_to_3_process)
	assert(schema_2_to_3_process_copy.get_internal_id() == schema_2_to_3_process.get_internal_id())
	assert(schema_2_to_3_process_copy.blocks[0] != schema_2_to_3_block and schema_2_to_3_process_copy.blocks[1] == null)
	assert(schema_2_to_3_process_copy.blocks[0].get_internal_id() == schema_2_to_3_block.get_internal_id())
	assert(schema_2_to_3_global_copy != schema_2_to_3_global)
	assert(schema_2_to_3_global_copy.get_internal_id() == schema_2_to_3_global.get_internal_id())
	assert(schema_2_to_3_local_copy != schema_2_to_3_local)
	assert(schema_2_to_3_local_copy.get_internal_id() == schema_2_to_3_local.get_internal_id())
	assert(schema_2_to_3_local_copy.owner_container_id == schema_2_to_3_process.get_internal_id())
	assert(schema_2_to_3_local_copy.global_variable_id == schema_2_to_3_global.get_internal_id())
	assert(schema_2_to_3_machine_copy != schema_2_to_3_machine)
	assert(schema_2_to_3_machine_copy.get_internal_id() == schema_2_to_3_machine.get_internal_id())
	assert(schema_2_to_3_machine_copy.states.size() == 2 and schema_2_to_3_machine_copy.states[1] == null)
	assert(schema_2_to_3_state_copy != schema_2_to_3_state)
	assert(schema_2_to_3_state_copy.get_internal_id() == schema_2_to_3_state.get_internal_id())
	assert(schema_2_to_3_state_copy.blocks[0] == null and schema_2_to_3_state_copy.blocks[1] != schema_2_to_3_state_block)
	assert(schema_2_to_3_state_copy.blocks[1].get_internal_id() == schema_2_to_3_state_block.get_internal_id())
	assert(schema_2_to_3_machine_copy.initial_state_id == schema_2_to_3_state.get_internal_id())
	assert(schema_2_to_3_candidate.constructor != null)
	assert(schema_2_to_3_candidate.constructor is FlowBlockContainer)
	assert(schema_2_to_3_candidate.constructor.get_internal_id().length() == 32)
	assert(schema_2_to_3_candidate.constructor.get_internal_id() != schema_2_to_3_source_id)
	assert(schema_2_to_3_candidate.constructor.blocks.is_empty())
	assert(schema_2_to_3_candidate.constructor.dependencies.is_empty())
	assert(schema_2_to_3_candidate.methods.is_empty())
	assert(not FlowGraphValidator.validate(schema_2_to_3_candidate).has_errors())
	schema_2_to_3_process_copy.display_name = "Candidate Process"
	schema_2_to_3_local_copy.owner_container_id = ""
	assert(schema_2_to_3_process.display_name != "Candidate Process")
	assert(schema_2_to_3_local.owner_container_id == schema_2_to_3_process.get_internal_id())
	assert(schema_2_to_3_source.schema_version == FlowGraph.SCHEMA_VERSION_2)
	assert(schema_2_to_3_source.get_internal_id() == schema_2_to_3_source_id)
	assert(schema_2_to_3_source.constructor == null and schema_2_to_3_source.methods.is_empty())
	assert(not FlowGraphValidator.validate(schema_2_to_3_source).has_errors())

	var schema_2_to_3_null_validation: FlowValidationResult = FlowGraphValidator.validate(null)
	var schema_2_to_3_null_result: FlowGraphMigrationResult = FlowGraphMigrator.migrate_schema_2_to_3(
		null
	)
	assert(schema_2_to_3_null_result.has_errors())
	assert(not schema_2_to_3_null_result.is_successful())
	assert(schema_2_to_3_null_result.migrated_graph == null)
	assert(schema_2_to_3_null_result.diagnostics.size() == schema_2_to_3_null_validation.diagnostics.size())
	for schema_2_to_3_null_diagnostic_index: int in schema_2_to_3_null_validation.diagnostics.size():
		var expected_schema_2_to_3_null_diagnostic: FlowDiagnostic = schema_2_to_3_null_validation.diagnostics[schema_2_to_3_null_diagnostic_index]
		var actual_schema_2_to_3_null_diagnostic: FlowDiagnostic = schema_2_to_3_null_result.diagnostics[schema_2_to_3_null_diagnostic_index]
		assert(actual_schema_2_to_3_null_diagnostic.code == expected_schema_2_to_3_null_diagnostic.code)
		assert(actual_schema_2_to_3_null_diagnostic.element_path == expected_schema_2_to_3_null_diagnostic.element_path)
		assert(actual_schema_2_to_3_null_diagnostic.related_id == expected_schema_2_to_3_null_diagnostic.related_id)
	assert(schema_2_to_3_null_result.diagnostics[0].code == FlowDiagnostic.CODE_NULL_GRAPH)
	assert(schema_2_to_3_null_result.diagnostics[0].element_path == "graph")
	assert(schema_2_to_3_null_result.diagnostics[0].related_id == "")

	var schema_2_to_3_wrong_schema: FlowGraph = FlowGraph.new()
	var schema_2_to_3_wrong_schema_result: FlowGraphMigrationResult = FlowGraphMigrator.migrate_schema_2_to_3(
		schema_2_to_3_wrong_schema
	)
	assert(not schema_2_to_3_wrong_schema_result.is_successful())
	assert(schema_2_to_3_wrong_schema_result.migrated_graph == null)
	assert(schema_2_to_3_wrong_schema_result.diagnostics.size() == 1)
	var schema_2_to_3_wrong_schema_diagnostic: FlowDiagnostic = schema_2_to_3_wrong_schema_result.diagnostics[0]
	assert(schema_2_to_3_wrong_schema_diagnostic.code == FlowDiagnostic.CODE_MIGRATION_SOURCE_SCHEMA)
	assert(schema_2_to_3_wrong_schema_diagnostic.element_path == "graph")
	assert(schema_2_to_3_wrong_schema_diagnostic.related_id == "")

	var schema_2_to_3_mixed_source: FlowGraph = FlowGraph.new()
	schema_2_to_3_mixed_source.schema_version = FlowGraph.SCHEMA_VERSION_2
	var schema_2_to_3_legacy_container: FlowProcess = FlowProcess.new()
	schema_2_to_3_mixed_source.containers = [schema_2_to_3_legacy_container]
	var schema_2_to_3_mixed_first: FlowGraphMigrationResult = FlowGraphMigrator.migrate_schema_2_to_3(
		schema_2_to_3_mixed_source
	)
	var schema_2_to_3_mixed_second: FlowGraphMigrationResult = FlowGraphMigrator.migrate_schema_2_to_3(
		schema_2_to_3_mixed_source
	)
	assert(not schema_2_to_3_mixed_first.is_successful())
	assert(schema_2_to_3_mixed_first.migrated_graph == null)
	assert(schema_2_to_3_mixed_first.diagnostics.size() == schema_2_to_3_mixed_second.diagnostics.size())
	for schema_2_to_3_diagnostic_index: int in schema_2_to_3_mixed_first.diagnostics.size():
		var first_schema_2_to_3_diagnostic: FlowDiagnostic = schema_2_to_3_mixed_first.diagnostics[schema_2_to_3_diagnostic_index]
		var second_schema_2_to_3_diagnostic: FlowDiagnostic = schema_2_to_3_mixed_second.diagnostics[schema_2_to_3_diagnostic_index]
		assert(first_schema_2_to_3_diagnostic.code == second_schema_2_to_3_diagnostic.code)
		assert(first_schema_2_to_3_diagnostic.element_path == second_schema_2_to_3_diagnostic.element_path)
		assert(first_schema_2_to_3_diagnostic.related_id == second_schema_2_to_3_diagnostic.related_id)
	assert(_has_migration_diagnostic(schema_2_to_3_mixed_first, FlowDiagnostic.CODE_MIXED_SCHEMA_SOURCES))
	assert(schema_2_to_3_mixed_source.containers[0] == schema_2_to_3_legacy_container)

	var schema_2_to_3_schema_3_source: FlowGraph = FlowGraph.new()
	schema_2_to_3_schema_3_source.schema_version = FlowGraph.SCHEMA_VERSION_2
	var schema_2_to_3_incompatible_constructor: FlowConstructorDefinition = FlowConstructorDefinition.new()
	schema_2_to_3_schema_3_source.constructor = schema_2_to_3_incompatible_constructor
	var schema_2_to_3_schema_3_result: FlowGraphMigrationResult = FlowGraphMigrator.migrate_schema_2_to_3(
		schema_2_to_3_schema_3_source
	)
	assert(not schema_2_to_3_schema_3_result.is_successful())
	assert(schema_2_to_3_schema_3_result.migrated_graph == null)
	assert(schema_2_to_3_schema_3_result.diagnostics.size() == 1)
	var schema_2_to_3_schema_3_diagnostic: FlowDiagnostic = schema_2_to_3_schema_3_result.diagnostics[0]
	assert(schema_2_to_3_schema_3_diagnostic.code == FlowDiagnostic.CODE_MIXED_SCHEMA_SOURCES)
	assert(schema_2_to_3_schema_3_diagnostic.element_path == "graph")
	assert(schema_2_to_3_schema_3_diagnostic.related_id == "")
	assert(schema_2_to_3_schema_3_source.constructor == schema_2_to_3_incompatible_constructor)

	var schema_2_to_3_invalid_source: FlowGraph = FlowGraph.new()
	schema_2_to_3_invalid_source.schema_version = FlowGraph.SCHEMA_VERSION_2
	schema_2_to_3_invalid_source._internal_id = ""
	var schema_2_to_3_invalid_result: FlowGraphMigrationResult = FlowGraphMigrator.migrate_schema_2_to_3(
		schema_2_to_3_invalid_source
	)
	assert(not schema_2_to_3_invalid_result.is_successful())
	assert(schema_2_to_3_invalid_result.migrated_graph == null)
	assert(schema_2_to_3_invalid_result.diagnostics.size() == 1)
	var schema_2_to_3_invalid_diagnostic: FlowDiagnostic = schema_2_to_3_invalid_result.diagnostics[0]
	assert(schema_2_to_3_invalid_diagnostic.code == FlowDiagnostic.CODE_EMPTY_INTERNAL_ID)
	assert(schema_2_to_3_invalid_diagnostic.element_path == "graph")
	assert(schema_2_to_3_invalid_diagnostic.related_id == "")
	assert(schema_2_to_3_invalid_source._internal_id == "")
	_test_method_call_foundation()
	_test_method_return_definition()
	_test_flow_id_validation()
	_test_isolated_method_invalid_id_duplication()
	_test_isolated_method_duplication()
	_test_method_return_global_identity_collisions()

	print("[Flujo] Model smoke test passed")
	await get_tree().process_frame
	get_tree().quit()
