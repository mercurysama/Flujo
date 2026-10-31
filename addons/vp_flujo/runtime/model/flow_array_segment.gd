@tool
## Akis Tok projection for Array.
class_name FlowArraySegment
extends FlowChipSegment


const CHIP_TYPE: StringName = &"array"
const DISPLAY_NAME: String = "Array"
const CATEGORY: StringName = &"collection"
const STYLE_ROLE: StringName = &"array"

var _variable_graph: FlowGraph = null


func _init(new_source: FlowArrayValueSource = null) -> void:
	if new_source != null:
		set_value_source(new_source)


func get_chip_type() -> StringName:
	return CHIP_TYPE


func get_chip_type_descriptor() -> FlowChipTypeDescriptor:
	var descriptor: FlowChipTypeDescriptor = FlowChipTypeDescriptor.new()
	descriptor.type_id = CHIP_TYPE
	descriptor.display_name = DISPLAY_NAME
	descriptor.category = CATEGORY
	descriptor.label_strategy = &"array"
	descriptor.semantic_style_role = STYLE_ROLE
	descriptor.editable = true
	descriptor.supported_variant_types = [Variant.Type.TYPE_ARRAY]
	return descriptor


func get_chip_label() -> String:
	var source: FlowArrayValueSource = get_value_source() as FlowArrayValueSource
	return source.get_preview(_variable_graph) if source != null else "[]"


func get_chip_tooltip_data() -> FlowChipTooltipData:
	var data: FlowChipTooltipData = FlowChipTooltipData.new(DISPLAY_NAME)
	var source: FlowArrayValueSource = get_value_source() as FlowArrayValueSource
	data.add_field("Type", DISPLAY_NAME)
	data.add_field(
		"Produced Type",
		FlowChipTypeDescriptor.variant_type_display_name(Variant.Type.TYPE_ARRAY)
	)
	if source == null:
		data.add_field("Status", "invalid")
		return data
	data.add_field("Preview", source.get_preview(_variable_graph))
	data.add_field("Elements", str(source.elements.size()))
	return data


func set_variable_graph(graph: FlowGraph) -> void:
	_variable_graph = graph


func get_value_type() -> Variant.Type:
	return Variant.Type.TYPE_ARRAY


func is_chip_valid() -> bool:
	var source: FlowArrayValueSource = get_value_source() as FlowArrayValueSource
	return source != null and source.is_valid()


func validate_structure(result: FlowValidationResult, element_path: String) -> void:
	var source: FlowValueSource = get_value_source()
	if not source is FlowArrayValueSource:
		result.add_diagnostic(FlowDiagnostic.new(
			FlowDiagnostic.CODE_INVALID_VALUE_SOURCE,
			FlowDiagnostic.Severity.ERROR,
			"Array segment requires FlowArrayValueSource.",
			element_path + ".value_source",
			segment_id
		))
		return
	(source as FlowArrayValueSource).validate_structure(
		result,
		element_path + ".value_source"
	)


func duplicate_with_new_id() -> FlowDocumentSegment:
	var copy: FlowArraySegment = duplicate(false) as FlowArraySegment
	copy._segment_id = FlowId.create()
	copy._variable_graph = null
	var source: FlowValueSource = get_value_source()
	copy._value_source = source.duplicate_with_new_id() if source != null else null
	return copy
