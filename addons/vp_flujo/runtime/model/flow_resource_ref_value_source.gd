@tool
## Persistent reference to a project Resource path.
class_name FlowResourceRefValueSource
extends FlowValueSource


const SOURCE_KIND: StringName = FlowValueSource.SOURCE_KIND_RESOURCE_REF
const PRODUCED_TYPE: Variant.Type = Variant.Type.TYPE_OBJECT

@export_storage var resource_path: String = ""
@export_storage var resource_type_hint: StringName = &"Resource"


func _init(
		new_resource_path: String = "",
		new_resource_type_hint: StringName = &"Resource"
) -> void:
	resource_path = new_resource_path
	resource_type_hint = new_resource_type_hint


func get_source_kind() -> StringName:
	return SOURCE_KIND


func get_value_type() -> Variant.Type:
	return PRODUCED_TYPE


func has_path() -> bool:
	return not resource_path.strip_edges().is_empty()


func is_valid() -> bool:
	return FlowId.is_valid(_source_id) 		and not String(resource_type_hint).strip_edges().is_empty()


func get_preview() -> String:
	if not has_path():
		return "Resource<%s>" % String(resource_type_hint)
	return "%s(%s)" % [
		String(resource_type_hint),
		resource_path.get_file(),
	]


func validate_structure(result: FlowValidationResult, element_path: String) -> void:
	super.validate_structure(result, element_path)
	if result == null:
		return
	if not has_path():
		result.add_diagnostic(FlowDiagnostic.new(
			FlowDiagnostic.CODE_RESOURCE_REF_PATH_MISSING,
			FlowDiagnostic.Severity.WARNING,
			"ResourceRef is structurally valid but no resource path is selected.",
			element_path + ".resource_path",
			_source_id
		))
	if String(resource_type_hint).strip_edges().is_empty():
		_add_error(
			result,
			FlowDiagnostic.CODE_RESOURCE_REF_TYPE_MISMATCH,
			"ResourceRef type hint cannot be empty.",
			element_path + ".resource_type_hint"
		)


func resolve(_context: Variant = null) -> FlowValueResult:
	if not has_path():
		return _failure(
			FlowDiagnostic.CODE_RESOURCE_REF_PATH_MISSING,
			"ResourceRef has no selected resource path."
		)
	if not ResourceLoader.exists(resource_path):
		return _failure(
			FlowDiagnostic.CODE_RESOURCE_REF_MISSING,
			"ResourceRef path does not exist."
		)
	var resource: Resource = ResourceLoader.load(
		resource_path,
		"",
		ResourceLoader.CACHE_MODE_REUSE
	)
	if resource == null:
		return _failure(
			FlowDiagnostic.CODE_RESOURCE_REF_MISSING,
			"ResourceRef could not load its resource."
		)
	if not String(resource_type_hint).is_empty() 			and not resource.is_class(String(resource_type_hint)):
		return _failure(
			FlowDiagnostic.CODE_RESOURCE_REF_TYPE_MISMATCH,
			"Loaded Resource class does not match the authored type hint."
		)
	return FlowValueResult.ok(resource, PRODUCED_TYPE)


func duplicate_with_new_id() -> FlowValueSource:
	var copy: FlowResourceRefValueSource = duplicate(false) as FlowResourceRefValueSource
	copy._source_id = FlowId.create()
	return copy


static func placeholder(expected_type: StringName = &"Resource") -> FlowResourceRefValueSource:
	return FlowResourceRefValueSource.new("", expected_type)


func _failure(code: StringName, message: String) -> FlowValueResult:
	return FlowValueResult.fail(
		PRODUCED_TYPE,
		FlowDiagnostic.new(
			code,
			FlowDiagnostic.Severity.ERROR,
			message,
			"value_source",
			_source_id
		)
	)


static func _add_error(
		result: FlowValidationResult,
		code: StringName,
		message: String,
		path: String,
		related_id: String = ""
) -> void:
	result.add_diagnostic(FlowDiagnostic.new(
		code,
		FlowDiagnostic.Severity.ERROR,
		message,
		path,
		related_id
	))
