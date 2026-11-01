extends Node

## FSM-5C: bounded cross-clock queue, deferred callback admission and FIFO.
var failures: Array[String] = []


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var graph: FlowGraph = FlowGraph.new()
	graph.schema_version = FlowGraph.SCHEMA_VERSION_3
	graph.constructor = FlowConstructorDefinition.new()
	var idle: FlowStateDefinition = FlowStateDefinition.new()
	var next: FlowStateDefinition = FlowStateDefinition.new()
	var edge: FlowStateTransitionDefinition = FlowStateTransitionDefinition.new()
	edge.trigger = FlowStateTransitionDefinition.Trigger.EVENT
	edge.event_name = &"go"
	edge.target_state_id = next.get_internal_id()
	idle.transitions = [edge]
	var manual: FlowStateMachineDefinition = FlowStateMachineDefinition.new()
	manual.states = [idle, next]
	manual.initial_state_id = idle.get_internal_id()
	manual.tick_mode = FlowStateMachineDefinition.TickMode.MANUAL
	var physics_state: FlowStateDefinition = FlowStateDefinition.new()
	var physics: FlowStateMachineDefinition = FlowStateMachineDefinition.new()
	physics.states = [physics_state]
	physics.initial_state_id = physics_state.get_internal_id()
	physics.tick_mode = FlowStateMachineDefinition.TickMode.PHYSICS
	graph.state_machines = [manual, physics]
	_check(not FlowGraphValidator.validate(graph).has_errors(), "Two-clock fixture validates.")

	var controller: PVController = PVController.new()
	controller.flow_graph = graph
	add_child(controller)
	await get_tree().process_frame
	var runtime: FlowFSMRuntime = controller.get_fsm_runtime()
	if not _check(runtime != null and runtime.is_running(), "FSM starts for 5C."):
		controller.queue_free()
		_finish()
		return
	var m: String = manual.get_internal_id()
	var p: String = physics.get_internal_id()
	# Real Godot physics clock may consume queued items. Disable the controller's
	# engine callbacks without disabling its manually operated FSM runtime.
	controller.set_process(false)
	controller.set_physics_process(false)
	var limit: int = FlowFSMRuntime.MAX_PENDING_REQUESTS
	for index: int in limit:
		_check(runtime.emit_event(p, &"none"), "Cross-clock event %d admitted." % index)
	_check(runtime.pending_request_count() == limit, "Queue reaches exactly the limit.")
	_check(not runtime.emit_event(p, &"none"), "Overflow event is rejected.")
	_check(not runtime.request_transition(m, next.get_internal_id()),
		"Overflow direct request is rejected without mutation.")
	_check(runtime.pending_request_count() == limit, "Overflow never changes queue length.")

	var callback_results: Array[bool] = []
	runtime.state_updated.connect(func(machine_id: String, _state_id: String) -> void:
		if machine_id == m and callback_results.size() < 2:
			callback_results.append(runtime.emit_event(m, &"go"))
	)
	runtime.tick(0.1, FlowStateMachineDefinition.TickMode.MANUAL)
	_check(callback_results == [false],
		"A callback may not accept an event when cross-clock carryover fills the queue.")
	_check(runtime.get_active_state_id(m) == idle.get_internal_id(),
		"Overflow callback cannot change the active state.")
	_check(runtime.pending_request_count() == limit,
		"All older cross-clock requests are retained; nothing accepted is silently lost.")
	# 6G: a single machine now delivers 32 accepted packets per matching
	# tick, so the original 256-capacity admission test drains in eight ticks.
	for tick_index: int in FlowFSMRuntime.MAX_PENDING_REQUESTS / FlowFSMRuntime.MAX_REQUESTS_PER_MACHINE_TICK:
		runtime.tick(0.1, FlowStateMachineDefinition.TickMode.PHYSICS)
		var remaining: int = FlowFSMRuntime.MAX_PENDING_REQUESTS \
				- (tick_index + 1) * FlowFSMRuntime.MAX_REQUESTS_PER_MACHINE_TICK
		_check(runtime.pending_request_count() == remaining,
			"Budgeted cross-clock carryover remains intact at tick %d." % tick_index)
	_check(runtime.pending_request_count() == 0, "Target clock drains unmatched events without loss.")
	runtime.tick(0.1, FlowStateMachineDefinition.TickMode.MANUAL)
	_check(callback_results == [false, true], "Callback is admitted after capacity is freed.")
	_check(runtime.get_active_state_id(m) == idle.get_internal_id(),
		"Callback event is deferred to the following manual tick.")
	_check(runtime.pending_request_count() == 1, "Accepted callback event is preserved.")
	runtime.tick(0.1, FlowStateMachineDefinition.TickMode.MANUAL)
	_check(runtime.get_active_state_id(m) == next.get_internal_id(),
		"Accepted event transitions on next tick.")
	_check(runtime.pending_request_count() == 0, "Accepted event is consumed once.")

	controller.visual_program_enabled = false
	controller.queue_free()
	await get_tree().process_frame
	_finish()


func _check(ok: bool, description: String) -> bool:
	if not ok:
		failures.append(description)
		push_error("[Flujo] FSM-5C: " + description)
	return ok


func _finish() -> void:
	if failures.is_empty():
		print("[Flujo] FSM-5C bounded queue test passed")
	get_tree().quit(0 if failures.is_empty() else 1)
