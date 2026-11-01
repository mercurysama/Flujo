extends Node
var failures: Array[String] = []
var seen: Array[String] = []

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	var g := FlowGraph.new()
	g.schema_version = FlowGraph.SCHEMA_VERSION_3
	g.constructor = FlowConstructorDefinition.new()
	var a0 := FlowStateDefinition.new()
	var a1 := FlowStateDefinition.new()
	var b0 := FlowStateDefinition.new()
	var b1 := FlowStateDefinition.new()
	var a := FlowStateMachineDefinition.new()
	a.states = [a0, a1]
	a.initial_state_id = a0.get_internal_id()
	a.tick_mode = FlowStateMachineDefinition.TickMode.MANUAL
	var b := FlowStateMachineDefinition.new()
	b.states = [b0, b1]
	b.initial_state_id = b0.get_internal_id()
	b.tick_mode = FlowStateMachineDefinition.TickMode.PHYSICS
	g.state_machines = [a, b]
	var c := PVController.new()
	c.flow_graph = g
	add_child(c)
	await get_tree().process_frame
	var r: FlowFSMRuntime = c.get_fsm_runtime()
	if r == null:
		get_tree().quit(1)
		return
	c.set_process(false)
	c.set_physics_process(false)
	var aid: String = a.get_internal_id()
	var bid: String = b.get_internal_id()
	r.transition_committed.connect(func(mid: String, _f: String, to: String, _t: String) -> void:
		seen.append(mid + ":" + to)
	)
	r.state_entered.connect(func(mid: String, sid: String) -> void:
		if mid == aid and sid == a1.get_internal_id():
			_check(r.request_transition(bid, b1.get_internal_id()), "A to B")
			r.tick(0.1, FlowStateMachineDefinition.TickMode.PHYSICS)
		elif mid == bid and sid == b1.get_internal_id():
			_check(r.request_transition(aid, a0.get_internal_id()), "B to A")
		elif mid == aid and sid == a0.get_internal_id():
			_check(r.request_transition(bid, b0.get_internal_id()), "A to B reset")
	)
	_check(r.request_transition(aid, a1.get_internal_id()), "Seed")
	var modes: Array[int] = [FlowStateMachineDefinition.TickMode.MANUAL, FlowStateMachineDefinition.TickMode.PHYSICS, FlowStateMachineDefinition.TickMode.MANUAL, FlowStateMachineDefinition.TickMode.PHYSICS]
	for i: int in modes.size():
		r.tick(0.1, modes[i])
		_check(seen.size() == i + 1, "One commit at tick %d" % i)
		_check(r.pending_request_count() == (0 if i == 3 else 1), "Bounded queue at tick %d" % i)
	_check(r.get_active_state_id(aid) == a0.get_internal_id(), "A cycle")
	_check(r.get_active_state_id(bid) == b0.get_internal_id(), "B cycle")
	_check(not FlowGraphValidator.validate(g).has_errors(), "Graph unchanged")
	c.visual_program_enabled = false
	c.queue_free()
	await get_tree().process_frame
	get_tree().quit(0 if failures.is_empty() else 1)

func _check(ok: bool, msg: String) -> void:
	if not ok:
		failures.append(msg)
		push_error("Potok 6C: " + msg)
