extends Node

## Potok 5F-2: event consumption is observable only on its machine clock.
var failures: Array[String] = []
var observed: Array[String] = []
var copies: Array[Dictionary] = []
var transitions: int = 0
var callback_injections: int = 0


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
	var machine: FlowStateMachineDefinition = FlowStateMachineDefinition.new()
	machine.states = [idle, next]
	machine.initial_state_id = idle.get_internal_id()
	machine.tick_mode = FlowStateMachineDefinition.TickMode.MANUAL
	var physics_state: FlowStateDefinition = FlowStateDefinition.new()
	var physics: FlowStateMachineDefinition = FlowStateMachineDefinition.new()
	physics.states = [physics_state]
	physics.initial_state_id = physics_state.get_internal_id()
	physics.tick_mode = FlowStateMachineDefinition.TickMode.PHYSICS
	graph.state_machines = [machine, physics]
	_check(not FlowGraphValidator.validate(graph).has_errors(), "Valid two-clock fixture.")
	var controller: PVController = PVController.new()
	controller.flow_graph = graph
	add_child(controller)
	await get_tree().process_frame
	var runtime: FlowFSMRuntime = controller.get_fsm_runtime()
	if not _check(runtime != null and runtime.is_running(), "Potok starts."):
		controller.queue_free()
		_finish()
		return
	controller.set_process(false)
	controller.set_physics_process(false)
	var m: String = machine.get_internal_id()
	var p: String = physics.get_internal_id()
	runtime.event_consumed.connect(func(id: String, event_name: StringName, data: Dictionary) -> void:
		observed.append(id + ":" + String(event_name))
		copies.append(data.duplicate(true))
		if event_name == &"go":
			data["nested"]["num"] = 987
			callback_injections += 1 if runtime.emit_event(m, &"after", {"from": "observer"}) else 0
			runtime.tick(0.1, FlowStateMachineDefinition.TickMode.MANUAL)
	)
	runtime.transition_committed.connect(func(_id: String, _old: String, _new: String, _edge: String) -> void:
		transitions += 1
	)
	var caller_data: Dictionary = {"nested": {"num": 3}}
	_check(runtime.emit_event(m, &"unmatched", {"n": 1}), "Unmatched queues.")
	_check(runtime.emit_event(p, &"other_clock", {"n": 2}), "Cross-clock event queues.")
	_check(runtime.emit_event(m, &"go", caller_data), "Matched event queues.")
	caller_data["nested"]["num"] = 400
	runtime.tick(0.1, FlowStateMachineDefinition.TickMode.MANUAL)
	_check(observed == [m + ":unmatched", m + ":go"],
		"Same-clock events observed exactly once in queue FIFO order.")
	_check(copies.size() == 2 and copies[0].get("n") == 1,
		"Unmatched event provides its payload.")
	if copies.size() == 2:
		var nested: Dictionary = copies[1].get("nested", {})
		_check(nested.get("num") == 3, "Delivered copy is isolated from caller and other listeners.")
	_check(runtime.get_active_state_id(m) == next.get_internal_id(), "Matched event commits once.")
	_check(transitions == 1, "Reentrant callback cannot commit an extra transition.")
	_check(callback_injections == 1, "Consumption listener can queue an event.")
	_check(runtime.pending_request_count() == 2,
		"Other-clock event and newly enqueued event both survive.")
	runtime.tick(0.1, FlowStateMachineDefinition.TickMode.PHYSICS)
	_check(observed == [m + ":unmatched", m + ":go", p + ":other_clock"],
		"Cross-clock packet observed only on matching clock.")
	_check(runtime.pending_request_count() == 1, "Other-clock delivery preserves deferred packet.")
	runtime.tick(0.1, FlowStateMachineDefinition.TickMode.MANUAL)
	_check(observed.back() == m + ":after", "Callback event observed on next manual tick.")
	_check(runtime.pending_request_count() == 0, "Event queue fully consumed.")
	_check(transitions == 1, "Unmatched events never commit a transition.")
	controller.visual_program_enabled = false
	controller.queue_free()
	await get_tree().process_frame
	_finish()


func _check(ok: bool, detail: String) -> bool:
	if not ok:
		failures.append(detail)
		push_error("[Flujo] Potok-5F-2: " + detail)
	return ok


func _finish() -> void:
	if failures.is_empty():
		print("[Flujo] Potok-5F-2 consumption observation passed")
	get_tree().quit(0 if failures.is_empty() else 1)
