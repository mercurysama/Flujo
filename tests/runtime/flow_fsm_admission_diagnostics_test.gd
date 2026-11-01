extends Node

## Potok 5G admission diagnostics, including reserved in-flight capacity.
var failures: Array[String] = []
var reasons: Array[String] = []


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var graph: FlowGraph = FlowGraph.new()
	graph.schema_version = FlowGraph.SCHEMA_VERSION_3
	graph.constructor = FlowConstructorDefinition.new()
	var idle: FlowStateDefinition = FlowStateDefinition.new()
	var next: FlowStateDefinition = FlowStateDefinition.new()
	var disabled: FlowStateDefinition = FlowStateDefinition.new()
	disabled.enabled = false
	var manual: FlowStateMachineDefinition = FlowStateMachineDefinition.new()
	manual.states = [idle, next, disabled]
	manual.initial_state_id = idle.get_internal_id()
	manual.tick_mode = FlowStateMachineDefinition.TickMode.MANUAL
	var clock_state: FlowStateDefinition = FlowStateDefinition.new()
	var physics: FlowStateMachineDefinition = FlowStateMachineDefinition.new()
	physics.states = [clock_state]
	physics.initial_state_id = clock_state.get_internal_id()
	physics.tick_mode = FlowStateMachineDefinition.TickMode.PHYSICS
	graph.state_machines = [manual, physics]
	_check(not FlowGraphValidator.validate(graph).has_errors(), "Valid diagnostic test graph.")
	var controller: PVController = PVController.new()
	controller.flow_graph = graph
	add_child(controller)
	await get_tree().process_frame
	var runtime: FlowFSMRuntime = controller.get_fsm_runtime()
	if not _check(runtime != null and runtime.is_running(), "Runtime available."):
		controller.queue_free()
		_finish()
		return
	controller.set_process(false)
	controller.set_physics_process(false)
	var m: String = manual.get_internal_id()
	var p: String = physics.get_internal_id()
	runtime.request_rejected.connect(func(id: String, kind: StringName, code: StringName) -> void:
		reasons.append(id + ":" + String(kind) + ":" + String(code))
	)
	_check(not runtime.emit_event(m, &""), "Reject empty event.")
	_check(reasons.back() == m + ":event:invalid_event_name", "Stable name diagnostic.")
	_check(not runtime.emit_event("unknown", &"go"), "Reject unknown machine.")
	_check(reasons.back() == "unknown:event:invalid_machine", "Stable machine diagnostic.")
	_check(not runtime.emit_event(m, &"go", {"node": controller}), "Reject unsafe payload.")
	_check(reasons.back() == m + ":event:invalid_payload", "Stable payload diagnostic.")
	_check(not runtime.request_transition(m, "missing"), "Reject missing target.")
	_check(reasons.back() == m + ":direct:invalid_target", "Stable target diagnostic.")
	_check(not runtime.request_transition(m, disabled.get_internal_id()), "Reject disabled target.")
	_check(reasons.back() == m + ":direct:invalid_target", "Disabled target diagnostic.")
	_check(runtime.pending_request_count() == 0 and reasons.size() == 5,
		"Each invalid request yields exactly one diagnostic and no enqueue.")
	_check(runtime.emit_event(p, &"other"), "Valid event accepts without diagnostic.")
	_check(reasons.size() == 5, "Accepted events have no rejection signal.")
	for i: int in FlowFSMRuntime.MAX_PENDING_REQUESTS - 1:
		_check(runtime.emit_event(p, &"other"), "Fill queue item %d." % i)
	_check(runtime.pending_request_count() == FlowFSMRuntime.MAX_PENDING_REQUESTS,
		"Exactly 256 items admitted.")
	_check(not runtime.emit_event(m, &"go"), "Reject full queue event.")
	_check(reasons.back() == m + ":event:queue_full", "Overflow has specific diagnostic.")
	_check(not runtime.request_transition(m, next.get_internal_id()), "Reject full queue direct.")
	_check(reasons.back() == m + ":direct:queue_full", "Direct overflow diagnostic.")
	var before: int = reasons.size()
	runtime.state_updated.connect(func(id: String, _state: String) -> void:
		if id == m and reasons.size() == before:
			_check(not runtime.emit_event(m, &"callback"), "Reserved overflow rejected in callback.")
	)
	runtime.tick(0.1, FlowStateMachineDefinition.TickMode.MANUAL)
	_check(reasons.size() == before + 1 and reasons.back() == m + ":event:queue_full",
		"Callback reservation reports exactly one queue_full.")
	_check(runtime.pending_request_count() == FlowFSMRuntime.MAX_PENDING_REQUESTS,
		"Rejected callback preserves carried-over queue.")
	# 6G: each matching PHYSICS tick may consume only 32 events.
	# Preserve the 5G rejection contract while verifying no accepted data is lost.
	for tick_index: int in FlowFSMRuntime.MAX_PENDING_REQUESTS / FlowFSMRuntime.MAX_REQUESTS_PER_MACHINE_TICK:
		runtime.tick(0.1, FlowStateMachineDefinition.TickMode.PHYSICS)
		var remaining: int = FlowFSMRuntime.MAX_PENDING_REQUESTS \
				- (tick_index + 1) * FlowFSMRuntime.MAX_REQUESTS_PER_MACHINE_TICK
		_check(runtime.pending_request_count() == remaining,
			"Budgeted physics drainage keeps all admitted events at tick %d." % tick_index)
	_check(runtime.pending_request_count() == 0, "Matching physics clock drains all events without loss.")
	runtime.stop()
	_check(not runtime.emit_event(m, &"go"), "Stopped runtime rejects events.")
	_check(reasons.back() == m + ":event:not_running", "Stopped event diagnostic.")
	_check(not runtime.request_transition(m, next.get_internal_id()), "Stopped runtime rejects direct.")
	_check(reasons.back() == m + ":direct:not_running", "Stopped direct diagnostic.")
	controller.queue_free()
	await get_tree().process_frame
	_finish()


func _check(ok: bool, description: String) -> bool:
	if not ok:
		failures.append(description)
		push_error("[Flujo] Potok-5G: " + description)
	return ok


func _finish() -> void:
	if failures.is_empty():
		print("[Flujo] Potok-5G admission diagnostics passed")
	get_tree().quit(0 if failures.is_empty() else 1)
