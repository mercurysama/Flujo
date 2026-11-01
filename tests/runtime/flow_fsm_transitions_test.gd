extends Node

var _failures: Array[String] = []
var _output: Array[String] = []


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var graph: FlowGraph = FlowGraph.new()
	graph.schema_version = FlowGraph.SCHEMA_VERSION_3
	graph.constructor = FlowConstructorDefinition.new()
	var idle: FlowStateDefinition = _state("Idle")
	var busy: FlowStateDefinition = _state("Busy")
	var done: FlowStateDefinition = _state("Done")
	var low: FlowStateTransitionDefinition = _event_edge("go", busy.get_internal_id(), 1)
	var high: FlowStateTransitionDefinition = _event_edge("go", done.get_internal_id(), 10)
	var condition: FlowStateTransitionDefinition = FlowStateTransitionDefinition.new()
	condition.target_state_id = done.get_internal_id()
	condition.condition = FlowLiteralValueSource.new(Variant.Type.TYPE_BOOL, true)
	condition.priority = 20
	idle.transitions = [low, high, null, condition]
	busy.transitions = [_event_edge("finish", done.get_internal_id(), 1)]
	var machine: FlowStateMachineDefinition = FlowStateMachineDefinition.new()
	machine.states = [idle, busy, done]
	machine.initial_state_id = idle.get_internal_id()
	machine.tick_mode = FlowStateMachineDefinition.TickMode.MANUAL
	var side: FlowStateDefinition = _state("Side")
	var side_next: FlowStateDefinition = _state("SideNext")
	side.transitions = [_event_edge("side", side_next.get_internal_id(), 1)]
	var second: FlowStateMachineDefinition = FlowStateMachineDefinition.new()
	second.states = [side, side_next]
	second.initial_state_id = side.get_internal_id()
	second.tick_mode = FlowStateMachineDefinition.TickMode.PHYSICS
	graph.state_machines = [machine, second]
	_check(not FlowGraphValidator.validate(graph).has_errors(), "Valid transition graph is accepted.")
	var copy: FlowGraph = graph.duplicate_with_new_ids()
	_check(not FlowGraphValidator.validate(copy).has_errors(), "Duplicated transition graph is valid.")
	if copy != null:
		var copy_idle: FlowStateDefinition = copy.state_machines[0].states[0]
		_check(copy_idle.transitions[0].target_state_id == copy.state_machines[0].states[1].get_internal_id(),
			"Duplicated event target remaps to the copied state.")
		_check(copy_idle.transitions[3].get_internal_id() != condition.get_internal_id(),
			"Duplicated transition gains an independent ID.")

	var controller: PVController = PVController.new()
	controller.flow_graph = graph
	controller.runtime_output.entry_message_emitted.connect(_record)
	add_child(controller)
	await get_tree().process_frame
	var runtime: FlowFSMRuntime = controller.get_fsm_runtime()
	if not _check(runtime != null, "FSM runtime starts"):
		get_tree().quit(1)
		return
	_check(runtime.get_active_state_id(machine.get_internal_id()) == idle.get_internal_id(), "Initial state is Idle.")
	_check(not runtime.request_transition(machine.get_internal_id(), "missing"), "Unknown target is rejected.")
	_check(runtime.emit_event(machine.get_internal_id(), &"go"), "Named event is queued.")
	runtime.tick(0.1, FlowStateMachineDefinition.TickMode.MANUAL)
	_check(runtime.get_active_state_id(machine.get_internal_id()) == done.get_internal_id(),
		"Higher-priority event wins; event precedes true condition.")
	_check(_output.count("StateExit:Idle-exit") == 1 and _output.count("StateEnter:Done-enter") == 1,
		"Transition exits and enters exactly once.")
	_check(runtime.request_transition(machine.get_internal_id(), idle.get_internal_id()), "Direct request queues.")
	_check(runtime.request_transition(machine.get_internal_id(), busy.get_internal_id()), "Second direct request queues.")
	runtime.tick(0.1, FlowStateMachineDefinition.TickMode.MANUAL)
	_check(runtime.get_active_state_id(machine.get_internal_id()) == idle.get_internal_id(), "FIFO direct request wins.")
	_check(runtime.request_transition(machine.get_internal_id(), busy.get_internal_id()), "Direct request can override condition.")
	runtime.tick(0.1, FlowStateMachineDefinition.TickMode.MANUAL)
	_check(runtime.get_active_state_id(machine.get_internal_id()) == busy.get_internal_id(), "Direct target activated.")
	_check(runtime.emit_event(machine.get_internal_id(), &"finish"), "Busy completion event queues.")
	runtime.tick(0.1, FlowStateMachineDefinition.TickMode.MANUAL)
	_check(runtime.get_active_state_id(machine.get_internal_id()) == done.get_internal_id(),
		"Busy event reaches Done.")
	_check(runtime.emit_event(second.get_internal_id(), &"side"), "Second-machine event queues.")
	runtime.tick(0.1, FlowStateMachineDefinition.TickMode.MANUAL)
	_check(runtime.get_active_state_id(second.get_internal_id()) == side.get_internal_id(),
		"Different clock leaves second machine unchanged.")
	_check(runtime.pending_request_count() == 1, "Cross-clock event waits in queue.")
	runtime.tick(0.1, FlowStateMachineDefinition.TickMode.PHYSICS)
	_check(runtime.get_active_state_id(second.get_internal_id()) == side_next.get_internal_id(),
		"Second machine processes its queued event on physics tick.")

	_check(runtime.request_transition(machine.get_internal_id(), idle.get_internal_id()), "Return to Idle.")
	runtime.tick(0.1, FlowStateMachineDefinition.TickMode.MANUAL)
	runtime.tick(0.1, FlowStateMachineDefinition.TickMode.MANUAL)
	_check(runtime.get_active_state_id(machine.get_internal_id()) == done.get_internal_id(),
		"True Condition Tok triggers without events.")
	_check(not FlowGraphValidator.validate(graph).has_errors(), "Execution does not mutate authored graph.")
	controller.visual_program_enabled = false
	_check(not runtime.is_running(), "Disabling controller stops FSM and clears runtime.")
	controller.queue_free()
	await get_tree().process_frame
	if _failures.is_empty():
		print("[Flujo] FSM 002 transitions test passed")
	else:
		for failure: String in _failures:
			push_error("[Flujo] FSM 002: " + failure)
	get_tree().quit(0 if _failures.is_empty() else 1)


func _state(label: String) -> FlowStateDefinition:
	var s: FlowStateDefinition = FlowStateDefinition.new()
	s.display_name = label
	var enter: FlowPrintBlock = FlowPrintBlock.new()
	enter.text = label + "-enter"
	var update: FlowPrintBlock = FlowPrintBlock.new()
	update.text = label + "-update"
	var exit: FlowPrintBlock = FlowPrintBlock.new()
	exit.text = label + "-exit"
	s.enter_blocks = [enter]
	s.blocks = [update]
	s.exit_blocks = [exit]
	return s


func _event_edge(name: String, target: String, priority: int) -> FlowStateTransitionDefinition:
	var e: FlowStateTransitionDefinition = FlowStateTransitionDefinition.new()
	e.trigger = FlowStateTransitionDefinition.Trigger.EVENT
	e.event_name = StringName(name)
	e.target_state_id = target
	e.priority = priority
	return e


func _record(_controller: Node, _process_id: String, _block_id: String, message: String, entry_point: StringName) -> void:
	_output.append("%s:%s" % [String(entry_point), message])


func _check(value: bool, description: String) -> bool:
	if not value:
		_failures.append(description)
		push_error("[Flujo] FSM 002 assertion: " + description)
	return value
