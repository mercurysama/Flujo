extends Node

## FSM-5B — typed conditions, self transitions and invalid authoring.
var _failures: Array[String] = []
var _output: Array[String] = []
var _commits: Array[String] = []


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	await _test_conditions_and_self()
	await _test_invalid_condition_rejection()
	if _failures.is_empty():
		print("[Flujo] FSM-5B conditions and self-transition test passed")
	get_tree().quit(0 if _failures.is_empty() else 1)


func _test_conditions_and_self() -> void:
	var graph: FlowGraph = _graph()
	var idle: FlowStateDefinition = _state("Idle")
	var busy: FlowStateDefinition = _state("Busy")
	var false_edge: FlowStateTransitionDefinition = _condition(idle.get_internal_id(), false, 100)
	var self_edge: FlowStateTransitionDefinition = _condition(idle.get_internal_id(), true, 90)
	var true_edge: FlowStateTransitionDefinition = _condition(busy.get_internal_id(), true, 10)
	# Self edges are legal authored data but cannot execute Exit/Enter.
	idle.transitions = [false_edge, self_edge, true_edge]
	var machine: FlowStateMachineDefinition = _machine([idle, busy], idle.get_internal_id())
	graph.state_machines = [machine]
	_check(not FlowGraphValidator.validate(graph).has_errors(),
		"Boolean conditions and same-state edges are structurally valid.")

	var controller: PVController = PVController.new()
	controller.flow_graph = graph
	controller.runtime_output.entry_message_emitted.connect(_record)
	add_child(controller)
	await get_tree().process_frame
	var runtime: FlowFSMRuntime = controller.get_fsm_runtime()
	if not _check(runtime != null and runtime.is_running(), "Condition graph starts."):
		controller.queue_free()
		await get_tree().process_frame
		return
	runtime.transition_committed.connect(_on_commit)
	var machine_id: String = machine.get_internal_id()
	_check(runtime.get_active_state_id(machine_id) == idle.get_internal_id(), "Idle starts active.")
	runtime.tick(0.1, FlowStateMachineDefinition.TickMode.MANUAL)
	_check(runtime.get_active_state_id(machine_id) == busy.get_internal_id(),
		"False condition and true self edge do not prevent a valid true target.")
	_check(_output.slice(-3) == ["StateUpdate:Idle", "StateExit:Idle", "StateEnter:Busy"],
		"A valid boolean transition runs Update then Exit then Enter.")
	_check(_commits.size() == 1, "One transition is committed on the first tick.")
	_check(_output.count("StateUpdate:Busy") == 0,
		"Destination Update is deferred until next tick.")
	runtime.tick(0.1, FlowStateMachineDefinition.TickMode.MANUAL)
	_check(_output.back() == "StateUpdate:Busy", "Destination updates on following tick.")
	var prior: int = _output.size()
	_check(runtime.request_transition(machine_id, busy.get_internal_id()),
		"Explicit request targeting active state can queue as no-op.")
	runtime.tick(0.1, FlowStateMachineDefinition.TickMode.MANUAL)
	_check(runtime.get_active_state_id(machine_id) == busy.get_internal_id(),
		"Self request does not change active ID.")
	_check(_commits.size() == 1 and _output.size() == prior + 1,
		"Self request does not emit transition or repeat Enter/Exit.")
	_check(runtime.pending_request_count() == 0, "Self request is consumed.")
	controller.visual_program_enabled = false
	controller.queue_free()
	await get_tree().process_frame


func _test_invalid_condition_rejection() -> void:
	var graph: FlowGraph = _graph()
	var idle: FlowStateDefinition = _state("InvalidIdle")
	var busy: FlowStateDefinition = _state("InvalidBusy")
	var invalid: FlowStateTransitionDefinition = FlowStateTransitionDefinition.new()
	invalid.target_state_id = busy.get_internal_id()
	invalid.condition = FlowLiteralValueSource.new(Variant.Type.TYPE_INT, 1)
	idle.transitions = [invalid]
	var machine: FlowStateMachineDefinition = _machine([idle, busy], idle.get_internal_id())
	graph.state_machines = [machine]
	var validation: FlowValidationResult = FlowGraphValidator.validate(graph)
	_check(validation.has_errors(), "Non-boolean condition is rejected by validator.")
	var saw_type_error: bool = false
	for diagnostic: FlowDiagnostic in validation.diagnostics:
		if diagnostic.code == FlowDiagnostic.CODE_FSM_CONDITION_INVALID:
			saw_type_error = true
	_check(saw_type_error, "Validator returns specific FSM condition diagnostic.")
	var controller: PVController = PVController.new()
	controller.flow_graph = graph
	add_child(controller)
	await get_tree().process_frame
	_check(controller.get_fsm_runtime() == null,
		"Controller never starts a machine with an invalid condition.")
	controller.queue_free()
	await get_tree().process_frame

	# Missing condition receives the same deterministic validation contract.
	invalid.condition = null
	validation = FlowGraphValidator.validate(graph)
	saw_type_error = false
	for diagnostic: FlowDiagnostic in validation.diagnostics:
		if diagnostic.code == FlowDiagnostic.CODE_FSM_CONDITION_INVALID:
			saw_type_error = true
	_check(saw_type_error, "Missing condition is reported without executing.")


func _graph() -> FlowGraph:
	var graph: FlowGraph = FlowGraph.new()
	graph.schema_version = FlowGraph.SCHEMA_VERSION_3
	graph.constructor = FlowConstructorDefinition.new()
	return graph


func _machine(states: Array[FlowStateDefinition], first_id: String) -> FlowStateMachineDefinition:
	var machine: FlowStateMachineDefinition = FlowStateMachineDefinition.new()
	machine.states = states
	machine.initial_state_id = first_id
	machine.tick_mode = FlowStateMachineDefinition.TickMode.MANUAL
	return machine


func _state(label: String) -> FlowStateDefinition:
	var state: FlowStateDefinition = FlowStateDefinition.new()
	state.display_name = label
	var enter: FlowPrintBlock = FlowPrintBlock.new()
	enter.text = label
	var update: FlowPrintBlock = FlowPrintBlock.new()
	update.text = label
	var exit: FlowPrintBlock = FlowPrintBlock.new()
	exit.text = label
	state.enter_blocks = [enter]
	state.blocks = [update]
	state.exit_blocks = [exit]
	return state


func _condition(target_id: String, value: bool, priority: int) -> FlowStateTransitionDefinition:
	var edge: FlowStateTransitionDefinition = FlowStateTransitionDefinition.new()
	edge.target_state_id = target_id
	edge.trigger = FlowStateTransitionDefinition.Trigger.CONDITION
	edge.condition = FlowLiteralValueSource.new(Variant.Type.TYPE_BOOL, value)
	edge.priority = priority
	return edge


func _record(_controller: Node, _container_id: String, _block_id: String,
		message: String, phase: StringName) -> void:
	_output.append("%s:%s" % [String(phase), message])


func _on_commit(_machine_id: String, from_id: String, to_id: String, _trigger_id: String) -> void:
	_commits.append(from_id + ":" + to_id)


func _check(ok: bool, description: String) -> bool:
	if not ok:
		_failures.append(description)
		push_error("[Flujo] FSM-5B: " + description)
	return ok
