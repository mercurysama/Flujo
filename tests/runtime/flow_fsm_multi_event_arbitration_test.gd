extends Node

## FSM-5D: multi-event arbitration, direct FIFO and cross-clock isolation.
var failures: Array[String] = []
var transitions: Array[String] = []


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var graph: FlowGraph = FlowGraph.new()
	graph.schema_version = FlowGraph.SCHEMA_VERSION_3
	graph.constructor = FlowConstructorDefinition.new()
	var idle: FlowStateDefinition = _state("Idle")
	var low: FlowStateDefinition = _state("Low")
	var high: FlowStateDefinition = _state("High")
	var earliest: FlowStateDefinition = _state("Earliest")
	var after: FlowStateDefinition = _state("After")
	idle.transitions = [
		_event(&"low", low.get_internal_id(), 1),
		_event(&"high", high.get_internal_id(), 20),
		_event(&"earlier", earliest.get_internal_id(), 5),
		_event(&"later", after.get_internal_id(), 5),
	]
	var primary: FlowStateMachineDefinition = _machine(
		[idle, low, high, earliest, after], idle.get_internal_id(),
		FlowStateMachineDefinition.TickMode.MANUAL
	)
	var clock_initial: FlowStateDefinition = _state("ClockIdle")
	var clock_end: FlowStateDefinition = _state("ClockEnd")
	clock_initial.transitions = [_event(&"clock", clock_end.get_internal_id(), 1)]
	var clock: FlowStateMachineDefinition = _machine(
		[clock_initial, clock_end], clock_initial.get_internal_id(),
		FlowStateMachineDefinition.TickMode.PHYSICS
	)
	graph.state_machines = [primary, clock]
	_check(not FlowGraphValidator.validate(graph).has_errors(), "5D fixture is valid.")

	var controller: PVController = PVController.new()
	controller.flow_graph = graph
	add_child(controller)
	await get_tree().process_frame
	var runtime: FlowFSMRuntime = controller.get_fsm_runtime()
	if not _check(runtime != null and runtime.is_running(), "FSM starts."):
		controller.queue_free()
		_finish()
		return
	controller.set_process(false)
	controller.set_physics_process(false)
	runtime.transition_committed.connect(_on_transition)
	var m: String = primary.get_internal_id()
	var p: String = clock.get_internal_id()

	# An early low-priority event must not beat a later high-priority event.
	_check(runtime.emit_event(m, &"low"), "Low event enqueues.")
	_check(runtime.emit_event(m, &"high"), "High event enqueues.")
	_check(runtime.emit_event(p, &"clock"), "Different-clock event enqueues.")
	_check(runtime.pending_request_count() == 3, "Three independent pending items.")
	runtime.tick(0.1, FlowStateMachineDefinition.TickMode.MANUAL)
	_check(runtime.get_active_state_id(m) == high.get_internal_id(),
		"Highest event priority wins across arrival order.")
	_check(runtime.get_active_state_id(p) == clock_initial.get_internal_id(),
		"Other clock remains untouched.")
	_check(runtime.pending_request_count() == 1,
		"Only other-clock event survives; losing same-clock events are consumed.")
	_check(transitions.size() == 1, "At most one transition commits for matching clock.")
	runtime.tick(0.1, FlowStateMachineDefinition.TickMode.PHYSICS)
	_check(runtime.get_active_state_id(p) == clock_end.get_internal_id(),
		"Preserved cross-clock event commits on its own tick.")
	_check(runtime.pending_request_count() == 0, "Delivered cross-clock item is consumed.")
	_check(transitions.size() == 2, "Second clock commits one independent transition.")

	# Equal-priority events from different names use FIFO arrival order, not
	# the authored index of their matching edges.
	_check(runtime.request_transition(m, idle.get_internal_id()), "Return to Idle queues.")
	runtime.tick(0.1, FlowStateMachineDefinition.TickMode.MANUAL)
	_check(runtime.get_active_state_id(m) == idle.get_internal_id(), "Return commits.")
	_check(runtime.emit_event(m, &"later"), "Later-authored event arrives first.")
	_check(runtime.emit_event(m, &"earlier"), "Earlier-authored event arrives second.")
	runtime.tick(0.1, FlowStateMachineDefinition.TickMode.MANUAL)
	_check(runtime.get_active_state_id(m) == after.get_internal_id(),
		"Equal priority resolves by request FIFO before authored edge order.")
	_check(runtime.pending_request_count() == 0, "Both competing events are consumed.")

	# Direct requests override events regardless of arrival order or priority;
	# multiple direct requests honor their own FIFO.
	_check(runtime.request_transition(m, idle.get_internal_id()), "Reset request queues.")
	runtime.tick(0.1, FlowStateMachineDefinition.TickMode.MANUAL)
	_check(runtime.emit_event(m, &"high"), "High event arrives before direct requests.")
	_check(runtime.request_transition(m, low.get_internal_id()), "First direct request queues.")
	_check(runtime.request_transition(m, earliest.get_internal_id()), "Second direct request queues.")
	runtime.tick(0.1, FlowStateMachineDefinition.TickMode.MANUAL)
	_check(runtime.get_active_state_id(m) == low.get_internal_id(),
		"First direct request wins even over earlier high-priority event.")
	_check(runtime.pending_request_count() == 0, "Competing requests are consumed in one tick.")
	_check(runtime.get_active_state_id(p) == clock_end.get_internal_id(),
		"Unrelated machine remains unchanged.")

	# Update callbacks may enqueue future requests, but cannot force an
	# additional transition during the same tick.
	_check(runtime.request_transition(m, idle.get_internal_id()), "Reset for callback queues.")
	runtime.tick(0.1, FlowStateMachineDefinition.TickMode.MANUAL)
	var injected: Array[bool] = []
	runtime.state_updated.connect(func(machine_id: String, state_id: String) -> void:
		if machine_id == m and state_id == idle.get_internal_id() and injected.is_empty():
			injected.append(runtime.request_transition(m, high.get_internal_id()))
	)
	_check(runtime.emit_event(m, &"low"), "Pre-tick event queues.")
	runtime.tick(0.1, FlowStateMachineDefinition.TickMode.MANUAL)
	_check(injected == [true], "Callback queues a direct request.")
	_check(runtime.get_active_state_id(m) == low.get_internal_id(),
		"Pre-tick event commits, callback request remains deferred.")
	_check(runtime.pending_request_count() == 1, "Deferred callback request survives.")
	runtime.tick(0.1, FlowStateMachineDefinition.TickMode.MANUAL)
	_check(runtime.get_active_state_id(m) == high.get_internal_id(),
		"Deferred callback request commits on next tick.")
	_check(runtime.pending_request_count() == 0, "Deferred request consumed once.")
	_check(not FlowGraphValidator.validate(graph).has_errors(),
		"Runtime never mutates authored state/edge graph.")
	controller.visual_program_enabled = false
	controller.queue_free()
	await get_tree().process_frame
	_finish()


