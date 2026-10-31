@tool
## Akis Tok projection for Resource.
class_name FlowResourceRefSegment
extends FlowChipSegment


const CHIP_TYPE: StringName = &"resource_ref"
const DISPLAY_NAME: String = "Resource"
const CATEGORY: StringName = &"resource"
const STYLE_ROLE: StringName = &"resource_ref"

var _variable_graph: FlowGraph = null


func _init(new_source: FlowResourceRefValueSource = null) -> void:
	if new_source != null:
		set_value_source(new_source)


func get_chip_type() -> StringName:
	return CHIP_TYPE


func get_chip_type_descriptor() -> FlowChipTypeDescriptor:
	var descriptor: FlowChipTypeDescriptor = FlowChipTypeDescriptor.new()
	descriptor.type_id = CHIP_TYPE
	descriptor.display_name = DISPLAY_NAME
	descriptor.category = CATEGORY
	descriptor.label_strategy = &"resource_ref"
	descriptor.semantic_style_role = STYLE_ROLE
	descriptor.editable = true
	descriptor.supported_variant_types = [Variant.Type.TYPE_OBJECT]
	return descriptor


func get_chip_label() -> String:
	var source: FlowResourceRefValueSource = get_value_source() as FlowResourceRefValueSource
	return source.get_preview() if source != null else "Resource<?> "


func get_chip_tooltip_data() -> FlowChipTooltipData:
	var data: FlowChipTooltipData = FlowChipTooltipData.new(DISPLAY_NAME)
	var source: FlowResourceRefValueSource = get_value_source() as FlowResourceRefValueSource
	data.add_field("Type", DISPLAY_NAME)
	data.add_field(
		"Produced Type",
		FlowChipTypeDescriptor.variant_type_display_name(Variant.Type.TYPE_OBJECT)
	)
	if source == null:
		data.add_field("Status", "invalid")
		return data
	data.add_field("Preview", source.get_preview())
	data.add_field("Resource Type", String(source.resource_type_hint))
	data.add_field("Path", source.resource_path if source.has_path() else "<unbound>")
	return data


func set_variable_graph(graph: FlowGraph) -> void:
	_variable_graph = graph


func get_value_type() -> Variant.Type:
	return Variant.Type.TYPE_OBJECT


func is_chip_valid() -> bool:
	var source: FlowResourceRefValueSource = get_value_source() as FlowResourceRefValueSource
	return source != null and source.is_valid() and source.has_path()


func validate_structure(result: FlowValidationResult, element_path: String) -> void:
	var source: FlowValueSource = get_value_source()
	if not source is FlowResourceRefValueSource:
		result.add_diagnostic(FlowDiagnostic.new(
			FlowDiagnostic.CODE_INVALID_VALUE_SOURCE,
			FlowDiagnostic.Severity.ERROR,
			"Resource segment requires FlowResourceRefValueSource.",
			element_path + ".value_source",
			segment_id
		))
		return
	(source as FlowResourceRefValueSource).validate_structure(
		result,
		element_path + ".value_source"
	)


func duplicate_with_new_id() -> FlowDocumentSegment:
	var copy: FlowResourceRefSegment = duplicate(false) as FlowResourceRefSegment
	copy._segment_id = FlowId.create()
	copy._variable_graph = null
	var source: FlowValueSource = get_value_source()
	copy._value_source = source.duplicate_with_new_id() if source != null else null
	return copy
