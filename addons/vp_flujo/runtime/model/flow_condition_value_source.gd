@tool
## Persistent semantic source for a Condition Tok.
class_name FlowConditionValueSource
extends FlowValueSource


const SOURCE_KIND: StringName = FlowValueSource.SOURCE_KIND_CONDITION
const PRODUCED_TYPE: Variant.Type = Variant.Type.TYPE_BOOL

@export var comparisons: Array[FlowConditionComparison] = []
@export_storage var connectors: Array[StringName] = []


func _init(
		new_comparisons: Array[FlowConditionComparison] = [],
		new_connectors: Array[StringName] = []
) -> void:
	comparisons = new_comparisons.duplicate()
	connectors = new_connectors.duplicate()


func get_source_kind() -> StringName:
	return SOURCE_KIND


func get_value_type() -> Variant.Type:
	return PRODUCED_TYPE


func get_produced_type() -> Variant.Type:
	return PRODUCED_TYPE


func get_value() -> Variant:
	return null


func resolve_value() -> Variant:
	return null


func get_preview(variable_graph: FlowGraph = null) -> String:
	var result: String = ""
	for index: int in comparisons.size():
		if index > 0:
			var connector_text: String = FlowConditionOperatorCatalog.connector_symbol(connectors[index - 1]) \
				if index - 1 < connectors.size() else ""
			if connector_text.is_empty():
				connector_text = "<unset>"
			result += " %s " % connector_text
		var comparison: FlowConditionComparison = comparisons[index]
		result += comparison.get_preview(variable_graph) if comparison != null else "<missing>"
	return result


func get_comparison_previews(variable_graph: FlowGraph = null) -> Array[String]:
	var result: Array[String] = []
	for comparison: FlowConditionComparison in comparisons:
		result.append(comparison.get_preview(variable_graph) if comparison != null else "<missing>")
	return result


func is_valid(variable_graph: FlowGraph = null) -> bool:
	var result: FlowValidationResult = validate_condition(variable_graph)
	return not result.has_errors()


func validate_condition(variable_graph: FlowGraph = null) -> FlowValidationResult:
	var result: FlowValidationResult = FlowValidationResult.new()
	_validate_into(result, "value_source", variable_graph)
	return result


func validate_structure(result: FlowValidationResult, element_path: String) -> void:
	_validate_into(result, element_path, null)


func validate_against_graph(result: FlowValidationResult, element_path: String, graph: FlowGraph) -> void:
	_validate_into(result, element_path, graph)


## Adds only graph-dependent reference diagnostics to an already structural pass.
func validate_graph_references(
		result: FlowValidationResult,
		element_path: String,
		graph: FlowGraph
) -> void:
	if result == null or graph == null:
		return
	for index: int in comparisons.size():
		var comparison: FlowConditionComparison = comparisons[index]
		if comparison == null:
			continue
		_validate_graph_operand(result, comparison.left_source,
			"%s.comparisons[%d].left_source" % [element_path, index], graph)
		_validate_graph_operand(result, comparison.right_source,
			"%s.comparisons[%d].right_source" % [element_path, index], graph)


func resolve(context: Variant = null) -> FlowValueResult:
	var resolution_context: FlowValueResolutionContext = context as FlowValueResolutionContext
	var graph: FlowGraph = resolution_context.graph 		if resolution_context != null else context as FlowGraph
	var validation: FlowValidationResult = validate_condition(graph)
	if validation.has_errors():
		return FlowValueResult.fail(PRODUCED_TYPE, _first_error(validation, "value_source"))
	var comparison_values: Array[bool] = []
	for comparison: FlowConditionComparison in comparisons:
		var left_result: FlowValueResult = comparison.left_source.resolve(context)
		if not left_result.success:
			return FlowValueResult.fail(PRODUCED_TYPE, left_result.diagnostic)
		var right_result: FlowValueResult = comparison.right_source.resolve(context)
		if not right_result.success:
			return FlowValueResult.fail(PRODUCED_TYPE, right_result.diagnostic)
		comparison_values.append(_compare(
			comparison.operator_id,
			left_result.value,
			left_result.value_type,
			right_result.value,
			right_result.value_type
		))
	return FlowValueResult.ok(_combine_values(comparison_values), PRODUCED_TYPE)


func duplicate_with_new_id() -> FlowValueSource:
	var copy: FlowConditionValueSource = duplicate(false) as FlowConditionValueSource
	copy._source_id = FlowId.create()
	copy.comparisons = []
	for comparison: FlowConditionComparison in comparisons:
		copy.comparisons.append(comparison.duplicate_with_new_id() if comparison != null else null)
	copy.connectors = connectors.duplicate()
	return copy


