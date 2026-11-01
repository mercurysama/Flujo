@tool
## Runtime bridge from one Akis document to either text or one typed value.
class_name FlowStructuredDocumentResolver
extends RefCounted


static func resolve_text(
		document: FlowStructuredDocument,
		context: FlowValueResolutionContext = null
) -> FlowStructuredRenderResult:
	var result: FlowStructuredRenderResult = FlowStructuredRenderResult.new()
	var graph: FlowGraph = context.graph if context != null else null
	var validation: FlowValidationResult = FlowStructuredDocumentValidator.validate(
		document,
		graph
	)
	for diagnostic: FlowDiagnostic in validation.diagnostics:
		result.add_diagnostic(diagnostic)
	if result.has_errors():
		return result

	var rendered: String = ""
	for index: int in document.segments.size():
		var segment: FlowDocumentSegment = document.segments[index]
		if segment is FlowTextSegment:
			rendered += (segment as FlowTextSegment).text
			continue
		var chip: FlowChipSegment = segment as FlowChipSegment
		if chip == null:
			result.add_diagnostic(_diagnostic(
				FlowDiagnostic.CODE_UNKNOWN_SEGMENT_TYPE,
				"Structured document contains a non-text segment that is not a Tok.",
				"segments[%d]" % index,
				segment.get_segment_id() if segment != null else ""
			))
			return result
		var source: FlowValueSource = chip.get_value_source()
		if source == null:
			result.add_diagnostic(_diagnostic(
				FlowDiagnostic.CODE_NULL_VALUE_SOURCE,
				"Structured Tok has no ValueSource.",
				"segments[%d].value_source" % index,
				chip.get_segment_id()
			))
			return result
		var value_result: FlowValueResult = source.resolve(context)
		if value_result == null or not value_result.success:
			result.add_diagnostic(
				value_result.diagnostic
				if value_result != null and value_result.diagnostic != null
				else _diagnostic(
					FlowDiagnostic.CODE_STRUCTURED_VALUE_RESOLUTION_FAILED,
					"Structured Tok failed to resolve.",
					"segments[%d].value_source" % index,
					chip.get_segment_id()
				)
			)
			return result
		rendered += format_runtime_value(value_result.value)

	result.text = rendered
	return result


static func resolve_value(
		document: FlowStructuredDocument,
		context: FlowValueResolutionContext = null
) -> FlowValueResult:
	var graph: FlowGraph = context.graph if context != null else null
	var validation: FlowValidationResult = FlowStructuredDocumentValidator.validate(
		document,
		graph
	)
	if validation.has_errors():
		return FlowValueResult.fail(
			Variant.Type.TYPE_NIL,
			_first_error(validation)
		)

	var candidate: FlowChipSegment = null
	for index: int in document.segments.size():
		var segment: FlowDocumentSegment = document.segments[index]
		if segment is FlowTextSegment:
			if not (segment as FlowTextSegment).text.strip_edges().is_empty():
				return FlowValueResult.fail(
					Variant.Type.TYPE_NIL,
					_diagnostic(
						FlowDiagnostic.CODE_STRUCTURED_VALUE_SHAPE_INVALID,
						"A typed Akis value cannot contain runtime text.",
						"segments[%d]" % index,
						segment.get_segment_id()
					)
				)
			continue
		if not segment is FlowChipSegment or candidate != null:
			return FlowValueResult.fail(
				Variant.Type.TYPE_NIL,
				_diagnostic(
					FlowDiagnostic.CODE_STRUCTURED_VALUE_SHAPE_INVALID,
					"A typed Akis value requires exactly one Tok.",
					"segments[%d]" % index,
					segment.get_segment_id() if segment != null else ""
				)
			)
		candidate = segment as FlowChipSegment

	if candidate == null:
		return FlowValueResult.fail(
			Variant.Type.TYPE_NIL,
			_diagnostic(
				FlowDiagnostic.CODE_STRUCTURED_VALUE_SHAPE_INVALID,
				"A typed Akis value requires exactly one Tok.",
				"segments"
			)
		)
	var source: FlowValueSource = candidate.get_value_source()
	if source == null:
		return FlowValueResult.fail(
			Variant.Type.TYPE_NIL,
			_diagnostic(
				FlowDiagnostic.CODE_NULL_VALUE_SOURCE,
				"Structured Tok has no ValueSource.",
				"segments.value_source",
				candidate.get_segment_id()
			)
		)
	return source.resolve(context)


static func format_runtime_value(value: Variant) -> String:
	match typeof(value):
		Variant.Type.TYPE_NIL:
			return "null"
		Variant.Type.TYPE_BOOL:
			return "true" if bool(value) else "false"
		Variant.Type.TYPE_STRING, Variant.Type.TYPE_STRING_NAME:
			return String(value)
		Variant.Type.TYPE_OBJECT:
			if value == null:
				return "null"
			if value is Node:
				return (value as Node).name
			if value is Resource:
				var resource: Resource = value as Resource
				if not resource.resource_path.is_empty():
					return resource.resource_path
				return resource.get_class()
	return str(value)


static func _first_error(validation: FlowValidationResult) -> FlowDiagnostic:
	for diagnostic: FlowDiagnostic in validation.diagnostics:
		if diagnostic != null and diagnostic.severity == FlowDiagnostic.Severity.ERROR:
			return diagnostic
	return _diagnostic(
		FlowDiagnostic.CODE_STRUCTURED_VALUE_RESOLUTION_FAILED,
		"Structured document validation failed.",
		"document"
	)


static func _diagnostic(
		code: StringName,
		message: String,
		element_path: String,
		related_id: String = ""
) -> FlowDiagnostic:
	return FlowDiagnostic.new(
		code,
		FlowDiagnostic.Severity.ERROR,
		message,
		element_path,
		related_id
	)
