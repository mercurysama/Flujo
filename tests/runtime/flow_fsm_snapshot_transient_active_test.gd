extends Node

## Potok 8D2-B2A: snapshot of three simultaneously active dynamic lifetimes
## across three MANUAL machines. FLU-FSM-004 codec remains untouched.
var _failures: Array[String] = []


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var graph: FlowGraph = FlowGraph.new()
	graph.schema_version = FlowGraph.SCHEMA_VERSION_3
	graph.constructor = FlowConstructorDefinition.new()
	var e_initial: FlowStateDefinition = _state("E-Idle")
	var e_template: FlowStateDefinition = _state("E-Template")
	var s_initial: FlowStateDefinition = _state("S-Idle")
	var s_template: FlowStateDefinition = _state("S-Template")
	var p_initial: FlowStateDefinition = _state("P-Idle")
	var p_template: FlowStateDefinition = _state("P-Template")
	var e_machine: FlowStateMachineDefinition = _machine(e_initial, e_template)
	var s_machine: FlowStateMachineDefinition = _machine(s_initial, s_template)
	var p_machine: FlowStateMachineDefinition = _machine(p_initial, p_template)
	graph.state_machines = [e_machine, s_machine, p_machine]
	if not _check(not FlowGraphValidator.validate(graph).has_errors(),
			"Three authored schema 3 FSMs validate before snapshot test"):
		get_tree().quit(1)
		return

	var source: PVController = PVController.new()
	source.flow_graph = graph
	var target: PVController = PVController.new()
	target.flow_graph = graph
	add_child(source)
	add_child(target)
	await get_tree().process_frame
	var runtime: FlowFSMRuntime = source.get_fsm_runtime()
	var restored: FlowFSMRuntime = target.get_fsm_runtime()
	if not _check(runtime != null and restored != null and runtime != restored
			and runtime.is_running() and restored.is_running(),
			"Independent runtimes share only the authored FlowGraph"):
		source.queue_free()
		target.queue_free()
		get_tree().quit(1)
		return

	var e_mid: String = e_machine.get_internal_id()
	var s_mid: String = s_machine.get_internal_id()
	var p_mid: String = p_machine.get_internal_id()
	var persistent: int = FlowFSMDynamicStateRecord.Lifetime.PERSISTENT
	var ephemeral: int = FlowFSMDynamicStateRecord.Lifetime.EPHEMERAL
	var session: int = FlowFSMDynamicStateRecord.Lifetime.SESSION
	var e_p1: String = _register(runtime, e_mid, e_template, persistent, "E-P1")
	var e_transient: String = _register(runtime, e_mid, e_template, ephemeral, "E-E")
	var e_p2: String = _register(runtime, e_mid, e_template, persistent, "E-P2")
	var s_transient: String = _register(runtime, s_mid, s_template, session, "S-S")
	var s_p1: String = _register(runtime, s_mid, s_template, persistent, "S-P1")
	var s_p2: String = _register(runtime, s_mid, s_template, persistent, "S-P2")
	var p_p1: String = _register(runtime, p_mid, p_template, persistent, "P-P1")
	var p_transient: String = _register(runtime, p_mid, p_template, session, "P-S")
	var p_p2: String = _register(runtime, p_mid, p_template, persistent, "P-P2")
	var ids: Array[String] = [
		e_p1, e_transient, e_p2, s_transient, s_p1, s_p2,
		p_p1, p_transient, p_p2
	]
	var all_valid: bool = true
	for alias_id: String in ids:
		if not FlowId.is_valid(alias_id):
			all_valid = false
	if not _check(all_valid and ids.size() == 9
			and runtime.get_dynamic_state_ids(e_mid) == [e_p1, e_transient, e_p2]
			and runtime.get_dynamic_state_ids(s_mid) == [s_transient, s_p1, s_p2]
			and runtime.get_dynamic_state_ids(p_mid) == [p_p1, p_transient, p_p2],
			"Interleaved ephemeral, session, persistent aliases register in stable order"):
		source.visual_program_enabled = false
		target.visual_program_enabled = false
		source.queue_free()
		target.queue_free()
		get_tree().quit(1)
		return
	_check(runtime.change_state(e_mid, e_transient)
		and runtime.change_state(s_mid, s_transient)
		and runtime.change_state(p_mid, p_p1),
		"Three independent MANUAL machines queue different lifetime targets")
	runtime.tick(0.125, FlowStateMachineDefinition.TickMode.MANUAL)
	_check(runtime.get_active_state_id(e_mid) == e_transient
		and runtime.get_active_state_id(s_mid) == s_transient
		and runtime.get_active_state_id(p_mid) == p_p1
		and runtime.pending_request_count() == 0,
		"EPHEMERAL, SESSION, and PERSISTENT aliases are active simultaneously")

	var saved: Dictionary = runtime.export_snapshot()
	var expected_machines: Array = [
		{"machine_id": e_mid, "active_state_id": e_initial.get_internal_id()},
		{"machine_id": s_mid, "active_state_id": s_initial.get_internal_id()},
		{"machine_id": p_mid, "active_state_id": p_p1}
	]
	var expected_dynamic: Array = [
		_entry(e_mid, e_p1, e_template, "E-P1"),
		_entry(e_mid, e_p2, e_template, "E-P2"),
		_entry(s_mid, s_p1, s_template, "S-P1"),
		_entry(s_mid, s_p2, s_template, "S-P2"),
		_entry(p_mid, p_p1, p_template, "P-P1"),
		_entry(p_mid, p_p2, p_template, "P-P2")
	]
	_check(saved.get("format_version") == FlowFSMSnapshotCodec.FORMAT_VERSION
		and saved.get("graph_id") == graph.get_internal_id()
		and saved.get("schema_version") == graph.schema_version,
		"Snapshot preserves existing FLU-FSM-004 version and graph identity")
	_check(saved.get("machines", []) == expected_machines,
		"Machine order follows authored graph; transient active IDs recover as initial")
	_check(saved.get("dynamic_states", []) == expected_dynamic,
		"Only PERSISTENT IDs and JSON-safe data serialize in machine/registration order")
	_check(saved.get("dynamic_states", []).size() == 6
		and not JSON.stringify(saved).contains(e_transient)
		and not JSON.stringify(saved).contains(s_transient)
		and not JSON.stringify(saved).contains(p_transient),
		"No EPHEMERAL/SESSION alias ID is leaked anywhere in serialized snapshot")
	_check(runtime.get_active_state_id(e_mid) == e_transient
		and runtime.get_active_state_id(s_mid) == s_transient
		and runtime.get_active_state_id(p_mid) == p_p1
		and runtime.get_dynamic_state_ids(e_mid).size() == 3,
		"Export does not mutate live active states or registries")

	var detached: Dictionary = saved.duplicate(true)
	(detached["dynamic_states"] as Array)[0]["data"]["nested"]["values"].append(999)
	(detached["machines"] as Array)[0]["active_state_id"] = e_p1
	var fresh: Dictionary = runtime.export_snapshot()
	_check(fresh.get("machines", []) == expected_machines
		and fresh.get("dynamic_states", []) == expected_dynamic,
		"Mutation of returned snapshot cannot rewrite runtime's nested metadata")
	_check(runtime.export_snapshot() == fresh,
		"Export order and portable payload are deterministic for unchanged runtime")

	var target_before: String = restored.register_state(
		e_mid, e_template.get_internal_id(), "", session, {"target": "replace"}
	)
	_check(FlowId.is_valid(target_before)
		and restored.get_dynamic_state_ids(e_mid) == [target_before],
		"Target runtime owns a separate session alias before explicit restore")
	_check(restored.restore_snapshot(fresh),
		"Portable existing codec restores into a second matching controller")
	_check(restored.get_active_state_id(e_mid) == e_initial.get_internal_id()
		and restored.get_active_state_id(s_mid) == s_initial.get_internal_id()
		and restored.get_active_state_id(p_mid) == p_p1,
		"Restored active states respect transient fallback and persistent identity")
	_check(restored.get_dynamic_state_ids(e_mid) == [e_p1, e_p2]
		and restored.get_dynamic_state_ids(s_mid) == [s_p1, s_p2]
		and restored.get_dynamic_state_ids(p_mid) == [p_p1, p_p2]
		and not restored.has_state(e_mid, target_before),
		"Restore replaces local alias registries with ordered persistent entries")
	_check(restored.export_snapshot() == fresh,
		"Round-trip re-export matches portable snapshot order and payload exactly")
	_check(restored.set_dynamic_state_data(p_mid, p_p1,
		{"tag": "changed-in-target", "nested": {"values": [42]}}),
		"Restored alias data may be mutated independently")
	_check(runtime.get_dynamic_state_data(p_mid, p_p1)
		== {"tag": "P-P1", "nested": {"values": ["P-P1", 4]}},
		"Restoring and editing another controller never changes source metadata")
	_check(runtime.get_active_state_id(e_mid) == e_transient
		and runtime.get_active_state_id(s_mid) == s_transient
		and runtime.get_active_state_id(p_mid) == p_p1
		and graph.state_machines == [e_machine, s_machine, p_machine]
		and e_machine.states == [e_initial, e_template]
		and s_machine.states == [s_initial, s_template]
		and p_machine.states == [p_initial, p_template]
		and not FlowGraphValidator.validate(graph).has_errors(),
		"Snapshots do not change source active states or authored definitions")
	source.visual_program_enabled = false
	target.visual_program_enabled = false
	source.queue_free()
	target.queue_free()
	await get_tree().process_frame
	if _failures.is_empty():
		print("[Flujo] Potok 8D2-B2A transient active snapshot and stable ordering passed")
	else:
		for failure: String in _failures:
			push_error("[Flujo] Potok 8D2-B2A: " + failure)
	get_tree().quit(0 if _failures.is_empty() else 1)


