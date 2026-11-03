extends Node

## Potok 9C3-A: real disk restore uses global Exit phase then Enter phase,
## clears only owner's stale queue and preserves sibling independence.
const FILE_PATH: String = "user://flujo_fsm_tests/phase9_9c3_callback_restore.json"
var _failures: Array[String] = []
var _trace: Array[String] = []
var _peer_trace: Array[String] = []
var _owns_file: bool = false


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	if FileAccess.file_exists(FILE_PATH):
		_check(false, "9C3 reserved user file must not preexist")
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
	_check(not FlowGraphValidator.validate(graph).has_errors(), "Two machines validate")
	var owner: PVController = PVController.new()
	owner.flow_graph = graph
	var peer: PVController = PVController.new()
	peer.flow_graph = graph
	add_child(owner)
	add_child(peer)
	await get_tree().process_frame
	var runtime: FlowFSMRuntime = owner.get_fsm_runtime()
	var sibling: FlowFSMRuntime = peer.get_fsm_runtime()
	if not _check(runtime != null and sibling != null
			and runtime != sibling and runtime.is_running() and sibling.is_running(),
			"Two distinct running controller FSM runtimes"):
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
	_check(runtime.change_state(aid, a1.get_internal_id())
			and runtime.change_state(bid, b1.get_internal_id()),
			"Target states queued")
	runtime.tick(0.1, FlowStateMachineDefinition.TickMode.MANUAL)
	var expected_snapshot: Dictionary = runtime.export_snapshot()
	_check(runtime.save_to_file(FILE_PATH), "Target state snapshot saved on disk")
	_owns_file = FileAccess.file_exists(FILE_PATH)
	_check(runtime.change_state(aid, a0.get_internal_id())
			and runtime.change_state(bid, b0.get_internal_id()),
			"Both owner machines return to initial states")
	runtime.tick(0.1, FlowStateMachineDefinition.TickMode.MANUAL)
	_check(runtime.get_active_state_id(aid) == a0.get_internal_id()
			and runtime.get_active_state_id(bid) == b0.get_internal_id(),
			"Owner currently differs from stored snapshot")
	_check(runtime.change_state(aid, a1.get_internal_id())
			and runtime.emit_event(bid, &"unhandled", {"sequence": 7}),
			"Owner holds stale pending direct and event")
	_check(sibling.change_state(bid, b1.get_internal_id()),
			"Sibling queues independent transition")
	_check(runtime.pending_request_count() == 2
			and sibling.pending_request_count() == 1,
			"Owner and sibling queues independently populated")
	runtime.state_exited.connect(func(mid: String, sid: String) -> void:
		_trace.append("Exit:" + mid + ":" + sid)
	)
	runtime.state_entered.connect(func(mid: String, sid: String) -> void:
		_trace.append("Enter:" + mid + ":" + sid)
	)
	runtime.transition_committed.connect(func(mid: String, old: String, target: String, trigger: String) -> void:
		_trace.append("Commit:" + mid + ":" + old + ">" + target + ":" + trigger)
	)
	sibling.state_exited.connect(func(mid: String, sid: String) -> void:
		_peer_trace.append("Exit:" + mid + ":" + sid)
	)
	sibling.state_entered.connect(func(mid: String, sid: String) -> void:
		_peer_trace.append("Enter:" + mid + ":" + sid)
	)
	_check(runtime.restore_from_file(FILE_PATH), "Valid disk snapshot restores")
	var expected_trace: Array[String] = [
		"Exit:" + aid + ":" + a0.get_internal_id(),
		"Exit:" + bid + ":" + b0.get_internal_id(),
		"Enter:" + aid + ":" + a1.get_internal_id(),
		"Enter:" + bid + ":" + b1.get_internal_id()
	]
	_check(_trace == expected_trace,
			"Disk restore emits global Exit A/B followed by Enter A/B, no commits")
	_check(runtime.pending_request_count() == 0
			and runtime.get_active_state_id(aid) == a1.get_internal_id()
			and runtime.get_active_state_id(bid) == b1.get_internal_id(),
			"Owner restores target states and discards stale queue")
	_check(sibling.pending_request_count() == 1
			and sibling.get_active_state_id(bid) == b0.get_internal_id()
			and _peer_trace.is_empty(),
			"Disk restore leaves peer pending request and callback trace unchanged")
	_check(JSON.parse_string(JSON.stringify(runtime.export_snapshot()))
			== JSON.parse_string(JSON.stringify(expected_snapshot)),
			"Restored snapshot reexports identical portable JSON")
	sibling.tick(0.1, FlowStateMachineDefinition.TickMode.MANUAL)
	_check(sibling.pending_request_count() == 0
			and sibling.get_active_state_id(bid) == b1.get_internal_id()
			and _peer_trace == [
				"Exit:" + bid + ":" + b0.get_internal_id(),
				"Enter:" + bid + ":" + b1.get_internal_id()
			],
			"Peer independently processes its own queued request")
	_check(_trace == expected_trace, "Peer tick adds no owner callbacks")
	_cleanup()
	owner.visual_program_enabled = false
	peer.visual_program_enabled = false
	owner.queue_free()
	peer.queue_free()
	await get_tree().process_frame
	if _failures.is_empty():
		print("[Flujo] Potok 9C3-A disk restore lifecycle passed")
	else:
		for failure: String in _failures:
			push_error("[Flujo] Potok 9C3-A: " + failure)
	get_tree().quit(0 if _failures.is_empty() else 1)


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
		for path: String in [absolute, absolute + ".tmp", absolute + ".bak"]:
			if FileAccess.file_exists(path):
				DirAccess.remove_absolute(path)


func _check(ok: bool, description: String) -> bool:
	if not ok:
		_failures.append(description)
		push_error("[Flujo] Potok 9C3-A assertion: " + description)
	return ok
