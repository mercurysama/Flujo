class_name FlowFSMRuntime
extends RefCounted

## Controller-local FSM state. All authored FlowGraph resources stay read-only.
signal machine_started(machine_id: String, state_id: String)
signal state_entered(machine_id: String, state_id: String)
signal state_updated(machine_id: String, state_id: String)
## Fired for each event consumed by its machine clock, even without a matching edge.
signal event_consumed(machine_id: String, event_name: StringName, payload: Dictionary)
## Stable rejection codes for runtime admission; no payload is leaked.
signal request_rejected(machine_id: String, kind: StringName, code: StringName)
signal state_exited(machine_id: String, state_id: String)
signal machine_stopped(machine_id: String, state_id: String)
signal transition_committed(machine_id: String, from_state_id: String, to_state_id: String, trigger_id: String)

const MAX_PENDING_REQUESTS: int = 256
## Max committed hops inherited through transition lifecycle callbacks.
const MAX_CHAIN_HOPS: int = 8
const MAX_DYNAMIC_STATES: int = 128

var _controller: PVController
var _graph: FlowGraph
var _active: Dictionary[String, String] = {}
var _pending_requests: Array[Dictionary] = []
var _inflight_reserved: int = 0
var _next_chain_id: int = 1
var _committing_chain_id: int = 0
var _committing_chain_hop: int = 0
var _blocked_chains: Dictionary[int, bool] = {}
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
	_next_chain_id = 1
	_committing_chain_id = 0
	_committing_chain_hop = 0
	_blocked_chains.clear()
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
	if not _running:
		request_rejected.emit(machine_id, &"direct", &"not_running")
		return false
	var machine: FlowStateMachineDefinition = _find_machine(machine_id)
	if machine == null or not machine.enabled or not _active.has(machine_id):
		request_rejected.emit(machine_id, &"direct", &"invalid_machine")
		return false
	var target: FlowStateDefinition = _find_state(machine, target_state_id)
	if target == null or not target.enabled:
		request_rejected.emit(machine_id, &"direct", &"invalid_target")
		return false
	if _pending_requests.size() + _inflight_reserved >= MAX_PENDING_REQUESTS:
		request_rejected.emit(machine_id, &"direct", &"queue_full")
		return false
	var lineage: Dictionary = _admit_chain_hop(machine_id, &"direct")
	if lineage.is_empty():
		return false
	_pending_requests.append({
		"kind": &"direct", "machine_id": machine_id, "target_id": target_state_id,
		"chain_id": lineage["chain_id"], "chain_hop": lineage["chain_hop"]
	})
	return true


## A root starts a distinct lineage; requests from transition callbacks inherit it.
## The saturated lineage is blocked without denying unrelated valid roots.
func _admit_chain_hop(machine_id: String, kind: StringName) -> Dictionary:
	var chain_id: int = _committing_chain_id
	var chain_hop: int = _committing_chain_hop + 1 if chain_id != 0 else 1
	if chain_id != 0 and chain_hop > MAX_CHAIN_HOPS:
		_blocked_chains[chain_id] = true
		request_rejected.emit(machine_id, kind, &"chain_budget_exceeded")
		return {}
	if chain_id == 0:
		chain_id = _next_chain_id
		_next_chain_id += 1
	return {"chain_id": chain_id, "chain_hop": chain_hop}


