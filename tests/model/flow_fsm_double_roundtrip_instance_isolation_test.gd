extends SceneTree

## Potok 7E-1D: save -> reopen -> save -> reopen, then isolate two scene runtimes.
const TEMP_DIR: String = "res://.godot/flujo_tests"
const FIRST_PATH: String = TEMP_DIR + "/potok_7e1d_first.tscn"
const SECOND_PATH: String = TEMP_DIR + "/potok_7e1d_second.tscn"

var failures: Array[String] = []


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var first_source := Node.new()
	first_source.name = "Potok7E1DScene"
	var controller := PVController.new()
	controller.name = "ControllerNode"

	var graph := FlowGraph.new()
	graph.schema_version = FlowGraph.SCHEMA_VERSION_3
	graph.constructor = FlowConstructorDefinition.new()
	var idle := FlowStateDefinition.new()
	idle.display_name = "Idle"
	var active := FlowStateDefinition.new()
	active.display_name = "Active"
	var enter := FlowPrintBlock.new()
	enter.text = "enter first"
	var update := FlowPrintBlock.new()
	update.text = "update first"
	var exit := FlowPrintBlock.new()
	exit.text = "exit first"
	idle.enter_blocks = [enter]
	idle.blocks = [update]
	idle.exit_blocks = [exit]

	var edge := FlowStateTransitionDefinition.new()
	edge.display_name = "Advance"
	edge.trigger = FlowStateTransitionDefinition.Trigger.EVENT
	edge.event_name = &"advance"
	edge.target_state_id = active.get_internal_id()
	edge.priority = 3
	idle.transitions = [edge]
	var machine := FlowStateMachineDefinition.new()
	machine.display_name = "Character"
	machine.tick_mode = FlowStateMachineDefinition.TickMode.MANUAL
	machine.states = [idle, active]
	machine.initial_state_id = idle.get_internal_id()
	graph.state_machines = [machine]
	controller.flow_graph = graph
	first_source.add_child(controller)
	controller.owner = first_source

	var baseline: Dictionary = {
		"graph": graph.get_internal_id(),
		"machine": machine.get_internal_id(),
		"idle": idle.get_internal_id(),
		"active": active.get_internal_id(),
		"enter": enter.get_internal_id(),
		"update": update.get_internal_id(),
		"exit": exit.get_internal_id(),
		"edge": edge.get_internal_id()
	}
	_check(not FlowGraphValidator.validate(graph).has_errors(),
		"First-generation graph is valid before any save")
	_verify_root(first_source, baseline, "authoring source")

	var dir_error: Error = DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(TEMP_DIR)
	)
	_check(dir_error == OK, "Ignored test fixture directory is available")

	var first_saved: bool = dir_error == OK and _save(first_source, FIRST_PATH)
	_check(first_saved, "First PackedScene save succeeds")
	first_source.free()
	await process_frame

	var intermediate: Node = null
	if first_saved:
		intermediate = _load(FIRST_PATH)
	if _check(intermediate != null, "First scene reloads and instantiates"):
		_verify_root(intermediate, baseline, "first reopened scene")

	var second_saved: bool = intermediate != null and _save(intermediate, SECOND_PATH)
	_check(second_saved, "Reopened scene packs and saves a second time")
	if intermediate != null:
		intermediate.free()
	await process_frame

	var second_packed: PackedScene = null
	if second_saved:
		second_packed = ResourceLoader.load(
			SECOND_PATH, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE
		) as PackedScene
	if _check(second_packed != null, "Second save reloads without resource cache"):
		var first_instance: Node = second_packed.instantiate()
		var second_instance: Node = second_packed.instantiate()
		if _check(first_instance != null and second_instance != null,
				"Two independent copies instantiate from second-generation scene"):
			_verify_root(first_instance, baseline, "first second-generation instance")
			_verify_root(second_instance, baseline, "second second-generation instance")
			get_root().add_child(first_instance)
			get_root().add_child(second_instance)
			await process_frame

			var first_controller: PVController = first_instance.get_node_or_null(
				"ControllerNode"
			) as PVController
			var second_controller: PVController = second_instance.get_node_or_null(
				"ControllerNode"
			) as PVController
			if _check(first_controller != null and second_controller != null
					and first_controller != second_controller,
					"Each instantiation owns a separate PVController node"):
				_test_runtime_isolation(first_controller, second_controller, baseline)
				_verify_root(first_instance, baseline,
					"first instance after independent runtime activity")
				_verify_root(second_instance, baseline,
					"second instance after independent runtime activity")

			first_instance.queue_free()
			second_instance.queue_free()
			for _i: int in 3:
				await process_frame
		else:
			if first_instance != null:
				first_instance.free()
			if second_instance != null:
				second_instance.free()

	_cleanup()
	if failures.is_empty():
		print("[Flujo] Potok 7E-1D repeated scene roundtrip and runtime instance isolation passed")
	else:
		for failure: String in failures:
			push_error("[Flujo] Potok 7E-1D: " + failure)
	quit(0 if failures.is_empty() else 1)


