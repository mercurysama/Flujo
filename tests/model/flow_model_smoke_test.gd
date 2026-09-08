extends Node

const SMOKE_TEMPORARY_RESOURCES: PackedStringArray = [
	"res://.godot/flow_method_call_regression.tres",
	"res://.godot/flow_method_return_regression.tres",
	"res://.godot/flow_value_type_schema_3_regression.tres",
	"res://.godot/typed_variable_schema_2_regression.tres",
	"res://.godot/typed_variable_schema_3_regression.tres",
]

var _failures: Array[String] = []


func _check(condition: bool, context: String = "") -> bool:
	if condition:
		return true
	var stack: Array[Dictionary] = get_stack()
	var location: String = "unknown location"
	if stack.size() > 1:
		var caller: Dictionary = stack[1]
		location = "%s:%s" % [caller.get("source", "unknown"), caller.get("line", 0)]
	var failure: String = "[Flujo] Model smoke check failed at %s%s." % [
		location,
		" (%s)" % context if not context.is_empty() else "",
	]
	_failures.append(failure)
	push_error(failure)
	return false


func _cleanup_smoke_temporary_resources() -> void:
	for resource_path: String in SMOKE_TEMPORARY_RESOURCES:
		var absolute_path: String = ProjectSettings.globalize_path(resource_path)
		if FileAccess.file_exists(absolute_path):
			var removal_result: Error = DirAccess.remove_absolute(absolute_path)
			_check(removal_result == OK)
		_check(not FileAccess.file_exists(absolute_path))


func _finish_smoke_test() -> void:
	_cleanup_smoke_temporary_resources()
	if _failures.is_empty():
		print("[Flujo] Model smoke test passed")
		get_tree().quit(0)
		return
	push_error("[Flujo] Model smoke test failed with %d check failure(s)." % _failures.size())
	get_tree().quit(1)


func _has_diagnostic(result: FlowValidationResult, code: StringName) -> bool:
	if not _check(result != null, "diagnostic result"):
		return false
	for diagnostic: FlowDiagnostic in result.diagnostics:
		if diagnostic.code == code:
			return true

	return false


func _has_migration_diagnostic(result: FlowGraphMigrationResult, code: StringName) -> bool:
	if not _check(result != null, "migration diagnostic result"):
		return false
	for diagnostic: FlowDiagnostic in result.diagnostics:
		if diagnostic.code == code:
			return true

	return false


func _find_diagnostic(
		result: FlowValidationResult,
		code: StringName,
		element_path: String
) -> FlowDiagnostic:
	if not _check(result != null, "diagnostic lookup result"):
		return null
	for diagnostic: FlowDiagnostic in result.diagnostics:
		if diagnostic.code == code and diagnostic.element_path == element_path:
			return diagnostic

	return null


func _diagnostic_at(
		result: FlowValidationResult,
		diagnostic_index: int,
		context: String
) -> FlowDiagnostic:
	if not _check(result != null, "%s result" % context):
		return null
	if not _check(diagnostic_index >= 0, "%s diagnostic index is non-negative" % context):
		return null
	if not _check(
		diagnostic_index < result.diagnostics.size(),
		"%s diagnostic at index %d" % [context, diagnostic_index]
	):
		return null
	var diagnostic: FlowDiagnostic = result.diagnostics[diagnostic_index]
	if not _check(diagnostic is FlowDiagnostic, "%s diagnostic type at index %d" % [context, diagnostic_index]):
		return null
	return diagnostic


func _migration_diagnostic_at(
		result: FlowGraphMigrationResult,
		diagnostic_index: int,
		context: String
) -> FlowDiagnostic:
	if not _check(result != null, "%s result" % context):
		return null
	if not _check(diagnostic_index >= 0, "%s diagnostic index is non-negative" % context):
		return null
	if not _check(
		diagnostic_index < result.diagnostics.size(),
		"%s diagnostic at index %d" % [context, diagnostic_index]
	):
		return null
	var diagnostic: FlowDiagnostic = result.diagnostics[diagnostic_index]
	if not _check(diagnostic is FlowDiagnostic, "%s diagnostic type at index %d" % [context, diagnostic_index]):
		return null
	return diagnostic


func _check_dictionary_keys(
		value: Dictionary,
		required_keys: Array[String],
		context: String
) -> bool:
	for key: String in required_keys:
		if not _check(value.has(key), "%s requires key %s" % [context, key]):
			return false
	return true


func _assert_same_diagnostic_sequence(
		first_result: FlowValidationResult,
		second_result: FlowValidationResult
) -> void:
	if not _check(first_result != null, "first diagnostic sequence result"):
		return
	if not _check(second_result != null, "second diagnostic sequence result"):
		return
	if not _check(
		first_result.diagnostics.size() == second_result.diagnostics.size(),
		"diagnostic sequence length"
	):
		return
	for diagnostic_index: int in first_result.diagnostics.size():
		var first: FlowDiagnostic = first_result.diagnostics[diagnostic_index]
		var second: FlowDiagnostic = second_result.diagnostics[diagnostic_index]
		if not _check(first is FlowDiagnostic, "first diagnostic at index %d" % diagnostic_index):
			return
		if not _check(second is FlowDiagnostic, "second diagnostic at index %d" % diagnostic_index):
			return
		_check(first.code == second.code)
		_check(first.element_path == second.element_path)
		_check(first.related_id == second.related_id)


func _test_typed_variable_metadata_validation() -> void:
	for scope: int in [FlowVariableDefinition.Scope.LOCAL, FlowVariableDefinition.Scope.GLOBAL]:
		_check(FlowVariableDefinition.is_valid_scope(scope))
	for binding: int in [
		FlowVariableDefinition.Binding.OWN_VALUE,
		FlowVariableDefinition.Binding.GLOBAL_REFERENCE,
	]:
		_check(FlowVariableDefinition.is_valid_binding(binding))
	for value_type: int in [
		FlowVariableDefinition.ValueType.BOOL,
		FlowVariableDefinition.ValueType.INT,
		FlowVariableDefinition.ValueType.FLOAT,
		FlowVariableDefinition.ValueType.STRING,
		FlowVariableDefinition.ValueType.VECTOR2,
		FlowVariableDefinition.ValueType.VECTOR3,
		FlowVariableDefinition.ValueType.COLOR,
	]:
		_check(FlowVariableDefinition.is_valid_value_type(value_type))
	_check(not FlowVariableDefinition.is_valid_scope(-1))
	_check(not FlowVariableDefinition.is_valid_scope(2))
	_check(not FlowVariableDefinition.is_valid_binding(-1))
	_check(not FlowVariableDefinition.is_valid_binding(2))
	_check(not FlowVariableDefinition.is_valid_value_type(-1))
	_check(not FlowVariableDefinition.is_valid_value_type(7))

	var valid_schema_2: FlowGraph = FlowGraph.new()
	valid_schema_2.schema_version = FlowGraph.SCHEMA_VERSION_2
	for value_type: int in range(FlowVariableDefinition.ValueType.BOOL, FlowVariableDefinition.ValueType.COLOR + 1):
		var variable: FlowVariableDefinition = FlowVariableDefinition.new()
		variable.scope = FlowVariableDefinition.Scope.GLOBAL if value_type % 2 == 0 else FlowVariableDefinition.Scope.LOCAL
		variable.binding = FlowVariableDefinition.Binding.GLOBAL_REFERENCE if value_type % 2 == 0 else FlowVariableDefinition.Binding.OWN_VALUE
		variable.value_type = value_type
		valid_schema_2.variables.append(variable)
	_check(not FlowGraphValidator.validate(valid_schema_2).has_errors())
	var valid_schema_3: FlowGraph = FlowGraph.new()
	valid_schema_3.schema_version = FlowGraph.SCHEMA_VERSION_3
	valid_schema_3.constructor = FlowConstructorDefinition.new()
	var valid_method: FlowMethodDefinition = FlowMethodDefinition.new()
	valid_method.display_name = "All Value Types"
	for value_type: int in range(FlowVariableDefinition.ValueType.BOOL, FlowVariableDefinition.ValueType.COLOR + 1):
		var parameter: FlowMethodParameterDefinition = FlowMethodParameterDefinition.new()
		parameter.display_name = "Parameter %d" % value_type
		parameter.value_type = value_type
		valid_method.parameters.append(parameter)
	var valid_return: FlowMethodReturnDefinition = FlowMethodReturnDefinition.new()
	valid_return.value_type = FlowVariableDefinition.ValueType.COLOR
	valid_method.return_definition = valid_return
	valid_schema_3.methods = [valid_method]
	_check(not FlowGraphValidator.validate(valid_schema_3).has_errors())

	var invalid_schema_2: FlowGraph = FlowGraph.new()
	invalid_schema_2.schema_version = FlowGraph.SCHEMA_VERSION_2
	var invalid_scope_negative: FlowVariableDefinition = FlowVariableDefinition.new()
	invalid_scope_negative.scope = -1
	var invalid_scope_upper: FlowVariableDefinition = FlowVariableDefinition.new()
	invalid_scope_upper.scope = 2
	var invalid_binding_negative: FlowVariableDefinition = FlowVariableDefinition.new()
	invalid_binding_negative.binding = -1
	var invalid_binding_upper: FlowVariableDefinition = FlowVariableDefinition.new()
	invalid_binding_upper.binding = 2
	var invalid_value_type_negative: FlowVariableDefinition = FlowVariableDefinition.new()
	invalid_value_type_negative.value_type = -1
	var invalid_value_type_upper: FlowVariableDefinition = FlowVariableDefinition.new()
	invalid_value_type_upper.value_type = 7
	invalid_schema_2.variables = [invalid_scope_negative, invalid_scope_upper, invalid_binding_negative, invalid_binding_upper, invalid_value_type_negative, invalid_value_type_upper]
	var schema_2_first: FlowValidationResult = FlowGraphValidator.validate(invalid_schema_2)
	var schema_2_second: FlowValidationResult = FlowGraphValidator.validate(invalid_schema_2)
	_assert_same_diagnostic_sequence(schema_2_first, schema_2_second)
	var schema_2_codes: Array[StringName] = [FlowDiagnostic.CODE_INVALID_VARIABLE_SCOPE, FlowDiagnostic.CODE_INVALID_VARIABLE_SCOPE, FlowDiagnostic.CODE_INVALID_VARIABLE_BINDING, FlowDiagnostic.CODE_INVALID_VARIABLE_BINDING, FlowDiagnostic.CODE_INVALID_VALUE_TYPE, FlowDiagnostic.CODE_INVALID_VALUE_TYPE]
	var schema_2_paths: Array[String] = ["variables[0].scope", "variables[1].scope", "variables[2].binding", "variables[3].binding", "variables[4].value_type", "variables[5].value_type"]
	var schema_2_ids: Array[String] = [invalid_scope_negative.get_internal_id(), invalid_scope_upper.get_internal_id(), invalid_binding_negative.get_internal_id(), invalid_binding_upper.get_internal_id(), invalid_value_type_negative.get_internal_id(), invalid_value_type_upper.get_internal_id()]
	if not _check(schema_2_first.diagnostics.size() == schema_2_codes.size(), "schema 2 typed-metadata diagnostic count"):
		return
	if not _check(schema_2_paths.size() == schema_2_codes.size(), "schema 2 typed-metadata path count"):
		return
	if not _check(schema_2_ids.size() == schema_2_codes.size(), "schema 2 typed-metadata ID count"):
		return
	for diagnostic_index: int in schema_2_codes.size():
		var diagnostic: FlowDiagnostic = _diagnostic_at(
			schema_2_first,
			diagnostic_index,
			"schema 2 typed-metadata"
		)
		if diagnostic == null:
			return
		_check(diagnostic.code == schema_2_codes[diagnostic_index])
		_check(diagnostic.element_path == schema_2_paths[diagnostic_index])
		_check(diagnostic.related_id == schema_2_ids[diagnostic_index])
	_check(invalid_scope_negative.scope == -1)
	_check(invalid_scope_upper.scope == 2)
	_check(invalid_binding_negative.binding == -1)
	_check(invalid_binding_upper.binding == 2)
	_check(invalid_value_type_negative.value_type == -1)
	_check(invalid_value_type_upper.value_type == 7)

	var invalid_schema_3: FlowGraph = FlowGraph.new()
	invalid_schema_3.schema_version = FlowGraph.SCHEMA_VERSION_3
	invalid_schema_3.constructor = FlowConstructorDefinition.new()
	var invalid_schema_3_variable: FlowVariableDefinition = FlowVariableDefinition.new()
	invalid_schema_3_variable.scope = -1
	invalid_schema_3_variable.binding = 2
	invalid_schema_3_variable.value_type = 7
	invalid_schema_3.variables = [invalid_schema_3_variable]
	var invalid_metadata_method: FlowMethodDefinition = FlowMethodDefinition.new()
	invalid_metadata_method.display_name = "Invalid Metadata"
	var invalid_parameter_negative: FlowMethodParameterDefinition = FlowMethodParameterDefinition.new()
	invalid_parameter_negative.display_name = "Negative"
	invalid_parameter_negative.value_type = -1
	var invalid_parameter_upper: FlowMethodParameterDefinition = FlowMethodParameterDefinition.new()
	invalid_parameter_upper.display_name = "Upper"
	invalid_parameter_upper.value_type = 7
	invalid_metadata_method.parameters = [invalid_parameter_negative, null, invalid_parameter_upper]
	var invalid_return: FlowMethodReturnDefinition = FlowMethodReturnDefinition.new()
	invalid_return.value_type = -1
	invalid_metadata_method.return_definition = invalid_return
	var invalid_upper_return_method: FlowMethodDefinition = FlowMethodDefinition.new()
	invalid_upper_return_method.display_name = "Invalid Upper Return"
	var invalid_upper_return: FlowMethodReturnDefinition = FlowMethodReturnDefinition.new()
	invalid_upper_return.value_type = 7
	invalid_upper_return_method.return_definition = invalid_upper_return
	invalid_schema_3.methods = [invalid_metadata_method, invalid_upper_return_method]
	var schema_3_first: FlowValidationResult = FlowGraphValidator.validate(invalid_schema_3)
	var schema_3_second: FlowValidationResult = FlowGraphValidator.validate(invalid_schema_3)
	_assert_same_diagnostic_sequence(schema_3_first, schema_3_second)
	var schema_3_codes: Array[StringName] = [FlowDiagnostic.CODE_INVALID_VARIABLE_SCOPE, FlowDiagnostic.CODE_INVALID_VARIABLE_BINDING, FlowDiagnostic.CODE_INVALID_VALUE_TYPE, FlowDiagnostic.CODE_INVALID_VALUE_TYPE, FlowDiagnostic.CODE_INVALID_VALUE_TYPE, FlowDiagnostic.CODE_INVALID_VALUE_TYPE, FlowDiagnostic.CODE_INVALID_VALUE_TYPE]
	var schema_3_paths: Array[String] = ["variables[0].scope", "variables[0].binding", "variables[0].value_type", "methods[0].parameters[0].value_type", "methods[0].parameters[2].value_type", "methods[0].return_definition.value_type", "methods[1].return_definition.value_type"]
	var schema_3_ids: Array[String] = [invalid_schema_3_variable.get_internal_id(), invalid_schema_3_variable.get_internal_id(), invalid_schema_3_variable.get_internal_id(), invalid_parameter_negative.get_internal_id(), invalid_parameter_upper.get_internal_id(), invalid_return.get_internal_id(), invalid_upper_return.get_internal_id()]
	if not _check(schema_3_first.diagnostics.size() == schema_3_codes.size(), "schema 3 typed-metadata diagnostic count"):
		return
	if not _check(schema_3_paths.size() == schema_3_codes.size(), "schema 3 typed-metadata path count"):
		return
	if not _check(schema_3_ids.size() == schema_3_codes.size(), "schema 3 typed-metadata ID count"):
		return
	for diagnostic_index: int in schema_3_codes.size():
		var diagnostic: FlowDiagnostic = _diagnostic_at(
			schema_3_first,
			diagnostic_index,
			"schema 3 typed-metadata"
		)
		if diagnostic == null:
			return
		_check(diagnostic.code == schema_3_codes[diagnostic_index])
		_check(diagnostic.element_path == schema_3_paths[diagnostic_index])
		_check(diagnostic.related_id == schema_3_ids[diagnostic_index])
	_check(invalid_schema_3_variable.scope == -1)
	_check(invalid_schema_3_variable.binding == 2)
	_check(invalid_schema_3_variable.value_type == 7)
	_check(invalid_parameter_negative.value_type == -1)
	_check(invalid_parameter_upper.value_type == 7)
	_check(invalid_return.value_type == -1)
	_check(invalid_upper_return.value_type == 7)


func _make_typed_variable(value_type: int, suffix: int) -> FlowVariableDefinition:
	var variable: FlowVariableDefinition = FlowVariableDefinition.new()
	variable.display_name = "Typed %d" % value_type
	variable.value_type = value_type
	variable.bool_value = suffix % 2 == 0
	variable.int_value = -41 + suffix * 17
	variable.float_value = 0.375 + suffix * 1.25
	variable.string_value = "typed-value-%d" % suffix
	variable.vector2_value = Vector2(0.5 + suffix, -1.25 - suffix)
	variable.vector3_value = Vector3(-2.0 - suffix, 3.5 + suffix, 4.25 - suffix)
	variable.color_value = Color(0.1 * (suffix + 1), 0.2, 0.3, 0.4 + 0.05 * suffix)
	variable.persistent = suffix % 2 == 1
	variable.user_note = "Typed note %d" % suffix
	return variable


func _assert_typed_variable_values(
		variable: FlowVariableDefinition,
		value_type: int,
		suffix: int
) -> void:
	_check(variable.value_type == value_type)
	_check(variable.display_name == "Typed %d" % value_type)
	_check(variable.bool_value == (suffix % 2 == 0))
	_check(variable.int_value == -41 + suffix * 17)
	_check(is_equal_approx(variable.float_value, 0.375 + suffix * 1.25))
	_check(variable.string_value == "typed-value-%d" % suffix)
	_check(variable.vector2_value == Vector2(0.5 + suffix, -1.25 - suffix))
	_check(variable.vector3_value == Vector3(-2.0 - suffix, 3.5 + suffix, 4.25 - suffix))
	_check(variable.color_value == Color(0.1 * (suffix + 1), 0.2, 0.3, 0.4 + 0.05 * suffix))
	_check(variable.persistent == (suffix % 2 == 1))
	_check(variable.user_note == "Typed note %d" % suffix)


