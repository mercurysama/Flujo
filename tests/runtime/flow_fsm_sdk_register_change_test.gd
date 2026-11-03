extends Node

## Potok 8D1-C4A: an SDK StateEnter registers a dynamic state, but
## change_state only queues; Exit/Enter commit on the next manual tick.
var _failures: Array[String] = []
var _trace: Array[String] = []


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var sdk_script: Script = load("res://tests/fixtures/fsm_sdk_register_and_change_probe.gd") as Script
	if not _check(sdk_script != null and sdk_script.can_instantiate(),
			"SDK-style FlowBlock fixture instantiates without global class_name"):
		get_tree().quit(1)
		return

	var graph: FlowGraph = FlowGraph.new()
	graph.schema_version = FlowGraph.SCHEMA_VERSION_3
	graph.constructor = FlowConstructorDefinition.new()
	var idle: FlowStateDefinition = FlowStateDefinition.new()
	idle.display_name = "Idle"
	var template: FlowStateDefinition = FlowStateDefinition.new()
	template.display_name = "DynamicTemplate"
	idle.enter_blocks = [_probe(sdk_script, template.get_internal_id()),
		_printer("idle-enter-continued")]
	idle.blocks = [_printer("idle-update")]
	idle.exit_blocks = [_printer("idle-exit")]
	template.enter_blocks = [_printer("template-enter")]
	template.blocks = [_printer("template-update")]
	var machine: FlowStateMachineDefinition = FlowStateMachineDefinition.new()
	machine.tick_mode = FlowStateMachineDefinition.TickMode.MANUAL
	machine.states = [idle, template]
	machine.initial_state_id = idle.get_internal_id()
	graph.state_machines = [machine]
	if not _check(not FlowGraphValidator.validate(graph).has_errors(),
			"Authored schema 3 graph validates before SDK execution"):
		get_tree().quit(1)
		return

	var controller: PVController = PVController.new()
	controller.flow_graph = graph
	controller.runtime_output.entry_message_emitted.connect(_on_output)
	add_child(controller)
	await get_tree().process_frame

	var runtime: FlowFSMRuntime = controller.get_fsm_runtime()
	if not _check(runtime != null and runtime.is_running(),
			"Controller starts a real running FSM"):
		controller.queue_free()
		get_tree().quit(1)
		return
	runtime.transition_committed.connect(_on_transition_committed)
	var machine_id: String = machine.get_internal_id()
	var records: Array = controller.get_meta("potok_8d1c4a_records", [])
	if not _check(records.size() == 1,
			"Initial StateEnter SDK block executes exactly once"):
		controller.visual_program_enabled = false
		controller.queue_free()
		get_tree().quit(1)
		return
	var record: Dictionary = records[0]
	var alias: String = String(record.get("alias", ""))
	var operations: FlowFSMOperations = record.get("facade") as FlowFSMOperations
	if not _check(FlowId.is_valid(alias),
			"SDK registers a valid unique runtime ID from the authorized template"):
		controller.visual_program_enabled = false
		controller.queue_free()
		get_tree().quit(1)
		return

	_check(record.get("phase") == "StateEnter" and record.get("resolved") == true
		and record.get("queued") == true,
		"SDK reads its new alias and successfully requests its activation")
	_check(record.get("data") == {"source": "SDK", "nested": {"level": 4}},
		"Registration exposes the expected detached structured metadata")
	_check(runtime.has_state(machine_id, alias)
		and runtime.get_dynamic_state_ids(machine_id) == [alias]
		and runtime.get_dynamic_state_lifetime(machine_id, alias) ==
			FlowFSMDynamicStateRecord.Lifetime.SESSION,
		"New alias is present only in the per-machine dynamic registry")
	_check(runtime.get_dynamic_state_data(machine_id, alias) ==
		{"source": "SDK", "nested": {"level": 4}},
		"Runtime stores SDK-supplied metadata without writing authored state")
	_check(runtime.get_active_state_id(machine_id) == idle.get_internal_id()
		and runtime.pending_request_count() == 1,
		"Register and change_state do not reenter: transition remains queued")
	_check(_trace == ["StateEnter:idle-enter-continued"],
		"Executor finishes the initial StateEnter block sequence before transition")

	if operations != null:
		_check(not operations.has_state(alias)
			and not operations.change_state(alias)
			and operations.register_state(template.get_internal_id()) == "",
			"Escaped SDK facade expires after the StateEnter callback")
	_check(runtime.pending_request_count() == 1,
		"Stale SDK calls never add extra requests")

	runtime.tick(0.1, FlowStateMachineDefinition.TickMode.MANUAL)
	_check(runtime.get_active_state_id(machine_id) == alias,
		"First matching tick commits the queued dynamic-state change")
	_check(runtime.pending_request_count() == 0,
		"Committed change consumes the one queued request")
	_check(_trace == [
		"StateEnter:idle-enter-continued",
		"StateUpdate:idle-update",
		"StateExit:idle-exit",
		"StateEnter:template-enter",
		"Commit:direct"
	], "Tick executes original Update, Exit, template Enter and one commit in order")
	_check(controller.get_meta("potok_8d1c4a_records", []).size() == 1,
		"Dynamic template Enter never repeats the registering SDK callback")
	runtime.tick(0.1, FlowStateMachineDefinition.TickMode.MANUAL)
	_check(_trace.size() == 6 and _trace[5] == "StateUpdate:template-update",
		"Dynamic alias receives template Update only on a later tick")
	_check(machine.states.size() == 2 and machine.states[0] == idle
		and machine.states[1] == template
		and not FlowGraphValidator.validate(graph).has_errors(),
		"SDK registration and activation leave authored FlowGraph immutable")

	controller.visual_program_enabled = false
	controller.queue_free()
	await get_tree().process_frame
	if _failures.is_empty():
		print("[Flujo] Potok 8D1-C4A SDK queued dynamic activation passed")
	else:
		for failure: String in _failures:
			push_error("[Flujo] Potok 8D1-C4A: " + failure)
	get_tree().quit(0 if _failures.is_empty() else 1)


func _probe(script: Script, template_id: String) -> FlowBlock:
	var block: FlowBlock = script.new() as FlowBlock
	if block != null:
		block.set("template_state_id", template_id)
	return block


func _printer(message: String) -> FlowPrintBlock:
	var block: FlowPrintBlock = FlowPrintBlock.new()
	block.text = message
	return block


func _on_output(_controller: Node, _container_id: String, _block_id: String,
		message: String, phase: StringName) -> void:
	_trace.append(String(phase) + ":" + message)


func _on_transition_committed(_machine_id: String, _from_state: String,
		_to_state: String, trigger: String) -> void:
	_trace.append("Commit:" + trigger)


func _check(ok: bool, description: String) -> bool:
	if not ok:
		_failures.append(description)
		push_error("[Flujo] Potok 8D1-C4A: " + description)
	return ok
