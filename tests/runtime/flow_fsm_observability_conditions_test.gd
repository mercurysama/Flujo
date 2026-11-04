extends Node

## Potok 10A-4: characterize observable conditional arbitration and no-ops.
## Existing signals do not identify false/self candidates or condition results.
var _failures: Array[String] = []
var _signals: Array[String] = []
var _commits: Array[String] = []
var _rejections: Array[String] = []


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var graph: FlowGraph = FlowGraph.new()
	graph.schema_version = FlowGraph.SCHEMA_VERSION_3
	graph.constructor = FlowConstructorDefinition.new()
	var idle: FlowStateDefinition = FlowStateDefinition.new()
	var busy: FlowStateDefinition = FlowStateDefinition.new()
	var waiting: FlowStateDefinition = FlowStateDefinition.new()
	var false_edge: FlowStateTransitionDefinition = _condition(busy.get_internal_id(), false, 100)
	var self_edge: FlowStateTransitionDefinition = _condition(idle.get_internal_id(), true, 90)
	var winner: FlowStateTransitionDefinition = _condition(busy.get_internal_id(), true, 10)
	idle.transitions = [false_edge, self_edge, winner]
	var only_false: FlowStateTransitionDefinition = _condition(waiting.get_internal_id(), false, 80)
	var waiting_self: FlowStateTransitionDefinition = _condition(waiting.get_internal_id(), true, 70)
	waiting.transitions = [only_false, waiting_self]
	var first: FlowStateMachineDefinition = _machine([idle, busy], idle.get_internal_id())
	var second: FlowStateMachineDefinition = _machine([waiting], waiting.get_internal_id())
	graph.state_machines = [first, second]
	_check(not FlowGraphValidator.validate(graph).has_errors(), "Typed boolean and self edges validate")
	var mid: String = first.get_internal_id()
	var sid: String = second.get_internal_id()
	var controller: PVController = PVController.new()
	controller.flow_graph = graph
	add_child(controller)
	await get_tree().process_frame
	var runtime: FlowFSMRuntime = controller.get_fsm_runtime()
	if not _check(runtime != null and runtime.is_running(), "Valid graph starts"):
		controller.queue_free()
		_finish()
		return
	controller.set_process(false)
	controller.set_physics_process(false)
	runtime.state_updated.connect(func(id: String, _state: String) -> void:
		_signals.append("update:" + id)
	)
	runtime.state_exited.connect(func(id: String, _state: String) -> void:
		_signals.append("exit:" + id)
	)
	runtime.state_entered.connect(func(id: String, _state: String) -> void:
		_signals.append("enter:" + id)
	)
	runtime.transition_committed.connect(func(id: String, from_id: String, to_id: String, trigger_id: String) -> void:
		_signals.append("commit:" + id)
		_commits.append(id + ":" + from_id + ">" + to_id + ":" + trigger_id)
	)
	runtime.request_rejected.connect(func(id: String, kind: StringName, code: StringName) -> void:
		_rejections.append(id + ":" + String(kind) + ":" + String(code))
	)
	runtime.tick(0.1, FlowStateMachineDefinition.TickMode.MANUAL)
	_check(_signals == [
		"update:" + mid, "exit:" + mid, "enter:" + mid, "commit:" + mid,
		"update:" + sid
	], "Conditional winner commits once, false/self-only machine only updates")
	_check(_commits == [mid + ":" + idle.get_internal_id() + ">" + busy.get_internal_id()
			+ ":" + winner.get_internal_id()], "Only the winning edge ID is observable")
	_check(runtime.get_active_state_id(mid) == busy.get_internal_id()
			and runtime.get_active_state_id(sid) == waiting.get_internal_id(),
			"False and self edges cannot force a transition")
	_check(_rejections.is_empty(), "False/self candidates emit no admission rejection")
	_signals.clear()
	_check(runtime.request_transition(mid, busy.get_internal_id()), "Self direct request admitted")
	runtime.tick(0.1, FlowStateMachineDefinition.TickMode.MANUAL)
	_check(_signals == ["update:" + mid, "update:" + sid],
			"Consumed self direct request emits neither Exit/Enter nor commit")
	_check(_commits.size() == 1 and _rejections.is_empty() and runtime.pending_request_count() == 0,
			"No-op has no public transition decision signal and leaves no pending request")
	_check(runtime.get_active_state_id(mid) == busy.get_internal_id()
			and runtime.get_active_state_id(sid) == waiting.get_internal_id(),
			"Both active states remain stable")
	_check(graph.state_machines == [first, second]
			and idle.transitions == [false_edge, self_edge, winner]
			and waiting.transitions == [only_false, waiting_self]
			and not FlowGraphValidator.validate(graph).has_errors(),
			"Read-only observation preserves authored definitions")
	controller.visual_program_enabled = false
	controller.queue_free()
	await get_tree().process_frame
	_finish()


func _machine(states: Array[FlowStateDefinition], initial_id: String) -> FlowStateMachineDefinition:
	var result: FlowStateMachineDefinition = FlowStateMachineDefinition.new()
	result.states = states
	result.initial_state_id = initial_id
	result.tick_mode = FlowStateMachineDefinition.TickMode.MANUAL
	return result


func _condition(target_id: String, value: bool, priority: int) -> FlowStateTransitionDefinition:
	var result: FlowStateTransitionDefinition = FlowStateTransitionDefinition.new()
	result.target_state_id = target_id
	result.trigger = FlowStateTransitionDefinition.Trigger.CONDITION
	result.condition = FlowLiteralValueSource.new(Variant.Type.TYPE_BOOL, value)
	result.priority = priority
	return result


func _check(ok: bool, description: String) -> bool:
	if not ok:
		_failures.append(description)
		push_error("[Flujo] Potok-10A4: " + description)
	return ok


func _finish() -> void:
	if _failures.is_empty():
		print("[Flujo] Potok-10A4 conditional signal characterization passed")
	get_tree().quit(0 if _failures.is_empty() else 1)