func _assert_all_typed_variables(graph: FlowGraph) -> void:
	var expected_types: Array[int] = [
		FlowVariableDefinition.ValueType.BOOL,
		FlowVariableDefinition.ValueType.INT,
		FlowVariableDefinition.ValueType.FLOAT,
		FlowVariableDefinition.ValueType.STRING,
		FlowVariableDefinition.ValueType.VECTOR2,
		FlowVariableDefinition.ValueType.VECTOR3,
		FlowVariableDefinition.ValueType.COLOR,
	]
	if not _check(graph != null, "typed variable graph"):
		return
	if not _check(graph.variables.size() == 8, "typed variable collection length"):
		return
	_check(graph.variables[1] == null)
	for type_index: int in expected_types.size():
		var variable_index: int = type_index if type_index < 1 else type_index + 1
		var variable: FlowVariableDefinition = graph.variables[variable_index]
		if not _check(variable is FlowVariableDefinition, "typed variable at index %d" % variable_index):
			return
		_assert_typed_variable_values(variable, expected_types[type_index], type_index)


func _test_typed_variable_persistence_and_duplication() -> void:
	var source: FlowGraph = FlowGraph.new()
	source.schema_version = FlowGraph.SCHEMA_VERSION_2
	var owner: FlowProcess = FlowProcess.new()
	owner.display_name = "Typed Owner"
	source.processes = [owner, null]
	var typed_variables: Array[FlowVariableDefinition] = []
	for value_type: int in range(FlowVariableDefinition.ValueType.BOOL, FlowVariableDefinition.ValueType.COLOR + 1):
		var variable: FlowVariableDefinition = _make_typed_variable(value_type, value_type)
		variable.owner_container_id = owner.get_internal_id()
		typed_variables.append(variable)
	typed_variables[0].scope = FlowVariableDefinition.Scope.GLOBAL
	typed_variables[6].binding = FlowVariableDefinition.Binding.GLOBAL_REFERENCE
	typed_variables[6].global_variable_id = typed_variables[0].get_internal_id()
	source.variables = [typed_variables[0], null]
	for variable: FlowVariableDefinition in typed_variables.slice(1):
		source.variables.append(variable)

	_check(FlowVariableDefinition.ValueType.BOOL == 0)
	_check(FlowVariableDefinition.ValueType.INT == 1)
	_check(FlowVariableDefinition.ValueType.FLOAT == 2)
	_check(FlowVariableDefinition.ValueType.STRING == 3)
	_check(FlowVariableDefinition.ValueType.VECTOR2 == 4)
	_check(FlowVariableDefinition.ValueType.VECTOR3 == 5)
	_check(FlowVariableDefinition.ValueType.COLOR == 6)
	_check(not FlowGraphValidator.validate(source).has_errors())
	_assert_all_typed_variables(source)
	var source_owner_id: String = owner.get_internal_id()
	var source_global_id: String = typed_variables[0].get_internal_id()
	var source_color_id: String = typed_variables[6].get_internal_id()

	var copy: FlowGraph = source.duplicate_with_new_ids()
	if not _check(copy != null, "typed-variable duplicate graph"):
		return
	_check(copy != source)
	_check(copy.schema_version == FlowGraph.SCHEMA_VERSION_2)
	if not _check(copy.processes.size() == 2, "typed-variable duplicated process collection length"):
		return
	if not _check(copy.variables.size() == 8, "typed-variable duplicated variable collection length"):
		return
	_check(copy.processes[1] == null)
	_check(copy.variables[1] == null)
	_assert_all_typed_variables(copy)
	if not _check(copy.processes[0] is FlowProcess, "typed-variable duplicated owner process at index 0"):
		return
	var copied_owner: FlowProcess = copy.processes[0]
	_check(copied_owner != owner)
	_check(copied_owner.get_internal_id() != source_owner_id)
	for source_index: int in source.variables.size():
		if source.variables[source_index] == null:
			continue
		if not _check(copy.variables[source_index] is FlowVariableDefinition, "typed-variable duplicate at index %d" % source_index):
			return
		_check(copy.variables[source_index] != source.variables[source_index])
		_check(copy.variables[source_index].get_internal_id() != source.variables[source_index].get_internal_id())
	if not _check(copy.variables[0] is FlowVariableDefinition, "typed-variable duplicate at index 0"):
		return
	if not _check(copy.variables[4] is FlowVariableDefinition, "typed-variable duplicate at index 4"):
		return
	if not _check(copy.variables[7] is FlowVariableDefinition, "typed-variable duplicate at index 7"):
		return
	var copied_global: FlowVariableDefinition = copy.variables[0]
	var copied_string: FlowVariableDefinition = copy.variables[4]
	var copied_color: FlowVariableDefinition = copy.variables[7]
	_check(copy.variables[0].get_internal_id() != source_global_id)
	_check(copy.variables[7].get_internal_id() != source_color_id)
	_check(copied_global.owner_container_id == copied_owner.get_internal_id())
	_check(copied_color.owner_container_id == copied_owner.get_internal_id())
	_check(copied_color.global_variable_id == copied_global.get_internal_id())
	copied_string.string_value = "copy-only"
	copied_string.vector3_value = Vector3.ZERO
	if not _check(source.variables[4] is FlowVariableDefinition, "typed-variable source at index 4"):
		return
	_check(source.variables[4].string_value == "typed-value-3")
	_check(source.variables[4].vector3_value == Vector3(-5.0, 6.5, 1.25))
	_check(source.processes[0].get_internal_id() == source_owner_id)
	_check(source.variables[0].get_internal_id() == source_global_id)
	_check(source.variables[7].get_internal_id() == source_color_id)
	_check(source.variables[7].global_variable_id == source_global_id)

	var invalid_reference_source: FlowGraph = FlowGraph.new()
	invalid_reference_source.schema_version = FlowGraph.SCHEMA_VERSION_2
	var invalid_reference_variable: FlowVariableDefinition = _make_typed_variable(
		FlowVariableDefinition.ValueType.COLOR,
		FlowVariableDefinition.ValueType.COLOR
	)
	invalid_reference_variable.owner_container_id = "missing-owner"
	invalid_reference_variable.global_variable_id = "missing-global"
	invalid_reference_source.variables = [invalid_reference_variable]
	var invalid_reference_copy: FlowGraph = invalid_reference_source.duplicate_with_new_ids()
	if not _check(invalid_reference_copy != null, "invalid-reference duplicated graph"):
		return
	if not _check(invalid_reference_copy.variables.size() == 1, "invalid-reference duplicated variable collection length"):
		return
	if not _check(invalid_reference_copy.variables[0] is FlowVariableDefinition, "invalid-reference duplicated variable at index 0"):
		return
	_check(invalid_reference_copy.variables[0].owner_container_id == "missing-owner")
	_check(invalid_reference_copy.variables[0].global_variable_id == "missing-global")
	_check(invalid_reference_variable.owner_container_id == "missing-owner")
	_check(invalid_reference_variable.global_variable_id == "missing-global")

	var schema_2_path: String = "res://.godot/typed_variable_schema_2_regression.tres"
	if not _check(ResourceSaver.save(source, schema_2_path) == OK):
		return
	var loaded_schema_2: FlowGraph = ResourceLoader.load(
		schema_2_path,
		"",
		ResourceLoader.CACHE_MODE_IGNORE
	) as FlowGraph
	if not _check(loaded_schema_2 != null):
		return
	if not _check(loaded_schema_2.variables.size() == source.variables.size(), "loaded schema-2 typed variable collection length"):
		return
	_check(loaded_schema_2.schema_version == FlowGraph.SCHEMA_VERSION_2)
	_assert_all_typed_variables(loaded_schema_2)
	for source_index: int in source.variables.size():
		if source.variables[source_index] != null:
			if not _check(loaded_schema_2.variables[source_index] is FlowVariableDefinition, "loaded schema-2 typed variable at index %d" % source_index):
				return
			_check(loaded_schema_2.variables[source_index].get_internal_id() == source.variables[source_index].get_internal_id())
	if not _check(loaded_schema_2.variables[0] is FlowVariableDefinition, "loaded schema-2 typed variable at index 0"):
		return
	if not _check(loaded_schema_2.variables[7] is FlowVariableDefinition, "loaded schema-2 typed variable at index 7"):
		return
	_check(loaded_schema_2.variables[7].global_variable_id == loaded_schema_2.variables[0].get_internal_id())

	var migration: FlowGraphMigrationResult = FlowGraphMigrator.migrate_schema_2_to_3(source)
	if not _check(migration != null, "schema 2-to-3 typed-variable migration result"):
		return
	if not _check(migration.is_successful(), "schema 2-to-3 typed-variable migration success"):
		return
	var migrated: FlowGraph = migration.migrated_graph
	if not _check(migrated != null, "schema 2-to-3 typed-variable migration candidate"):
		return
	if not _check(migrated.schema_version == FlowGraph.SCHEMA_VERSION_3):
		return
	if not _check(migrated.constructor is FlowConstructorDefinition, "schema 2-to-3 typed-variable migration constructor"):
		return
	if not _check(migrated.methods.is_empty()):
		return
	if not _check(migrated.variables.size() == source.variables.size(), "schema 2-to-3 typed-variable collection length"):
		return
	_assert_all_typed_variables(migrated)
	for source_index: int in source.variables.size():
		if source.variables[source_index] == null:
			continue
		if not _check(migrated.variables[source_index] is FlowVariableDefinition, "migrated typed variable at index %d" % source_index):
			return
		_check(migrated.variables[source_index] != source.variables[source_index])
		_check(migrated.variables[source_index].get_internal_id() == source.variables[source_index].get_internal_id())
	if not _check(migrated.variables[5] is FlowVariableDefinition, "migrated typed variable at index 5"):
		return
	if not _check(migrated.variables[7] is FlowVariableDefinition, "migrated typed variable at index 7"):
		return
	var migrated_color: FlowVariableDefinition = migrated.variables[5]
	var migrated_reference: FlowVariableDefinition = migrated.variables[7]
	_check(migrated_reference.owner_container_id == source_owner_id)
	_check(migrated_reference.global_variable_id == source_global_id)
	migrated_color.color_value = Color.BLACK
	if not _check(source.variables[5] is FlowVariableDefinition, "typed-variable source at index 5"):
		return
	_check(source.variables[5].color_value == Color(0.5, 0.2, 0.3, 0.6))
	migrated_color.color_value = Color(0.5, 0.2, 0.3, 0.6)

	var schema_3_path: String = "res://.godot/typed_variable_schema_3_regression.tres"
	if not _check(ResourceSaver.save(migrated, schema_3_path) == OK):
		return
	var loaded_schema_3: FlowGraph = ResourceLoader.load(
		schema_3_path,
		"",
		ResourceLoader.CACHE_MODE_IGNORE
	) as FlowGraph
	if not _check(loaded_schema_3 != null):
		return
	if not _check(loaded_schema_3.variables.size() == migrated.variables.size(), "loaded schema-3 typed variable collection length"):
		return
	_check(loaded_schema_3.schema_version == FlowGraph.SCHEMA_VERSION_3)
	_assert_all_typed_variables(loaded_schema_3)
	for migrated_index: int in migrated.variables.size():
		if migrated.variables[migrated_index] != null:
			if not _check(loaded_schema_3.variables[migrated_index] is FlowVariableDefinition, "loaded schema-3 typed variable at index %d" % migrated_index):
				return
			_check(loaded_schema_3.variables[migrated_index].get_internal_id() == migrated.variables[migrated_index].get_internal_id())
	if not _check(loaded_schema_3.variables[0] is FlowVariableDefinition, "loaded schema-3 typed variable at index 0"):
		return
	if not _check(loaded_schema_3.variables[7] is FlowVariableDefinition, "loaded schema-3 typed variable at index 7"):
		return
	_check(loaded_schema_3.variables[7].global_variable_id == loaded_schema_3.variables[0].get_internal_id())
	_check(DirAccess.remove_absolute(ProjectSettings.globalize_path(schema_2_path)) == OK)
	_check(DirAccess.remove_absolute(ProjectSettings.globalize_path(schema_3_path)) == OK)
	_check(not FileAccess.file_exists(ProjectSettings.globalize_path(schema_2_path)))
	_check(not FileAccess.file_exists(ProjectSettings.globalize_path(schema_3_path)))


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
	_check(not validation.has_errors())
	_check(validation.diagnostics.is_empty())
	_check(graph.methods[2] == target_method)
	_check(self_call.method_id == target_method_id)

	var copy: FlowGraph = graph.duplicate_with_new_ids()
	if not _check(copy != null, "duplicated method-call graph"):
		return
	if not _check(copy.constructor is FlowConstructorDefinition, "duplicated method-call constructor"):
		return
	if not _check(copy.processes.size() == 2, "duplicated method-call process collection"):
		return
	if not _check(copy.processes[0] is FlowProcess, "duplicated method-call process at index 0"):
		return
	if not _check(copy.state_machines.size() == 1, "duplicated method-call state-machine collection"):
		return
	if not _check(copy.state_machines[0] is FlowStateMachineDefinition, "duplicated method-call state machine at index 0"):
		return
	if not _check(copy.state_machines[0].states.size() == 2, "duplicated method-call state collection"):
		return
	if not _check(copy.state_machines[0].states[1] is FlowStateDefinition, "duplicated method-call state at index 1"):
		return
	if not _check(copy.methods.size() == 3, "duplicated method-call method collection"):
		return
	if not _check(copy.methods[0] is FlowMethodDefinition, "duplicated method-call caller at index 0"):
		return
	if not _check(copy.methods[2] is FlowMethodDefinition, "duplicated method-call target at index 2"):
		return
	if not _check(copy.constructor.blocks.size() == 2, "duplicated method-call constructor blocks"):
		return
	if not _check(copy.constructor.blocks[0] is FlowMethodCallBlock, "duplicated method-call constructor block at index 0"):
		return
	if not _check(copy.processes[0].blocks.size() == 2, "duplicated method-call process blocks"):
		return
	if not _check(copy.processes[0].blocks[1] is FlowMethodCallBlock, "duplicated method-call process block at index 1"):
		return
	if not _check(copy.state_machines[0].states[1].blocks.size() == 2, "duplicated method-call state blocks"):
		return
	if not _check(copy.state_machines[0].states[1].blocks[0] is FlowMethodCallBlock, "duplicated method-call state block at index 0"):
		return
	if not _check(copy.methods[0].blocks.size() == 2, "duplicated method-call caller blocks"):
		return
	if not _check(copy.methods[0].blocks[0] is FlowMethodCallBlock, "duplicated method-call caller block at index 0"):
		return
	if not _check(copy.methods[2].blocks.size() == 2, "duplicated method-call target blocks"):
		return
	if not _check(copy.methods[2].blocks[1] is FlowMethodCallBlock, "duplicated method-call target block at index 1"):
		return
	var target_method_copy: FlowMethodDefinition = copy.methods[2]
	var constructor_call_copy: FlowMethodCallBlock = copy.constructor.blocks[0]
	var process_call_copy: FlowMethodCallBlock = copy.processes[0].blocks[1]
	var state_call_copy: FlowMethodCallBlock = copy.state_machines[0].states[1].blocks[0]
	var method_call_copy: FlowMethodCallBlock = copy.methods[0].blocks[0]
	var self_call_copy: FlowMethodCallBlock = target_method_copy.blocks[1]
	_check(copy != graph)
	_check(copy.get_internal_id() != graph_id)
	_check(copy.processes[1] == null)
	_check(copy.processes[0].blocks[0] == null)
	_check(copy.state_machines[0].states[0] == null)
	_check(copy.constructor.blocks[1] == null)
	_check(copy.methods[1] == null)
	_check(copy.methods[0].blocks[1] == null)
	_check(target_method_copy.blocks[0] == null)
	for call_copy: FlowMethodCallBlock in [
		constructor_call_copy,
		process_call_copy,
		state_call_copy,
		method_call_copy,
		self_call_copy,
	]:
		_check(call_copy is FlowMethodCallBlock)
		_check(call_copy.method_id == target_method_copy.get_internal_id())
	_check(target_method_copy.get_internal_id() != target_method_id)
	_check(constructor_call_copy != constructor_call and constructor_call_copy.get_internal_id() != constructor_call_id)
	_check(process_call_copy != process_call and process_call_copy.get_internal_id() != process_call_id)
	_check(state_call_copy != state_call and state_call_copy.get_internal_id() != state_call_id)
	_check(method_call_copy != method_call and method_call_copy.get_internal_id() != method_call_id)
	_check(self_call_copy != self_call and self_call_copy.get_internal_id() != self_call_id)
	constructor_call_copy.method_id = caller_method.get_internal_id()
	constructor_call_copy.display_name = "Changed Copy"
	_check(constructor_call.method_id == target_method_id)
	_check(constructor_call.display_name == "Call Method")
	_check(graph.get_internal_id() == graph_id)
	_check(not FlowGraphValidator.validate(graph).has_errors())

	var unknown_graph: FlowGraph = FlowGraph.new()
	unknown_graph.schema_version = FlowGraph.SCHEMA_VERSION_3
	unknown_graph.constructor = FlowConstructorDefinition.new()
	var unknown_call: FlowMethodCallBlock = FlowMethodCallBlock.new()
	unknown_call.method_id = "unknown_method_id"
	unknown_graph.constructor.blocks = [null, unknown_call]
	var unknown_copy: FlowGraph = unknown_graph.duplicate_with_new_ids()
	if not _check(unknown_copy != null, "unknown-reference duplicated graph"):
		return
	if not _check(unknown_copy.constructor is FlowConstructorDefinition, "unknown-reference duplicated constructor"):
		return
	var unknown_constructor_copy: FlowConstructorDefinition = unknown_copy.constructor
	if not _check(unknown_constructor_copy.blocks.size() == 2, "unknown-reference duplicated block collection length"):
		return
	if not _check(unknown_constructor_copy.blocks[1] is FlowMethodCallBlock, "unknown-reference duplicated call block at index 1"):
		return
	var unknown_call_copy: FlowMethodCallBlock = unknown_constructor_copy.blocks[1]
	_check(unknown_constructor_copy.blocks[0] == null)
	_check(unknown_call_copy != unknown_call)
	_check(unknown_call_copy.get_internal_id() != unknown_call.get_internal_id())
	_check(unknown_call_copy.method_id == "unknown_method_id")
	_check(unknown_call.method_id == "unknown_method_id")

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
	if not _check(first_diagnostic_result.diagnostics.size() == 4, "method-call diagnostic count"):
		return
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
	if not _check(expected_codes.size() == first_diagnostic_result.diagnostics.size(), "method-call diagnostic code count"):
		return
	if not _check(expected_paths.size() == first_diagnostic_result.diagnostics.size(), "method-call diagnostic path count"):
		return
	if not _check(expected_related_ids.size() == first_diagnostic_result.diagnostics.size(), "method-call diagnostic ID count"):
		return
	for diagnostic_index: int in first_diagnostic_result.diagnostics.size():
		var diagnostic: FlowDiagnostic = _diagnostic_at(
			first_diagnostic_result,
			diagnostic_index,
			"method-call"
		)
		if diagnostic == null:
			return
		_check(diagnostic.code == expected_codes[diagnostic_index])
		_check(diagnostic.element_path == expected_paths[diagnostic_index])
		_check(diagnostic.related_id == expected_related_ids[diagnostic_index])
	_check(empty_process_call.method_id == "")
	_check(missing_state_call.method_id == "missing_method_id")
	_check(wrong_type_constructor_call.method_id == diagnostic_process.get_internal_id())
	_check(empty_method_call.method_id == "")

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
		if not _check(incompatible_first.diagnostics.size() == 1, "incompatible schema method-call diagnostic count"):
			return
		var incompatible_diagnostic: FlowDiagnostic = _diagnostic_at(
			incompatible_first,
			0,
			"incompatible schema method-call"
		)
		if incompatible_diagnostic == null:
			return
		_check(incompatible_diagnostic.code == FlowDiagnostic.CODE_METHOD_CALL_INCOMPATIBLE_SCHEMA)
		_check(incompatible_diagnostic.element_path == (
			"containers[0].blocks[0]"
			if incompatible_schema == FlowGraph.CURRENT_SCHEMA_VERSION
			else "processes[0].blocks[0]"
		))
		_check(incompatible_diagnostic.related_id == incompatible_call.get_internal_id())
		_check(incompatible_call.method_id == "preserved_incompatible_method")

	var resource_path: String = "res://.godot/flow_method_call_regression.tres"
	if not _check(ResourceSaver.save(graph, resource_path) == OK):
		return
	var loaded_graph: FlowGraph = ResourceLoader.load(
		resource_path,
		"",
		ResourceLoader.CACHE_MODE_IGNORE
	) as FlowGraph
	if not _check(loaded_graph != null):
		return
	if not _check(loaded_graph.constructor is FlowConstructorDefinition, "loaded method-call constructor"):
		return
	var loaded_constructor: FlowConstructorDefinition = loaded_graph.constructor
	if not _check(loaded_constructor.blocks.size() >= 1, "loaded constructor block at index 0"):
		return
	if not _check(loaded_constructor.blocks[0] is FlowMethodCallBlock, "loaded constructor method-call block"):
		return
	if not _check(loaded_graph.methods.size() >= 3, "loaded method collection through index 2"):
		return
	if not _check(loaded_graph.methods[2] is FlowMethodDefinition, "loaded target method at index 2"):
		return
	if not _check(loaded_graph.methods[0] is FlowMethodDefinition, "loaded caller method at index 0"):
		return
	var loaded_constructor_call: FlowMethodCallBlock = loaded_constructor.blocks[0] as FlowMethodCallBlock
	var loaded_target_method: FlowMethodDefinition = loaded_graph.methods[2]
	var loaded_caller_method: FlowMethodDefinition = loaded_graph.methods[0]
	_check(loaded_constructor_call.method_id == loaded_target_method.get_internal_id())
	if not _check(loaded_caller_method.blocks.size() >= 1, "loaded caller block at index 0"):
		return
	_check(loaded_caller_method.blocks[0] is FlowMethodCallBlock)
	_check(not FlowGraphValidator.validate(loaded_graph).has_errors())
	_check(DirAccess.remove_absolute(ProjectSettings.globalize_path(resource_path)) == OK)
	_check(not FileAccess.file_exists(ProjectSettings.globalize_path(resource_path)))


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
	_check(not valid_result.has_errors())
	_check(method_without_return.return_definition == null)
	_check(method_with_return.return_definition == return_definition)
	_check(return_definition.value_type == FlowVariableDefinition.ValueType.VECTOR3)
	_check(return_definition.value_type != FlowVariableDefinition.ValueType.BOOL)

	var copy: FlowGraph = graph.duplicate_with_new_ids()
	if not _check(copy != null, "duplicated method-return graph"):
		return
	if not _check(copy.methods.size() == 3, "duplicated method-return collection length"):
		return
	if not _check(copy.methods[0] is FlowMethodDefinition, "duplicated no-return method at index 0"):
		return
	if not _check(copy.methods[2] is FlowMethodDefinition, "duplicated return method at index 2"):
		return
	var method_copy: FlowMethodDefinition = copy.methods[2]
	_check(copy != graph)
	_check(copy.get_internal_id() != graph_id)
	_check(copy.methods[1] == null)
	_check(copy.methods[0].return_definition == null)
	_check(method_copy is FlowMethodDefinition)
	_check(method_copy.get_internal_id() != method_with_return_id)
	if not _check(method_copy.return_definition is FlowMethodReturnDefinition, "duplicated optional return definition"):
		return
	_check(method_copy.return_definition != return_definition)
	_check(method_copy.return_definition.get_internal_id() != return_id)
	_check(method_copy.return_definition.display_name == "Result")
	_check(method_copy.return_definition.value_type == FlowVariableDefinition.ValueType.VECTOR3)
	method_copy.return_definition.display_name = "Copied Result"
	_check(return_definition.display_name == "Result")
	_check(graph.get_internal_id() == graph_id)
	_check(method_with_return.get_internal_id() == method_with_return_id)
	_check(return_definition.get_internal_id() == return_id)
	_check(not FlowGraphValidator.validate(graph).has_errors())

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
	if not _check(empty_id_first.diagnostics.size() == 1, "empty return-ID diagnostic count"):
		return
	var empty_id_diagnostic: FlowDiagnostic = _diagnostic_at(empty_id_first, 0, "empty return-ID")
	if empty_id_diagnostic == null:
		return
	_check(empty_id_diagnostic.code == FlowDiagnostic.CODE_EMPTY_INTERNAL_ID)
	_check(empty_id_diagnostic.element_path == "methods[0].return_definition")
	_check(empty_id_diagnostic.related_id == "")
	_check(empty_id_method.return_definition == empty_id_return)
	_check(empty_id_return.get_internal_id() == "")

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
	if not _check(duplicate_id_first.diagnostics.size() == 1, "duplicate return-ID diagnostic count"):
		return
	var duplicate_id_diagnostic: FlowDiagnostic = _diagnostic_at(duplicate_id_first, 0, "duplicate return-ID")
	if duplicate_id_diagnostic == null:
		return
	_check(duplicate_id_diagnostic.code == FlowDiagnostic.CODE_DUPLICATE_INTERNAL_ID)
	_check(duplicate_id_diagnostic.element_path == "methods[0].return_definition")
	_check(duplicate_id_diagnostic.related_id == duplicate_id_method.get_internal_id())
	_check(duplicate_id_method.return_definition == duplicate_id_return)

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
	if not _check(repeated_first.diagnostics.size() == 1, "repeated return-instance diagnostic count"):
		return
	var repeated_diagnostic: FlowDiagnostic = _diagnostic_at(repeated_first, 0, "repeated return instance")
	if repeated_diagnostic == null:
		return
	_check(repeated_diagnostic.code == FlowDiagnostic.CODE_REPEATED_RESOURCE_INSTANCE)
	_check(repeated_diagnostic.element_path == "methods[1].return_definition")
	_check(repeated_diagnostic.related_id == repeated_return.get_internal_id())
	_check(first_method.return_definition == repeated_return)
	_check(second_method.return_definition == repeated_return)

	for incompatible_schema: int in [FlowGraph.CURRENT_SCHEMA_VERSION, FlowGraph.SCHEMA_VERSION_2]:
		var incompatible_graph: FlowGraph = FlowGraph.new()
		incompatible_graph.schema_version = incompatible_schema
		var incompatible_method: FlowMethodDefinition = FlowMethodDefinition.new()
		incompatible_method.return_definition = FlowMethodReturnDefinition.new()
		incompatible_graph.methods = [incompatible_method]
		var incompatible_result: FlowValidationResult = FlowGraphValidator.validate(incompatible_graph)
		_check(_has_diagnostic(incompatible_result, FlowDiagnostic.CODE_MIXED_SCHEMA_SOURCES))
		_check(incompatible_method.return_definition is FlowMethodReturnDefinition)

	var migration_source: FlowGraph = FlowGraph.new()
	migration_source.schema_version = FlowGraph.SCHEMA_VERSION_2
	var migration_result: FlowGraphMigrationResult = FlowGraphMigrator.migrate_schema_2_to_3(migration_source)
	if not _check(migration_result != null, "method-return schema 2-to-3 migration result"):
		return
	if not _check(migration_result.is_successful(), "method-return schema 2-to-3 migration success"):
		return
	if not _check(migration_result.migrated_graph != null, "method-return schema 2-to-3 migration candidate"):
		return
	var migrated_graph: FlowGraph = migration_result.migrated_graph
	_check(migrated_graph.methods.is_empty())
	_check(migrated_graph.constructor is FlowConstructorDefinition)
	_check(migration_source.methods.is_empty())

	var resource_path: String = "res://.godot/flow_method_return_regression.tres"
	if not _check(ResourceSaver.save(graph, resource_path) == OK):
		return
	var loaded_graph: FlowGraph = ResourceLoader.load(
		resource_path,
		"",
		ResourceLoader.CACHE_MODE_IGNORE
	) as FlowGraph
	if not _check(loaded_graph != null):
		return
	if not _check(loaded_graph.methods.size() == 3, "loaded method-return collection length"):
		return
	_check(loaded_graph.methods[1] == null)
	if not _check(loaded_graph.methods[0] is FlowMethodDefinition, "loaded no-return method at index 0"):
		return
	if not _check(loaded_graph.methods[2] is FlowMethodDefinition, "loaded return method at index 2"):
		return
	var loaded_method_without_return: FlowMethodDefinition = loaded_graph.methods[0]
	var loaded_method_with_return: FlowMethodDefinition = loaded_graph.methods[2]
	_check(loaded_method_without_return.return_definition == null)
	if not _check(loaded_method_with_return.return_definition is FlowMethodReturnDefinition, "loaded optional return definition"):
		return
	var loaded_return_definition: FlowMethodReturnDefinition = loaded_method_with_return.return_definition
	_check(loaded_return_definition.get_internal_id() == return_id)
	_check(loaded_return_definition.display_name == "Result")
	_check(loaded_return_definition.value_type == FlowVariableDefinition.ValueType.VECTOR3)
	_check(not FlowGraphValidator.validate(loaded_graph).has_errors())
	_check(DirAccess.remove_absolute(ProjectSettings.globalize_path(resource_path)) == OK)
	_check(not FileAccess.file_exists(ProjectSettings.globalize_path(resource_path)))


