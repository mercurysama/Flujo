extends Node

## Potok 8D2-B3A2: machine traversal order remains authored, even when
## cross-machine direct requests arrive in reverse order over two ticks.
var _errors: Array[String] = []
var _left: Array[String] = []
var _right: Array[String] = []


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var graph: FlowGraph = FlowGraph.new()
	graph.schema_version = FlowGraph.SCHEMA_VERSION_3
	graph.constructor = FlowConstructorDefinition.new()
	var a0: FlowStateDefinition = _state("A0")
	var a1: FlowStateDefinition = _state("A1")
	var a2: FlowStateDefinition = _state("A2")
	var b0: FlowStateDefinition = _state("B0")
	var b1: FlowStateDefinition = _state("B1")
	var b2: FlowStateDefinition = _state("B2")
	var ma: FlowStateMachineDefinition = _machine([a0, a1, a2], a0)
	var mb: FlowStateMachineDefinition = _machine([b0, b1, b2], b0)
	graph.state_machines = [ma, mb]
	if not _check(not FlowGraphValidator.validate(graph).has_errors(),
			"Two three-state authored MANUAL machines validate"):
		get_tree().quit(1)
		return
	var first: PVController = PVController.new()
	first.flow_graph = graph
	var second: PVController = PVController.new()
	second.flow_graph = graph
	add_child(first)
	add_child(second)
	await get_tree().process_frame
	var left: FlowFSMRuntime = first.get_fsm_runtime()
	var right: FlowFSMRuntime = second.get_fsm_runtime()
	if not _check(left != null and right != null and left != right
			and left.is_running() and right.is_running(),
			"Two independent live runtimes share only authored definitions"):
		first.queue_free()
		second.queue_free()
		get_tree().quit(1)
		return
	left.transition_committed.connect(_capture_left)
	right.transition_committed.connect(_capture_right)
	var ai: String = ma.get_internal_id()
	var bi: String = mb.get_internal_id()
	var expected: Array[String] = [
		_format(ai, a0, a1), _format(bi, b0, b1),
		_format(ai, a1, a2), _format(bi, b1, b2)
	]
	# Reverse request order is deliberate. The machine graph order, not
	# enqueue order across machines, determines the ordered commit trace.
	_check(left.change_state(bi, b1.get_internal_id())
			and left.change_state(ai, a1.get_internal_id())
			and right.change_state(bi, b1.get_internal_id())
			and right.change_state(ai, a1.get_internal_id()),
			"Both runtimes accept identical reverse-machine first wave")
	_check(left.pending_request_count() == 2
			and right.pending_request_count() == 2,
			"First wave has independent two-entry queues")
	left.tick(0.1, FlowStateMachineDefinition.TickMode.MANUAL)
	_check(_left == expected.slice(0, 2),
			"First wave commits A then B despite B then A enqueue order")
	_check(_right.is_empty() and right.pending_request_count() == 2,
			"Left-only tick leaves right untouched")
	right.tick(0.1, FlowStateMachineDefinition.TickMode.MANUAL)
	_check(_right == expected.slice(0, 2)
			and left.pending_request_count() == 0
			and right.pending_request_count() == 0,
			"Both first-wave traces and drained queues agree")

	_check(left.change_state(bi, b2.get_internal_id())
			and left.change_state(ai, a2.get_internal_id())
			and right.change_state(bi, b2.get_internal_id())
			and right.change_state(ai, a2.get_internal_id()),
			"Both runtimes accept identical reverse-machine second wave")
	right.tick(0.1, FlowStateMachineDefinition.TickMode.MANUAL)
	_check(_right == expected and _left == expected.slice(0, 2)
			and left.pending_request_count() == 2,
			"Right-only second tick remains isolated and ordered")
	left.tick(0.1, FlowStateMachineDefinition.TickMode.MANUAL)
	_check(_left == expected and _right == expected,
			"Both full four-transition traces match exact authored ordering")
	_check(left.pending_request_count() == 0
			and right.pending_request_count() == 0
			and left.get_active_state_id(ai) == a2.get_internal_id()
			and right.get_active_state_id(ai) == a2.get_internal_id()
			and left.get_active_state_id(bi) == b2.get_internal_id()
			and right.get_active_state_id(bi) == b2.get_internal_id(),
			"Queues drain and two machines end at matching second targets")
	_check(graph.state_machines == [ma, mb]
			and ma.states == [a0, a1, a2]
			and mb.states == [b0, b1, b2]
			and not FlowGraphValidator.validate(graph).has_errors(),
			"Two-wave replay never mutates shared authored state definitions")
	first.visual_program_enabled = false
	second.visual_program_enabled = false
	first.queue_free()
	second.queue_free()
	await get_tree().process_frame
	if _errors.is_empty():
		print("[Flujo] Potok 8D2-B3A2 ordered two-wave deterministic replay passed")
	else:
		for error: String in _errors:
			push_error("[Flujo] Potok 8D2-B3A2: " + error)
	get_tree().quit(0 if _errors.is_empty() else 1)


func _state(name: String) -> FlowStateDefinition:
	var result: FlowStateDefinition = FlowStateDefinition.new()
	result.display_name = name
	return result


func _machine(states: Array[FlowStateDefinition],
		initial: FlowStateDefinition) -> FlowStateMachineDefinition:
	var result: FlowStateMachineDefinition = FlowStateMachineDefinition.new()
	result.states = states
	result.initial_state_id = initial.get_internal_id()
	result.tick_mode = FlowStateMachineDefinition.TickMode.MANUAL
	return result


func _format(machine_id: String, old_state: FlowStateDefinition,
		new_state: FlowStateDefinition) -> String:
	return machine_id + ":" + old_state.get_internal_id() + ">" + new_state.get_internal_id() + ":direct"


func _capture_left(machine_id: String, previous_id: String,
		target_id: String, trigger_id: String) -> void:
	_left.append(machine_id + ":" + previous_id + ">" + target_id + ":" + trigger_id)


func _capture_right(machine_id: String, previous_id: String,
		target_id: String, trigger_id: String) -> void:
	_right.append(machine_id + ":" + previous_id + ">" + target_id + ":" + trigger_id)


func _check(ok: bool, description: String) -> bool:
	if not ok:
		_errors.append(description)
		push_error("[Flujo] Potok 8D2-B3A2 assertion: " + description)
	return ok
