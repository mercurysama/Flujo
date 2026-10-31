extends Node


const TEMP_ROOT: String = "res://.godot/flujo_tests/condition_step_2c_c_1"
const RESOURCE_PATH: String = TEMP_ROOT + "/document.tres"

var _failures: Array[String] = []


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	_test_operator_matrix_and_bool_int()
	_test_invalid_signatures()
	_test_multi_comparison_and_precedence()
	_test_preview_and_missing_reference()
	_test_persistence_and_ids()
	_test_duplication()
	_test_generic_factory_support()
	_cleanup()
	_finish()


func _test_operator_matrix_and_bool_int() -> void:
	_check(FlowConditionOperatorCatalog.comparison_ids().size() == 6,
		"Condition catalog exposes six comparison operators.")
	_check(FlowConditionOperatorCatalog.connector_ids() == [&"and", &"or"],
		"Condition catalog exposes AND and OR connectors.")
	_check(_resolves(_condition(&"equal", _int(2), _int(2)), true), "int == int resolves true.")
	_check(_resolves(_condition(&"not_equal", _int(2), _int(3)), true), "int != int resolves true.")
	_check(_resolves(_condition(&"greater_than", _int(3), _int(2)), true), "int > int resolves true.")
	_check(_resolves(_condition(&"less_or_equal", _float(1.5), _float(1.5)), true),
		"float <= float resolves true.")
	_check(_resolves(_condition(&"equal", _string("hola"), _string("hola")), true),
		"String == String resolves true.")
	_check(_resolves(_condition(&"equal", _bool(true), _bool(true)), true),
		"bool == bool resolves true.")
	_check(_resolves(_condition(&"not_equal", _bool(true), _bool(false)), true),
		"bool != bool resolves true.")
	_check(_resolves(_condition(&"equal", _bool(true), _int(1)), true), "true == 1 resolves true.")
	_check(_resolves(_condition(&"equal", _bool(false), _int(0)), true), "false == 0 resolves true.")
	_check(_resolves(_condition(&"equal", _bool(true), _int(0)), false), "true == 0 resolves false.")
	_check(_resolves(_condition(&"equal", _bool(false), _int(1)), false), "false == 1 resolves false.")
	_check(_resolves(_condition(&"equal", _bool(true), _int(2)), false),
		"true == 2 resolves false without an error.")
	_check(_resolves(_condition(&"equal", _int(2), _bool(true)), false),
		"2 == true resolves false without an error.")
	_check(_resolves(_condition(&"not_equal", _bool(true), _int(2)), true),
		"bool != int inverts equality.")


func _test_invalid_signatures() -> void:
	_check(_has_code(_validation(_condition(&"greater_than", _bool(true), _int(1))),
		FlowDiagnostic.CODE_CONDITION_SIGNATURE_INCOMPATIBLE),
		"bool > int is rejected.")
	_check(_has_code(_validation(_condition(&"greater_than", _int(1), _bool(true))),
		FlowDiagnostic.CODE_CONDITION_SIGNATURE_INCOMPATIBLE),
		"int > bool is rejected.")
	_check(_has_code(_validation(_condition(&"equal", _int(1), _float(1.0))),
		FlowDiagnostic.CODE_CONDITION_SIGNATURE_INCOMPATIBLE),
		"int == float is rejected without promotion.")
	_check(_has_code(_validation(_condition(&"greater_than", _string("a"), _string("b"))),
		FlowDiagnostic.CODE_CONDITION_SIGNATURE_INCOMPATIBLE),
		"String > String is rejected.")
	_check(_condition(&"equal", _bool(true), _int(2)).get_value_type() == Variant.Type.TYPE_BOOL,
		"Invalidity does not change Condition produced type.")


func _test_multi_comparison_and_precedence() -> void:
	var and_condition: FlowConditionValueSource = FlowConditionValueSource.new([
		_comparison(&"equal", _bool(true), _bool(true)),
		_comparison(&"equal", _int(1), _int(2)),
	], [&"and"])
	_check(_resolves(and_condition, false), "Two comparisons with AND combine boolean results.")
	var or_condition: FlowConditionValueSource = FlowConditionValueSource.new([
		_comparison(&"equal", _bool(true), _bool(false)),
		_comparison(&"equal", _int(1), _int(1)),
	], [&"or"])
	_check(_resolves(or_condition, true), "Two comparisons with OR combine boolean results.")
	var ordered: FlowConditionValueSource = FlowConditionValueSource.new([
		_comparison(&"equal", _int(1), _int(1)),
		_comparison(&"equal", _int(2), _int(2)),
		_comparison(&"equal", _int(3), _int(4)),
	], [&"or", &"and"])
	_check(ordered.comparisons.size() == 3 and ordered.connectors == [&"or", &"and"],
		"Three comparisons preserve comparison ordering and connector positions.")
	_check(_resolves(ordered, true), "AND precedence is applied before OR.")
	_check(ordered.get_preview() == "1 == 1 OR 2 == 2 AND 3 == 4",
		"Condition preview preserves connector ordering.")
	var wrong_count: FlowConditionValueSource = FlowConditionValueSource.new([
		_comparison(&"equal", _int(1), _int(1)),
		_comparison(&"equal", _int(2), _int(2)),
	], [])
	_check(_has_code(_validation(wrong_count), FlowDiagnostic.CODE_CONDITION_CONNECTOR_COUNT_INVALID),
		"Connector count is validated against comparison count.")


