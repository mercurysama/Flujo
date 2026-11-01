class_name FlowFSMRuntime
extends RefCounted

## Controller-local FSM state. All authored FlowGraph resources stay read-only.
signal machine_started(machine_id: String, state_id: String)
signal state_entered(machine_id: String, state_id: String)
signal state_updated(machine_id: String, state_id: String)
signal state_exited(machine_id: String, state_id: String)
signal machine_stopped(machine_id: String, state_id: String)
signal transition_committed(machine_id: String, from_state_id: String, to_state_id: String, trigger_id: String)

const MAX_PENDING_REQUESTS: int = 256
const MAX_DYNAMIC_STATES: int = 128

var _controller: PVController
var _graph: FlowGraph
var _active: Dictionary[String, String] = {}
var _pending_requests: Array[Dictionary] = []
var _dynamic_states: Dictionary[String, Dictionary] = {}
var _running: bool = false
var _in_tick: bool = false
var _stop_after_tick: bool = false
var last_delta: float = 0.0


func is_running() -> bool:
	return _running


func get_active_state_id(machine_id: String) -> String:
	return _active.get(machine_id, "")


func get_active_machine_ids() -> Array[String]:
	return _active.keys()


func pending_request_count() -> int:
	return _pending_requests.size()


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
	if graph.schema_version == FlowGraph.SCHEMA_VERSION_4 \
			and FlowGraphValidator.validate_requirement_bindings(graph, controller.requirement_bindings).has_errors():
		push_warning("[Flujo] FSM refused invalid Requirement bindings.")
		return false
	_controller = controller
	_graph = graph
	_running = true
	_stop_after_tick = false
	_pending_requests.clear()
	_dynamic_states.clear()
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


## Queue one explicit destination; it does not need an authored edge.
func request_transition(machine_id: String, target_state_id: String) -> bool:
	if not _running or _pending_requests.size() >= MAX_PENDING_REQUESTS:
		return false
	var machine: FlowStateMachineDefinition = _find_machine(machine_id)
	var target: FlowStateDefinition = _find_state(machine, target_state_id)
	if machine == null or target == null or not target.enabled \
			or not machine.enabled or not _active.has(machine_id):
		return false
	_pending_requests.append({
		"kind": &"direct", "machine_id": machine_id, "target_id": target_state_id
	})
	return true


## Event delivery is deferred until the machine's next matching tick.
func emit_event(machine_id: String, event_name: StringName) -> bool:
	if not _running or String(event_name).is_empty() \
			or _pending_requests.size() >= MAX_PENDING_REQUESTS:
		return false
	if not _active.has(machine_id) or _find_machine(machine_id) == null:
		return false
	_pending_requests.append({
		"kind": &"event", "machine_id": machine_id, "event_name": event_name
	})
	return true


## Update first, then at most one Exit → Enter transition per machine.
func tick(delta: float, mode: int = FlowStateMachineDefinition.TickMode.PROCESS) -> void:
	if not _running or _in_tick or not is_instance_valid(_controller):
		return
	if not _controller.can_execute_visual_program() or _controller.flow_graph != _graph:
		return
	_in_tick = true
	last_delta = delta
	var incoming: Array[Dictionary] = _pending_requests
	_pending_requests = []
	var leftovers: Array[Dictionary] = []
	for machine: FlowStateMachineDefinition in _graph.state_machines:
		if machine == null or not machine.enabled or machine.tick_mode != mode:
			continue
		var machine_id: String = machine.get_internal_id()
		var state_id: String = get_active_state_id(machine_id)
		if state_id.is_empty():
			continue
		var state: FlowStateDefinition = _find_state(machine, state_id)
		if state == null or not state.enabled:
			continue
		_execute_phase(machine, state, state.blocks, &"StateUpdate")
		state_updated.emit(machine_id, state_id)
		var candidate: Dictionary = _pick_request(machine, state, incoming)
		if candidate.is_empty():
			candidate = _pick_condition(machine, state)
		var target_id: String = String(candidate.get("target_id", ""))
		if not target_id.is_empty() and target_id != state_id:
			_commit_transition(machine, state, target_id, String(candidate.get("trigger_id", "")))
	for item: Dictionary in incoming:
		var machine: FlowStateMachineDefinition = _find_machine(String(item.get("machine_id", "")))
		if machine != null and machine.tick_mode != mode and _active.has(machine.get_internal_id()):
			leftovers.append(item)
	# Requests raised in the current Update/Enter/Exit are deferred to the next tick.
	leftovers.append_array(_pending_requests)
	_pending_requests = leftovers.slice(0, MAX_PENDING_REQUESTS)
	_in_tick = false
	if _stop_after_tick:
		_stop_after_tick = false
		stop()


