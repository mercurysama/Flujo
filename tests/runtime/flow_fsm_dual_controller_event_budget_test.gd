extends Node

## 8D2-B3A3: identical event/queue/budget replay across two PVControllers.
var failures: Array[String] = []
var seen: Array = [[], []]
var commits: Array = [[], []]
var deferrals: Array = [[], []]
var injected: Array[bool] = [false, false]


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var graph: FlowGraph = FlowGraph.new()
	graph.schema_version = FlowGraph.SCHEMA_VERSION_3
	graph.constructor = FlowConstructorDefinition.new()
	var a0: FlowStateDefinition = FlowStateDefinition.new()
	var b0: FlowStateDefinition = FlowStateDefinition.new()
	var b1: FlowStateDefinition = FlowStateDefinition.new()
	var edge: FlowStateTransitionDefinition = FlowStateTransitionDefinition.new()
	edge.trigger = FlowStateTransitionDefinition.Trigger.EVENT
	edge.event_name = &"go"
	edge.target_state_id = b1.get_internal_id()
	b0.transitions = [edge]
	var ma: FlowStateMachineDefinition = _machine([a0], a0)
	var mb: FlowStateMachineDefinition = _machine([b0, b1], b0)
	graph.state_machines = [ma, mb]
	if not _check(not FlowGraphValidator.validate(graph).has_errors(), "Valid graph"):
		get_tree().quit(1)
		return
	var controllers: Array[PVController] = []
	var runtimes: Array[FlowFSMRuntime] = []
	for i: int in 2:
		var ctrl: PVController = PVController.new()
		ctrl.flow_graph = graph
		controllers.append(ctrl)
		add_child(ctrl)
	await get_tree().process_frame
	for i: int in 2:
		var rt: FlowFSMRuntime = controllers[i].get_fsm_runtime()
		if not _check(rt != null and rt.is_running(), "Running instance %d" % i):
			get_tree().quit(1)
			return
		runtimes.append(rt)
	_check(runtimes[0] != runtimes[1], "Runtimes are distinct")
	var aid: String = ma.get_internal_id()
	var bid: String = mb.get_internal_id()
	for i: int in 2:
		var rt: FlowFSMRuntime = runtimes[i]
		rt.event_consumed.connect(func(mid: String, name: StringName, _data: Dictionary) -> void:
			seen[i].append(mid + ":" + String(name))
		)
		rt.work_budget_deferred.connect(func(mid: String, count: int) -> void:
			deferrals[i].append(mid + ":" + str(count))
		)
		rt.transition_committed.connect(func(mid: String, old: String, target: String, trigger: String) -> void:
			commits[i].append(mid + ":" + old + ">" + target + ":" + trigger)
		)
		rt.state_updated.connect(func(mid: String, _state: String) -> void:
			if mid == aid and not injected[i]:
				injected[i] = true
				_check(rt.emit_event(aid, &"callback"), "Callback event admitted %d" % i)
				rt.tick(0.1, FlowStateMachineDefinition.TickMode.MANUAL)
		)
	_check(FlowFSMRuntime.MAX_REQUESTS_PER_MACHINE_TICK == 32, "Budget is 32")
	for n: int in 34:
		for i: int in 2:
			_check(runtimes[i].emit_event(aid, StringName("e_%02d" % n)),
					"Event accepted %d:%d" % [i, n])
	for i: int in 2:
		_check(runtimes[i].emit_event(bid, &"go"), "Machine B event admitted")
		_check(runtimes[i].pending_request_count() == 35, "Initial queue count")
	runtimes[0].tick(0.1, FlowStateMachineDefinition.TickMode.MANUAL)
	_check(seen[0].size() == 33 and seen[1].is_empty(), "Only A advances first")
	_check(runtimes[0].pending_request_count() == 3
			and runtimes[1].pending_request_count() == 35,
			"Queue independence and callback deferral")
	runtimes[1].tick(0.1, FlowStateMachineDefinition.TickMode.MANUAL)
	_check(seen[0] == seen[1] and commits[0] == commits[1]
			and deferrals[0] == deferrals[1], "Equivalent first-tick traces")
	_check(deferrals[0] == [aid + ":2"], "Exactly two budgeted packets deferred")
	var expected_commit: String = bid + ":" + b0.get_internal_id() + ">" + b1.get_internal_id() + ":" + edge.get_internal_id()
	_check(commits[0] == [expected_commit], "Exactly one B transition, no starvation")
	for i: int in 2:
		runtimes[i].tick(0.1, FlowStateMachineDefinition.TickMode.MANUAL)
	_check(seen[0] == seen[1] and seen[0].size() == 36, "Equivalent full event traces")
	for n: int in 34:
		_check(seen[0][n if n < 32 else n + 1] == aid + ":e_%02d" % n,
				"FIFO event %d remains ordered" % n)
	_check(seen[0][32] == bid + ":go" and seen[0][35] == aid + ":callback",
			"B event interleaves by machine clock, callback remains last")
	_check(deferrals[0] == [aid + ":2"] and deferrals[1] == deferrals[0],
			"Only one budget deferral in each runtime")
	_check(commits[0] == commits[1] and commits[0].size() == 1,
			"Nested tick cannot create duplicate commits")
	_check(runtimes[0].pending_request_count() == 0
			and runtimes[1].pending_request_count() == 0
			and runtimes[0].get_active_state_id(bid) == b1.get_internal_id()
			and runtimes[1].get_active_state_id(bid) == b1.get_internal_id(),
			"Both independent queues drain and target states match")
	_check(graph.state_machines == [ma, mb] and ma.states == [a0]
			and mb.states == [b0, b1]
			and not FlowGraphValidator.validate(graph).has_errors(),
			"Authored graph remains intact")
	for ctrl: PVController in controllers:
		ctrl.visual_program_enabled = false
		ctrl.queue_free()
	await get_tree().process_frame
	if failures.is_empty():
		print("[Flujo] Potok 8D2-B3A3 deterministic events and budget passed")
	else:
		for failure: String in failures:
			push_error("[Flujo] Potok 8D2-B3A3: " + failure)
	get_tree().quit(0 if failures.is_empty() else 1)


func _machine(states: Array[FlowStateDefinition], initial: FlowStateDefinition) -> FlowStateMachineDefinition:
	var result: FlowStateMachineDefinition = FlowStateMachineDefinition.new()
	result.states = states
	result.initial_state_id = initial.get_internal_id()
	result.tick_mode = FlowStateMachineDefinition.TickMode.MANUAL
	return result


func _check(ok: bool, message: String) -> bool:
	if not ok:
		failures.append(message)
		push_error("[Flujo] Potok 8D2-B3A3 assertion: " + message)
	return ok