## Event delivery is deferred until the machine's next matching tick.
func emit_event(machine_id: String, event_name: StringName, payload: Dictionary = {}) -> bool:
	if not _running:
		request_rejected.emit(machine_id, &"event", &"not_running")
		return false
	if String(event_name).strip_edges().is_empty():
		request_rejected.emit(machine_id, &"event", &"invalid_event_name")
		return false
	var machine: FlowStateMachineDefinition = _find_machine(machine_id)
	if machine == null or not machine.enabled or not _active.has(machine_id):
		request_rejected.emit(machine_id, &"event", &"invalid_machine")
		return false
	if not FlowFSMDataValidator.valid_dictionary(payload):
		request_rejected.emit(machine_id, &"event", &"invalid_payload")
		return false
	if _pending_requests.size() + _inflight_reserved >= MAX_PENDING_REQUESTS:
		request_rejected.emit(machine_id, &"event", &"queue_full")
		return false
	var lineage: Dictionary = _admit_chain_hop(machine_id, &"event")
	if lineage.is_empty():
		return false
	_pending_requests.append({
		"kind": &"event",
		"machine_id": machine_id,
		"event_name": event_name,
		"payload": payload.duplicate(true),
		"chain_id": lineage["chain_id"], "chain_hop": lineage["chain_hop"]
	})
	return true


## Update first, then at most one Exit → Enter transition per machine.
func tick(delta: float, mode: int = FlowStateMachineDefinition.TickMode.PROCESS) -> void:
	if not _running or _in_tick or not is_instance_valid(_controller):
		return
	if not _controller.can_execute_visual_program() or _controller.flow_graph != _graph:
		return
	_in_tick = true
	_blocked_chains.clear()
	last_delta = delta
	var incoming: Array[Dictionary] = _pending_requests
	_pending_requests = []
	var leftovers: Array[Dictionary] = []
	# Reserve capacity for requests which must survive until another clock ticks.
	# A callback cannot accept a request that the final queue would silently drop.
	for item: Dictionary in incoming:
		var target_machine: FlowStateMachineDefinition = _find_machine(String(item.get("machine_id", "")))
		if target_machine != null and target_machine.tick_mode != mode \
				and _active.has(target_machine.get_internal_id()):
			leftovers.append(item)
	_inflight_reserved = leftovers.size()
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
		# Deliver detached packet data before arbitration; callbacks may enqueue only
		# for a future tick, and other-clock packets are not observed here.
		for request: Dictionary in incoming:
			if request.get("kind") != &"event" \
					or String(request.get("machine_id", "")) != machine_id \
					or _blocked_chains.has(int(request.get("chain_id", 0))):
				continue
			var packet: Dictionary = request.get("payload", {})
			event_consumed.emit(
				machine_id, request.get("event_name", &""), packet.duplicate(true)
			)
		var candidate: Dictionary = _pick_request(machine, state, incoming)
		if candidate.is_empty():
			candidate = _pick_condition(machine, state)
		var target_id: String = String(candidate.get("target_id", ""))
		if not target_id.is_empty() and target_id != state_id:
			_commit_transition(machine, state, target_id,
				String(candidate.get("trigger_id", "")),
				int(candidate.get("chain_id", 0)), int(candidate.get("chain_hop", 1)))
	# Requests raised in Update/Enter/Exit are deferred to the next matching tick.
	leftovers.append_array(_pending_requests)
	# A saturated chain loses its queued descendants, not unrelated roots.
	var kept: Array[Dictionary] = []
	for request: Dictionary in leftovers:
		if not _blocked_chains.has(int(request.get("chain_id", 0))):
			kept.append(request)
	_pending_requests = kept
	_inflight_reserved = 0
	_blocked_chains.clear()
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
	_blocked_chains.clear()
	_committing_chain_id = 0
	_committing_chain_hop = 0
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
		if String(request.get("machine_id", "")) != machine_id \
				or _blocked_chains.has(int(request.get("chain_id", 0))):
			continue
		if request.get("kind") == &"direct":
			var target_id: String = String(request.get("target_id", ""))
			var target: FlowStateDefinition = _find_state(machine, target_id)
			if target != null and target.enabled and target_id != state.get_internal_id():
				return {
					"target_id": target_id, "trigger_id": "direct",
					"chain_id": request.get("chain_id", 0),
					"chain_hop": request.get("chain_hop", 1)
				}
		elif request.get("kind") == &"event":
			for edge_index: int in state.transitions.size():
				var edge: FlowStateTransitionDefinition = state.transitions[edge_index]
				if edge == null or not edge.enabled \
						or edge.trigger != FlowStateTransitionDefinition.Trigger.EVENT \
						or edge.event_name != request.get("event_name"):
					continue
				var target: FlowStateDefinition = _find_state(machine, edge.target_state_id)
				# A same-state event is a no-op, not an arbitration winner.
				if target == null or not target.enabled \
						or edge.target_state_id == get_active_state_id(machine_id):
					continue
				var order: int = request_index * (state.transitions.size() + 1) + edge_index
				if edge.priority > best_priority or (edge.priority == best_priority and order < best_order):
					best = {
						"target_id": edge.target_state_id,
						"trigger_id": edge.get_internal_id(),
						"chain_id": request.get("chain_id", 0),
						"chain_hop": request.get("chain_hop", 1)
					}
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
		trigger_id: String,
		chain_id: int = 0,
		chain_hop: int = 1
) -> void:
	var target: FlowStateDefinition = _find_state(machine, target_id)
	if target == null or not target.enabled:
		return
	if chain_id == 0:
		chain_id = _next_chain_id
		_next_chain_id += 1
	var previous_chain_id: int = _committing_chain_id
	var previous_chain_hop: int = _committing_chain_hop
	_committing_chain_id = chain_id
	_committing_chain_hop = chain_hop
	var machine_id: String = machine.get_internal_id()
	var old_id: String = get_active_state_id(machine_id)
	_execute_phase(machine, state, state.exit_blocks, &"StateExit")
	state_exited.emit(machine_id, old_id)
	_active[machine_id] = target_id
	_execute_phase(machine, target, target.enter_blocks, &"StateEnter")
	state_entered.emit(machine_id, target_id)
	transition_committed.emit(machine_id, old_id, target_id, trigger_id)
	_committing_chain_id = previous_chain_id
	_committing_chain_hop = previous_chain_hop


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


