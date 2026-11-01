extends Node
## Potok 6H-2: shutdown requested during a transition; no nested shutdown.
var failures: Array[String] = []
var exit_ids: Array[String] = []
var stopped_ids: Array[String] = []
var committed: int = 0
var recursive_stop_calls: int = 0

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
	var a := _machine([a0, a1], a0.get_internal_id(), FlowStateMachineDefinition.TickMode.MANUAL)
	var b := _machine([b0, b1], b0.get_internal_id(), FlowStateMachineDefinition.TickMode.PHYSICS)
	graph.state_machines = [a, b]
	_check(not FlowGraphValidator.validate(graph).has_errors(), "Valid graph")
	var first := PVController.new()
	first.flow_graph = graph
	var second := PVController.new()
	second.flow_graph = graph
	add_child(first)
	add_child(second)
	await get_tree().process_frame
	var rt: FlowFSMRuntime = first.get_fsm_runtime()
	var other: FlowFSMRuntime = second.get_fsm_runtime()
	if rt == null or other == null or not rt.is_running() or not other.is_running():
		push_error("Potok 6H-2 runtimes unavailable")
		get_tree().quit(1)
		return
	first.set_process(false)
	first.set_physics_process(false)
	second.set_process(false)
	second.set_physics_process(false)
	var aid: String = a.get_internal_id()
	var bid: String = b.get_internal_id()
	rt.state_exited.connect(func(mid: String, sid: String) -> void:
		exit_ids.append(mid + ":" + sid)
		if mid == aid and sid == a1.get_internal_id() and recursive_stop_calls == 0:
			recursive_stop_calls += 1
			rt.stop()
	)
	rt.machine_stopped.connect(func(mid: String, _sid: String) -> void:
		stopped_ids.append(mid)
	)
	rt.transition_committed.connect(func(mid: String, _from: String, _to: String, _trigger: String) -> void:
		if mid == aid:
			committed += 1
			rt.stop()
			rt.tick(0.1, FlowStateMachineDefinition.TickMode.PHYSICS)
	)
	_check(rt.request_transition(bid, b1.get_internal_id()), "Other-clock command accepted")
	_check(rt.request_transition(aid, a1.get_internal_id()), "Manual command accepted")
	rt.tick(0.1, FlowStateMachineDefinition.TickMode.MANUAL)
	_check(committed == 1, "Transition commits before deferred stop")
	_check(not rt.is_running(), "Deferred stop completes at tick boundary")
	_check(rt.pending_request_count() == 0, "Stop clears queued physics request")
	_check(rt.get_active_machine_ids().is_empty(), "Stopped runtime has no active states")
	_check(exit_ids.count(aid + ":" + a0.get_internal_id()) == 1, "Initial A0 exits once on transition")
	_check(exit_ids.count(aid + ":" + a1.get_internal_id()) == 1, "A1 exits once on shutdown")
	_check(exit_ids.count(bid + ":" + b0.get_internal_id()) == 1, "B0 exits once on shutdown")
	_check(stopped_ids.count(aid) == 1 and stopped_ids.count(bid) == 1,
		"Shutdown signals once per active machine")
	_check(recursive_stop_calls == 1, "Shutdown callback invokes stop once, no recursion")
	rt.stop()
	_check(exit_ids.size() == 3 and stopped_ids.size() == 2, "Repeated stop is idempotent")
	_check(other.is_running() and other.pending_request_count() == 0,
		"Second controller remains running with independent queue")
	_check(other.get_active_state_id(aid) == a0.get_internal_id() and
		other.get_active_state_id(bid) == b0.get_internal_id(),
		"Second controller state unaffected")
	_check(not FlowGraphValidator.validate(graph).has_errors(), "Authored graph remains valid")
	first.visual_program_enabled = false
	second.visual_program_enabled = false
	first.queue_free()
	second.queue_free()
	await get_tree().process_frame
	if failures.is_empty():
		print("[Flujo] Potok 6H-2 reentrant stop guard passed")
	get_tree().quit(0 if failures.is_empty() else 1)

func _machine(states: Array[FlowStateDefinition], initial: String, mode: int) -> FlowStateMachineDefinition:
	var machine := FlowStateMachineDefinition.new()
	machine.states = states
	machine.initial_state_id = initial
	machine.tick_mode = mode
	return machine

func _check(ok: bool, description: String) -> void:
	if not ok:
		failures.append(description)
		push_error("[Flujo] Potok 6H-2: " + description)
