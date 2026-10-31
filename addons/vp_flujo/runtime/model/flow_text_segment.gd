@tool
## Literal text segment. No symbols are parsed or interpreted.
class_name FlowTextSegment
extends FlowDocumentSegment


const SEGMENT_TYPE: StringName = &"text"

@export_multiline var text: String = ""


func get_segment_type() -> StringName:
	return SEGMENT_TYPE
