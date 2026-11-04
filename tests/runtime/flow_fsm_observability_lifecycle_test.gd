extends Node
## Potok 10A-5: characterize current lifecycle signals across two owners.
var failures: Array[String] = []
var a_trace: Array[String] = []
var b_trace: Array[String] = []

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	var graph: FlowGraph = FlowGraph.new()
	graph.schema_version = FlowGraph.SCHEMA_VERSION_3
	graph.constructor = FlowConstructorDefinition.new()
	var one: FlowStateDefinition = FlowStateDefinition.new()
	var two: FlowStateDefinition = FlowStateDefinition.new()
	var manual: FlowStateMachineDefinition = _machine(one, FlowStateMachineDefinition.TickMode.MANUAL)
	var physics: FlowStateMachineDefinition = _machine(two, FlowStateMachineDefinition.TickMode.PHYSICS)
	graph.state_machines = [manual, physics]
	_check(not FlowGraphValidator.validate(graph).has_errors(), "Valid graph")
	var mid: String = manual.get_internal_id()
	var pid: String = physics.get_internal_id()
	var first: PVController = PVController.new()
	first.flow_graph = graph
	var second: PVController = PVController.new()
	second.flow_graph = graph
	add_child(first)
	add_child(second)
	await get_tree().process_frame
	var a: FlowFSMRuntime = first.get_fsm_runtime()
	var b: FlowFSMRuntime = second.get_fsm_runtime()
	if not _check(a != null and b != null and a != b and a.is_running() and b.is_running(), "Two runtimes"):
		first.queue_free()
		second.queue_free()
		_finish()
		return
	first.set_process(false)
	first.set_physics_process(false)
	second.set_process(false)
	second.set_physics_process(false)
	a.state_updated.connect(func(m: String, _s: String) -> void: a_trace.append("update:" + m))
	a.state_exited.connect(func(m: String, _s: String) -> void: a_trace.append("exit:" + m))
	a.state_entered.connect(func(m: String, _s: String) -> void: a_trace.append("enter:" + m))
	a.machine_stopped.connect(func(m: String, _s: String) -> void: a_trace.append("stopped:" + m))
	b.state_updated.connect(func(m: String, _s: String) -> void: b_trace.append("update:" + m))
	b.state_exited.connect(func(m: String, _s: String) -> void: b_trace.append("exit:" + m))
	b.state_entered.connect(func(m: String, _s: String) -> void: b_trace.append("enter:" + m))
	b.machine_stopped.connect(func(m: String, _s: String) -> void: b_trace.append("stopped:" + m))
	a.tick(0.1, FlowStateMachineDefinition.TickMode.MANUAL)
	a.tick(0.2, FlowStateMachineDefinition.TickMode.PHYSICS)
	_check(a_trace == ["update:" + mid, "update:" + pid] and b_trace.is_empty(),
			"Only matching clocks of A emit updates")
	a_trace.clear()
	_check(a.reset(), "Reset A succeeds")
	_check(a_trace == ["exit:" + mid, "enter:" + mid, "exit:" + pid, "enter:" + pid],
			"Reset invokes Exit/Enter in authored order without Stopped")
	_check(b.is_running() and b_trace.is_empty(), "B unaffected by A reset")
	a_trace.clear()
	_check(b.emit_event(pid, &"unmatched") and b.pending_request_count() == 1,
			"B preserves independently queued event")
	a.stop()
	_check(a_trace == ["exit:" + mid, "stopped:" + mid, "exit:" + pid, "stopped:" + pid],
			"Stop emits Exit/Stopped once per machine in authored order")
	_check(not a.is_running() and b.is_running() and b.pending_request_count() == 1 and b_trace.is_empty(),
			"A stop cannot consume B pending queue")
	var stopped_size: int = a_trace.size()
	a.stop()
	a.tick(0.1, FlowStateMachineDefinition.TickMode.MANUAL)
	_check(a_trace.size() == stopped_size and a.get_active_machine_ids().is_empty(),
			"Repeated stop/tick cannot emit after shutdown")
	b.tick(0.1, FlowStateMachineDefinition.TickMode.PHYSICS)
	_check(b_trace == ["update:" + pid] and b.pending_request_count() == 0,
			"B consumes unmatched event only on own physics clock")
	_check(b.get_active_state_id(mid) == one.get_internal_id()
			and b.get_active_state_id(pid) == two.get_internal_id(),
			"B identities survive independent A shutdown")
	b_trace.clear()
	second.visual_program_enabled = false
	_check(b_trace == ["exit:" + mid, "stopped:" + mid, "exit:" + pid, "stopped:" + pid]
			and not b.is_running(), "B disable cleans only B")
	first.visual_program_enabled = false
	_check(a_trace.size() == stopped_size, "Detaching A cannot double-stop")
	_check(graph.state_machines == [manual, physics]
			and not FlowGraphValidator.validate(graph).has_errors(), "Authored graph remains read-only")
	first.queue_free()
	second.queue_free()
	await get_tree().process_frame
	_finish()

func _machine(state: FlowStateDefinition, mode: int) -> FlowStateMachineDefinition:
	var result: FlowStateMachineDefinition = FlowStateMachineDefinition.new()
	result.states = [state]
	result.initial_state_id = state.get_internal_id()
	result.tick_mode = mode
	return result

func _check(ok: bool, why: String) -> bool:
	if not ok:
		failures.append(why)
		push_error("[Flujo] Potok-10A5: " + why)
	return ok

func _finish() -> void:
	if failures.is_empty():
		print("[Flujo] Potok-10A5 lifecycle signals and clocks passed")
	get_tree().quit(0 if failures.is_empty() else 1)
