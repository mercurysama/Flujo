@tool
## Persistent ordered document composed of reusable runtime segments.
class_name FlowStructuredDocument
extends Resource


const CURRENT_VERSION: int = 1

@export_storage var version: int = CURRENT_VERSION
@export var segments: Array[FlowDocumentSegment] = []


## Compatibility alias for consumers that name the persisted revision explicitly.
var document_version: int:
	get:
		return version
	set(value):
		version = value


## Compatibility alias for model code that uses schema-style terminology.
var schema_version: int:
	get:
		return version
	set(value):
		version = value


func get_version() -> int:
	return version


## Duplicates the document, preserving order and null positions while assigning
## independent IDs to every copied segment.
func duplicate_with_new_ids() -> FlowStructuredDocument:
	var copy: FlowStructuredDocument = duplicate(false) as FlowStructuredDocument
	copy.segments = []
	for segment: FlowDocumentSegment in segments:
		if segment == null:
			copy.segments.append(null)
		else:
			copy.segments.append(segment.duplicate_with_new_id())
	return copy


## Deep copy used by editor session snapshots. Persistent segment IDs remain
## unchanged so Revertir can restore the exact document that was opened.
func duplicate_preserving_ids() -> FlowStructuredDocument:
	var copy: FlowStructuredDocument = duplicate(false) as FlowStructuredDocument
	copy.segments = []
	for segment: FlowDocumentSegment in segments:
		if segment == null:
			copy.segments.append(null)
		else:
			copy.segments.append(segment.duplicate(true) as FlowDocumentSegment)
	return copy
