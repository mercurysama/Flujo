extends Node

## FSM-5A — event arbitration and deferred delivery are observable without UI.
var _failures: Array[String] = []
var _events: Array[String] = []


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var graph: FlowGraph = FlowGraph.new()
	graph.schema_version = FlowGraph.SCHEMA_VERSION_3
	graph.constructor = FlowConstructorDefinition.new()
	var idle: FlowStateDefinition = _state("Idle")
	var first: FlowStateDefinition = _state("First")
	var second: FlowStateDefinition = _state("Second")
	var final: FlowStateDefinition = _state("Final")
	var a: FlowStateTransitionDefinition = _edge(&"go", first.get_internal_id(), 5)
	var b: FlowStateTransitionDefinition = _edge(&"go", second.get_internal_id(), 5)
	var c: FlowStateTransitionDefinition = _edge(&"go", final.get_internal_id(), 1)
	idle.transitions = [a, b, c]
	var machine: FlowStateMachineDefinition = FlowStateMachineDefinition.new()
	machine.states = [idle, first, second, final]
	machine.initial_state_id = idle.get_internal_id()
	machine.tick_mode = FlowStateMachineDefinition.TickMode.MANUAL
	graph.state_machines = [machine]
	_check(not FlowGraphValidator.validate(graph).has_errors(), "The graph is valid before execution.")

	var controller: PVController = PVController.new()
	controller.flow_graph = graph
	controller.runtime_output.entry_message_emitted.connect(_on_output)
	add_child(controller)
	await get_tree().process_frame
	var runtime: FlowFSMRuntime = controller.get_fsm_runtime()
	if not _check(runtime != null and runtime.is_running(), "Controller starts a valid FSM."):
		_finish()
		return
	var machine_id: String = machine.get_internal_id()
	var initial_output: int = _events.size()
	_check(not runtime.emit_event(machine_id, &""), "Empty event name is rejected.")
	_check(not runtime.emit_event("invalid-machine", &"go"), "Unknown machine event is rejected.")
	_check(runtime.pending_request_count() == 0, "Rejected events never enqueue.")
	_check(runtime.emit_event(machine_id, &"unmatched"), "Unmatched event can be safely queued.")
	runtime.tick(0.1, FlowStateMachineDefinition.TickMode.MANUAL)
	_check(runtime.pending_request_count() == 0, "Unmatched event is consumed on the matching tick.")
	_check(runtime.get_active_state_id(machine_id) == idle.get_internal_id(),
		"Unmatched event does not transition.")
	_check(_events.size() == initial_output + 1 and _events.back() == "StateUpdate:Idle",
		"Unmatched event still executes one Update.")

	_check(runtime.emit_event(machine_id, &"go"), "Compatible event is enqueued.")
	runtime.tick(0.1, FlowStateMachineDefinition.TickMode.MANUAL)
	_check(runtime.get_active_state_id(machine_id) == first.get_internal_id(),
		"Same-priority event edges prefer declaration order.")
	_check(_events.slice(-3) == ["StateUpdate:Idle", "StateExit:Idle", "StateEnter:First"],
		"One event commits exactly one Exit and one Enter.")
	_check(_events.count("StateUpdate:First") == 0,
		"Destination Update waits until the next tick.")

	_check(runtime.request_transition(machine_id, idle.get_internal_id()), "Direct reset queues.")
	runtime.tick(0.1, FlowStateMachineDefinition.TickMode.MANUAL)
	_check(runtime.get_active_state_id(machine_id) == idle.get_internal_id(), "Direct reset returns to Idle.")
	_check(runtime.emit_event(machine_id, &"go"), "Event priority focal enqueues.")
	a.priority = 1
	b.priority = 8
	runtime.tick(0.1, FlowStateMachineDefinition.TickMode.MANUAL)
	_check(runtime.get_active_state_id(machine_id) == second.get_internal_id(),
		"Higher priority wins independent of authored order.")
	# Restore the authored definition: the runtime should never depend on editing during gameplay.
	a.priority = 5
	b.priority = 5

	_check(runtime.request_transition(machine_id, idle.get_internal_id()), "Direct return queues again.")
	runtime.tick(0.1, FlowStateMachineDefinition.TickMode.MANUAL)
	var injected: Array[bool] = []
	runtime.state_updated.connect(func(id: String, state_id: String) -> void:
		if id == machine_id and state_id == idle.get_internal_id() and injected.is_empty():
			injected.append(runtime.emit_event(machine_id, &"go"))
	)
	runtime.tick(0.1, FlowStateMachineDefinition.TickMode.MANUAL)
	_check(injected == [true], "Event emitted in Update is accepted.")
	_check(runtime.get_active_state_id(machine_id) == idle.get_internal_id(),
		"Event emitted during Update cannot transition in that same tick.")
	_check(runtime.pending_request_count() == 1, "Update event remains queued.")
	runtime.tick(0.1, FlowStateMachineDefinition.TickMode.MANUAL)
	_check(runtime.get_active_state_id(machine_id) == first.get_internal_id(),
		"Deferred event commits on next matching tick.")
	_check(runtime.pending_request_count() == 0, "Delivered event is consumed once.")

	controller.visual_program_enabled = false
	controller.queue_free()
	await get_tree().process_frame
	_finish()


func _state(label: String) -> FlowStateDefinition:
	var result: FlowStateDefinition = FlowStateDefinition.new()
	result.display_name = label
	var enter: FlowPrintBlock = FlowPrintBlock.new()
	enter.text = label
	var update: FlowPrintBlock = FlowPrintBlock.new()
	update.text = label
	var exit: FlowPrintBlock = FlowPrintBlock.new()
	exit.text = label
	result.enter_blocks = [enter]
	result.blocks = [update]
	result.exit_blocks = [exit]
	return result


func _edge(event_name: StringName, target_id: String, priority: int) -> FlowStateTransitionDefinition:
	var result: FlowStateTransitionDefinition = FlowStateTransitionDefinition.new()
	result.trigger = FlowStateTransitionDefinition.Trigger.EVENT
	result.event_name = event_name
	result.target_state_id = target_id
	result.priority = priority
	return result


func _on_output(_controller: Node, _container_id: String, _block_id: String,
		message: String, phase: StringName) -> void:
	_events.append("%s:%s" % [String(phase), message])


func _check(ok: bool, description: String) -> bool:
	if not ok:
		_failures.append(description)
		push_error("[Flujo] FSM-5A: " + description)
	return ok


func _finish() -> void:
	if _failures.is_empty():
		print("[Flujo] FSM-5A event ordering test passed")
	else:
		for failure: String in _failures:
			push_error("[Flujo] FSM-5A failed: " + failure)
	get_tree().quit(0 if _failures.is_empty() else 1)
