@tool
## Akis Tok projection for a live scene Node reference.
class_name FlowNodeRefSegment
extends FlowChipSegment


const CHIP_TYPE: StringName = &"node_ref"
const DISPLAY_NAME: String = "Node"
const CATEGORY: StringName = &"scene"
const LABEL_STRATEGY: StringName = &"node_ref"
const STYLE_ROLE: StringName = &"node_ref"

var _resolution_context: FlowValueResolutionContext = null


func _init(new_source: FlowNodeRefValueSource = null) -> void:
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
	descriptor.editable = true
	descriptor.supported_variant_types = [Variant.Type.TYPE_OBJECT]
	return descriptor


func get_chip_label() -> String:
	var source: FlowNodeRefValueSource = get_value_source() as FlowNodeRefValueSource
	return source.get_preview() if source != null else "$<invalid>"


func get_chip_tooltip_data() -> FlowChipTooltipData:
	var data: FlowChipTooltipData = FlowChipTooltipData.new(DISPLAY_NAME)
	var source: FlowNodeRefValueSource = get_value_source() as FlowNodeRefValueSource
	data.add_field("Type", DISPLAY_NAME)
	data.add_field("Produced Type", "Object (Node)")
	if source == null:
		data.add_field("Status", "invalid")
		return data
	data.add_field("Node", String(source.node_name_hint))
	data.add_field("Class", String(source.node_class_hint))
	if not source.requirement_id.is_empty():
		data.add_field("Requirement ID", source.requirement_id)
	else:
		data.add_field("Node Path", String(source.node_path))
	return data


func set_resolution_context(context: FlowValueResolutionContext) -> void:
	_resolution_context = context


func get_value_type() -> Variant.Type:
	return Variant.Type.TYPE_OBJECT


func is_chip_valid() -> bool:
	var source: FlowNodeRefValueSource = get_value_source() as FlowNodeRefValueSource
	if source == null or not source.is_valid():
		return false
	if _resolution_context == null:
		return true
	return source.resolve(_resolution_context).success


func validate_structure(result: FlowValidationResult, element_path: String) -> void:
	var source: FlowNodeRefValueSource = get_value_source() as FlowNodeRefValueSource
	if source == null:
		result.add_diagnostic(FlowDiagnostic.new(
			FlowDiagnostic.CODE_INVALID_VALUE_SOURCE,
			FlowDiagnostic.Severity.ERROR,
			"NodeRef segment requires a FlowNodeRefValueSource.",
			element_path + ".value_source",
			segment_id
		))
		return
	source.validate_structure(result, element_path + ".value_source")


func duplicate_with_new_id() -> FlowDocumentSegment:
	var copy: FlowNodeRefSegment = duplicate(false) as FlowNodeRefSegment
	copy._segment_id = FlowId.create()
	copy._resolution_context = null
	var source: FlowValueSource = get_value_source()
	copy._value_source = source.duplicate_with_new_id() if source != null else null
	return copy
