@tool
extends SceneTree

## Potok 7E-1B2 — structural editor commands, repeated history cycles, and saved scene.
var failures: Array[String] = []

const TEMP_DIR: String = "res://.godot/flujo_tests"
const SCENE_PATH: String = TEMP_DIR + "/potok_7e1b2_structural_scene.tscn"


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	for _i: int in 5:
		await process_frame
	while EditorInterface.get_resource_filesystem().is_scanning():
		await process_frame

	var manager: EditorUndoRedoManager = EditorInterface.get_editor_undo_redo()
	if not _check(manager != null, "Editor undo manager available"):
		quit(1)
		return

	var root := Node.new()
	root.name = "Potok7E1B2Scene"
	get_root().add_child(root)

	var graph := FlowGraph.new()
	graph.schema_version = FlowGraph.SCHEMA_VERSION_3
	graph.constructor = FlowConstructorDefinition.new()
	var a := FlowStateDefinition.new()
	a.display_name = "Idle"
	var b := FlowStateDefinition.new()
	b.display_name = "Active"
	var phase := FlowPrintBlock.new()
	phase.text = "entry marker"
	a.enter_blocks = [phase]
	var loop := _event(a.get_internal_id(), &"again")
	var to_b := _event(b.get_internal_id(), &"start")
	a.transitions = [loop, to_b]
	var machine := FlowStateMachineDefinition.new()
	machine.display_name = "Controller FSM"
	machine.states = [a, b]
	machine.initial_state_id = a.get_internal_id()
	graph.state_machines = [machine]
	var controller := PVController.new()
	controller.name = "ControllerNode"
	controller.flow_graph = graph
	root.add_child(controller)
	controller.owner = root

	var gid: String = graph.get_internal_id()
	var mid: String = machine.get_internal_id()
	var aid: String = a.get_internal_id()
	var bid: String = b.get_internal_id()
	var pid: String = phase.get_internal_id()
	var loop_id: String = loop.get_internal_id()
	var to_b_id: String = to_b.get_internal_id()
	_check(not FlowGraphValidator.validate(graph).has_errors(), "Original FSM graph validates")

	var commands := FlowGraphEditorCommands.new(manager)
	var history: UndoRedo = manager.get_history_undo_redo(manager.get_object_history_id(controller))
	var copied_id: String = commands.duplicate_fsm_state(controller, mid, aid) # Action 1
	_check(not copied_id.is_empty() and copied_id != aid, "Duplicated A receives new state ID")
	if machine.states.size() < 3:
		_fail_and_exit(root)
		return
	var copied_state: FlowStateDefinition = machine.states[1]
	var copied_phase_id: String = ""
	var copied_loop_id: String = ""
	var copied_to_b_id: String = ""
	if _check(copied_state.get_internal_id() == copied_id and
			copied_state.enter_blocks.size() == 1 and copied_state.transitions.size() == 2,
			"Duplicated A owns a copied Enter block and two transitions"):
		copied_phase_id = copied_state.enter_blocks[0].get_internal_id()
		copied_loop_id = copied_state.transitions[0].get_internal_id()
		copied_to_b_id = copied_state.transitions[1].get_internal_id()
		_check(copied_phase_id != pid and copied_loop_id != loop_id and
			copied_to_b_id != to_b_id and copied_loop_id != copied_to_b_id,
			"Deep duplication allocates distinct phase and transition IDs")
		_check(copied_state.transitions[0].target_state_id == copied_id and
			copied_state.transitions[1].target_state_id == bid,
			"Duplicated self-loop remapped; separate target ID preserved")

	_check(not commands.delete_fsm_state(controller, mid, bid),
		"Incoming edge dependencies reject unsafe B deletion")
	_check(machine.states.size() == 3 and machine.states[2].get_internal_id() == bid,
		"Rejected delete does not remove or reposition B")

	var added_id: String = commands.add_fsm_state(controller, mid) # Action 2
	_check(not added_id.is_empty() and added_id != copied_id and added_id != aid,
		"Added C receives a distinct stable ID")
	_check(commands.move_fsm_state(controller, mid, added_id, -1), # Action 3
		"Added C can be reordered above B")
	_check(machine.states.size() == 4 and machine.states[2].get_internal_id() == added_id,
		"Reorder results in A/copy/C/B")

	var first_edge_id: String = commands.add_fsm_transition( # Action 4
		controller, mid, added_id
	)
	_check(not first_edge_id.is_empty(), "C owns new event transition")
	var duplicated_edge_id: String = commands.duplicate_fsm_transition( # Action 5
		controller, mid, added_id, first_edge_id
	)
	_check(not duplicated_edge_id.is_empty() and duplicated_edge_id != first_edge_id,
		"Duplicated C transition receives a new ID")
	_check(commands.move_fsm_transition( # Action 6
		controller, mid, added_id, duplicated_edge_id, -1
	), "Duplicated transition moves before original")
	_check(commands.delete_fsm_transition( # Action 7
		controller, mid, added_id, first_edge_id
	), "Original C transition deleted; copied one stays")
	var final_edge_id: String = commands.add_fsm_transition(controller, mid, added_id) # Action 8
	_check(not final_edge_id.is_empty() and final_edge_id != duplicated_edge_id,
		"Second surviving C transition receives distinct ID")
	_check(commands.set_fsm_transition_property( # Action 9
		controller, mid, added_id, final_edge_id, &"target_state_id", bid
	), "Surviving C edge target edited by validated command")
	_check(commands.delete_fsm_state(controller, mid, aid), # Action 10
		"Initial A deletion succeeds without incoming surviving references")
	_check(_final_state(machine, copied_id, added_id, bid, copied_phase_id,
		copied_loop_id, copied_to_b_id, duplicated_edge_id, final_edge_id),
		"Final authored structure, order, initial and edge ownership are exact")
	_check(not commands.delete_fsm_state(controller, mid, bid),
		"Deleted A's outgoing edges are gone; surviving incoming edges still protect B")
	_check(not FlowGraphValidator.validate(graph).has_errors(),
		"Final edited structural graph validates")

	# Each accepted call is one distinct atomic action. Rejected deletions add none.
	for _cycle: int in 2:
		for _action: int in 10:
			history.undo()
		_check(machine.states.size() == 2 and machine.states[0].get_internal_id() == aid
			and machine.states[1].get_internal_id() == bid and
			machine.initial_state_id == aid, "Undo restores original A/B and initial ID")
		_check(a.enter_blocks.size() == 1 and a.enter_blocks[0].get_internal_id() == pid
			and a.transitions.size() == 2 and a.transitions[0].get_internal_id() == loop_id
			and a.transitions[1].get_internal_id() == to_b_id
			and a.transitions[0].target_state_id == aid
			and a.transitions[1].target_state_id == bid,
			"Undo preserves exact original phase/edge IDs and references")
		_check(not FlowGraphValidator.validate(graph).has_errors(),
			"Graph valid after complete Undo")
		for _action: int in 10:
			history.redo()
		_check(_final_state(machine, copied_id, added_id, bid, copied_phase_id,
			copied_loop_id, copied_to_b_id, duplicated_edge_id, final_edge_id),
			"Redo restores same structural IDs, order, initial and targets")
		_check(not FlowGraphValidator.validate(graph).has_errors(),
			"Graph valid after complete Redo")

	var dir_result: Error = DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(TEMP_DIR)
	)
	_check(dir_result == OK, "Owned fixture directory available")
	var packed := PackedScene.new()
	var packed_result: Error = packed.pack(root)
	_check(packed_result == OK, "Edited structural controller scene packs")
	var saved: Error = FAILED
	if dir_result == OK and packed_result == OK:
		saved = ResourceSaver.save(packed, ProjectSettings.globalize_path(SCENE_PATH))
	_check(saved == OK, "Final structurally edited scene saves")
	root.free()
	await process_frame

	if saved == OK:
		var saved_scene: PackedScene = ResourceLoader.load(
			SCENE_PATH, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE
		) as PackedScene
		if _check(saved_scene != null, "Fresh edited scene can be loaded"):
			var instance: Node = saved_scene.instantiate()
			if _check(instance != null, "Fresh structural scene instantiates"):
				var restored: PVController = instance.get_node_or_null(
					"ControllerNode"
				) as PVController
				if _check(restored != null and restored.flow_graph != null,
						"Restored controller owns saved graph"):
					var restored_graph: FlowGraph = restored.flow_graph
					_check(restored_graph.get_internal_id() == gid and
						restored_graph.schema_version == FlowGraph.SCHEMA_VERSION_3,
						"Graph identity and schema persist")
					_check(restored_graph.state_machines.size() == 1,
						"Scene owns exactly one authored machine")
					if restored_graph.state_machines.size() == 1:
						var restored_machine: FlowStateMachineDefinition = restored_graph.state_machines[0]
						_check(restored_machine.get_internal_id() == mid,
							"Machine ID persists")
						_check(_final_state(restored_machine, copied_id, added_id, bid,
							copied_phase_id, copied_loop_id, copied_to_b_id,
							duplicated_edge_id, final_edge_id),
							"All added and copied state/edge/phase IDs survive reload")
						if restored_machine.states.size() == 3:
							var copied: FlowStateDefinition = restored_machine.states[0]
							_check(copied.enter_blocks.size() == 1 and
								(copied.enter_blocks[0] as FlowPrintBlock).text == "entry marker",
								"Copied Enter phase content survives reload")
					_check(not FlowGraphValidator.validate(restored_graph).has_errors(),
						"Reopened structurally edited graph validates")
				instance.free()

	_cleanup()
	if failures.is_empty():
		print("[Flujo] Potok 7E-1B2 structural undo redo scene roundtrip passed")
	else:
		for failure: String in failures:
			push_error("[Flujo] Potok 7E-1B2: " + failure)
	quit(0 if failures.is_empty() else 1)