## EPHEMERAL aliases are cleared on reset; SESSION/PERSISTENT aliases survive.
func reset() -> bool:
	if not _running or _in_tick:
		return false
	for machine: FlowStateMachineDefinition in _graph.state_machines:
		if machine == null or not _active.has(machine.get_internal_id()):
			continue
		var next: FlowStateDefinition = machine.get_initial_state()
		if next == null or not next.enabled:
			return false
	_pending_requests.clear()
	for machine: FlowStateMachineDefinition in _graph.state_machines:
		if machine == null or not _active.has(machine.get_internal_id()):
			continue
		var previous_id: String = get_active_state_id(machine.get_internal_id())
		var previous: FlowStateDefinition = _find_state(machine, previous_id)
		if previous != null:
			_execute_phase(machine, previous, previous.exit_blocks, &"StateExit")
			state_exited.emit(machine.get_internal_id(), previous_id)
		var initial: FlowStateDefinition = machine.get_initial_state()
		_active[machine.get_internal_id()] = initial.get_internal_id()
		var registry: Dictionary = _dynamic_states.get(machine.get_internal_id(), {})
		var retained: Dictionary = {}
		for state_id: String in registry.keys():
			var record: FlowFSMDynamicStateRecord = registry[state_id] as FlowFSMDynamicStateRecord
			if record != null and record.lifetime != FlowFSMDynamicStateRecord.Lifetime.EPHEMERAL:
				retained[state_id] = record
		_dynamic_states[machine.get_internal_id()] = retained
		_execute_phase(machine, initial, initial.enter_blocks, &"StateEnter")
		state_entered.emit(machine.get_internal_id(), initial.get_internal_id())
	return true


## Returns a detached portable dictionary; EPHEMERAL and SESSION are omitted.
func export_snapshot() -> Dictionary:
	if not _running or _in_tick:
		return {}
	return FlowFSMSnapshotCodec.make_snapshot(_graph, _active, _dynamic_states)


