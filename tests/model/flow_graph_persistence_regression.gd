extends SceneTree

const TEMP_DIR_PATH: String = "res://.godot/flujo_tests"
const TEMP_SCENE_PATH: String = TEMP_DIR_PATH + "/pv_controller_flow_graph_regression.tscn"

var _failures: Array[String] = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var root: Node = Node.new()
	var controller: PVController = null
	var scene_path: String = ""
	var loaded_scene: PackedScene = null
	var instance_a: Node = null
	var instance_b: Node = null
	var controller_a: PVController = null
	var controller_b: PVController = null
	var graph_a: FlowGraph = null
	var graph_b: FlowGraph = null
	var original_graph_id: String = ""
	var original_process_id: String = ""
	var original_global_variable_id: String = ""
	var original_machine_id: String = ""
	var original_idle_state_id: String = ""

	controller = _build_controller_with_schema_2_graph()
	original_graph_id = controller.flow_graph.get_internal_id()
	original_process_id = controller.flow_graph.processes[0].get_internal_id()
	original_global_variable_id = controller.flow_graph.variables[2].get_internal_id()
	original_machine_id = controller.flow_graph.state_machines[0].get_internal_id()
	original_idle_state_id = controller.flow_graph.state_machines[0].states[0].get_internal_id()
	root.name = "FlowGraphPersistenceRoot"
	root.add_child(controller)
	controller.owner = root
	_assert(_save_scene(root), "Scene can be saved to the temp Godot project folder.")
	scene_path = ProjectSettings.globalize_path(TEMP_SCENE_PATH)
	_assert(FileAccess.file_exists(scene_path), "Saved scene exists on disk before reloading.")
	root.free()
	root = null
	controller = null
	await process_frame
	loaded_scene = load(TEMP_SCENE_PATH) as PackedScene
	_assert(loaded_scene != null, "Saved scene can be loaded back from disk.")
	instance_a = loaded_scene.instantiate()
	instance_b = loaded_scene.instantiate()
	_assert(instance_a != null and instance_b != null, "Both instances are created from the saved scene.")
	controller_a = instance_a.get_node("ControllerNode") as PVController
	controller_b = instance_b.get_node("ControllerNode") as PVController
	_assert(controller_a != null and controller_b != null, "Both instantiations resolve the same PVController node path.")
	_assert(controller_a.flow_graph != null and controller_b.flow_graph != null, "Both instantiations retain a schema 2 FlowGraph.")
	_assert(controller_a.flow_graph.schema_version == FlowGraph.SCHEMA_VERSION_2, "Loaded schema version is preserved.")
	_assert(controller_a.flow_graph.get_internal_id() == original_graph_id, "FlowGraph internal ID is preserved.")
	graph_a = controller_a.flow_graph
	graph_b = controller_b.flow_graph
	_assert(graph_a.processes.size() == 4, "Process list retains order and null slots.")
	_assert(graph_a.processes[0] is FlowProcess and graph_a.processes[2] is FlowProcess, "Process resource types survive serialization.")
	_assert(graph_a.processes[1] == null, "Null position is preserved in process arrays.")
	_assert(graph_a.processes[0].display_name == "Spawn", "Process display name is preserved.")
	_assert(graph_a.processes[0].get_internal_id() == original_process_id, "Process internal ID is preserved.")
	_assert(graph_a.processes[0].get_internal_id() != graph_a.processes[2].get_internal_id(), "Process IDs remain stable and unique.")
	_assert(graph_a.processes[0].blocks[0].display_name == "Initialize", "Block metadata survives serialization.")
	_assert(graph_a.variables.size() == 4, "Variable list retains order and null slots.")
	_assert(graph_a.variables[0] is FlowVariableDefinition and graph_a.variables[2] is FlowVariableDefinition, "Variable resource types survive serialization.")
	_assert(graph_a.variables[1] == null, "Null position is preserved in variable arrays.")
	_assert(graph_a.variables[0].int_value == 42, "Persistent primitive value survives round-trip.")
	_assert(graph_a.variables[0].owner_container_id == graph_a.processes[0].get_internal_id(), "Owner reference remains by internal ID.")
	_assert(graph_a.variables[2].scope == FlowVariableDefinition.Scope.GLOBAL, "Global variable scope survives serialization.")
	_assert(graph_a.variables[2].get_internal_id() == original_global_variable_id, "Variable internal ID is preserved.")
	_assert(graph_a.variables[3].global_variable_id == graph_a.variables[2].get_internal_id(), "Global variable reference resolves by internal ID.")
	_assert(graph_a.state_machines.size() == 1, "State machine list is preserved.")
	_assert(graph_a.state_machines[0] is FlowStateMachineDefinition, "State machine resource type survives serialization.")
	_assert(graph_a.state_machines[0].display_name == "Combat States", "State machine name survives round-trip.")
	_assert(graph_a.state_machines[0].get_internal_id() == original_machine_id, "State machine internal ID is preserved.")
	_assert(graph_a.state_machines[0].states[0] is FlowStateDefinition, "State resource type survives serialization.")
	_assert(graph_a.state_machines[0].states[0].display_name == "Idle", "State metadata is preserved.")
	_assert(graph_a.state_machines[0].states[0].get_internal_id() == original_idle_state_id, "State internal ID is preserved.")
	_assert(graph_a.state_machines[0].initial_state_id == graph_a.state_machines[0].states[0].get_internal_id(), "Initial state ID survives serialization.")
	_assert(graph_a.state_machines[0].states[2].display_name == "Active", "State values remain in their array positions.")
	_assert(graph_b.schema_version == FlowGraph.SCHEMA_VERSION_2, "The second instance observes the persisted schema version.")
	_assert(graph_b.get_internal_id() == original_graph_id, "The second instance observes the persisted FlowGraph ID.")
	_assert(graph_b.processes.size() == 4 and graph_b.processes[1] == null, "The second instance observes process order and null slots.")
	_assert(graph_b.processes[0] is FlowProcess and graph_b.processes[0].display_name == "Spawn", "The second instance observes persisted process type and name.")
	_assert(graph_b.processes[0].get_internal_id() == original_process_id, "The second instance observes the persisted process ID.")
	_assert(graph_b.variables.size() == 4 and graph_b.variables[1] == null, "The second instance observes variable order and null slots.")
	_assert(graph_b.variables[0] is FlowVariableDefinition and graph_b.variables[0].int_value == 42, "The second instance observes the persisted variable value.")
	_assert(graph_b.variables[0].owner_container_id == graph_b.processes[0].get_internal_id(), "The second instance observes the persisted owner reference.")
	_assert(graph_b.variables[3].global_variable_id == graph_b.variables[2].get_internal_id(), "The second instance observes the persisted global reference.")
	_assert(graph_b.state_machines.size() == 1 and graph_b.state_machines[0] is FlowStateMachineDefinition, "The second instance observes the persisted state machine type.")
	_assert(graph_b.state_machines[0].get_internal_id() == original_machine_id, "The second instance observes the persisted state machine ID.")
	_assert(graph_b.state_machines[0].states[0] is FlowStateDefinition and graph_b.state_machines[0].states[0].get_internal_id() == original_idle_state_id, "The second instance observes the persisted state ID.")
	_assert(graph_b.state_machines[0].initial_state_id == graph_b.state_machines[0].states[0].get_internal_id(), "The second instance observes the persisted initial-state reference.")
	_assert(instance_a.scene_file_path == TEMP_SCENE_PATH, "The regression uses a normal PackedScene instance, not a simulated inherited scene.")

	if instance_a != null:
		instance_a.free()
	if instance_b != null:
		instance_b.free()
	if root != null:
		root.free()
	_cleanup_temp_scene()
	_finish()


