extends Node

## Potok 8D1-C1A: retained SDK facade is invalid after StateEnter returns.
## This characterizes existing production behavior; no runtime change assumed.
var _failures: Array[String] = []


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var probe_script: Script = load(
		"res://tests/fixtures/fsm_sdk_retained_operations_probe.gd"
	) as Script
	if not _check(probe_script != null and probe_script.can_instantiate(),
			"SDK-style fixture instantiates without global class_name"):
		get_tree().quit(1)
		return

	var graph: FlowGraph = FlowGraph.new()
	graph.schema_version = FlowGraph.SCHEMA_VERSION_3
	graph.constructor = FlowConstructorDefinition.new()
	var idle: FlowStateDefinition = FlowStateDefinition.new()
	idle.display_name = "Idle"
	var template: FlowStateDefinition = FlowStateDefinition.new()
	template.display_name = "Template"
	var machine: FlowStateMachineDefinition = FlowStateMachineDefinition.new()
	machine.tick_mode = FlowStateMachineDefinition.TickMode.MANUAL
	machine.states = [idle, template]
	machine.initial_state_id = idle.get_internal_id()
	graph.state_machines = [machine]

	var probe: FlowBlock = probe_script.new() as FlowBlock
	if not _check(probe != null, "Fixture creates a FlowBlock"):
		get_tree().quit(1)
		return
	probe.set("template_state_id", template.get_internal_id())
	idle.enter_blocks = [probe]

	var controller: PVController = PVController.new()
	controller.flow_graph = graph
	add_child(controller)
	await get_tree().process_frame
	var runtime: FlowFSMRuntime = controller.get_fsm_runtime()
	if not _check(runtime != null and runtime.is_running(),
			"PVController starts the real FSM runtime"):
		controller.queue_free()
		get_tree().quit(1)
		return

	var machine_id: String = machine.get_internal_id()
	var captured: Array = controller.get_meta("potok_8d1c1_records", [])
	if not _check(captured.size() == 1,
			"StateEnter executes one SDK callback and captures its facade"):
		controller.visual_program_enabled = false
		controller.queue_free()
		get_tree().quit(1)
		return
	var record: Dictionary = captured[0]
	var operations: FlowFSMOperations = record.get("operations") as FlowFSMOperations
	var alias: String = String(record.get("created_id", ""))
	_check(record.get("phase") == "StateEnter", "Captured facade belongs to StateEnter")
	if not _check(operations != null and FlowId.is_valid(alias),
			"Facade can register a dynamic alias while the SDK callback is active"):
		controller.visual_program_enabled = false
		controller.queue_free()
		get_tree().quit(1)
		return
	_check(runtime.has_state(machine_id, alias),
		"Callback-created alias exists in the runtime after the callback")
	_check(runtime.get_dynamic_state_ids(machine_id) == [alias],
		"Exactly one callback-created alias exists in the local registry")

	var baseline_data: Dictionary = runtime.get_dynamic_state_data(machine_id, alias)
	var baseline_pending: int = runtime.pending_request_count()
	var baseline_active: String = runtime.get_active_state_id(machine_id)

	_check(operations.register_state(template.get_internal_id()) == "",
		"Expired facade rejects registration")
	_check(not operations.has_state(alias),
		"Expired facade does not expose previously registered state")
	_check(not operations.change_state(alias),
		"Expired facade cannot queue a transition")
	_check(not operations.remove_state(alias, idle.get_internal_id()),
		"Expired facade cannot remove an alias")
	_check(operations.get_state_data(alias).is_empty(),
		"Expired facade cannot read a prior callback's state data")
	_check(not operations.set_state_data(alias, {"origin": "after_callback"}),
		"Expired facade cannot mutate data after callback return")
	_check(runtime.get_dynamic_state_ids(machine_id) == [alias]
		and runtime.get_dynamic_state_data(machine_id, alias) == baseline_data
		and runtime.pending_request_count() == baseline_pending
		and runtime.get_active_state_id(machine_id) == baseline_active,
		"All rejected stale calls leave runtime identity, data and requests unchanged")
	_check(machine.states.size() == 2
		and machine.states[0] == idle and machine.states[1] == template
		and not FlowGraphValidator.validate(graph).has_errors(),
		"Expired facade never mutates the authored FlowGraph")

	controller.visual_program_enabled = false
	controller.queue_free()
	await get_tree().process_frame
	if _failures.is_empty():
		print("[Flujo] Potok 8D1-C1A retained facade expiration passed")
	else:
		for failure: String in _failures:
			push_error("[Flujo] Potok 8D1-C1A assertion: " + failure)
	get_tree().quit(0 if _failures.is_empty() else 1)


func _check(ok: bool, description: String) -> bool:
	if not ok:
		_failures.append(description)
		push_error("[Flujo] Potok 8D1-C1A: " + description)
	return ok
