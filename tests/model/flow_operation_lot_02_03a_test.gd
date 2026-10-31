extends Node


const TEMP_ROOT: String = "res://.godot/flujo_tests/operation_lot_02_03a"
const RESOURCE_PATH: String = TEMP_ROOT + "/operation_document.tres"
const TYPES_PATH: String = TEMP_ROOT + "/basic_types_document.tres"

var _failures: Array[String] = []


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	_test_catalog()
	_test_arithmetic_resolution()
	_test_zero_failures()
	_test_concat()
	_test_runtime_variable_context()
	_test_vector_operations()
	_test_basic_literal_types()
	_test_duplication()
	_test_operation_persistence()
	_test_basic_types_persistence()
	_cleanup()
	_finish()


func _test_catalog() -> void:
	_check(
		FlowOperationOperatorCatalog.operator_ids().size() == 6,
		"Operation catalog exposes six MVP operators."
	)
	_check(
		not FlowOperationOperatorCatalog.find_signature(
			&"add",
			[Variant.Type.TYPE_INT, Variant.Type.TYPE_FLOAT]
		).is_empty() == false,
		"Operation catalog rejects implicit int/float promotion."
	)
	_check(
		FlowOperationOperatorCatalog.find_signature(
			&"concat",
			[Variant.Type.TYPE_STRING, Variant.Type.TYPE_STRING]
		).get("produced_type", Variant.Type.TYPE_NIL) == Variant.Type.TYPE_STRING,
		"String concatenation has an exact String signature."
	)


func _test_arithmetic_resolution() -> void:
	_check_result(
		_operation(&"add", _int(7), _int(5)).resolve(),
		12,
		Variant.Type.TYPE_INT,
		"int addition resolves."
	)
	_check_result(
		_operation(&"subtract", _float(7.5), _float(2.0)).resolve(),
		5.5,
		Variant.Type.TYPE_FLOAT,
		"float subtraction resolves."
	)
	_check_result(
		_operation(&"multiply", _int(6), _int(4)).resolve(),
		24,
		Variant.Type.TYPE_INT,
		"int multiplication resolves."
	)
	_check_result(
		_operation(&"divide", _int(-5), _int(2)).resolve(),
		-2,
		Variant.Type.TYPE_INT,
		"integer division truncates toward zero."
	)
	_check_result(
		_operation(&"divide", _float(5.0), _float(2.0)).resolve(),
		2.5,
		Variant.Type.TYPE_FLOAT,
		"float division resolves."
	)
	_check_result(
		_operation(&"modulo", _int(17), _int(5)).resolve(),
		2,
		Variant.Type.TYPE_INT,
		"integer modulo resolves."
	)


func _test_zero_failures() -> void:
	var division: FlowValueResult = _operation(
		&"divide",
		_int(9),
		_int(0)
	).resolve()
	_check(
		not division.success
			and division.diagnostic != null
			and division.diagnostic.code == FlowDiagnostic.CODE_OPERATION_DIVISION_BY_ZERO,
		"Division by zero returns a structured failure."
	)
	var modulo: FlowValueResult = _operation(
		&"modulo",
		_int(9),
		_int(0)
	).resolve()
	_check(
		not modulo.success
			and modulo.diagnostic != null
			and modulo.diagnostic.code == FlowDiagnostic.CODE_OPERATION_MODULO_BY_ZERO,
		"Modulo by zero returns a structured failure."
	)


func _test_concat() -> void:
	var result: FlowValueResult = _operation(
		&"concat",
		_string("Hola "),
		_string("Flujo")
	).resolve()
	_check_result(
		result,
		"Hola Flujo",
		Variant.Type.TYPE_STRING,
		"String concatenation resolves."
	)


func _test_runtime_variable_context() -> void:
	var graph: FlowGraph = FlowGraph.new()
	var count: FlowVariableDefinition = FlowVariableDefinition.new()
	count.display_name = "Count"
	count.value_type = FlowVariableDefinition.ValueType.INT
	count.int_value = 3
	graph.variables = [count]

	var variable: FlowVariableRefValueSource = FlowVariableRefValueSource.new(
		count.get_internal_id(),
		count.value_type
	)
	var operation: FlowOperationValueSource = _operation(
		&"add",
		variable,
		_int(2)
	)
	var legacy_result: FlowValueResult = operation.resolve(graph)
	_check_result(
		legacy_result,
		5,
		Variant.Type.TYPE_INT,
		"FlowGraph compatibility resolution uses the authored variable value."
	)

	var context: FlowValueResolutionContext = FlowValueResolutionContext.new(graph)
	context.set_variable_value(count.get_internal_id(), 40)
	var runtime_result: FlowValueResult = operation.resolve(context)
	_check_result(
		runtime_result,
		42,
		Variant.Type.TYPE_INT,
		"Resolution context overrides the authored value without mutating the definition."
	)
	_check(
		count.int_value == 3,
		"Runtime resolution does not mutate FlowVariableDefinition."
	)

	context.set_variable_value(count.get_internal_id(), "wrong")
	var mismatch: FlowValueResult = operation.resolve(context)
	_check(
		not mismatch.success
			and mismatch.diagnostic != null
			and mismatch.diagnostic.code == FlowDiagnostic.CODE_VALUE_RESOLUTION_TYPE_MISMATCH,
		"Runtime variable type mismatch returns a structured failure."
	)


