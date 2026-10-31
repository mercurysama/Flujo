extends Node


const TEMP_ROOT: String = "res://.godot/flujo_tests/expression_step_2c_b"
const RESOURCE_PATH: String = TEMP_ROOT + "/document.tres"

var _failures: Array[String] = []


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	_test_catalog_and_exact_signatures()
	_test_operations_batch_signatures()
	_test_expression_validation_and_produced_type()
	_test_graph_resolution_and_missing_variable()
	_test_duplication()
	_test_persistence()
	_test_real_count_save_load_reopen()
	_cleanup()
	_finish()


func _test_catalog_and_exact_signatures() -> void:
	_check(FlowExpressionOperatorCatalog.operator_ids().size() == 9,
		"The extended catalog exposes four legacy and five new operators.")
	_check(FlowExpressionOperatorCatalog.has_operator(&"add"), "Catalog exposes add.")
	_check(FlowExpressionOperatorCatalog.has_operator(&"greater_than"),
		"Catalog exposes greater_than.")
	_check(FlowExpressionOperatorCatalog.has_operator(&"equal"), "Catalog exposes equal.")
	_check(FlowExpressionOperatorCatalog.has_operator(&"and"), "Catalog exposes and.")
	_check(FlowExpressionOperatorCatalog.has_operator(&"multiply"),
		"Catalog exposes multiply.")
	_check(FlowExpressionOperatorCatalog.find_signature(&"add", [Variant.Type.TYPE_INT, Variant.Type.TYPE_INT]).get("produced_type", -1) == Variant.Type.TYPE_INT,
		"int + int selects int.")
	_check(FlowExpressionOperatorCatalog.find_signature(&"add", [Variant.Type.TYPE_FLOAT, Variant.Type.TYPE_FLOAT]).get("produced_type", -1) == Variant.Type.TYPE_FLOAT,
		"float + float selects float.")
	_check(FlowExpressionOperatorCatalog.find_signature(&"add", [Variant.Type.TYPE_STRING, Variant.Type.TYPE_STRING]).get("produced_type", -1) == Variant.Type.TYPE_STRING,
		"String + String selects String.")
	_check(FlowExpressionOperatorCatalog.find_signature(&"add", [Variant.Type.TYPE_INT, Variant.Type.TYPE_FLOAT]).is_empty(),
		"int + float has no implicit promotion signature.")
	_check(FlowExpressionOperatorCatalog.find_signature(&"add", [Variant.Type.TYPE_FLOAT, Variant.Type.TYPE_INT]).is_empty(),
		"float + int has no implicit promotion signature.")
	_check(FlowExpressionOperatorCatalog.find_signature(&"equal", [Variant.Type.TYPE_BOOL, Variant.Type.TYPE_BOOL]).get("produced_type", -1) == Variant.Type.TYPE_BOOL,
		"bool == bool selects bool.")
	_check(FlowExpressionOperatorCatalog.find_signature(&"and", [Variant.Type.TYPE_BOOL, Variant.Type.TYPE_BOOL]).get("produced_type", -1) == Variant.Type.TYPE_BOOL,
		"bool AND bool selects bool.")


