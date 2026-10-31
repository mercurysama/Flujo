@tool
## Persistent executable value source for one Operation Tok.
class_name FlowOperationValueSource
extends FlowValueSource


const SOURCE_KIND: StringName = FlowValueSource.SOURCE_KIND_OPERATION

@export_storage var operator_id: StringName = &""
@export_storage var operands: Array[FlowValueSource] = []


func _init(
		new_operator_id: StringName = &"",
		new_operands: Array[FlowValueSource] = []
) -> void:
	operator_id = new_operator_id
	operands = new_operands.duplicate()


func get_source_kind() -> StringName:
	return SOURCE_KIND


func get_value_type() -> Variant.Type:
	var signature: Dictionary = get_selected_signature()
	return int(signature.get("produced_type", Variant.Type.TYPE_NIL)) as Variant.Type


func get_selected_signature() -> Dictionary:
	var operand_types: Array[Variant.Type] = []
	for operand: FlowValueSource in operands:
		if operand == null:
			return {}
		operand_types.append(operand.get_value_type())
	return FlowOperationOperatorCatalog.find_signature(operator_id, operand_types)


func get_preview(variable_graph: FlowGraph = null) -> String:
	var symbol_value: String = FlowOperationOperatorCatalog.symbol(operator_id)
	if symbol_value.is_empty():
		symbol_value = "<unset>"
	var labels: Array[String] = []
	for operand: FlowValueSource in operands:
		labels.append(_operand_preview(operand, variable_graph))
	return (" %s " % symbol_value).join(labels)


func get_operand_summary(variable_graph: FlowGraph = null) -> String:
	var values: Array[String] = []
	for operand: FlowValueSource in operands:
		values.append(_operand_preview(operand, variable_graph))
	return ", ".join(values)


func is_valid() -> bool:
	if not FlowId.is_valid(_source_id) 			or not FlowOperationOperatorCatalog.has_operator(operator_id):
		return false
	if operands.size() != 2 or get_selected_signature().is_empty():
		return false
	for operand: FlowValueSource in operands:
		if operand == null or not _is_allowed_operand(operand) or not operand.is_valid():
			return false
	return true


func validate_structure(result: FlowValidationResult, element_path: String) -> void:
	super.validate_structure(result, element_path)
	if result == null:
		return
	if operator_id.is_empty():
		_add_error(
			result,
			FlowDiagnostic.CODE_OPERATION_OPERATOR_EMPTY,
			"Operation operator_id is empty.",
			element_path + ".operator_id",
			_source_id
		)
	elif not FlowOperationOperatorCatalog.has_operator(operator_id):
		_add_error(
			result,
			FlowDiagnostic.CODE_OPERATION_OPERATOR_UNKNOWN,
			"Operation operator is unknown: %s." % String(operator_id),
			element_path + ".operator_id",
			String(operator_id)
		)
	var descriptor: Dictionary = FlowOperationOperatorCatalog.get_descriptor(operator_id)
	var expected_arity: int = int(descriptor.get("arity", -1)) 		if not descriptor.is_empty() else -1
	if expected_arity >= 0 and operands.size() != expected_arity:
		_add_error(
			result,
			FlowDiagnostic.CODE_OPERATION_ARITY_INVALID,
			"Operation expects %d operands, got %d." % [expected_arity, operands.size()],
			element_path + ".operands",
			_source_id
		)
	for index: int in operands.size():
		var operand: FlowValueSource = operands[index]
		var path: String = "%s.operands[%d]" % [element_path, index]
		if operand == null:
			_add_error(
				result,
				FlowDiagnostic.CODE_OPERATION_OPERAND_NULL,
				"Operation operand is null.",
				path,
				_source_id
			)
			continue
		if not _is_allowed_operand(operand):
			_add_error(
				result,
				FlowDiagnostic.CODE_OPERATION_OPERAND_KIND_INVALID,
				"Operation operands accept LiteralValue or VariableRef sources.",
				path,
				operand.get_source_id()
			)
		operand.validate_structure(result, path)
	if expected_arity == operands.size() 			and not operands.is_empty() 			and get_selected_signature().is_empty():
		_add_error(
			result,
			FlowDiagnostic.CODE_OPERATION_SIGNATURE_INCOMPATIBLE,
			"Operation operands do not match an exact operator signature.",
			element_path + ".operands",
			_source_id
		)


func validate_against_graph(
		result: FlowValidationResult,
		element_path: String,
		graph: FlowGraph
) -> void:
	if result == null or graph == null:
		return
	for index: int in operands.size():
		var variable_source: FlowVariableRefValueSource = 			operands[index] as FlowVariableRefValueSource
		if variable_source == null:
			continue
		var variable: FlowVariableDefinition = variable_source.resolve_definition(graph)
		if variable == null:
			_add_error(
				result,
				FlowDiagnostic.CODE_VARIABLE_REFERENCE_MISSING,
				"VariableRef references a variable missing from the active FlowGraph.",
				"%s.operands[%d].variable_id" % [element_path, index],
				variable_source.variable_id
			)
		elif variable.get_declared_variant_type() != variable_source.get_value_type():
			_add_error(
				result,
				FlowDiagnostic.CODE_VARIABLE_REFERENCE_TYPE_MISMATCH,
				"VariableRef declared type does not match the resolved variable type.",
				"%s.operands[%d].declared_value_type" % [element_path, index],
				variable_source.variable_id
			)


