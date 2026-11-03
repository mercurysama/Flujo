extends Node

## Potok 8D2-B1A: EPHEMERAL active on reset; SESSION/PERSISTENT data and
## identity survive. The second PVController is intentionally not reset.
var _failures: Array[String] = []
var _a_trace: Array[String] = []
var _b_trace: Array[String] = []


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var graph: FlowGraph = FlowGraph.new()
	graph.schema_version = FlowGraph.SCHEMA_VERSION_3
	graph.constructor = FlowConstructorDefinition.new()

	var idle: FlowStateDefinition = FlowStateDefinition.new()
	idle.display_name = "Idle"
	idle.enter_blocks = [_printer("idle-enter")]
	idle.exit_blocks = [_printer("idle-exit")]
	var template: FlowStateDefinition = FlowStateDefinition.new()
	template.display_name = "Worker"
	template.enter_blocks = [_printer("worker-enter")]
	template.exit_blocks = [_printer("worker-exit")]
	var machine: FlowStateMachineDefinition = FlowStateMachineDefinition.new()
	machine.tick_mode = FlowStateMachineDefinition.TickMode.MANUAL
	machine.states = [idle, template]
	machine.initial_state_id = idle.get_internal_id()
	graph.state_machines = [machine]
	if not _check(not FlowGraphValidator.validate(graph).has_errors(),
			"Authored schema 3 graph validates before runtime characterization"):
		get_tree().quit(1)
		return
	var mid: String = machine.get_internal_id()
	var initial_id: String = idle.get_internal_id()
	var template_id: String = template.get_internal_id()

	var controller_a: PVController = PVController.new()
	controller_a.flow_graph = graph
	controller_a.runtime_output.entry_message_emitted.connect(_on_output_a)
	var controller_b: PVController = PVController.new()
	controller_b.flow_graph = graph
	controller_b.runtime_output.entry_message_emitted.connect(_on_output_b)
	add_child(controller_a)
	add_child(controller_b)
	await get_tree().process_frame
	var runtime_a: FlowFSMRuntime = controller_a.get_fsm_runtime()
	var runtime_b: FlowFSMRuntime = controller_b.get_fsm_runtime()
	if not _check(runtime_a != null and runtime_b != null
			and runtime_a != runtime_b and runtime_a.is_running()
			and runtime_b.is_running(), "Two controllers own running independent runtimes"):
		controller_a.queue_free()
		controller_b.queue_free()
		get_tree().quit(1)
		return
	runtime_a.state_exited.connect(_on_exit_a)
	runtime_a.state_entered.connect(_on_enter_a)
	runtime_a.transition_committed.connect(_on_commit_a)

	var original_session: Dictionary = {
		"kind": "session", "nested": {"counter": 2, "labels": ["a", "b"]}
	}
	var original_persistent: Dictionary = {
		"kind": "persistent", "nested": {"counter": 3, "labels": ["c", "d"]}
	}
	var ephemeral: String = runtime_a.register_state(
		mid, template_id, "", FlowFSMDynamicStateRecord.Lifetime.EPHEMERAL,
		{"kind": "ephemeral", "nested": {"counter": 1}}
	)
	var session: String = runtime_a.register_state(
		mid, template_id, "", FlowFSMDynamicStateRecord.Lifetime.SESSION,
		original_session
	)
	var persistent: String = runtime_a.register_state(
		mid, template_id, "", FlowFSMDynamicStateRecord.Lifetime.PERSISTENT,
		original_persistent
	)
	var peer: String = runtime_b.register_state(
		mid, template_id, "", FlowFSMDynamicStateRecord.Lifetime.SESSION,
		{"kind": "peer", "nested": {"counter": 99}}
	)
	if not _check(FlowId.is_valid(ephemeral) and FlowId.is_valid(session)
			and FlowId.is_valid(persistent) and FlowId.is_valid(peer)
			and runtime_a.get_dynamic_state_ids(mid) == [ephemeral, session, persistent]
			and runtime_b.get_dynamic_state_ids(mid) == [peer],
			"Three policies and independent peer alias registered in stable order"):
		controller_a.visual_program_enabled = false
		controller_b.visual_program_enabled = false
		controller_a.queue_free()
		controller_b.queue_free()
		get_tree().quit(1)
		return

	original_session["nested"]["counter"] = 200
	original_persistent["nested"]["labels"].append("caller-modified")
	var detached: Dictionary = runtime_a.get_dynamic_state_data(mid, session)
	detached["nested"]["counter"] = 400
	_check(runtime_a.get_dynamic_state_data(mid, session) == {
		"kind": "session", "nested": {"counter": 2, "labels": ["a", "b"]}
	}, "Session registration and readback are detached from caller")
	_check(runtime_a.get_dynamic_state_data(mid, persistent) == {
		"kind": "persistent", "nested": {"counter": 3, "labels": ["c", "d"]}
	}, "Persistent registration uses a nested deep copy")

	_check(runtime_a.change_state(mid, ephemeral),
		"Request to activate EPHEMERAL alias is accepted")
	runtime_a.tick(0.1, FlowStateMachineDefinition.TickMode.MANUAL)
	_check(runtime_a.get_active_state_id(mid) == ephemeral,
		"EPHEMERAL alias is active before reset")
	_check(runtime_a.pending_request_count() == 0,
		"Initial activation consumed its request")
	_check(runtime_a.change_state(mid, session)
		and runtime_a.emit_event(mid, &"ignored", {"sequence": 1}),
		"Two mixed requests are queued on A before reset")
	_check(runtime_b.change_state(mid, template_id),
		"Independent controller B owns an unprocessed authored transition")
	_check(runtime_a.pending_request_count() == 2
		and runtime_b.pending_request_count() == 1
		and runtime_b.get_active_state_id(mid) == initial_id,
		"Queues are isolated before reset")

	_a_trace.clear()
	_b_trace.clear()
	_check(runtime_a.reset(), "Reset accepts running controller outside tick")
	_check(_a_trace == [
		"StateExit:worker-exit", "Exit:" + ephemeral,
		"StateEnter:idle-enter", "Enter:" + initial_id
	], "EPHEMERAL active reset performs Exit once and authored Enter once")
	_check(runtime_a.get_active_state_id(mid) == initial_id
		and not runtime_a.has_state(mid, ephemeral)
		and runtime_a.get_dynamic_state_lifetime(mid, ephemeral) == -1
		and runtime_a.get_dynamic_state_data(mid, ephemeral).is_empty(),
		"Reset selects authored initial and completely removes EPHEMERAL alias")
	_check(runtime_a.get_dynamic_state_ids(mid) == [session, persistent]
		and runtime_a.get_dynamic_state_lifetime(mid, session)
			== FlowFSMDynamicStateRecord.Lifetime.SESSION
		and runtime_a.get_dynamic_state_lifetime(mid, persistent)
			== FlowFSMDynamicStateRecord.Lifetime.PERSISTENT,
		"Reset preserves both surviving policies and original registration order")
	_check(runtime_a.get_dynamic_state_data(mid, session) == {
		"kind": "session", "nested": {"counter": 2, "labels": ["a", "b"]}
	} and runtime_a.get_dynamic_state_data(mid, persistent) == {
		"kind": "persistent", "nested": {"counter": 3, "labels": ["c", "d"]}
	}, "Reset preserves all nested values of SESSION and PERSISTENT")
	_check(runtime_a.pending_request_count() == 0
		and runtime_b.pending_request_count() == 1
		and runtime_b.get_active_state_id(mid) == initial_id
		and runtime_b.get_dynamic_state_ids(mid) == [peer]
		and runtime_b.get_dynamic_state_data(mid, peer).get("nested", {}).get("counter") == 99
		and _b_trace.is_empty(),
		"Reset clears only controller A queue and never invokes controller B callbacks")

	_check(not runtime_a.change_state(mid, ephemeral)
		and runtime_a.pending_request_count() == 0,
		"Removed EPHEMERAL alias cannot receive new direct commands")
	_check(runtime_a.change_state(mid, session),
		"SESSION alias remains executable after reset")
	runtime_a.tick(0.1, FlowStateMachineDefinition.TickMode.MANUAL)
	_check(runtime_a.get_active_state_id(mid) == session
		and runtime_a.pending_request_count() == 0,
		"SESSION alias activates after reset using its unchanged ID")
	_check(runtime_a.change_state(mid, persistent),
		"PERSISTENT alias remains executable after reset")
	runtime_a.tick(0.1, FlowStateMachineDefinition.TickMode.MANUAL)
	_check(runtime_a.get_active_state_id(mid) == persistent,
		"PERSISTENT alias activates after reset using its unchanged ID")

	runtime_b.tick(0.1, FlowStateMachineDefinition.TickMode.MANUAL)
	_check(runtime_b.get_active_state_id(mid) == template_id
		and runtime_b.pending_request_count() == 0
		and runtime_b.get_dynamic_state_ids(mid) == [peer],
		"Controller B completes its originally pending transition independently")
	_check(runtime_a.get_active_state_id(mid) == persistent
		and runtime_a.get_dynamic_state_ids(mid) == [session, persistent],
		"Advancing B does not modify A state or registry")
	_check(graph.state_machines == [machine]
		and machine.states == [idle, template]
		and not FlowGraphValidator.validate(graph).has_errors(),
		"Reset, queued requests and alias lifecycle leave authored graph intact")

	controller_a.visual_program_enabled = false
	controller_b.visual_program_enabled = false
	controller_a.queue_free()
	controller_b.queue_free()
	await get_tree().process_frame
	if _failures.is_empty():
		print("[Flujo] Potok 8D2-B1A lifetime reset and controller isolation passed")
	else:
		for failure: String in _failures:
			push_error("[Flujo] Potok 8D2-B1A: " + failure)
	get_tree().quit(0 if _failures.is_empty() else 1)


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


func _on_enter_a(_machine_id: String, state_id: String) -> void:
	_a_trace.append("Enter:" + state_id)


func _on_commit_a(_machine_id: String, source_id: String,
		target_id: String, trigger: String) -> void:
	_a_trace.append("Commit:" + source_id + ">" + target_id + ":" + trigger)


func _check(condition: bool, description: String) -> bool:
	if not condition:
		_failures.append(description)
		push_error("[Flujo] Potok 8D2-B1A: " + description)
	return condition