func _test_operations_batch_signatures() -> void:
	var cases: Array[Dictionary] = [
		{"id": &"subtract", "type": Variant.Type.TYPE_INT, "symbol": "-"},
		{"id": &"subtract", "type": Variant.Type.TYPE_FLOAT, "symbol": "-"},
		{"id": &"multiply", "type": Variant.Type.TYPE_INT, "symbol": "*"},
		{"id": &"multiply", "type": Variant.Type.TYPE_FLOAT, "symbol": "*"},
		{"id": &"divide", "type": Variant.Type.TYPE_INT, "symbol": "/"},
		{"id": &"divide", "type": Variant.Type.TYPE_FLOAT, "symbol": "/"},
		{"id": &"modulo", "type": Variant.Type.TYPE_INT, "symbol": "%"},
		{"id": &"concat", "type": Variant.Type.TYPE_STRING, "symbol": "+"},
	]
	for data: Dictionary in cases:
		var operator_id: StringName = data["id"]
		var value_type: Variant.Type = data["type"]
		var signature: Dictionary = FlowExpressionOperatorCatalog.find_signature(
			operator_id, [value_type, value_type]
		)
		_check(not signature.is_empty() and int(signature.get("produced_type", -1)) == int(value_type),
			"Exact operator signature: %s with type %d" % [String(operator_id), int(value_type)])
		_check(FlowExpressionOperatorCatalog.symbol(operator_id) == String(data["symbol"]),
			"Expected preview symbol for %s" % String(operator_id))
	var invalid: Array[Dictionary] = [
		{"id": &"subtract", "left": Variant.Type.TYPE_STRING, "right": Variant.Type.TYPE_STRING},
		{"id": &"multiply", "left": Variant.Type.TYPE_BOOL, "right": Variant.Type.TYPE_BOOL},
		{"id": &"divide", "left": Variant.Type.TYPE_INT, "right": Variant.Type.TYPE_FLOAT},
		{"id": &"modulo", "left": Variant.Type.TYPE_FLOAT, "right": Variant.Type.TYPE_FLOAT},
		{"id": &"concat", "left": Variant.Type.TYPE_INT, "right": Variant.Type.TYPE_INT},
	]
	for data: Dictionary in invalid:
		_check(FlowExpressionOperatorCatalog.find_signature(
			data["id"], [data["left"], data["right"]]
		).is_empty(), "Mixed or unsupported signature is rejected: %s" % String(data["id"]))
	var concat: FlowExpressionValueSource = FlowExpressionValueSource.new(
		&"concat", [_literal_string("Hola"), _literal_string(" mundo")]
	)
	_check(concat.is_valid() and concat.get_value_type() == Variant.Type.TYPE_STRING \
			and concat.get_preview() == '"Hola" + " mundo"',
		"String concatenation is valid and generates an escaped preview.")
	var arithmetic: FlowExpressionValueSource = FlowExpressionValueSource.new(
		&"subtract", [_literal_int(9), _literal_int(4)]
	)
	_check(arithmetic.is_valid() and arithmetic.get_preview() == "9 - 4",
		"Subtract preview uses the persisted operator ID.")
	var doc: FlowStructuredDocument = FlowStructuredDocument.new()
	doc.segments = [FlowExpressionSegment.new(arithmetic)]
	_check(not FlowStructuredDocumentValidator.validate(doc).has_errors(),
		"Extended operator validates as structured document data.")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TEMP_ROOT))
	_check(ResourceSaver.save(doc, RESOURCE_PATH) == OK,
		"Extended operator persists as a Resource.")
	var reopened: FlowStructuredDocument = ResourceLoader.load(
		RESOURCE_PATH, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP
	) as FlowStructuredDocument
	var persisted: FlowExpressionValueSource = 		(reopened.segments[0] as FlowExpressionSegment).get_value_source() as FlowExpressionValueSource 		if reopened != null and not reopened.segments.is_empty() else null
	_check(persisted != null and persisted.operator_id == &"subtract" 			and persisted.get_preview() == "9 - 4",
		"Resource round-trip preserves a new operator ID and operands.")


func _test_expression_validation_and_produced_type() -> void:
	var expression: FlowExpressionValueSource = FlowExpressionValueSource.new(
		&"greater_than",
		[_literal_int(2), _literal_int(0)]
	)
	_check(expression.get_value_type() == Variant.Type.TYPE_BOOL,
		"Produced type derives from the selected operator signature.")
	_check(expression.get_preview() == "2 > 0", "Preview is generated from structure.")
	var valid: FlowValidationResult = FlowValidationResult.new()
	expression.validate_structure(valid, "expression")
	_check(not valid.has_errors(), "A valid int comparison has no diagnostics.")

	var wrong_arity: FlowExpressionValueSource = FlowExpressionValueSource.new(
		&"and", [_literal_bool(true)]
	)
	var arity_result: FlowValidationResult = FlowValidationResult.new()
	wrong_arity.validate_structure(arity_result, "expression")
	_check(_has_code(arity_result, FlowDiagnostic.CODE_EXPRESSION_ARITY_INVALID),
		"Wrong arity uses a stable expression diagnostic.")

	var unknown: FlowExpressionValueSource = FlowExpressionValueSource.new(
		&"unknown", [_literal_int(1), _literal_int(2)]
	)
	var unknown_result: FlowValidationResult = FlowValidationResult.new()
	unknown.validate_structure(unknown_result, "expression")
	_check(_has_code(unknown_result, FlowDiagnostic.CODE_EXPRESSION_OPERATOR_UNKNOWN),
		"Unknown operators are diagnosed without repair.")


