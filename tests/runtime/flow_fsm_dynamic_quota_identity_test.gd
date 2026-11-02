extends Node

## Potok 8B1: runtime-only state quota, authored collisions and stable ID recycling.
var _failures: Array[String] = []

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	var graph := FlowGraph.new()
	graph.schema_version = FlowGraph.SCHEMA_VERSION_3
	graph.constructor = FlowConstructorDefinition.new()
	var idle := FlowStateDefinition.new()
	idle.display_name = "Idle"
	var template := FlowStateDefinition.new()
	template.display_name = "Stunned"
	var other_template := FlowStateDefinition.new()
	other_template.display_name = "Other"
	var machine := FlowStateMachineDefinition.new()
	machine.tick_mode = FlowStateMachineDefinition.TickMode.MANUAL
	machine.states = [idle, template]
	machine.initial_state_id = idle.get_internal_id()
	var other_machine := FlowStateMachineDefinition.new()
	other_machine.tick_mode = FlowStateMachineDefinition.TickMode.MANUAL
	other_machine.states = [other_template]
	other_machine.initial_state_id = other_template.get_internal_id()
	graph.state_machines = [machine, other_machine]
	var first := PVController.new()
	first.flow_graph = graph
	var second := PVController.new()
	second.flow_graph = graph
	add_child(first)
	add_child(second)
	await get_tree().process_frame
	var runtime: FlowFSMRuntime = first.get_fsm_runtime()
	var other: FlowFSMRuntime = second.get_fsm_runtime()
	if not _check(runtime != null and other != null and runtime.is_running()
			and other.is_running(), "Both controller runtimes started"):
		get_tree().quit(1)
		return
	var mid: String = machine.get_internal_id()
	var tid: String = template.get_internal_id()
	var oid: String = other_machine.get_internal_id()
	var initial_count: int = machine.states.size()
	_check(runtime.register_state(mid, tid, idle.get_internal_id()) == "",
		"Authored initial-state ID cannot become a dynamic ID")
	_check(runtime.register_state(mid, tid, tid) == "",
		"Authored template ID collision is rejected")
	_check(runtime.register_state(mid, other_template.get_internal_id()) == "",
		"Template belonging to a different machine is rejected")
	_check(runtime.get_dynamic_state_ids(mid).is_empty(),
		"Rejected aliases do not occupy registry")
	var ordered: Array[String] = []
	for i: int in 128:
		var next_id: String = runtime.register_state(mid, tid, "",
			FlowFSMDynamicStateRecord.Lifetime.EPHEMERAL, {"index": i})
		if not _check(FlowId.is_valid(next_id), "Registration %d succeeds within quota" % i):
			break
		ordered.append(next_id)
	_check(ordered.size() == 128, "128 aliases fit exactly")
	_check(runtime.get_dynamic_state_ids(mid) == ordered,
		"Registry enumeration follows registration order")
	var before: Array[String] = runtime.get_dynamic_state_ids(mid)
	_check(runtime.register_state(mid, tid) == "",
		"129th alias rejected at quota")
	_check(runtime.register_state(mid, tid, idle.get_internal_id()) == "",
		"Quota rejection cannot overwrite authored state")
	_check(runtime.get_dynamic_state_ids(mid) == before,
		"Quota and collision rejections preserve registry")
	_check(runtime.get_dynamic_state_ids(oid).is_empty()
		and other.get_dynamic_state_ids(mid).is_empty(),
		"Second machine/controller remain independent")
	if ordered.size() == 128:
		var removed_id: String = ordered[31]
		_check(runtime.remove_state(mid, removed_id),
			"Inactive alias can be removed with quota full")
		ordered.remove_at(31)
		_check(not runtime.has_state(mid, removed_id),
			"Removed alias is not resolvable")
		_check(runtime.get_dynamic_state_ids(mid) == ordered,
			"Removing interior alias preserves survivor order")
		var reused_id: String = runtime.register_state(mid, tid, removed_id,
			FlowFSMDynamicStateRecord.Lifetime.SESSION, {"reused": true})
		_check(reused_id == removed_id,
			"Removed valid ID can be re-registered")
		ordered.append(removed_id)
		_check(runtime.get_dynamic_state_ids(mid) == ordered,
			"Re-registered alias appends deterministically")
		_check(runtime.get_dynamic_state_lifetime(mid, removed_id) ==
			FlowFSMDynamicStateRecord.Lifetime.SESSION
			and runtime.get_dynamic_state_data(mid, removed_id).get("reused") == true,
			"Re-registered alias owns new lifetime and fresh data")
		_check(runtime.register_state(mid, tid, removed_id) == "",
			"Duplicate re-registration still rejects")
	_check(machine.states.size() == initial_count
		and not FlowGraphValidator.validate(graph).has_errors(),
		"No runtime aliases are inserted into authored graph")
	first.visual_program_enabled = false
	_check(runtime.get_dynamic_state_ids(mid).is_empty(),
		"Stop frees full dynamic registry")
	_check(other.is_running(), "Other runtime remains active")
	second.visual_program_enabled = false
	first.queue_free()
	second.queue_free()
	await get_tree().process_frame
	if _failures.is_empty():
		print("[Flujo] Potok 8B1 dynamic quota identity and ordered registry passed")
	get_tree().quit(0 if _failures.is_empty() else 1)

func _check(ok: bool, description: String) -> bool:
	if not ok:
		_failures.append(description)
		push_error("[Flujo] Potok 8B1: " + description)
	return ok
