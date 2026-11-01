@tool
class_name FlowPrintBlock
extends FlowOutputBlock

@export_multiline var text: String = ""
@export var content: FlowStructuredDocument


func _init() -> void:
	display_name = "Print"


func get_output_message() -> String:
	return text


func resolve_output_message(
		context: FlowValueResolutionContext
) -> FlowValueResult:
	if content == null:
		return FlowValueResult.ok(text, Variant.Type.TYPE_STRING)
	var rendered: FlowStructuredRenderResult = resolve_structured_property_text(
		&"content",
		context
	)
	if rendered.has_errors():
		var diagnostic: FlowDiagnostic = null
		for candidate: FlowDiagnostic in rendered.diagnostics:
			if candidate != null and candidate.severity == FlowDiagnostic.Severity.ERROR:
				diagnostic = candidate
				break
		if diagnostic == null:
			diagnostic = FlowDiagnostic.new(
				FlowDiagnostic.CODE_STRUCTURED_VALUE_RESOLUTION_FAILED,
				FlowDiagnostic.Severity.ERROR,
				"Print content could not be resolved.",
				"content",
				get_internal_id()
			)
		return FlowValueResult.fail(Variant.Type.TYPE_STRING, diagnostic)
	return FlowValueResult.ok(rendered.text, Variant.Type.TYPE_STRING)
