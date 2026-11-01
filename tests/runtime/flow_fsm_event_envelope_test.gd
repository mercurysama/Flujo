extends Node

## Potok 5F-1B: machine-scoped JSON-safe event packets.
var failures: Array[String] = []


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var graph: FlowGraph = FlowGraph.new()
	graph.schema_version = FlowGraph.SCHEMA_VERSION_3
	graph.constructor = FlowConstructorDefinition.new()
	var idle: FlowStateDefinition = FlowStateDefinition.new()
	var done: FlowStateDefinition = FlowStateDefinition.new()
	var edge: FlowStateTransitionDefinition = FlowStateTransitionDefinition.new()
	edge.trigger = FlowStateTransitionDefinition.Trigger.EVENT
	edge.event_name = &"go"
	edge.target_state_id = done.get_internal_id()
	idle.transitions = [edge]
	var machine: FlowStateMachineDefinition = FlowStateMachineDefinition.new()
	machine.states = [idle, done]
	machine.initial_state_id = idle.get_internal_id()
	machine.tick_mode = FlowStateMachineDefinition.TickMode.MANUAL
	graph.state_machines = [machine]
	_check(not FlowGraphValidator.validate(graph).has_errors(), "Fixture graph is valid.")
	var controller: PVController = PVController.new()
	controller.flow_graph = graph
	add_child(controller)
	await get_tree().process_frame
	var runtime: FlowFSMRuntime = controller.get_fsm_runtime()
	if not _check(runtime != null and runtime.is_running(), "Potok runtime starts."):
		controller.queue_free()
		_finish()
		return
	controller.set_process(false)
	controller.set_physics_process(false)
	var machine_id: String = machine.get_internal_id()
	var nested: Dictionary = {"items": [1, true, {"level": 3}], "label": "start"}
	_check(runtime.emit_event(machine_id, &"go", nested), "Valid nested payload is admitted.")
	nested["items"][2]["level"] = 99
	nested["label"] = "changed"
	_check(runtime.pending_request_count() == 1, "Accepted packet is queued.")
	var pending: Array = runtime.get("_pending_requests") as Array
	if pending.size() == 1:
		var stored: Dictionary = pending[0].get("payload", {})
		_check(stored.get("label") == "start", "Payload is detached from caller's dictionary.")
		var items: Array = stored.get("items", [])
		_check(items.size() == 3 and items[2] is Dictionary and items[2].get("level") == 3,
			"Nested arrays and dictionaries are deeply copied.")
	var invalid: Dictionary = {"node": controller}
	_check(not runtime.emit_event(machine_id, &"go", invalid), "Live Node payload is rejected.")
	_check(not runtime.emit_event(machine_id, &"go", {1: "wrong key"}),
		"Non-string dictionary keys are rejected.")
	_check(not runtime.emit_event(machine_id, &"go", {"too_large": "a".repeat(70000)}),
		"Oversized JSON payload is rejected.")
	_check(not runtime.emit_event("missing-machine", &"go", {}), "Unknown machine rejected.")
	_check(runtime.pending_request_count() == 1, "Rejected packets do not mutate queue.")
	runtime.tick(0.1, FlowStateMachineDefinition.TickMode.MANUAL)
	_check(runtime.get_active_state_id(machine_id) == done.get_internal_id(),
		"Payload event still triggers exactly one matching transition.")
	_check(runtime.pending_request_count() == 0, "Delivered event consumed.")
	_check(runtime.emit_event(machine_id, &"unmatched"), "Legacy two-argument API is preserved.")
	_check(runtime.pending_request_count() == 1, "Legacy event enqueued.")
	runtime.tick(0.1, FlowStateMachineDefinition.TickMode.MANUAL)
	_check(runtime.pending_request_count() == 0, "Legacy event consumed.")
	controller.visual_program_enabled = false
	controller.queue_free()
	await get_tree().process_frame
	_finish()


func _check(ok: bool, message: String) -> bool:
	if not ok:
		failures.append(message)
		push_error("[Flujo] Potok-5F-1: " + message)
	return ok


func _finish() -> void:
	if failures.is_empty():
		print("[Flujo] Potok-5F-1 event envelope test passed")
	get_tree().quit(0 if failures.is_empty() else 1)
