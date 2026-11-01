extends Node

## Potok 6C-2: a cyclic chain saturates, an independent root survives.
var failures: Array[String] = []
var committed: Array[String] = []
var admissions: Array[bool] = []
var refused: Array[String] = []

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
	var a := _machine([a0, a1], a0.get_internal_id(), FlowStateMachineDefinition.TickMode.MANUAL)
	var b := _machine([b0, b1], b0.get_internal_id(), FlowStateMachineDefinition.TickMode.PHYSICS)
	var c := _machine([c0, c1], c0.get_internal_id(), FlowStateMachineDefinition.TickMode.PROCESS)
	graph.state_machines = [a, b, c]
	_check(not FlowGraphValidator.validate(graph).has_errors(), "Graph valid")
	var controller := PVController.new()
	controller.flow_graph = graph
	add_child(controller)
	await get_tree().process_frame
	var runtime: FlowFSMRuntime = controller.get_fsm_runtime()
	if runtime == null or not runtime.is_running():
		push_error("Potok-6C2 runtime could not start")
		get_tree().quit(1)
		return
	controller.set_process(false)
	controller.set_physics_process(false)
	var aid: String = a.get_internal_id()
	var bid: String = b.get_internal_id()
	var cid: String = c.get_internal_id()
	runtime.transition_committed.connect(func(mid: String, _previous: String, _next: String, _trigger: String) -> void:
		committed.append(mid)
	)
	runtime.request_rejected.connect(func(mid: String, kind: StringName, code: StringName) -> void:
		refused.append(mid + ":" + String(kind) + ":" + String(code))
	)
	runtime.state_entered.connect(func(mid: String, sid: String) -> void:
		if mid == aid and sid == a1.get_internal_id():
			admissions.append(runtime.request_transition(bid, b1.get_internal_id()))
		elif mid == bid and sid == b1.get_internal_id():
			admissions.append(runtime.request_transition(aid, a0.get_internal_id()))
		elif mid == aid and sid == a0.get_internal_id():
			admissions.append(runtime.request_transition(bid, b0.get_internal_id()))
		elif mid == bid and sid == b0.get_internal_id():
			admissions.append(runtime.request_transition(aid, a1.get_internal_id()))
	)
	_check(runtime.request_transition(cid, c1.get_internal_id()), "Independent root queues")
	_check(runtime.request_transition(aid, a1.get_internal_id()), "Seed cyclical root queues")
	for i: int in 8:
		var mode: int = FlowStateMachineDefinition.TickMode.MANUAL if i % 2 == 0 else FlowStateMachineDefinition.TickMode.PHYSICS
		runtime.tick(0.1, mode)
		_check(committed.size() == i + 1, "One cyclic commit at hop %d" % (i + 1))
	_check(admissions.size() == 8, "Eight callback requests attempted")
	_check(admissions.count(false) == 1, "Ninth hop rejected once")
	_check(refused == [aid + ":direct:chain_budget_exceeded"], "Chain-specific diagnostic")
	_check(runtime.pending_request_count() == 1, "Only independent root remains queued")
	for i: int in 4:
		runtime.tick(0.1, FlowStateMachineDefinition.TickMode.MANUAL)
		runtime.tick(0.1, FlowStateMachineDefinition.TickMode.PHYSICS)
	_check(committed.size() == 8, "Saturated chain cannot restart itself")
	_check(runtime.pending_request_count() == 1, "Independent root is preserved")
	runtime.tick(0.1, FlowStateMachineDefinition.TickMode.PROCESS)
	_check(runtime.get_active_state_id(cid) == c1.get_internal_id(), "Independent root commits")
	_check(runtime.pending_request_count() == 0, "All admitted requests are consumed")
	_check(committed.size() == 9, "Only unrelated ninth commit")
	_check(not FlowGraphValidator.validate(graph).has_errors(), "Authored graph remains intact")
	controller.visual_program_enabled = false
	controller.queue_free()
	await get_tree().process_frame
	if failures.is_empty():
		print("[Flujo] Potok 6C2 lineage isolation passed")
	get_tree().quit(0 if failures.is_empty() else 1)

func _machine(states: Array[FlowStateDefinition], first: String, mode: int) -> FlowStateMachineDefinition:
	var machine := FlowStateMachineDefinition.new()
	machine.states = states
	machine.initial_state_id = first
	machine.tick_mode = mode
	return machine

func _check(ok: bool, description: String) -> void:
	if not ok:
		failures.append(description)
		push_error("[Flujo] Potok 6C2: " + description)