func resolve(context: Variant = null) -> FlowValueResult:
	var graph: FlowGraph = context.graph 		if context is FlowValueResolutionContext else context as FlowGraph
	var validation: FlowValidationResult = FlowValidationResult.new()
	validate_structure(validation, "operation")
	validate_against_graph(validation, "operation", graph)
	if validation.has_errors():
		return FlowValueResult.fail(
			get_value_type(),
			validation.diagnostics[0] as FlowDiagnostic
		)
	var results: Array[FlowValueResult] = []
	for operand: FlowValueSource in operands:
		var resolved: FlowValueResult = operand.resolve(context)
		if not resolved.success:
			return FlowValueResult.fail(get_value_type(), resolved.diagnostic)
		results.append(resolved)
	return _evaluate(results[0], results[1])


func duplicate_with_new_id() -> FlowValueSource:
	var copy: FlowOperationValueSource = duplicate(false) as FlowOperationValueSource
	copy._source_id = FlowId.create()
	copy.operands = []
	for operand: FlowValueSource in operands:
		copy.operands.append(
			operand.duplicate_with_new_id() if operand != null else null
		)
	return copy


func _evaluate(left: FlowValueResult, right: FlowValueResult) -> FlowValueResult:
	match operator_id:
		FlowOperationOperatorCatalog.OPERATOR_ADD:
			return FlowValueResult.ok(left.value + right.value, get_value_type())
		FlowOperationOperatorCatalog.OPERATOR_SUBTRACT:
			return FlowValueResult.ok(left.value - right.value, get_value_type())
		FlowOperationOperatorCatalog.OPERATOR_MULTIPLY:
			return FlowValueResult.ok(left.value * right.value, get_value_type())
		FlowOperationOperatorCatalog.OPERATOR_DIVIDE:
			if (right.value_type == Variant.Type.TYPE_INT and int(right.value) == 0) 					or (right.value_type == Variant.Type.TYPE_FLOAT 					and float(right.value) == 0.0):
				return _runtime_error(
					FlowDiagnostic.CODE_OPERATION_DIVISION_BY_ZERO,
					"Operation division by zero."
				)
			if get_value_type() == Variant.Type.TYPE_INT:
				return FlowValueResult.ok(
					int(float(left.value) / float(right.value)),
					Variant.Type.TYPE_INT
				)
			return FlowValueResult.ok(
				float(left.value) / float(right.value),
				Variant.Type.TYPE_FLOAT
			)
		FlowOperationOperatorCatalog.OPERATOR_MODULO:
			if int(right.value) == 0:
				return _runtime_error(
					FlowDiagnostic.CODE_OPERATION_MODULO_BY_ZERO,
					"Operation modulo by zero."
				)
			return FlowValueResult.ok(
				int(left.value) % int(right.value),
				Variant.Type.TYPE_INT
			)
		FlowOperationOperatorCatalog.OPERATOR_CONCAT:
			return FlowValueResult.ok(
				String(left.value) + String(right.value),
				Variant.Type.TYPE_STRING
			)
	return _runtime_error(
		FlowDiagnostic.CODE_OPERATION_OPERATOR_UNKNOWN,
		"Operation operator cannot be evaluated."
	)


func _runtime_error(code: StringName, message: String) -> FlowValueResult:
	return FlowValueResult.fail(
		get_value_type(),
		FlowDiagnostic.new(
			code,
			FlowDiagnostic.Severity.ERROR,
			message,
			"operation",
			_source_id
		)
	)


func _is_allowed_operand(operand: FlowValueSource) -> bool:
	return operand is FlowLiteralValueSource or operand is FlowVariableRefValueSource


static func _operand_preview(operand: FlowValueSource, graph: FlowGraph) -> String:
	if operand == null:
		return "<unset>"
	if operand is FlowLiteralValueSource:
		var literal: FlowLiteralValueSource = operand as FlowLiteralValueSource
		if not literal.is_valid():
			return "<unset>"
		var text: String = literal.get_runtime_text()
		if literal.get_value_type() == Variant.Type.TYPE_STRING:
			return '"%s"' % text.replace('"', '\"')
		return text
	if operand is FlowVariableRefValueSource:
		var variable_source: FlowVariableRefValueSource = 			operand as FlowVariableRefValueSource
		if variable_source.variable_id.is_empty():
			return "<missing>"
		var definition: FlowVariableDefinition = 			variable_source.resolve_definition(graph)
		return definition.display_name 			if definition != null else "<missing:%s>" % variable_source.variable_id
	return "<unsupported>"


static func _add_error(
		result: FlowValidationResult,
		code: StringName,
		message: String,
		path: String,
		related_id: String = ""
) -> void:
	result.add_diagnostic(FlowDiagnostic.new(
		code,
		FlowDiagnostic.Severity.ERROR,
		message,
		path,
		related_id
	))
