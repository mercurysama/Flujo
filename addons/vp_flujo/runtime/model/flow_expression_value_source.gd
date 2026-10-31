@tool
## Structural, non-evaluating value source for one Step 2C-B expression.
class_name FlowExpressionValueSource
extends FlowValueSource


const SOURCE_KIND: StringName = FlowValueSource.SOURCE_KIND_EXPRESSION

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


func get_value() -> Variant:
	# Expressions are structural data in this MVP; runtime evaluation is deferred.
	return null


func resolve_value() -> Variant:
	return null


func get_selected_signature() -> Dictionary:
	var operand_types: Array[Variant.Type] = []
	for operand: FlowValueSource in operands:
		if operand == null:
			return {}
		operand_types.append(operand.get_value_type())
	return FlowExpressionOperatorCatalog.find_signature(operator_id, operand_types)


func get_produced_type() -> Variant.Type:
	return get_value_type()


func get_preview(variable_graph: FlowGraph = null) -> String:
	var symbol_value: String = FlowExpressionOperatorCatalog.symbol(operator_id)
	if symbol_value.is_empty():
		return "<unknown:%s>" % String(operator_id)
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
	if not FlowId.is_valid(_source_id) or not FlowExpressionOperatorCatalog.has_operator(operator_id):
		return false
	if operands.size() != 2:
		return false
	for operand: FlowValueSource in operands:
		if operand == null or not _is_allowed_operand(operand) or not operand.is_valid():
			return false
	return not get_selected_signature().is_empty()


func validate_structure(result: FlowValidationResult, element_path: String) -> void:
	super.validate_structure(result, element_path)
	if result == null:
		return
	if operator_id.is_empty():
		_add_expression_error(result, FlowDiagnostic.CODE_EXPRESSION_OPERATOR_EMPTY,
			"Expression operator_id is empty.", element_path + ".operator_id", _source_id)
	elif not FlowExpressionOperatorCatalog.has_operator(operator_id):
		_add_expression_error(result, FlowDiagnostic.CODE_EXPRESSION_OPERATOR_UNKNOWN,
			"Expression operator is unknown: %s." % String(operator_id),
			element_path + ".operator_id", String(operator_id))
	var descriptor: Dictionary = FlowExpressionOperatorCatalog.get_descriptor(operator_id)
	var expected_arity: int = int(descriptor.get("arity", -1)) if not descriptor.is_empty() else -1
	if expected_arity >= 0 and operands.size() != expected_arity:
		_add_expression_error(result, FlowDiagnostic.CODE_EXPRESSION_ARITY_INVALID,
			"Expression operator expects %d operands, got %d." % [expected_arity, operands.size()],
			element_path + ".operands", _source_id)
	for index: int in operands.size():
		var operand: FlowValueSource = operands[index]
		var operand_path: String = "%s.operands[%d]" % [element_path, index]
		if operand == null:
			_add_expression_error(result, FlowDiagnostic.CODE_EXPRESSION_OPERAND_NULL,
				"Expression operand is null.", operand_path, _source_id)
			continue
		if not _is_allowed_operand(operand):
			_add_expression_error(result, FlowDiagnostic.CODE_EXPRESSION_OPERAND_KIND_INVALID,
				"Expression operands accept only LiteralValue or VariableRef sources.",
				operand_path, operand.get_source_id())
		operand.validate_structure(result, operand_path)
	if not FlowExpressionOperatorCatalog.find_signature(operator_id, _operand_types()).is_empty():
		return
	if expected_arity == operands.size() and not operands.is_empty():
		_add_expression_error(result, FlowDiagnostic.CODE_EXPRESSION_SIGNATURE_INCOMPATIBLE,
			"Expression operands do not match an exact operator signature.",
			element_path + ".operands", _source_id)


func validate_against_graph(
		result: FlowValidationResult,
		element_path: String,
		variable_graph: FlowGraph
) -> void:
	if result == null or variable_graph == null:
		return
	for index: int in operands.size():
		var variable_source: FlowVariableRefValueSource = operands[index] as FlowVariableRefValueSource
		if variable_source == null:
			continue
		var variable: FlowVariableDefinition = variable_source.resolve_definition(variable_graph)
		if variable == null:
			_add_expression_error(result, FlowDiagnostic.CODE_VARIABLE_REFERENCE_MISSING,
				"VariableRef references a variable that is missing from the active FlowGraph.",
				"%s.operands[%d].variable_id" % [element_path, index], variable_source.variable_id)
		elif variable.get_declared_variant_type() != variable_source.get_value_type():
			_add_expression_error(result, FlowDiagnostic.CODE_VARIABLE_REFERENCE_TYPE_MISMATCH,
				"VariableRef declared type does not match the resolved variable type.",
				"%s.operands[%d].declared_value_type" % [element_path, index], variable_source.variable_id)


func duplicate_with_new_id() -> FlowValueSource:
	var copy: FlowExpressionValueSource = duplicate(false) as FlowExpressionValueSource
	copy._source_id = FlowId.create()
	copy.operands = []
	for operand: FlowValueSource in operands:
		copy.operands.append(operand.duplicate_with_new_id() if operand != null else null)
	return copy


func _operand_types() -> Array[Variant.Type]:
	var result: Array[Variant.Type] = []
	for operand: FlowValueSource in operands:
		result.append(Variant.Type.TYPE_NIL if operand == null else operand.get_value_type())
	return result


func _is_allowed_operand(operand: FlowValueSource) -> bool:
	return operand is FlowLiteralValueSource or operand is FlowVariableRefValueSource


func _operand_preview(operand: FlowValueSource, variable_graph: FlowGraph) -> String:
	if operand == null:
		return "<null>"
	if operand is FlowLiteralValueSource:
		var literal: FlowLiteralValueSource = operand as FlowLiteralValueSource
		var text: String = literal.get_runtime_text()
		if literal.get_value_type() == Variant.Type.TYPE_STRING:
			return '"%s"' % text.replace('"', '\\"')
		return text if not text.is_empty() else "<invalid literal>"
	if operand is FlowVariableRefValueSource:
		var variable_source: FlowVariableRefValueSource = operand as FlowVariableRefValueSource
		if variable_source.variable_id.is_empty():
			return "<missing>"
		if variable_graph != null:
			var variable: FlowVariableDefinition = variable_source.resolve_definition(variable_graph)
			if variable != null:
				return variable.display_name
		return "<missing:%s>" % variable_source.variable_id
	return "<unsupported:%s>" % String(operand.get_source_kind())


static func _add_expression_error(
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
