extends Node

## Potok 8D1-C4C1: actual StateUpdate SDK callback removes only its
## inactive target, preserving a sibling machine command and a surviving alias.
var _failures: Array[String] = []
var _commits: Array[String] = []


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var sdk: Script = load("res://tests/fixtures/fsm_sdk_selective_removal_probe.gd") as Script
	if not _check(sdk != null and sdk.can_instantiate(),
			"SDK removal fixture can instantiate without class_name"):
		get_tree().quit(1)
		return

	var graph: FlowGraph = FlowGraph.new()
	graph.schema_version = FlowGraph.SCHEMA_VERSION_3
	graph.constructor = FlowConstructorDefinition.new()
	var idle_b: FlowStateDefinition = FlowStateDefinition.new()
	idle_b.display_name = "SiblingIdle"
	var target_b: FlowStateDefinition = FlowStateDefinition.new()
	target_b.display_name = "SiblingTarget"
	var idle_a: FlowStateDefinition = FlowStateDefinition.new()
	idle_a.display_name = "MainIdle"
	var template_a: FlowStateDefinition = FlowStateDefinition.new()
	template_a.display_name = "MainTemplate"
	var sibling: FlowStateMachineDefinition = FlowStateMachineDefinition.new()
	sibling.tick_mode = FlowStateMachineDefinition.TickMode.MANUAL
	sibling.states = [idle_b, target_b]
	sibling.initial_state_id = idle_b.get_internal_id()
	var main: FlowStateMachineDefinition = FlowStateMachineDefinition.new()
	main.tick_mode = FlowStateMachineDefinition.TickMode.MANUAL
	main.states = [idle_a, template_a]
	main.initial_state_id = idle_a.get_internal_id()
	# Sibling executes first and queues before the main SDK removal callback.
	graph.state_machines = [sibling, main]
	idle_b.blocks = [_probe(sdk, "sibling", "", target_b.get_internal_id())]
	idle_a.blocks = [_probe(sdk, "remove", template_a.get_internal_id(), "")]
	if not _check(not FlowGraphValidator.validate(graph).has_errors(),
			"Schema 3 two-machine authored graph validates"):
		get_tree().quit(1)
		return

	var controller: PVController = PVController.new()
	controller.flow_graph = graph
	add_child(controller)
	await get_tree().process_frame
	var runtime: FlowFSMRuntime = controller.get_fsm_runtime()
	if not _check(runtime != null and runtime.is_running(),
			"Real controller starts both manual state machines"):
		controller.queue_free()
		get_tree().quit(1)
		return
	var main_id: String = main.get_internal_id()
	var sibling_id: String = sibling.get_internal_id()
	runtime.transition_committed.connect(_on_commit)
	_check(runtime.pending_request_count() == 0,
		"Startup contains no pending direct transitions")
	runtime.tick(0.1, FlowStateMachineDefinition.TickMode.MANUAL)
	var records: Array = controller.get_meta("potok_8d1c4c1_records", [])
	if not _check(records.size() == 2,
			"First tick invokes sibling then main StateUpdate SDK callbacks exactly once"):
		controller.visual_program_enabled = false
		controller.queue_free()
		get_tree().quit(1)
		return
	var sibling_result: Dictionary = records[0]
	var result: Dictionary = records[1]
	_check(sibling_result.get("phase") == "StateUpdate"
		and sibling_result.get("role") == "sibling"
		and sibling_result.get("queued_sibling") == true,
		"Sibling SDK queues its authored target before main callback")
	_check(result.get("phase") == "StateUpdate" and result.get("role") == "remove",
		"Main SDK removal executes in a real StateUpdate callback")
	var retired: String = String(result.get("retired", ""))
	var survivor: String = String(result.get("survivor", ""))
	_check(FlowId.is_valid(retired) and FlowId.is_valid(survivor)
		and retired != survivor, "Two distinct dynamic aliases were registered")
	for key: String in ["first_retired_queued", "second_retired_queued",
		"survivor_queued", "removed", "retired_absent", "retired_data_empty",
		"retired_change_rejected", "double_remove_rejected", "survivor_present"]:
		_check(result.get(key) == true, "SDK operation contract holds for " + key)
	_check(runtime.get_dynamic_state_ids(main_id) == [survivor]
		and runtime.get_dynamic_state_data(main_id, survivor) == {"role": "survivor"},
		"Only surviving alias and its data remain in the main registry")
	_check(runtime.get_dynamic_state_ids(sibling_id).is_empty()
		and runtime.pending_request_count() == 2,
		"Both removed-target requests purged; sibling and survivor requests preserved")
	_check(runtime.get_active_state_id(main_id) == idle_a.get_internal_id()
		and runtime.get_active_state_id(sibling_id) == idle_b.get_internal_id()
		and _commits.is_empty(),
		"SDK removal during Update does not trigger reentrant transitions")

	for record: Dictionary in records:
		var operations: FlowFSMOperations = record.get("facade") as FlowFSMOperations
		if operations != null:
			_check(not operations.change_state(survivor)
				and operations.register_state(template_a.get_internal_id()) == "",
				"Retained SDK facade rejects mutation outside its callback")
	_check(runtime.pending_request_count() == 2,
		"Expired facades cannot restore purged requests")

	runtime.tick(0.1, FlowStateMachineDefinition.TickMode.MANUAL)
	_check(runtime.pending_request_count() == 0
		and runtime.get_active_state_id(main_id) == survivor
		and runtime.get_active_state_id(sibling_id) == target_b.get_internal_id(),
		"Next tick commits only surviving A alias and sibling B request")
	_check(_commits == [
		sibling_id + ":" + idle_b.get_internal_id() + ">" + target_b.get_internal_id(),
		main_id + ":" + idle_a.get_internal_id() + ">" + survivor
	], "Both unaffected transitions commit in deterministic machine order")
	_check(controller.get_meta("potok_8d1c4c1_records", []).size() == 2,
		"Second tick never repeats SDK removals")
	_check(machine_integrity(main, sibling, idle_a, template_a, idle_b, target_b, graph),
		"SDK actions preserve authored graph and stable state definitions")

	controller.visual_program_enabled = false
	controller.queue_free()
	await get_tree().process_frame
	if _failures.is_empty():
		print("[Flujo] Potok 8D1-C4C1 SDK selective inactive alias removal passed")
	else:
		for failure: String in _failures:
			push_error("[Flujo] Potok 8D1-C4C1 assertion: " + failure)
	get_tree().quit(0 if _failures.is_empty() else 1)


func _probe(script: Script, role: String, template_id: String, target: String) -> FlowBlock:
	var block: FlowBlock = script.new() as FlowBlock
	if block != null:
		block.set("role", role)
		block.set("template_state_id", template_id)
		block.set("other_target_id", target)
	return block


func machine_integrity(main: FlowStateMachineDefinition,
		sibling: FlowStateMachineDefinition,
		idle_a: FlowStateDefinition, template_a: FlowStateDefinition,
		idle_b: FlowStateDefinition, target_b: FlowStateDefinition,
		graph: FlowGraph) -> bool:
	return graph.state_machines == [sibling, main] \
		and main.states == [idle_a, template_a] \
		and sibling.states == [idle_b, target_b] \
		and not FlowGraphValidator.validate(graph).has_errors()


func _on_commit(machine_id: String, old_id: String, new_id: String,
		_trigger: String) -> void:
	_commits.append(machine_id + ":" + old_id + ">" + new_id)


func _check(ok: bool, description: String) -> bool:
	if not ok:
		_failures.append(description)
		push_error("[Flujo] Potok 8D1-C4C1: " + description)
	return ok
