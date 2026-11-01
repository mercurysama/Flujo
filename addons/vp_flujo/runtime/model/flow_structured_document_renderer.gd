@tool
## Runtime-only deterministic textual renderer for structured documents.
class_name FlowStructuredDocumentRenderer
extends RefCounted


static func render(
		document: FlowStructuredDocument,
		context: FlowValueResolutionContext = null
) -> FlowStructuredRenderResult:
	return FlowStructuredDocumentResolver.resolve_text(document, context)
