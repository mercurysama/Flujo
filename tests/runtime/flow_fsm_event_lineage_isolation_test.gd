extends Node

## Potok 6D: event descendants, canceled sibling, and independent controllers.
var failures: Array[String] = []
var commits: Array[String] = []
var rejected: Array[String] = []
var event_seen: Array[String] = []
var admissions: Array[bool] = []
var a0_entries: int = 0

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	var graph := FlowGraph.new()
	graph.schema_version = FlowGraph.SCHEMA_VERSION_3
	graph.constructor = FlowConstructorDefinition.new()
	var a0 := FlowStateDefinition.new()
	var a1 := FlowStateDefinition.new()
	var b0 := FlowStateDefinition.new()
	var b1 := FlowStateDefinition.new()
	var c0 := FlowStateDefinition.new()
	var c1 := FlowStateDefinition.new()
	b0.transitions = [_event(&"forward", b1.get_internal_id())]
	b1.transitions = [_event(&"reverse", b0.get_internal_id())]
	var a := _machine([a0, a1], a0.get_internal_id(), FlowStateMachineDefinition.TickMode.MANUAL)
	var b := _machine([b0, b1], b0.get_internal_id(), FlowStateMachineDefinition.TickMode.PHYSICS)
	var c := _machine([c0, c1], c0.get_internal_id(), FlowStateMachineDefinition.TickMode.PROCESS)
	graph.state_machines = [a, b, c]
	_check(not FlowGraphValidator.validate(graph).has_errors(), "Shared graph valid")
	var controller := PVController.new()
	controller.flow_graph = graph
	add_child(controller)
	var independent := PVController.new()
	independent.flow_graph = graph
	add_child(independent)
	await get_tree().process_frame
	var runtime: FlowFSMRuntime = controller.get_fsm_runtime()
	var isolated: FlowFSMRuntime = independent.get_fsm_runtime()
	if not _check(runtime != null and isolated != null and runtime.is_running() and isolated.is_running(),
			"Both controllers start"):
		get_tree().quit(1)
		return
	controller.set_process(false)
	controller.set_physics_process(false)
	independent.set_process(false)
	independent.set_physics_process(false)
	var aid: String = a.get_internal_id()
	var bid: String = b.get_internal_id()
	var cid: String = c.get_internal_id()
	runtime.transition_committed.connect(func(mid: String, _old: String, _new: String, _trigger: String) -> void:
		commits.append(mid)
	)
	runtime.event_consumed.connect(func(mid: String, name: StringName, _payload: Dictionary) -> void:
		event_seen.append(mid + ":" + String(name))
	)
	runtime.request_rejected.connect(func(mid: String, kind: StringName, code: StringName) -> void:
		rejected.append(mid + ":" + String(kind) + ":" + String(code))
	)
	runtime.state_entered.connect(func(mid: String, sid: String) -> void:
		if mid == aid and sid == a1.get_internal_id():
			admissions.append(runtime.emit_event(bid, &"forward", {"step": 1}))
		elif mid == bid and sid == b1.get_internal_id():
			admissions.append(runtime.request_transition(aid, a0.get_internal_id()))
		elif mid == aid and sid == a0.get_internal_id():
			a0_entries += 1
			admissions.append(runtime.emit_event(bid, &"reverse", {"step": a0_entries}))
			if a0_entries == 2:
				admissions.append(runtime.request_transition(cid, c1.get_internal_id()))
		elif mid == bid and sid == b0.get_internal_id():
			admissions.append(runtime.request_transition(aid, a1.get_internal_id()))
	)
	_check(runtime.request_transition(cid, c1.get_internal_id()), "Independent PROCESS root admitted")
	_check(runtime.request_transition(aid, a1.get_internal_id()), "Cyclic root admitted")
	var expected: Array[String] = [aid, bid, aid, bid, aid, bid, aid, bid]
	for index: int in 8:
		var clock: int = FlowStateMachineDefinition.TickMode.MANUAL if index % 2 == 0 else FlowStateMachineDefinition.TickMode.PHYSICS
		runtime.tick(0.1, clock)
		_check(commits.size() == index + 1 and commits.back() == expected[index],
			"One correct commit at hop %d" % (index + 1))
	_check(a0_entries == 2, "Two A0 Enter callbacks run")
	_check(admissions.size() == 9 and admissions.count(false) == 1,
		"One ninth-hop rejection; sibling admitted earlier")
	_check(rejected == [aid + ":direct:chain_budget_exceeded"],
		"Only ninth-hop direct request is rejected")
	_check(event_seen == [bid + ":forward", bid + ":reverse", bid + ":forward", bid + ":reverse"],
		"Four event descendants received on B clock in order")
	_check(runtime.pending_request_count() == 1,
		"Canceled sibling removed; unrelated PROCESS root preserved")
	_check(runtime.get_active_state_id(cid) == c0.get_internal_id(), "PROCESS unaffected")
	_check(isolated.pending_request_count() == 0, "Second controller queue stays private")
	_check(isolated.get_active_state_id(aid) == a0.get_internal_id(), "Second A independent")
	_check(isolated.request_transition(aid, a1.get_internal_id()), "Second controller accepts fresh root")
	isolated.tick(0.1, FlowStateMachineDefinition.TickMode.MANUAL)
	_check(isolated.get_active_state_id(aid) == a1.get_internal_id(), "Second controller can commit")
	_check(runtime.get_active_state_id(aid) == a0.get_internal_id(), "First controller A unchanged")
	runtime.tick(0.1, FlowStateMachineDefinition.TickMode.PROCESS)
	_check(runtime.get_active_state_id(cid) == c1.get_internal_id(), "Independent PROCESS root executes")
	_check(runtime.pending_request_count() == 0, "No saturated sibling remains")
	_check(commits.size() == 9, "Only independent ninth commit")
	_check(not FlowGraphValidator.validate(graph).has_errors(), "Authored shared graph remains valid")
	controller.visual_program_enabled = false
	independent.visual_program_enabled = false
	controller.queue_free()
	independent.queue_free()
	await get_tree().process_frame
	if failures.is_empty():
		print("[Flujo] Potok 6D event lineage and controller isolation passed")
	get_tree().quit(0 if failures.is_empty() else 1)

func _machine(states: Array[FlowStateDefinition], initial: String, mode: int) -> FlowStateMachineDefinition:
	var machine := FlowStateMachineDefinition.new()
	machine.states = states
	machine.initial_state_id = initial
	machine.tick_mode = mode
	return machine

func _event(name: StringName, target: String) -> FlowStateTransitionDefinition:
	var edge := FlowStateTransitionDefinition.new()
	edge.trigger = FlowStateTransitionDefinition.Trigger.EVENT
	edge.event_name = name
	edge.target_state_id = target
	return edge

func _check(ok: bool, msg: String) -> bool:
	if not ok:
		failures.append(msg)
		push_error("[Flujo] Potok 6D: " + msg)
	return ok
