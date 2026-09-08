@tool
class_name FlowMethodDefinition
extends FlowBlockContainer

@export var parameters: Array[FlowMethodParameterDefinition] = []
@export var return_definition: FlowMethodReturnDefinition

func _init() -> void:
	display_name = "Method"

func duplicate_method_with_new_ids() -> FlowMethodDefinition:
	var copy: FlowMethodDefinition = duplicate(false) as FlowMethodDefinition
	var id_counts: Dictionary[String, int] = _collect_owned_id_counts()
	var id_map: Dictionary[String, String] = {}
	copy._internal_id = _duplicate_internal_id(_internal_id, id_counts, id_map)

	copy.blocks = []
	for block: FlowBlock in blocks:
		if block == null:
			copy.blocks.append(null)
			continue

		var block_copy: FlowBlock = block.duplicate(false) as FlowBlock
		block_copy._internal_id = _duplicate_internal_id(
			block.get_internal_id(),
			id_counts,
			id_map
		)
		copy.blocks.append(block_copy)

	copy.parameters = []
	for parameter: FlowMethodParameterDefinition in parameters:
		if parameter == null:
			copy.parameters.append(null)
			continue

		var parameter_copy: FlowMethodParameterDefinition = parameter.duplicate(false) as FlowMethodParameterDefinition
		parameter_copy._internal_id = _duplicate_internal_id(
			parameter.get_internal_id(),
			id_counts,
			id_map
		)
		copy.parameters.append(parameter_copy)

	if return_definition == null:
		copy.return_definition = null
	else:
		var return_copy: FlowMethodReturnDefinition = return_definition.duplicate(false) as FlowMethodReturnDefinition
		return_copy._internal_id = _duplicate_internal_id(
			return_definition.get_internal_id(),
			id_counts,
			id_map
		)
		copy.return_definition = return_copy

	_remap_method_calls(copy.blocks, id_map)
	return copy


func _collect_owned_id_counts() -> Dictionary[String, int]:
	var id_counts: Dictionary[String, int] = {}
	_count_id(_internal_id, id_counts)
	for block: FlowBlock in blocks:
		if block != null:
			_count_id(block.get_internal_id(), id_counts)
	for parameter: FlowMethodParameterDefinition in parameters:
		if parameter != null:
			_count_id(parameter.get_internal_id(), id_counts)
	if return_definition != null:
		_count_id(return_definition.get_internal_id(), id_counts)
	return id_counts


func _count_id(value: String, id_counts: Dictionary[String, int]) -> void:
	id_counts[value] = int(id_counts.get(value, 0)) + 1


func _duplicate_internal_id(
		original_id: String,
		id_counts: Dictionary[String, int],
		id_map: Dictionary[String, String]
) -> String:
	if original_id.is_empty() \
			or not FlowId.is_valid(original_id) \
			or int(id_counts.get(original_id, 0)) != 1:
		return original_id

	var copied_id: String = FlowId.create()
	id_map[original_id] = copied_id
	return copied_id


func _remap_method_calls(blocks_to_remap: Array[FlowBlock], id_map: Dictionary[String, String]) -> void:
	for block: FlowBlock in blocks_to_remap:
		if block is FlowMethodCallBlock:
			var method_call: FlowMethodCallBlock = block as FlowMethodCallBlock
			if id_map.has(method_call.method_id):
				method_call.method_id = id_map[method_call.method_id]
