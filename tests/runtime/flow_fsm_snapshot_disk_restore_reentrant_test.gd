extends Node

## Potok 9C3-C: file restoration requests from FSM tick callbacks must
## refuse reentry while owner and sibling queues remain coherent.
const FILE_PATH: String = "user://flujo_fsm_tests/phase9_9c3_reentrant.json"
var failures: Array[String] = []
var trace: Array[String] = []
var peer_trace: Array[String] = []
var update_attempts: Array[bool] = []
var commit_attempts: Array[bool] = []
var updates: int = 0
var commits: int = 0
var _owns_file: bool = false


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	if FileAccess.file_exists(FILE_PATH):
		_check(false, "Reserved file must be absent")
		get_tree().quit(1)
		return
	var graph: FlowGraph = FlowGraph.new()
	graph.schema_version = FlowGraph.SCHEMA_VERSION_3
	graph.constructor = FlowConstructorDefinition.new()
	var a0: FlowStateDefinition = _state("A0")
	var a1: FlowStateDefinition = _state("A1")
	var b0: FlowStateDefinition = _state("B0")
	var b1: FlowStateDefinition = _state("B1")
	var ma: FlowStateMachineDefinition = _machine(a0, a1)
	var mb: FlowStateMachineDefinition = _machine(b0, b1)
	graph.state_machines = [ma, mb]
	_check(not FlowGraphValidator.validate(graph).has_errors(), "Two MANUAL machines validate")
	var owner: PVController = PVController.new()
	owner.flow_graph = graph
	var peer: PVController = PVController.new()
	peer.flow_graph = graph
	add_child(owner)
	add_child(peer)
	await get_tree().process_frame
	var rt: FlowFSMRuntime = owner.get_fsm_runtime()
	var sibling: FlowFSMRuntime = peer.get_fsm_runtime()
	if not _check(rt != null and sibling != null and rt != sibling
			and rt.is_running() and sibling.is_running(), "Separate running FSM instances"):
		owner.queue_free()
		peer.queue_free()
		get_tree().quit(1)
		return
	owner.set_process(false)
	owner.set_physics_process(false)
	peer.set_process(false)
	peer.set_physics_process(false)
	var aid: String = ma.get_internal_id()
	var bid: String = mb.get_internal_id()
	var snapshot: Dictionary = rt.export_snapshot()
	_check(rt.save_to_file(FILE_PATH), "Initial snapshot saved to disk")
	_owns_file = FileAccess.file_exists(FILE_PATH)
	var original_bytes: String = FileAccess.get_file_as_string(FILE_PATH)
	_check(JSON.parse_string(original_bytes)
			== JSON.parse_string(JSON.stringify(snapshot)), "Disk snapshot is portable")
	rt.state_exited.connect(func(mid: String, sid: String) -> void:
		trace.append("Exit:" + mid + ":" + sid)
	)
	rt.state_entered.connect(func(mid: String, sid: String) -> void:
		trace.append("Enter:" + mid + ":" + sid)
	)
	rt.state_updated.connect(func(mid: String, _sid: String) -> void:
		if mid == aid and updates == 0:
			updates += 1
			update_attempts.append(rt.restore_from_file(FILE_PATH))
			_check(rt.emit_event(aid, &"callback"), "Update can queue future event")
			rt.tick(0.1, FlowStateMachineDefinition.TickMode.MANUAL)
	)
	rt.transition_committed.connect(func(mid: String, old: String, target: String, trigger: String) -> void:
		trace.append("Commit:" + mid + ":" + old + ">" + target + ":" + trigger)
		if mid == aid:
			commits += 1
			commit_attempts.append(rt.restore_from_file(FILE_PATH))
			rt.tick(0.1, FlowStateMachineDefinition.TickMode.MANUAL)
	)
	sibling.state_exited.connect(func(mid: String, sid: String) -> void:
		peer_trace.append("Exit:" + mid + ":" + sid)
	)
	sibling.state_entered.connect(func(mid: String, sid: String) -> void:
		peer_trace.append("Enter:" + mid + ":" + sid)
	)
	_check(rt.change_state(aid, a1.get_internal_id())
			and rt.change_state(bid, b1.get_internal_id()),
			"Owner queues two state changes")
	_check(sibling.change_state(bid, b1.get_internal_id()),
			"Peer queues independent state change")
	rt.tick(0.1, FlowStateMachineDefinition.TickMode.MANUAL)
	_check(update_attempts == [false] and commit_attempts == [false]
			and updates == 1 and commits == 1,
			"Both update and commit callbacks refuse file restore inside tick")
	var expected_tick: Array[String] = [
		"Exit:" + aid + ":" + a0.get_internal_id(),
		"Enter:" + aid + ":" + a1.get_internal_id(),
		"Commit:" + aid + ":" + a0.get_internal_id() + ">" + a1.get_internal_id() + ":direct",
		"Exit:" + bid + ":" + b0.get_internal_id(),
		"Enter:" + bid + ":" + b1.get_internal_id(),
		"Commit:" + bid + ":" + b0.get_internal_id() + ">" + b1.get_internal_id() + ":direct"
	]
	_check(trace == expected_tick, "No nested tick or file restore publishes extra lifecycle signals")
	_check(rt.pending_request_count() == 1 and sibling.pending_request_count() == 1,
			"Rejected file restore preserves owner deferred event and peer queue")
	_check(rt.get_active_state_id(aid) == a1.get_internal_id()
			and rt.get_active_state_id(bid) == b1.get_internal_id(),
			"Owner commits normally despite rejected reentrant restores")
	_check(FileAccess.get_file_as_string(FILE_PATH) == original_bytes,
			"Reentrant restore attempts do not modify snapshot file")
	trace.clear()
	_check(rt.restore_from_file(FILE_PATH), "Outside-tick disk restore succeeds")
	var expected_restore: Array[String] = [
		"Exit:" + aid + ":" + a1.get_internal_id(),
		"Exit:" + bid + ":" + b1.get_internal_id(),
		"Enter:" + aid + ":" + a0.get_internal_id(),
		"Enter:" + bid + ":" + b0.get_internal_id()
	]
	_check(trace == expected_restore, "Outside-tick file restore emits global Exit then Enter")
	_check(rt.pending_request_count() == 0 and sibling.pending_request_count() == 1
			and peer_trace.is_empty(), "Outside-tick restore drops only owner stale packets")
	_check(JSON.parse_string(JSON.stringify(rt.export_snapshot()))
			== JSON.parse_string(JSON.stringify(snapshot)),
			"Reexport reproduces disk snapshot")
	sibling.tick(0.1, FlowStateMachineDefinition.TickMode.MANUAL)
	_check(sibling.pending_request_count() == 0
			and sibling.get_active_state_id(bid) == b1.get_internal_id()
			and peer_trace == [
				"Exit:" + bid + ":" + b0.get_internal_id(),
				"Enter:" + bid + ":" + b1.get_internal_id()
			], "Peer independently commits its queued change")
	_check(trace == expected_restore, "Peer tick cannot leak owner callbacks")
	_cleanup()
	owner.visual_program_enabled = false
	peer.visual_program_enabled = false
	owner.queue_free()
	peer.queue_free()
	await get_tree().process_frame
	if failures.is_empty():
		print("[Flujo] Potok 9C3-C file restore in-tick guard passed")
	else:
		for issue: String in failures:
			push_error("[Flujo] Potok 9C3-C: " + issue)
	get_tree().quit(0 if failures.is_empty() else 1)


func _state(name: String) -> FlowStateDefinition:
	var state: FlowStateDefinition = FlowStateDefinition.new()
	state.display_name = name
	return state


func _machine(initial: FlowStateDefinition, target: FlowStateDefinition) -> FlowStateMachineDefinition:
	var machine: FlowStateMachineDefinition = FlowStateMachineDefinition.new()
	machine.tick_mode = FlowStateMachineDefinition.TickMode.MANUAL
	machine.states = [initial, target]
	machine.initial_state_id = initial.get_internal_id()
	return machine


func _cleanup() -> void:
	if _owns_file:
		var absolute: String = ProjectSettings.globalize_path(FILE_PATH)
		for name: String in [absolute, absolute + ".tmp", absolute + ".bak"]:
			if FileAccess.file_exists(name):
				DirAccess.remove_absolute(name)


func _check(ok: bool, description: String) -> bool:
	if not ok:
		failures.append(description)
		push_error("[Flujo] Potok 9C3-C assertion: " + description)
	return ok