## Failed preflight leaves the currently running FSM completely unchanged.
func restore_snapshot(snapshot: Variant) -> bool:
	if not _running or _in_tick:
		return false
	var prepared: Dictionary = FlowFSMSnapshotCodec.prepare(snapshot, _graph, _active)
	if not prepared.get("ok", false):
		push_warning("[Flujo] FSM snapshot rejected: %s" % String(prepared.get("reason", "")))
		return false
	var next_active: Dictionary[String, String] = prepared["active"]
	var next_dynamic: Dictionary[String, Dictionary] = prepared["dynamic"]
	for machine: FlowStateMachineDefinition in _graph.state_machines:
		if machine == null or not _active.has(machine.get_internal_id()):
			continue
		var old_id: String = get_active_state_id(machine.get_internal_id())
		var old_state: FlowStateDefinition = _find_state(machine, old_id)
		if old_state != null:
			_execute_phase(machine, old_state, old_state.exit_blocks, &"StateExit")
			state_exited.emit(machine.get_internal_id(), old_id)
	_dynamic_states = next_dynamic
	_active = next_active
	_pending_requests.clear()
	for machine: FlowStateMachineDefinition in _graph.state_machines:
		if machine == null or not _active.has(machine.get_internal_id()):
			continue
		var current_id: String = get_active_state_id(machine.get_internal_id())
		var current: FlowStateDefinition = _find_state(machine, current_id)
		if current != null:
			_execute_phase(machine, current, current.enter_blocks, &"StateEnter")
			state_entered.emit(machine.get_internal_id(), current_id)
	return true


## Save only inside Godot's user:// sandbox and preserve last valid backup.
func save_to_file(path: String) -> bool:
	if not _snapshot_path_allowed(path):
		return false
	var snapshot: Dictionary = export_snapshot()
	if snapshot.is_empty() or not FlowFSMDataValidator.valid_dictionary(snapshot):
		return false
	var json: String = JSON.stringify(snapshot, "\t")
	if json.length() > FlowFSMDataValidator.MAX_JSON_LENGTH:
		return false
	var absolute: String = ProjectSettings.globalize_path(path)
	if DirAccess.make_dir_recursive_absolute(absolute.get_base_dir()) != OK:
		return false
	var temporary: String = absolute + ".tmp"
	var file: FileAccess = FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(json)
	file.flush()
	file = null
	if FileAccess.get_file_as_string(temporary) != json:
		DirAccess.remove_absolute(temporary)
		return false
	var prior: bool = FileAccess.file_exists(absolute)
	var backup: String = absolute + ".bak"
	if prior:
		if FileAccess.file_exists(backup):
			DirAccess.remove_absolute(backup)
		if DirAccess.copy_absolute(absolute, backup) != OK:
			DirAccess.remove_absolute(temporary)
			return false
	if DirAccess.rename_absolute(temporary, absolute) != OK:
		# Some platforms do not atomically replace an existing destination.
		if not prior or DirAccess.remove_absolute(absolute) != OK \
				or DirAccess.rename_absolute(temporary, absolute) != OK:
			if prior and FileAccess.file_exists(backup):
				DirAccess.copy_absolute(backup, absolute)
			if FileAccess.file_exists(temporary):
				DirAccess.remove_absolute(temporary)
			return false
	return true


func restore_from_file(path: String) -> bool:
	if not _snapshot_path_allowed(path) or not FileAccess.file_exists(path):
		return false
	var contents: String = FileAccess.get_file_as_string(path)
	if contents.length() > FlowFSMDataValidator.MAX_JSON_LENGTH:
		return false
	var decoded: Variant = JSON.parse_string(contents)
	return restore_snapshot(decoded)


func _snapshot_path_allowed(path: String) -> bool:
	return path.begins_with("user://") and path.ends_with(".json") \
		and not path.contains("..") and not path.contains("\\") \
		and path.length() > "user://x.json".length()
