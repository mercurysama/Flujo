@tool
extends FlowOutputBlock

@export var prefix: String = ""
@export_multiline var message: String = ""
@export var suffix: String = ""
@export var document: FlowStructuredDocument = null


func _init() -> void:
	_ensure_akis_document(false)


## Ensures the Akis document exists and matches the V1 FPrint author contract.
## When migrate_legacy is true, preserves legacy message as initial Tok content.
func ensure_fprint_akis(migrate_legacy: bool = true) -> FlowStructuredDocument:
	_ensure_akis_document(migrate_legacy)
	return document


func _ensure_akis_document(migrate_legacy: bool) -> void:
	if document == null:
		document = FlowStructuredDocument.new()
	# Author-defined Akis contract (V1: only Text, insertable/evaluable, preconfig ["text"]).
	document.akis_type_config = {
		"text": {
			"insertable": true,
			"evaluable": true,
		}
	}
	document.akis_preconfiguration = ["text"]
	if document.segments.is_empty():
		# Legacy adaptation: preserve existing message content without deleting it.
		var initial_text: String = ""
		if migrate_legacy and not message.is_empty():
			initial_text = message
		var tok: FlowTextSegment = FlowTextSegment.new()
		tok.text = initial_text
		tok.evaluable = true
		document.segments.append(tok)
	elif migrate_legacy and document.segments.size() == 1 and not message.is_empty():
		# If a legacy message exists alongside a single empty initial tok, preserve it.
		var only: FlowDocumentSegment = document.segments[0]
		if only is FlowTextSegment:
			var text_tok: FlowTextSegment = only as FlowTextSegment
			if text_tok.text.is_empty():
				text_tok.text = message


func get_output_message() -> String:
	# FPrint consumes Akis values: concatenate evaluable tok outputs in order.
	# Keep legacy path if document is unexpectedly unavailable.
	if document == null:
		return prefix + message + suffix
	# Preserve legacy scalar data compatibility: if a legacy message exists and
	# document still represents an untouched empty default tok, prefer legacy output.
	if _is_legacy_message_fallback_active():
		return prefix + message + suffix
	var render_result: FlowStructuredRenderResult = FlowStructuredDocumentRenderer.render(document)
	return prefix + render_result.text + suffix


func _is_legacy_message_fallback_active() -> bool:
	if document == null or message.is_empty():
		return false
	if document.segments.size() != 1:
		return false
	var only: FlowDocumentSegment = document.segments[0]
	if not only is FlowTextSegment:
		return false
	var text_tok: FlowTextSegment = only as FlowTextSegment
	# Treat a single default empty text tok as not overriding legacy message.
	return text_tok.text.is_empty() and text_tok.evaluable


func remap_internal_references(_id_map: Dictionary[String, String]) -> void:
	if document != null:
		document = document.duplicate_with_new_ids()
