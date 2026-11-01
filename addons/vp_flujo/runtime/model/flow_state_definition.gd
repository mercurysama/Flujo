@tool
class_name FlowStateDefinition
extends FlowBlockContainer

@export var is_initial: bool = false
## Empty legacy phases default safely; blocks remains the Update phase.
@export var enter_blocks: Array[FlowBlock] = []
@export var exit_blocks: Array[FlowBlock] = []

func _init() -> void:
	display_name = "State"

func duplicate_state_with_new_ids() -> FlowStateDefinition:
	var copy: FlowStateDefinition = duplicate_with_new_ids() as FlowStateDefinition
	copy.enter_blocks = _copy_phase(enter_blocks)
	copy.exit_blocks = _copy_phase(exit_blocks)
	return copy


func _copy_phase(source: Array[FlowBlock]) -> Array[FlowBlock]:
	var result: Array[FlowBlock] = []
	for block: FlowBlock in source:
		result.append(block.duplicate_with_new_id() if block != null else null)
	return result
