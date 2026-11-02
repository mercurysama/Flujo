@tool
## An authored typed reference to one top-level field of a same-tick event.
## Packet values live only in FlowValueResolutionContext, never in the graph.
class_name FlowEventPayloadValueSource
extends FlowValueSource

const SOURCE_KIND: StringName = &"event_payload"
const ALLOWED_TYPES: Array[int] = [
	Variant.Type.TYPE_BOOL, Variant.Type.TYPE_INT,
	Variant.Type.TYPE_FLOAT, Variant.Type.TYPE_STRING
]

@export_storage var event_name: StringName = &""
@export_storage var field_name: String = ""
@export_storage var value_type: Variant.Type = Variant.Type.TYPE_NIL

func _init(
		new_event_name: StringName = &"",
		new_field_name: String = "",
		new_value_type: Variant.Type = Variant.Type.TYPE_NIL
) -> void:
	event_name = new_event_name
	field_name = new_field_name
	value_type = new_value_type


func get_source_kind() -> StringName:
	return SOURCE_KIND


func get_value_type() -> Variant.Type:
	return value_type


func is_valid() -> bool:
	return FlowId.is_valid(_source_id) \
		and not String(event_name).strip_edges().is_empty() \
		and not field_name.strip_edges().is_empty() \
		and value_type in ALLOWED_TYPES


func validate_structure(result: FlowValidationResult, element_path: String) -> void:
	super.validate_structure(result, element_path)
	if not is_valid():
		_add_error(
			result, &"event_payload_source_invalid",
			"Event payload operand needs a nonblank event, field and supported exact type.",
			element_path
		)


func resolve(context: Variant = null) -> FlowValueResult:
	if not is_valid():
		return _fail(&"event_payload_source_invalid", "Event field source is incomplete.")
	var scope: FlowValueResolutionContext = context as FlowValueResolutionContext
	if scope == null or not scope.has_event_payload(event_name):
		return _fail(&"event_payload_missing", "Event packet is unavailable in this machine tick.")
	var packet: Dictionary = scope.get_event_payload(event_name)
	if not packet.has(field_name):
		return _fail(&"event_payload_missing", "Required event field is missing.")
	var found: Variant = packet[field_name]
	if typeof(found) != value_type:
		return _fail(&"event_payload_type_mismatch", "Event field does not match its declared type.")
	return FlowValueResult.ok(found, value_type)


func get_preview() -> String:
	if event_name.is_empty() or field_name.is_empty():
		return "<event field>"
	return 'event("%s").%s' % [String(event_name), field_name]


func _fail(code: StringName, message: String) -> FlowValueResult:
	return FlowValueResult.fail(
		value_type, FlowDiagnostic.new(
			code, FlowDiagnostic.Severity.ERROR, message,
			"value_source.event_payload", _source_id
		)
	)
