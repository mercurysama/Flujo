extends Node

## FSM-4B: lifecycle edge cases are independent of the basic FSM-001 scene.
var failures: Array[String] = []
var messages: Array[String] = []
var signals: Array[String] = []


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var graph: FlowGraph = FlowGraph.new()
	graph.schema_version = FlowGraph.SCHEMA_VERSION_3
	graph.constructor = FlowConstructorDefinition.new()
	var state: FlowStateDefinition = FlowStateDefinition.new()
	state.enter_blocks = [_block("enter")]
	state.blocks = [_block("update")]
	state.exit_blocks = [_block("exit")]
	var machine: FlowStateMachineDefinition = FlowStateMachineDefinition.new()
	machine.tick_mode = FlowStateMachineDefinition.TickMode.MANUAL
	machine.states = [state]
	machine.initial_state_id = state.get_internal_id()
	graph.state_machines = [machine]
	var machine_id: String = machine.get_internal_id()

	var controller: PVController = PVController.new()
	controller.flow_graph = graph
	controller.runtime_output.entry_message_emitted.connect(_record_message)
	add_child(controller)
	await get_tree().process_frame
	var runtime: FlowFSMRuntime = controller.get_fsm_runtime()
	if not _check(runtime != null and runtime.is_running(), "FSM can start"):
		_finish()
		return
	runtime.machine_started.connect(_record_machine_start)
	runtime.state_entered.connect(_record_enter)
	runtime.state_updated.connect(_record_update)
	runtime.state_exited.connect(_record_exit)
	runtime.machine_stopped.connect(_record_machine_stop)

	_check(messages == ["StateEnter:enter"], "Enter occurs only on start.")
	for i: int in 3:
		runtime.tick(0.125, FlowStateMachineDefinition.TickMode.MANUAL)
	_check(messages == [
		"StateEnter:enter", "StateUpdate:update", "StateUpdate:update", "StateUpdate:update"
	], "Single state without transitions stays active through repeated updates.")
	_check(runtime.get_active_state_id(machine_id) == state.get_internal_id(), "Active state stays stable.")
	_check(signals == ["update", "update", "update"], "Every manual tick emits exactly one Update signal.")
	_check(is_equal_approx(runtime.last_delta, 0.125), "Delta is visible to observers.")
	_check(runtime.reset(), "Reset is allowed outside a tick.")
	_check(messages.slice(-2) == ["StateExit:exit", "StateEnter:enter"],
		"Reset calls Exit then Enter in order.")
	_check(signals.slice(-2) == ["exit", "enter"], "Reset emits ordered signals.")
	runtime.tick(0.5, FlowStateMachineDefinition.TickMode.MANUAL)
	_check(messages.back() == "StateUpdate:update", "Reset FSM continues updating.")

	controller.visual_program_enabled = false
	_check(controller.get_fsm_runtime() == null, "Disabling detaches runtime.")
	_check(not runtime.is_running(), "Disabling stops prior runtime.")
	_check(messages.back() == "StateExit:exit", "Disabling executes Exit.")
	var before: int = messages.size()
	runtime.stop()
	_check(messages.size() == before, "Stop is idempotent after disable.")
	controller.visual_program_enabled = true
	var next_runtime: FlowFSMRuntime = controller.get_fsm_runtime()
	_check(next_runtime != null and next_runtime != runtime and next_runtime.is_running(),
		"Enabling starts a fresh independent FSM instance.")
	_check(messages.back() == "StateEnter:enter", "Re-enable executes exactly one new Enter.")
	var before_exit: int = messages.count("StateExit:exit")
	controller.queue_free()
	await get_tree().process_frame
	_check(messages.count("StateExit:exit") == before_exit + 1,
		"Scene-tree teardown executes a final Exit exactly once.")
	_finish()


func _block(message: String) -> FlowPrintBlock:
	var block: FlowPrintBlock = FlowPrintBlock.new()
	block.text = message
	return block


func _record_message(_controller: Node, _container_id: String, _block_id: String, text: String,
		entry_point: StringName) -> void:
	messages.append("%s:%s" % [String(entry_point), text])


func _record_machine_start(_machine_id: String, _state_id: String) -> void:
	signals.append("started")


func _record_enter(_machine_id: String, _state_id: String) -> void:
	signals.append("enter")


func _record_update(_machine_id: String, _state_id: String) -> void:
	signals.append("update")


func _record_exit(_machine_id: String, _state_id: String) -> void:
	signals.append("exit")


func _record_machine_stop(_machine_id: String, _state_id: String) -> void:
	signals.append("stopped")


func _check(ok: bool, reason: String) -> bool:
	if not ok:
		failures.append(reason)
		push_error("[Flujo] FSM-4B: " + reason)
	return ok


func _finish() -> void:
	if failures.is_empty():
		print("[Flujo] FSM-4B lifecycle test passed")
	get_tree().quit(0 if failures.is_empty() else 1)
