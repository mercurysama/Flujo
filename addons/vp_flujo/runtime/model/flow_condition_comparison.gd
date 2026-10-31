@tool
## Persistent one-row comparison owned by a FlowConditionValueSource.
class_name FlowConditionComparison
extends Resource


@export_storage var comparison_id: String = FlowId.create()
@export_storage var operator_id: StringName = &""
@export var left_source: FlowValueSource = null
@export var right_source: FlowValueSource = null


func _init(
		new_operator_id: StringName = &"",
		new_left_source: FlowValueSource = null,
		new_right_source: FlowValueSource = null,
		new_comparison_id: String = ""
) -> void:
	operator_id = new_operator_id
	left_source = new_left_source
	right_source = new_right_source
	if not new_comparison_id.is_empty():
		comparison_id = new_comparison_id


func get_preview(variable_graph: FlowGraph = null) -> String:
	var left_text: String = FlowConditionValueSource.preview_source(left_source, variable_graph)
	var right_text: String = FlowConditionValueSource.preview_source(right_source, variable_graph)
	var symbol_text: String = FlowConditionOperatorCatalog.symbol(operator_id)
	if symbol_text.is_empty():
		symbol_text = "<unset>"
	return "%s %s %s" % [left_text, symbol_text, right_text]


func duplicate_with_new_id() -> FlowConditionComparison:
	var copy: FlowConditionComparison = duplicate(false) as FlowConditionComparison
	copy.comparison_id = FlowId.create()
	copy.left_source = left_source.duplicate_with_new_id() if left_source != null else null
	copy.right_source = right_source.duplicate_with_new_id() if right_source != null else null
	return copy