func _build_controller_with_schema_2_graph() -> PVController:
	var graph: FlowGraph = FlowGraph.new()
	graph.schema_version = FlowGraph.SCHEMA_VERSION_2

	var process_a: FlowProcess = FlowProcess.new()
	process_a.display_name = "Spawn"
	process_a.process_type = FlowProcess.ProcessType.READY
	var block_a: FlowBlock = FlowBlock.new()
	block_a.display_name = "Initialize"
	block_a.enabled = true
	process_a.blocks = [block_a, null]

	var process_b: FlowProcess = FlowProcess.new()
	process_b.display_name = "Tick"
	process_b.process_type = FlowProcess.ProcessType.PROCESS
	var block_b: FlowBlock = FlowBlock.new()
	block_b.display_name = "Update"
	block_b.enabled = false
	process_b.blocks = [null, block_b]

	var process_c: FlowProcess = FlowProcess.new()
	process_c.display_name = "Cleanup"
	process_c.process_type = FlowProcess.ProcessType.PHYSICS_PROCESS
	process_c.blocks = []
	graph.processes = [process_a, null, process_b, process_c]

	var local_variable: FlowVariableDefinition = FlowVariableDefinition.new()
	local_variable.display_name = "Local Counter"
	local_variable.scope = FlowVariableDefinition.Scope.LOCAL
	local_variable.binding = FlowVariableDefinition.Binding.OWN_VALUE
	local_variable.value_type = FlowVariableDefinition.ValueType.INT
	local_variable.int_value = 42
	local_variable.owner_container_id = process_a.get_internal_id()

	var global_variable: FlowVariableDefinition = FlowVariableDefinition.new()
	global_variable.display_name = "Shared Value"
	global_variable.scope = FlowVariableDefinition.Scope.GLOBAL
	global_variable.binding = FlowVariableDefinition.Binding.OWN_VALUE
	global_variable.value_type = FlowVariableDefinition.ValueType.STRING
	global_variable.string_value = "shared"
	global_variable.owner_container_id = process_c.get_internal_id()

	var reference_variable: FlowVariableDefinition = FlowVariableDefinition.new()
	reference_variable.display_name = "Global Ref"
	reference_variable.scope = FlowVariableDefinition.Scope.LOCAL
	reference_variable.binding = FlowVariableDefinition.Binding.GLOBAL_REFERENCE
	reference_variable.value_type = FlowVariableDefinition.ValueType.STRING
	reference_variable.string_value = "ref"
	reference_variable.owner_container_id = process_b.get_internal_id()
	reference_variable.global_variable_id = global_variable.get_internal_id()

	graph.variables = [local_variable, null, global_variable, reference_variable]

	var state_idle: FlowStateDefinition = FlowStateDefinition.new()
	state_idle.display_name = "Idle"
	state_idle.is_initial = true
	state_idle.enabled = true
	var state_active: FlowStateDefinition = FlowStateDefinition.new()
	state_active.display_name = "Active"
	state_active.enabled = true
	var state_waiting: FlowStateDefinition = FlowStateDefinition.new()
	state_waiting.display_name = "Waiting"
	state_waiting.enabled = false
	var machine: FlowStateMachineDefinition = FlowStateMachineDefinition.new()
	machine.display_name = "Combat States"
	machine.states = [state_idle, null, state_active, state_waiting]
	machine.initial_state_id = state_idle.get_internal_id()
	graph.state_machines = [machine]

	var controller: PVController = PVController.new()
	controller.name = "ControllerNode"
	controller.flow_graph = graph
	return controller


