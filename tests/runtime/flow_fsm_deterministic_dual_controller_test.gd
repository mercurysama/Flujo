extends Node

## Potok 8D2-B3A1: identical direct inputs replay deterministically across
## two independent controllers with the same authored two-machine graph.
var _failures: Array[String] = []
var _trace_a: Array[String] = []
var _trace_b: Array[String] = []


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var graph: FlowGraph = FlowGraph.new()
	graph.schema_version = FlowGraph.SCHEMA_VERSION_3
	graph.constructor = FlowConstructorDefinition.new()
	var a_idle: FlowStateDefinition = _state("A-Idle")
	var a_target: FlowStateDefinition = _state("A-Target")
	var b_idle: FlowStateDefinition = _state("B-Idle")
	var b_target: FlowStateDefinition = _state("B-Target")
	var machine_a: FlowStateMachineDefinition = _machine(a_idle, a_target)
	var machine_b: FlowStateMachineDefinition = _machine(b_idle, b_target)
	graph.state_machines = [machine_a, machine_b]
	if not _check(not FlowGraphValidator.validate(graph).has_errors(),
			"Shared authored graph with two MANUAL machines validates"):
		get_tree().quit(1)
		return

	var controller_a: PVController = PVController.new()
	controller_a.flow_graph = graph
	var controller_b: PVController = PVController.new()
	controller_b.flow_graph = graph
	add_child(controller_a)
	add_child(controller_b)
	await get_tree().process_frame
	var runtime_a: FlowFSMRuntime = controller_a.get_fsm_runtime()
	var runtime_b: FlowFSMRuntime = controller_b.get_fsm_runtime()
	if not _check(runtime_a != null and runtime_b != null
			and runtime_a != runtime_b and runtime_a.is_running()
			and runtime_b.is_running(), "Both controllers own separate running runtimes"):
		controller_a.queue_free()
		controller_b.queue_free()
		get_tree().quit(1)
		return

	var id_a: String = machine_a.get_internal_id()
	var id_b: String = machine_b.get_internal_id()
	var a_start: String = a_idle.get_internal_id()
	var b_start: String = b_idle.get_internal_id()
	var a_end: String = a_target.get_internal_id()
	var b_end: String = b_target.get_internal_id()
	_check(runtime_a.get_active_state_id(id_a) == a_start
			and runtime_a.get_active_state_id(id_b) == b_start
			and runtime_b.get_active_state_id(id_a) == a_start
			and runtime_b.get_active_state_id(id_b) == b_start,
			"Both instances begin at equal authored initial state IDs")
	runtime_a.transition_committed.connect(_record_a)
	runtime_b.transition_committed.connect(_record_b)
	_check(runtime_a.change_state(id_a, a_end)
			and runtime_a.change_state(id_b, b_end),
			"A accepts two ordered direct requests")
	_check(runtime_a.pending_request_count() == 2
			and runtime_b.pending_request_count() == 0
			and runtime_b.get_active_state_id(id_a) == a_start
			and runtime_b.get_active_state_id(id_b) == b_start,
			"A queue and initial state do not leak to independent B")
	_check(runtime_b.change_state(id_a, a_end)
			and runtime_b.change_state(id_b, b_end),
			"B independently accepts the identical direct sequence")
	_check(runtime_a.pending_request_count() == 2
			and runtime_b.pending_request_count() == 2,
			"Each instance holds its own pair of pending requests")

	runtime_a.tick(0.1, FlowStateMachineDefinition.TickMode.MANUAL)
	var expected: Array[String] = [
		id_a + ":" + a_start + ">" + a_end + ":direct",
		id_b + ":" + b_start + ">" + b_end + ":direct"
	]
	_check(_trace_a == expected,
			"A commits both expected transitions in authored machine order")
	_check(_trace_b.is_empty()
			and runtime_b.pending_request_count() == 2
			and runtime_b.get_active_state_id(id_a) == a_start,
			"Advancing A alone cannot consume B queue or change its states")

	runtime_b.tick(0.1, FlowStateMachineDefinition.TickMode.MANUAL)
	_check(_trace_b == expected and _trace_a == _trace_b,
			"Same inputs and tick yield identical ordered commit traces")
	_check(runtime_a.pending_request_count() == 0
			and runtime_b.pending_request_count() == 0,
			"Both independent queues drain completely")
	_check(runtime_a.get_active_state_id(id_a) == a_end
			and runtime_a.get_active_state_id(id_b) == b_end
			and runtime_b.get_active_state_id(id_a) == a_end
			and runtime_b.get_active_state_id(id_b) == b_end,
			"Final active machine states are equivalent in both runtimes")
	_check(graph.state_machines == [machine_a, machine_b]
			and machine_a.states == [a_idle, a_target]
			and machine_b.states == [b_idle, b_target]
			and not FlowGraphValidator.validate(graph).has_errors(),
			"Shared authored graph remains unmodified after both ticks")

	controller_a.visual_program_enabled = false
	controller_b.visual_program_enabled = false
	controller_a.queue_free()
	controller_b.queue_free()
	await get_tree().process_frame
	if _failures.is_empty():
		print("[Flujo] Potok 8D2-B3A1 deterministic dual controller replay passed")
	else:
		for error: String in _failures:
			push_error("[Flujo] Potok 8D2-B3A1: " + error)
	get_tree().quit(0 if _failures.is_empty() else 1)


func _state(name: String) -> FlowStateDefinition:
	var state: FlowStateDefinition = FlowStateDefinition.new()
	state.display_name = name
	return state


func _machine(initial: FlowStateDefinition,
		target: FlowStateDefinition) -> FlowStateMachineDefinition:
	var machine: FlowStateMachineDefinition = FlowStateMachineDefinition.new()
	machine.tick_mode = FlowStateMachineDefinition.TickMode.MANUAL
	machine.states = [initial, target]
	machine.initial_state_id = initial.get_internal_id()
	return machine


func _record_a(machine_id: String, from_state_id: String,
		to_state_id: String, trigger_id: String) -> void:
	_trace_a.append(machine_id + ":" + from_state_id + ">" + to_state_id
			+ ":" + trigger_id)


func _record_b(machine_id: String, from_state_id: String,
		to_state_id: String, trigger_id: String) -> void:
	_trace_b.append(machine_id + ":" + from_state_id + ">" + to_state_id
			+ ":" + trigger_id)


func _check(value: bool, message: String) -> bool:
	if not value:
		_failures.append(message)
		push_error("[Flujo] Potok 8D2-B3A1 assertion: " + message)
	return value
