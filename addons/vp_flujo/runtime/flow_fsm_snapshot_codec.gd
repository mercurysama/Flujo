class_name FlowFSMSnapshotCodec
extends RefCounted

## Versioned, portable FSM instance data. No executable content is serialized.
const FORMAT_VERSION: int = 1


static func make_snapshot(
		graph: FlowGraph,
		active: Dictionary[String, String],
		registries: Dictionary[String, Dictionary]
) -> Dictionary:
	var machines: Array[Dictionary] = []
	var saved_dynamic: Array[Dictionary] = []
	for machine: FlowStateMachineDefinition in graph.state_machines:
		if machine == null:
			continue
		var machine_id: String = machine.get_internal_id()
		if not active.has(machine_id):
			continue
		var current_id: String = active[machine_id]
		var registry: Dictionary = registries.get(machine_id, {})
		var active_record: FlowFSMDynamicStateRecord = registry.get(current_id) as FlowFSMDynamicStateRecord
		if active_record != null and active_record.lifetime != FlowFSMDynamicStateRecord.Lifetime.PERSISTENT:
			current_id = machine.initial_state_id
		machines.append({"machine_id": machine_id, "active_state_id": current_id})
		for state_id: String in registry.keys():
			var record: FlowFSMDynamicStateRecord = registry.get(state_id) as FlowFSMDynamicStateRecord
			if record == null or record.lifetime != FlowFSMDynamicStateRecord.Lifetime.PERSISTENT:
				continue
			saved_dynamic.append({
				"machine_id": machine_id,
				"runtime_id": record.runtime_id,
				"template_state_id": record.template_state_id,
				"lifetime": FlowFSMDynamicStateRecord.Lifetime.PERSISTENT,
				"data": record.data.duplicate(true)
			})
	return {
		"format_version": FORMAT_VERSION,
		"graph_id": graph.get_internal_id(),
		"schema_version": graph.schema_version,
		"machines": machines,
		"dynamic_states": saved_dynamic
	}


## Prepare produces a detached candidate; it never touches the live runtime.
static func prepare(
		snapshot: Variant,
		graph: FlowGraph,
		current_active: Dictionary[String, String]
) -> Dictionary:
	if typeof(snapshot) != TYPE_DICTIONARY or graph == null:
		return {"ok": false, "reason": "snapshot_shape_invalid"}
	var data: Dictionary = snapshot as Dictionary
	if not FlowFSMDataValidator.valid_dictionary(data):
		return {"ok": false, "reason": "snapshot_data_unsafe"}
	if data.get("format_version") != FORMAT_VERSION:
		return {"ok": false, "reason": "snapshot_version_unsupported"}
	if data.get("graph_id") != graph.get_internal_id() or data.get("schema_version") != graph.schema_version:
		return {"ok": false, "reason": "snapshot_graph_incompatible"}
	var raw_machines: Variant = data.get("machines")
	var raw_dynamic: Variant = data.get("dynamic_states")
	if typeof(raw_machines) != TYPE_ARRAY or typeof(raw_dynamic) != TYPE_ARRAY:
		return {"ok": false, "reason": "snapshot_collections_invalid"}
	var dynamic_list: Array = raw_dynamic as Array
	if dynamic_list.size() > FlowFSMRuntime.MAX_DYNAMIC_STATES * maxi(1, current_active.size()):
		return {"ok": false, "reason": "snapshot_dynamic_budget_exceeded"}
	var rebuilt: Dictionary[String, Dictionary] = {}
	for raw_entry: Variant in dynamic_list:
		if typeof(raw_entry) != TYPE_DICTIONARY:
			return {"ok": false, "reason": "snapshot_dynamic_record_invalid"}
		var entry: Dictionary = raw_entry as Dictionary
		var machine_id: String = String(entry.get("machine_id", ""))
		var machine: FlowStateMachineDefinition = _find_machine(graph, machine_id)
		var alias_id: String = String(entry.get("runtime_id", ""))
		var template_id: String = String(entry.get("template_state_id", ""))
		var lifetime: Variant = entry.get("lifetime", -1)
		var record_data: Variant = entry.get("data")
		# JSON.parse_string may decode integral numeric fields as floating-point.
		var numeric_lifetime: bool = typeof(lifetime) in [TYPE_INT, TYPE_FLOAT] \
			and is_finite(float(lifetime)) \
			and float(lifetime) == float(int(lifetime))
		if machine == null or not current_active.has(machine_id) \
				or not FlowId.is_valid(alias_id) \
				or not numeric_lifetime \
				or int(lifetime) != FlowFSMDynamicStateRecord.Lifetime.PERSISTENT \
				or typeof(record_data) != TYPE_DICTIONARY:
			return {"ok": false, "reason": "snapshot_dynamic_identity_invalid"}
		var template: FlowStateDefinition = _find_authored(machine, template_id)
		if template == null or not template.enabled or _find_authored(machine, alias_id) != null:
			return {"ok": false, "reason": "snapshot_dynamic_template_invalid"}
		if not FlowFSMDataValidator.valid_dictionary(record_data as Dictionary):
			return {"ok": false, "reason": "snapshot_dynamic_data_unsafe"}
		var registry: Dictionary = rebuilt.get(machine_id, {})
		if registry.has(alias_id) or registry.size() >= FlowFSMRuntime.MAX_DYNAMIC_STATES:
			return {"ok": false, "reason": "snapshot_dynamic_duplicate_or_budget"}
		registry[alias_id] = FlowFSMDynamicStateRecord.new(
			alias_id, template_id,
			FlowFSMDynamicStateRecord.Lifetime.PERSISTENT,
			record_data as Dictionary
		)
		rebuilt[machine_id] = registry

	var raw_entries: Array = raw_machines as Array
	if raw_entries.size() != current_active.size():
		return {"ok": false, "reason": "snapshot_machine_count_invalid"}
	var staged_active: Dictionary[String, String] = {}
	for raw_entry: Variant in raw_entries:
		if typeof(raw_entry) != TYPE_DICTIONARY:
			return {"ok": false, "reason": "snapshot_machine_record_invalid"}
		var entry: Dictionary = raw_entry as Dictionary
		var machine_id: String = String(entry.get("machine_id", ""))
		var state_id: String = String(entry.get("active_state_id", ""))
		var machine: FlowStateMachineDefinition = _find_machine(graph, machine_id)
		if machine == null or not machine.enabled or not current_active.has(machine_id) \
				or staged_active.has(machine_id):
			return {"ok": false, "reason": "snapshot_machine_id_invalid"}
		var authored: FlowStateDefinition = _find_authored(machine, state_id)
		var registry: Dictionary = rebuilt.get(machine_id, {})
		if (authored == null or not authored.enabled) and not registry.has(state_id):
			return {"ok": false, "reason": "snapshot_active_state_missing"}
		staged_active[machine_id] = state_id
	return {"ok": true, "reason": "", "active": staged_active, "dynamic": rebuilt}


static func _find_machine(graph: FlowGraph, machine_id: String) -> FlowStateMachineDefinition:
	for machine: FlowStateMachineDefinition in graph.state_machines:
		if machine != null and machine.get_internal_id() == machine_id:
			return machine
	return null


static func _find_authored(machine: FlowStateMachineDefinition, state_id: String) -> FlowStateDefinition:
	for state: FlowStateDefinition in machine.states:
		if state != null and state.get_internal_id() == state_id:
			return state
	return null
