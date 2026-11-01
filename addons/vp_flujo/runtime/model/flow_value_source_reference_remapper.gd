@tool
## Remaps stable graph-owned IDs inside nested ValueSource trees.
##
## The source tree owns source_id identities, but references such as variable_id
## and requirement_id belong to the surrounding FlowGraph. Graph duplication
## renews those target IDs, so every nested source must be visited after the
## duplicate's complete ID map is known.
class_name FlowValueSourceReferenceRemapper
extends RefCounted


static func remap_graph_ids(
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
	if source is FlowNodeRefValueSource:
		var node_ref: FlowNodeRefValueSource = source as FlowNodeRefValueSource
		if not node_ref.requirement_id.is_empty() 				and id_map.has(node_ref.requirement_id):
			node_ref.requirement_id = id_map[node_ref.requirement_id]
		return
	if source is FlowNodePropertyRefValueSource:
		var node_property: FlowNodePropertyRefValueSource = 			source as FlowNodePropertyRefValueSource
		if not node_property.requirement_id.is_empty() 				and id_map.has(node_property.requirement_id):
			node_property.requirement_id = id_map[node_property.requirement_id]
		return
	if source is FlowArrayValueSource:
		for child: FlowValueSource in (source as FlowArrayValueSource).elements:
			remap_graph_ids(child, id_map)
		return
	if source is FlowDictionaryValueSource:
		for entry: FlowDictionaryEntry in (source as FlowDictionaryValueSource).entries:
			if entry != null:
				remap_graph_ids(entry.value_source, id_map)
		return
	if source is FlowExpressionValueSource:
		for operand: FlowValueSource in (source as FlowExpressionValueSource).operands:
			remap_graph_ids(operand, id_map)
		return
	if source is FlowOperationValueSource:
		for operand: FlowValueSource in (source as FlowOperationValueSource).operands:
			remap_graph_ids(operand, id_map)
		return
	if source is FlowConditionValueSource:
		for comparison: FlowConditionComparison in 				(source as FlowConditionValueSource).comparisons:
			if comparison == null:
				continue
			remap_graph_ids(comparison.left_source, id_map)
			remap_graph_ids(comparison.right_source, id_map)


## Compatibility alias retained for Lot 09 callers.
static func remap_variable_ids(
		source: FlowValueSource,
		id_map: Dictionary[String, String]
) -> void:
	remap_graph_ids(source, id_map)
