extends Node

## Potok 8D2-B2B: failed snapshot preflight is atomic, including pending
## requests and callbacks, with two independent PVControllers.
var _failures: Array[String] = []
var _trace: Array[String] = []


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var graph: FlowGraph = FlowGraph.new()
	graph.schema_version = FlowGraph.SCHEMA_VERSION_3
	graph.constructor = FlowConstructorDefinition.new()
	var a_idle: FlowStateDefinition = _state("A-Idle", "a-idle")
	var a_worker: FlowStateDefinition = _state("A-Worker", "a-worker")
	var b_idle: FlowStateDefinition = _state("B-Idle", "b-idle")
	var b_worker: FlowStateDefinition = _state("B-Worker", "b-worker")
	var machine_a: FlowStateMachineDefinition = _machine(a_idle, a_worker)
	var machine_b: FlowStateMachineDefinition = _machine(b_idle, b_worker)
	graph.state_machines = [machine_a, machine_b]
	if not _check(not FlowGraphValidator.validate(graph).has_errors(),
			"Two authored schema 3 machines validate"):
		get_tree().quit(1)
		return

	var owner: PVController = PVController.new()
	owner.flow_graph = graph
	owner.runtime_output.entry_message_emitted.connect(_on_output)
	var sibling: PVController = PVController.new()
	sibling.flow_graph = graph
	add_child(owner)
	add_child(sibling)
	await get_tree().process_frame
	var runtime: FlowFSMRuntime = owner.get_fsm_runtime()
	var other: FlowFSMRuntime = sibling.get_fsm_runtime()
	if not _check(runtime != null and other != null
			and runtime.is_running() and other.is_running() and runtime != other,
			"Two controller-local FSM runtimes started"):
		owner.queue_free()
		sibling.queue_free()
		get_tree().quit(1)
		return
	runtime.state_exited.connect(_on_exit)
	runtime.state_entered.connect(_on_enter)
	runtime.transition_committed.connect(_on_commit)
	var ma: String = machine_a.get_internal_id()
	var mb: String = machine_b.get_internal_id()
	var persistent: int = FlowFSMDynamicStateRecord.Lifetime.PERSISTENT
	var session: int = FlowFSMDynamicStateRecord.Lifetime.SESSION
	var alias_a: String = runtime.register_state(
		ma, a_worker.get_internal_id(), "", persistent,
		{"owner": "a", "nested": {"count": 7, "values": [1, 2]}}
	)
	var alias_b: String = runtime.register_state(
		mb, b_worker.get_internal_id(), "", persistent,
		{"owner": "b", "nested": {"count": 8, "values": [3, 4]}}
	)
	var transient: String = runtime.register_state(
		ma, a_worker.get_internal_id(), "", session,
		{"owner": "session", "nested": {"count": 9}}
	)
	var independent: String = other.register_state(
		ma, a_worker.get_internal_id(), "", session, {"owner": "sibling"}
	)
	if not _check(FlowId.is_valid(alias_a) and FlowId.is_valid(alias_b)
			and FlowId.is_valid(transient) and FlowId.is_valid(independent),
			"Two persistent and two controller-isolated session aliases register"):
		owner.visual_program_enabled = false
		sibling.visual_program_enabled = false
		owner.queue_free()
		sibling.queue_free()
		get_tree().quit(1)
		return

	_check(runtime.change_state(ma, alias_a),
		"Machine A queues persistent activation")
	runtime.tick(0.1, FlowStateMachineDefinition.TickMode.MANUAL)
	_check(runtime.get_active_state_id(ma) == alias_a
		and runtime.get_active_state_id(mb) == b_idle.get_internal_id(),
		"Source runtime owns active persistent and initial authored machines")
	var baseline: Dictionary = runtime.export_snapshot()
	_check((baseline.get("dynamic_states", []) as Array).size() == 2
		and (baseline.get("machines", []) as Array).size() == 2,
		"Valid portable snapshot captures both persistent records and machines")
	_check(runtime.change_state(ma, transient)
		and runtime.emit_event(ma, &"unhandled", {"marker": "queued"})
		and runtime.change_state(mb, b_worker.get_internal_id()),
		"Three mixed packets are queued before invalid restore attempts")
	_check(other.change_state(ma, a_worker.get_internal_id()),
		"Other controller has one independent queued request")
	var queue_before: int = runtime.pending_request_count()
	var sibling_queue: int = other.pending_request_count()
	var ids_a: Array[String] = runtime.get_dynamic_state_ids(ma)
	var ids_b: Array[String] = runtime.get_dynamic_state_ids(mb)
	var data_a: Dictionary = runtime.get_dynamic_state_data(ma, alias_a)
	var data_b: Dictionary = runtime.get_dynamic_state_data(mb, alias_b)
	var data_t: Dictionary = runtime.get_dynamic_state_data(ma, transient)
	var active_a: String = runtime.get_active_state_id(ma)
	var active_b: String = runtime.get_active_state_id(mb)
	_check(queue_before == 3 and sibling_queue == 1
		and ids_a == [alias_a, transient] and ids_b == [alias_b],
		"Source and sibling queues plus registries have known baseline")

	var invalid_names: Array[String] = [
		"non_dictionary", "unsupported_version", "foreign_graph",
		"foreign_schema", "missing_machine_collection", "wrong_dynamic_collection",
		"missing_machine", "duplicate_machine", "unknown_machine",
		"invalid_active_id", "unsaved_session_active", "bad_machine_record",
		"unknown_dynamic_machine", "bad_dynamic_record", "bad_alias_id",
		"authored_id_collision", "missing_template", "wrong_lifetime",
		"string_payload", "unsafe_callable", "too_deep",
		"duplicated_dynamic_id", "per_machine_quota"
	]
	_trace.clear()
	for case_name: String in invalid_names:
		var invalid: Variant = _make_invalid(
			baseline, case_name, ma, a_idle.get_internal_id(), transient
		)
		_check(not runtime.restore_snapshot(invalid),
			"Invalid snapshot must be rejected: " + case_name)
		_check(runtime.get_active_state_id(ma) == active_a
			and runtime.get_active_state_id(mb) == active_b
			and runtime.get_dynamic_state_ids(ma) == ids_a
			and runtime.get_dynamic_state_ids(mb) == ids_b
			and runtime.get_dynamic_state_data(ma, alias_a) == data_a
			and runtime.get_dynamic_state_data(mb, alias_b) == data_b
			and runtime.get_dynamic_state_data(ma, transient) == data_t
			and runtime.pending_request_count() == queue_before
			and runtime.export_snapshot() == baseline
			and _trace.is_empty(),
			"Failed preflight has no mutation, lifecycle or queue consumption: " + case_name)
		_check(other.get_dynamic_state_ids(ma) == [independent]
			and other.get_active_state_id(ma) == a_idle.get_internal_id()
			and other.pending_request_count() == sibling_queue,
			"Rejected snapshot never changes other controller: " + case_name)

	_check(runtime.restore_snapshot(baseline),
		"Valid snapshot is still restorable after invalid attempts")
	_check(_trace == [
		"StateExit:a-worker-exit", "Exit:" + active_a,
		"StateExit:b-idle-exit", "Exit:" + active_b,
		"StateEnter:a-worker-enter", "Enter:" + alias_a,
		"StateEnter:b-idle-enter", "Enter:" + active_b
	], "Valid restore executes ordered Exit of both, then ordered Enter of both")
	_check(runtime.pending_request_count() == 0
		and runtime.get_active_state_id(ma) == alias_a
		and runtime.get_active_state_id(mb) == b_idle.get_internal_id()
		and runtime.get_dynamic_state_ids(ma) == [alias_a]
		and runtime.get_dynamic_state_ids(mb) == [alias_b]
		and not runtime.has_state(ma, transient),
		"Successful restore clears stale pending packets and replaces session alias")
	_check(runtime.get_dynamic_state_data(ma, alias_a) == data_a
		and runtime.get_dynamic_state_data(mb, alias_b) == data_b,
		"Successful restore keeps detached persistent nested data")
	(baseline["dynamic_states"] as Array)[0]["data"]["nested"]["count"] = 404
	_check(runtime.get_dynamic_state_data(ma, alias_a) == data_a,
		"Mutating caller's snapshot after restore cannot mutate live registry")
	_check(other.pending_request_count() == sibling_queue
		and other.get_dynamic_state_ids(ma) == [independent],
		"Successful restore still does not affect independent controller")
	other.tick(0.1, FlowStateMachineDefinition.TickMode.MANUAL)
	_check(other.get_active_state_id(ma) == a_worker.get_internal_id()
		and other.pending_request_count() == 0
		and runtime.get_active_state_id(ma) == alias_a,
		"Other controller eventually consumes only its own preexisting request")
	_check(graph.state_machines == [machine_a, machine_b]
		and machine_a.states == [a_idle, a_worker]
		and machine_b.states == [b_idle, b_worker]
		and not FlowGraphValidator.validate(graph).has_errors(),
		"Every rejected/valid snapshot preserves authored FlowGraph")

	owner.visual_program_enabled = false
	sibling.visual_program_enabled = false
	owner.queue_free()
	sibling.queue_free()
	await get_tree().process_frame
	if _failures.is_empty():
		print("[Flujo] Potok 8D2-B2B invalid snapshot atomic preflight passed")
	else:
		for error: String in _failures:
			push_error("[Flujo] Potok 8D2-B2B: " + error)
	get_tree().quit(0 if _failures.is_empty() else 1)


