@tool
## Remaps stable graph-owned IDs inside nested ValueSource trees.
class_name FlowValueSourceReferenceRemapper
extends RefCounted


static func remap_variable_ids(
		source: FlowValueSource,
		id_map: Dictionary[String, String]
) -> void:
	if source == null or id_map.is_empty():
		return
	if source is FlowVariableRefValueSource:
		var variable: FlowVariableRefValueSource = source as FlowVariableRefValueSource
		if id_map.has(variable.variable_id):
			variable.variable_id = id_map[variable.variable_id]
		return
	if source is FlowArrayValueSource:
		for child: FlowValueSource in (source as FlowArrayValueSource).elements:
			remap_variable_ids(child, id_map)
		return
	if source is FlowDictionaryValueSource:
		for entry: FlowDictionaryEntry in (source as FlowDictionaryValueSource).entries:
			if entry != null:
				remap_variable_ids(entry.value_source, id_map)
		return
	if source is FlowExpressionValueSource:
		for operand: FlowValueSource in (source as FlowExpressionValueSource).operands:
			remap_variable_ids(operand, id_map)
		return
	if source is FlowOperationValueSource:
		for operand: FlowValueSource in (source as FlowOperationValueSource).operands:
			remap_variable_ids(operand, id_map)
		return
	if source is FlowConditionValueSource:
		for comparison: FlowConditionComparison in (source as FlowConditionValueSource).comparisons:
			if comparison == null:
				continue
			remap_variable_ids(comparison.left_source, id_map)
			remap_variable_ids(comparison.right_source, id_map)