func _validate_into(
		result: FlowValidationResult,
		element_path: String,
		variable_graph: FlowGraph
) -> void:
	super.validate_structure(result, element_path)
	if comparisons.is_empty():
		_add_condition_error(result, FlowDiagnostic.CODE_CONDITION_COMPARISON_REQUIRED,
			"Condition requires at least one comparison.", element_path + ".comparisons", _source_id)
	var expected_connectors: int = maxi(0, comparisons.size() - 1)
	if connectors.size() != expected_connectors:
		_add_condition_error(result, FlowDiagnostic.CODE_CONDITION_CONNECTOR_COUNT_INVALID,
			"Condition connectors must contain exactly comparisons.size() - 1 entries.",
			element_path + ".connectors", _source_id)
	var seen_comparison_ids: Dictionary[String, String] = {}
	for index: int in comparisons.size():
		var comparison: FlowConditionComparison = comparisons[index]
		var comparison_path: String = "%s.comparisons[%d]" % [element_path, index]
		if comparison == null:
			_add_condition_error(result, FlowDiagnostic.CODE_CONDITION_SOURCE_NULL,
				"Condition comparison is null.", comparison_path, _source_id)
			continue
		if comparison.comparison_id.is_empty():
			_add_condition_error(result, FlowDiagnostic.CODE_CONDITION_COMPARISON_ID_EMPTY,
				"Condition comparison_id is required.", comparison_path + ".comparison_id")
		elif not FlowId.is_valid(comparison.comparison_id):
			_add_condition_error(result, FlowDiagnostic.CODE_CONDITION_COMPARISON_ID_INVALID,
				"Condition comparison_id is not a valid FlowId.", comparison_path + ".comparison_id",
				comparison.comparison_id)
		elif seen_comparison_ids.has(comparison.comparison_id):
			_add_condition_error(result, FlowDiagnostic.CODE_CONDITION_COMPARISON_ID_DUPLICATE,
				"Condition comparison_id is duplicated.", comparison_path + ".comparison_id",
				comparison.comparison_id)
		else:
			seen_comparison_ids[comparison.comparison_id] = comparison_path
		_validate_comparison(result, comparison, comparison_path, variable_graph)
	for index: int in connectors.size():
		if not FlowConditionOperatorCatalog.has_connector(connectors[index]):
			_add_condition_error(result, FlowDiagnostic.CODE_CONDITION_CONNECTOR_UNKNOWN,
				"Condition connector is unknown: %s." % String(connectors[index]),
				"%s.connectors[%d]" % [element_path, index], String(connectors[index]))


func _validate_comparison(
		result: FlowValidationResult,
		comparison: FlowConditionComparison,
		comparison_path: String,
		variable_graph: FlowGraph
) -> void:
	if comparison.operator_id.is_empty():
		_add_condition_error(result, FlowDiagnostic.CODE_CONDITION_OPERATOR_EMPTY,
			"Condition operator_id is required.", comparison_path + ".operator_id")
	elif not FlowConditionOperatorCatalog.has_operator(comparison.operator_id):
		_add_condition_error(result, FlowDiagnostic.CODE_CONDITION_OPERATOR_UNKNOWN,
			"Condition operator is unknown: %s." % String(comparison.operator_id),
			comparison_path + ".operator_id", String(comparison.operator_id))
	_validate_operand(result, comparison.left_source, comparison_path + ".left_source", variable_graph)
	_validate_operand(result, comparison.right_source, comparison_path + ".right_source", variable_graph)
	if comparison.left_source == null or comparison.right_source == null:
		return
	var signature: Dictionary = FlowConditionOperatorCatalog.find_signature(
		comparison.operator_id,
		comparison.left_source.get_value_type(),
		comparison.right_source.get_value_type()
	)
	if signature.is_empty():
		_add_condition_error(result, FlowDiagnostic.CODE_CONDITION_SIGNATURE_INCOMPATIBLE,
			"Condition operands do not match an exact comparison signature.",
			comparison_path, comparison.comparison_id)


func _validate_operand(
		result: FlowValidationResult,
		operand: FlowValueSource,
		operand_path: String,
		variable_graph: FlowGraph
) -> void:
	if operand == null:
		_add_condition_error(result, FlowDiagnostic.CODE_CONDITION_SOURCE_NULL,
			"Condition operand source is null.", operand_path, _source_id)
		return
	if not (operand is FlowLiteralValueSource or operand is FlowVariableRefValueSource):
		_add_condition_error(result, FlowDiagnostic.CODE_CONDITION_SOURCE_KIND_INVALID,
			"Condition operands accept only LiteralValueSource or VariableRefValueSource.",
			operand_path, operand.get_source_id())
	operand.validate_structure(result, operand_path)
	if variable_graph != null and operand is FlowVariableRefValueSource:
		_validate_graph_operand(result, operand, operand_path, variable_graph)


