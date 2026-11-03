extends Node

## Potok 10A-3: characterize preexisting public signals without a new debug API.
## Deliberately uses two PVController instances with one immutable authored graph.
var _failures: Array[String] = []
var _trace_a: Array[String] = []
var _trace_b: Array[String] = []
var _rejections: Array[String] = []
var _packets_a: Array[Dictionary] = []
var _commits_a: Array[String] = []
var _direct_reasons: Array[String] = []


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var graph: FlowGraph = FlowGraph.new()
	graph.schema_version = FlowGraph.SCHEMA_VERSION_3
	graph.constructor = FlowConstructorDefinition.new()
	var idle: FlowStateDefinition = FlowStateDefinition.new()
	idle.display_name = "Idle"
	var target: FlowStateDefinition = FlowStateDefinition.new()
	target.display_name = "Target"
	var edge: FlowStateTransitionDefinition = FlowStateTransitionDefinition.new()
	edge.trigger = FlowStateTransitionDefinition.Trigger.EVENT
	edge.event_name = &"go"
	edge.target_state_id = target.get_internal_id()
	idle.transitions = [edge]
	var machine: FlowStateMachineDefinition = FlowStateMachineDefinition.new()
	machine.display_name = "Observe"
	machine.states = [idle, target]
	machine.initial_state_id = idle.get_internal_id()
	machine.tick_mode = FlowStateMachineDefinition.TickMode.MANUAL
	graph.state_machines = [machine]
	_check(not FlowGraphValidator.validate(graph).has_errors(), "Authored test graph validates")
	var machine_id: String = machine.get_internal_id()
	var idle_id: String = idle.get_internal_id()
	var target_id: String = target.get_internal_id()
	var edge_id: String = edge.get_internal_id()

	var controller_a: PVController = PVController.new()
	controller_a.flow_graph = graph
	var controller_b: PVController = PVController.new()
	controller_b.flow_graph = graph
	add_child(controller_a)
	add_child(controller_b)
	await get_tree().process_frame
	var runtime_a: FlowFSMRuntime = controller_a.get_fsm_runtime()
	var runtime_b: FlowFSMRuntime = controller_b.get_fsm_runtime()
	if not _check(runtime_a != null and runtime_b != null and runtime_a != runtime_b
			and runtime_a.is_running() and runtime_b.is_running(),
			"Controllers own two isolated running runtimes"):
		controller_a.queue_free()
		controller_b.queue_free()
		_finish()
		return
	controller_a.set_process(false)
	controller_a.set_physics_process(false)
	controller_b.set_process(false)
	controller_b.set_physics_process(false)

	runtime_a.state_updated.connect(func(mid: String, _sid: String) -> void:
		if mid == machine_id:
			_trace_a.append("update")
	)
	runtime_a.event_consumed.connect(func(mid: String, event_name: StringName, payload: Dictionary) -> void:
		if mid == machine_id:
			_trace_a.append("consumed:" + String(event_name))
			_packets_a.append(payload.duplicate(true))
	)
	runtime_a.state_exited.connect(func(mid: String, _sid: String) -> void:
		if mid == machine_id:
			_trace_a.append("exit")
	)
	runtime_a.state_entered.connect(func(mid: String, _sid: String) -> void:
		if mid == machine_id:
			_trace_a.append("enter")
	)
	runtime_a.transition_committed.connect(func(mid: String, from_id: String, to_id: String, trigger_id: String) -> void:
		if mid == machine_id:
			_trace_a.append("commit")
			_commits_a.append(from_id + ">" + to_id + ":" + trigger_id)
	)
	runtime_a.direct_transition_committed.connect(func(mid: String, _from: String, _to: String, reason: StringName, _packet: Dictionary) -> void:
		if mid == machine_id:
			_trace_a.append("direct_metadata")
			_direct_reasons.append(String(reason))
	)
	runtime_a.request_rejected.connect(func(mid: String, kind: StringName, code: StringName) -> void:
		_rejections.append(mid + ":" + String(kind) + ":" + String(code))
	)
	runtime_b.state_updated.connect(func(mid: String, _sid: String) -> void:
		if mid == machine_id:
			_trace_b.append("update")
	)
	runtime_b.event_consumed.connect(func(mid: String, name: StringName, _packet: Dictionary) -> void:
		if mid == machine_id:
			_trace_b.append("consumed:" + String(name))
	)
	runtime_b.state_exited.connect(func(mid: String, _sid: String) -> void:
		if mid == machine_id:
			_trace_b.append("exit")
	)
	runtime_b.state_entered.connect(func(mid: String, _sid: String) -> void:
		if mid == machine_id:
			_trace_b.append("enter")
	)
	runtime_b.transition_committed.connect(func(mid: String, _from: String, _to: String, _trigger: String) -> void:
		if mid == machine_id:
			_trace_b.append("commit")
	)

	_check(not runtime_a.emit_event(machine_id, &""), "Empty event rejected")
	_check(_rejections == [machine_id + ":event:invalid_event_name"],
			"Rejection includes stable machine, kind and code")
	_check(runtime_a.pending_request_count() == 0 and runtime_b.pending_request_count() == 0,
			"Rejected event enqueues nowhere")
	var original: Dictionary = {"nested": {"number": 7}}
	_check(runtime_a.emit_event(machine_id, &"unmatched", original), "A accepts unmatched event")
	original["nested"]["number"] = 91
	_check(runtime_b.emit_event(machine_id, &"go"), "B independently accepts an event")
	runtime_a.tick(0.1, FlowStateMachineDefinition.TickMode.MANUAL)
	_check(_trace_a == ["update", "consumed:unmatched"],
			"Unmatched event yields Update and consumption without a transition")
	_check(_packets_a.size() == 1 and _packets_a[0].get("nested", {}).get("number") == 7,
			"Consumed payload is detached from caller edits")
	_check(runtime_a.get_active_state_id(machine_id) == idle_id
			and runtime_b.get_active_state_id(machine_id) == idle_id,
			"An unmatched event cannot change A or B")
	_check(runtime_a.pending_request_count() == 0 and runtime_b.pending_request_count() == 1
			and _trace_b.is_empty(), "A clock does not drain B queue")

	_trace_a.clear()
	_check(runtime_a.emit_event(machine_id, &"go"), "A independently accepts matching event")
	runtime_a.tick(0.1, FlowStateMachineDefinition.TickMode.MANUAL)
	_check(_trace_a == ["update", "consumed:go", "exit", "enter", "commit"],
			"Observable signal order is Update, consume, Exit, Enter, commit")
	_check(_commits_a == [idle_id + ">" + target_id + ":" + edge_id],
			"Commit signal identifies authored machine edge and states")
	_check(runtime_a.get_active_state_id(machine_id) == target_id
			and runtime_b.get_active_state_id(machine_id) == idle_id
			and runtime_b.pending_request_count() == 1 and _trace_b.is_empty(),
			"A commit leaves independent B unchanged and queued")
	runtime_b.tick(0.1, FlowStateMachineDefinition.TickMode.MANUAL)
	_check(_trace_b == ["update", "consumed:go", "exit", "enter", "commit"],
			"B emits same ordered public signals on its own tick")
	_check(runtime_b.get_active_state_id(machine_id) == target_id
			and runtime_b.pending_request_count() == 0, "B transitions only after B clock")

	_trace_a.clear()
	_check(runtime_a.request_transition(machine_id, idle_id, &"manual_debug"),
			"Existing direct request accepted")
	runtime_a.tick(0.1, FlowStateMachineDefinition.TickMode.MANUAL)
	_check(_trace_a == ["update", "exit", "enter", "commit", "direct_metadata"],
			"Direct metadata follows legacy commit without changing signal order")
	_check(_direct_reasons == ["manual_debug"], "Direct reason remains observable")
	_check(runtime_a.get_active_state_id(machine_id) == idle_id
			and runtime_b.get_active_state_id(machine_id) == target_id,
			"Direct request remains instance-local")
	_check(graph.state_machines.size() == 1 and graph.state_machines[0] == machine
			and machine.states.size() == 2 and machine.states[0] == idle
			and machine.states[1] == target and idle.transitions.size() == 1
			and idle.transitions[0] == edge
			and machine.initial_state_id == idle_id
			and edge.target_state_id == target_id
			and edge.get_internal_id() == edge_id
			and not FlowGraphValidator.validate(graph).has_errors(),
			"Observation and transitions never modify authored FlowGraph")

	controller_a.visual_program_enabled = false
	_check(not runtime_a.is_running() and runtime_b.is_running(),
			"Teardown of A stops only A")
	controller_a.queue_free()
	controller_b.queue_free()
	await get_tree().process_frame
	_finish()


func _check(condition: bool, description: String) -> bool:
	if not condition:
		_failures.append(description)
		push_error("[Flujo] Potok-10A3: " + description)
	return condition


func _finish() -> void:
	if _failures.is_empty():
		print("[Flujo] Potok-10A3 existing signal characterization passed")
	get_tree().quit(0 if _failures.is_empty() else 1)
