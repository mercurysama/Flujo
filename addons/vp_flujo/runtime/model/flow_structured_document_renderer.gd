@tool
## Runtime-only deterministic textual renderer for structured documents.
class_name FlowStructuredDocumentRenderer
extends RefCounted


static func render(document: FlowStructuredDocument) -> FlowStructuredRenderResult:
	var result: FlowStructuredRenderResult = FlowStructuredRenderResult.new()
	var validation: FlowValidationResult = FlowStructuredDocumentValidator.validate(document)
	for diagnostic: FlowDiagnostic in validation.diagnostics:
		result.add_diagnostic(diagnostic)
	if result.has_errors():
		return result

	var rendered_text: String = ""
	for segment: FlowDocumentSegment in document.segments:
		if segment is FlowTextSegment:
			rendered_text += (segment as FlowTextSegment).text
		elif segment is FlowLiteralValueSegment:
			rendered_text += (segment as FlowLiteralValueSegment).get_runtime_text()
		else:
			# Validation is intentionally repeated at this boundary so a caller that
			# mutates a document between passes still receives an explicit failure.
			result.add_diagnostic(FlowDiagnostic.new(
				FlowDiagnostic.CODE_UNKNOWN_SEGMENT_TYPE,
				FlowDiagnostic.Severity.ERROR,
				"Structured document contains a segment that cannot be rendered.",
				"segments",
				segment.get_segment_id() if segment != null else ""
			))
			return result

	result.text = rendered_text
	return result
