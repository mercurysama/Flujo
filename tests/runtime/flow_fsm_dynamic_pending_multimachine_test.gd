extends Node

## Potok 8C2 — removing a dynamic alias purges only matching queued direct commands.
var _failures: Array[String] = []
var _consumed: Array[String] = []
var _commits: Array[String] = []

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	var graph: FlowGraph = FlowGraph.new()
	graph.schema_version = FlowGraph.SCHEMA_VERSION_3
	graph.constructor = FlowConstructorDefinition.new()
	var idle_a: FlowStateDefinition = FlowStateDefinition.new()
	idle_a.display_name = "IdleA"
	var template_a: FlowStateDefinition = FlowStateDefinition.new()
	template_a.display_name = "DynamicTemplateA"
	var idle_b: FlowStateDefinition = FlowStateDefinition.new()
	idle_b.display_name = "IdleB"
	var target_b: FlowStateDefinition = FlowStateDefinition.new()
	target_b.display_name = "TargetB"
	var machine_a: FlowStateMachineDefinition = FlowStateMachineDefinition.new()
	machine_a.tick_mode = FlowStateMachineDefinition.TickMode.MANUAL
	machine_a.states = [idle_a, template_a]
	machine_a.initial_state_id = idle_a.get_internal_id()
	var machine_b: FlowStateMachineDefinition = FlowStateMachineDefinition.new()
	machine_b.tick_mode = FlowStateMachineDefinition.TickMode.MANUAL
	machine_b.states = [idle_b, target_b]
	machine_b.initial_state_id = idle_b.get_internal_id()
	graph.state_machines = [machine_a, machine_b]
	var first: PVController = PVController.new()
	first.flow_graph = graph
	var second: PVController = PVController.new()
	second.flow_graph = graph
	add_child(first)
	add_child(second)
	await get_tree().process_frame
	var runtime: FlowFSMRuntime = first.get_fsm_runtime()
	var independent: FlowFSMRuntime = second.get_fsm_runtime()
	if not _check(runtime != null and independent != null and runtime.is_running()
			and independent.is_running(), "Both controller instances started"):
		get_tree().quit(1)
		return
	var a_id: String = machine_a.get_internal_id()
	var b_id: String = machine_b.get_internal_id()
	var alias: String = runtime.register_state(a_id, template_a.get_internal_id())
	if not _check(FlowId.is_valid(alias), "Alias registered in machine A"):
		get_tree().quit(1)
		return
	runtime.event_consumed.connect(_record_event)
	runtime.transition_committed.connect(_record_commit)
	_check(runtime.change_state(a_id, alias), "Queue first A direct to alias")
	_check(runtime.emit_event(a_id, &"unmatched_a", {"seq": 1}),
			"Queue A independent event")
	_check(runtime.change_state(b_id, target_b.get_internal_id()),
			"Queue B authored direct")
	_check(runtime.change_state(a_id, alias), "Queue second A direct to alias")
	_check(runtime.emit_event(b_id, &"unmatched_b", {"seq": 2}),
			"Queue B independent event")
	_check(runtime.pending_request_count() == 5,
			"Mixed two-machine direct/event queue has five requests")
	_check(runtime.remove_state(a_id, alias), "Inactive alias removal permitted")
	_check(runtime.pending_request_count() == 3,
			"Only two direct commands targeting deleted alias were removed")
	_check(not runtime.has_state(a_id, alias), "Deleted alias cannot be resolved")
	_check(not runtime.change_state(a_id, alias),
			"Fresh direct request to deleted alias rejected")
	_check(runtime.pending_request_count() == 3,
			"Rejected stale target does not add a request")
	var recycled: String = runtime.register_state(
			a_id, template_a.get_internal_id(), alias)
	_check(recycled == alias, "Explicit ID can be re-registered after removal")
	_check(runtime.pending_request_count() == 3,
			"Old direct requests do not resurrect when ID is reused")
	runtime.tick(0.1, FlowStateMachineDefinition.TickMode.MANUAL)
	_check(runtime.pending_request_count() == 0,
			"Unrelated events and B direct command consume normally")
	_check(runtime.get_active_state_id(a_id) == idle_a.get_internal_id(),
			"Machine A did not transition via deleted stale requests")
	_check(runtime.get_active_state_id(b_id) == target_b.get_internal_id(),
			"Machine B pending valid direct transition still commits")
	_check(_consumed.has(a_id + ":unmatched_a")
			and _consumed.has(b_id + ":unmatched_b")
			and _consumed.size() == 2,
			"Both unrelated events remain deliverable")
	_check(_commits.size() == 1
			and _commits[0] == b_id + ":" + idle_b.get_internal_id()
				+ ">" + target_b.get_internal_id(),
			"Only machine B commits its pending transition")
	_check(runtime.get_dynamic_state_ids(a_id) == [alias],
			"Recreated alias remains registered but inactive")
	_check(independent.pending_request_count() == 0
			and independent.get_dynamic_state_ids(a_id).is_empty()
			and independent.get_active_state_id(a_id) == idle_a.get_internal_id(),
			"Other controller instance unaffected")
	_check(machine_a.states.size() == 2 and machine_b.states.size() == 2
			and not FlowGraphValidator.validate(graph).has_errors(),
			"Runtime never writes to FlowGraph authored state arrays")
	first.visual_program_enabled = false
	second.visual_program_enabled = false
	first.queue_free()
	second.queue_free()
	await get_tree().process_frame
	if _failures.is_empty():
		print("[Flujo] Potok 8C2 selective queue purge passed")
	else:
		for failure: String in _failures:
			push_error("[Flujo] Potok 8C2: " + failure)
	get_tree().quit(0 if _failures.is_empty() else 1)

func _record_event(machine_id: String, event_name: StringName, _payload: Dictionary) -> void:
	_consumed.append(machine_id + ":" + String(event_name))

func _record_commit(machine_id: String, from_state_id: String,
		to_state_id: String, _trigger_id: String) -> void:
	_commits.append(machine_id + ":" + from_state_id + ">" + to_state_id)

func _check(ok: bool, description: String) -> bool:
	if not ok:
		_failures.append(description)
		push_error("[Flujo] Potok 8C2: " + description)
	return ok
