extends Node

## Potok 8D2-B3B3: bounded Update/Commit reentrancy attempts and
## controller-local snapshot restoration, without production changes.
var failures: Array[String] = []
var trace: Array[String] = []
var peer_trace: Array[String] = []
var update_attempts: Array[bool] = []
var commit_attempts: Array[bool] = []
var updates: int = 0
var commits: int = 0


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
	if not _check(not FlowGraphValidator.validate(graph).has_errors(), "Two authored MANUAL machines validate"):
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
	var sibling: FlowFSMRuntime = peer.get_fsm_runtime()
	if not _check(rt != null and sibling != null and rt != sibling
			and rt.is_running() and sibling.is_running(), "Separate running controller runtimes"):
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
	_check((snapshot.get("machines", []) as Array).size() == 2
			and rt.pending_request_count() == 0, "Valid initial snapshot is portable")
	rt.state_exited.connect(func(mid: String, sid: String) -> void:
		trace.append("Exit:" + mid + ":" + sid)
	)
	rt.state_entered.connect(func(mid: String, sid: String) -> void:
		trace.append("Enter:" + mid + ":" + sid)
	)
	rt.state_updated.connect(func(mid: String, _state: String) -> void:
		if mid == aid and updates == 0:
			updates += 1
			update_attempts.append(rt.reset())
			update_attempts.append(rt.restore_snapshot(snapshot))
			_check(rt.emit_event(aid, &"callback"), "Update can enqueue future event")
			rt.tick(0.1, FlowStateMachineDefinition.TickMode.MANUAL)
	)
	rt.transition_committed.connect(func(mid: String, old: String, target: String, trigger: String) -> void:
		trace.append("Commit:" + mid + ":" + old + ">" + target + ":" + trigger)
		if mid == aid:
			commits += 1
			commit_attempts.append(rt.reset())
			commit_attempts.append(rt.restore_snapshot(snapshot))
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
			"Owner queues both machine targets")
	_check(sibling.change_state(bid, b1.get_internal_id()),
			"Sibling independently queues B target")
	rt.tick(0.1, FlowStateMachineDefinition.TickMode.MANUAL)
	_check(update_attempts == [false, false] and commit_attempts == [false, false]
			and updates == 1 and commits == 1,
			"Update and Commit reject all in-tick reset/restore attempts exactly once")
	var expected_tick: Array[String] = [
		"Exit:" + aid + ":" + a0.get_internal_id(),
		"Enter:" + aid + ":" + a1.get_internal_id(),
		"Commit:" + aid + ":" + a0.get_internal_id() + ">" + a1.get_internal_id() + ":direct",
		"Exit:" + bid + ":" + b0.get_internal_id(),
		"Enter:" + bid + ":" + b1.get_internal_id(),
		"Commit:" + bid + ":" + b0.get_internal_id() + ">" + b1.get_internal_id() + ":direct"
	]
	_check(trace == expected_tick, "No nested tick or rejected lifecycle mutation creates extra callback")
	_check(rt.pending_request_count() == 1
			and sibling.pending_request_count() == 1,
			"Update-injected event is deferred and sibling pending queue remains isolated")
	_check(rt.get_active_state_id(aid) == a1.get_internal_id()
			and rt.get_active_state_id(bid) == b1.get_internal_id()
			and sibling.get_active_state_id(aid) == a0.get_internal_id()
			and sibling.get_active_state_id(bid) == b0.get_internal_id(),
			"Owner committed both while peer remains untouched")
	trace.clear()
	_check(rt.restore_snapshot(snapshot), "Same snapshot restores successfully outside tick")
	var expected_restore: Array[String] = [
		"Exit:" + aid + ":" + a1.get_internal_id(),
		"Exit:" + bid + ":" + b1.get_internal_id(),
		"Enter:" + aid + ":" + a0.get_internal_id(),
		"Enter:" + bid + ":" + b0.get_internal_id()
	]
	_check(trace == expected_restore, "Outside-tick restore emits global Exit phase then Enter phase")
	_check(rt.pending_request_count() == 0
			and sibling.pending_request_count() == 1
			and peer_trace.is_empty(),
			"Restore drops deferred callback event only in owner")
	_check(rt.export_snapshot() == snapshot
			and rt.get_active_state_id(aid) == a0.get_internal_id()
			and rt.get_active_state_id(bid) == b0.get_internal_id(),
			"Restored snapshot and initial states match original")
	sibling.tick(0.1, FlowStateMachineDefinition.TickMode.MANUAL)
	_check(sibling.get_active_state_id(bid) == b1.get_internal_id()
			and sibling.pending_request_count() == 0
			and rt.get_active_state_id(bid) == b0.get_internal_id(),
			"Peer independently commits its original queued target")
	_check(peer_trace == [
		"Exit:" + bid + ":" + b0.get_internal_id(),
		"Enter:" + bid + ":" + b1.get_internal_id()
	] and trace == expected_restore,
			"No cross-controller callback leakage")
	_check(graph.state_machines == [ma, mb]
			and ma.states == [a0, a1] and mb.states == [b0, b1]
			and not FlowGraphValidator.validate(graph).has_errors(),
			"All reentrancy probes preserve authored graph")
	owner.visual_program_enabled = false
	peer.visual_program_enabled = false
	owner.queue_free()
	peer.queue_free()
	await get_tree().process_frame
	if failures.is_empty():
		print("[Flujo] Potok 8D2-B3B3 reentrancy and isolation passed")
	else:
		for failure: String in failures:
			push_error("[Flujo] Potok 8D2-B3B3: " + failure)
	get_tree().quit(0 if failures.is_empty() else 1)


func _state(name: String) -> FlowStateDefinition:
	var state: FlowStateDefinition = FlowStateDefinition.new()
	state.display_name = name
	return state


func _machine(initial: FlowStateDefinition,
		target: FlowStateDefinition) -> FlowStateMachineDefinition:
	var machine: FlowStateMachineDefinition = FlowStateMachineDefinition.new()
	machine.tick_mode = FlowStateMachineDefinition.TickMode.MANUAL
	machine.states = [initial, target]
	machine.initial_state_id = initial.get_internal_id()
	return machine


func _check(ok: bool, detail: String) -> bool:
	if not ok:
		failures.append(detail)
		push_error("[Flujo] Potok 8D2-B3B3 assertion: " + detail)
	return ok