## Stop is idempotent and releases all queued transitions.
func stop() -> void:
	if not _running:
		return
	if _in_tick:
		_stop_after_tick = true
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
	_pending_requests.clear()
	_dynamic_states.clear()
	_active.clear()
	_running = false
	_controller = null
	_graph = null


## Direct commands keep FIFO precedence; events use priority and authored order.
func _pick_request(
		machine: FlowStateMachineDefinition,
		state: FlowStateDefinition,
		requests: Array[Dictionary]
) -> Dictionary:
	var machine_id: String = machine.get_internal_id()
	var best: Dictionary = {}
	var best_priority: int = -2147483647
	var best_order: int = 2147483647
	for request_index: int in requests.size():
		var request: Dictionary = requests[request_index]
		if String(request.get("machine_id", "")) != machine_id:
			continue
		if request.get("kind") == &"direct":
			var target_id: String = String(request.get("target_id", ""))
			var target: FlowStateDefinition = _find_state(machine, target_id)
			if target != null and target.enabled and target_id != state.get_internal_id():
				return {"target_id": target_id, "trigger_id": "direct"}
		elif request.get("kind") == &"event":
			for edge_index: int in state.transitions.size():
				var edge: FlowStateTransitionDefinition = state.transitions[edge_index]
				if edge == null or not edge.enabled \
						or edge.trigger != FlowStateTransitionDefinition.Trigger.EVENT \
						or edge.event_name != request.get("event_name"):
					continue
				var target: FlowStateDefinition = _find_state(machine, edge.target_state_id)
				if target == null or not target.enabled:
					continue
				var order: int = request_index * (state.transitions.size() + 1) + edge_index
				if edge.priority > best_priority or (edge.priority == best_priority and order < best_order):
					best = {"target_id": edge.target_state_id, "trigger_id": edge.get_internal_id()}
					best_priority = edge.priority
					best_order = order
	return best


func _pick_condition(
		machine: FlowStateMachineDefinition,
		state: FlowStateDefinition
) -> Dictionary:
	var best: Dictionary = {}
	var best_priority: int = -2147483647
	for edge: FlowStateTransitionDefinition in state.transitions:
		if edge == null or not edge.enabled \
				or edge.trigger != FlowStateTransitionDefinition.Trigger.CONDITION \
				or edge.condition == null or edge.priority <= best_priority:
			continue
		var target: FlowStateDefinition = _find_state(machine, edge.target_state_id)
		if target == null or not target.enabled or edge.target_state_id == state.get_internal_id():
			continue
		var value: FlowValueResult = edge.condition.resolve(_controller.get_value_resolution_context())
		if value != null and value.success and value.value_type == Variant.Type.TYPE_BOOL \
				and value.value == true:
			best = {"target_id": edge.target_state_id, "trigger_id": edge.get_internal_id()}
			best_priority = edge.priority
	return best


func _commit_transition(
		machine: FlowStateMachineDefinition,
		state: FlowStateDefinition,
		target_id: String,
		trigger_id: String
) -> void:
	var target: FlowStateDefinition = _find_state(machine, target_id)
	if target == null or not target.enabled:
		return
	var machine_id: String = machine.get_internal_id()
	var old_id: String = get_active_state_id(machine_id)
	_execute_phase(machine, state, state.exit_blocks, &"StateExit")
	state_exited.emit(machine_id, old_id)
	_active[machine_id] = target_id
	_execute_phase(machine, target, target.enter_blocks, &"StateEnter")
	state_entered.emit(machine_id, target_id)
	transition_committed.emit(machine_id, old_id, target_id, trigger_id)


func _find_machine(machine_id: String) -> FlowStateMachineDefinition:
	if _graph == null:
		return null
	for machine: FlowStateMachineDefinition in _graph.state_machines:
		if machine != null and machine.get_internal_id() == machine_id:
			return machine
	return null


## Dynamic identities borrow a read-only authored template.
func _find_state(machine: FlowStateMachineDefinition, state_id: String) -> FlowStateDefinition:
	if machine == null:
		return null
	var authored: FlowStateDefinition = _find_authored_state(machine, state_id)
	if authored != null:
		return authored
	var registry: Dictionary = _dynamic_states.get(machine.get_internal_id(), {})
	var record: FlowFSMDynamicStateRecord = registry.get(state_id) as FlowFSMDynamicStateRecord
	if record == null:
		return null
	return _find_authored_state(machine, record.template_state_id)


