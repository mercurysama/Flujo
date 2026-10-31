@tool
## Generic expression Tok projection backed by one FlowExpressionValueSource.
class_name FlowExpressionSegment
extends FlowChipSegment


const CHIP_TYPE: StringName = &"expression"
const DISPLAY_NAME: String = "Expression"
const CATEGORY: StringName = &"expression"
const LABEL_STRATEGY: StringName = &"generated_preview"
const STYLE_ROLE: StringName = &"expression"

var _variable_graph: FlowGraph = null


func _init(new_source: FlowExpressionValueSource = null) -> void:
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
	var source: FlowExpressionValueSource = get_value_source() as FlowExpressionValueSource
	return source.get_preview(_variable_graph) if source != null else "<invalid expression>"


func get_chip_tooltip_data() -> FlowChipTooltipData:
	var data: FlowChipTooltipData = FlowChipTooltipData.new(DISPLAY_NAME)
	var source: FlowExpressionValueSource = get_value_source() as FlowExpressionValueSource
	data.add_field("Type", DISPLAY_NAME)
	if source == null:
		data.add_field("Result Type", "invalid")
		data.add_field("Expression", "<null source>")
		return data
	data.add_field("Result Type", FlowChipTypeDescriptor.variant_type_display_name(source.get_value_type()))
	data.add_field("Expression", source.get_preview(_variable_graph))
	data.add_field("Inputs", source.get_operand_summary(_variable_graph))
	return data


func get_editable_value_type() -> Variant.Type:
	return get_value_type()


func get_editable_value() -> Variant:
	return get_chip_label()


func set_variable_graph(graph: FlowGraph) -> void:
	_variable_graph = graph


func get_value_type() -> Variant.Type:
	var source: FlowExpressionValueSource = get_value_source() as FlowExpressionValueSource
	return source.get_value_type() if source != null else Variant.Type.TYPE_NIL


func validate_structure(result: FlowValidationResult, element_path: String) -> void:
	var source: FlowValueSource = get_value_source()
	if source == null:
		return
	if not source is FlowExpressionValueSource:
		result.add_diagnostic(FlowDiagnostic.new(
			FlowDiagnostic.CODE_INVALID_VALUE_SOURCE,
			FlowDiagnostic.Severity.ERROR,
			"Expression segment requires a FlowExpressionValueSource.",
			element_path + ".value_source",
			segment_id
		))
		return
	(source as FlowExpressionValueSource).validate_structure(result, element_path + ".value_source")


func is_chip_valid() -> bool:
	var source: FlowExpressionValueSource = get_value_source() as FlowExpressionValueSource
	if source == null or not source.is_valid():
		return false
	if _variable_graph == null:
		return true
	for operand: FlowValueSource in source.operands:
		var variable_source: FlowVariableRefValueSource = operand as FlowVariableRefValueSource
		if variable_source != null and variable_source.resolve_definition(_variable_graph) == null:
			return false
	return true


func duplicate_with_new_id() -> FlowDocumentSegment:
	var copy: FlowExpressionSegment = duplicate(false) as FlowExpressionSegment
	copy._segment_id = FlowId.create()
	copy._variable_graph = null
	var source: FlowValueSource = get_value_source()
	copy._value_source = source.duplicate_with_new_id() if source != null else null
	return copy
