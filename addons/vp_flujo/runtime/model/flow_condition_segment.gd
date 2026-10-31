@tool
## Generic Condition Tok projection backed by one FlowConditionValueSource.
class_name FlowConditionSegment
extends FlowChipSegment


const CHIP_TYPE: StringName = &"condition"
const DISPLAY_NAME: String = "Condition"
const CATEGORY: StringName = &"condition"
const LABEL_STRATEGY: StringName = &"generated_preview"
const STYLE_ROLE: StringName = &"condition"

var _variable_graph: FlowGraph = null


func _init(new_source: FlowConditionValueSource = null) -> void:
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
	var source: FlowConditionValueSource = get_value_source() as FlowConditionValueSource
	return source.get_preview(_variable_graph) if source != null else "<missing>"


func get_chip_tooltip_data() -> FlowChipTooltipData:
	var data: FlowChipTooltipData = FlowChipTooltipData.new(DISPLAY_NAME)
	var source: FlowConditionValueSource = get_value_source() as FlowConditionValueSource
	data.add_field("Type", DISPLAY_NAME)
	data.add_field("Produced Type", "bool")
	data.add_field("Preview", source.get_preview(_variable_graph) if source != null else "<missing>")
	data.add_field("Validity", "valid" if is_chip_valid() else "invalid")
	return data


func set_variable_graph(graph: FlowGraph) -> void:
	_variable_graph = graph


func get_value_type() -> Variant.Type:
	return FlowConditionValueSource.PRODUCED_TYPE


func validate_structure(result: FlowValidationResult, element_path: String) -> void:
	var source: FlowConditionValueSource = get_value_source() as FlowConditionValueSource
	if source == null:
		result.add_diagnostic(FlowDiagnostic.new(
			FlowDiagnostic.CODE_INVALID_VALUE_SOURCE,
			FlowDiagnostic.Severity.ERROR,
			"Condition segment requires a FlowConditionValueSource.",
			element_path + ".value_source",
			segment_id
		))
		return
	source.validate_against_graph(result, element_path + ".value_source", _variable_graph)


func is_chip_valid() -> bool:
	var source: FlowConditionValueSource = get_value_source() as FlowConditionValueSource
	return source != null and source.is_valid(_variable_graph)


func duplicate_with_new_id() -> FlowDocumentSegment:
	var copy: FlowConditionSegment = duplicate(false) as FlowConditionSegment
	copy._segment_id = FlowId.create()
	copy._variable_graph = null
	var source: FlowValueSource = get_value_source()
	copy._value_source = source.duplicate_with_new_id() if source != null else null
	return copy
