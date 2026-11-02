extends Node

## Potok 7D-2: typed last-by-event-name snapshot only in matching machine tick.
var failures: Array[String] = []

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	var graph := FlowGraph.new()
	graph.schema_version = FlowGraph.SCHEMA_VERSION_3
	graph.constructor = FlowConstructorDefinition.new()
	var a0 := FlowStateDefinition.new()
	var a1 := FlowStateDefinition.new()
	var b0 := FlowStateDefinition.new()
	var b1 := FlowStateDefinition.new()
	var operand := FlowEventPayloadValueSource.new(&"hit", "hp", Variant.Type.TYPE_INT)
	var comparison := FlowConditionComparison.new(
		FlowConditionOperatorCatalog.OPERATOR_GREATER_THAN,
		operand, FlowLiteralValueSource.new(Variant.Type.TYPE_INT, 5))
	var condition := FlowConditionValueSource.new([comparison], [])
	for pair in [[a0,a1],[b0,b1]]:
		var edge := FlowStateTransitionDefinition.new()
		edge.trigger = FlowStateTransitionDefinition.Trigger.CONDITION
		edge.condition = condition
		edge.target_state_id = (pair[1] as FlowStateDefinition).get_internal_id()
		(pair[0] as FlowStateDefinition).transitions = [edge]
	var a := _machine([a0,a1], a0.get_internal_id())
	var b := _machine([b0,b1], b0.get_internal_id())
	graph.state_machines = [a,b]
	_check(not FlowGraphValidator.validate(graph).has_errors(), "Typed event field source validates")
	var first := PVController.new()
	first.flow_graph = graph
	add_child(first)
	var second := PVController.new()
	second.flow_graph = graph
	add_child(second)
	await get_tree().process_frame
	var rt: FlowFSMRuntime = first.get_fsm_runtime()
	var other: FlowFSMRuntime = second.get_fsm_runtime()
	if not _check(rt != null and other != null and rt.is_running() and other.is_running(),
			"Independent controllers start"):
		get_tree().quit(1)
		return
	first.set_process(false)
	first.set_physics_process(false)
	second.set_process(false)
	second.set_physics_process(false)
	var aid: String = a.get_internal_id()
	var bid: String = b.get_internal_id()
	var ctx: FlowValueResolutionContext = first.get_value_resolution_context()
	_check(not operand.resolve(ctx).success, "No ambient event packet available")
	var seen: Array[String] = []
	rt.event_consumed.connect(func(mid: String, event_name: StringName, _payload: Dictionary) -> void:
		seen.append(mid + ":" + String(event_name))
	)
	rt.tick(0.1, FlowStateMachineDefinition.TickMode.MANUAL)
	_check(rt.get_active_state_id(aid) == a0.get_internal_id(), "No event means no condition transition")
	_check(rt.emit_event(aid, &"hit", {"hp": "7"}), "Text payload admitted JSON-safe")
	rt.tick(0.1, FlowStateMachineDefinition.TickMode.MANUAL)
	_check(rt.get_active_state_id(aid) == a0.get_internal_id(), "String is never coerced to int")
	_check(not operand.resolve(ctx).success, "Payload cleared after matching tick")
	_check(rt.emit_event(aid, &"other", {"hp": 99}), "Different event name admitted")
	rt.tick(0.1, FlowStateMachineDefinition.TickMode.MANUAL)
	_check(rt.get_active_state_id(aid) == a0.get_internal_id(), "Other event name is invisible to hit")
	_check(rt.emit_event(aid, &"hit", {"hp": 8}), "Typed hit accepted")
	_check(rt.emit_event(aid, &"hit", {"hp": 2}), "Second hit accepted FIFO")
	rt.tick(0.1, FlowStateMachineDefinition.TickMode.MANUAL)
	_check(rt.get_active_state_id(aid) == a0.get_internal_id(), "Latest hit wins within same tick")
	_check(rt.emit_event(aid, &"hit", {"hp": 3}), "Low hit accepted")
	_check(rt.emit_event(aid, &"hit", {"hp": 9}), "Last high hit accepted")
	rt.tick(0.1, FlowStateMachineDefinition.TickMode.MANUAL)
	_check(rt.get_active_state_id(aid) == a1.get_internal_id(), "Last high hit activates condition")
	_check(rt.get_active_state_id(bid) == b0.get_internal_id(), "Other machine does not see A hit")
	_check(other.get_active_state_id(aid) == a0.get_internal_id(), "Second controller has no packet")
	_check(other.emit_event(aid, &"hit", {"hp": 8}), "Second controller independent hit")
	other.tick(0.1, FlowStateMachineDefinition.TickMode.MANUAL)
	_check(other.get_active_state_id(aid) == a1.get_internal_id(), "Second controller can transition alone")
	_check(rt.get_active_state_id(bid) == b0.get_internal_id(), "First B still untouched")
	_check(rt.emit_event(bid, &"hit", {"hp": 12}), "First B independent hit")
	rt.tick(0.1, FlowStateMachineDefinition.TickMode.MANUAL)
	_check(rt.get_active_state_id(bid) == b1.get_internal_id(), "First B reacts only to own hit")
	_check(not operand.resolve(ctx).success, "No stale packet after B tick")
	_check(seen.size() == 7, "Event consumption remains exactly once per delivered packet")
	_check(not FlowGraphValidator.validate(graph).has_errors(), "Authored graph unchanged")
	first.visual_program_enabled = false
	second.visual_program_enabled = false
	first.queue_free()
	second.queue_free()
	await get_tree().process_frame
	if failures.is_empty():
		print("[Flujo] Potok 7D-2 typed event field tick isolation passed")
	get_tree().quit(0 if failures.is_empty() else 1)

func _machine(states: Array[FlowStateDefinition], initial: String) -> FlowStateMachineDefinition:
	var machine := FlowStateMachineDefinition.new()
	machine.states = states
	machine.initial_state_id = initial
	machine.tick_mode = FlowStateMachineDefinition.TickMode.MANUAL
	return machine

func _check(ok: bool, message: String) -> bool:
	if not ok:
		failures.append(message)
		push_error("[Flujo] Potok 7D-2: " + message)
	return ok