func _make_invalid(source: Dictionary, case_name: String,
		machine_id: String, authored_id: String, transient_id: String) -> Variant:
	var snapshot: Dictionary = source.duplicate(true)
	var machines: Array = snapshot["machines"]
	var dynamic: Array = snapshot["dynamic_states"]
	match case_name:
		"non_dictionary":
			return ["not", "a", "dictionary"]
		"unsupported_version":
			snapshot["format_version"] = 999
		"foreign_graph":
			snapshot["graph_id"] = "not-the-live-graph"
		"foreign_schema":
			snapshot["schema_version"] = 777
		"missing_machine_collection":
			snapshot.erase("machines")
		"wrong_dynamic_collection":
			snapshot["dynamic_states"] = {}
		"missing_machine":
			machines.pop_back()
		"duplicate_machine":
			machines[1] = machines[0].duplicate(true)
		"unknown_machine":
			machines[1]["machine_id"] = "missing-machine"
		"invalid_active_id":
			machines[0]["active_state_id"] = "missing-state"
		"unsaved_session_active":
			machines[0]["active_state_id"] = transient_id
		"bad_machine_record":
			# The codec exports Array[Dictionary]; make an untyped copy so a
			# malformed row is representable without a Godot TypedArray error.
			var loose_machines: Array = []
			for row: Variant in machines:
				loose_machines.append(row)
			loose_machines[0] = "invalid-row"
			snapshot["machines"] = loose_machines
		"unknown_dynamic_machine":
			dynamic[0]["machine_id"] = "missing-machine"
		"bad_dynamic_record":
			var loose_dynamic: Array = []
			for row: Variant in dynamic:
				loose_dynamic.append(row)
			loose_dynamic[0] = "invalid-row"
			snapshot["dynamic_states"] = loose_dynamic
		"bad_alias_id":
			dynamic[0]["runtime_id"] = "not-a-valid-flow-id"
		"authored_id_collision":
			dynamic[0]["runtime_id"] = authored_id
		"missing_template":
			dynamic[0]["template_state_id"] = "missing-template"
		"wrong_lifetime":
			dynamic[0]["lifetime"] = FlowFSMDynamicStateRecord.Lifetime.SESSION
		"string_payload":
			dynamic[0]["data"] = "not-a-dictionary"
		"unsafe_callable":
			dynamic[0]["data"] = {"callback": Callable(self, "_run")}
		"too_deep":
			var nested: Dictionary = {"value": 10}
			for i: int in 10:
				nested = {"nested": nested}
			dynamic[0]["data"] = nested
		"duplicated_dynamic_id":
			dynamic.append(dynamic[0].duplicate(true))
		"per_machine_quota":
			for i: int in FlowFSMRuntime.MAX_DYNAMIC_STATES:
				var entry: Dictionary = dynamic[0].duplicate(true)
				entry["runtime_id"] = FlowId.create()
				entry["data"] = {"case": i}
				dynamic.append(entry)
	return snapshot


