@tool
## Akis Tok projection for Bitfield.
class_name FlowBitfieldSegment
extends FlowChipSegment


const CHIP_TYPE: StringName = &"bitfield"
const DISPLAY_NAME: String = "Bitfield"
const CATEGORY: StringName = &"semantic_int"
const STYLE_ROLE: StringName = &"bitfield"

var _variable_graph: FlowGraph = null


func _init(new_source: FlowBitfieldValueSource = null) -> void:
	if new_source != null:
		set_value_source(new_source)


func get_chip_type() -> StringName:
	return CHIP_TYPE


func get_chip_type_descriptor() -> FlowChipTypeDescriptor:
	var descriptor: FlowChipTypeDescriptor = FlowChipTypeDescriptor.new()
	descriptor.type_id = CHIP_TYPE
	descriptor.display_name = DISPLAY_NAME
	descriptor.category = CATEGORY
	descriptor.label_strategy = &"bitfield"
	descriptor.semantic_style_role = STYLE_ROLE
	descriptor.editable = true
	descriptor.supported_variant_types = [Variant.Type.TYPE_INT]
	return descriptor


func get_chip_label() -> String:
	var source: FlowBitfieldValueSource = get_value_source() as FlowBitfieldValueSource
	return source.get_preview() if source != null else "Flags<?> "


func get_chip_tooltip_data() -> FlowChipTooltipData:
	var data: FlowChipTooltipData = FlowChipTooltipData.new(DISPLAY_NAME)
	var source: FlowBitfieldValueSource = get_value_source() as FlowBitfieldValueSource
	data.add_field("Type", DISPLAY_NAME)
	data.add_field(
		"Produced Type",
		FlowChipTypeDescriptor.variant_type_display_name(Variant.Type.TYPE_INT)
	)
	if source == null:
		data.add_field("Status", "invalid")
		return data
	data.add_field("Preview", source.get_preview())
	data.add_field("Bitfield", String(source.bitfield_name))
	data.add_field("Mask", str(source.selected_mask))
	return data


func set_variable_graph(graph: FlowGraph) -> void:
	_variable_graph = graph


func get_value_type() -> Variant.Type:
	return Variant.Type.TYPE_INT


func is_chip_valid() -> bool:
	var source: FlowBitfieldValueSource = get_value_source() as FlowBitfieldValueSource
	return source != null and source.is_valid()


func validate_structure(result: FlowValidationResult, element_path: String) -> void:
	var source: FlowValueSource = get_value_source()
	if not source is FlowBitfieldValueSource:
		result.add_diagnostic(FlowDiagnostic.new(
			FlowDiagnostic.CODE_INVALID_VALUE_SOURCE,
			FlowDiagnostic.Severity.ERROR,
			"Bitfield segment requires FlowBitfieldValueSource.",
			element_path + ".value_source",
			segment_id
		))
		return
	(source as FlowBitfieldValueSource).validate_structure(
		result,
		element_path + ".value_source"
	)


func duplicate_with_new_id() -> FlowDocumentSegment:
	var copy: FlowBitfieldSegment = duplicate(false) as FlowBitfieldSegment
	copy._segment_id = FlowId.create()
	copy._variable_graph = null
	var source: FlowValueSource = get_value_source()
	copy._value_source = source.duplicate_with_new_id() if source != null else null
	return copy