func _test_flow_id_validation() -> void:
	var generated_id: String = FlowId.create()
	_check(FlowId.is_valid(generated_id))
	_check(not FlowId.is_valid(""))
	_check(not FlowId.is_valid("1234"))
	_check(not FlowId.is_valid("zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz"))

	var malformed_graph: FlowGraph = FlowGraph.new()
	malformed_graph._internal_id = "z"
	var first_result: FlowValidationResult = FlowGraphValidator.validate(malformed_graph)
	var second_result: FlowValidationResult = FlowGraphValidator.validate(malformed_graph)
	_assert_same_diagnostic_sequence(first_result, second_result)
	if not _check(first_result.diagnostics.size() == 2, "malformed graph-ID diagnostic count"):
		return
	var invalid_length_diagnostic: FlowDiagnostic = _diagnostic_at(first_result, 0, "malformed graph-ID length")
	if invalid_length_diagnostic == null:
		return
	var non_hexadecimal_diagnostic: FlowDiagnostic = _diagnostic_at(first_result, 1, "malformed graph-ID hexadecimal")
	if non_hexadecimal_diagnostic == null:
		return
	_check(invalid_length_diagnostic.code == FlowDiagnostic.CODE_INVALID_INTERNAL_ID_LENGTH)
	_check(invalid_length_diagnostic.element_path == "graph")
	_check(invalid_length_diagnostic.related_id == "z")
	_check(non_hexadecimal_diagnostic.code == FlowDiagnostic.CODE_NON_HEXADECIMAL_INTERNAL_ID)
	_check(non_hexadecimal_diagnostic.element_path == "graph")
	_check(non_hexadecimal_diagnostic.related_id == "z")