func _state(name: String) -> FlowStateDefinition:
	var state: FlowStateDefinition = FlowStateDefinition.new()
	state.display_name = name
	return state


func _machine(initial: FlowStateDefinition,
		template: FlowStateDefinition) -> FlowStateMachineDefinition:
	var machine: FlowStateMachineDefinition = FlowStateMachineDefinition.new()
	machine.tick_mode = FlowStateMachineDefinition.TickMode.MANUAL
	machine.states = [initial, template]
	machine.initial_state_id = initial.get_internal_id()
	return machine


func _register(runtime: FlowFSMRuntime, mid: String,
		template: FlowStateDefinition, lifetime: int, label: String) -> String:
	return runtime.register_state(
		mid, template.get_internal_id(), "", lifetime,
		{"tag": label, "nested": {"values": [label, 4]}}
	)


func _entry(mid: String, alias_id: String, template: FlowStateDefinition,
		label: String) -> Dictionary:
	return {
		"machine_id": mid,
		"runtime_id": alias_id,
		"template_state_id": template.get_internal_id(),
		"lifetime": FlowFSMDynamicStateRecord.Lifetime.PERSISTENT,
		"data": {"tag": label, "nested": {"values": [label, 4]}}
	}


func _check(ok: bool, message: String) -> bool:
	if not ok:
		_failures.append(message)
		push_error("[Flujo] Potok 8D2-B2A: " + message)
	return ok