func _test_runtime_isolation(
		first: PVController, second: PVController, expected: Dictionary
) -> void:
	first.set_process(false)
	first.set_physics_process(false)
	second.set_process(false)
	second.set_physics_process(false)
	var first_runtime: FlowFSMRuntime = first.get_fsm_runtime()
	var second_runtime: FlowFSMRuntime = second.get_fsm_runtime()
	if not _check(first_runtime != null and second_runtime != null
			and first_runtime != second_runtime and first_runtime.is_running()
			and second_runtime.is_running(), "Each controller starts a separate live FSM runtime"):
		return

	var machine_id: String = expected["machine"]
	var idle_id: String = expected["idle"]
	var active_id: String = expected["active"]
	_check(first_runtime.get_active_state_id(machine_id) == idle_id
		and second_runtime.get_active_state_id(machine_id) == idle_id,
		"Both fresh copies start at the same authored initial state")

	var first_context: FlowValueResolutionContext = first.get_value_resolution_context()
	var second_context: FlowValueResolutionContext = second.get_value_resolution_context()
	_check(first_context != second_context and first_context.controller == first
		and second_context.controller == second,
		"Separate controllers own distinct runtime value contexts")
	first_context.set_variable_value("local-only", 27)
	_check(first_context.has_variable_value("local-only")
		and not second_context.has_variable_value("local-only"),
		"Transient variable values do not cross scene instances")
	first_context.begin_event_packet_scope(machine_id)
	first_context.record_event_packet(machine_id, &"probe", {"secret": "instance-one"})
	_check(first_context.has_event_payload(&"probe")
		and not second_context.has_event_payload(&"probe"),
		"Per-tick event packet context does not leak to the second instance")
	first_context.end_event_packet_scope()
	_check(not first_context.has_event_payload(&"probe"),
		"Ending the first event scope erases its temporary packet")

	_check(first_runtime.emit_event(machine_id, &"advance", {}),
		"First controller accepts its own authored transition event")
	_check(first_runtime.pending_request_count() == 1
		and second_runtime.pending_request_count() == 0,
		"Queued event remains isolated before the first manual tick")
	first_runtime.tick(0.1, FlowStateMachineDefinition.TickMode.MANUAL)
	_check(first_runtime.get_active_state_id(machine_id) == active_id
		and second_runtime.get_active_state_id(machine_id) == idle_id,
		"First instance changes state; second instance remains Idle")
	_check(second_runtime.is_running() and second_runtime.pending_request_count() == 0,
		"Second FSM continues without a stale queued event")

	first.visual_program_enabled = false
	_check(not first_runtime.is_running()
		and second_runtime.is_running()
		and second_runtime.get_active_state_id(machine_id) == idle_id,
		"Stopping first controller never stops or changes second controller")
	_check(second_runtime.emit_event(machine_id, &"advance", {}),
		"Second controller accepts its own event after first stopped")
	second_runtime.tick(0.1, FlowStateMachineDefinition.TickMode.MANUAL)
	_check(second_runtime.get_active_state_id(machine_id) == active_id,
		"Second controller transitions independently on its own manual tick")
	_check(not second_context.has_event_payload(&"probe")
		and not second_context.has_variable_value("local-only"),
		"Second controller never acquires first controller's transient data")
	_check(not FlowGraphValidator.validate(first.flow_graph).has_errors()
		and not FlowGraphValidator.validate(second.flow_graph).has_errors(),
		"Runtime progression never corrupts shared authored graph definitions")
	second.visual_program_enabled = false