func _save_scene(root: Node) -> bool:
	var packed_scene: PackedScene = PackedScene.new()
	var save_result: Error = packed_scene.pack(root)
	if save_result != OK:
		return false
	var dir_path: String = ProjectSettings.globalize_path(TEMP_DIR_PATH)
	if not DirAccess.dir_exists_absolute(dir_path):
		DirAccess.make_dir_recursive_absolute(dir_path)
	var save_status: Error = ResourceSaver.save(packed_scene, ProjectSettings.globalize_path(TEMP_SCENE_PATH))
	return save_status == OK


func _cleanup_temp_scene() -> void:
	var scene_path: String = ProjectSettings.globalize_path(TEMP_SCENE_PATH)
	if FileAccess.file_exists(scene_path):
		DirAccess.remove_absolute(scene_path)
	var temp_dir: String = ProjectSettings.globalize_path(TEMP_DIR_PATH)
	if DirAccess.dir_exists_absolute(temp_dir):
		var dir_access: DirAccess = DirAccess.open(temp_dir)
		if dir_access != null:
			var files: PackedStringArray = dir_access.get_files()
			var directories: PackedStringArray = dir_access.get_directories()
			if files.is_empty() and directories.is_empty():
				DirAccess.remove_absolute(temp_dir)


func _finish() -> void:
	if _failures.is_empty():
		print("[Flujo] FlowGraph persistence regression passed")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	quit(1)


func _assert(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