func _state(name: String, message_prefix: String) -> FlowStateDefinition:
	var state: FlowStateDefinition = FlowStateDefinition.new()
	state.display_name = name
	state.enter_blocks = [_printer(message_prefix + "-enter")]
	state.exit_blocks = [_printer(message_prefix + "-exit")]
	return state


func _machine(idle: FlowStateDefinition,
		worker: FlowStateDefinition) -> FlowStateMachineDefinition:
	var machine: FlowStateMachineDefinition = FlowStateMachineDefinition.new()
	machine.tick_mode = FlowStateMachineDefinition.TickMode.MANUAL
	machine.states = [idle, worker]
	machine.initial_state_id = idle.get_internal_id()
	return machine


func _printer(message: String) -> FlowPrintBlock:
	var block: FlowPrintBlock = FlowPrintBlock.new()
	block.text = message
	return block


func _on_output(_controller: Node, _container: String,
		_block: String, message: String, entry_point: StringName) -> void:
	_trace.append(String(entry_point) + ":" + message)


func _on_exit(_machine_id: String, id: String) -> void:
	_trace.append("Exit:" + id)


func _on_enter(_machine_id: String, id: String) -> void:
	_trace.append("Enter:" + id)


func _on_commit(_machine_id: String, from_id: String,
		to_id: String, reason: String) -> void:
	_trace.append("Commit:" + from_id + ">" + to_id + ":" + reason)


func _check(value: bool, message: String) -> bool:
	if not value:
		_failures.append(message)
		push_error("[Flujo] Potok 8D2-B2B assertion: " + message)
	return value
