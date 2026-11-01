extends Node

## FSM-5E: self-target event must not suppress another eligible edge.
var _failures: Array[String] = []
var _commits: int = 0
var _entries: Array[String] = []


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var graph: FlowGraph = FlowGraph.new()
	graph.schema_version = FlowGraph.SCHEMA_VERSION_3
	graph.constructor = FlowConstructorDefinition.new()
	var idle: FlowStateDefinition = _state("Idle")
	var other: FlowStateDefinition = _state("Other")
	var disabled: FlowStateDefinition = _state("Disabled")
	disabled.enabled = false
	# A self edge may be authored but is an ignored no-op, just as for
	# conditional and explicit self requests. It must not shadow a valid edge.
	idle.transitions = [
		_edge(&"go", idle.get_internal_id(), 100),
		_edge(&"go", disabled.get_internal_id(), 80),
		_edge(&"go", other.get_internal_id(), 1),
	]
	var machine: FlowStateMachineDefinition = FlowStateMachineDefinition.new()
	machine.states = [idle, other, disabled]
	machine.initial_state_id = idle.get_internal_id()
	machine.tick_mode = FlowStateMachineDefinition.TickMode.MANUAL
	graph.state_machines = [machine]
	_check(not FlowGraphValidator.validate(graph).has_errors(),
		"Self edge and disabled destination remain valid authored definitions.")
	var controller: PVController = PVController.new()
	controller.flow_graph = graph
	controller.runtime_output.entry_message_emitted.connect(_on_output)
	add_child(controller)
	await get_tree().process_frame
	var runtime: FlowFSMRuntime = controller.get_fsm_runtime()
	if not _check(runtime != null and runtime.is_running(), "Runtime starts."):
		controller.queue_free()
		_finish()
		return
	controller.set_process(false)
	controller.set_physics_process(false)
	runtime.transition_committed.connect(_on_commit)
	var m: String = machine.get_internal_id()
	_check(runtime.emit_event(m, &"go"), "Competing event enqueues.")
	runtime.tick(0.1, FlowStateMachineDefinition.TickMode.MANUAL)
	_check(runtime.get_active_state_id(m) == other.get_internal_id(),
		"Self and disabled targets do not suppress an eligible lower-priority event edge.")
	_check(_commits == 1, "Exactly one transition is committed.")
	_check(_entries == ["StateEnter:Idle", "StateUpdate:Idle", "StateExit:Idle", "StateEnter:Other"],
		"Valid event performs one Update/Exit/Enter sequence.")
	_check(runtime.pending_request_count() == 0, "Competing event is consumed once.")
	_check(not FlowGraphValidator.validate(graph).has_errors(), "Runtime leaves graph valid.")
	controller.visual_program_enabled = false
	controller.queue_free()
	await get_tree().process_frame
	_finish()


func _state(label: String) -> FlowStateDefinition:
	var state: FlowStateDefinition = FlowStateDefinition.new()
	state.display_name = label
	var enter: FlowPrintBlock = FlowPrintBlock.new()
	enter.text = label
	var update: FlowPrintBlock = FlowPrintBlock.new()
	update.text = label
	var exit: FlowPrintBlock = FlowPrintBlock.new()
	exit.text = label
	state.enter_blocks = [enter]
	state.blocks = [update]
	state.exit_blocks = [exit]
	return state


func _edge(name: StringName, target: String, priority: int) -> FlowStateTransitionDefinition:
	var e: FlowStateTransitionDefinition = FlowStateTransitionDefinition.new()
	e.trigger = FlowStateTransitionDefinition.Trigger.EVENT
	e.event_name = name
	e.target_state_id = target
	e.priority = priority
	return e


func _on_commit(_machine: String, _from: String, _to: String, _edge_id: String) -> void:
	_commits += 1


func _on_output(_controller: Node, _id: String, _block_id: String,
		message: String, phase: StringName) -> void:
	_entries.append("%s:%s" % [String(phase), message])


func _check(ok: bool, msg: String) -> bool:
	if not ok:
		_failures.append(msg)
		push_error("[Flujo] FSM-5E: " + msg)
	return ok


func _finish() -> void:
	if _failures.is_empty():
		print("[Flujo] FSM-5E self-event arbitration test passed")
	get_tree().quit(0 if _failures.is_empty() else 1)
