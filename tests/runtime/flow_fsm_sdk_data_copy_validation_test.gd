extends Node

## Potok 8D1-C4B: real SDK callback data must be detached and validated.
## Two PVController instances share a read-only FlowGraph but own their data.
var _failures: Array[String] = []


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var script: Script = load("res://tests/fixtures/fsm_sdk_data_copy_validation_probe.gd") as Script
	if not _check(script != null and script.can_instantiate(),
			"External-style SDK fixture loads without a global class_name"):
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
	var probe: FlowBlock = script.new() as FlowBlock
	if not _check(probe != null, "External block instantiates"):
		get_tree().quit(1)
		return
	probe.set("template_state_id", template.get_internal_id())
	idle.enter_blocks = [probe]
	if not _check(not FlowGraphValidator.validate(graph).has_errors(),
			"Shared schema 3 FlowGraph validates before SDK callbacks"):
		get_tree().quit(1)
		return

	var first: PVController = PVController.new()
	first.name = "OwnerOne"
	first.flow_graph = graph
	var second: PVController = PVController.new()
	second.name = "OwnerTwo"
	second.flow_graph = graph
	add_child(first)
	add_child(second)
	await get_tree().process_frame
	var runtime_one: FlowFSMRuntime = first.get_fsm_runtime()
	var runtime_two: FlowFSMRuntime = second.get_fsm_runtime()
	if not _check(runtime_one != null and runtime_two != null
			and runtime_one != runtime_two
			and runtime_one.is_running() and runtime_two.is_running(),
			"Two controllers own distinct running FSM instances"):
		first.queue_free()
		second.queue_free()
		get_tree().quit(1)
		return
	var machine_id: String = machine.get_internal_id()
	var alias_one: String = _verify_owner(first, runtime_one, machine_id)
	var alias_two: String = _verify_owner(second, runtime_two, machine_id)

	_check(FlowId.is_valid(alias_one) and FlowId.is_valid(alias_two)
		and alias_one != alias_two,
		"Each SDK callback owns a unique dynamic alias")
	_check(runtime_one.get_dynamic_state_ids(machine_id) == [alias_one]
		and runtime_two.get_dynamic_state_ids(machine_id) == [alias_two],
		"Rejected registrations cannot add aliases to either controller")
	_check(runtime_one.get_dynamic_state_data(machine_id, alias_one) ==
		{"outer": {"inner": [1, 2, 3]}, "owner": "OwnerOne"}
		and runtime_two.get_dynamic_state_data(machine_id, alias_two) ==
			{"outer": {"inner": [1, 2, 3]}, "owner": "OwnerTwo"},
		"Data remains independently stored in each controller runtime")
	_check(runtime_one.pending_request_count() == 0
		and runtime_two.pending_request_count() == 0
		and runtime_one.get_active_state_id(machine_id) == idle.get_internal_id()
		and runtime_two.get_active_state_id(machine_id) == idle.get_internal_id(),
		"Invalid SDK data operations do not enqueue or change active states")
	_check(machine.states == [idle, template] and idle.enter_blocks == [probe]
		and not FlowGraphValidator.validate(graph).has_errors(),
		"SDK mutations never modify authored FlowGraph")

	first.visual_program_enabled = false
	second.visual_program_enabled = false
	first.queue_free()
	second.queue_free()
	await get_tree().process_frame
	if _failures.is_empty():
		print("[Flujo] Potok 8D1-C4B SDK deep copy and invalid data rejection passed")
	else:
		for failure: String in _failures:
			push_error("[Flujo] Potok 8D1-C4B: " + failure)
	get_tree().quit(0 if _failures.is_empty() else 1)


func _verify_owner(owner: PVController, runtime: FlowFSMRuntime, machine_id: String) -> String:
	var records: Array = owner.get_meta("potok_8d1c4b_records", [])
	if not _check(records.size() == 1,
			owner.name + " invokes exactly one StateEnter SDK callback"):
		return ""
	var record: Dictionary = records[0]
	var operations: FlowFSMOperations = record.get("facade") as FlowFSMOperations
	var alias: String = String(record.get("alias", ""))
	_check(record.get("phase") == "StateEnter"
		and FlowId.is_valid(alias) and record.get("registered") == true,
		owner.name + " SDK callback registers one valid SESSION alias")
	for key: String in [
		"registration_detached", "read_detached", "set_accepted",
		"set_detached", "second_read_detached"
	]:
		_check(record.get(key) == true,
			owner.name + " SDK satisfies copy/replace contract: " + key)
	var invalid_results: Array = record.get("invalid", [])
	_check(invalid_results.size() == 8,
		owner.name + " exercises eight distinct invalid payload categories")
	for i: int in invalid_results.size():
		var result: Dictionary = invalid_results[i]
		_check(result.get("index") == i
			and result.get("registration_rejected") == true
			and result.get("write_rejected") == true
			and result.get("data_unchanged") == true,
			owner.name + " rejects invalid registration/update %d without mutation" % i)
	var expected: Dictionary = {
		"outer": {"inner": [1, 2, 3]},
		"owner": String(owner.name)
	}
	_check(record.get("final_data") == expected
		and runtime.get_dynamic_state_data(machine_id, alias) == expected,
		owner.name + " retains exactly the last accepted deep-copied data")
	_check(runtime.get_dynamic_state_lifetime(machine_id, alias) ==
		FlowFSMDynamicStateRecord.Lifetime.SESSION,
		owner.name + " stores the intended SESSION lifetime")
	if operations != null:
		_check(operations.get_state_data(alias).is_empty()
			and not operations.set_state_data(alias, {"stale": true})
			and operations.register_state(alias) == "",
			owner.name + " SDK facade expires after its callback")
	return alias


func _check(ok: bool, description: String) -> bool:
	if not ok:
		_failures.append(description)
		push_error("[Flujo] Potok 8D1-C4B: " + description)
	return ok