func _test_preview_and_missing_reference() -> void:
	var graph: FlowGraph = FlowGraph.new()
	var health: FlowVariableDefinition = _variable("Health", FlowVariableDefinition.ValueType.INT)
	graph.variables = [health]
	var source: FlowConditionValueSource = FlowConditionValueSource.new([
		_comparison(&"greater_than", FlowVariableRefValueSource.new(
			health.get_internal_id(), health.value_type), _int(0)),
	], [])
	_check(source.get_preview(graph) == "Health > 0", "Variable preview resolves the current graph name.")
	health.display_name = "Current Health"
	_check(source.get_preview(graph) == "Current Health > 0", "Variable preview follows graph renames.")
	var string_condition: FlowConditionValueSource = _condition(&"not_equal", _string("hola"), _string("adios"))
	_check(string_condition.get_preview() == '"hola" != "adios"', "String literals are quoted in preview.")
	var missing: FlowConditionValueSource = _condition(&"equal",
		FlowVariableRefValueSource.new(FlowId.create(), FlowVariableDefinition.ValueType.INT), _int(0))
	_check(missing.get_preview(graph) == "<missing> == 0", "Missing references use a stable preview marker.")
	_check(_has_code(missing.validate_condition(graph), FlowDiagnostic.CODE_VARIABLE_REFERENCE_MISSING),
		"Missing graph variables are diagnosed.")
	_check(missing.resolve(graph).value_type == Variant.Type.TYPE_BOOL and not missing.resolve(graph).success,
		"Invalid conditions fail resolution while retaining bool result type.")


