class_name FlowFSMRuntime
extends RefCounted

## Per-controller execution; the shared graph remains read-only.
signal machine_started(machine_id: String, state_id: String)
signal state_entered(machine_id: String, state_id: String)
signal state_updated(machine_id: String, state_id: String)
signal state_exited(machine_id: String, state_id: String)
signal machine_stopped(machine_id: String, state_id: String)

var _controller: PVController
var _graph: FlowGraph
var _active: Dictionary[String, String] = {}
var _running: bool = false
var _in_tick: bool = false
var last_delta: float = 0.0


func is_running() -> bool:
	return _running


func get_active_state_id(machine_id: String) -> String:
	return _active.get(machine_id, "")


func get_active_machine_ids() -> Array[String]:
	return _active.keys()


func start(controller: PVController) -> bool:
	if Engine.is_editor_hint() or _running or controller == null or not controller.can_execute_visual_program():
		return false
	var graph: FlowGraph = controller.flow_graph
	if graph == null or graph.schema_version not in [
		FlowGraph.SCHEMA_VERSION_3,
		FlowGraph.SCHEMA_VERSION_4,
	]:
		return false
	if FlowGraphValidator.validate(graph).has_errors():
		push_warning("[Flujo] FSM refused invalid FlowGraph.")
		return false
	if graph.schema_version == FlowGraph.SCHEMA_VERSION_4 and FlowGraphValidator.validate_requirement_bindings(graph, controller.requirement_bindings).has_errors():
		push_warning("[Flujo] FSM refused invalid Requirement bindings.")
		return false
	_controller = controller
	_graph = graph
	_running = true
	for machine: FlowStateMachineDefinition in graph.state_machines:
		if machine == null or not machine.enabled or not machine.auto_start or machine.states.is_empty():
			continue
		var state: FlowStateDefinition = machine.get_initial_state()
		if state == null or not state.enabled:
			push_warning("[Flujo] FSM has no executable initial state: %s." % machine.get_internal_id())
			continue
		var machine_id: String = machine.get_internal_id()
		_active[machine_id] = state.get_internal_id()
		machine_started.emit(machine_id, state.get_internal_id())
		_execute_phase(machine, state, state.enter_blocks, &"StateEnter")
		state_entered.emit(machine_id, state.get_internal_id())
	if _active.is_empty():
		_running = false
		_controller = null
		_graph = null
		return false
	return true


## One Update execution per active machine and matching engine tick.
func tick(delta: float, mode: int = FlowStateMachineDefinition.TickMode.PROCESS) -> void:
	if not _running or _in_tick or not is_instance_valid(_controller):
		return
	if not _controller.can_execute_visual_program() or _controller.flow_graph != _graph:
		return
	_in_tick = true
	last_delta = delta
	for machine: FlowStateMachineDefinition in _graph.state_machines:
		if machine == null or not machine.enabled or machine.tick_mode != mode:
			continue
		var state_id: String = get_active_state_id(machine.get_internal_id())
		if state_id.is_empty():
			continue
		var state: FlowStateDefinition = _find_state(machine, state_id)
		if state == null or not state.enabled:
			continue
		_execute_phase(machine, state, state.blocks, &"StateUpdate")
		state_updated.emit(machine.get_internal_id(), state_id)
	_in_tick = false


## Exit runs once on normal stop, then all per-instance references are released.
func stop() -> void:
	if not _running or _in_tick:
		return
	for machine: FlowStateMachineDefinition in _graph.state_machines:
		if machine == null:
			continue
		var machine_id: String = machine.get_internal_id()
		var state_id: String = get_active_state_id(machine_id)
		if state_id.is_empty():
			continue
		var state: FlowStateDefinition = _find_state(machine, state_id)
		if state != null:
			_execute_phase(machine, state, state.exit_blocks, &"StateExit")
			state_exited.emit(machine_id, state_id)
		machine_stopped.emit(machine_id, state_id)
	_active.clear()
	_running = false
	_controller = null
	_graph = null


func _find_state(machine: FlowStateMachineDefinition, state_id: String) -> FlowStateDefinition:
	for state: FlowStateDefinition in machine.states:
		if state != null and state.get_internal_id() == state_id:
			return state
	return null


## A transient wrapper reuses the generic Ready/Timer block executor.
func _execute_phase(
		machine: FlowStateMachineDefinition,
		state: FlowStateDefinition,
		blocks: Array[FlowBlock],
		entry_point: StringName
) -> void:
	if blocks.is_empty() or not is_instance_valid(_controller):
		return
	var wrapper: FlowBlockContainer = FlowBlockContainer.new()
	wrapper.blocks = blocks
	FlowReadyExecutor.new()._execute_blocks(
		_controller,
		_graph,
		wrapper,
		"fsm.%s.%s.%s" % [machine.get_internal_id(), state.get_internal_id(), String(entry_point)],
		_controller.runtime_output,
		entry_point,
		machine.get_internal_id(),
		_controller.get_value_resolution_context(),
		[],
		true
	)
