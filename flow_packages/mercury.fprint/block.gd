@tool
extends FlowOutputBlock

@export var prefix: String = ""
@export_multiline var message: String = ""
@export var suffix: String = ""
@export var document: FlowStructuredDocument = null


func get_output_message() -> String:
	var central_content: String = message
	if document != null:
		var render_result: FlowStructuredRenderResult = FlowStructuredDocumentRenderer.render(document)
		central_content = render_result.text
	return prefix + central_content + suffix


func remap_internal_references(_id_map: Dictionary[String, String]) -> void:
	if document != null:
		document = document.duplicate_with_new_ids()