func _event(target_id: String, event_name: StringName) -> FlowStateTransitionDefinition:
	var edge := FlowStateTransitionDefinition.new()
	edge.trigger = FlowStateTransitionDefinition.Trigger.EVENT
	edge.event_name = event_name
	edge.target_state_id = target_id
	return edge


func _final_state(
		machine: FlowStateMachineDefinition, copied_id: String, added_id: String,
		bid: String, phase_id: String, copied_loop_id: String,
		copied_to_b_id: String, duplicated_edge_id: String, final_edge_id: String
) -> bool:
	if machine.states.size() != 3 or machine.initial_state_id != copied_id:
		return false
	var copy: FlowStateDefinition = machine.states[0]
	var added: FlowStateDefinition = machine.states[1]
	var b: FlowStateDefinition = machine.states[2]
	return copy.get_internal_id() == copied_id \
		and added.get_internal_id() == added_id and b.get_internal_id() == bid \
		and copy.enter_blocks.size() == 1 \
		and copy.enter_blocks[0].get_internal_id() == phase_id \
		and copy.transitions.size() == 2 \
		and copy.transitions[0].get_internal_id() == copied_loop_id \
		and copy.transitions[0].target_state_id == copied_id \
		and copy.transitions[1].get_internal_id() == copied_to_b_id \
		and copy.transitions[1].target_state_id == bid \
		and added.transitions.size() == 2 \
		and added.transitions[0].get_internal_id() == duplicated_edge_id \
		and added.transitions[0].target_state_id == added_id \
		and added.transitions[1].get_internal_id() == final_edge_id \
		and added.transitions[1].target_state_id == bid


func _check(ok: bool, message: String) -> bool:
	if not ok:
		failures.append(message)
	return ok


func _fail_and_exit(root: Node) -> void:
	root.free()
	_cleanup()
	push_error("[Flujo] Potok 7E-1B2: duplicate failed, cannot run later assertions")
	quit(1)


func _cleanup() -> void:
	var abs_scene: String = ProjectSettings.globalize_path(SCENE_PATH)
	if FileAccess.file_exists(abs_scene):
		DirAccess.remove_absolute(abs_scene)
	var abs_dir: String = ProjectSettings.globalize_path(TEMP_DIR)
	if DirAccess.dir_exists_absolute(abs_dir):
		var directory: DirAccess = DirAccess.open(abs_dir)
		if directory != null and directory.get_files().is_empty() \
				and directory.get_directories().is_empty():
			DirAccess.remove_absolute(abs_dir)
