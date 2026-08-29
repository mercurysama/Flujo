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

	var default_variable: FlowVariableDefinition = FlowVariableDefinition.new()
	assert(default_variable.get_internal_id().length() == 32)
	assert(default_variable.display_name == "Variable")
	assert(default_variable.scope == FlowVariableDefinition.Scope.LOCAL)
	assert(default_variable.binding == FlowVariableDefinition.Binding.OWN_VALUE)
	assert(default_variable.value_type == FlowVariableDefinition.ValueType.BOOL)
	assert(default_variable.bool_value == false)
	assert(default_variable.int_value == 0)
	assert(default_variable.float_value == 0.0)
	assert(default_variable.string_value == "")
	assert(default_variable.vector2_value == Vector2.ZERO)
	assert(default_variable.vector3_value == Vector3.ZERO)
	assert(default_variable.color_value == Color.WHITE)
	assert(default_variable.persistent == false)
	assert(default_variable.global_variable_id == "")
	assert(default_variable.owner_container_id == "")
	assert(default_variable.user_note == "")

	var global_variable: FlowVariableDefinition = FlowVariableDefinition.new()
	global_variable.display_name = "Player Position"
	global_variable.scope = FlowVariableDefinition.Scope.GLOBAL
	global_variable.binding = FlowVariableDefinition.Binding.OWN_VALUE
	global_variable.value_type = FlowVariableDefinition.ValueType.VECTOR3
	global_variable.vector3_value = Vector3(1.0, 2.0, 3.0)
	global_variable.persistent = true
	global_variable.user_note = "Tracks the player position."

	var global_variable_id: String = global_variable.get_internal_id()
	var global_variable_copy: FlowVariableDefinition = global_variable.duplicate_with_new_id()
	assert(global_variable_copy != global_variable)
	assert(global_variable_copy.get_internal_id().length() == 32)
	assert(global_variable_copy.get_internal_id() != global_variable_id)
	assert(global_variable.get_internal_id() == global_variable_id)
	assert(global_variable_copy.display_name == "Player Position")
	assert(global_variable_copy.scope == FlowVariableDefinition.Scope.GLOBAL)
	assert(global_variable_copy.binding == FlowVariableDefinition.Binding.OWN_VALUE)
	assert(global_variable_copy.value_type == FlowVariableDefinition.ValueType.VECTOR3)
	assert(global_variable_copy.vector3_value == Vector3(1.0, 2.0, 3.0))
	assert(global_variable_copy.persistent == true)
	assert(global_variable_copy.user_note == "Tracks the player position.")

	var global_reference: FlowVariableDefinition = FlowVariableDefinition.new()
	global_reference.scope = FlowVariableDefinition.Scope.LOCAL
	global_reference.binding = FlowVariableDefinition.Binding.GLOBAL_REFERENCE
	global_reference.value_type = FlowVariableDefinition.ValueType.VECTOR3
	global_reference.global_variable_id = global_variable_id
	global_reference.owner_container_id = process.get_internal_id()
	assert(global_reference.persistent == false)

	var global_reference_id: String = global_reference.get_internal_id()
	var global_reference_copy: FlowVariableDefinition = global_reference.duplicate_with_new_id()
	assert(global_reference_copy != global_reference)
	assert(global_reference_copy.get_internal_id().length() == 32)
	assert(global_reference_copy.get_internal_id() != global_reference_id)
	assert(global_reference_copy.global_variable_id == global_variable_id)
	assert(global_reference_copy.owner_container_id == process.get_internal_id())
	assert(global_reference_copy.scope == FlowVariableDefinition.Scope.LOCAL)
	assert(global_reference_copy.binding == FlowVariableDefinition.Binding.GLOBAL_REFERENCE)
	assert(global_reference_copy.value_type == FlowVariableDefinition.ValueType.VECTOR3)
	assert(global_reference_copy.persistent == false)
	assert(global_reference.get_internal_id() == global_reference_id)
	assert(global_reference.global_variable_id == global_variable_id)
	assert(global_reference.owner_container_id == process.get_internal_id())
	assert(global_reference.scope == FlowVariableDefinition.Scope.LOCAL)
	assert(global_reference.binding == FlowVariableDefinition.Binding.GLOBAL_REFERENCE)
	assert(global_reference.value_type == FlowVariableDefinition.ValueType.VECTOR3)
	assert(global_reference.persistent == false)

	print("[Flujo] Model smoke test passed")
	await get_tree().process_frame
	get_tree().quit()
