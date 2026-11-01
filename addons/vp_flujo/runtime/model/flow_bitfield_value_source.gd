@tool
## Int-valued source that preserves named bit flags.
class_name FlowBitfieldValueSource
extends FlowValueSource


const SOURCE_KIND: StringName = FlowValueSource.SOURCE_KIND_BITFIELD
const PRODUCED_TYPE: Variant.Type = Variant.Type.TYPE_INT

@export_storage var bitfield_name: StringName = &"Flags"
@export_storage var option_names: Array[StringName] = []
@export_storage var option_values: Array[int] = []
@export_storage var selected_mask: int = 0


func _init(
		new_bitfield_name: StringName = &"Flags",
		new_option_names: Array[StringName] = [],
		new_option_values: Array[int] = [],
		new_selected_mask: int = 0
) -> void:
	bitfield_name = new_bitfield_name
	option_names.assign(new_option_names)
	option_values.assign(new_option_values)
	selected_mask = new_selected_mask


func get_source_kind() -> StringName:
	return SOURCE_KIND


func get_value_type() -> Variant.Type:
	return PRODUCED_TYPE


func is_valid() -> bool:
	return FlowId.is_valid(_source_id) and _options_valid() and _mask_valid()


func get_preview() -> String:
	if selected_mask == 0:
		return "%s.None" % String(bitfield_name)
	var names: PackedStringArray = PackedStringArray()
	for index: int in option_values.size():
		var flag: int = option_values[index]
		if flag != 0 and (selected_mask & flag) == flag:
			names.append(String(option_names[index]))
	return "%s.%s" % [
		String(bitfield_name),
		" | ".join(names) if not names.is_empty() else "<invalid>",
	]


func validate_structure(result: FlowValidationResult, element_path: String) -> void:
	super.validate_structure(result, element_path)
	if result == null:
		return
	if not _options_valid():
		_add_error(
			result,
			FlowDiagnostic.CODE_BITFIELD_OPTIONS_INVALID,
			"Bitfield options must be non-empty, unique, positive bit values.",
			element_path,
			_source_id
		)
	elif not _mask_valid():
		_add_error(
			result,
			FlowDiagnostic.CODE_BITFIELD_MASK_INVALID,
			"Bitfield selected mask contains undeclared bits.",
			element_path + ".selected_mask",
			_source_id
		)


func resolve(_context: Variant = null) -> FlowValueResult:
	if not is_valid():
		return FlowValueResult.fail(
			PRODUCED_TYPE,
			FlowDiagnostic.new(
				FlowDiagnostic.CODE_BITFIELD_MASK_INVALID,
				FlowDiagnostic.Severity.ERROR,
				"Bitfield source is invalid.",
				"value_source",
				_source_id
			)
		)
	return FlowValueResult.ok(selected_mask, PRODUCED_TYPE)


func duplicate_with_new_id() -> FlowValueSource:
	var copy: FlowBitfieldValueSource = duplicate(false) as FlowBitfieldValueSource
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
		if name.is_empty() or value <= 0 				or (value & (value - 1)) != 0 				or seen_names.has(name) or seen_values.has(value):
			return false
		seen_names[name] = true
		seen_values[value] = true
	return true


func _mask_valid() -> bool:
	var known_mask: int = 0
	for value: int in option_values:
		known_mask |= value
	return (selected_mask & ~known_mask) == 0


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