func _test_vector_operations() -> void:
	var v2_result: FlowValueResult = _operation(
		&"add",
		FlowLiteralValueSource.new(Variant.Type.TYPE_VECTOR2, Vector2(1.0, 2.0)),
		FlowLiteralValueSource.new(Variant.Type.TYPE_VECTOR2, Vector2(3.0, 4.0))
	).resolve()
	_check_result(
		v2_result,
		Vector2(4.0, 6.0),
		Variant.Type.TYPE_VECTOR2,
		"Vector2 addition resolves."
	)

	var v3_result: FlowValueResult = _operation(
		&"subtract",
		FlowLiteralValueSource.new(Variant.Type.TYPE_VECTOR3, Vector3(5.0, 7.0, 9.0)),
		FlowLiteralValueSource.new(Variant.Type.TYPE_VECTOR3, Vector3(1.0, 2.0, 3.0))
	).resolve()
	_check_result(
		v3_result,
		Vector3(4.0, 5.0, 6.0),
		Variant.Type.TYPE_VECTOR3,
		"Vector3 subtraction resolves."
	)


func _test_basic_literal_types() -> void:
	var cases: Array[Dictionary] = [
		{"type": Variant.Type.TYPE_VECTOR2, "value": Vector2(1.25, -2.5)},
		{"type": Variant.Type.TYPE_VECTOR2I, "value": Vector2i(3, -4)},
		{"type": Variant.Type.TYPE_VECTOR3, "value": Vector3(1.0, 2.0, 3.0)},
		{"type": Variant.Type.TYPE_VECTOR3I, "value": Vector3i(-1, 2, -3)},
		{"type": Variant.Type.TYPE_COLOR, "value": Color(0.1, 0.2, 0.3, 0.4)},
		{"type": Variant.Type.TYPE_NODE_PATH, "value": NodePath("Player/Camera")},
	]
	for data: Dictionary in cases:
		var value_type: Variant.Type = int(data["type"])
		var literal: FlowLiteralValueSource = FlowLiteralValueSource.new(
			value_type,
			data["value"]
		)
		_check(
			literal.is_valid(),
			"Basic literal type %s validates." 				% FlowChipTypeDescriptor.variant_type_display_name(value_type)
		)
		var resolved: FlowValueResult = literal.resolve()
		_check_result(
			resolved,
			data["value"],
			value_type,
			"Basic literal type resolves with exact Variant.Type."
		)
		_check(
			not literal.get_runtime_text().is_empty(),
			"Basic literal type has deterministic preview text."
		)


func _test_duplication() -> void:
	var original: FlowOperationValueSource = _operation(
		&"add",
		_int(1),
		_int(2)
	)
	var copy: FlowOperationValueSource = 		original.duplicate_with_new_id() as FlowOperationValueSource
	_check(
		copy != null
			and copy.source_id != original.source_id
			and copy.operator_id == original.operator_id,
		"Operation duplication creates a new source identity and preserves semantics."
	)
	_check(
		copy.operands.size() == 2
			and copy.operands[0].source_id != original.operands[0].source_id
			and copy.operands[1].source_id != original.operands[1].source_id,
		"Operation duplication deep-copies operand source identities."
	)


func _test_operation_persistence() -> void:
	var source: FlowOperationValueSource = _operation(
		&"subtract",
		_int(9),
		_int(4)
	)
	var segment: FlowOperationSegment = FlowOperationSegment.new(source)
	segment.slot_id = "operation"
	segment.slot_kind = FlowChipSegment.SLOT_KIND_VARIADIC
	var document: FlowStructuredDocument = FlowStructuredDocument.new()
	document.segments = [segment]

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TEMP_ROOT))
	_check(
		ResourceSaver.save(document, RESOURCE_PATH) == OK,
		"Operation document saves."
	)
	var loaded: FlowStructuredDocument = ResourceLoader.load(
		RESOURCE_PATH,
		"",
		ResourceLoader.CACHE_MODE_IGNORE_DEEP
	) as FlowStructuredDocument
	_check(
		loaded != null
			and not loaded.segments.is_empty()
			and loaded.segments[0] is FlowOperationSegment,
		"Operation segment survives ResourceLoader."
	)
	if loaded == null or loaded.segments.is_empty():
		return
	var loaded_segment: FlowOperationSegment = loaded.segments[0] as FlowOperationSegment
	var loaded_source: FlowOperationValueSource = 		loaded_segment.get_value_source() as FlowOperationValueSource
	_check(
		loaded_segment.segment_id == segment.segment_id
			and loaded_segment.slot_id == "operation"
			and loaded_source != null
			and loaded_source.source_id == source.source_id
			and loaded_source.operator_id == &"subtract"
			and loaded_source.operands.size() == 2
			and loaded_source.operands[0].source_id == source.operands[0].source_id
			and loaded_source.operands[1].source_id == source.operands[1].source_id,
		"Operation persistence preserves IDs, slot metadata, operator and operand order."
	)
	_check_result(
		loaded_source.resolve(),
		5,
		Variant.Type.TYPE_INT,
		"Reloaded Operation resolves."
	)


