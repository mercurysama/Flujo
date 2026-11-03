extends Node

## Potok 8D1-C2: two controllers execute two machines against one shared graph.
## The same explicit alias ID is valid in four distinct runtime registries.
var _failures: Array[String] = []


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var script: Script = load("res://tests/fixtures/fsm_sdk_machine_isolation_probe.gd") as Script
	if not _check(script != null and script.can_instantiate(),
			"SDK isolation fixture can instantiate without class_name"):
		get_tree().quit(1)
		return

	var graph: FlowGraph = FlowGraph.new()
	graph.schema_version = FlowGraph.SCHEMA_VERSION_3
	graph.constructor = FlowConstructorDefinition.new()
	var idle_a: FlowStateDefinition = FlowStateDefinition.new()
	idle_a.display_name = "Idle A"
	var template_a: FlowStateDefinition = FlowStateDefinition.new()
	template_a.display_name = "Template A"
	var idle_b: FlowStateDefinition = FlowStateDefinition.new()
	idle_b.display_name = "Idle B"
	var template_b: FlowStateDefinition = FlowStateDefinition.new()
	template_b.display_name = "Template B"
	var machine_a: FlowStateMachineDefinition = FlowStateMachineDefinition.new()
	machine_a.tick_mode = FlowStateMachineDefinition.TickMode.MANUAL
	machine_a.states = [idle_a, template_a]
	machine_a.initial_state_id = idle_a.get_internal_id()
	var machine_b: FlowStateMachineDefinition = FlowStateMachineDefinition.new()
	machine_b.tick_mode = FlowStateMachineDefinition.TickMode.MANUAL
	machine_b.states = [idle_b, template_b]
	machine_b.initial_state_id = idle_b.get_internal_id()
	graph.state_machines = [machine_a, machine_b]

	var a_id: String = machine_a.get_internal_id()
	var b_id: String = machine_b.get_internal_id()
	var same_alias: String = FlowId.create()
	idle_a.enter_blocks = [_probe(script, a_id, template_a.get_internal_id(),
		idle_b.get_internal_id(), template_b.get_internal_id(), same_alias)]
	idle_b.enter_blocks = [_probe(script, b_id, template_b.get_internal_id(),
		idle_a.get_internal_id(), template_a.get_internal_id(), same_alias)]
	if not _check(FlowId.is_valid(same_alias)
		and not FlowGraphValidator.validate(graph).has_errors(),
		"Shared authored graph and explicit dynamic ID are valid"):
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
	var one: FlowFSMRuntime = first.get_fsm_runtime()
	var two: FlowFSMRuntime = second.get_fsm_runtime()
	if not _check(one != null and two != null and one != two
		and one.is_running() and two.is_running(),
		"Both controllers own separate running runtimes for the same graph"):
		first.queue_free()
		second.queue_free()
		get_tree().quit(1)
		return

	var first_records: Array = first.get_meta("potok_8d1c2_observations", [])
	var second_records: Array = second.get_meta("potok_8d1c2_observations", [])
	_check_callbacks(first_records, same_alias, a_id, b_id, "OwnerOne")
	_check_callbacks(second_records, same_alias, a_id, b_id, "OwnerTwo")
	for runtime: FlowFSMRuntime in [one, two]:
		for machine_id: String in [a_id, b_id]:
			_check(runtime.get_dynamic_state_ids(machine_id) == [same_alias],
				"Each controller/machine registry owns exactly the same named alias")
		_check(runtime.pending_request_count() == 0,
			"Foreign-machine SDK attempts never enqueue a transition")
	_check(one.get_active_state_id(a_id) == idle_a.get_internal_id()
		and one.get_active_state_id(b_id) == idle_b.get_internal_id()
		and two.get_active_state_id(a_id) == idle_a.get_internal_id()
		and two.get_active_state_id(b_id) == idle_b.get_internal_id(),
		"All four initial states remain unchanged by rejected SDK cross-operations")

	# The four registries share an alias ID but not mutable data.
	_check(one.get_dynamic_state_data(a_id, same_alias).get("controller") == "OwnerOne"
		and one.get_dynamic_state_data(b_id, same_alias).get("controller") == "OwnerOne"
		and two.get_dynamic_state_data(a_id, same_alias).get("controller") == "OwnerTwo"
		and two.get_dynamic_state_data(b_id, same_alias).get("controller") == "OwnerTwo",
		"SDK data writes are isolated per controller and machine")
	_check(one.set_dynamic_state_data(a_id, same_alias, {"controller": "OneUpdated"}),
		"Direct runtime mutation of only one registry succeeds")
	_check(one.get_dynamic_state_data(b_id, same_alias).get("controller") == "OwnerOne"
		and two.get_dynamic_state_data(a_id, same_alias).get("controller") == "OwnerTwo",
		"Mutation of first/A does not leak to first/B or second/A")

	_check(one.change_state(a_id, same_alias),
		"First controller machine A can independently request its dynamic state")
	one.tick(0.1, FlowStateMachineDefinition.TickMode.MANUAL)
	_check(one.get_active_state_id(a_id) == same_alias
		and one.get_active_state_id(b_id) == idle_b.get_internal_id()
		and two.get_active_state_id(a_id) == idle_a.get_internal_id(),
		"First/A transition does not affect first/B or the second controller")
	_check(two.change_state(b_id, same_alias),
		"Second controller machine B can independently request the same ID")
	two.tick(0.1, FlowStateMachineDefinition.TickMode.MANUAL)
	_check(two.get_active_state_id(b_id) == same_alias
		and two.get_active_state_id(a_id) == idle_a.get_internal_id()
		and one.get_active_state_id(b_id) == idle_b.get_internal_id(),
		"Second/B transition does not affect second/A or first/B")

	_check(one.remove_state(b_id, same_alias),
		"First/B inactive alias can be removed without touching other registries")
	_check(one.get_dynamic_state_ids(b_id).is_empty()
		and one.get_dynamic_state_ids(a_id) == [same_alias]
		and two.get_dynamic_state_ids(b_id) == [same_alias],
		"Alias removal changes only its controller and machine")
	first.visual_program_enabled = false
	_check(not one.is_running() and two.is_running()
		and two.get_active_state_id(b_id) == same_alias
		and two.get_dynamic_state_ids(a_id) == [same_alias],
		"Stopping first controller preserves second controller and its aliases")

	_check(graph.state_machines.size() == 2
		and machine_a.states == [idle_a, template_a]
		and machine_b.states == [idle_b, template_b]
		and not FlowGraphValidator.validate(graph).has_errors(),
		"All runtime operations leave FlowGraph definitions unchanged")
	second.visual_program_enabled = false
	first.queue_free()
	second.queue_free()
	await get_tree().process_frame
	if _failures.is_empty():
		print("[Flujo] Potok 8D1-C2 multi-controller SDK machine isolation passed")
	else:
		for failure: String in _failures:
			push_error("[Flujo] Potok 8D1-C2 assertion: " + failure)
	get_tree().quit(0 if _failures.is_empty() else 1)


