extends Node

## Potok 6F-1: typed direct request envelope, FIFO and old signal compatibility.
var failures: Array[String] = []
var rejections: Array[String] = []
var order: Array[String] = []
var notices: Array[Dictionary] = []
var legacy_count: int = 0

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	var graph := FlowGraph.new()
	graph.schema_version = FlowGraph.SCHEMA_VERSION_3
	graph.constructor = FlowConstructorDefinition.new()
	var a0 := FlowStateDefinition.new()
	var a1 := FlowStateDefinition.new()
	var p0 := FlowStateDefinition.new()
	var p1 := FlowStateDefinition.new()
	var p2 := FlowStateDefinition.new()
	var a := _machine([a0, a1], a0.get_internal_id(), FlowStateMachineDefinition.TickMode.MANUAL)
	var p := _machine([p0, p1, p2], p0.get_internal_id(), FlowStateMachineDefinition.TickMode.PHYSICS)
	graph.state_machines = [a, p]
	_check(not FlowGraphValidator.validate(graph).has_errors(), "Valid authored graph")
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
	var pid: String = p.get_internal_id()
	runtime.request_rejected.connect(func(id: String, kind: StringName, code: StringName) -> void:
		rejections.append(id + ":" + String(kind) + ":" + String(code))
	)
	runtime.transition_committed.connect(func(mid: String, _from: String, _to: String, _trigger: String) -> void:
		legacy_count += 1
		order.append("legacy:" + mid)
	)
	runtime.direct_transition_committed.connect(func(mid: String, _from: String, _to: String, reason: StringName, packet: Dictionary) -> void:
		order.append("direct:" + mid + ":" + String(reason))
		notices.append({"machine": mid, "reason": reason, "payload": packet.duplicate(true)})
		if reason == &"primary":
			packet["nested"]["n"] = -100
			_check(runtime.request_transition(aid, a1.get_internal_id()), "Metadata callback defers to A")
			runtime.tick(0.1, FlowStateMachineDefinition.TickMode.MANUAL)
	)
	var invalid: Dictionary = {"node": controller}
	_check(not runtime.request_transition(pid, p1.get_internal_id(), &"unsafe", invalid),
		"Reject live Node in payload")
	_check(rejections.back() == pid + ":direct:invalid_payload", "Invalid payload diagnostic")
	_check(not runtime.request_transition(pid, p1.get_internal_id(), &"unsafe", {1: "value"}),
		"Reject nonstring dictionary key")
	_check(rejections.back() == pid + ":direct:invalid_payload", "Invalid key diagnostic")
	_check(not runtime.request_transition(pid, p1.get_internal_id(), &"long",
		{"large": "z".repeat(70000)}), "Reject oversized payload")
	_check(rejections.back() == pid + ":direct:invalid_payload", "Oversized payload diagnostic")
	_check(not runtime.request_transition(pid, p1.get_internal_id(),
		StringName("r".repeat(129))), "Reject oversized reason")
	_check(rejections.back() == pid + ":direct:invalid_reason", "Invalid reason diagnostic")
	_check(runtime.pending_request_count() == 0 and rejections.size() == 4,
		"No invalid direct packet enters queue")
	var original: Dictionary = {"nested": {"n": 3}, "label": "first"}
	_check(runtime.request_transition(pid, p1.get_internal_id(), &"primary", original),
		"Primary direct request admitted")
	_check(runtime.request_transition(pid, p2.get_internal_id(), &"secondary",
		{"label": "second"}), "Competing direct request admitted")
	original["nested"]["n"] = 999
	original["label"] = "mutated"
	var queued: Array = runtime.get("_pending_requests") as Array
	if queued.size() == 2:
		var stored: Dictionary = queued[0].get("payload", {})
		_check(stored.get("label") == "first", "Queued payload detached from caller")
		_check(stored.get("nested", {}).get("n") == 3, "Nested queued values copied")
	_check(rejections.size() == 4, "Accepted requests have no error signal")
	runtime.tick(0.1, FlowStateMachineDefinition.TickMode.MANUAL)
	_check(runtime.get_active_state_id(pid) == p0.get_internal_id(), "Other-clock command waits")
	_check(runtime.pending_request_count() == 2, "Other-clock queue preserved")
	runtime.tick(0.1, FlowStateMachineDefinition.TickMode.PHYSICS)
	_check(runtime.get_active_state_id(pid) == p1.get_internal_id(), "First direct FIFO wins")
	_check(runtime.get_active_state_id(aid) == a0.get_internal_id(), "Callback cannot force A")
	_check(runtime.pending_request_count() == 1, "Only callback-enqueued A remains")
	_check(order == ["legacy:" + pid, "direct:" + pid + ":primary"],
		"Existing four-argument signal fires first, metadata signal second")
	_check(notices.size() == 1 and notices[0].get("reason") == &"primary",
		"Only winning direct packet reports metadata")
	if notices.size() == 1:
		_check(notices[0].get("payload", {}).get("nested", {}).get("n") == 3,
			"Listener observes original deep-copied snapshot")
	_check(original["nested"]["n"] == 999, "Signal cannot alter original payload")
	runtime.tick(0.1, FlowStateMachineDefinition.TickMode.MANUAL)
	_check(runtime.get_active_state_id(aid) == a1.get_internal_id(),
		"Callback-generated request executes on next A clock")
	_check(runtime.pending_request_count() == 0, "All competing requests consumed")
	_check(notices.size() == 2 and notices[1].get("reason") == &"",
		"Legacy two-argument request produces empty metadata")
	_check(runtime.request_transition(pid, p1.get_internal_id()), "Self-target enqueued")
	runtime.tick(0.1, FlowStateMachineDefinition.TickMode.PHYSICS)
	_check(notices.size() == 2 and legacy_count == 2, "Self-target has no commit signals")
	_check(runtime.pending_request_count() == 0, "No-op direct request consumed")
	_check(not FlowGraphValidator.validate(graph).has_errors(), "Graph remains unmodified")
	controller.visual_program_enabled = false
	controller.queue_free()
	await get_tree().process_frame
	if failures.is_empty():
		print("[Flujo] Potok 6F-1 direct request metadata passed")
	get_tree().quit(0 if failures.is_empty() else 1)

func _machine(states: Array[FlowStateDefinition], initial: String, mode: int) -> FlowStateMachineDefinition:
	var machine := FlowStateMachineDefinition.new()
	machine.states = states
	machine.initial_state_id = initial
	machine.tick_mode = mode
	return machine

func _check(ok: bool, message: String) -> bool:
	if not ok:
		failures.append(message)
		push_error("[Flujo] Potok 6F-1: " + message)
	return ok