func _test_graph_resolution_and_missing_variable() -> void:
	var graph: FlowGraph = FlowGraph.new()
	var count: FlowVariableDefinition = _variable("Count", FlowVariableDefinition.ValueType.INT)
	graph.variables = [count]
	var source: FlowVariableRefValueSource = FlowVariableRefValueSource.new(
		count.get_internal_id(), count.value_type
	)
	var expression: FlowExpressionValueSource = FlowExpressionValueSource.new(
		&"add", [source, _literal_int(1)]
	)
	var document: FlowStructuredDocument = FlowStructuredDocument.new()
	document.segments = [FlowExpressionSegment.new(expression)]
	var valid: FlowValidationResult = FlowStructuredDocumentValidator.validate(document, graph)
	_check(not valid.has_errors(), "A graph-resolved VariableRef operand validates.")
	_check(expression.get_preview(graph) == "Count + 1",
		"VariableRef preview resolves the visible graph name only as presentation.")
	count.display_name = "Renamed Count"
	_check(expression.get_preview(graph) == "Renamed Count + 1" and source.variable_id == count.get_internal_id(),
		"Graph rename changes preview without changing variable_id.")

	var missing: FlowExpressionValueSource = FlowExpressionValueSource.new(
		&"greater_than",
		[FlowVariableRefValueSource.new(FlowId.create(), FlowVariableDefinition.ValueType.INT), _literal_int(0)]
	)
	var missing_document: FlowStructuredDocument = FlowStructuredDocument.new()
	missing_document.segments = [FlowExpressionSegment.new(missing)]
	var missing_result: FlowValidationResult = FlowStructuredDocumentValidator.validate(
		missing_document, graph
	)
	_check(_has_code(missing_result, FlowDiagnostic.CODE_VARIABLE_REFERENCE_MISSING),
		"Missing expression VariableRef operands remain bound and invalid.")


func _test_duplication() -> void:
	var variable_id: String = FlowId.create()
	var original_source: FlowExpressionValueSource = FlowExpressionValueSource.new(
		&"equal",
		[FlowVariableRefValueSource.new(variable_id, FlowVariableDefinition.ValueType.STRING), _literal_string("ok")]
	)
	var original_segment: FlowExpressionSegment = FlowExpressionSegment.new(original_source)
	original_segment.slot_id = "condition"
	var original: FlowStructuredDocument = FlowStructuredDocument.new()
	original.segments = [original_segment]
	var copy: FlowStructuredDocument = original.duplicate_with_new_ids()
	var copied_segment: FlowExpressionSegment = copy.segments[0] as FlowExpressionSegment
	var copied_source: FlowExpressionValueSource = copied_segment.get_value_source() as FlowExpressionValueSource
	_check(copied_segment.segment_id != original_segment.segment_id,
		"Expression duplication creates a new segment_id.")
	_check(copied_source.source_id != original_source.source_id,
		"Expression duplication creates a new source_id.")
	_check(copied_source.operator_id == original_source.operator_id and copied_segment.slot_id == "condition",
		"Expression duplication preserves operator_id and slot_id.")
	_check((copied_source.operands[0] as FlowVariableRefValueSource).source_id != original_source.operands[0].source_id,
		"Expression duplication creates independent operand source IDs.")
	_check((copied_source.operands[0] as FlowVariableRefValueSource).variable_id == variable_id,
		"Expression duplication preserves the external variable_id.")


func _test_persistence() -> void:
	var expression: FlowExpressionValueSource = FlowExpressionValueSource.new(
		&"and", [_literal_bool(true), _literal_bool(false)]
	)
	var segment: FlowExpressionSegment = FlowExpressionSegment.new(expression)
	segment.slot_id = "condition"
	segment.slot_kind = FlowChipSegment.SLOT_KIND_NAMED
	var document: FlowStructuredDocument = FlowStructuredDocument.new()
	document.segments = [segment]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TEMP_ROOT))
	_check(ResourceSaver.save(document, RESOURCE_PATH) == OK, "Expression document saves through ResourceSaver.")
	var loaded: FlowStructuredDocument = ResourceLoader.load(
		RESOURCE_PATH, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP
	) as FlowStructuredDocument
	_check(loaded != null and loaded.segments[0] is FlowExpressionSegment,
		"ResourceLoader preserves the concrete Expression segment.")
	if loaded == null:
		return
	var loaded_source: FlowExpressionValueSource = \
		(loaded.segments[0] as FlowExpressionSegment).get_value_source() as FlowExpressionValueSource
	_check(loaded_source != null and loaded_source.operator_id == &"and" \
			and loaded_source.operands.size() == 2,
		"Persistence preserves operator and operand order.")
	_check(loaded_source != null and loaded_source.get_value_type() == Variant.Type.TYPE_BOOL \
			and loaded.segments[0].get_segment_id() == segment.get_segment_id() \
			and (loaded.segments[0] as FlowExpressionSegment).slot_id == "condition",
		"Persistence preserves produced type, segment identity, and slot identity.")