func _test_isolated_method_invalid_id_duplication() -> void:
	var malformed_method: FlowMethodDefinition = FlowMethodDefinition.new()
	malformed_method._internal_id = "malformed_method_id"
	var malformed_call: FlowMethodCallBlock = FlowMethodCallBlock.new()
	malformed_call.method_id = malformed_method.get_internal_id()
	malformed_method.blocks = [malformed_call]
	var malformed_copy: FlowMethodDefinition = malformed_method.duplicate_method_with_new_ids()
	if not _check(malformed_copy != null, "malformed isolated-method duplicate"):
		return
	if not _check(malformed_copy.blocks.size() == 1, "malformed isolated-method block collection length"):
		return
	if not _check(malformed_copy.blocks[0] is FlowMethodCallBlock, "malformed isolated-method call block at index 0"):
		return
	var malformed_call_copy: FlowMethodCallBlock = malformed_copy.blocks[0]
	_check(malformed_copy.get_internal_id() == "malformed_method_id")
	_check(malformed_call_copy != malformed_call)
	_check(malformed_call_copy.method_id == "malformed_method_id")
	_check(malformed_method.get_internal_id() == "malformed_method_id")
	_check(malformed_call.method_id == "malformed_method_id")
	var malformed_graph: FlowGraph = FlowGraph.new()
	malformed_graph.schema_version = FlowGraph.SCHEMA_VERSION_3
	malformed_graph.constructor = FlowConstructorDefinition.new()
	malformed_graph.methods = [malformed_copy]
	var malformed_first: FlowValidationResult = FlowGraphValidator.validate(malformed_graph)
	var malformed_second: FlowValidationResult = FlowGraphValidator.validate(malformed_graph)
	_assert_same_diagnostic_sequence(malformed_first, malformed_second)
	if not _check(malformed_first.diagnostics.size() == 2, "malformed isolated-method diagnostic count"):
		return
	var malformed_length_diagnostic: FlowDiagnostic = _diagnostic_at(malformed_first, 0, "malformed isolated-method length")
	if malformed_length_diagnostic == null:
		return
	var malformed_hexadecimal_diagnostic: FlowDiagnostic = _diagnostic_at(malformed_first, 1, "malformed isolated-method hexadecimal")
	if malformed_hexadecimal_diagnostic == null:
		return
	_check(malformed_length_diagnostic.code == FlowDiagnostic.CODE_INVALID_INTERNAL_ID_LENGTH)
	_check(malformed_length_diagnostic.element_path == "methods[0]")
	_check(malformed_length_diagnostic.related_id == "malformed_method_id")
	_check(malformed_hexadecimal_diagnostic.code == FlowDiagnostic.CODE_NON_HEXADECIMAL_INTERNAL_ID)
	_check(malformed_hexadecimal_diagnostic.element_path == "methods[0]")
	_check(malformed_hexadecimal_diagnostic.related_id == "malformed_method_id")

	var empty_method: FlowMethodDefinition = FlowMethodDefinition.new()
	empty_method._internal_id = ""
	var empty_call: FlowMethodCallBlock = FlowMethodCallBlock.new()
	empty_call.method_id = ""
	empty_method.blocks = [empty_call]
	var empty_copy: FlowMethodDefinition = empty_method.duplicate_method_with_new_ids()
	if not _check(empty_copy != null, "empty isolated-method duplicate"):
		return
	if not _check(empty_copy.blocks.size() == 1, "empty isolated-method block collection length"):
		return
	if not _check(empty_copy.blocks[0] is FlowMethodCallBlock, "empty isolated-method call block at index 0"):
		return
	var empty_call_copy: FlowMethodCallBlock = empty_copy.blocks[0]
	_check(empty_copy.get_internal_id() == "")
	_check(empty_call_copy.method_id == "")
	_check(empty_call_copy != empty_call)
	_check(empty_method.get_internal_id() == "")
	_check(empty_call.method_id == "")
	var empty_graph: FlowGraph = FlowGraph.new()
	empty_graph.schema_version = FlowGraph.SCHEMA_VERSION_3
	empty_graph.constructor = FlowConstructorDefinition.new()
	empty_graph.methods = [empty_copy]
	var empty_first: FlowValidationResult = FlowGraphValidator.validate(empty_graph)
	var empty_second: FlowValidationResult = FlowGraphValidator.validate(empty_graph)
	_assert_same_diagnostic_sequence(empty_first, empty_second)
	if not _check(empty_first.diagnostics.size() == 2, "empty isolated-method diagnostic count"):
		return
	var empty_method_diagnostic: FlowDiagnostic = _diagnostic_at(empty_first, 0, "empty isolated-method")
	if empty_method_diagnostic == null:
		return
	var empty_reference_diagnostic: FlowDiagnostic = _diagnostic_at(empty_first, 1, "empty isolated-method reference")
	if empty_reference_diagnostic == null:
		return
	_check(empty_method_diagnostic.code == FlowDiagnostic.CODE_EMPTY_INTERNAL_ID)
	_check(empty_method_diagnostic.element_path == "methods[0]")
	_check(empty_reference_diagnostic.code == FlowDiagnostic.CODE_EMPTY_METHOD_REFERENCE)
	_check(empty_reference_diagnostic.element_path == "methods[0].blocks[0].method_id")

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
	if not _check(first_order_copy != null, "first ambiguous isolated-method duplicate"):
		return
	if not _check(second_order_copy != null, "second ambiguous isolated-method duplicate"):
		return
	if not _check(first_order_copy.blocks.size() == 2, "first ambiguous isolated-method block collection length"):
		return
	if not _check(second_order_copy.blocks.size() == 2, "second ambiguous isolated-method block collection length"):
		return
	if not _check(first_order_copy.blocks[0] is FlowMethodCallBlock, "first ambiguous isolated-method call block at index 0"):
		return
	if not _check(first_order_copy.blocks[1] is FlowBlock, "first ambiguous isolated-method block at index 1"):
		return
	if not _check(second_order_copy.blocks[0] is FlowBlock, "second ambiguous isolated-method block at index 0"):
		return
	if not _check(second_order_copy.blocks[1] is FlowMethodCallBlock, "second ambiguous isolated-method call block at index 1"):
		return
	_check(first_order_copy.get_internal_id() == ambiguous_id)
	_check(first_order_copy.blocks[1].get_internal_id() == ambiguous_id)
	_check((first_order_copy.blocks[0] as FlowMethodCallBlock).method_id == ambiguous_id)
	_check(second_order_copy.get_internal_id() == ambiguous_id)
	_check(second_order_copy.blocks[0].get_internal_id() == ambiguous_id)
	_check((second_order_copy.blocks[1] as FlowMethodCallBlock).method_id == ambiguous_id)
	_check(first_order_copy.blocks[0] != first_order_call)
	_check(first_order_copy.blocks[1] != first_order_block)
	_check(second_order_copy.blocks[0] != second_order_block)
	_check(second_order_copy.blocks[1] != second_order_call)
	first_order_copy.blocks[1].display_name = "Copied Ambiguous Block"
	_check(first_order_block.display_name == "Block")
	var ambiguous_graph: FlowGraph = FlowGraph.new()
	ambiguous_graph.schema_version = FlowGraph.SCHEMA_VERSION_3
	ambiguous_graph.constructor = FlowConstructorDefinition.new()
	ambiguous_graph.methods = [first_order_copy]
	var ambiguous_first: FlowValidationResult = FlowGraphValidator.validate(ambiguous_graph)
	var ambiguous_second: FlowValidationResult = FlowGraphValidator.validate(ambiguous_graph)
	_assert_same_diagnostic_sequence(ambiguous_first, ambiguous_second)
	if not _check(ambiguous_first.diagnostics.size() == 1, "ambiguous isolated-method diagnostic count"):
		return
	var ambiguous_diagnostic: FlowDiagnostic = _diagnostic_at(ambiguous_first, 0, "ambiguous isolated-method")
	if ambiguous_diagnostic == null:
		return
	_check(ambiguous_diagnostic.code == FlowDiagnostic.CODE_DUPLICATE_INTERNAL_ID)
	_check(ambiguous_diagnostic.element_path == "methods[0].blocks[1]")
	_check(ambiguous_diagnostic.related_id == ambiguous_id)


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

	if not _check(first_copy != null, "first isolated-method duplicate"):
		return
	if not _check(second_copy != null, "second isolated-method duplicate"):
		return
	if not _check(first_copy.parameters.size() == 3, "isolated-method duplicated parameter collection length"):
		return
	if not _check(first_copy.parameters[0] is FlowMethodParameterDefinition, "isolated-method duplicated parameter at index 0"):
		return
	if not _check(first_copy.parameters[2] is FlowMethodParameterDefinition, "isolated-method duplicated parameter at index 2"):
		return
	if not _check(first_copy.return_definition is FlowMethodReturnDefinition, "isolated-method duplicated return definition"):
		return
	if not _check(first_copy.blocks.size() == 5, "isolated-method duplicated block collection length"):
		return
	if not _check(first_copy.blocks[1] is FlowMethodCallBlock, "isolated-method duplicated self call at index 1"):
		return
	if not _check(first_copy.blocks[2] is FlowBlock, "isolated-method duplicated block at index 2"):
		return
	if not _check(first_copy.blocks[3] is FlowMethodCallBlock, "isolated-method duplicated external call at index 3"):
		return
	_check(first_copy != original and second_copy != original and second_copy != first_copy)
	_check(first_copy.display_name == "Independent Method")
	_check(not first_copy.enabled)
	_check(first_copy.user_note == "Original method note")
	_check(first_copy.get_internal_id() != original_id)
	_check(second_copy.get_internal_id() != original_id)
	_check(second_copy.get_internal_id() != first_copy.get_internal_id())
	_check(first_copy.parameters[1] == null)
	_check(first_copy.parameters[0] != first_parameter)
	_check(first_copy.parameters[2] != second_parameter)
	_check(first_copy.parameters[0].get_internal_id() != first_parameter_id)
	_check(first_copy.parameters[2].get_internal_id() != second_parameter_id)
	_check(first_copy.parameters[0].value_type == FlowVariableDefinition.ValueType.INT)
	_check(first_copy.parameters[2].value_type == FlowVariableDefinition.ValueType.COLOR)
	_check(first_copy.return_definition != return_definition)
	_check(first_copy.return_definition.get_internal_id() != return_id)
	_check(first_copy.return_definition.display_name == "Method Result")
	_check(first_copy.return_definition.value_type == FlowVariableDefinition.ValueType.STRING)
	_check(first_copy.blocks[0] == null)
	_check(first_copy.blocks[4] == null)
	_check(first_copy.blocks[1] != self_call)
	_check(first_copy.blocks[2] != regular_block)
	_check(first_copy.blocks[3] != external_call)
	_check(first_copy.blocks[1].get_internal_id() != self_call_id)
	_check(first_copy.blocks[2].get_internal_id() != regular_block_id)
	_check(first_copy.blocks[3].get_internal_id() != external_call_id)
	_check((first_copy.blocks[1] as FlowMethodCallBlock).method_id == first_copy.get_internal_id())
	_check((first_copy.blocks[3] as FlowMethodCallBlock).method_id == "external_method_id")

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
		_check(not resource_id.is_empty())
		_check(not reserved_ids.has(resource_id))
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
		_check(not resource_id.is_empty())
		_check(not reserved_ids.has(resource_id))
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
		_check(not resource_id.is_empty())
		_check(not reserved_ids.has(resource_id))
		reserved_ids[resource_id] = true

	first_copy.display_name = "Copied Method"
	first_copy.parameters[0].display_name = "Copied Parameter"
	first_copy.return_definition.display_name = "Copied Return"
	first_copy.blocks[2].display_name = "Copied Block"
	(first_copy.blocks[1] as FlowMethodCallBlock).method_id = "changed_copy_reference"
	_check(original.display_name == "Independent Method")
	_check(first_parameter.display_name == "First Parameter")
	_check(return_definition.display_name == "Method Result")
	_check(regular_block.display_name == "Regular Block")
	_check(self_call.method_id == original_id)
	_check(external_call.method_id == "external_method_id")
	_check(original.get_internal_id() == original_id)
	_check(first_parameter.get_internal_id() == first_parameter_id)
	_check(second_parameter.get_internal_id() == second_parameter_id)
	_check(return_definition.get_internal_id() == return_id)
	_check(self_call.get_internal_id() == self_call_id)
	_check(regular_block.get_internal_id() == regular_block_id)
	_check(external_call.get_internal_id() == external_call_id)


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
		if not _check(case_data.has("graph"), "return-ID collision %s graph entry" % category):
			return
		if not _check(case_data.has("return_definition"), "return-ID collision %s return entry" % category):
			return
		if not _check(case_data.has("target"), "return-ID collision %s target entry" % category):
			return
		var graph: FlowGraph = case_data["graph"] as FlowGraph
		var return_definition: FlowMethodReturnDefinition = case_data["return_definition"] as FlowMethodReturnDefinition
		var target: Resource = case_data["target"] as Resource
		if not _check(graph != null, "return-ID collision %s graph type" % category):
			return
		if not _check(return_definition != null, "return-ID collision %s return type" % category):
			return
		if not _check(target != null, "return-ID collision %s target type" % category):
			return
		if not _check(graph.methods.size() >= 1, "return-ID collision %s method collection length" % category):
			return
		if not _check(graph.methods[0] is FlowMethodDefinition, "return-ID collision %s method at index 0" % category):
			return
		var target_id: String = String(target.get("_internal_id"))
		var original_return_id: String = return_definition.get_internal_id()
		_check(not seen_graph_instances.has(graph.get_instance_id()))
		_check(not seen_return_instances.has(return_definition.get_instance_id()))
		_check(not seen_target_instances.has(target.get_instance_id()))
		seen_graph_instances[graph.get_instance_id()] = true
		seen_return_instances[return_definition.get_instance_id()] = true
		seen_target_instances[target.get_instance_id()] = true
		_check(not target_id.is_empty())
		_check(target_id != original_return_id)
		_check(not FlowGraphValidator.validate(graph).has_errors())

		return_definition._internal_id = target_id
		var first_result: FlowValidationResult = FlowGraphValidator.validate(graph)
		var second_result: FlowValidationResult = FlowGraphValidator.validate(graph)
		_assert_same_diagnostic_sequence(first_result, second_result)
		if not _check(first_result.diagnostics.size() == 1, "return-ID collision diagnostic count for %s" % category):
			return
		var diagnostic: FlowDiagnostic = _diagnostic_at(first_result, 0, "return-ID collision for %s" % category)
		if diagnostic == null:
			return
		_check(diagnostic.code == FlowDiagnostic.CODE_DUPLICATE_INTERNAL_ID)
		_check(diagnostic.element_path == "methods[0].return_definition")
		_check(diagnostic.related_id == target_id)
		_check(return_definition.get_internal_id() == target_id)
		_check(String(target.get("_internal_id")) == target_id)
		_check(graph.methods[0].return_definition == return_definition)


