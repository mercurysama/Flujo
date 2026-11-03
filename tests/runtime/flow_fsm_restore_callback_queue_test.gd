extends Node

## Potok 8D2-B3B2: valid snapshot restoration emits every Exit before
## any Enter, removes stale pending packets and never changes a sibling.
var failures: Array[String] = []
var lifecycle: Array[String] = []
var peer_lifecycle: Array[String] = []


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var graph: FlowGraph = FlowGraph.new()
	graph.schema_version = FlowGraph.SCHEMA_VERSION_3
	graph.constructor = FlowConstructorDefinition.new()
	var a0: FlowStateDefinition = _state("A-Initial")
	var a1: FlowStateDefinition = _state("A-Target")
	var b0: FlowStateDefinition = _state("B-Initial")
	var b1: FlowStateDefinition = _state("B-Target")
	var ma: FlowStateMachineDefinition = _machine(a0, a1)
	var mb: FlowStateMachineDefinition = _machine(b0, b1)
	graph.state_machines = [ma, mb]
	if not _check(not FlowGraphValidator.validate(graph).has_errors(), "Valid authored graph"):
		get_tree().quit(1)
		return
	var owner: PVController = PVController.new()
	owner.flow_graph = graph
	var peer: PVController = PVController.new()
	peer.flow_graph = graph
	add_child(owner)
	add_child(peer)
	await get_tree().process_frame
	var runtime: FlowFSMRuntime = owner.get_fsm_runtime()
	var sibling: FlowFSMRuntime = peer.get_fsm_runtime()
	if not _check(runtime != null and sibling != null and runtime != sibling
			and runtime.is_running() and sibling.is_running(), "Separate live runtimes"):
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
			and runtime.change_state(bid, b1.get_internal_id()), "Owner target states queued")
	runtime.tick(0.1, FlowStateMachineDefinition.TickMode.MANUAL)
	_check(runtime.get_active_state_id(aid) == a1.get_internal_id()
			and runtime.get_active_state_id(bid) == b1.get_internal_id(),
			"Snapshot source has both target states active")
	var saved: Dictionary = runtime.export_snapshot()
	_check((saved.get("machines", []) as Array).size() == 2
			and runtime.pending_request_count() == 0,
			"Portable snapshot captures both machines without pending packets")
	_check(runtime.change_state(aid, a0.get_internal_id())
			and runtime.change_state(bid, b0.get_internal_id()),
			"Move owner away from saved target states")
	runtime.tick(0.1, FlowStateMachineDefinition.TickMode.MANUAL)
	_check(runtime.get_active_state_id(aid) == a0.get_internal_id()
			and runtime.get_active_state_id(bid) == b0.get_internal_id(),
			"Owner currently differs from valid snapshot")
	_check(runtime.change_state(aid, a1.get_internal_id())
			and runtime.emit_event(bid, &"unhandled", {"seq": 7}),
			"Owner queues stale direct and event packets")
	_check(sibling.change_state(bid, b1.get_internal_id()),
			"Sibling holds independent queued transition")
	_check(runtime.pending_request_count() == 2
			and sibling.pending_request_count() == 1,
			"Queues separately populated before snapshot restore")
	runtime.state_exited.connect(func(mid: String, sid: String) -> void:
		lifecycle.append("Exit:" + mid + ":" + sid)
	)
	runtime.state_entered.connect(func(mid: String, sid: String) -> void:
		lifecycle.append("Enter:" + mid + ":" + sid)
	)
	runtime.transition_committed.connect(func(mid: String, old: String, target: String, trigger: String) -> void:
		lifecycle.append("Commit:" + mid + ":" + old + ">" + target + ":" + trigger)
	)
	sibling.state_exited.connect(func(mid: String, sid: String) -> void:
		peer_lifecycle.append("Exit:" + mid + ":" + sid)
	)
	sibling.state_entered.connect(func(mid: String, sid: String) -> void:
		peer_lifecycle.append("Enter:" + mid + ":" + sid)
	)
	_check(runtime.restore_snapshot(saved), "Valid matching graph snapshot restores")
	var expected: Array[String] = [
		"Exit:" + aid + ":" + a0.get_internal_id(),
		"Exit:" + bid + ":" + b0.get_internal_id(),
		"Enter:" + aid + ":" + a1.get_internal_id(),
		"Enter:" + bid + ":" + b1.get_internal_id()
	]
	_check(lifecycle == expected, "Restore performs global Exit phase, then Enter phase")
	_check(runtime.get_active_state_id(aid) == a1.get_internal_id()
			and runtime.get_active_state_id(bid) == b1.get_internal_id()
			and runtime.pending_request_count() == 0,
			"Saved targets restored, stale owner queue discarded")
	_check(sibling.get_active_state_id(aid) == a0.get_internal_id()
			and sibling.get_active_state_id(bid) == b0.get_internal_id()
			and sibling.pending_request_count() == 1
			and peer_lifecycle.is_empty(),
			"Other controller remains untouched by successful restore")
	_check(runtime.export_snapshot() == saved,
			"Restore re-export produces the identical portable snapshot")
	sibling.tick(0.1, FlowStateMachineDefinition.TickMode.MANUAL)
	_check(sibling.get_active_state_id(bid) == b1.get_internal_id()
			and sibling.pending_request_count() == 0
			and runtime.get_active_state_id(bid) == b1.get_internal_id(),
			"Sibling processes its own queued transition independently")
	_check(peer_lifecycle == [
		"Exit:" + bid + ":" + b0.get_internal_id(),
		"Enter:" + bid + ":" + b1.get_internal_id()
	], "Only sibling's own B machine emits subsequent lifecycle signals")
	_check(lifecycle == expected,
			"Ticking sibling cannot add callbacks to restored controller")
	_check(graph.state_machines == [ma, mb]
			and ma.states == [a0, a1] and mb.states == [b0, b1]
			and not FlowGraphValidator.validate(graph).has_errors(),
			"Restoration never changes shared authored graph")
	owner.visual_program_enabled = false
	peer.visual_program_enabled = false
	owner.queue_free()
	peer.queue_free()
	await get_tree().process_frame
	if failures.is_empty():
		print("[Flujo] Potok 8D2-B3B2 restore callback and queue isolation passed")
	else:
		for failure: String in failures:
			push_error("[Flujo] Potok 8D2-B3B2: " + failure)
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


func _check(ok: bool, description: String) -> bool:
	if not ok:
		failures.append(description)
		push_error("[Flujo] Potok 8D2-B3B2 assertion: " + description)
	return ok
