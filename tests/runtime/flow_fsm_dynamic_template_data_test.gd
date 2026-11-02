extends Node

## Potok 8B2: same-machine template, detached structured data and validator limits.
var _failures: Array[String] = []

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	var graph := FlowGraph.new()
	graph.schema_version = FlowGraph.SCHEMA_VERSION_3
	graph.constructor = FlowConstructorDefinition.new()
	var initial := FlowStateDefinition.new()
	initial.display_name = "Idle"
	var template := FlowStateDefinition.new()
	template.display_name = "Temporary"
	var disabled := FlowStateDefinition.new()
	disabled.display_name = "Disabled"
	disabled.enabled = false
	var foreign := FlowStateDefinition.new()
	foreign.display_name = "Foreign"
	var machine := FlowStateMachineDefinition.new()
	machine.tick_mode = FlowStateMachineDefinition.TickMode.MANUAL
	machine.states = [initial, template, disabled]
	machine.initial_state_id = initial.get_internal_id()
	var second_machine := FlowStateMachineDefinition.new()
	second_machine.tick_mode = FlowStateMachineDefinition.TickMode.MANUAL
	second_machine.states = [foreign]
	second_machine.initial_state_id = foreign.get_internal_id()
	graph.state_machines = [machine, second_machine]
	var one := PVController.new()
	one.flow_graph = graph
	var two := PVController.new()
	two.flow_graph = graph
	add_child(one)
	add_child(two)
	await get_tree().process_frame
	var runtime: FlowFSMRuntime = one.get_fsm_runtime()
	var independent: FlowFSMRuntime = two.get_fsm_runtime()
	if not _check(runtime != null and independent != null and runtime.is_running(),
			"Runtime starts with disabled non-initial template"):
		get_tree().quit(1)
		return
	var mid: String = machine.get_internal_id()
	var tid: String = template.get_internal_id()
	_check(runtime.register_state(mid, disabled.get_internal_id()) == "",
		"Disabled same-machine template rejected")
	_check(runtime.register_state(mid, foreign.get_internal_id()) == "",
		"Foreign-machine template rejected")
	_check(runtime.register_state("unknown-machine", tid) == "",
		"Unknown machine rejected")
	_check(runtime.get_dynamic_state_ids(mid).is_empty(),
		"Template rejections leave registry unchanged")
	var nested: Dictionary = {"events": [{"score": 3, "flags": [true, null, 2.5]}],
		"name": "temporary"}
	var alias_id: String = runtime.register_state(mid, tid, "",
		FlowFSMDynamicStateRecord.Lifetime.SESSION, nested)
	if not _check(FlowId.is_valid(alias_id), "Valid nested JSON-safe data registers"):
		get_tree().quit(1)
		return
	(nested["events"] as Array)[0]["score"] = 99
	(nested["events"] as Array).append("corrupt")
	var stored: Dictionary = runtime.get_dynamic_state_data(mid, alias_id)
	_check((stored["events"] as Array).size() == 1
		and (stored["events"] as Array)[0]["score"] == 3,
		"Registration deep-clones caller-owned arrays and dictionaries")
	(stored["events"] as Array)[0]["score"] = 20
	_check((runtime.get_dynamic_state_data(mid, alias_id)["events"] as Array)[0]["score"] == 3,
		"Readback is detached from registry data")
	var replacement: Dictionary = {"outer": {"inner": [1, 2, 3]}}
	_check(runtime.set_dynamic_state_data(mid, alias_id, replacement),
		"Valid replacement accepted")
	(replacement["outer"] as Dictionary)["inner"] = ["changed"]
	_check((runtime.get_dynamic_state_data(mid, alias_id)["outer"] as Dictionary)["inner"] == [1, 2, 3],
		"Replacement data is deep cloned")
	var baseline: Dictionary = runtime.get_dynamic_state_data(mid, alias_id)
	var too_many: Array = []
	too_many.resize(FlowFSMDataValidator.MAX_ENTRIES + 1)
	var bad_key: Dictionary = {1: "numeric key"}
	var nonfinite: Dictionary = {"number": INF}
	var too_long: Dictionary = {"text": "z".repeat(FlowFSMDataValidator.MAX_JSON_LENGTH + 1)}
	var deep_value: Variant = "leaf"
	for i: int in FlowFSMDataValidator.MAX_DEPTH + 1:
		deep_value = [deep_value]
	var bad_sets: Array[Dictionary] = [
		{"many": too_many}, bad_key, nonfinite, too_long, {"deep": deep_value},
		{"callable": Callable(self, "_check")}, {"vec": Vector2(1, 2)}
	]
	for i: int in bad_sets.size():
		var invalid: Dictionary = bad_sets[i]
		_check(runtime.register_state(mid, tid, "",
			FlowFSMDynamicStateRecord.Lifetime.EPHEMERAL, invalid) == "",
			"Bad payload %d rejected at registration" % i)
		_check(not runtime.set_dynamic_state_data(mid, alias_id, invalid),
			"Bad payload %d rejected as update" % i)
		_check(runtime.get_dynamic_state_data(mid, alias_id) == baseline
			and runtime.get_dynamic_state_ids(mid) == [alias_id],
			"Rejected payload %d does not mutate state or registry" % i)
	var live_object := Node.new()
	_check(not runtime.set_dynamic_state_data(mid, alias_id, {"node": live_object}),
		"Live Godot objects rejected")
	live_object.free()
	_check(runtime.get_dynamic_state_data(mid, alias_id) == baseline,
		"Post-rejection value remains intact")
	_check(machine.states.size() == 3
		and second_machine.states.size() == 1
		and independent.get_dynamic_state_ids(mid).is_empty()
		and not FlowGraphValidator.validate(graph).has_errors(),
		"Authored templates, graph and second runtime unchanged")
	one.visual_program_enabled = false
	two.visual_program_enabled = false
	one.queue_free()
	two.queue_free()
	await get_tree().process_frame
	if _failures.is_empty():
		print("[Flujo] Potok 8B2 template and structured data validator passed")
	get_tree().quit(0 if _failures.is_empty() else 1)

func _check(ok: bool, description: String) -> bool:
	if not ok:
		_failures.append(description)
		push_error("[Flujo] Potok 8B2: " + description)
	return ok
