extends Node

## 8D2-B3A4: deterministic reset replay with explicit equal dynamic IDs.
var failures: Array[String] = []
var traces: Array = [[], []]


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
	if not _check(not FlowGraphValidator.validate(graph).has_errors(), "Authored graph validates"):
		get_tree().quit(1)
		return
	var controllers: Array[PVController] = []
	for i: int in 2:
		var controller: PVController = PVController.new()
		controller.flow_graph = graph
		controllers.append(controller)
		add_child(controller)
	await get_tree().process_frame
	var runtimes: Array[FlowFSMRuntime] = []
	for i: int in 2:
		var rt: FlowFSMRuntime = controllers[i].get_fsm_runtime()
		if not _check(rt != null and rt.is_running(), "Controller %d starts" % i):
			get_tree().quit(1)
			return
		runtimes.append(rt)
	_check(runtimes[0] != runtimes[1], "Separate mutable runtimes")
	var aid: String = ma.get_internal_id()
	var bid: String = mb.get_internal_id()
	var ephemeral_id: String = FlowId.create()
	var persistent_id: String = FlowId.create()
	_check(FlowId.is_valid(ephemeral_id) and FlowId.is_valid(persistent_id)
			and ephemeral_id != persistent_id, "Explicit runtime IDs are valid and distinct")
	for i: int in 2:
		var rt: FlowFSMRuntime = runtimes[i]
		rt.state_exited.connect(func(mid: String, sid: String) -> void:
			traces[i].append("Exit:" + mid + ":" + sid)
		)
		rt.state_entered.connect(func(mid: String, sid: String) -> void:
			traces[i].append("Enter:" + mid + ":" + sid)
		)
		rt.transition_committed.connect(func(mid: String, old: String, target: String, trigger: String) -> void:
			traces[i].append("Commit:" + mid + ":" + old + ">" + target + ":" + trigger)
		)
		_check(rt.register_state(aid, a1.get_internal_id(), ephemeral_id,
				FlowFSMDynamicStateRecord.Lifetime.EPHEMERAL,
				{"value": {"count": 3}}) == ephemeral_id,
				"Explicit EPHEMERAL ID accepted on controller %d" % i)
		_check(rt.register_state(bid, b1.get_internal_id(), persistent_id,
				FlowFSMDynamicStateRecord.Lifetime.PERSISTENT,
				{"value": {"count": 7}}) == persistent_id,
				"Explicit PERSISTENT ID accepted on controller %d" % i)
		_check(rt.change_state(aid, ephemeral_id)
				and rt.change_state(bid, persistent_id), "Both aliases queued")
		rt.tick(0.125, FlowStateMachineDefinition.TickMode.MANUAL)
	_check(traces[0] == traces[1] and traces[0].size() == 6,
			"Initial two alias activations create identical Exit/Enter/Commit traces")
	for i: int in 2:
		var rt: FlowFSMRuntime = runtimes[i]
		_check(rt.get_active_state_id(aid) == ephemeral_id
				and rt.get_active_state_id(bid) == persistent_id
				and rt.pending_request_count() == 0,
				"Both aliases active, initial queue empty")
		_check(rt.change_state(aid, a0.get_internal_id())
				and rt.emit_event(bid, &"unmatched", {"seq": 1}),
				"Identical direct and event queue before reset")
	_check(runtimes[0].pending_request_count() == 2
			and runtimes[1].pending_request_count() == 2, "Independent pending packets")
	traces[0].clear()
	traces[1].clear()
	_check(runtimes[0].reset(), "Reset controller 0")
	_check(runtimes[0].pending_request_count() == 0
			and runtimes[1].pending_request_count() == 2
			and runtimes[1].get_active_state_id(aid) == ephemeral_id,
			"Resetting one instance does not alter sibling queue or active state")
	_check(runtimes[1].reset(), "Reset controller 1")
	var expected: Array[String] = [
		"Exit:" + aid + ":" + ephemeral_id,
		"Enter:" + aid + ":" + a0.get_internal_id(),
		"Exit:" + bid + ":" + persistent_id,
		"Enter:" + bid + ":" + b0.get_internal_id()
	]
	_check(traces[0] == expected and traces[1] == expected,
			"Reset applies per-machine Exit then Enter in authored order with no stale commit")
	for i: int in 2:
		var rt: FlowFSMRuntime = runtimes[i]
		_check(not rt.has_state(aid, ephemeral_id)
				and rt.get_dynamic_state_ids(aid).is_empty()
				and rt.get_dynamic_state_ids(bid) == [persistent_id]
				and rt.get_dynamic_state_data(bid, persistent_id)
					== {"value": {"count": 7}},
				"EPHEMERAL removed and persistent data retained identically")
		_check(rt.get_active_state_id(aid) == a0.get_internal_id()
				and rt.get_active_state_id(bid) == b0.get_internal_id()
				and rt.pending_request_count() == 0,
				"Reset returns both machines to authored initial with empty queue")
		_check(not rt.change_state(aid, ephemeral_id)
				and rt.change_state(bid, persistent_id),
				"Stale ephemeral rejected and surviving persistent alias usable")
		rt.tick(0.125, FlowStateMachineDefinition.TickMode.MANUAL)
	_check(traces[0] == traces[1]
			and runtimes[0].get_active_state_id(bid) == persistent_id
			and runtimes[1].get_active_state_id(bid) == persistent_id,
			"Post-reset persistent replay remains deterministic")
	_check(graph.state_machines == [ma, mb] and ma.states == [a0, a1]
			and mb.states == [b0, b1]
			and not FlowGraphValidator.validate(graph).has_errors(),
			"Reset and dynamic aliases do not mutate authored graph")
	for controller: PVController in controllers:
		controller.visual_program_enabled = false
		controller.queue_free()
	await get_tree().process_frame
	if failures.is_empty():
		print("[Flujo] Potok 8D2-B3A4 deterministic dynamic reset replay passed")
	else:
		for failure: String in failures:
			push_error("[Flujo] Potok 8D2-B3A4: " + failure)
	get_tree().quit(0 if failures.is_empty() else 1)


func _state(name: String) -> FlowStateDefinition:
	var state: FlowStateDefinition = FlowStateDefinition.new()
	state.display_name = name
	return state


func _machine(initial: FlowStateDefinition, target: FlowStateDefinition) -> FlowStateMachineDefinition:
	var machine: FlowStateMachineDefinition = FlowStateMachineDefinition.new()
	machine.states = [initial, target]
	machine.initial_state_id = initial.get_internal_id()
	machine.tick_mode = FlowStateMachineDefinition.TickMode.MANUAL
	return machine


func _check(value: bool, message: String) -> bool:
	if not value:
		failures.append(message)
		push_error("[Flujo] Potok 8D2-B3A4 assertion: " + message)
	return value
