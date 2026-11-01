extends Node

var _failures: Array[String] = []
var _events: Array[String] = []


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var graph: FlowGraph = FlowGraph.new()
	graph.schema_version = FlowGraph.SCHEMA_VERSION_3
	graph.constructor = FlowConstructorDefinition.new()
	var state: FlowStateDefinition = FlowStateDefinition.new()
	state.display_name = "Idle"
	state.enter_blocks = [_print_block("enter")]
	state.blocks = [_print_block("update")]
	state.exit_blocks = [_print_block("exit")]
	var machine: FlowStateMachineDefinition = FlowStateMachineDefinition.new()
	machine.display_name = "One state"
	machine.tick_mode = FlowStateMachineDefinition.TickMode.MANUAL
	machine.states = [state]
	machine.initial_state_id = state.get_internal_id()
	graph.state_machines = [machine]
	_check(not FlowGraphValidator.validate(graph).has_errors(), "One-state FSM is valid.")

	var duplicate: FlowGraph = graph.duplicate_with_new_ids()
	_check(duplicate != null and duplicate.state_machines.size() == 1, "Graph duplication succeeds.")
	if duplicate != null and duplicate.state_machines.size() == 1:
		var copy_machine: FlowStateMachineDefinition = duplicate.state_machines[0]
		var copy_state: FlowStateDefinition = copy_machine.states[0]
		_check(copy_machine.initial_state_id == copy_state.get_internal_id(), "Initial ID remaps.")
		_check(copy_state.enter_blocks.size() == 1 and copy_state.exit_blocks.size() == 1, "Phase blocks duplicate.")
		_check(copy_state.enter_blocks[0].get_internal_id() != state.enter_blocks[0].get_internal_id(), "Enter block ID renews.")
		_check(copy_state.exit_blocks[0].get_internal_id() != state.exit_blocks[0].get_internal_id(), "Exit block ID renews.")
		_check(not FlowGraphValidator.validate(duplicate).has_errors(), "Duplicated phases validate.")

	var a: PVController = PVController.new()
	a.flow_graph = graph
	a.runtime_output.entry_message_emitted.connect(_record)
	add_child(a)
	await get_tree().process_frame
	var ar: FlowFSMRuntime = a.get_fsm_runtime()
	_check(ar != null and ar.is_running(), "PVController starts its FSM.")
	if ar != null:
		_check(ar.get_active_state_id(machine.get_internal_id()) == state.get_internal_id(), "Initial state is active.")
		_check(_events == ["StateEnter:enter"], "Enter runs exactly once.")
		ar.tick(0.25, FlowStateMachineDefinition.TickMode.MANUAL)
		_check(_events == ["StateEnter:enter", "StateUpdate:update"], "Manual tick executes Update exactly once.")
		_check(is_equal_approx(ar.last_delta, 0.25), "Tick preserves delta.")

	var b: PVController = PVController.new()
	b.flow_graph = graph
	b.runtime_output.entry_message_emitted.connect(_record)
	add_child(b)
	await get_tree().process_frame
	var br: FlowFSMRuntime = b.get_fsm_runtime()
	_check(br != null and br != ar, "Controllers own independent FSM runtimes.")
	if br != null:
		_check(br.get_active_state_id(machine.get_internal_id()) == state.get_internal_id(), "Second instance starts independently.")

	a.visual_program_enabled = false
	_check(ar == null or not ar.is_running(), "Disabling controller stops its FSM.")
	_check(_events.count("StateExit:exit") == 1, "Exit runs once on stop.")
	if br != null:
		_check(br.is_running(), "Second instance remains active after first stops.")
		br.tick(0.5, FlowStateMachineDefinition.TickMode.MANUAL)
	b.visual_program_enabled = false
	_check(_events.count("StateExit:exit") == 2, "Each instance exits exactly once.")

	a.queue_free()
	b.queue_free()
	await get_tree().process_frame
	if _failures.is_empty():
		print("[Flujo] FSM 001 runtime test passed")
	else:
		for failure: String in _failures:
			push_error("[Flujo] FSM 001 failed: " + failure)
	get_tree().quit(0 if _failures.is_empty() else 1)


func _print_block(value: String) -> FlowPrintBlock:
	var block: FlowPrintBlock = FlowPrintBlock.new()
	block.text = value
	return block


func _record(
		_controller: Node,
		_container_id: String,
		_block_id: String,
		message: String,
		entry_point: StringName
) -> void:
	_events.append("%s:%s" % [String(entry_point), message])


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
		push_error("[Flujo] FSM 001 assertion: " + message)
