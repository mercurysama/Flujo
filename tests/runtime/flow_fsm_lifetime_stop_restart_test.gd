extends Node

## Potok 8D2-B1B: stop/restart creates a fresh per-controller registry and
## queue; even PERSISTENT aliases are not automatically restored from disk.
var _failures: Array[String] = []
var _a_trace: Array[String] = []
var _b_trace: Array[String] = []


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var script: Script = load(
		"res://tests/fixtures/fsm_lifetime_stop_restart_probe.gd"
	) as Script
	if not _check(script != null and script.can_instantiate(),
			"External-style SDK retention fixture loads successfully"):
		get_tree().quit(1)
		return
	var graph: FlowGraph = FlowGraph.new()
	graph.schema_version = FlowGraph.SCHEMA_VERSION_3
	graph.constructor = FlowConstructorDefinition.new()
	var idle: FlowStateDefinition = FlowStateDefinition.new()
	idle.display_name = "Idle"
	var template: FlowStateDefinition = FlowStateDefinition.new()
	template.display_name = "Worker"
	idle.enter_blocks = [_printer("idle-enter"), _probe(script, idle.get_internal_id())]
	template.exit_blocks = [_printer("worker-exit"), _probe(script, template.get_internal_id())]
	var machine: FlowStateMachineDefinition = FlowStateMachineDefinition.new()
	machine.tick_mode = FlowStateMachineDefinition.TickMode.MANUAL
	machine.states = [idle, template]
	machine.initial_state_id = idle.get_internal_id()
	graph.state_machines = [machine]
	if not _check(not FlowGraphValidator.validate(graph).has_errors(),
			"Schema 3 authored machine validates before lifecycle test"):
		get_tree().quit(1)
		return
	var mid: String = machine.get_internal_id()
	var idle_id: String = idle.get_internal_id()
	var template_id: String = template.get_internal_id()

	var first: PVController = PVController.new()
	first.flow_graph = graph
	first.runtime_output.entry_message_emitted.connect(_on_output_a)
	var second: PVController = PVController.new()
	second.flow_graph = graph
	second.runtime_output.entry_message_emitted.connect(_on_output_b)
	add_child(first)
	add_child(second)
	await get_tree().process_frame
	var runtime_a: FlowFSMRuntime = first.get_fsm_runtime()
	var runtime_b: FlowFSMRuntime = second.get_fsm_runtime()
	if not _check(runtime_a != null and runtime_b != null
			and runtime_a != runtime_b and runtime_a.is_running()
			and runtime_b.is_running(),
			"Both PVControllers own independent running manual FSM runtimes"):
		first.queue_free()
		second.queue_free()
		get_tree().quit(1)
		return

	var captured_a: Array = first.get_meta("potok_8d2b1b_records", [])
	var captured_b: Array = second.get_meta("potok_8d2b1b_records", [])
	if not _check(captured_a.size() == 1 and captured_b.size() == 1
			and captured_a[0].get("phase") == "StateEnter"
			and captured_b[0].get("phase") == "StateEnter"
			and captured_a[0].get("issued") == true
			and captured_a[0].get("can_read_in_callback") == true,
			"Both controllers invoke initial SDK Enter once and A has scoped read access"):
		first.visual_program_enabled = false
		second.visual_program_enabled = false
		first.queue_free()
		second.queue_free()
		get_tree().quit(1)
		return
	var expired: FlowFSMOperations = captured_a[0].get("operations") as FlowFSMOperations
	_check(expired != null and not expired.has_state(idle_id),
		"SDK facade expires immediately when its initial Enter callback returns")

	var temporary: String = runtime_a.register_state(
		mid, template_id, "", FlowFSMDynamicStateRecord.Lifetime.EPHEMERAL,
		{"kind": "ephemeral", "nested": {"count": 1}}
	)
	var session: String = runtime_a.register_state(
		mid, template_id, "", FlowFSMDynamicStateRecord.Lifetime.SESSION,
		{"kind": "session", "nested": {"count": 2}}
	)
	var persistent: String = runtime_a.register_state(
		mid, template_id, "", FlowFSMDynamicStateRecord.Lifetime.PERSISTENT,
		{"kind": "persistent", "nested": {"count": 3}}
	)
	var peer: String = runtime_b.register_state(
		mid, template_id, "", FlowFSMDynamicStateRecord.Lifetime.SESSION,
		{"kind": "independent", "nested": {"count": 99}}
	)
	if not _check(FlowId.is_valid(temporary) and FlowId.is_valid(session)
			and FlowId.is_valid(persistent) and FlowId.is_valid(peer)
			and runtime_a.get_dynamic_state_ids(mid) == [temporary, session, persistent]
			and runtime_b.get_dynamic_state_ids(mid) == [peer],
			"All three lifetime policies and independent peer alias register"):
		first.visual_program_enabled = false
		second.visual_program_enabled = false
		first.queue_free()
		second.queue_free()
		get_tree().quit(1)
		return

	_check(runtime_a.change_state(mid, persistent),
		"Persistent alias activation is queued before shutdown")
	runtime_a.tick(0.1, FlowStateMachineDefinition.TickMode.MANUAL)
	_check(runtime_a.get_active_state_id(mid) == persistent
		and runtime_a.pending_request_count() == 0,
		"Persistent alias is active before stop")
	_check(runtime_a.change_state(mid, temporary)
		and runtime_a.change_state(mid, session)
		and runtime_a.emit_event(mid, &"unused", {"source": "before_stop"}),
		"Mixed direct and event requests are accepted by old runtime")
	_check(runtime_b.change_state(mid, template_id),
		"Independent peer queues an authored transition")
	_check(runtime_a.pending_request_count() == 3
		and runtime_b.pending_request_count() == 1,
		"Old and independent queues contain their own pending requests")

	runtime_a.state_exited.connect(_on_exit_a)
	runtime_a.machine_stopped.connect(_on_stopped_a)
	_a_trace.clear()
	_b_trace.clear()
	first.visual_program_enabled = false
	_check(first.get_fsm_runtime() == null and not runtime_a.is_running()
		and runtime_a.get_active_state_id(mid).is_empty()
		and runtime_a.get_dynamic_state_ids(mid).is_empty()
		and runtime_a.pending_request_count() == 0,
		"Disabling first controller stops old runtime and clears ALL lifetimes and queue")
	_check(_a_trace == [
		"StateExit:worker-exit",
		"Exit:" + persistent,
		"Stopped:" + persistent
	], "Stop executes one active alias Exit and machine Stopped with no stale commits")

	captured_a = first.get_meta("potok_8d2b1b_records", [])
	_check(captured_a.size() == 2
		and captured_a[1].get("phase") == "StateExit"
		and captured_a[1].get("can_read_in_callback") == false,
		"Shutdown exit callback cannot use SDK operations on disabled controller")
	var shutdown_sdk: FlowFSMOperations = null
	if captured_a.size() >= 2:
		shutdown_sdk = captured_a[1].get("operations") as FlowFSMOperations
	_check(expired != null and not expired.has_state(persistent)
		and not expired.change_state(idle_id)
		and expired.register_state(template_id) == ""
		and expired.get_state_data(persistent).is_empty(),
		"Old Enter facade cannot read or mutate detached runtime after stop")
	if shutdown_sdk != null:
		_check(not shutdown_sdk.has_state(template_id)
			and not shutdown_sdk.change_state(idle_id)
			and shutdown_sdk.register_state(template_id) == "",
			"Old shutdown Exit facade cannot mutate after its callback")
	_check(runtime_a.register_state(mid, template_id) == ""
		and not runtime_a.change_state(mid, idle_id)
		and runtime_a.pending_request_count() == 0,
		"Stopped runtime instance cannot accept new aliases or stale commands")
	_check(runtime_b.is_running()
		and runtime_b.get_dynamic_state_ids(mid) == [peer]
		and runtime_b.get_dynamic_state_data(mid, peer)
			== {"kind": "independent", "nested": {"count": 99}}
		and runtime_b.get_active_state_id(mid) == idle_id
		and runtime_b.pending_request_count() == 1
		and _b_trace.is_empty(),
		"Stopping A leaves controller B, its data and pending request untouched")

	_a_trace.clear()
	first.visual_program_enabled = true
	var restarted: FlowFSMRuntime = first.get_fsm_runtime()
	if not _check(restarted != null and restarted != runtime_a and restarted.is_running(),
			"Re-enabling same PVController allocates a fresh running runtime"):
		first.queue_free()
		second.visual_program_enabled = false
		second.queue_free()
		get_tree().quit(1)
		return
	captured_a = first.get_meta("potok_8d2b1b_records", [])
	_check(captured_a.size() == 3
		and captured_a[2].get("phase") == "StateEnter"
		and captured_a[2].get("issued") == true
		and captured_a[2].get("can_read_in_callback") == true,
		"Fresh runtime invokes exactly one new authorized Enter callback")
	_check(_a_trace == ["StateEnter:idle-enter"],
		"Restart enters only authored initial state once")
	_check(restarted.get_active_state_id(mid) == idle_id
		and restarted.get_dynamic_state_ids(mid).is_empty()
		and restarted.pending_request_count() == 0,
		"Restart restores none of EPHEMERAL, SESSION, PERSISTENT automatically")
	for old_id: String in [temporary, session, persistent]:
		_check(not restarted.has_state(mid, old_id)
			and restarted.get_dynamic_state_lifetime(mid, old_id) == -1
			and restarted.get_dynamic_state_data(mid, old_id).is_empty()
			and not restarted.change_state(mid, old_id),
			"Restart refuses stale alias identity: " + old_id)
	_check(restarted.pending_request_count() == 0,
		"Old direct requests and event do not reappear on fresh runtime")
	restarted.tick(0.1, FlowStateMachineDefinition.TickMode.MANUAL)
	_check(restarted.get_active_state_id(mid) == idle_id
		and restarted.pending_request_count() == 0,
		"First new manual tick never processes requests from old runtime")
	_check(expired.register_state(template_id) == ""
		and not expired.change_state(idle_id)
		and expired.get_state_data(session).is_empty(),
		"Pre-stop SDK capability cannot affect the restarted runtime")
	if shutdown_sdk != null:
		_check(shutdown_sdk.register_state(template_id) == ""
			and not shutdown_sdk.change_state(idle_id),
			"Shutdown SDK capability remains expired across restart")
	_check(restarted.pending_request_count() == 0
		and restarted.get_dynamic_state_ids(mid).is_empty(),
		"No stale SDK capability can pollute the fresh queue or registry")
	var fresh: String = restarted.register_state(
		mid, template_id, "", FlowFSMDynamicStateRecord.Lifetime.SESSION,
		{"origin": "fresh-runtime"}
	)
	_check(FlowId.is_valid(fresh) and not [temporary, session, persistent].has(fresh)
		and restarted.get_dynamic_state_ids(mid) == [fresh],
		"New runtime permits a new alias without resurrecting old registry")
	_check(expired.register_state(template_id) == ""
		and restarted.get_dynamic_state_ids(mid) == [fresh],
		"Retained old facade cannot add or remove new instance's fresh alias")

	runtime_b.tick(0.1, FlowStateMachineDefinition.TickMode.MANUAL)
	_check(runtime_b.get_active_state_id(mid) == template_id
		and runtime_b.pending_request_count() == 0
		and runtime_b.get_dynamic_state_ids(mid) == [peer],
		"Unstopped controller B eventually executes its own pending transition")
	_check(restarted.get_active_state_id(mid) == idle_id
		and restarted.get_dynamic_state_ids(mid) == [fresh]
		and graph.state_machines == [machine]
		and machine.states == [idle, template]
		and not FlowGraphValidator.validate(graph).has_errors(),
		"Other controller tick and full lifecycle preserve A and authored graph")

	first.visual_program_enabled = false
	second.visual_program_enabled = false
	first.queue_free()
	second.queue_free()
	await get_tree().process_frame
	if _failures.is_empty():
		print("[Flujo] Potok 8D2-B1B lifetime stop restart and SDK expiry passed")
	else:
		for failure: String in _failures:
			push_error("[Flujo] Potok 8D2-B1B: " + failure)
	get_tree().quit(0 if _failures.is_empty() else 1)


func _probe(script: Script, authored_id: String) -> FlowBlock:
	var block: FlowBlock = script.new() as FlowBlock
	if block != null:
		block.set("authored_state_id", authored_id)
	return block


func _printer(message: String) -> FlowPrintBlock:
	var block: FlowPrintBlock = FlowPrintBlock.new()
	block.text = message
	return block


func _on_output_a(_controller: Node, _container: String, _block: String,
		message: String, phase: StringName) -> void:
	_a_trace.append(String(phase) + ":" + message)


func _on_output_b(_controller: Node, _container: String, _block: String,
		message: String, phase: StringName) -> void:
	_b_trace.append(String(phase) + ":" + message)


func _on_exit_a(_machine_id: String, state_id: String) -> void:
	_a_trace.append("Exit:" + state_id)


func _on_stopped_a(_machine_id: String, state_id: String) -> void:
	_a_trace.append("Stopped:" + state_id)


func _check(ok: bool, description: String) -> bool:
	if not ok:
		_failures.append(description)
		push_error("[Flujo] Potok 8D2-B1B: " + description)
	return ok
