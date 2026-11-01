extends Node

var _failures: Array[String] = []
var _output: Array[String] = []


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var graph: FlowGraph = FlowGraph.new()
	graph.schema_version = FlowGraph.SCHEMA_VERSION_3
	graph.constructor = FlowConstructorDefinition.new()
	var idle: FlowStateDefinition = FlowStateDefinition.new()
	idle.display_name = "Idle"
	idle.enter_blocks = [_printer("idle-enter")]
	idle.blocks = [_printer("idle-update")]
	idle.exit_blocks = [_printer("idle-exit")]
	var template: FlowStateDefinition = FlowStateDefinition.new()
	template.display_name = "Stunned"
	template.enter_blocks = [_printer("stunned-enter")]
	template.blocks = [_printer("stunned-update")]
	template.exit_blocks = [_printer("stunned-exit")]
	var machine: FlowStateMachineDefinition = FlowStateMachineDefinition.new()
	machine.tick_mode = FlowStateMachineDefinition.TickMode.MANUAL
	machine.states = [idle, template]
	machine.initial_state_id = idle.get_internal_id()
	graph.state_machines = [machine]
	var machine_id: String = machine.get_internal_id()
	var controller: PVController = PVController.new()
	controller.flow_graph = graph
	controller.runtime_output.entry_message_emitted.connect(_record)
	var other: PVController = PVController.new()
	other.flow_graph = graph
	add_child(controller)
	add_child(other)
	await get_tree().process_frame
	var runtime: FlowFSMRuntime = controller.get_fsm_runtime()
	var independent: FlowFSMRuntime = other.get_fsm_runtime()
	if not _check(runtime != null and independent != null, "Controller FSMs start independently"):
		get_tree().quit(1)
		return

	var data: Dictionary = {"intensity": 3, "tags": ["red", "slow"]}
	var alias_id: String = runtime.register_state(
		machine_id, template.get_internal_id(), "",
		FlowFSMDynamicStateRecord.Lifetime.PERSISTENT, data
	)
	_check(FlowId.is_valid(alias_id), "Dynamic alias receives a valid stable runtime ID.")
	_check(runtime.has_state(machine_id, alias_id), "Dynamic state is addressable by runtime ID.")
	_check(not independent.has_state(machine_id, alias_id), "Different controller cannot see alias.")
	_check(machine.states.size() == 2, "Authored state array is immutable.")
	_check(runtime.get_dynamic_state_lifetime(machine_id, alias_id) ==
		FlowFSMDynamicStateRecord.Lifetime.PERSISTENT, "Lifetime is stored per alias.")
	data["intensity"] = 100
	_check(runtime.get_dynamic_state_data(machine_id, alias_id)["intensity"] == 3,
		"Register clones the caller's data.")
	var detached: Dictionary = runtime.get_dynamic_state_data(machine_id, alias_id)
	detached["intensity"] = 99
	_check(runtime.get_dynamic_state_data(machine_id, alias_id)["intensity"] == 3,
		"Reading data returns a detached copy.")
	_check(runtime.set_dynamic_state_data(machine_id, alias_id, {"intensity": 6}),
		"Replacing safe structured data succeeds.")
	_check(runtime.get_dynamic_state_data(machine_id, alias_id)["intensity"] == 6,
		"Replacement is visible.")
	var live_node: Node = Node.new()
	_check(not runtime.set_dynamic_state_data(machine_id, alias_id, {"node": live_node}),
		"Object-valued metadata is rejected.")
	live_node.free()

	_check(runtime.register_state(machine_id, template.get_internal_id(), alias_id) == "",
		"Duplicate alias ID is rejected.")
	_check(runtime.register_state(machine_id, "missing") == "", "Foreign template rejected.")
	_check(runtime.change_state(machine_id, alias_id), "Direct transition to dynamic alias queues.")
	runtime.tick(0.25, FlowStateMachineDefinition.TickMode.MANUAL)
	_check(runtime.get_active_state_id(machine_id) == alias_id, "Dynamic alias becomes active.")
	_check(_output.has("StateEnter:stunned-enter"), "Dynamic alias executes its template Enter.")
	runtime.tick(0.25, FlowStateMachineDefinition.TickMode.MANUAL)
	_check(_output.has("StateUpdate:stunned-update"), "Dynamic alias executes template Update.")
	_check(not runtime.remove_state(machine_id, alias_id), "Active removal without fallback rejects.")
	_check(runtime.remove_state(machine_id, alias_id, idle.get_internal_id()),
		"Active alias removal transitions safely to fallback.")
	_check(runtime.get_active_state_id(machine_id) == idle.get_internal_id(), "Fallback becomes active.")
	_check(not runtime.has_state(machine_id, alias_id), "Removed dynamic ID becomes invalid.")
	_check(_output.has("StateExit:stunned-exit"), "Removal executes source Exit.")
	var temporary: String = runtime.register_state(machine_id, template.get_internal_id())
	_check(runtime.change_state(machine_id, temporary), "Request to inactive alias queues.")
	_check(runtime.remove_state(machine_id, temporary), "Inactive alias can be removed.")
	_check(runtime.pending_request_count() == 0, "Removing an alias purges pending direct requests.")
	_check(not FlowGraphValidator.validate(graph).has_errors(), "Runtime never mutates FlowGraph.")
	controller.visual_program_enabled = false
	_check(runtime.get_dynamic_state_ids(machine_id).is_empty(), "Stop clears dynamic registry.")
	_check(independent.is_running(), "Other controller remains running.")
	other.visual_program_enabled = false
	controller.queue_free()
	other.queue_free()
	await get_tree().process_frame
	if _failures.is_empty():
		print("[Flujo] FSM 003 dynamic states test passed")
	else:
		for failure: String in _failures:
			push_error("[Flujo] FSM 003: " + failure)
	get_tree().quit(0 if _failures.is_empty() else 1)


func _printer(message: String) -> FlowPrintBlock:
	var p: FlowPrintBlock = FlowPrintBlock.new()
	p.text = message
	return p


func _record(_controller: Node, _process_id: String, _block_id: String, message: String, entry_point: StringName) -> void:
	_output.append("%s:%s" % [String(entry_point), message])


func _check(value: bool, description: String) -> bool:
	if not value:
		_failures.append(description)
		push_error("[Flujo] FSM 003 assertion: " + description)
	return value
