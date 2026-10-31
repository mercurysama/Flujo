@tool
## Persistent base for one ordered structured-document segment.
class_name FlowDocumentSegment
extends Resource


@export_storage var _segment_id: String = FlowId.create()


## Read/write alias useful to authoring adapters; the serialized field remains
## hidden and stable through _segment_id.
var segment_id: String:
	get:
		return _segment_id
	set(value):
		_segment_id = value


func get_segment_id() -> String:
	return _segment_id


## Existing model APIs use get_internal_id() for persistent identity. Keep the
## alias available while the structured-document vocabulary uses segment_id.
func get_internal_id() -> String:
	return _segment_id


func get_segment_type() -> StringName:
	return &"unknown"


## Duplicates the concrete segment and gives the copy an independent identity.
func duplicate_with_new_id() -> FlowDocumentSegment:
	var copy: FlowDocumentSegment = duplicate(true) as FlowDocumentSegment
	copy._segment_id = FlowId.create()
	return copy