func _test_persistence_and_ids() -> void:
	var graph: FlowGraph = FlowGraph.new()
	var enabled: FlowVariableDefinition = _variable("Enabled", FlowVariableDefinition.ValueType.BOOL)
	graph.variables = [enabled]
	var variable_source: FlowVariableRefValueSource = FlowVariableRefValueSource.new(
		enabled.get_internal_id(), enabled.value_type)
	var condition: FlowConditionValueSource = FlowConditionValueSource.new([
		_comparison(&"equal", variable_source, _bool(true)),
		_comparison(&"not_equal", _string("hola"), _string("adios")),
	], [&"and"])
	var segment: FlowConditionSegment = FlowConditionSegment.new(condition)
	segment.slot_id = "condition"
	var document: FlowStructuredDocument = FlowStructuredDocument.new()
	document.segments = [segment]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TEMP_ROOT))
	_check(ResourceSaver.save(document, RESOURCE_PATH) == OK, "Condition saves through ResourceSaver.")
	var loaded: FlowStructuredDocument = ResourceLoader.load(
		RESOURCE_PATH, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as FlowStructuredDocument
	_check(loaded != null and loaded.segments[0] is FlowConditionSegment,
		"ResourceLoader preserves the concrete Condition segment.")
	if loaded == null:
		return
	var loaded_segment: FlowConditionSegment = loaded.segments[0] as FlowConditionSegment
	var loaded_source: FlowConditionValueSource = loaded_segment.get_value_source() as FlowConditionValueSource
	_check(loaded_segment.segment_id == segment.segment_id and loaded_source.source_id == condition.source_id,
		"Persistence preserves segment and Condition source IDs.")
	_check(loaded_source.comparisons[0].comparison_id == condition.comparisons[0].comparison_id \
			and loaded_source.comparisons[1].comparison_id == condition.comparisons[1].comparison_id,
		"Persistence preserves comparison IDs and ordering.")
	_check(loaded_source.connectors == [&"and"] and loaded_source.comparisons[0].operator_id == &"equal",
		"Persistence preserves connectors and operator IDs.")
	var loaded_variable: FlowVariableRefValueSource = \
		loaded_source.comparisons[0].left_source as FlowVariableRefValueSource
	var loaded_literal: FlowLiteralValueSource = loaded_source.comparisons[1].left_source as FlowLiteralValueSource
	_check(loaded_variable.variable_id == enabled.get_internal_id() \
			and loaded_literal.get_value_type() == Variant.Type.TYPE_STRING \
			and loaded_literal.get_value() == "hola",
		"Persistence preserves VariableRef IDs and Literal type/value.")
	_check(not FlowStructuredDocumentValidator.validate(loaded, graph).has_errors(),
		"Reloaded Condition validates through the generic structured-document boundary.")


func _test_duplication() -> void:
	var original: FlowConditionValueSource = FlowConditionValueSource.new([
		_comparison(&"equal", _int(1), _int(1)),
		_comparison(&"not_equal", _bool(true), _int(0)),
	], [&"and"])
	var copy: FlowConditionValueSource = original.duplicate_with_new_id() as FlowConditionValueSource
	_check(copy.source_id != original.source_id, "Condition duplication creates a new source ID.")
	_check(copy.comparisons.size() == original.comparisons.size() and copy.connectors == original.connectors,
		"Condition duplication preserves order and connectors.")
	_check(copy.comparisons[0].comparison_id != original.comparisons[0].comparison_id,
		"Condition duplication creates new comparison IDs.")
	_check(copy.comparisons[0].left_source.source_id != original.comparisons[0].left_source.source_id,
		"Condition duplication deep-copies left sources.")
	copy.connectors[0] = &"or"
	_check(original.connectors[0] == &"and", "Condition duplication does not share mutable connector arrays.")


func _test_generic_factory_support() -> void:
	var schema: FlowChipFieldSchema = FlowChipFieldSchema.new()
	schema.mode = FlowChipFieldSchema.Mode.FIXED
	schema.accepted_value_types = [Variant.Type.TYPE_BOOL]
	schema.accepted_source_kinds = [FlowValueSource.SOURCE_KIND_CONDITION]
	var slot: FlowChipSlotDefinition = FlowChipSlotDefinition.new("condition", "Condition", true)
	slot.accepted_value_types = [Variant.Type.TYPE_BOOL]
	slot.accepted_source_kinds = [FlowValueSource.SOURCE_KIND_CONDITION]
	slot.initial_value_source = _condition(&"equal", _bool(true), _bool(true))
	schema.slots = [slot]
	var factory_result: FlowChipFieldCreationResult = FlowChipFieldFactory.new().create(schema)
	_check(factory_result.is_successful() and factory_result.document.segments[0] is FlowConditionSegment,
		"Generic chip factory creates a Condition segment without UI-specific construction.")


func _condition(operator_id: StringName, left: FlowValueSource, right: FlowValueSource) -> FlowConditionValueSource:
	return FlowConditionValueSource.new([_comparison(operator_id, left, right)], [])


func _comparison(operator_id: StringName, left: FlowValueSource, right: FlowValueSource) -> FlowConditionComparison:
	return FlowConditionComparison.new(operator_id, left, right)


func _resolves(condition: FlowConditionValueSource, expected: bool) -> bool:
	var result: FlowValueResult = condition.resolve()
	return _check(result.success and result.value_type == Variant.Type.TYPE_BOOL and result.value == expected,
		"Condition resolution matches the expected boolean result.")


func _validation(condition: FlowConditionValueSource) -> FlowValidationResult:
	return condition.validate_condition()


func _int(value: int) -> FlowLiteralValueSource:
	return FlowLiteralValueSource.new(FlowLiteralValueSource.TYPE_INT, value)


func _float(value: float) -> FlowLiteralValueSource:
	return FlowLiteralValueSource.new(FlowLiteralValueSource.TYPE_FLOAT, value)


func _bool(value: bool) -> FlowLiteralValueSource:
	return FlowLiteralValueSource.new(FlowLiteralValueSource.TYPE_BOOL, value)


func _string(value: String) -> FlowLiteralValueSource:
	return FlowLiteralValueSource.new(FlowLiteralValueSource.TYPE_STRING, value)


func _variable(name: String, value_type: FlowVariableDefinition.ValueType) -> FlowVariableDefinition:
	var variable: FlowVariableDefinition = FlowVariableDefinition.new()
	variable.display_name = name
	variable.value_type = value_type
	return variable


func _has_code(result: FlowValidationResult, code: StringName) -> bool:
	for diagnostic: FlowDiagnostic in result.diagnostics:
		if diagnostic.code == code:
			return true
	return false


func _cleanup() -> void:
	var absolute_path: String = ProjectSettings.globalize_path(RESOURCE_PATH)
	if FileAccess.file_exists(absolute_path):
		DirAccess.remove_absolute(absolute_path)
	var absolute_root: String = ProjectSettings.globalize_path(TEMP_ROOT)
	if DirAccess.dir_exists_absolute(absolute_root):
		DirAccess.remove_absolute(absolute_root)


func _check(condition: bool, message: String) -> bool:
	if condition:
		return true
	_failures.append(message)
	push_error("[Flujo] Condition model check failed: " + message)
	return false


func _finish() -> void:
	if _failures.is_empty():
		print("[Flujo] Flow Condition Step 2C-C.1 model test passed")
	else:
		push_error("[Flujo] Flow Condition Step 2C-C.1 model test failed: %d failures" % _failures.size())
	get_tree().quit(0 if _failures.is_empty() else 1)
