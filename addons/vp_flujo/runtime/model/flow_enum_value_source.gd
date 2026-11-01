@tool
## Int-valued source that preserves enum labels and authored semantic identity.
class_name FlowEnumValueSource
extends FlowValueSource


const SOURCE_KIND: StringName = FlowValueSource.SOURCE_KIND_ENUM
const PRODUCED_TYPE: Variant.Type = Variant.Type.TYPE_INT

@export_storage var enum_name: StringName = &"Enum"
@export_storage var option_names: Array[StringName] = []
@export_storage var option_values: Array[int] = []
@export_storage var selected_value: int = 0
@export_storage var has_selection: bool = false


func _init(
		new_enum_name: StringName = &"Enum",
		new_option_names: Array[StringName] = [],
		new_option_values: Array[int] = [],
		new_selected_value: int = 0,
		new_has_selection: bool = false
) -> void:
	enum_name = new_enum_name
	option_names.assign(new_option_names)
	option_values.assign(new_option_values)
	selected_value = new_selected_value
	has_selection = new_has_selection


func get_source_kind() -> StringName:
	return SOURCE_KIND


func get_value_type() -> Variant.Type:
	return PRODUCED_TYPE


func is_valid() -> bool:
	return FlowId.is_valid(_source_id) and _options_valid() 		and has_selection and option_values.has(selected_value)


func get_preview() -> String:
	if not has_selection:
		return "%s.<unset>" % String(enum_name)
	var index: int = option_values.find(selected_value)
	if index < 0:
		return "%s(<invalid:%d>)" % [String(enum_name), selected_value]
	return "%s.%s" % [String(enum_name), String(option_names[index])]


func validate_structure(result: FlowValidationResult, element_path: String) -> void:
	super.validate_structure(result, element_path)
	if result == null:
		return
	if not _options_valid():
		_add_error(
			result,
			FlowDiagnostic.CODE_ENUM_OPTIONS_INVALID,
			"Enum options must be non-empty, aligned and unique.",
			element_path,
			_source_id
		)
	elif not has_selection or not option_values.has(selected_value):
		_add_error(
			result,
			FlowDiagnostic.CODE_ENUM_VALUE_INVALID,
			"Enum selected value is not declared by its options.",
			element_path + ".selected_value",
			_source_id
		)


func resolve(_context: Variant = null) -> FlowValueResult:
	if not is_valid():
		return FlowValueResult.fail(
			PRODUCED_TYPE,
			FlowDiagnostic.new(
				FlowDiagnostic.CODE_ENUM_VALUE_INVALID,
				FlowDiagnostic.Severity.ERROR,
				"Enum source is invalid.",
				"value_source",
				_source_id
			)
		)
	return FlowValueResult.ok(selected_value, PRODUCED_TYPE)


func duplicate_with_new_id() -> FlowValueSource:
	var copy: FlowEnumValueSource = duplicate(false) as FlowEnumValueSource
	copy._source_id = FlowId.create()
	copy.option_names = option_names.duplicate()
	copy.option_values = option_values.duplicate()
	return copy


func _options_valid() -> bool:
	if option_names.is_empty() or option_names.size() != option_values.size():
		return false
	var seen_names: Dictionary = {}
	var seen_values: Dictionary = {}
	for index: int in option_names.size():
		var name: String = String(option_names[index]).strip_edges()
		var value: int = option_values[index]
		if name.is_empty() or seen_names.has(name) or seen_values.has(value):
			return false
		seen_names[name] = true
		seen_values[value] = true
	return true


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