func _run_smoke_tests() -> void:

	var null_graph_result: FlowValidationResult = FlowGraphValidator.validate(null)
	_check(null_graph_result.has_errors())
	_check(_has_diagnostic(null_graph_result, FlowDiagnostic.CODE_NULL_GRAPH))

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
	_check(not valid_result.has_errors())
	_check(valid_result.diagnostics.is_empty())
	_check(valid_graph.schema_version == FlowGraph.CURRENT_SCHEMA_VERSION)
	_check(valid_graph.get_internal_id() == valid_graph_id)
	_check(valid_graph.containers.size() == 3)
	_check(valid_graph.containers[0] == valid_process)
	_check(valid_graph.containers[1] == null)
	_check(valid_graph.containers[2] == valid_state)
	_check(valid_process.get_internal_id() == valid_process_id)
	_check(valid_process.blocks.size() == 2)
	_check(valid_process.blocks[0] == valid_block)
	_check(valid_process.blocks[1] == null)
	_check(valid_block.get_internal_id() == valid_block_id)
	_check(valid_state.get_internal_id() == valid_state_id)

	var unsupported_schema_graph: FlowGraph = FlowGraph.new()
	unsupported_schema_graph.schema_version = FlowGraph.SCHEMA_VERSION_3 + 1
	var unsupported_schema_result: FlowValidationResult = FlowGraphValidator.validate(
		unsupported_schema_graph
	)
	_check(unsupported_schema_result.has_errors())
	_check(_has_diagnostic(
		unsupported_schema_result,
		FlowDiagnostic.CODE_UNSUPPORTED_SCHEMA_VERSION
	))

	var empty_id_graph: FlowGraph = FlowGraph.new()
	empty_id_graph._internal_id = ""
	var empty_id_result: FlowValidationResult = FlowGraphValidator.validate(empty_id_graph)
	_check(_has_diagnostic(empty_id_result, FlowDiagnostic.CODE_EMPTY_INTERNAL_ID))

	var short_id_graph: FlowGraph = FlowGraph.new()
	short_id_graph._internal_id = "1234"
	var short_id_result: FlowValidationResult = FlowGraphValidator.validate(short_id_graph)
	_check(_has_diagnostic(short_id_result, FlowDiagnostic.CODE_INVALID_INTERNAL_ID_LENGTH))

	var non_hex_id_graph: FlowGraph = FlowGraph.new()
	non_hex_id_graph._internal_id = "zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz"
	var non_hex_id_result: FlowValidationResult = FlowGraphValidator.validate(non_hex_id_graph)
	_check(_has_diagnostic(non_hex_id_result, FlowDiagnostic.CODE_NON_HEXADECIMAL_INTERNAL_ID))

	var duplicate_id_graph: FlowGraph = FlowGraph.new()
	var duplicate_id_process: FlowProcess = FlowProcess.new()
	duplicate_id_process._internal_id = duplicate_id_graph.get_internal_id()
	duplicate_id_graph.containers.append(duplicate_id_process)
	var duplicate_id_result: FlowValidationResult = FlowGraphValidator.validate(duplicate_id_graph)
	_check(_has_diagnostic(duplicate_id_result, FlowDiagnostic.CODE_DUPLICATE_INTERNAL_ID))
	var duplicate_id_diagnostic: FlowDiagnostic = _find_diagnostic(
		duplicate_id_result,
		FlowDiagnostic.CODE_DUPLICATE_INTERNAL_ID,
		"containers[0]"
	)
	if not _check(duplicate_id_diagnostic != null, "duplicate graph-ID diagnostic"):
		return
	_check(duplicate_id_diagnostic.severity == FlowDiagnostic.Severity.ERROR)
	_check(not duplicate_id_diagnostic.message.is_empty())
	_check(duplicate_id_diagnostic.element_path == "containers[0]")
	_check(duplicate_id_diagnostic.related_id == duplicate_id_graph.get_internal_id())

	var duplicate_block_id_graph: FlowGraph = FlowGraph.new()
	var duplicate_block_id_process: FlowProcess = FlowProcess.new()
	var duplicate_id_block: FlowBlock = FlowBlock.new()
	duplicate_id_block._internal_id = duplicate_block_id_process.get_internal_id()
	duplicate_block_id_process.blocks.append(duplicate_id_block)
	duplicate_block_id_graph.containers.append(duplicate_block_id_process)
	var duplicate_block_id_result: FlowValidationResult = FlowGraphValidator.validate(
		duplicate_block_id_graph
	)
	_check(_has_diagnostic(
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
	_check(_has_diagnostic(
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
	if not _check(repeated_block_diagnostic != null, "repeated block-instance diagnostic"):
		return
	_check(repeated_block_diagnostic.severity == FlowDiagnostic.Severity.ERROR)
	_check(not repeated_block_diagnostic.message.is_empty())
	_check(repeated_block_diagnostic.element_path == "containers[0].blocks[2]")
	_check(repeated_block_diagnostic.related_id == repeated_block_id)
	_check(repeated_block_graph.get_internal_id() == repeated_block_graph_id)
	_check(repeated_block_graph.containers.size() == 1)
	_check(repeated_block_graph.containers[0] == repeated_block_process)
	_check(repeated_block_process.get_internal_id() == repeated_block_process_id)
	_check(repeated_block_process.blocks.size() == 3)
	_check(repeated_block_process.blocks[0] == repeated_block)
	_check(repeated_block_process.blocks[1] == null)
	_check(repeated_block_process.blocks[2] == repeated_block)
	_check(repeated_block.get_internal_id() == repeated_block_id)

	var unmigratable_graph: FlowGraph = FlowGraph.new()
	var unmigratable_container: FlowBlockContainer = FlowBlockContainer.new()
	unmigratable_graph.containers.append(unmigratable_container)
	var unmigratable_result: FlowValidationResult = FlowGraphValidator.validate(
		unmigratable_graph
	)
	_check(_has_diagnostic(
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
	if not _check(copy != null, "schema 1 duplicated graph"):
		return
	if not _check(copy.containers.size() == 3, "schema 1 duplicated container collection length"):
		return
	if not _check(copy.containers[0] is FlowProcess, "schema 1 duplicated process at index 0"):
		return
	if not _check(copy.containers[2] is FlowStateDefinition, "schema 1 duplicated state at index 2"):
		return

	_check(copy != original)
	_check(original.get_internal_id().length() == 32)
	_check(copy.get_internal_id().length() == 32)
	_check(process.get_internal_id().length() == 32)
	_check(block.get_internal_id().length() == 32)
	_check(state.get_internal_id().length() == 32)
	_check(copy.get_internal_id() != original.get_internal_id())
	_check(copy.containers[1] == null)
	_check(original.constructor == null and copy.constructor == null)

	var process_copy: FlowProcess = copy.containers[0] as FlowProcess
	var state_copy: FlowStateDefinition = copy.containers[2] as FlowStateDefinition

	_check(process_copy.get_internal_id().length() == 32)
	_check(state_copy.get_internal_id().length() == 32)
	_check(process_copy.get_internal_id() != process.get_internal_id())
	_check(state_copy.get_internal_id() != state.get_internal_id())
	_check(process_copy.display_name == "Main Process")
	_check(state_copy.display_name == "Idle")
	_check(state_copy.is_initial)
	_check(process_copy.blocks.size() == 1)
	_check(process_copy.blocks[0] != null)
	_check(process_copy.blocks[0].get_internal_id().length() == 32)
	_check(process_copy.blocks[0].get_internal_id() != block.get_internal_id())
	_check(process_copy.blocks[0].display_name == "Print")

	var first_controller: PVController = PVController.new()
	var second_controller: PVController = PVController.new()
	_check(first_controller.flow_graph != second_controller.flow_graph)
	first_controller.free()
	second_controller.free()

	var default_variable: FlowVariableDefinition = FlowVariableDefinition.new()
	_check(default_variable.get_internal_id().length() == 32)
	_check(default_variable.display_name == "Variable")
	_check(default_variable.scope == FlowVariableDefinition.Scope.LOCAL)
	_check(default_variable.binding == FlowVariableDefinition.Binding.OWN_VALUE)
	_check(default_variable.value_type == FlowVariableDefinition.ValueType.BOOL)
	_check(default_variable.bool_value == false)
	_check(default_variable.int_value == 0)
	_check(default_variable.float_value == 0.0)
	_check(default_variable.string_value == "")
	_check(default_variable.vector2_value == Vector2.ZERO)
	_check(default_variable.vector3_value == Vector3.ZERO)
	_check(default_variable.color_value == Color.WHITE)
	_check(default_variable.persistent == false)
	_check(default_variable.global_variable_id == "")
	_check(default_variable.owner_container_id == "")
	_check(default_variable.user_note == "")

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
	_check(global_variable_copy != global_variable)
	_check(global_variable_copy.get_internal_id().length() == 32)
	_check(global_variable_copy.get_internal_id() != global_variable_id)
	_check(global_variable.get_internal_id() == global_variable_id)
	_check(global_variable_copy.display_name == "Player Position")
	_check(global_variable_copy.scope == FlowVariableDefinition.Scope.GLOBAL)
	_check(global_variable_copy.binding == FlowVariableDefinition.Binding.OWN_VALUE)
	_check(global_variable_copy.value_type == FlowVariableDefinition.ValueType.VECTOR3)
	_check(global_variable_copy.vector3_value == Vector3(1.0, 2.0, 3.0))
	_check(global_variable_copy.persistent == true)
	_check(global_variable_copy.user_note == "Tracks the player position.")

	var global_reference: FlowVariableDefinition = FlowVariableDefinition.new()
	global_reference.scope = FlowVariableDefinition.Scope.LOCAL
	global_reference.binding = FlowVariableDefinition.Binding.GLOBAL_REFERENCE
	global_reference.value_type = FlowVariableDefinition.ValueType.VECTOR3
	global_reference.global_variable_id = global_variable_id
	global_reference.owner_container_id = process.get_internal_id()
	_check(global_reference.persistent == false)

	var global_reference_id: String = global_reference.get_internal_id()
	var global_reference_copy: FlowVariableDefinition = global_reference.duplicate_with_new_id()
	_check(global_reference_copy != global_reference)
	_check(global_reference_copy.get_internal_id().length() == 32)
	_check(global_reference_copy.get_internal_id() != global_reference_id)
	_check(global_reference_copy.global_variable_id == global_variable_id)
	_check(global_reference_copy.owner_container_id == process.get_internal_id())
	_check(global_reference_copy.scope == FlowVariableDefinition.Scope.LOCAL)
	_check(global_reference_copy.binding == FlowVariableDefinition.Binding.GLOBAL_REFERENCE)
	_check(global_reference_copy.value_type == FlowVariableDefinition.ValueType.VECTOR3)
	_check(global_reference_copy.persistent == false)
	_check(global_reference.get_internal_id() == global_reference_id)
	_check(global_reference.global_variable_id == global_variable_id)
	_check(global_reference.owner_container_id == process.get_internal_id())
	_check(global_reference.scope == FlowVariableDefinition.Scope.LOCAL)
	_check(global_reference.binding == FlowVariableDefinition.Binding.GLOBAL_REFERENCE)
	_check(global_reference.value_type == FlowVariableDefinition.ValueType.VECTOR3)
	_check(global_reference.persistent == false)

	var state_machine: FlowStateMachineDefinition = FlowStateMachineDefinition.new()
	var state_machine_id: String = state_machine.get_internal_id()
	_check(state_machine_id.length() == 32)
	_check(state_machine.display_name == "State Machine")
	_check(state_machine.enabled == true)
	_check(state_machine.user_note == "")
	_check(state_machine.states.is_empty())
	_check(state_machine.initial_state_id == "")
	_check(state_machine.get_initial_state() == null)

	state_machine.add_state(null)
	_check(state_machine.states.size() == 1)
	_check(state_machine.states[0] == null)
	_check(state_machine.initial_state_id == "")
	_check(state_machine.get_initial_state() == null)

	var idle_state: FlowStateDefinition = FlowStateDefinition.new()
	idle_state.display_name = "Idle"
	var idle_state_id: String = idle_state.get_internal_id()
	var idle_is_initial: bool = idle_state.is_initial
	state_machine.add_state(idle_state)
	_check(state_machine.states.size() == 2)
	_check(state_machine.states[1] == idle_state)
	_check(state_machine.initial_state_id == idle_state_id)
	_check(state_machine.get_initial_state() == idle_state)

	var run_state: FlowStateDefinition = FlowStateDefinition.new()
	run_state.display_name = "Run"
	var run_state_id: String = run_state.get_internal_id()
	var run_is_initial: bool = run_state.is_initial
	state_machine.add_state(run_state)
	_check(state_machine.states.size() == 3)
	_check(state_machine.states[2] == run_state)
	_check(state_machine.initial_state_id == idle_state_id)
	_check(state_machine.get_initial_state() == idle_state)

	_check(state_machine.set_initial_state_by_id("") == false)
	_check(state_machine.initial_state_id == idle_state_id)
	_check(state_machine.set_initial_state_by_id("missing_state") == false)
	_check(state_machine.initial_state_id == idle_state_id)
	_check(state_machine.set_initial_state_by_id(run_state_id) == true)
	_check(state_machine.initial_state_id == run_state_id)
	_check(state_machine.get_initial_state() == run_state)
	_check(idle_state.is_initial == idle_is_initial)
	_check(run_state.is_initial == run_is_initial)

	state_machine.display_name = "Movement"
	state_machine.enabled = false
	state_machine.user_note = "Controls movement states."

	var state_machine_copy: FlowStateMachineDefinition = state_machine.duplicate_with_new_ids()
	if not _check(state_machine_copy != null, "state-machine duplicate"):
		return
	if not _check(state_machine_copy.states.size() == 3, "state-machine duplicated state collection length"):
		return
	if not _check(state_machine_copy.states[1] is FlowStateDefinition, "state-machine duplicated idle state at index 1"):
		return
	if not _check(state_machine_copy.states[2] is FlowStateDefinition, "state-machine duplicated run state at index 2"):
		return
	var idle_state_copy: FlowStateDefinition = state_machine_copy.states[1] as FlowStateDefinition
	var run_state_copy: FlowStateDefinition = state_machine_copy.states[2] as FlowStateDefinition
	_check(state_machine_copy != state_machine)
	_check(state_machine_copy.get_internal_id().length() == 32)
	_check(state_machine_copy.get_internal_id() != state_machine_id)
	_check(state_machine.get_internal_id() == state_machine_id)
	_check(state_machine_copy.display_name == "Movement")
	_check(state_machine_copy.enabled == false)
	_check(state_machine_copy.user_note == "Controls movement states.")
	_check(state_machine_copy.states[0] == null)
	_check(idle_state_copy != idle_state)
	_check(run_state_copy != run_state)
	_check(idle_state_copy.get_internal_id().length() == 32)
	_check(run_state_copy.get_internal_id().length() == 32)
	_check(idle_state_copy.get_internal_id() != idle_state_id)
	_check(run_state_copy.get_internal_id() != run_state_id)
	_check(idle_state_copy.display_name == "Idle")
	_check(run_state_copy.display_name == "Run")
	_check(state_machine_copy.initial_state_id == run_state_copy.get_internal_id())
	_check(state_machine_copy.get_initial_state() == run_state_copy)
	_check(state_machine.display_name == "Movement")
	_check(state_machine.enabled == false)
	_check(state_machine.user_note == "Controls movement states.")
	_check(state_machine.states.size() == 3)
	_check(state_machine.states[0] == null)
	_check(state_machine.states[1] == idle_state)
	_check(state_machine.states[2] == run_state)
	_check(state_machine.initial_state_id == run_state_id)
	_check(state_machine.get_initial_state() == run_state)
	_check(idle_state.get_internal_id() == idle_state_id)
	_check(run_state.get_internal_id() == run_state_id)
	_check(idle_state.is_initial == idle_is_initial)
	_check(run_state.is_initial == run_is_initial)

	var state_machine_without_initial: FlowStateMachineDefinition = FlowStateMachineDefinition.new()
	var unassigned_state: FlowStateDefinition = FlowStateDefinition.new()
	state_machine_without_initial.states.append(unassigned_state)
	_check(state_machine_without_initial.initial_state_id == "")
	var state_machine_without_initial_copy: FlowStateMachineDefinition = state_machine_without_initial.duplicate_with_new_ids()
	if not _check(state_machine_without_initial_copy != null, "state-machine without-initial duplicate"):
		return
	if not _check(state_machine_without_initial_copy.states.size() == 1, "state-machine without-initial state collection length"):
		return
	if not _check(state_machine_without_initial_copy.states[0] is FlowStateDefinition, "state-machine without-initial state at index 0"):
		return
	var unassigned_state_copy: FlowStateDefinition = state_machine_without_initial_copy.states[0] as FlowStateDefinition
	_check(state_machine_without_initial_copy.initial_state_id == unassigned_state_copy.get_internal_id())
	_check(state_machine_without_initial_copy.get_initial_state() == unassigned_state_copy)

	var state_machine_with_invalid_initial: FlowStateMachineDefinition = FlowStateMachineDefinition.new()
	var invalid_initial_state: FlowStateDefinition = FlowStateDefinition.new()
	state_machine_with_invalid_initial.states.append(invalid_initial_state)
	state_machine_with_invalid_initial.initial_state_id = "missing_state"
	var state_machine_with_invalid_initial_copy: FlowStateMachineDefinition = state_machine_with_invalid_initial.duplicate_with_new_ids()
	if not _check(state_machine_with_invalid_initial_copy != null, "state-machine invalid-initial duplicate"):
		return
	_check(state_machine_with_invalid_initial_copy.initial_state_id == "")
	_check(state_machine_with_invalid_initial_copy.get_initial_state() == null)

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
	_check(not schema_2_result.has_errors())
	_check(schema_2_result.diagnostics.is_empty())
	_check(schema_2_graph.containers.is_empty())
	_check(schema_2_graph.processes.size() == 2)
	_check(schema_2_graph.processes[1] == null)
	_check(schema_2_graph.variables.size() == 3)
	_check(schema_2_graph.variables[1] == null)
	_check(schema_2_graph.state_machines.size() == 2)
	_check(schema_2_graph.state_machines[1] == null)

	var schema_2_graph_id: String = schema_2_graph.get_internal_id()
	var schema_2_process_id: String = schema_2_process.get_internal_id()
	var schema_2_block_id: String = schema_2_block.get_internal_id()
	var schema_2_global_id: String = schema_2_global.get_internal_id()
	var schema_2_local_id: String = schema_2_local.get_internal_id()
	var schema_2_machine_id: String = schema_2_machine.get_internal_id()
	var schema_2_state_id: String = schema_2_state.get_internal_id()
	var schema_2_state_block_id: String = schema_2_state_block.get_internal_id()
	var schema_2_copy: FlowGraph = schema_2_graph.duplicate_with_new_ids()
	if not _check(schema_2_copy != null, "schema 2 duplicated graph"):
		return
	if not _check(schema_2_copy.processes.size() == 2, "schema 2 duplicated process collection length"):
		return
	if not _check(schema_2_copy.variables.size() == 3, "schema 2 duplicated variable collection length"):
		return
	if not _check(schema_2_copy.state_machines.size() == 2, "schema 2 duplicated state-machine collection length"):
		return
	if not _check(schema_2_copy.processes[0] is FlowProcess, "schema 2 duplicated process at index 0"):
		return
	if not _check(schema_2_copy.variables[0] is FlowVariableDefinition, "schema 2 duplicated global variable at index 0"):
		return
	if not _check(schema_2_copy.variables[2] is FlowVariableDefinition, "schema 2 duplicated local variable at index 2"):
		return
	if not _check(schema_2_copy.state_machines[0] is FlowStateMachineDefinition, "schema 2 duplicated state machine at index 0"):
		return
	var schema_2_process_copy: FlowProcess = schema_2_copy.processes[0] as FlowProcess
	var schema_2_global_copy: FlowVariableDefinition = schema_2_copy.variables[0] as FlowVariableDefinition
	var schema_2_local_copy: FlowVariableDefinition = schema_2_copy.variables[2] as FlowVariableDefinition
	var schema_2_machine_copy: FlowStateMachineDefinition = schema_2_copy.state_machines[0] as FlowStateMachineDefinition
	if not _check(schema_2_machine_copy.states.size() == 2, "schema 2 duplicated state collection length"):
		return
	if not _check(schema_2_machine_copy.states[1] is FlowStateDefinition, "schema 2 duplicated state at index 1"):
		return
	var schema_2_state_copy: FlowStateDefinition = schema_2_machine_copy.states[1] as FlowStateDefinition

	_check(schema_2_copy != schema_2_graph)
	_check(schema_2_copy.get_internal_id().length() == 32)
	_check(schema_2_copy.get_internal_id() != schema_2_graph_id)
	_check(schema_2_copy.schema_version == FlowGraph.SCHEMA_VERSION_2)
	_check(schema_2_copy.containers.is_empty())
	_check(schema_2_graph.constructor == null and schema_2_copy.constructor == null)
	_check(schema_2_copy.processes.size() == 2)
	_check(schema_2_copy.processes[1] == null)
	_check(schema_2_copy.variables.size() == 3)
	_check(schema_2_copy.variables[1] == null)
	_check(schema_2_copy.state_machines.size() == 2)
	_check(schema_2_copy.state_machines[1] == null)
	_check(schema_2_process_copy != schema_2_process)
	_check(schema_2_process_copy.get_internal_id().length() == 32)
	_check(schema_2_process_copy.get_internal_id() != schema_2_process_id)
	_check(schema_2_process_copy.blocks.size() == 2)
	_check(schema_2_process_copy.blocks[1] == null)
	_check(schema_2_process_copy.blocks[0] != schema_2_block)
	_check(schema_2_process_copy.blocks[0].get_internal_id().length() == 32)
	_check(schema_2_process_copy.blocks[0].get_internal_id() != schema_2_block_id)
	_check(schema_2_global_copy != schema_2_global)
	_check(schema_2_global_copy.get_internal_id() != schema_2_global_id)
	_check(schema_2_local_copy != schema_2_local)
	_check(schema_2_local_copy.get_internal_id() != schema_2_local_id)
	_check(schema_2_local_copy.owner_container_id == schema_2_process_copy.get_internal_id())
	_check(schema_2_local_copy.global_variable_id == schema_2_global_copy.get_internal_id())
	_check(schema_2_machine_copy != schema_2_machine)
	_check(schema_2_machine_copy.get_internal_id() != schema_2_machine_id)
	_check(schema_2_machine_copy.states.size() == 2)
	_check(schema_2_machine_copy.states[0] == null)
	_check(schema_2_state_copy != schema_2_state)
	_check(schema_2_state_copy.get_internal_id() != schema_2_state_id)
	_check(schema_2_state_copy.blocks[0] != schema_2_state_block)
	_check(schema_2_state_copy.blocks[0].get_internal_id() != schema_2_state_block_id)
	_check(schema_2_machine_copy.initial_state_id == schema_2_state_copy.get_internal_id())
	_check(schema_2_machine_copy.get_initial_state() == schema_2_state_copy)
	_check(schema_2_graph.get_internal_id() == schema_2_graph_id)
	_check(schema_2_process.get_internal_id() == schema_2_process_id)
	_check(schema_2_block.get_internal_id() == schema_2_block_id)
	_check(schema_2_global.get_internal_id() == schema_2_global_id)
	_check(schema_2_local.get_internal_id() == schema_2_local_id)
	_check(schema_2_local.owner_container_id == schema_2_process_id)
	_check(schema_2_local.global_variable_id == schema_2_global_id)
	_check(schema_2_machine.get_internal_id() == schema_2_machine_id)
	_check(schema_2_state.get_internal_id() == schema_2_state_id)
	_check(schema_2_state_block.get_internal_id() == schema_2_state_block_id)

	var missing_reference_graph: FlowGraph = FlowGraph.new()
	missing_reference_graph.schema_version = FlowGraph.SCHEMA_VERSION_2
	var missing_reference_variable: FlowVariableDefinition = FlowVariableDefinition.new()
	missing_reference_variable.owner_container_id = "missing_owner"
	missing_reference_variable.global_variable_id = "missing_global"
	missing_reference_graph.variables.append(missing_reference_variable)
	var missing_reference_result: FlowValidationResult = FlowGraphValidator.validate(
		missing_reference_graph
	)
	_check(missing_reference_result.has_errors())
	_check(_has_diagnostic(
		missing_reference_result,
		FlowDiagnostic.CODE_MISSING_OWNER_CONTAINER_REFERENCE
	))
	_check(_has_diagnostic(
		missing_reference_result,
		FlowDiagnostic.CODE_MISSING_GLOBAL_VARIABLE_REFERENCE
	))
	_check(missing_reference_variable.owner_container_id == "missing_owner")
	_check(missing_reference_variable.global_variable_id == "missing_global")

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
	_check(_has_diagnostic(
		invalid_reference_result,
		FlowDiagnostic.CODE_INVALID_OWNER_CONTAINER_REFERENCE
	))
	_check(_has_diagnostic(
		invalid_reference_result,
		FlowDiagnostic.CODE_INVALID_GLOBAL_VARIABLE_REFERENCE
	))

	var mixed_sources_graph: FlowGraph = FlowGraph.new()
	mixed_sources_graph.schema_version = FlowGraph.SCHEMA_VERSION_2
	mixed_sources_graph.containers.append(FlowProcess.new())
	mixed_sources_graph.processes.append(FlowProcess.new())
	var mixed_sources_result: FlowValidationResult = FlowGraphValidator.validate(mixed_sources_graph)
	_check(_has_diagnostic(mixed_sources_result, FlowDiagnostic.CODE_MIXED_SCHEMA_SOURCES))

	var schema_1_processes_source: FlowGraph = FlowGraph.new()
	schema_1_processes_source.processes.append(FlowProcess.new())
	var schema_1_processes_result: FlowValidationResult = FlowGraphValidator.validate(
		schema_1_processes_source
	)
	_check(_has_diagnostic(
		schema_1_processes_result,
		FlowDiagnostic.CODE_MIXED_SCHEMA_SOURCES
	))

	var schema_1_variables_source: FlowGraph = FlowGraph.new()
	schema_1_variables_source.variables.append(FlowVariableDefinition.new())
	var schema_1_variables_result: FlowValidationResult = FlowGraphValidator.validate(
		schema_1_variables_source
	)
	_check(_has_diagnostic(
		schema_1_variables_result,
		FlowDiagnostic.CODE_MIXED_SCHEMA_SOURCES
	))

	var schema_1_machines_source: FlowGraph = FlowGraph.new()
	schema_1_machines_source.state_machines.append(FlowStateMachineDefinition.new())
	var schema_1_machines_result: FlowValidationResult = FlowGraphValidator.validate(
		schema_1_machines_source
	)
	_check(_has_diagnostic(
		schema_1_machines_result,
		FlowDiagnostic.CODE_MIXED_SCHEMA_SOURCES
	))

	var schema_1_null_processes_source: FlowGraph = FlowGraph.new()
	schema_1_null_processes_source.processes.append(null)
	var schema_1_null_processes_result: FlowValidationResult = FlowGraphValidator.validate(
		schema_1_null_processes_source
	)
	_check(_has_diagnostic(
		schema_1_null_processes_result,
		FlowDiagnostic.CODE_MIXED_SCHEMA_SOURCES
	))

	var schema_1_null_variables_source: FlowGraph = FlowGraph.new()
	schema_1_null_variables_source.variables.append(null)
	var schema_1_null_variables_result: FlowValidationResult = FlowGraphValidator.validate(
		schema_1_null_variables_source
	)
	_check(_has_diagnostic(
		schema_1_null_variables_result,
		FlowDiagnostic.CODE_MIXED_SCHEMA_SOURCES
	))

	var schema_1_null_machines_source: FlowGraph = FlowGraph.new()
	schema_1_null_machines_source.state_machines.append(null)
	var schema_1_null_machines_result: FlowValidationResult = FlowGraphValidator.validate(
		schema_1_null_machines_source
	)
	_check(_has_diagnostic(
		schema_1_null_machines_result,
		FlowDiagnostic.CODE_MIXED_SCHEMA_SOURCES
	))

	var schema_2_containers_source: FlowGraph = FlowGraph.new()
	schema_2_containers_source.schema_version = FlowGraph.SCHEMA_VERSION_2
	schema_2_containers_source.containers.append(null)
	var schema_2_containers_result: FlowValidationResult = FlowGraphValidator.validate(
		schema_2_containers_source
	)
	_check(_has_diagnostic(
		schema_2_containers_result,
		FlowDiagnostic.CODE_MIXED_SCHEMA_SOURCES
	))
	var schema_1_constructor_source: FlowGraph = FlowGraph.new()
	var schema_1_constructor: FlowConstructorDefinition = FlowConstructorDefinition.new()
	schema_1_constructor_source.constructor = schema_1_constructor
	var schema_1_constructor_graph_id: String = schema_1_constructor_source.get_internal_id()
	var schema_1_constructor_result: FlowValidationResult = FlowGraphValidator.validate(schema_1_constructor_source)
	var schema_1_constructor_diagnostic: FlowDiagnostic = _find_diagnostic(schema_1_constructor_result, FlowDiagnostic.CODE_MIXED_SCHEMA_SOURCES, "graph")
	_check(schema_1_constructor_diagnostic != null)
	_check(schema_1_constructor_source.constructor == schema_1_constructor)
	_check(schema_1_constructor_source.get_internal_id() == schema_1_constructor_graph_id)

	var schema_1_null_methods_source: FlowGraph = FlowGraph.new()
	schema_1_null_methods_source.methods.append(null)
	var schema_1_null_methods_result: FlowValidationResult = FlowGraphValidator.validate(schema_1_null_methods_source)
	var schema_1_null_methods_diagnostic: FlowDiagnostic = _find_diagnostic(schema_1_null_methods_result, FlowDiagnostic.CODE_MIXED_SCHEMA_SOURCES, "graph")
	_check(schema_1_null_methods_diagnostic != null)
	_check(schema_1_null_methods_source.methods.size() == 1)
	_check(schema_1_null_methods_source.methods[0] == null)

	var schema_2_constructor_source: FlowGraph = FlowGraph.new()
	schema_2_constructor_source.schema_version = FlowGraph.SCHEMA_VERSION_2
	var schema_2_constructor: FlowConstructorDefinition = FlowConstructorDefinition.new()
	schema_2_constructor_source.constructor = schema_2_constructor
	var schema_2_constructor_result: FlowValidationResult = FlowGraphValidator.validate(schema_2_constructor_source)
	var schema_2_constructor_diagnostic: FlowDiagnostic = _find_diagnostic(schema_2_constructor_result, FlowDiagnostic.CODE_MIXED_SCHEMA_SOURCES, "graph")
	_check(schema_2_constructor_diagnostic != null)
	_check(schema_2_constructor_source.constructor == schema_2_constructor)
	_check(schema_2_constructor_source.schema_version == FlowGraph.SCHEMA_VERSION_2)

	var schema_2_null_methods_source: FlowGraph = FlowGraph.new()
	schema_2_null_methods_source.schema_version = FlowGraph.SCHEMA_VERSION_2
	schema_2_null_methods_source.methods.append(null)
	var schema_2_null_methods_result: FlowValidationResult = FlowGraphValidator.validate(schema_2_null_methods_source)
	var schema_2_null_methods_diagnostic: FlowDiagnostic = _find_diagnostic(schema_2_null_methods_result, FlowDiagnostic.CODE_MIXED_SCHEMA_SOURCES, "graph")
	_check(schema_2_null_methods_diagnostic != null)
	_check(schema_2_null_methods_source.methods.size() == 1)
	_check(schema_2_null_methods_source.methods[0] == null)
	_check(schema_2_null_methods_source.schema_version == FlowGraph.SCHEMA_VERSION_2)


	var incompatible_migration_process: FlowProcess = schema_1_processes_source.processes[0]
	var incompatible_migration_graph_id: String = schema_1_processes_source.get_internal_id()
	var incompatible_migration_result: FlowGraphMigrationResult = FlowGraphMigrator.migrate_schema_1_to_2(
		schema_1_processes_source
	)
	_check(not incompatible_migration_result.is_successful())
	_check(incompatible_migration_result.migrated_graph == null)
	_check(_has_migration_diagnostic(
		incompatible_migration_result,
		FlowDiagnostic.CODE_MIXED_SCHEMA_SOURCES
	))
	_check(schema_1_processes_source.get_internal_id() == incompatible_migration_graph_id)
	_check(schema_1_processes_source.processes[0] == incompatible_migration_process)
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
	_check(not empty_state_machine_result.has_errors())

	var valid_initial_state_graph: FlowGraph = FlowGraph.new()
	valid_initial_state_graph.schema_version = FlowGraph.SCHEMA_VERSION_2
	var valid_initial_state_machine: FlowStateMachineDefinition = FlowStateMachineDefinition.new()
	var valid_initial_state: FlowStateDefinition = FlowStateDefinition.new()
	valid_initial_state_machine.states.append(valid_initial_state)
	valid_initial_state_machine.initial_state_id = valid_initial_state.get_internal_id()
	valid_initial_state_graph.state_machines.append(valid_initial_state_machine)
	_check(not FlowGraphValidator.validate(valid_initial_state_graph).has_errors())

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
	if not _check(empty_initial_id_diagnostic != null, "empty initial-state diagnostic"):
		return
	_check(empty_initial_id_diagnostic.related_id == empty_initial_id_machine.get_internal_id())
	_check(empty_initial_id_machine.initial_state_id == "")

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
	if not _check(missing_initial_id_diagnostic != null, "missing initial-state diagnostic"):
		return
	_check(missing_initial_id_diagnostic.related_id == "missing_state")
	_check(missing_initial_id_machine.initial_state_id == "missing_state")

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
	if not _check(foreign_initial_id_diagnostic != null, "foreign initial-state diagnostic"):
		return
	_check(foreign_initial_id_diagnostic.related_id == second_foreign_state.get_internal_id())
	_check(first_foreign_machine.initial_state_id == second_foreign_state.get_internal_id())

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
	if not _check(empty_machine_reference_diagnostic != null, "empty-machine initial-state diagnostic"):
		return
	_check(empty_machine_reference_diagnostic.related_id == "missing_state")
	_check(empty_machine_reference.initial_state_id == "missing_state")
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
	_check(_has_diagnostic(
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
	if not _check(migration_result != null, "schema 1-to-2 migration result"):
		return
	if not _check(migration_result.is_successful(), "schema 1-to-2 migration success"):
		return
	if not _check(migration_result.diagnostics.is_empty(), "schema 1-to-2 migration diagnostics"):
		return
	var migrated_graph: FlowGraph = migration_result.migrated_graph
	if not _check(migrated_graph != null, "schema 1-to-2 migration candidate"):
		return
	if not _check(migrated_graph.processes.size() == 4, "schema 1-to-2 migrated process collection length"):
		return
	if not _check(migrated_graph.state_machines.size() == 1, "schema 1-to-2 migrated state-machine collection length"):
		return
	if not _check(migrated_graph.processes[0] is FlowProcess, "schema 1-to-2 migrated process at index 0"):
		return
	if not _check(migrated_graph.state_machines[0] is FlowStateMachineDefinition, "schema 1-to-2 migrated state machine at index 0"):
		return
	var migrated_process: FlowProcess = migrated_graph.processes[0] as FlowProcess
	var migrated_machine: FlowStateMachineDefinition = migrated_graph.state_machines[0] as FlowStateMachineDefinition
	if not _check(migrated_machine.states.size() == 4, "schema 1-to-2 migrated state collection length"):
		return
	if not _check(migrated_machine.states[2] is FlowStateDefinition, "schema 1-to-2 migrated initial state at index 2"):
		return
	if not _check(migrated_machine.states[3] is FlowStateDefinition, "schema 1-to-2 migrated second state at index 3"):
		return
	var migrated_initial_state: FlowStateDefinition = migrated_machine.states[2] as FlowStateDefinition
	var migrated_second_state: FlowStateDefinition = migrated_machine.states[3] as FlowStateDefinition
	_check(migrated_graph != migration_source)
	_check(migrated_graph.schema_version == FlowGraph.SCHEMA_VERSION_2)
	_check(migrated_graph.get_internal_id() == migration_source_id)
	_check(migrated_graph.containers.is_empty())
	_check(migrated_graph.processes[1] == null)
	_check(migrated_graph.processes[2] == null)
	_check(migrated_graph.processes[3] == null)
	_check(migrated_process != migration_process)
	_check(migrated_process.get_internal_id() == migration_process_id)
	if not _check(migrated_process.blocks.size() >= 1, "schema 1-to-2 migrated process block at index 0"):
		return
	if not _check(migrated_process.blocks[0] is FlowBlock, "schema 1-to-2 migrated process block type"):
		return
	_check(migrated_process.blocks[0] != migration_process_block)
	_check(migrated_process.blocks[0].get_internal_id() == migration_process_block_id)
	_check(migrated_machine.display_name == "Migrated States")
	_check(migrated_machine.get_internal_id().length() == 32)
	_check(migrated_machine.get_internal_id() != migration_source_id)
	_check(migrated_machine.states[0] == null)
	_check(migrated_machine.states[1] == null)
	_check(migrated_initial_state != migration_initial_state)
	_check(migrated_initial_state.get_internal_id() == migration_initial_state_id)
	if not _check(migrated_initial_state.blocks.size() >= 1, "schema 1-to-2 migrated initial-state block at index 0"):
		return
	if not _check(migrated_initial_state.blocks[0] is FlowBlock, "schema 1-to-2 migrated initial-state block type"):
		return
	_check(migrated_initial_state.blocks[0] != migration_initial_block)
	_check(migrated_initial_state.blocks[0].get_internal_id() == migration_initial_block_id)
	_check(migrated_second_state != migration_second_state)
	_check(migrated_second_state.get_internal_id() == migration_second_state_id)
	_check(migrated_machine.initial_state_id == migration_initial_state_id)
	_check(migrated_machine.get_initial_state() == migrated_initial_state)
	var migrated_validation: FlowValidationResult = FlowGraphValidator.validate(migrated_graph)
	_check(not migrated_validation.has_errors())
	_check(migration_source.schema_version == FlowGraph.CURRENT_SCHEMA_VERSION)
	_check(migration_source.get_internal_id() == migration_source_id)
	_check(migration_source.containers.size() == 4)
	_check(migration_source.containers[0] == migration_process)
	_check(migration_source.containers[1] == null)
	_check(migration_source.containers[2] == migration_initial_state)
	_check(migration_source.containers[3] == migration_second_state)
	_check(migration_source.processes.is_empty())
	_check(migration_source.variables.is_empty())
	_check(migration_source.state_machines.is_empty())
	_check(migration_process.get_internal_id() == migration_process_id)
	_check(migration_process_block.get_internal_id() == migration_process_block_id)
	_check(migration_initial_state.get_internal_id() == migration_initial_state_id)
	_check(migration_initial_block.get_internal_id() == migration_initial_block_id)
	_check(migration_second_state.get_internal_id() == migration_second_state_id)

	var no_initial_source: FlowGraph = FlowGraph.new()
	no_initial_source.containers.append(null)
	var no_initial_state: FlowStateDefinition = FlowStateDefinition.new()
	no_initial_source.containers.append(no_initial_state)
	var no_initial_result: FlowGraphMigrationResult = FlowGraphMigrator.migrate_schema_1_to_2(
		no_initial_source
	)
	if not _check(no_initial_result != null, "no-initial schema 1-to-2 migration result"):
		return
	if not _check(no_initial_result.is_successful(), "no-initial schema 1-to-2 migration success"):
		return
	if not _check(no_initial_result.migrated_graph != null, "no-initial schema 1-to-2 migration candidate"):
		return
	var no_initial_graph: FlowGraph = no_initial_result.migrated_graph
	if not _check(no_initial_graph.state_machines.size() == 1, "no-initial migrated state-machine collection length"):
		return
	if not _check(no_initial_graph.state_machines[0] is FlowStateMachineDefinition, "no-initial migrated state machine at index 0"):
		return
	var no_initial_machine: FlowStateMachineDefinition = no_initial_graph.state_machines[0] as FlowStateMachineDefinition
	if not _check(no_initial_machine.states.size() == 2, "no-initial migrated state collection length"):
		return
	if not _check(no_initial_machine.states[1] is FlowStateDefinition, "no-initial migrated state at index 1"):
		return
	var no_initial_state_copy: FlowStateDefinition = no_initial_machine.states[1] as FlowStateDefinition
	_check(no_initial_machine.initial_state_id == no_initial_state_copy.get_internal_id())
	_check(no_initial_machine.get_initial_state() == no_initial_state_copy)

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
	_check(not multiple_initial_result.is_successful())
	_check(multiple_initial_result.migrated_graph == null)
	_check(_has_migration_diagnostic(
		multiple_initial_result,
		FlowDiagnostic.CODE_MULTIPLE_INITIAL_STATES
	))
	_check(multiple_initial_source.get_internal_id() == multiple_initial_source_id)
	_check(multiple_initial_source.schema_version == FlowGraph.CURRENT_SCHEMA_VERSION)
	_check(multiple_initial_source.containers[0] == first_multiple_initial_state)
	_check(multiple_initial_source.containers[1] == second_multiple_initial_state)

	var unknown_container_source: FlowGraph = FlowGraph.new()
	var unknown_container: FlowBlockContainer = FlowBlockContainer.new()
	unknown_container_source.containers.append(unknown_container)
	var unknown_container_result: FlowGraphMigrationResult = FlowGraphMigrator.migrate_schema_1_to_2(
		unknown_container_source
	)
	_check(not unknown_container_result.is_successful())
	_check(_has_migration_diagnostic(
		unknown_container_result,
		FlowDiagnostic.CODE_UNMIGRATABLE_CONTAINER_TYPE
	))
	_check(unknown_container_source.containers[0] == unknown_container)
	_check(unknown_container_source.schema_version == FlowGraph.CURRENT_SCHEMA_VERSION)

	var invalid_migration_source: FlowGraph = FlowGraph.new()
	invalid_migration_source._internal_id = ""
	var invalid_migration_result: FlowGraphMigrationResult = FlowGraphMigrator.migrate_schema_1_to_2(
		invalid_migration_source
	)
	_check(not invalid_migration_result.is_successful())
	_check(_has_migration_diagnostic(
		invalid_migration_result,
		FlowDiagnostic.CODE_EMPTY_INTERNAL_ID
	))
	_check(invalid_migration_source._internal_id == "")
	_check(invalid_migration_source.schema_version == FlowGraph.CURRENT_SCHEMA_VERSION)

	var first_deterministic_failure: FlowGraphMigrationResult = FlowGraphMigrator.migrate_schema_1_to_2(
		multiple_initial_source
	)
	var second_deterministic_failure: FlowGraphMigrationResult = FlowGraphMigrator.migrate_schema_1_to_2(
		multiple_initial_source
	)
	if not _check(
		first_deterministic_failure.diagnostics.size() == second_deterministic_failure.diagnostics.size(),
		"schema 1-to-2 deterministic migration diagnostic count"
	):
		return
	for migration_diagnostic_index: int in first_deterministic_failure.diagnostics.size():
		var first_migration_diagnostic: FlowDiagnostic = _migration_diagnostic_at(
			first_deterministic_failure,
			migration_diagnostic_index,
			"first schema 1-to-2 deterministic migration"
		)
		if first_migration_diagnostic == null:
			return
		var second_migration_diagnostic: FlowDiagnostic = _migration_diagnostic_at(
			second_deterministic_failure,
			migration_diagnostic_index,
			"second schema 1-to-2 deterministic migration"
		)
		if second_migration_diagnostic == null:
			return
		_check(first_migration_diagnostic.code == second_migration_diagnostic.code)
		_check(first_migration_diagnostic.element_path == second_migration_diagnostic.element_path)
		_check(first_migration_diagnostic.related_id == second_migration_diagnostic.related_id)

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
	if not _check_dictionary_keys(
		presenter_schema_1,
		["sections", "schema_version", "active_source"],
		"schema 1 presenter result"
	):
		return
	var presenter_schema_1_sections_value: Variant = presenter_schema_1["sections"]
	if not _check(presenter_schema_1_sections_value is Array, "schema 1 presenter sections type"):
		return
	var presenter_schema_1_sections: Array = presenter_schema_1_sections_value
	if not _check(presenter_schema_1_sections.size() == 1, "schema 1 presenter section count"):
		return
	if not _check(presenter_schema_1_sections[0] is Dictionary, "schema 1 presenter section at index 0"):
		return
	var presenter_containers: Dictionary = presenter_schema_1_sections[0]
	if not _check_dictionary_keys(presenter_containers, ["title", "entries"], "schema 1 presenter section"):
		return
	var presenter_container_entries_value: Variant = presenter_containers["entries"]
	if not _check(presenter_container_entries_value is Array, "schema 1 presenter entries type"):
		return
	var presenter_container_entries: Array = presenter_container_entries_value
	if not _check(presenter_container_entries.size() == 3, "schema 1 presenter entry count"):
		return
	if not _check(presenter_container_entries[0] is Dictionary, "schema 1 presenter entry at index 0"):
		return
	if not _check(presenter_container_entries[1] is Dictionary, "schema 1 presenter entry at index 1"):
		return
	if not _check(presenter_container_entries[2] is Dictionary, "schema 1 presenter entry at index 2"):
		return
	var presenter_first_container: Dictionary = presenter_container_entries[0]
	var presenter_empty_container: Dictionary = presenter_container_entries[1]
	var presenter_last_container: Dictionary = presenter_container_entries[2]
	if not _check_dictionary_keys(
		presenter_first_container,
		["index", "name", "type", "internal_id", "is_empty"],
		"schema 1 presenter entry at index 0"
	):
		return
	if not _check_dictionary_keys(
		presenter_empty_container,
		["index", "name", "type", "internal_id", "is_empty"],
		"schema 1 presenter entry at index 1"
	):
		return
	if not _check_dictionary_keys(
		presenter_last_container,
		["index", "name", "type"],
		"schema 1 presenter entry at index 2"
	):
		return
	_check(presenter_schema_1 == presenter_schema_1_repeat)
	_check(presenter_schema_1["schema_version"] == FlowGraph.CURRENT_SCHEMA_VERSION)
	_check(presenter_schema_1["active_source"] == "Containers")
	_check(presenter_containers["title"] == "Containers")
	_check(presenter_first_container["index"] == 0)
	_check(presenter_first_container["name"] == "Presenter Process")
	_check(presenter_first_container["type"] == "FlowProcess")
	_check(presenter_first_container["internal_id"] == presenter_schema_1_process.get_internal_id())
	_check(presenter_first_container["is_empty"] == false)
	_check(presenter_empty_container["index"] == 1)
	_check(presenter_empty_container["name"] == "Empty")
	_check(presenter_empty_container["type"] == "Empty")
	_check(presenter_empty_container["internal_id"] == "")
	_check(presenter_empty_container["is_empty"] == true)
	_check(presenter_last_container["index"] == 2)
	_check(presenter_last_container["name"] == "Presenter State")
	_check(presenter_last_container["type"] == "FlowStateDefinition")
	_check(presenter_schema_1_graph.containers[0] == presenter_schema_1_process)
	_check(presenter_schema_1_graph.containers[1] == null)
	_check(presenter_schema_1_graph.containers[2] == presenter_schema_1_state)

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
	if not _check_dictionary_keys(
		presenter_schema_2,
		["sections", "schema_version", "active_source"],
		"schema 2 presenter result"
	):
		return
	var presenter_schema_2_sections_value: Variant = presenter_schema_2["sections"]
	if not _check(presenter_schema_2_sections_value is Array, "schema 2 presenter sections type"):
		return
	var presenter_schema_2_sections: Array = presenter_schema_2_sections_value
	if not _check(presenter_schema_2_sections.size() == 3, "schema 2 presenter section count"):
		return
	if not _check(presenter_schema_2_sections[0] is Dictionary, "schema 2 presenter process section at index 0"):
		return
	if not _check(presenter_schema_2_sections[1] is Dictionary, "schema 2 presenter variable section at index 1"):
		return
	if not _check(presenter_schema_2_sections[2] is Dictionary, "schema 2 presenter state-machine section at index 2"):
		return
	var presenter_processes: Dictionary = presenter_schema_2_sections[0]
	var presenter_variables: Dictionary = presenter_schema_2_sections[1]
	var presenter_machines: Dictionary = presenter_schema_2_sections[2]
	if not _check_dictionary_keys(presenter_processes, ["title", "entries"], "schema 2 process section"):
		return
	if not _check_dictionary_keys(presenter_variables, ["title", "entries"], "schema 2 variable section"):
		return
	if not _check_dictionary_keys(presenter_machines, ["title", "entries"], "schema 2 state-machine section"):
		return
	var presenter_process_entries_value: Variant = presenter_processes["entries"]
	var presenter_variable_entries_value: Variant = presenter_variables["entries"]
	var presenter_machine_entries_value: Variant = presenter_machines["entries"]
	if not _check(presenter_process_entries_value is Array, "schema 2 process entries type"):
		return
	if not _check(presenter_variable_entries_value is Array, "schema 2 variable entries type"):
		return
	if not _check(presenter_machine_entries_value is Array, "schema 2 state-machine entries type"):
		return
	var presenter_process_entries: Array = presenter_process_entries_value
	var presenter_variable_entries: Array = presenter_variable_entries_value
	var presenter_machine_entries: Array = presenter_machine_entries_value
	if not _check(presenter_process_entries.size() == 2, "schema 2 process entry count"):
		return
	if not _check(presenter_variable_entries.size() == 2, "schema 2 variable entry count"):
		return
	if not _check(presenter_machine_entries.size() == 2, "schema 2 state-machine entry count"):
		return
	if not _check(presenter_process_entries[0] is Dictionary, "schema 2 process entry at index 0"):
		return
	if not _check(presenter_process_entries[1] is Dictionary, "schema 2 process entry at index 1"):
		return
	if not _check(presenter_variable_entries[0] is Dictionary, "schema 2 variable entry at index 0"):
		return
	if not _check(presenter_variable_entries[1] is Dictionary, "schema 2 variable entry at index 1"):
		return
	if not _check(presenter_machine_entries[0] is Dictionary, "schema 2 state-machine entry at index 0"):
		return
	if not _check(presenter_machine_entries[1] is Dictionary, "schema 2 state-machine entry at index 1"):
		return
	var presenter_process_entry: Dictionary = presenter_process_entries[0]
	var presenter_empty_process_entry: Dictionary = presenter_process_entries[1]
	var presenter_empty_variable_entry: Dictionary = presenter_variable_entries[0]
	var presenter_variable_entry: Dictionary = presenter_variable_entries[1]
	var presenter_machine_entry: Dictionary = presenter_machine_entries[0]
	var presenter_empty_machine_entry: Dictionary = presenter_machine_entries[1]
	if not _check_dictionary_keys(presenter_process_entry, ["internal_id"], "schema 2 process entry at index 0"):
		return
	if not _check_dictionary_keys(presenter_empty_process_entry, ["name"], "schema 2 process entry at index 1"):
		return
	if not _check_dictionary_keys(presenter_empty_variable_entry, ["is_empty"], "schema 2 variable entry at index 0"):
		return
	if not _check_dictionary_keys(presenter_variable_entry, ["name", "internal_id"], "schema 2 variable entry at index 1"):
		return
	if not _check_dictionary_keys(presenter_machine_entry, ["name", "internal_id"], "schema 2 state-machine entry at index 0"):
		return
	if not _check_dictionary_keys(presenter_empty_machine_entry, ["name"], "schema 2 state-machine entry at index 1"):
		return
	_check(presenter_schema_2["schema_version"] == FlowGraph.SCHEMA_VERSION_2)
	_check(presenter_schema_2["active_source"] == "Typed collections")
	_check(presenter_processes["title"] == "Processes")
	_check(presenter_variables["title"] == "Variables")
	_check(presenter_machines["title"] == "State Machines")
	_check(presenter_process_entry["internal_id"] == presenter_schema_2_process.get_internal_id())
	_check(presenter_empty_process_entry["name"] == "Empty")
	_check(presenter_empty_variable_entry["is_empty"] == true)
	_check(presenter_variable_entry["name"] == "Typed Variable")
	_check(presenter_variable_entry["internal_id"] == presenter_schema_2_variable.get_internal_id())
	_check(presenter_machine_entry["name"] == "Typed Machine")
	_check(presenter_machine_entry["internal_id"] == presenter_schema_2_machine.get_internal_id())
	_check(presenter_empty_machine_entry["name"] == "Empty")
	_check(presenter_schema_2_graph.containers.is_empty())
	_check(presenter_schema_2_graph.processes[0] == presenter_schema_2_process)
	_check(presenter_schema_2_graph.variables[1] == presenter_schema_2_variable)
	_check(presenter_schema_2_graph.state_machines[0] == presenter_schema_2_machine)

	var presenter_invalid_graph: FlowGraph = FlowGraph.new()
	presenter_invalid_graph._internal_id = ""
	var presenter_invalid: Dictionary = FlowGraphInspectorPresenter.present(presenter_invalid_graph)
	if not _check_dictionary_keys(presenter_invalid, ["diagnostics"], "invalid presenter result"):
		return
	var presenter_diagnostics_value: Variant = presenter_invalid["diagnostics"]
	if not _check(presenter_diagnostics_value is Array, "invalid presenter diagnostics type"):
		return
	var presenter_diagnostics: Array = presenter_diagnostics_value
	if not _check(presenter_diagnostics.size() == 1, "invalid presenter diagnostic count"):
		return
	if not _check(presenter_diagnostics[0] is Dictionary, "invalid presenter diagnostic at index 0"):
		return
	var presenter_diagnostic: Dictionary = presenter_diagnostics[0]
	if not _check_dictionary_keys(presenter_diagnostic, ["code"], "invalid presenter diagnostic at index 0"):
		return
	_check(presenter_diagnostic["code"] == "empty_internal_id")
	_check(presenter_invalid_graph._internal_id == "")

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
	_check(not schema_3_validation.has_errors())
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
	_check(schema_3_graph.constructor == schema_3_constructor)
	_check(schema_3_constructor is FlowBlockContainer)
	_check(schema_3_constructor.display_name == "Constructor Flow")
	_check(not schema_3_constructor.enabled)
	_check(schema_3_constructor.user_note == "Constructor note")
	_check(schema_3_constructor.blocks.size() == 2)
	_check(schema_3_constructor.blocks[0] == schema_3_constructor_block)
	_check(schema_3_constructor.blocks[1] == null)
	_check(schema_3_graph.constructor.dependencies[1] == null)
	_check(schema_3_graph.methods[1] == null)
	_check(schema_3_method.parameters[1] == null)
	var schema_3_copy: FlowGraph = schema_3_graph.duplicate_with_new_ids()
	if not _check(schema_3_copy != null, "schema 3 duplicated graph"):
		return
	if not _check(schema_3_copy.constructor is FlowConstructorDefinition, "schema 3 duplicated constructor"):
		return
	if not _check(schema_3_copy.methods.size() == 2, "schema 3 duplicated method collection length"):
		return
	if not _check(schema_3_copy.methods[0] is FlowMethodDefinition, "schema 3 duplicated method at index 0"):
		return
	var schema_3_copy_constructor: FlowConstructorDefinition = schema_3_copy.constructor
	var schema_3_copy_method: FlowMethodDefinition = schema_3_copy.methods[0]
	if not _check(schema_3_copy_constructor.blocks.size() == 2, "schema 3 duplicated constructor block collection length"):
		return
	if not _check(schema_3_copy_constructor.blocks[0] is FlowBlock, "schema 3 duplicated constructor block at index 0"):
		return
	if not _check(schema_3_copy_constructor.dependencies.size() == 3, "schema 3 duplicated constructor dependency collection length"):
		return
	if not _check(schema_3_copy_constructor.dependencies[0] is FlowDependencyDefinition, "schema 3 duplicated dependency at index 0"):
		return
	if not _check(schema_3_copy_constructor.dependencies[2] is FlowDependencyDefinition, "schema 3 duplicated dependency at index 2"):
		return
	if not _check(schema_3_copy_method.parameters.size() == 2, "schema 3 duplicated parameter collection length"):
		return
	if not _check(schema_3_copy_method.parameters[0] is FlowMethodParameterDefinition, "schema 3 duplicated parameter at index 0"):
		return
	if not _check(schema_3_copy_method.blocks.size() == 2, "schema 3 duplicated method block collection length"):
		return
	if not _check(schema_3_copy_method.blocks[0] is FlowBlock, "schema 3 duplicated method block at index 0"):
		return
	_check(schema_3_copy.get_internal_id() != schema_3_graph_id)
	_check(schema_3_copy.constructor != schema_3_constructor)
	_check(schema_3_copy.constructor is FlowBlockContainer)
	_check(schema_3_copy_constructor.get_internal_id() != schema_3_constructor_id)
	_check(schema_3_copy_constructor.display_name == "Constructor Flow")
	_check(not schema_3_copy_constructor.enabled)
	_check(schema_3_copy_constructor.user_note == "Constructor note")
	_check(schema_3_copy_constructor.blocks[0] != schema_3_constructor_block)
	_check(schema_3_copy_constructor.blocks[0].get_internal_id() != schema_3_constructor_block_id)
	_check(schema_3_copy_constructor.blocks[0].display_name == "Constructor Block")
	_check(schema_3_copy_constructor.blocks[1] == null)
	_check(schema_3_copy_constructor.dependencies[0] != dependency_a)
	_check(schema_3_copy_constructor.dependencies[0].get_internal_id() != dependency_a_id)
	_check(schema_3_copy_constructor.dependencies[1] == null)
	_check(schema_3_copy_constructor.dependencies[2] != dependency_b)
	_check(schema_3_copy_constructor.dependencies[2].get_internal_id() != dependency_b_id)
	_check(schema_3_copy_constructor.dependencies[2].display_name == "Target")
	_check(schema_3_copy_method != schema_3_method)
	_check(schema_3_copy_method.get_internal_id() != schema_3_method_id)
	_check(schema_3_copy_method.parameters[0] != schema_3_parameter)
	_check(schema_3_copy_method.parameters[0].get_internal_id() != schema_3_parameter_id)
	_check(schema_3_copy_method.blocks[0] != schema_3_block)
	_check(schema_3_copy_method.blocks[0].get_internal_id() != schema_3_block_id)
	_check(schema_3_copy_method.parameters[1] == null and schema_3_copy.methods[1] == null)
	_check(schema_3_graph.get_internal_id() == schema_3_graph_id and dependency_a.get_internal_id() == dependency_a_id)
	schema_3_copy_constructor.display_name = "Copied Constructor"
	schema_3_copy_constructor.blocks[0].display_name = "Copied Block"
	schema_3_copy_constructor.dependencies[0].display_name = "Copied Dependency"
	_check(schema_3_constructor.display_name == "Constructor Flow")
	_check(schema_3_constructor_block.display_name == "Constructor Block")
	_check(dependency_a.display_name == "Collider")
	var schema_3_mixed_sources: FlowGraph = FlowGraph.new()
	schema_3_mixed_sources.schema_version = FlowGraph.SCHEMA_VERSION_3
	schema_3_mixed_sources.constructor = FlowConstructorDefinition.new()
	schema_3_mixed_sources.containers.append(FlowProcess.new())
	_check(_has_diagnostic(FlowGraphValidator.validate(schema_3_mixed_sources), FlowDiagnostic.CODE_MIXED_SCHEMA_SOURCES))
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
	_check(_has_diagnostic(schema_3_invalid_validation, FlowDiagnostic.CODE_EMPTY_DISPLAY_NAME))
	_check(_has_diagnostic(schema_3_invalid_validation, FlowDiagnostic.CODE_EMPTY_REQUIRED_CLASS_NAME))
	_check(_has_diagnostic(schema_3_invalid_validation, FlowDiagnostic.CODE_REPEATED_RESOURCE_INSTANCE))
	_check(invalid_dependency.required_class_name == &"")
	_check(FlowVariableDefinition.ValueType.BOOL == 0 and FlowVariableDefinition.ValueType.COLOR == 6)
	_check(schema_3_variable.value_type == FlowVariableDefinition.ValueType.INT)
	_check(schema_3_parameter.value_type == FlowVariableDefinition.ValueType.INT)
	_check(schema_3_variable.value_type == schema_3_parameter.value_type)
	var value_type_regression_path: String = "res://.godot/flow_value_type_schema_3_regression.tres"
	if not _check(ResourceSaver.save(schema_3_graph, value_type_regression_path) == OK, "schema 3 value-type ResourceSaver save"):
		return
	var loaded_schema_3_graph: FlowGraph = load(value_type_regression_path) as FlowGraph
	if not _check(loaded_schema_3_graph != null, "loaded schema 3 value-type graph"):
		return
	if not _check(loaded_schema_3_graph.constructor is FlowConstructorDefinition, "loaded schema 3 constructor"):
		return
	var loaded_schema_3_constructor: FlowConstructorDefinition = loaded_schema_3_graph.constructor
	_check(loaded_schema_3_constructor.display_name == "Constructor Flow")
	_check(not loaded_schema_3_constructor.enabled)
	_check(loaded_schema_3_constructor.user_note == "Constructor note")
	if not _check(loaded_schema_3_constructor.blocks.size() == 2, "loaded schema 3 constructor blocks"):
		return
	if not _check(loaded_schema_3_constructor.blocks[0] is FlowBlock, "loaded schema 3 constructor block at index 0"):
		return
	var loaded_schema_3_constructor_block: FlowBlock = loaded_schema_3_constructor.blocks[0]
	_check(loaded_schema_3_constructor_block.display_name == "Constructor Block")
	_check(loaded_schema_3_constructor.blocks[1] == null)
	if not _check(loaded_schema_3_constructor.dependencies.size() == 3, "loaded schema 3 constructor dependencies"):
		return
	if not _check(loaded_schema_3_constructor.dependencies[0] is FlowDependencyDefinition, "loaded schema 3 dependency at index 0"):
		return
	if not _check(loaded_schema_3_constructor.dependencies[2] is FlowDependencyDefinition, "loaded schema 3 dependency at index 2"):
		return
	_check(loaded_schema_3_constructor.dependencies[0].display_name == "Collider")
	_check(loaded_schema_3_constructor.dependencies[1] == null)
	_check(loaded_schema_3_constructor.dependencies[2].display_name == "Target")
	if not _check(loaded_schema_3_graph.variables.size() >= 1, "loaded schema 3 variable collection length"):
		return
	if not _check(loaded_schema_3_graph.variables[0] is FlowVariableDefinition, "loaded schema 3 variable at index 0"):
		return
	if not _check(loaded_schema_3_graph.methods.size() >= 1, "loaded schema 3 method collection length"):
		return
	if not _check(loaded_schema_3_graph.methods[0] is FlowMethodDefinition, "loaded schema 3 method at index 0"):
		return
	var loaded_schema_3_variable: FlowVariableDefinition = loaded_schema_3_graph.variables[0]
	var loaded_schema_3_method: FlowMethodDefinition = loaded_schema_3_graph.methods[0]
	_check(loaded_schema_3_variable.value_type == FlowVariableDefinition.ValueType.INT)
	if not _check(loaded_schema_3_method.parameters.size() >= 1, "loaded schema 3 parameter collection length"):
		return
	if not _check(loaded_schema_3_method.parameters[0] is FlowMethodParameterDefinition, "loaded schema 3 parameter at index 0"):
		return
	_check(loaded_schema_3_method.parameters[0].value_type == FlowVariableDefinition.ValueType.INT)
	_check(not FlowGraphValidator.validate(loaded_schema_3_graph).has_errors())
	var loaded_schema_3_copy: FlowGraph = loaded_schema_3_graph.duplicate_with_new_ids()
	if not _check(loaded_schema_3_copy.variables.size() >= 1, "copied schema 3 variable collection length"):
		return
	if not _check(loaded_schema_3_copy.variables[0] is FlowVariableDefinition, "copied schema 3 variable at index 0"):
		return
	if not _check(loaded_schema_3_copy.methods.size() >= 1, "copied schema 3 method collection length"):
		return
	if not _check(loaded_schema_3_copy.methods[0] is FlowMethodDefinition, "copied schema 3 method at index 0"):
		return
	var loaded_schema_3_copy_method: FlowMethodDefinition = loaded_schema_3_copy.methods[0]
	_check(loaded_schema_3_copy.variables[0].value_type == FlowVariableDefinition.ValueType.INT)
	if not _check(loaded_schema_3_copy_method.parameters.size() >= 1, "copied schema 3 parameter collection length"):
		return
	if not _check(loaded_schema_3_copy_method.parameters[0] is FlowMethodParameterDefinition, "copied schema 3 parameter at index 0"):
		return
	_check(loaded_schema_3_copy_method.parameters[0].value_type == FlowVariableDefinition.ValueType.INT)
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
	_check(_has_diagnostic(FlowGraphValidator.validate(duplicate_names_graph), FlowDiagnostic.CODE_DUPLICATE_DISPLAY_NAME))

	var duplicate_schema_3_id_graph: FlowGraph = FlowGraph.new()
	duplicate_schema_3_id_graph.schema_version = FlowGraph.SCHEMA_VERSION_3
	duplicate_schema_3_id_graph.constructor = FlowConstructorDefinition.new()
	var duplicate_schema_3_dependency: FlowDependencyDefinition = FlowDependencyDefinition.new()
	duplicate_schema_3_dependency._internal_id = duplicate_schema_3_id_graph.get_internal_id()
	duplicate_schema_3_id_graph.constructor.dependencies = [duplicate_schema_3_dependency]
	_check(_has_diagnostic(FlowGraphValidator.validate(duplicate_schema_3_id_graph), FlowDiagnostic.CODE_DUPLICATE_INTERNAL_ID))

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
	if not _check(first_invalid_constructor_blocks_result.diagnostics.size() == 3, "invalid constructor-block diagnostic count"):
		return
	var empty_constructor_block_diagnostic: FlowDiagnostic = _diagnostic_at(
		first_invalid_constructor_blocks_result,
		0,
		"empty constructor block"
	)
	if empty_constructor_block_diagnostic == null:
		return
	var repeated_constructor_block_diagnostic: FlowDiagnostic = _diagnostic_at(
		first_invalid_constructor_blocks_result,
		1,
		"repeated constructor block"
	)
	if repeated_constructor_block_diagnostic == null:
		return
	var duplicate_constructor_block_diagnostic: FlowDiagnostic = _diagnostic_at(
		first_invalid_constructor_blocks_result,
		2,
		"duplicate constructor block"
	)
	if duplicate_constructor_block_diagnostic == null:
		return
	_check(empty_constructor_block_diagnostic.code == FlowDiagnostic.CODE_EMPTY_INTERNAL_ID)
	_check(empty_constructor_block_diagnostic.element_path == "constructor.blocks[0]")
	_check(empty_constructor_block_diagnostic.related_id == "")
	_check(repeated_constructor_block_diagnostic.code == FlowDiagnostic.CODE_REPEATED_RESOURCE_INSTANCE)
	_check(repeated_constructor_block_diagnostic.element_path == "constructor.blocks[3]")
	_check(repeated_constructor_block_diagnostic.related_id == repeated_constructor_block.get_internal_id())
	_check(duplicate_constructor_block_diagnostic.code == FlowDiagnostic.CODE_DUPLICATE_INTERNAL_ID)
	_check(duplicate_constructor_block_diagnostic.element_path == "constructor.blocks[4]")
	_check(duplicate_constructor_block_diagnostic.related_id == repeated_constructor_block.get_internal_id())

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
	if not _check(first_invalid_constructor_dependencies_result.diagnostics.size() == 2, "invalid constructor-dependency diagnostic count"):
		return
	var empty_constructor_dependency_name_diagnostic: FlowDiagnostic = _diagnostic_at(
		first_invalid_constructor_dependencies_result,
		0,
		"empty constructor dependency name"
	)
	if empty_constructor_dependency_name_diagnostic == null:
		return
	var empty_constructor_dependency_class_diagnostic: FlowDiagnostic = _diagnostic_at(
		first_invalid_constructor_dependencies_result,
		1,
		"empty constructor dependency class"
	)
	if empty_constructor_dependency_class_diagnostic == null:
		return
	_check(empty_constructor_dependency_name_diagnostic.code == FlowDiagnostic.CODE_EMPTY_DISPLAY_NAME)
	_check(empty_constructor_dependency_name_diagnostic.element_path == "constructor.dependencies[1]")
	_check(empty_constructor_dependency_name_diagnostic.related_id == invalid_constructor_dependency.get_internal_id())
	_check(empty_constructor_dependency_class_diagnostic.code == FlowDiagnostic.CODE_EMPTY_REQUIRED_CLASS_NAME)
	_check(empty_constructor_dependency_class_diagnostic.element_path == "constructor.dependencies[1].required_class_name")
	_check(empty_constructor_dependency_class_diagnostic.related_id == invalid_constructor_dependency.get_internal_id())
	_check(invalid_constructor_dependencies_graph.constructor.dependencies[0] == null)
	_check(invalid_constructor_dependencies_graph.constructor.dependencies[1] == invalid_constructor_dependency)

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
	if not _check(first_cross_container_block_result.diagnostics.size() == 1, "cross-container block diagnostic count"):
		return
	var cross_container_block_diagnostic: FlowDiagnostic = _diagnostic_at(
		first_cross_container_block_result,
		0,
		"cross-container block"
	)
	if cross_container_block_diagnostic == null:
		return
	_check(cross_container_block_diagnostic.code == FlowDiagnostic.CODE_REPEATED_RESOURCE_INSTANCE)
	_check(cross_container_block_diagnostic.element_path == "methods[0].blocks[0]")
	_check(cross_container_block_diagnostic.related_id == cross_container_block.get_internal_id())
	_check(cross_container_block_graph.constructor.blocks[0] == cross_container_block)
	_check(cross_container_block_graph.constructor.blocks[1] == null)
	_check(cross_container_method.blocks[0] == cross_container_block)

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
	_check(not FlowGraphValidator.validate(schema_2_to_3_source).has_errors())
	var schema_2_to_3_source_id: String = schema_2_to_3_source.get_internal_id()
	var schema_2_to_3_result: FlowGraphMigrationResult = FlowGraphMigrator.migrate_schema_2_to_3(
		schema_2_to_3_source
	)
	if not _check(schema_2_to_3_result != null, "schema 2-to-3 migration result"):
		return
	if not _check(schema_2_to_3_result.is_successful(), "schema 2-to-3 migration success"):
		return
	if not _check(schema_2_to_3_result.diagnostics.is_empty(), "schema 2-to-3 migration diagnostics"):
		return
	var schema_2_to_3_candidate: FlowGraph = schema_2_to_3_result.migrated_graph
	if not _check(schema_2_to_3_candidate != null, "schema 2-to-3 migration candidate"):
		return
	if not _check(schema_2_to_3_candidate.processes.size() == 2, "schema 2-to-3 migrated process collection length"):
		return
	if not _check(schema_2_to_3_candidate.variables.size() == 3, "schema 2-to-3 migrated variable collection length"):
		return
	if not _check(schema_2_to_3_candidate.state_machines.size() == 2, "schema 2-to-3 migrated state-machine collection length"):
		return
	if not _check(schema_2_to_3_candidate.processes[0] is FlowProcess, "schema 2-to-3 migrated process at index 0"):
		return
	if not _check(schema_2_to_3_candidate.variables[0] is FlowVariableDefinition, "schema 2-to-3 migrated global variable at index 0"):
		return
	if not _check(schema_2_to_3_candidate.variables[2] is FlowVariableDefinition, "schema 2-to-3 migrated local variable at index 2"):
		return
	if not _check(schema_2_to_3_candidate.state_machines[1] is FlowStateMachineDefinition, "schema 2-to-3 migrated state machine at index 1"):
		return
	var schema_2_to_3_process_copy: FlowProcess = schema_2_to_3_candidate.processes[0]
	var schema_2_to_3_global_copy: FlowVariableDefinition = schema_2_to_3_candidate.variables[0]
	var schema_2_to_3_local_copy: FlowVariableDefinition = schema_2_to_3_candidate.variables[2]
	var schema_2_to_3_machine_copy: FlowStateMachineDefinition = schema_2_to_3_candidate.state_machines[1]
	if not _check(schema_2_to_3_machine_copy.states.size() >= 1, "schema 2-to-3 migrated state collection length"):
		return
	if not _check(schema_2_to_3_machine_copy.states[0] is FlowStateDefinition, "schema 2-to-3 migrated state at index 0"):
		return
	var schema_2_to_3_state_copy: FlowStateDefinition = schema_2_to_3_machine_copy.states[0]
	_check(schema_2_to_3_candidate != schema_2_to_3_source)
	_check(schema_2_to_3_candidate.schema_version == FlowGraph.SCHEMA_VERSION_3)
	_check(schema_2_to_3_candidate.get_internal_id() == schema_2_to_3_source_id)
	_check(schema_2_to_3_candidate.containers.is_empty())
	_check(schema_2_to_3_candidate.processes[1] == null)
	_check(schema_2_to_3_candidate.variables[1] == null)
	_check(schema_2_to_3_candidate.state_machines[0] == null)
	_check(schema_2_to_3_process_copy != schema_2_to_3_process)
	_check(schema_2_to_3_process_copy.get_internal_id() == schema_2_to_3_process.get_internal_id())
	if not _check(schema_2_to_3_process_copy.blocks.size() == 2, "schema 2-to-3 migrated process block collection length"):
		return
	if not _check(schema_2_to_3_process_copy.blocks[0] is FlowBlock, "schema 2-to-3 migrated process block at index 0"):
		return
	_check(schema_2_to_3_process_copy.blocks[0] != schema_2_to_3_block)
	_check(schema_2_to_3_process_copy.blocks[1] == null)
	_check(schema_2_to_3_process_copy.blocks[0].get_internal_id() == schema_2_to_3_block.get_internal_id())
	_check(schema_2_to_3_global_copy != schema_2_to_3_global)
	_check(schema_2_to_3_global_copy.get_internal_id() == schema_2_to_3_global.get_internal_id())
	_check(schema_2_to_3_local_copy != schema_2_to_3_local)
	_check(schema_2_to_3_local_copy.get_internal_id() == schema_2_to_3_local.get_internal_id())
	_check(schema_2_to_3_local_copy.owner_container_id == schema_2_to_3_process.get_internal_id())
	_check(schema_2_to_3_local_copy.global_variable_id == schema_2_to_3_global.get_internal_id())
	_check(schema_2_to_3_machine_copy != schema_2_to_3_machine)
	_check(schema_2_to_3_machine_copy.get_internal_id() == schema_2_to_3_machine.get_internal_id())
	_check(schema_2_to_3_machine_copy.states.size() == 2 and schema_2_to_3_machine_copy.states[1] == null)
	_check(schema_2_to_3_state_copy != schema_2_to_3_state)
	_check(schema_2_to_3_state_copy.get_internal_id() == schema_2_to_3_state.get_internal_id())
	_check(schema_2_to_3_state_copy.blocks[0] == null and schema_2_to_3_state_copy.blocks[1] != schema_2_to_3_state_block)
	_check(schema_2_to_3_state_copy.blocks[1].get_internal_id() == schema_2_to_3_state_block.get_internal_id())
	_check(schema_2_to_3_machine_copy.initial_state_id == schema_2_to_3_state.get_internal_id())
	_check(schema_2_to_3_candidate.constructor != null)
	_check(schema_2_to_3_candidate.constructor is FlowBlockContainer)
	_check(schema_2_to_3_candidate.constructor.get_internal_id().length() == 32)
	_check(schema_2_to_3_candidate.constructor.get_internal_id() != schema_2_to_3_source_id)
	_check(schema_2_to_3_candidate.constructor.blocks.is_empty())
	_check(schema_2_to_3_candidate.constructor.dependencies.is_empty())
	_check(schema_2_to_3_candidate.methods.is_empty())
	_check(not FlowGraphValidator.validate(schema_2_to_3_candidate).has_errors())
	schema_2_to_3_process_copy.display_name = "Candidate Process"
	schema_2_to_3_local_copy.owner_container_id = ""
	_check(schema_2_to_3_process.display_name != "Candidate Process")
	_check(schema_2_to_3_local.owner_container_id == schema_2_to_3_process.get_internal_id())
	_check(schema_2_to_3_source.schema_version == FlowGraph.SCHEMA_VERSION_2)
	_check(schema_2_to_3_source.get_internal_id() == schema_2_to_3_source_id)
	_check(schema_2_to_3_source.constructor == null and schema_2_to_3_source.methods.is_empty())
	_check(not FlowGraphValidator.validate(schema_2_to_3_source).has_errors())

	var schema_2_to_3_null_validation: FlowValidationResult = FlowGraphValidator.validate(null)
	var schema_2_to_3_null_result: FlowGraphMigrationResult = FlowGraphMigrator.migrate_schema_2_to_3(
		null
	)
	_check(schema_2_to_3_null_result.has_errors())
	_check(not schema_2_to_3_null_result.is_successful())
	_check(schema_2_to_3_null_result.migrated_graph == null)
	if not _check(
		schema_2_to_3_null_result.diagnostics.size() == schema_2_to_3_null_validation.diagnostics.size(),
		"schema 2-to-3 null-source diagnostic count"
	):
		return
	for schema_2_to_3_null_diagnostic_index: int in schema_2_to_3_null_validation.diagnostics.size():
		var expected_schema_2_to_3_null_diagnostic: FlowDiagnostic = _diagnostic_at(
			schema_2_to_3_null_validation,
			schema_2_to_3_null_diagnostic_index,
			"schema 2-to-3 null-source validation"
		)
		if expected_schema_2_to_3_null_diagnostic == null:
			return
		var actual_schema_2_to_3_null_diagnostic: FlowDiagnostic = _migration_diagnostic_at(
			schema_2_to_3_null_result,
			schema_2_to_3_null_diagnostic_index,
			"schema 2-to-3 null-source migration"
		)
		if actual_schema_2_to_3_null_diagnostic == null:
			return
		_check(actual_schema_2_to_3_null_diagnostic.code == expected_schema_2_to_3_null_diagnostic.code)
		_check(actual_schema_2_to_3_null_diagnostic.element_path == expected_schema_2_to_3_null_diagnostic.element_path)
		_check(actual_schema_2_to_3_null_diagnostic.related_id == expected_schema_2_to_3_null_diagnostic.related_id)
	var schema_2_to_3_null_diagnostic: FlowDiagnostic = _migration_diagnostic_at(
		schema_2_to_3_null_result,
		0,
		"schema 2-to-3 null-source expected diagnostic"
	)
	if schema_2_to_3_null_diagnostic == null:
		return
	_check(schema_2_to_3_null_diagnostic.code == FlowDiagnostic.CODE_NULL_GRAPH)
	_check(schema_2_to_3_null_diagnostic.element_path == "graph")
	_check(schema_2_to_3_null_diagnostic.related_id == "")

	var schema_2_to_3_wrong_schema: FlowGraph = FlowGraph.new()
	var schema_2_to_3_wrong_schema_result: FlowGraphMigrationResult = FlowGraphMigrator.migrate_schema_2_to_3(
		schema_2_to_3_wrong_schema
	)
	_check(not schema_2_to_3_wrong_schema_result.is_successful())
	_check(schema_2_to_3_wrong_schema_result.migrated_graph == null)
	if not _check(schema_2_to_3_wrong_schema_result.diagnostics.size() == 1, "schema 2-to-3 wrong-schema diagnostic count"):
		return
	var schema_2_to_3_wrong_schema_diagnostic: FlowDiagnostic = _migration_diagnostic_at(
		schema_2_to_3_wrong_schema_result,
		0,
		"schema 2-to-3 wrong schema"
	)
	if schema_2_to_3_wrong_schema_diagnostic == null:
		return
	_check(schema_2_to_3_wrong_schema_diagnostic.code == FlowDiagnostic.CODE_MIGRATION_SOURCE_SCHEMA)
	_check(schema_2_to_3_wrong_schema_diagnostic.element_path == "graph")
	_check(schema_2_to_3_wrong_schema_diagnostic.related_id == "")

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
	_check(not schema_2_to_3_mixed_first.is_successful())
	_check(schema_2_to_3_mixed_first.migrated_graph == null)
	if not _check(
		schema_2_to_3_mixed_first.diagnostics.size() == schema_2_to_3_mixed_second.diagnostics.size(),
		"schema 2-to-3 mixed-source diagnostic count"
	):
		return
	for schema_2_to_3_diagnostic_index: int in schema_2_to_3_mixed_first.diagnostics.size():
		var first_schema_2_to_3_diagnostic: FlowDiagnostic = _migration_diagnostic_at(
			schema_2_to_3_mixed_first,
			schema_2_to_3_diagnostic_index,
			"first schema 2-to-3 mixed source"
		)
		if first_schema_2_to_3_diagnostic == null:
			return
		var second_schema_2_to_3_diagnostic: FlowDiagnostic = _migration_diagnostic_at(
			schema_2_to_3_mixed_second,
			schema_2_to_3_diagnostic_index,
			"second schema 2-to-3 mixed source"
		)
		if second_schema_2_to_3_diagnostic == null:
			return
		_check(first_schema_2_to_3_diagnostic.code == second_schema_2_to_3_diagnostic.code)
		_check(first_schema_2_to_3_diagnostic.element_path == second_schema_2_to_3_diagnostic.element_path)
		_check(first_schema_2_to_3_diagnostic.related_id == second_schema_2_to_3_diagnostic.related_id)
	_check(_has_migration_diagnostic(schema_2_to_3_mixed_first, FlowDiagnostic.CODE_MIXED_SCHEMA_SOURCES))
	_check(schema_2_to_3_mixed_source.containers[0] == schema_2_to_3_legacy_container)

	var schema_2_to_3_schema_3_source: FlowGraph = FlowGraph.new()
	schema_2_to_3_schema_3_source.schema_version = FlowGraph.SCHEMA_VERSION_2
	var schema_2_to_3_incompatible_constructor: FlowConstructorDefinition = FlowConstructorDefinition.new()
	schema_2_to_3_schema_3_source.constructor = schema_2_to_3_incompatible_constructor
	var schema_2_to_3_schema_3_result: FlowGraphMigrationResult = FlowGraphMigrator.migrate_schema_2_to_3(
		schema_2_to_3_schema_3_source
	)
	_check(not schema_2_to_3_schema_3_result.is_successful())
	_check(schema_2_to_3_schema_3_result.migrated_graph == null)
	if not _check(schema_2_to_3_schema_3_result.diagnostics.size() == 1, "schema 2-to-3 incompatible-source diagnostic count"):
		return
	var schema_2_to_3_schema_3_diagnostic: FlowDiagnostic = _migration_diagnostic_at(
		schema_2_to_3_schema_3_result,
		0,
		"schema 2-to-3 incompatible source"
	)
	if schema_2_to_3_schema_3_diagnostic == null:
		return
	_check(schema_2_to_3_schema_3_diagnostic.code == FlowDiagnostic.CODE_MIXED_SCHEMA_SOURCES)
	_check(schema_2_to_3_schema_3_diagnostic.element_path == "graph")
	_check(schema_2_to_3_schema_3_diagnostic.related_id == "")
	_check(schema_2_to_3_schema_3_source.constructor == schema_2_to_3_incompatible_constructor)

	var schema_2_to_3_invalid_source: FlowGraph = FlowGraph.new()
	schema_2_to_3_invalid_source.schema_version = FlowGraph.SCHEMA_VERSION_2
	schema_2_to_3_invalid_source._internal_id = ""
	var schema_2_to_3_invalid_result: FlowGraphMigrationResult = FlowGraphMigrator.migrate_schema_2_to_3(
		schema_2_to_3_invalid_source
	)
	_check(not schema_2_to_3_invalid_result.is_successful())
	_check(schema_2_to_3_invalid_result.migrated_graph == null)
	if not _check(schema_2_to_3_invalid_result.diagnostics.size() == 1, "schema 2-to-3 invalid-source diagnostic count"):
		return
	var schema_2_to_3_invalid_diagnostic: FlowDiagnostic = _migration_diagnostic_at(
		schema_2_to_3_invalid_result,
		0,
		"schema 2-to-3 invalid source"
	)
	if schema_2_to_3_invalid_diagnostic == null:
		return
	_check(schema_2_to_3_invalid_diagnostic.code == FlowDiagnostic.CODE_EMPTY_INTERNAL_ID)
	_check(schema_2_to_3_invalid_diagnostic.element_path == "graph")
	_check(schema_2_to_3_invalid_diagnostic.related_id == "")
	_check(schema_2_to_3_invalid_source._internal_id == "")
	_test_method_call_foundation()
	_test_method_return_definition()
	_test_typed_variable_metadata_validation()
	_test_typed_variable_persistence_and_duplication()
	_test_flow_id_validation()
	_test_isolated_method_invalid_id_duplication()
	_test_isolated_method_duplication()
	_test_method_return_global_identity_collisions()



func _ready() -> void:
	await get_tree().process_frame
	_cleanup_smoke_temporary_resources()
	_run_smoke_tests()
	await get_tree().process_frame
	_finish_smoke_test()
