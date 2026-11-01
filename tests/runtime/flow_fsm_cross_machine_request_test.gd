extends Node
var errors: Array[String] = []
var events: Array[String] = []
var requests: Array[bool] = []

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	var graph := FlowGraph.new()
	graph.schema_version = FlowGraph.SCHEMA_VERSION_3
	graph.constructor = FlowConstructorDefinition.new()
	var a0 := _state("A0")
	var b0 := _state("B0")
	var b1 := _state("B1")
	var a := _machine([a0], a0.get_internal_id(), FlowStateMachineDefinition.TickMode.MANUAL)
	var b := _machine([b0, b1], b0.get_internal_id(), FlowStateMachineDefinition.TickMode.PHYSICS)
	graph.state_machines = [a, b]
	_check(not FlowGraphValidator.validate(graph).has_errors(), "Graph valid")
	var ctrl := PVController.new()
	ctrl.flow_graph = graph
	ctrl.runtime_output.entry_message_emitted.connect(_output)
	add_child(ctrl)
	await get_tree().process_frame
	var rt: FlowFSMRuntime = ctrl.get_fsm_runtime()
	if not _check(rt != null and rt.is_running(), "Runtime starts"):
		get_tree().quit(1)
		return
	ctrl.set_process(false)
	ctrl.set_physics_process(false)
	var aid: String = a.get_internal_id()
	var bid: String = b.get_internal_id()
	_check(not rt.request_transition(aid, b1.get_internal_id()), "Foreign target rejected")
	_check(not rt.request_transition("unknown", b1.get_internal_id()), "Unknown machine rejected")
	_check(rt.pending_request_count() == 0, "No invalid requests admitted")
	rt.state_updated.connect(func(id: String, _sid: String) -> void:
		if id == aid and requests.is_empty():
			requests.append(rt.request_transition(bid, b1.get_internal_id()))
			rt.tick(0.1, FlowStateMachineDefinition.TickMode.PHYSICS)
	)
	rt.tick(0.1, FlowStateMachineDefinition.TickMode.MANUAL)
	_check(requests == [true], "Source Update queues destination request")
	_check(rt.get_active_state_id(bid) == b0.get_internal_id(), "No recursive B transition")
	_check(rt.pending_request_count() == 1, "Cross-machine request retained")
	rt.tick(0.1, FlowStateMachineDefinition.TickMode.MANUAL)
	_check(rt.pending_request_count() == 1, "A clock retains B request")
	var before: int = events.size()
	rt.tick(0.1, FlowStateMachineDefinition.TickMode.PHYSICS)
	_check(rt.get_active_state_id(bid) == b1.get_internal_id(), "B changes on B clock")
	_check(events.slice(before) == ["StateUpdate:B0", "StateExit:B0", "StateEnter:B1"], "Atomic target lifecycle")
	_check(rt.pending_request_count() == 0, "B request consumed once")
	_check(rt.get_active_state_id(aid) == a0.get_internal_id(), "A unchanged")
	rt.tick(0.1, FlowStateMachineDefinition.TickMode.PHYSICS)
	_check(events.back() == "StateUpdate:B1", "New B Update deferred")
	ctrl.visual_program_enabled = false
	ctrl.queue_free()
	await get_tree().process_frame
	get_tree().quit(0 if errors.is_empty() else 1)

func _state(name: String) -> FlowStateDefinition:
	var state := FlowStateDefinition.new()
	state.display_name = name
	var enter := FlowPrintBlock.new()
	enter.text = name
	var update := FlowPrintBlock.new()
	update.text = name
	var exit := FlowPrintBlock.new()
	exit.text = name
	state.enter_blocks = [enter]
	state.blocks = [update]
	state.exit_blocks = [exit]
	return state

func _machine(states: Array[FlowStateDefinition], start: String, mode: int) -> FlowStateMachineDefinition:
	var m := FlowStateMachineDefinition.new()
	m.states = states
	m.initial_state_id = start
	m.tick_mode = mode
	return m

func _output(_ctrl: Node, _container: String, _block: String, value: String, phase: StringName) -> void:
	events.append(String(phase) + ":" + value)

func _check(ok: bool, message: String) -> bool:
	if not ok:
		errors.append(message)
		push_error("Potok 6A: " + message)
	return ok
