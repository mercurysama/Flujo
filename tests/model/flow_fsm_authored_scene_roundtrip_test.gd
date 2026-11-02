extends SceneTree

## Potok 7E-1A: authored FSM IDs and phase order survive a real saved scene.
## Run: godot --headless --path . --script tests/model/flow_fsm_authored_scene_roundtrip_test.gd

const TEMP_DIR: String = "res://.godot/flujo_tests"
const SCENE_PATH: String = TEMP_DIR + "/potok_7e1a_authored_roundtrip.tscn"

var failures: Array[String] = []


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var root := Node.new()
	root.name = "PotokAuthoredRoot"
	var controller := PVController.new()
	controller.name = "ControllerNode"
	var graph := FlowGraph.new()
	graph.schema_version = FlowGraph.SCHEMA_VERSION_3
	graph.constructor = FlowConstructorDefinition.new()

	var idle := FlowStateDefinition.new()
	idle.display_name = "Idle"
	var active := FlowStateDefinition.new()
	active.display_name = "Active"

	var enter_first := FlowPrintBlock.new()
	enter_first.text = "enter first"
	var enter_second := FlowPrintBlock.new()
	enter_second.text = "enter second"
	var update_block := FlowPrintBlock.new()
	update_block.text = "update"
	var exit_block := FlowPrintBlock.new()
	exit_block.text = "exit"
	idle.enter_blocks = [enter_first, enter_second]
	idle.blocks = [update_block]
	idle.exit_blocks = [exit_block]

	var edge := FlowStateTransitionDefinition.new()
	edge.display_name = "Advance"
	edge.trigger = FlowStateTransitionDefinition.Trigger.EVENT
	edge.event_name = &"advance"
	edge.priority = 3
	edge.target_state_id = active.get_internal_id()
	idle.transitions = [edge]

	var machine := FlowStateMachineDefinition.new()
	machine.display_name = "Character"
	machine.states = [idle, active]
	machine.initial_state_id = idle.get_internal_id()
	graph.state_machines = [machine]
	controller.flow_graph = graph
	root.add_child(controller)
	controller.owner = root

	_check(not FlowGraphValidator.validate(graph).has_errors(), "Original schema-3 authored graph validates")
	var original_graph_id: String = graph.get_internal_id()
	var original_machine_id: String = machine.get_internal_id()
	var original_idle_id: String = idle.get_internal_id()
	var original_active_id: String = active.get_internal_id()
	var original_edge_id: String = edge.get_internal_id()
	var original_enter_ids: Array[String] = [
		enter_first.get_internal_id(), enter_second.get_internal_id()
	]
	var original_update_id: String = update_block.get_internal_id()
	var original_exit_id: String = exit_block.get_internal_id()

	var dir_result: Error = DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(TEMP_DIR)
	)
	_check(dir_result == OK, "Owned temporary directory is available")
	var packed := PackedScene.new()
	var pack_result: Error = packed.pack(root)
	_check(pack_result == OK, "Scene packs with owned PVController and FlowGraph")
	var save_result: Error = FAILED
	if pack_result == OK and dir_result == OK:
		save_result = ResourceSaver.save(packed, ProjectSettings.globalize_path(SCENE_PATH))
	_check(save_result == OK, "Real scene saved to temporary .tscn")
	root.free()
	await process_frame

	if save_result == OK:
		var loaded: PackedScene = ResourceLoader.load(
			SCENE_PATH, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE
		) as PackedScene
		if _check(loaded != null, "Saved scene reopens through ResourceLoader"):
			var instance: Node = loaded.instantiate()
			if _check(instance != null, "Reopened scene instantiates"):
				var reopened: PVController = instance.get_node_or_null("ControllerNode") as PVController
				if _check(reopened != null and reopened.flow_graph != null,
						"Reopened scene owns a persistent PVController graph"):
					var saved_graph: FlowGraph = reopened.flow_graph
					_check(saved_graph.schema_version == FlowGraph.SCHEMA_VERSION_3,
						"Schema version survives save/reopen")
					_check(saved_graph.get_internal_id() == original_graph_id,
						"Graph stable ID survives save/reopen")
					_check(saved_graph.state_machines.size() == 1,
						"One authored machine survives")
					if saved_graph.state_machines.size() == 1:
						var saved_machine: FlowStateMachineDefinition = saved_graph.state_machines[0]
						_check(saved_machine.get_internal_id() == original_machine_id,
							"Machine stable ID survives")
						_check(saved_machine.initial_state_id == original_idle_id,
							"Initial state reference survives")
						_check(saved_machine.states.size() == 2,
							"State order and count survive")
						if saved_machine.states.size() == 2:
							var saved_idle: FlowStateDefinition = saved_machine.states[0]
							var saved_active: FlowStateDefinition = saved_machine.states[1]
							_check(saved_idle.get_internal_id() == original_idle_id
								and saved_active.get_internal_id() == original_active_id,
								"Ordered state IDs do not change")
							_check(saved_idle.enter_blocks.size() == 2
								and saved_idle.blocks.size() == 1
								and saved_idle.exit_blocks.size() == 1,
								"Enter/Update/Exit phase sizes survive")
							if saved_idle.enter_blocks.size() == 2:
								_check(saved_idle.enter_blocks[0].get_internal_id() == original_enter_ids[0]
									and saved_idle.enter_blocks[1].get_internal_id() == original_enter_ids[1],
									"Enter block order and stable IDs survive")
								_check((saved_idle.enter_blocks[0] as FlowPrintBlock).text == "enter first"
									and (saved_idle.enter_blocks[1] as FlowPrintBlock).text == "enter second",
									"Enter phase content survives")
							if saved_idle.blocks.size() == 1:
								_check(saved_idle.blocks[0].get_internal_id() == original_update_id,
									"Legacy Update block ID survives")
							if saved_idle.exit_blocks.size() == 1:
								_check(saved_idle.exit_blocks[0].get_internal_id() == original_exit_id,
									"Exit block ID survives")
							_check(saved_idle.transitions.size() == 1,
								"Transition count survives")
							if saved_idle.transitions.size() == 1:
								var saved_edge: FlowStateTransitionDefinition = saved_idle.transitions[0]
								_check(saved_edge.get_internal_id() == original_edge_id
									and saved_edge.target_state_id == original_active_id,
									"Transition ID and target reference survive")
								_check(saved_edge.trigger == FlowStateTransitionDefinition.Trigger.EVENT
									and saved_edge.event_name == &"advance" and saved_edge.priority == 3,
									"Event trigger and priority survive")
					_check(not FlowGraphValidator.validate(saved_graph).has_errors(),
						"Reopened authored graph remains valid")
				instance.free()

	_cleanup()
	if failures.is_empty():
		print("[Flujo] Potok 7E-1A authored scene roundtrip passed")
	else:
		for failure: String in failures:
			push_error("[Flujo] Potok 7E-1A: " + failure)
	quit(0 if failures.is_empty() else 1)


func _check(ok: bool, message: String) -> bool:
	if not ok:
		failures.append(message)
	return ok


func _cleanup() -> void:
	var absolute_path: String = ProjectSettings.globalize_path(SCENE_PATH)
	if FileAccess.file_exists(absolute_path):
		DirAccess.remove_absolute(absolute_path)
	var absolute_dir: String = ProjectSettings.globalize_path(TEMP_DIR)
	if DirAccess.dir_exists_absolute(absolute_dir):
		var directory: DirAccess = DirAccess.open(absolute_dir)
		if directory != null and directory.get_files().is_empty() and directory.get_directories().is_empty():
			DirAccess.remove_absolute(absolute_dir)