func _state(label: String) -> FlowStateDefinition:
	var state: FlowStateDefinition = FlowStateDefinition.new()
	state.display_name = label
	return state


func _machine(states: Array[FlowStateDefinition], initial: String, mode: int) -> FlowStateMachineDefinition:
	var machine: FlowStateMachineDefinition = FlowStateMachineDefinition.new()
	machine.states = states
	machine.initial_state_id = initial
	machine.tick_mode = mode
	return machine


func _event(name: StringName, target: String, priority: int) -> FlowStateTransitionDefinition:
	var edge: FlowStateTransitionDefinition = FlowStateTransitionDefinition.new()
	edge.trigger = FlowStateTransitionDefinition.Trigger.EVENT
	edge.event_name = name
	edge.target_state_id = target
	edge.priority = priority
	return edge


func _on_transition(machine_id: String, from_id: String, to_id: String, _trigger: String) -> void:
	transitions.append(machine_id + ":" + from_id + ":" + to_id)


func _check(ok: bool, message: String) -> bool:
	if not ok:
		failures.append(message)
		push_error("[Flujo] FSM-5D: " + message)
	return ok


func _finish() -> void:
	if failures.is_empty():
		print("[Flujo] FSM-5D arbitration test passed")
	get_tree().quit(0 if failures.is_empty() else 1)
