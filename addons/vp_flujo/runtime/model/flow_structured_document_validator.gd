@tool
## Validates structured documents without mutating, normalizing, or repairing them.
class_name FlowStructuredDocumentValidator
extends RefCounted


static func validate(
		document: FlowStructuredDocument,
		variable_graph: FlowGraph = null
) -> FlowValidationResult:
	var result: FlowValidationResult = FlowValidationResult.new()
	if document == null:
		_add_error(
			result,
			FlowDiagnostic.CODE_NULL_STRUCTURED_DOCUMENT,
			"FlowStructuredDocument is null.",
			"document"
		)
		return result

	if document.version != FlowStructuredDocument.CURRENT_VERSION:
		_add_error(
			result,
			FlowDiagnostic.CODE_UNSUPPORTED_STRUCTURED_DOCUMENT_VERSION,
			"Unsupported FlowStructuredDocument version: %d." % document.version,
			"version"
		)

	var seen_ids: Dictionary[String, String] = {}
	for segment_index: int in document.segments.size():
		var segment: FlowDocumentSegment = document.segments[segment_index]
		var segment_path: String = "segments[%d]" % segment_index
		if segment == null:
			_add_error(
				result,
				FlowDiagnostic.CODE_NULL_SEGMENT,
				"Structured document segment is null.",
				segment_path
			)
			continue

		_validate_segment_id(segment, segment_path, seen_ids, result)
		if segment is FlowTextSegment:
			continue
		if segment is FlowLiteralValueSegment:
			_validate_literal(segment as FlowLiteralValueSegment, segment_path, result)
			continue
		if segment is FlowVariableRefSegment:
			var variable_segment: FlowVariableRefSegment = segment as FlowVariableRefSegment
			variable_segment.validate_structure(result, segment_path)
			var variable_source: FlowVariableRefValueSource = \
				variable_segment.get_value_source() as FlowVariableRefValueSource
			if variable_source != null and variable_graph != null:
				var variable: FlowVariableDefinition = variable_source.resolve_definition(variable_graph)
				if variable == null:
					_add_error(
						result,
						FlowDiagnostic.CODE_VARIABLE_REFERENCE_MISSING,
						"VariableRef references a variable that is missing from the active FlowGraph.",
						segment_path + ".value_source.variable_id",
						variable_source.variable_id
					)
				elif variable.get_declared_variant_type() != variable_source.get_value_type():
					_add_error(
						result,
						FlowDiagnostic.CODE_VARIABLE_REFERENCE_TYPE_MISMATCH,
						"VariableRef declared type does not match the resolved variable type.",
						segment_path + ".value_source.declared_value_type",
						variable_source.variable_id
					)
			continue
		if segment is FlowExpressionSegment:
			var expression_segment: FlowExpressionSegment = segment as FlowExpressionSegment
			expression_segment.validate_structure(result, segment_path)
			if variable_graph != null:
				var expression_source: FlowExpressionValueSource = \
					expression_segment.get_value_source() as FlowExpressionValueSource
				if expression_source != null:
					expression_source.validate_against_graph(
						result,
						segment_path + ".value_source",
						variable_graph
					)
			continue
		if segment is FlowConditionSegment:
			var condition_segment: FlowConditionSegment = segment as FlowConditionSegment
			condition_segment.validate_structure(result, segment_path)
			var condition_source: FlowConditionValueSource = \
				condition_segment.get_value_source() as FlowConditionValueSource
			if condition_source != null and variable_graph != null:
				condition_source.validate_graph_references(
					result,
					segment_path + ".value_source",
					variable_graph
				)
			continue
		if segment is FlowChipSegment:
			(segment as FlowChipSegment).validate_structure(result, segment_path)
			_add_error(
				result,
				FlowDiagnostic.CODE_UNKNOWN_CHIP_TYPE,
				"Unsupported structured-document chip type: %s." % String((segment as FlowChipSegment).get_chip_type()),
				segment_path + ".chip_type",
				segment.get_segment_id()
			)
			continue

		_add_error(
			result,
			FlowDiagnostic.CODE_UNKNOWN_SEGMENT_TYPE,
			"Unsupported structured-document segment type: %s." % segment.get_class(),
			segment_path,
			segment.get_segment_id()
		)

	return result


static func _validate_segment_id(
		segment: FlowDocumentSegment,
		segment_path: String,
		seen_ids: Dictionary[String, String],
		result: FlowValidationResult
) -> void:
	var segment_id: String = segment.get_segment_id()
	if segment_id.is_empty():
		_add_error(
			result,
			FlowDiagnostic.CODE_EMPTY_SEGMENT_ID,
			"Structured-document segment ID is empty.",
			segment_path
		)
	elif not FlowId.is_valid(segment_id):
		_add_error(
			result,
			FlowDiagnostic.CODE_INVALID_SEGMENT_ID,
			"Structured-document segment ID is not a valid FlowId.",
			segment_path,
			segment_id
		)

	if not segment_id.is_empty():
		if seen_ids.has(segment_id):
			_add_error(
				result,
				FlowDiagnostic.CODE_DUPLICATE_SEGMENT_ID,
				"Structured-document segment ID is already used at %s." % seen_ids[segment_id],
				segment_path,
				segment_id
			)
		else:
			seen_ids[segment_id] = segment_path


static func _validate_literal(
		literal: FlowLiteralValueSegment,
		segment_path: String,
		result: FlowValidationResult
) -> void:
	var value_path: String = segment_path + ".value"
	var type_path: String = segment_path + ".value_type"
	if literal.value_type == Variant.Type.TYPE_NIL:
		_add_error(
			result,
			FlowDiagnostic.CODE_LITERAL_TYPE_NIL,
			"LiteralValue cannot use TYPE_NIL.",
			type_path,
			literal.get_segment_id()
		)
		return

	if not FlowLiteralValueSegment.is_allowed_type(literal.value_type):
		_add_error(
			result,
			FlowDiagnostic.CODE_INVALID_LITERAL_VALUE_TYPE,
			"LiteralValue uses an unsupported Variant.Type: %d." % int(literal.value_type),
			type_path,
			literal.get_segment_id()
		)
		return

	if typeof(literal.value) != literal.value_type:
		_add_error(
			result,
			FlowDiagnostic.CODE_LITERAL_VALUE_TYPE_MISMATCH,
			"LiteralValue explicit type does not match the stored Variant type.",
			value_path,
			literal.get_segment_id()
		)
		return

	if literal.value_type == FlowLiteralValueSegment.TYPE_FLOAT and not is_finite(float(literal.value)):
		_add_error(
			result,
			FlowDiagnostic.CODE_LITERAL_FLOAT_NOT_FINITE,
			"LiteralValue float must be finite.",
			value_path,
			literal.get_segment_id()
		)


static func _add_error(
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