static func _validate_graph_operand(
		result: FlowValidationResult,
		operand: FlowValueSource,
		operand_path: String,
		variable_graph: FlowGraph
) -> void:
	if not operand is FlowVariableRefValueSource:
		return
	var variable_source: FlowVariableRefValueSource = operand as FlowVariableRefValueSource
	var variable: FlowVariableDefinition = variable_source.resolve_definition(variable_graph)
	if variable == null:
		_add_condition_error(result, FlowDiagnostic.CODE_VARIABLE_REFERENCE_MISSING,
			"VariableRef references a variable that is missing from the active FlowGraph.",
			operand_path + ".variable_id", variable_source.variable_id)
	elif variable.get_declared_variant_type() != variable_source.get_value_type():
		_add_condition_error(result, FlowDiagnostic.CODE_VARIABLE_REFERENCE_TYPE_MISMATCH,
			"VariableRef declared type does not match the resolved variable type.",
			operand_path + ".declared_value_type", variable_source.variable_id)


static func preview_source(source: FlowValueSource, variable_graph: FlowGraph = null) -> String:
	if source == null:
		return "<missing>"
	if source is FlowLiteralValueSource:
		var literal: FlowLiteralValueSource = source as FlowLiteralValueSource
		var text: String = literal.get_runtime_text()
		if literal.get_value_type() == Variant.Type.TYPE_STRING:
			return '"%s"' % text.replace('"', '\\"')
		return text if not text.is_empty() else "<missing>"
	if source is FlowVariableRefValueSource:
		var variable_source: FlowVariableRefValueSource = source as FlowVariableRefValueSource
		if variable_graph != null:
			var variable: FlowVariableDefinition = variable_source.resolve_definition(variable_graph)
			if variable != null:
				return variable.display_name
		return "<missing>"
	return "<missing>"


static func _compare(
		operator_id: StringName,
		left_value: Variant,
		left_type: Variant.Type,
		right_value: Variant,
		right_type: Variant.Type
) -> bool:
	var equal: bool
	if (left_type == Variant.Type.TYPE_BOOL and right_type == Variant.Type.TYPE_INT) \
			or (left_type == Variant.Type.TYPE_INT and right_type == Variant.Type.TYPE_BOOL):
		equal = int(left_value) == int(right_value)
	else:
		match left_type:
			Variant.Type.TYPE_BOOL:
				equal = bool(left_value) == bool(right_value)
			Variant.Type.TYPE_INT:
				equal = int(left_value) == int(right_value)
			Variant.Type.TYPE_FLOAT:
				equal = float(left_value) == float(right_value)
			Variant.Type.TYPE_STRING:
				equal = String(left_value) == String(right_value)
			_:
				equal = false
	if operator_id == FlowConditionOperatorCatalog.OPERATOR_EQUAL:
		return equal
	if operator_id == FlowConditionOperatorCatalog.OPERATOR_NOT_EQUAL:
		return not equal
	if left_type == Variant.Type.TYPE_INT:
		return _compare_numeric(operator_id, int(left_value), int(right_value))
	return _compare_numeric(operator_id, float(left_value), float(right_value))


static func _compare_numeric(operator_id: StringName, left_value: float, right_value: float) -> bool:
	match operator_id:
		FlowConditionOperatorCatalog.OPERATOR_GREATER_THAN:
			return left_value > right_value
		FlowConditionOperatorCatalog.OPERATOR_LESS_THAN:
			return left_value < right_value
		FlowConditionOperatorCatalog.OPERATOR_GREATER_OR_EQUAL:
			return left_value >= right_value
		FlowConditionOperatorCatalog.OPERATOR_LESS_OR_EQUAL:
			return left_value <= right_value
	return false


func _combine_values(values: Array[bool]) -> bool:
	if values.is_empty():
		return false
	var groups: Array[bool] = [values[0]]
	for index: int in range(1, values.size()):
		if connectors[index - 1] == FlowConditionOperatorCatalog.CONNECTOR_AND:
			groups[groups.size() - 1] = groups[groups.size() - 1] and values[index]
		else:
			groups.append(values[index])
	var result: bool = false
	for group: bool in groups:
		result = result or group
	return result


static func _first_error(result: FlowValidationResult, fallback_path: String) -> FlowDiagnostic:
	for diagnostic: FlowDiagnostic in result.diagnostics:
		if diagnostic.severity == FlowDiagnostic.Severity.ERROR:
			return diagnostic
	return FlowDiagnostic.new(
		FlowDiagnostic.CODE_CONDITION_INVALID,
		FlowDiagnostic.Severity.ERROR,
		"Condition is invalid.",
		fallback_path,
		""
	)


static func _add_condition_error(
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
