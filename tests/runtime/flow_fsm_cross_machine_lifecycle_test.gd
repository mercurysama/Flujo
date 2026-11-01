extends Node

var errors: Array[String] = []
var accepted: Array[bool] = []

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	var graph := FlowGraph.new()
	graph.schema_version = FlowGraph.SCHEMA_VERSION_3
	graph.constructor = FlowConstructorDefinition.new()
	var a0 := FlowStateDefinition.new()
	var a1 := FlowStateDefinition.new()
	var a2 := FlowStateDefinition.new()
	var b0 := FlowStateDefinition.new()
	var b1 := FlowStateDefinition.new()
	var b2 := FlowStateDefinition.new()
	var a := FlowStateMachineDefinition.new()
	a.states = [a0, a1, a2]
	a.initial_state_id = a0.get_internal_id()
	a.tick_mode = FlowStateMachineDefinition.TickMode.MANUAL
	var b := FlowStateMachineDefinition.new()
	b.states = [b0, b1, b2]
	b.initial_state_id = b0.get_internal_id()
	b.tick_mode = FlowStateMachineDefinition.TickMode.PHYSICS
	graph.state_machines = [a, b]
	_check(not FlowGraphValidator.validate(graph).has_errors(), "Valid graph")
	var ctrl := PVController.new()
	ctrl.flow_graph = graph
	add_child(ctrl)
	await get_tree().process_frame
	var rt: FlowFSMRuntime = ctrl.get_fsm_runtime()
	if rt == null or not rt.is_running():
		get_tree().quit(1)
		return
	ctrl.set_process(false)
	ctrl.set_physics_process(false)
	var aid: String = a.get_internal_id()
	var bid: String = b.get_internal_id()
	rt.state_exited.connect(func(mid: String, sid: String) -> void:
		if mid == aid and sid == a0.get_internal_id():
			accepted.append(rt.request_transition(bid, b1.get_internal_id()))
			rt.tick(0.1, FlowStateMachineDefinition.TickMode.PHYSICS)
		if mid == bid and sid == b0.get_internal_id():
			accepted.append(rt.request_transition(aid, a2.get_internal_id()))
			rt.tick(0.1, FlowStateMachineDefinition.TickMode.MANUAL)
	)
	rt.state_entered.connect(func(mid: String, sid: String) -> void:
		if mid == aid and sid == a1.get_internal_id():
			accepted.append(rt.request_transition(bid, b2.get_internal_id()))
		if mid == bid and sid == b1.get_internal_id():
			accepted.append(rt.request_transition(aid, a1.get_internal_id()))
	)
	_check(rt.request_transition(aid, a1.get_internal_id()), "Initial request")
	rt.tick(0.1, FlowStateMachineDefinition.TickMode.MANUAL)
	_check(accepted == [true, true], "A Exit and Enter requested B")
	_check(rt.get_active_state_id(bid) == b0.get_internal_id(), "B not recursive")
	_check(rt.pending_request_count() == 2, "Two B commands retained")
	rt.tick(0.1, FlowStateMachineDefinition.TickMode.PHYSICS)
	_check(rt.get_active_state_id(bid) == b1.get_internal_id(), "First FIFO B command wins")
	_check(accepted == [true, true, true, true], "B Exit and Enter requested A")
	_check(rt.get_active_state_id(aid) == a1.get_internal_id(), "A not recursive")
	_check(rt.pending_request_count() == 2, "Two A commands retained")
	rt.tick(0.1, FlowStateMachineDefinition.TickMode.MANUAL)
	_check(rt.get_active_state_id(aid) == a2.get_internal_id(), "A FIFO wins over self")
	_check(rt.pending_request_count() == 0, "Both A requests consumed")
	_check(not FlowGraphValidator.validate(graph).has_errors(), "Graph remains valid")
	ctrl.visual_program_enabled = false
	ctrl.queue_free()
	await get_tree().process_frame
	if errors.is_empty():
		print("Potok-6B cross-machine Enter Exit passed")
	get_tree().quit(0 if errors.is_empty() else 1)

func _check(ok: bool, message: String) -> void:
	if not ok:
		errors.append(message)
		push_error("Potok-6B: " + message)