func _test_real_count_save_load_reopen() -> void:
	var graph: FlowGraph = FlowGraph.new()
	var count: FlowVariableDefinition = _variable("Count", FlowVariableDefinition.ValueType.INT)
	graph.variables = [count]
	var source: FlowExpressionValueSource = FlowExpressionValueSource.new(
		&"add",
		[
			FlowVariableRefValueSource.new(count.get_internal_id(), count.value_type),
			_literal_int(1),
		]
	)
	var segment: FlowExpressionSegment = FlowExpressionSegment.new(source)
	segment.slot_id = "expression"
	segment.slot_kind = FlowChipSegment.SLOT_KIND_VARIADIC
	var document: FlowStructuredDocument = FlowStructuredDocument.new()
	document.segments = [segment]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TEMP_ROOT))
	_check(ResourceSaver.save(document, RESOURCE_PATH) == OK,
		"Real Count + 1 focal saves a FlowStructuredDocument Resource.")
	var reopened: FlowStructuredDocument = ResourceLoader.load(
		RESOURCE_PATH, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP
	) as FlowStructuredDocument
	_check(reopened != null, "Real Count + 1 focal reopens the saved Resource.")
	if reopened == null:
		return
	var reopened_segment: FlowExpressionSegment = reopened.segments[0] as FlowExpressionSegment
	var reopened_source: FlowExpressionValueSource = \
		reopened_segment.get_value_source() as FlowExpressionValueSource
	var validation: FlowValidationResult = FlowStructuredDocumentValidator.validate(reopened, graph)
	_check(not validation.has_errors(), "Reopened Count + 1 validates against the persisted graph.")
	_check(reopened_segment.segment_id == segment.segment_id \
			and reopened_segment.slot_id == "expression" \
			and reopened_segment.slot_kind == FlowChipSegment.SLOT_KIND_VARIADIC,
		"Reopen preserves segment_id, slot_id, and variadic slot kind.")
	_check(reopened_source != null and reopened_source.operator_id == &"add" \
			and reopened_source.operands.size() == 2 \
			and reopened_source.source_id == source.source_id \
			and (reopened_source.operands[0] as FlowVariableRefValueSource).source_id == source.operands[0].source_id \
			and (reopened_source.operands[1] as FlowLiteralValueSource).source_id == source.operands[1].source_id \
			and (reopened_source.operands[0] as FlowVariableRefValueSource).variable_id == count.get_internal_id() \
			and (reopened_source.operands[1] as FlowLiteralValueSource).get_value_type() == FlowLiteralValueSource.TYPE_INT \
			and (reopened_source.operands[1] as FlowLiteralValueSource).get_value() == 1,
		"Reopen preserves operator, operand order, variable_id, literal type, and literal value.")
	_check(reopened_source != null and reopened_source.get_preview(graph) == "Count + 1",
		"Preview regenerates as Count + 1 after Resource reopen.")


func _literal_int(value: int) -> FlowLiteralValueSource:
	return FlowLiteralValueSource.new(FlowLiteralValueSource.TYPE_INT, value)


func _literal_bool(value: bool) -> FlowLiteralValueSource:
	return FlowLiteralValueSource.new(FlowLiteralValueSource.TYPE_BOOL, value)


func _literal_string(value: String) -> FlowLiteralValueSource:
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
	push_error("[Flujo] Expression model check failed: " + message)
	return false


func _finish() -> void:
	if _failures.is_empty():
		print("[Flujo] Flow Expression Step 2C-B model test passed")
	else:
		push_error("[Flujo] Flow Expression Step 2C-B model test failed: %d failures" % _failures.size())
	get_tree().quit(0 if _failures.is_empty() else 1)