func _test_basic_types_persistence() -> void:
	var values: Array[FlowDocumentSegment] = [
		FlowLiteralValueSegment.new(Variant.Type.TYPE_VECTOR2, Vector2(1.0, 2.0)),
		FlowLiteralValueSegment.new(Variant.Type.TYPE_VECTOR2I, Vector2i(3, 4)),
		FlowLiteralValueSegment.new(Variant.Type.TYPE_VECTOR3, Vector3(5.0, 6.0, 7.0)),
		FlowLiteralValueSegment.new(Variant.Type.TYPE_VECTOR3I, Vector3i(8, 9, 10)),
		FlowLiteralValueSegment.new(Variant.Type.TYPE_COLOR, Color(0.2, 0.4, 0.6, 0.8)),
		FlowLiteralValueSegment.new(Variant.Type.TYPE_NODE_PATH, NodePath("Root/Child")),
	]
	var document: FlowStructuredDocument = FlowStructuredDocument.new()
	document.segments = values
	_check(
		not FlowStructuredDocumentValidator.validate(document).has_errors(),
		"Structured document accepts all Lot 03A literal types."
	)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TEMP_ROOT))
	_check(
		ResourceSaver.save(document, TYPES_PATH) == OK,
		"Basic-types document saves."
	)
	var loaded: FlowStructuredDocument = ResourceLoader.load(
		TYPES_PATH,
		"",
		ResourceLoader.CACHE_MODE_IGNORE_DEEP
	) as FlowStructuredDocument
	_check(
		loaded != null and loaded.segments.size() == values.size(),
		"Basic-types document reloads with all values."
	)
	if loaded == null or loaded.segments.size() != values.size():
		return
	for index: int in values.size():
		var before: FlowLiteralValueSegment = values[index] as FlowLiteralValueSegment
		var after: FlowLiteralValueSegment = loaded.segments[index] as FlowLiteralValueSegment
		_check(
			after != null
				and after.value_type == before.value_type
				and after.value == before.value,
			"Basic literal round-trip preserves exact type/value at index %d." % index
		)


func _operation(
		operator_id: StringName,
		left: FlowValueSource,
		right: FlowValueSource
) -> FlowOperationValueSource:
	return FlowOperationValueSource.new(operator_id, [left, right])


func _int(value: int) -> FlowLiteralValueSource:
	return FlowLiteralValueSource.new(Variant.Type.TYPE_INT, value)


func _float(value: float) -> FlowLiteralValueSource:
	return FlowLiteralValueSource.new(Variant.Type.TYPE_FLOAT, value)


func _string(value: String) -> FlowLiteralValueSource:
	return FlowLiteralValueSource.new(Variant.Type.TYPE_STRING, value)


func _check_result(
		result: FlowValueResult,
		expected_value: Variant,
		expected_type: Variant.Type,
		message: String
) -> void:
	_check(
		result != null
			and result.success
			and result.value_type == expected_type
			and typeof(result.value) == expected_type
			and result.value == expected_value,
		message
	)


func _cleanup() -> void:
	for path: String in [RESOURCE_PATH, TYPES_PATH]:
		var absolute_path: String = ProjectSettings.globalize_path(path)
		if FileAccess.file_exists(absolute_path):
			DirAccess.remove_absolute(absolute_path)
	var absolute_root: String = ProjectSettings.globalize_path(TEMP_ROOT)
	if DirAccess.dir_exists_absolute(absolute_root):
		DirAccess.remove_absolute(absolute_root)


func _check(condition: bool, message: String) -> bool:
	if condition:
		return true
	_failures.append(message)
	push_error("[Flujo] Operation Lot 02/03A check failed: " + message)
	return false


func _finish() -> void:
	if _failures.is_empty():
		print("[Flujo] Operation Tok Lot 02 + Godot Types 03A test passed")
	else:
		push_error(
			"[Flujo] Operation Tok Lot 02 + Godot Types 03A test failed: %d failures" 				% _failures.size()
		)
	get_tree().quit(0 if _failures.is_empty() else 1)
