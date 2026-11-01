extends Node

## Potok 6G — bounded packet work per machine and deterministic carryover.
var failures: Array[String] = []
var seen_a: Array[String] = []
var seen_other: Array[String] = []
var deferred: Array[String] = []
var transitions: int = 0
var callback_queued: bool = false

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	var graph := FlowGraph.new()
	graph.schema_version = FlowGraph.SCHEMA_VERSION_3
	graph.constructor = FlowConstructorDefinition.new()
	var a0 := FlowStateDefinition.new()
	var b0 := FlowStateDefinition.new()
	var b1 := FlowStateDefinition.new()
	var c0 := FlowStateDefinition.new()
	var edge := FlowStateTransitionDefinition.new()
	edge.trigger = FlowStateTransitionDefinition.Trigger.EVENT
	edge.event_name = &"go"
	edge.target_state_id = b1.get_internal_id()
	b0.transitions = [edge]
	var a := _machine([a0], a0.get_internal_id(), FlowStateMachineDefinition.TickMode.MANUAL)
	var b := _machine([b0, b1], b0.get_internal_id(), FlowStateMachineDefinition.TickMode.MANUAL)
	var c := _machine([c0], c0.get_internal_id(), FlowStateMachineDefinition.TickMode.PHYSICS)
	graph.state_machines = [a, b, c]
	_check(not FlowGraphValidator.validate(graph).has_errors(), "Fixture validates")
	var controller := PVController.new()
	controller.flow_graph = graph
	add_child(controller)
	await get_tree().process_frame
	var runtime: FlowFSMRuntime = controller.get_fsm_runtime()
	if not _check(runtime != null and runtime.is_running(), "Runtime starts"):
		controller.queue_free()
		get_tree().quit(1)
		return
	controller.set_process(false)
	controller.set_physics_process(false)
	var aid: String = a.get_internal_id()
	var bid: String = b.get_internal_id()
	var cid: String = c.get_internal_id()
	runtime.work_budget_deferred.connect(func(mid: String, count: int) -> void:
		deferred.append(mid + ":" + str(count))
	)
	runtime.event_consumed.connect(func(mid: String, name: StringName, _payload: Dictionary) -> void:
		if mid == aid:
			seen_a.append(String(name))
		else:
			seen_other.append(mid + ":" + String(name))
	)
	runtime.transition_committed.connect(func(_id: String, _from: String, _to: String, _trigger: String) -> void:
		transitions += 1
	)
	runtime.state_updated.connect(func(mid: String, _state: String) -> void:
		if mid == aid and not callback_queued:
			callback_queued = true
			_check(runtime.emit_event(aid, &"callback"), "Update callback can queue a future event")
			runtime.tick(0.1, FlowStateMachineDefinition.TickMode.MANUAL)
	)
	for i: int in 40:
		_check(runtime.emit_event(aid, StringName("e_%02d" % i)), "A event %d admitted" % i)
	_check(runtime.emit_event(bid, &"go"), "B event admitted")
	_check(runtime.emit_event(cid, &"physics"), "Other-clock event admitted")
	_check(runtime.pending_request_count() == 42, "All original events queued")
	runtime.tick(0.1, FlowStateMachineDefinition.TickMode.MANUAL)
	_check(FlowFSMRuntime.MAX_REQUESTS_PER_MACHINE_TICK == 32, "Stable per-machine budget")
	_check(seen_a.size() == 32, "A consumes at most 32 packets on first tick")
	for i: int in seen_a.size():
		_check(seen_a[i] == "e_%02d" % i, "A FIFO prefix item %d" % i)
	_check(deferred == [aid + ":8"], "Exactly eight same-clock events deferred once")
	_check(seen_other == [bid + ":go"], "Independent machine B is not starved")
	_check(runtime.get_active_state_id(bid) == b1.get_internal_id(), "B commits despite A flood")
	_check(runtime.get_active_state_id(cid) == c0.get_internal_id(), "Physics machine untouched")
	_check(transitions == 1, "At most one B transition")
	_check(runtime.pending_request_count() == 10, "A surplus, callback and other-clock event survive")
	runtime.tick(0.1, FlowStateMachineDefinition.TickMode.MANUAL)
	_check(seen_a.size() == 41, "Remaining eight plus callback delivered on later tick")
	for i: int in 40:
		_check(seen_a[i] == "e_%02d" % i, "Full A FIFO event %d" % i)
	_check(seen_a.back() == "callback", "Callback-generated event comes after older carryover")
	_check(deferred == [aid + ":8"], "No duplicate budget signal without surplus")
	_check(runtime.pending_request_count() == 1, "Only other-clock item remains")
	runtime.tick(0.1, FlowStateMachineDefinition.TickMode.PHYSICS)
	_check(seen_other == [bid + ":go", cid + ":physics"], "Physics item delivered once")
	_check(runtime.pending_request_count() == 0, "No silently lost packet or leftover")
	_check(transitions == 1, "Exactly one authored transition")
	_check(not FlowGraphValidator.validate(graph).has_errors(), "Authored graph unchanged")
	controller.visual_program_enabled = false
	controller.queue_free()
	await get_tree().process_frame
	if failures.is_empty():
		print("[Flujo] Potok 6G fair packet-work budget passed")
	get_tree().quit(0 if failures.is_empty() else 1)

func _machine(states: Array[FlowStateDefinition], first: String, mode: int) -> FlowStateMachineDefinition:
	var machine := FlowStateMachineDefinition.new()
	machine.states = states
	machine.initial_state_id = first
	machine.tick_mode = mode
	return machine

func _check(ok: bool, msg: String) -> bool:
	if not ok:
		failures.append(msg)
		push_error("[Flujo] Potok 6G: " + msg)
	return ok