func _probe(script: Script, machine_id: String, template_id: String,
		foreign_state_id: String, foreign_template_id: String,
		alias_id: String) -> FlowBlock:
	var probe: FlowBlock = script.new() as FlowBlock
	if probe != null:
		probe.set("own_machine_id", machine_id)
		probe.set("own_template_id", template_id)
		probe.set("foreign_state_id", foreign_state_id)
		probe.set("foreign_template_id", foreign_template_id)
		probe.set("shared_alias_id", alias_id)
	return probe


func _check_callbacks(records: Array, alias_id: String,
		machine_a_id: String, machine_b_id: String, owner_label: String) -> void:
	if not _check(records.size() == 2,
			owner_label + " executes exactly two StateEnter SDK callbacks"):
		return
	var machine_ids: Array[String] = [machine_a_id, machine_b_id]
	for i: int in 2:
		var observed: Dictionary = records[i]
		var operations: FlowFSMOperations = observed.get("facade") as FlowFSMOperations
		var value: String = String(observed.get("alias", ""))
		_check(observed.get("machine_id") == machine_ids[i]
			and observed.get("phase") == "StateEnter"
			and operations != null and value == alias_id,
			owner_label + " machine %d registered its own explicit alias" % i)
		_check(observed.get("owns_state") == true
			and observed.get("wrote_own_data") == true,
			owner_label + " SDK capability can read and update only its own alias")
		_check(observed.get("foreign_template_result") == ""
			and observed.get("foreign_state_visible") == false
			and observed.get("foreign_change_accepted") == false
			and observed.get("foreign_remove_accepted") == false
			and observed.get("foreign_write_accepted") == false
			and (observed.get("foreign_read", {}) as Dictionary).is_empty(),
			owner_label + " facade rejects foreign machine's authored states")
		if operations != null:
			_check(not operations.has_state(alias_id)
				and not operations.set_state_data(alias_id, {"escaped": true})
				and operations.register_state(alias_id) == "",
				owner_label + " retained facade is expired outside callback")


func _check(ok: bool, description: String) -> bool:
	if not ok:
		_failures.append(description)
		push_error("[Flujo] Potok 8D1-C2: " + description)
	return ok
