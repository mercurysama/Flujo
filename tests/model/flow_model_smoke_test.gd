extends Node


func _ready() -> void:
	await get_tree().process_frame

	var original: FlowGraph = FlowGraph.new()

	var process: FlowProcess = FlowProcess.new()
	process.display_name = "Main Process"

	var block: FlowBlock = FlowBlock.new()
	block.display_name = "Print"
	process.blocks.append(block)

	var state: FlowStateDefinition = FlowStateDefinition.new()
	state.display_name = "Idle"
	state.is_initial = true

	original.containers.append(process)
	original.containers.append(null)
	original.containers.append(state)

	var copy: FlowGraph = original.duplicate_with_new_ids()

	assert(copy != original)
	assert(original.get_internal_id().length() == 32)
	assert(copy.get_internal_id().length() == 32)
	assert(process.get_internal_id().length() == 32)
	assert(block.get_internal_id().length() == 32)
	assert(state.get_internal_id().length() == 32)
	assert(copy.get_internal_id() != original.get_internal_id())
	assert(copy.containers.size() == 3)
	assert(copy.containers[0] is FlowProcess)
	assert(copy.containers[1] == null)
	assert(copy.containers[2] is FlowStateDefinition)

	var process_copy: FlowProcess = copy.containers[0] as FlowProcess
	var state_copy: FlowStateDefinition = copy.containers[2] as FlowStateDefinition

	assert(process_copy.get_internal_id().length() == 32)
	assert(state_copy.get_internal_id().length() == 32)
	assert(process_copy.get_internal_id() != process.get_internal_id())
	assert(state_copy.get_internal_id() != state.get_internal_id())
	assert(process_copy.display_name == "Main Process")
	assert(state_copy.display_name == "Idle")
	assert(state_copy.is_initial)
	assert(process_copy.blocks.size() == 1)
	assert(process_copy.blocks[0] != null)
	assert(process_copy.blocks[0].get_internal_id().length() == 32)
	assert(process_copy.blocks[0].get_internal_id() != block.get_internal_id())
	assert(process_copy.blocks[0].display_name == "Print")

	var first_controller: PVController = PVController.new()
	var second_controller: PVController = PVController.new()
	assert(first_controller.flow_graph != second_controller.flow_graph)
	first_controller.free()
	second_controller.free()

	print("[Flujo] Model smoke test passed")
	await get_tree().process_frame
	get_tree().quit()
