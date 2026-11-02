@tool
extends SceneTree

## Potok 7E-1B1: validated editor edits, two Undo/Redo cycles, then real scene save/reopen.
var failures: Array[String] = []

const TEMP_DIR: String = "res://.godot/flujo_tests"
const SCENE_PATH: String = TEMP_DIR + "/potok_7e1b1_edited_scene.tscn"


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	for _i: int in 5:
		await process_frame
	while EditorInterface.get_resource_filesystem().is_scanning():
		await process_frame

	var manager: EditorUndoRedoManager = EditorInterface.get_editor_undo_redo()
	if not _check(manager != null, "EditorUndoRedoManager available"):
		quit(1)
		return

	var root := Node.new()
	root.name = "Potok7E1B1Root"
	get_root().add_child(root)

	var graph := FlowGraph.new()
	graph.schema_version = FlowGraph.SCHEMA_VERSION_3
	graph.constructor = FlowConstructorDefinition.new()
	var idle := FlowStateDefinition.new()
	idle.display_name = "Idle"
	var running := FlowStateDefinition.new()
	running.display_name = "Running"
	var finished := FlowStateDefinition.new()
	finished.display_name = "Finished"
	var edge := FlowStateTransitionDefinition.new()
	edge.display_name = "To Running"
	edge.trigger = FlowStateTransitionDefinition.Trigger.EVENT
	edge.event_name = &"go"
	edge.target_state_id = running.get_internal_id()
	idle.transitions = [edge]

	var machine := FlowStateMachineDefinition.new()
	machine.display_name = "Character"
	machine.states = [idle, running, finished]
	machine.initial_state_id = idle.get_internal_id()
	graph.state_machines = [machine]

	var controller := PVController.new()
	controller.name = "ControllerNode"
	controller.flow_graph = graph
	root.add_child(controller)
	controller.owner = root

	var mid: String = machine.get_internal_id()
	var aid: String = idle.get_internal_id()
	var bid: String = running.get_internal_id()
	var cid: String = finished.get_internal_id()
	var eid: String = edge.get_internal_id()
	var gid: String = graph.get_internal_id()
	_check(not FlowGraphValidator.validate(graph).has_errors(),
		"Original schema-3 authored graph validates")

	var commands := FlowGraphEditorCommands.new(manager)
	var history: UndoRedo = manager.get_history_undo_redo(manager.get_object_history_id(controller))
	_check(not commands.set_fsm_state_property(controller, mid, "missing",
		&"display_name", "Rejected"), "Missing state ID rejected without mutation")
	_check(running.display_name == "Running" and machine.states[1].get_internal_id() == bid,
		"Rejected edit preserves model")

	_check(commands.set_fsm_state_property(controller, mid, bid,
		&"display_name", "Sprinting"), "Validated state rename commits")
	_check(commands.move_fsm_state(controller, mid, cid, -1),
		"Validated state reorder commits")
	_check(commands.set_fsm_machine_property(controller, mid,
		&"display_name", "Edited Character"), "Validated machine rename commits")
	_check(_final_state(machine, aid, bid, cid),
		"Edited names/order and stable references are correct")

	for _cycle: int in 2:
		history.undo()
		history.undo()
		history.undo()
		_check(machine.display_name == "Character" and running.display_name == "Running",
			"Three-step Undo restores original authored names")
		_check(machine.states.size() == 3 and
			machine.states[0].get_internal_id() == aid and
			machine.states[1].get_internal_id() == bid and
			machine.states[2].get_internal_id() == cid,
			"Three-step Undo restores original ordered state IDs")
		_check(machine.initial_state_id == aid and edge.target_state_id == bid and
			edge.get_internal_id() == eid, "Undo retains initial/target references and edge ID")
		history.redo()
		history.redo()
		history.redo()
		_check(_final_state(machine, aid, bid, cid),
			"Three-step Redo repeats exact edits with stable IDs")
		_check(not FlowGraphValidator.validate(graph).has_errors(),
			"Each full Redo yields a valid authored graph")

	var dir_result: Error = DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(TEMP_DIR)
	)
	_check(dir_result == OK, "Owned test directory exists")
	var packed := PackedScene.new()
	var pack_result: Error = packed.pack(root)
	_check(pack_result == OK, "Edited scene packs with PVController")
	var save_result: Error = FAILED
	if dir_result == OK and pack_result == OK:
		save_result = ResourceSaver.save(packed, ProjectSettings.globalize_path(SCENE_PATH))
	_check(save_result == OK, "Edited PackedScene saves as real .tscn")
	root.free()
	await process_frame

	if save_result == OK:
		var reopened_scene: PackedScene = ResourceLoader.load(
			SCENE_PATH, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE
		) as PackedScene
		if _check(reopened_scene != null, "Edited scene reloads without cache"):
			var instance: Node = reopened_scene.instantiate()
			if _check(instance != null, "Edited saved scene instantiates"):
				var saved_controller: PVController = instance.get_node_or_null(
					"ControllerNode"
				) as PVController
				if _check(saved_controller != null and saved_controller.flow_graph != null,
						"Reopened scene contains controller and graph"):
					var saved_graph: FlowGraph = saved_controller.flow_graph
					_check(saved_graph.get_internal_id() == gid and
						saved_graph.schema_version == FlowGraph.SCHEMA_VERSION_3,
						"Reopened graph retains identity and schema")
					_check(saved_graph.state_machines.size() == 1,
						"Reopened edited machine count is exact")
					if saved_graph.state_machines.size() == 1:
						var saved_machine: FlowStateMachineDefinition = saved_graph.state_machines[0]
						_check(saved_machine.get_internal_id() == mid and
							_final_state(saved_machine, aid, bid, cid),
							"Reopened machine retains name, state order and initial ID")
						if saved_machine.states.size() == 3:
							var saved_idle: FlowStateDefinition = saved_machine.states[0]
							_check(saved_idle.transitions.size() == 1,
								"Reopened outgoing edge remains owned by original state")
							if saved_idle.transitions.size() == 1:
								var saved_edge: FlowStateTransitionDefinition = saved_idle.transitions[0]
								_check(saved_edge.get_internal_id() == eid and
									saved_edge.target_state_id == bid and
									saved_edge.trigger == FlowStateTransitionDefinition.Trigger.EVENT and
									saved_edge.event_name == &"go",
									"Reopened transition retains exact ID, target and event")
					_check(not FlowGraphValidator.validate(saved_graph).has_errors(),
						"Reopened edited graph remains valid")
				instance.free()

	_cleanup()
	if failures.is_empty():
		print("[Flujo] Potok 7E-1B1 edited scene undo redo roundtrip passed")
	else:
		for failure: String in failures:
			push_error("[Flujo] Potok 7E-1B1: " + failure)
	quit(0 if failures.is_empty() else 1)


func _final_state(machine: FlowStateMachineDefinition, aid: String, bid: String, cid: String) -> bool:
	return machine.display_name == "Edited Character" and machine.states.size() == 3 \
		and machine.states[0].get_internal_id() == aid \
		and machine.states[1].get_internal_id() == cid \
		and machine.states[2].get_internal_id() == bid \
		and machine.states[2].display_name == "Sprinting" \
		and machine.initial_state_id == aid \
		and machine.states[0].transitions.size() == 1 \
		and machine.states[0].transitions[0].target_state_id == bid


func _check(ok: bool, message: String) -> bool:
	if not ok:
		failures.append(message)
	return ok


func _cleanup() -> void:
	var scene_abs: String = ProjectSettings.globalize_path(SCENE_PATH)
	if FileAccess.file_exists(scene_abs):
		DirAccess.remove_absolute(scene_abs)
	var dir_abs: String = ProjectSettings.globalize_path(TEMP_DIR)
	if DirAccess.dir_exists_absolute(dir_abs):
		var directory: DirAccess = DirAccess.open(dir_abs)
		if directory != null and directory.get_files().is_empty() and directory.get_directories().is_empty():
			DirAccess.remove_absolute(dir_abs)