func _find_authored_state(machine: FlowStateMachineDefinition, state_id: String) -> FlowStateDefinition:
	if machine == null:
		return null
	for state: FlowStateDefinition in machine.states:
		if state != null and state.get_internal_id() == state_id:
			return state
	return null


func has_state(machine_id: String, state_id: String) -> bool:
	return _find_state(_find_machine(machine_id), state_id) != null


## Each runtime alias is isolated, quota-checked and created from a known template.
func register_state(
		machine_id: String,
		template_state_id: String,
		runtime_id: String = "",
		lifetime: int = FlowFSMDynamicStateRecord.Lifetime.EPHEMERAL,
		data: Dictionary = {}
) -> String:
	if not _running:
		return ""
	var machine: FlowStateMachineDefinition = _find_machine(machine_id)
	if machine == null or not machine.enabled:
		return ""
	var template: FlowStateDefinition = _find_authored_state(machine, template_state_id)
	if template == null or not template.enabled:
		return ""
	if not FlowFSMDynamicStateRecord.is_valid_lifetime(lifetime) \
			or not FlowFSMDataValidator.valid_dictionary(data):
		return ""
	var registry: Dictionary = _dynamic_states.get(machine_id, {})
	if registry.size() >= MAX_DYNAMIC_STATES:
		return ""
	var candidate_id: String = FlowId.create() if runtime_id.is_empty() else runtime_id
	if not FlowId.is_valid(candidate_id) or _find_state(machine, candidate_id) != null:
		return ""
	var record: FlowFSMDynamicStateRecord = FlowFSMDynamicStateRecord.new(
		candidate_id, template_state_id, lifetime, data
	)
	registry[candidate_id] = record
	_dynamic_states[machine_id] = registry
	return candidate_id


func get_dynamic_state_ids(machine_id: String) -> Array[String]:
	var result: Array[String] = []
	var registry: Dictionary = _dynamic_states.get(machine_id, {})
	for state_id: String in registry.keys():
		result.append(state_id)
	return result


func get_dynamic_state_lifetime(machine_id: String, state_id: String) -> int:
	var registry: Dictionary = _dynamic_states.get(machine_id, {})
	var record: FlowFSMDynamicStateRecord = registry.get(state_id) as FlowFSMDynamicStateRecord
	return record.lifetime if record != null else -1


func get_dynamic_state_data(machine_id: String, state_id: String) -> Dictionary:
	var registry: Dictionary = _dynamic_states.get(machine_id, {})
	var record: FlowFSMDynamicStateRecord = registry.get(state_id) as FlowFSMDynamicStateRecord
	return record.data.duplicate(true) if record != null else {}


func set_dynamic_state_data(machine_id: String, state_id: String, data: Dictionary) -> bool:
	if not FlowFSMDataValidator.valid_dictionary(data):
		return false
	var registry: Dictionary = _dynamic_states.get(machine_id, {})
	var record: FlowFSMDynamicStateRecord = registry.get(state_id) as FlowFSMDynamicStateRecord
	if record == null:
		return false
	record.data = data.duplicate(true)
	return true


func change_state(machine_id: String, state_id: String) -> bool:
	return request_transition(machine_id, state_id)


## Removing an active alias requires an immediate, valid fallback outside tick.
func remove_state(machine_id: String, state_id: String, fallback_state_id: String = "") -> bool:
	if not _running:
		return false
	var registry: Dictionary = _dynamic_states.get(machine_id, {})
	if not registry.has(state_id):
		return false
	var machine: FlowStateMachineDefinition = _find_machine(machine_id)
	if machine == null:
		return false
	if get_active_state_id(machine_id) == state_id:
		if _in_tick or fallback_state_id.is_empty() or fallback_state_id == state_id:
			return false
		var target: FlowStateDefinition = _find_state(machine, fallback_state_id)
		var old_state: FlowStateDefinition = _find_state(machine, state_id)
		if target == null or not target.enabled or old_state == null:
			return false
		_commit_transition(machine, old_state, fallback_state_id, "dynamic-removal")
	registry.erase(state_id)
	_dynamic_states[machine_id] = registry
	var kept: Array[Dictionary] = []
	for request: Dictionary in _pending_requests:
		if request.get("kind") == &"direct" \
				and request.get("machine_id") == machine_id \
				and request.get("target_id") == state_id:
			continue
		kept.append(request)
	_pending_requests = kept
	return true


## Transient wrapper preserves the generic Ready/Timer block execution contract.
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
