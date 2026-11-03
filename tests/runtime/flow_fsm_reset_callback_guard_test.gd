extends Node

## Potok 8D2-B3B1: reset cannot run inside a tick callback. An outside-tick
## reset clears only its owner queue and emits bounded per-machine lifecycle.
var failures: Array[String] = []
var lifecycle: Array[String] = []
var peer_lifecycle: Array[String] = []
var rejected_in_tick: Array[bool] = []
var update_calls: int = 0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
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
	if not _check(not FlowGraphValidator.validate(graph).has_errors(), "Fixture validates"):
		get_tree().quit(1)
		return
	var owner: PVController = PVController.new()
	owner.flow_graph = graph
	var peer: PVController = PVController.new()
	peer.flow_graph = graph
	add_child(owner)
	add_child(peer)
	await get_tree().process_frame
	var rt: FlowFSMRuntime = owner.get_fsm_runtime()
	var other: FlowFSMRuntime = peer.get_fsm_runtime()
	if not _check(rt != null and other != null and rt != other
			and rt.is_running() and other.is_running(), "Distinct running runtimes"):
		owner.queue_free()
		peer.queue_free()
		get_tree().quit(1)
		return
	var aid: String = ma.get_internal_id()
	var bid: String = mb.get_internal_id()
	owner.set_process(false)
	owner.set_physics_process(false)
	peer.set_process(false)
	peer.set_physics_process(false)
	rt.state_exited.connect(func(mid: String, sid: String) -> void:
		lifecycle.append("Exit:" + mid + ":" + sid)
	)
	rt.state_entered.connect(func(mid: String, sid: String) -> void:
		lifecycle.append("Enter:" + mid + ":" + sid)
	)
	rt.transition_committed.connect(func(mid: String, old: String, target: String, reason: String) -> void:
		lifecycle.append("Commit:" + mid + ":" + old + ">" + target + ":" + reason)
	)
	other.state_exited.connect(func(mid: String, sid: String) -> void:
		peer_lifecycle.append("Exit:" + mid + ":" + sid)
	)
	other.state_entered.connect(func(mid: String, sid: String) -> void:
		peer_lifecycle.append("Enter:" + mid + ":" + sid)
	)
	rt.state_updated.connect(func(mid: String, _state: String) -> void:
		if mid == aid:
			update_calls += 1
			rejected_in_tick.append(rt.reset())
	)
	_check(rt.change_state(aid, a1.get_internal_id())
			and rt.change_state(bid, b1.get_internal_id()),
			"Two authored transitions admitted")
	rt.tick(0.1, FlowStateMachineDefinition.TickMode.MANUAL)
	_check(rejected_in_tick == [false] and update_calls == 1,
			"Reset rejected once inside Update without callback recursion")
	_check(rt.get_active_state_id(aid) == a1.get_internal_id()
			and rt.get_active_state_id(bid) == b1.get_internal_id()
			and rt.pending_request_count() == 0,
			"Rejected in-tick reset cannot interrupt two commits")
	_check(lifecycle == [
		"Exit:" + aid + ":" + a0.get_internal_id(),
		"Enter:" + aid + ":" + a1.get_internal_id(),
		"Commit:" + aid + ":" + a0.get_internal_id() + ">" + a1.get_internal_id() + ":direct",
		"Exit:" + bid + ":" + b0.get_internal_id(),
		"Enter:" + bid + ":" + b1.get_internal_id(),
		"Commit:" + bid + ":" + b0.get_internal_id() + ">" + b1.get_internal_id() + ":direct"
	], "Exactly two ordered initial transitions with no extra reset lifecycle")
	_check(rt.change_state(aid, a0.get_internal_id())
			and rt.emit_event(bid, &"ignored", {"source": "owner"}),
			"Owner holds mixed stale requests before real reset")
	_check(other.change_state(bid, b1.get_internal_id()),
			"Peer holds separate pending transition")
	_check(rt.pending_request_count() == 2
			and other.pending_request_count() == 1, "Queues independently populated")
	lifecycle.clear()
	peer_lifecycle.clear()
	_check(rt.reset(), "Reset succeeds only outside tick")
	_check(lifecycle == [
		"Exit:" + aid + ":" + a1.get_internal_id(),
		"Enter:" + aid + ":" + a0.get_internal_id(),
		"Exit:" + bid + ":" + b1.get_internal_id(),
		"Enter:" + bid + ":" + b0.get_internal_id()
	], "Reset executes one Exit then Enter per authored machine without commit")
	_check(rt.pending_request_count() == 0
			and other.pending_request_count() == 1
			and peer_lifecycle.is_empty(), "Only owner stale queue is cleared")
	_check(rt.get_active_state_id(aid) == a0.get_internal_id()
			and rt.get_active_state_id(bid) == b0.get_internal_id()
			and other.get_active_state_id(aid) == a0.get_internal_id()
			and other.get_active_state_id(bid) == b0.get_internal_id(),
			"Owner reset leaves peer active states alone")
	other.tick(0.1, FlowStateMachineDefinition.TickMode.MANUAL)
	_check(other.get_active_state_id(bid) == b1.get_internal_id()
			and other.pending_request_count() == 0
			and rt.get_active_state_id(bid) == b0.get_internal_id(),
			"Peer independently consumes only its own request")
	_check(graph.state_machines == [ma, mb]
			and ma.states == [a0, a1] and mb.states == [b0, b1]
			and not FlowGraphValidator.validate(graph).has_errors(),
			"Authored graph never mutated")
	owner.visual_program_enabled = false
	peer.visual_program_enabled = false
	owner.queue_free()
	peer.queue_free()
	await get_tree().process_frame
	if failures.is_empty():
		print("[Flujo] Potok 8D2-B3B1 bounded reset callback test passed")
	else:
		for failure: String in failures:
			push_error("[Flujo] Potok 8D2-B3B1: " + failure)
	get_tree().quit(0 if failures.is_empty() else 1)


func _state(display: String) -> FlowStateDefinition:
	var result: FlowStateDefinition = FlowStateDefinition.new()
	result.display_name = display
	return result


func _machine(initial: FlowStateDefinition, target: FlowStateDefinition) -> FlowStateMachineDefinition:
	var result: FlowStateMachineDefinition = FlowStateMachineDefinition.new()
	result.states = [initial, target]
	result.initial_state_id = initial.get_internal_id()
	result.tick_mode = FlowStateMachineDefinition.TickMode.MANUAL
	return result


func _check(ok: bool, message: String) -> bool:
	if not ok:
		failures.append(message)
		push_error("[Flujo] Potok 8D2-B3B1 assertion: " + message)
	return ok
