@tool
## Akis Tok projection for Enum.
class_name FlowEnumSegment
extends FlowChipSegment


const CHIP_TYPE: StringName = &"enum"
const DISPLAY_NAME: String = "Enum"
const CATEGORY: StringName = &"semantic_int"
const STYLE_ROLE: StringName = &"enum"

var _variable_graph: FlowGraph = null


func _init(new_source: FlowEnumValueSource = null) -> void:
	if new_source != null:
		set_value_source(new_source)


func get_chip_type() -> StringName:
	return CHIP_TYPE


func get_chip_type_descriptor() -> FlowChipTypeDescriptor:
	var descriptor: FlowChipTypeDescriptor = FlowChipTypeDescriptor.new()
	descriptor.type_id = CHIP_TYPE
	descriptor.display_name = DISPLAY_NAME
	descriptor.category = CATEGORY
	descriptor.label_strategy = &"enum"
	descriptor.semantic_style_role = STYLE_ROLE
	descriptor.editable = true
	descriptor.supported_variant_types = [Variant.Type.TYPE_INT]
	return descriptor


func get_chip_label() -> String:
	var source: FlowEnumValueSource = get_value_source() as FlowEnumValueSource
	return source.get_preview() if source != null else "Enum<?> "


func get_chip_tooltip_data() -> FlowChipTooltipData:
	var data: FlowChipTooltipData = FlowChipTooltipData.new(DISPLAY_NAME)
	var source: FlowEnumValueSource = get_value_source() as FlowEnumValueSource
	data.add_field("Type", DISPLAY_NAME)
	data.add_field(
		"Produced Type",
		FlowChipTypeDescriptor.variant_type_display_name(Variant.Type.TYPE_INT)
	)
	if source == null:
		data.add_field("Status", "invalid")
		return data
	data.add_field("Preview", source.get_preview())
	data.add_field("Enum", String(source.enum_name))
	data.add_field("Value", str(source.selected_value))
	return data


func set_variable_graph(graph: FlowGraph) -> void:
	_variable_graph = graph


func get_value_type() -> Variant.Type:
	return Variant.Type.TYPE_INT


func is_chip_valid() -> bool:
	var source: FlowEnumValueSource = get_value_source() as FlowEnumValueSource
	return source != null and source.is_valid()


func validate_structure(result: FlowValidationResult, element_path: String) -> void:
	var source: FlowValueSource = get_value_source()
	if not source is FlowEnumValueSource:
		result.add_diagnostic(FlowDiagnostic.new(
			FlowDiagnostic.CODE_INVALID_VALUE_SOURCE,
			FlowDiagnostic.Severity.ERROR,
			"Enum segment requires FlowEnumValueSource.",
			element_path + ".value_source",
			segment_id
		))
		return
	(source as FlowEnumValueSource).validate_structure(
		result,
		element_path + ".value_source"
	)


func duplicate_with_new_id() -> FlowDocumentSegment:
	var copy: FlowEnumSegment = duplicate(false) as FlowEnumSegment
	copy._segment_id = FlowId.create()
	copy._variable_graph = null
	var source: FlowValueSource = get_value_source()
	copy._value_source = source.duplicate_with_new_id() if source != null else null
	return copy
