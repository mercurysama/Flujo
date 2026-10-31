@tool
## Akis Tok projection for a typed Node property reference.
class_name FlowNodePropertyRefSegment
extends FlowChipSegment


const CHIP_TYPE: StringName = &"node_property_ref"
const DISPLAY_NAME: String = "Node Property"
const CATEGORY: StringName = &"scene"
const LABEL_STRATEGY: StringName = &"node_property"
const STYLE_ROLE: StringName = &"node_property"

var _resolution_context: FlowValueResolutionContext = null


func _init(new_source: FlowNodePropertyRefValueSource = null) -> void:
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
	return descriptor


func get_chip_label() -> String:
	var source: FlowNodePropertyRefValueSource = 		get_value_source() as FlowNodePropertyRefValueSource
	return source.get_preview() if source != null else "$<invalid>"


func get_chip_tooltip_data() -> FlowChipTooltipData:
	var data: FlowChipTooltipData = FlowChipTooltipData.new(DISPLAY_NAME)
	var source: FlowNodePropertyRefValueSource = 		get_value_source() as FlowNodePropertyRefValueSource
	data.add_field("Type", DISPLAY_NAME)
	if source == null:
		data.add_field("Status", "invalid")
		return data
	data.add_field("Node", String(source.node_name_hint))
	data.add_field("Property", String(source.property_name))
	data.add_field(
		"Value Type",
		FlowChipTypeDescriptor.variant_type_display_name(source.get_value_type())
	)
	if not source.requirement_id.is_empty():
		data.add_field("Requirement ID", source.requirement_id)
	elif not source.node_path.is_empty():
		data.add_field("Node Path", String(source.node_path))
	return data


func set_resolution_context(context: FlowValueResolutionContext) -> void:
	_resolution_context = context


func get_value_type() -> Variant.Type:
	var source: FlowNodePropertyRefValueSource = 		get_value_source() as FlowNodePropertyRefValueSource
	return source.get_value_type() if source != null else Variant.Type.TYPE_NIL


func is_chip_valid() -> bool:
	var source: FlowNodePropertyRefValueSource = 		get_value_source() as FlowNodePropertyRefValueSource
	if source == null or not source.is_valid():
		return false
	if _resolution_context == null:
		return true
	return source.resolve(_resolution_context).success


func validate_structure(result: FlowValidationResult, element_path: String) -> void:
	var source: FlowValueSource = get_value_source()
	if source == null:
		return
	if not source is FlowNodePropertyRefValueSource:
		result.add_diagnostic(FlowDiagnostic.new(
			FlowDiagnostic.CODE_INVALID_VALUE_SOURCE,
			FlowDiagnostic.Severity.ERROR,
			"NodePropertyRef segment requires a FlowNodePropertyRefValueSource.",
			element_path + ".value_source",
			segment_id
		))
		return
	(source as FlowNodePropertyRefValueSource).validate_structure(
		result,
		element_path + ".value_source"
	)


func duplicate_with_new_id() -> FlowDocumentSegment:
	var copy: FlowNodePropertyRefSegment = duplicate(false) as FlowNodePropertyRefSegment
	copy._segment_id = FlowId.create()
	copy._resolution_context = null
	var source: FlowValueSource = get_value_source()
	copy._value_source = source.duplicate_with_new_id() if source != null else null
	return copy
