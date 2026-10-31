@tool
## Structured chip segment backed by a stable FlowVariableDefinition ID.
class_name FlowVariableRefSegment
extends FlowChipSegment


const CHIP_TYPE: StringName = &"variable_ref"
const DISPLAY_NAME: String = "Variable"
const CATEGORY: StringName = &"variable"
const LABEL_STRATEGY: StringName = &"variable_name"
const STYLE_ROLE: StringName = &"variable"

## Resolution state is an ephemeral presentation projection. It is never saved
## and therefore cannot replace variable_id as the binding identity.
var _resolution_checked: bool = false
var _resolved_variable_id: String = ""
var _resolved_name: String = ""
var _resolved_variant_type: Variant.Type = Variant.Type.TYPE_NIL
var _resolved_value_type: FlowVariableDefinition.ValueType = \
	FlowVariableDefinition.ValueType.BOOL


func _init(new_source: FlowVariableRefValueSource = null) -> void:
	if new_source != null:
		set_value_source(new_source)


func get_chip_type() -> StringName:
	return CHIP_TYPE


func get_chip_type_descriptor() -> FlowChipTypeDescriptor:
	var descriptor: FlowChipTypeDescriptor = FlowChipTypeDescriptor.new()
	descriptor.type_id = CHIP_TYPE
	descriptor.display_name = DISPLAY_NAME
	descriptor.category = CATEGORY
	descriptor.label_strategy = LABEL_STRATEGY
	descriptor.semantic_style_role = STYLE_ROLE
	descriptor.editable = false
	return descriptor


func get_chip_label() -> String:
	var source: FlowVariableRefValueSource = get_value_source() as FlowVariableRefValueSource
	if source == null:
		return ""
	if not _resolved_name.is_empty():
		return _resolved_name
	if _resolution_checked and not _resolved_variable_id.is_empty():
		return "Variable"
	return source.variable_id


func get_chip_tooltip_data() -> FlowChipTooltipData:
	var source: FlowVariableRefValueSource = get_value_source() as FlowVariableRefValueSource
	var data: FlowChipTooltipData = FlowChipTooltipData.new(DISPLAY_NAME)
	if source == null:
		data.add_field("Type", DISPLAY_NAME)
		data.add_field("Name", "Unresolved")
		return data
	data.add_field("Type", DISPLAY_NAME)
	var resolved_label: String = _resolved_name
	if resolved_label.is_empty():
		resolved_label = "Variable" if _resolved_variable_id == source.variable_id else "Unresolved"
	data.add_field("Name", resolved_label)
	data.add_field("ID", source.variable_id)
	data.add_field(
		"Variant/Declared Type",
		FlowVariableDefinition.value_type_display_name(get_declared_value_type())
	)
	return data


## Declared type is a read-only projection of the selected graph variable.  The
## authored source type remains available as a diagnostic fallback while a
## missing reference is unresolved, but a resolved definition is authoritative.
func get_declared_value_type() -> FlowVariableDefinition.ValueType:
	if _resolution_checked and not _resolved_variable_id.is_empty():
		return _resolved_value_type
	var source: FlowVariableRefValueSource = get_value_source() as FlowVariableRefValueSource
	return source.declared_value_type if source != null else FlowVariableDefinition.ValueType.BOOL


func get_declared_variant_type() -> Variant.Type:
	return FlowVariableDefinition.to_variant_type(get_declared_value_type())


func validate_structure(result: FlowValidationResult, element_path: String) -> void:
	super.validate_structure(result, element_path)
	if result == null:
		return
	var source: FlowValueSource = get_value_source()
	if source != null and not source is FlowVariableRefValueSource:
		result.add_diagnostic(FlowDiagnostic.new(
			FlowDiagnostic.CODE_INVALID_VALUE_SOURCE,
			FlowDiagnostic.Severity.ERROR,
			"VariableRef segment requires a FlowVariableRefValueSource.",
			element_path + ".value_source",
			segment_id
		))


func set_resolved_variable(variable: FlowVariableDefinition) -> void:
	_resolution_checked = true
	_resolved_variable_id = ""
	_resolved_name = ""
	_resolved_variant_type = Variant.Type.TYPE_NIL
	var source: FlowVariableRefValueSource = get_value_source() as FlowVariableRefValueSource
	if variable == null or source == null or variable.get_internal_id() != source.variable_id:
		return
	_resolved_variable_id = variable.get_internal_id()
	_resolved_name = variable.display_name
	_resolved_variant_type = variable.get_declared_variant_type()
	_resolved_value_type = variable.value_type


func clear_resolution() -> void:
	_resolution_checked = false
	_resolved_variable_id = ""
	_resolved_name = ""
	_resolved_variant_type = Variant.Type.TYPE_NIL
	_resolved_value_type = FlowVariableDefinition.ValueType.BOOL


func is_chip_valid() -> bool:
	var source: FlowVariableRefValueSource = get_value_source() as FlowVariableRefValueSource
	if source == null or not source.is_valid():
		return false
	return not _resolution_checked or _resolved_variable_id == source.variable_id


func duplicate_with_new_id() -> FlowDocumentSegment:
	var copy: FlowVariableRefSegment = duplicate(false) as FlowVariableRefSegment
	copy._segment_id = FlowId.create()
	var source: FlowValueSource = get_value_source()
	copy._value_source = source.duplicate_with_new_id() if source != null else null
	copy.clear_resolution()
	return copy