func _verify_root(root: Node, expected: Dictionary, stage: String) -> void:
	var controller: PVController = root.get_node_or_null(
		"ControllerNode"
	) as PVController
	if not _check(controller != null and controller.flow_graph != null,
			stage + ": scene owns PVController with persisted graph"):
		return
	var graph: FlowGraph = controller.flow_graph
	_check(graph.get_internal_id() == expected["graph"]
		and graph.schema_version == FlowGraph.SCHEMA_VERSION_3,
		stage + ": stable graph ID and schema unchanged")
	if not _check(graph.state_machines.size() == 1,
			stage + ": exactly one authored machine remains"):
		return
	var machine: FlowStateMachineDefinition = graph.state_machines[0]
	if not _check(machine != null and machine.get_internal_id() == expected["machine"]
			and machine.tick_mode == FlowStateMachineDefinition.TickMode.MANUAL
			and machine.initial_state_id == expected["idle"],
			stage + ": machine ID, initial reference and manual clock unchanged"):
		return
	if not _check(machine.states.size() == 2,
			stage + ": two authored states retain original order"):
		return
	var idle: FlowStateDefinition = machine.states[0]
	var active: FlowStateDefinition = machine.states[1]
	if not _check(idle != null and active != null
			and idle.get_internal_id() == expected["idle"]
			and active.get_internal_id() == expected["active"]
			and idle.display_name == "Idle" and active.display_name == "Active",
			stage + ": state IDs/order/labels unchanged"):
		return
	if _check(idle.enter_blocks.size() == 1 and idle.blocks.size() == 1
			and idle.exit_blocks.size() == 1,
			stage + ": all Enter/Update/Exit phase blocks survive"):
		_check(idle.enter_blocks[0].get_internal_id() == expected["enter"]
			and (idle.enter_blocks[0] as FlowPrintBlock).text == "enter first"
			and idle.blocks[0].get_internal_id() == expected["update"]
			and (idle.blocks[0] as FlowPrintBlock).text == "update first"
			and idle.exit_blocks[0].get_internal_id() == expected["exit"]
			and (idle.exit_blocks[0] as FlowPrintBlock).text == "exit first",
			stage + ": phase IDs/order/content unchanged")
	if _check(idle.transitions.size() == 1,
			stage + ": one authored event edge survives"):
		var edge: FlowStateTransitionDefinition = idle.transitions[0]
		_check(edge.get_internal_id() == expected["edge"]
			and edge.target_state_id == expected["active"]
			and edge.trigger == FlowStateTransitionDefinition.Trigger.EVENT
			and edge.event_name == &"advance" and edge.priority == 3,
			stage + ": event edge ID/target/trigger/priority unchanged")
	_check(not FlowGraphValidator.validate(graph).has_errors(),
		stage + ": all persisted graph references remain valid")


func _save(root: Node, path: String) -> bool:
	var packed := PackedScene.new()
	if packed.pack(root) != OK:
		return false
	return ResourceSaver.save(packed, ProjectSettings.globalize_path(path)) == OK


func _load(path: String) -> Node:
	var packed: PackedScene = ResourceLoader.load(
		path, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE
	) as PackedScene
	return packed.instantiate() if packed != null else null


func _check(ok: bool, message: String) -> bool:
	if not ok:
		failures.append(message)
	return ok


func _cleanup() -> void:
	for path: String in [FIRST_PATH, SECOND_PATH]:
		var absolute_path: String = ProjectSettings.globalize_path(path)
		if FileAccess.file_exists(absolute_path):
			DirAccess.remove_absolute(absolute_path)
	var absolute_dir: String = ProjectSettings.globalize_path(TEMP_DIR)
	if DirAccess.dir_exists_absolute(absolute_dir):
		var directory: DirAccess = DirAccess.open(absolute_dir)
		if directory != null and directory.get_files().is_empty() \
				and directory.get_directories().is_empty():
			DirAccess.remove_absolute(absolute_dir)
