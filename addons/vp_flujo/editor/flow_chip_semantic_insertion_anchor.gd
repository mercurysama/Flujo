@tool
## Editor-only semantic position used while an Akis insertion selector is open.
##
## The text segment ID and local offset are the primary caret identity. The
## neighboring segment IDs retain the semantic boundary around Toks so a future
## source trigger can restore its position without trusting a transient visual
## array index.
class_name FlowChipSemanticInsertionAnchor
extends RefCounted


var segment_id: String = ""
var local_offset: int = 0
var left_segment_id: String = ""
var right_segment_id: String = ""


static func capture(
		document: FlowStructuredDocument,
		text_segment_id: String,
		offset: int
) -> FlowChipSemanticInsertionAnchor:
	var anchor: FlowChipSemanticInsertionAnchor = FlowChipSemanticInsertionAnchor.new()
	anchor.segment_id = text_segment_id
	anchor.local_offset = maxi(offset, 0)
	if document == null:
		return anchor
	var segment_index: int = _find_segment_index(document, text_segment_id)
	if segment_index < 0:
		return anchor
	anchor.local_offset = clampi(
		anchor.local_offset,
		0,
		(document.segments[segment_index] as FlowTextSegment).text.length()
	)
	anchor.left_segment_id = _neighbor_id(document, segment_index, -1)
	anchor.right_segment_id = _neighbor_id(document, segment_index, 1)
	return anchor


func duplicate_anchor() -> FlowChipSemanticInsertionAnchor:
	var copy: FlowChipSemanticInsertionAnchor = FlowChipSemanticInsertionAnchor.new()
	copy.segment_id = segment_id
	copy.local_offset = local_offset
	copy.left_segment_id = left_segment_id
	copy.right_segment_id = right_segment_id
	return copy


func is_empty() -> bool:
	return segment_id.is_empty() and left_segment_id.is_empty() and right_segment_id.is_empty()


## Resolves against semantic IDs first. The neighbor fallback is only for a
## rebuild that replaced the original text control; it never treats an index
## as persistent identity.
func resolve(document: FlowStructuredDocument) -> Dictionary:
	if document == null:
		return {}
	for segment: FlowDocumentSegment in document.segments:
		if segment != null and segment.get_segment_id() == segment_id:
			var text: FlowTextSegment = segment as FlowTextSegment
			if text != null:
				return {
					"segment": text,
					"offset": clampi(local_offset, 0, text.text.length()),
				}
	var left_index: int = _find_segment_index(document, left_segment_id)
	var right_index: int = _find_segment_index(document, right_segment_id)
	if right_index >= 0:
		var right: FlowTextSegment = document.segments[right_index] as FlowTextSegment
		if right != null:
			return {"segment": right, "offset": 0}
	if left_index >= 0:
		var left: FlowTextSegment = document.segments[left_index] as FlowTextSegment
		if left != null:
			return {"segment": left, "offset": left.text.length()}
	return {}


static func _find_segment_index(document: FlowStructuredDocument, candidate_id: String) -> int:
	if document == null or candidate_id.is_empty():
		return -1
	for index: int in document.segments.size():
		var segment: FlowDocumentSegment = document.segments[index]
		if segment != null and segment.get_segment_id() == candidate_id:
			return index
	return -1


static func _neighbor_id(
		document: FlowStructuredDocument,
		segment_index: int,
		direction: int
) -> String:
	var candidate_index: int = segment_index + direction
	while candidate_index >= 0 and candidate_index < document.segments.size():
		var segment: FlowDocumentSegment = document.segments[candidate_index]
		if segment != null:
			return segment.get_segment_id()
		candidate_index += direction
	return ""
