extends Node

## Potok 9D1-A: strict portable snapshot v1 identity rejection.
const FILE_PATH: String = "user://flujo_fsm_tests/phase9_9d1_compat.json"
var failures: Array[String] = []
var owns_file: bool = false


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	if FileAccess.file_exists(FILE_PATH):
		_check(false, "Reserved 9D1 fixture path must be empty")
		get_tree().quit(1)
		return
	var graph: FlowGraph = FlowGraph.new()
	graph.schema_version = FlowGraph.SCHEMA_VERSION_3
	graph.constructor = FlowConstructorDefinition.new()
	var idle: FlowStateDefinition = FlowStateDefinition.new()
	idle.display_name = "Idle"
	var active: FlowStateDefinition = FlowStateDefinition.new()
	active.display_name = "Active"
	var machine: FlowStateMachineDefinition = FlowStateMachineDefinition.new()
	machine.tick_mode = FlowStateMachineDefinition.TickMode.MANUAL
	machine.states = [idle, active]
	machine.initial_state_id = idle.get_internal_id()
	graph.state_machines = [machine]
	var mid: String = machine.get_internal_id()
	var controller: PVController = PVController.new()
	controller.flow_graph = graph
	add_child(controller)
	await get_tree().process_frame
	var runtime: FlowFSMRuntime = controller.get_fsm_runtime()
	if not _check(runtime != null and runtime.is_running(), "Live FSM runtime exists"):
		controller.queue_free()
		get_tree().quit(1)
		return
	var alias_id: String = runtime.register_state(
		mid, active.get_internal_id(), "",
		FlowFSMDynamicStateRecord.Lifetime.PERSISTENT,
		{"generation": 11}
	)
	_check(FlowId.is_valid(alias_id), "Persistent alias registered")
	_check(runtime.change_state(mid, alias_id), "Persistent alias queued")
	runtime.tick(0.1, FlowStateMachineDefinition.TickMode.MANUAL)
	var baseline: Dictionary = runtime.export_snapshot()
	_check(baseline.get("format_version") == 1
			and baseline.get("graph_id") == graph.get_internal_id()
			and baseline.get("schema_version") == graph.schema_version,
			"Known v1 snapshot identifies exact authored graph and schema")
	_check(runtime.change_state(mid, idle.get_internal_id()), "Pending direct request queued")
	var cases: Array[Dictionary] = []
	var old_format: Dictionary = baseline.duplicate(true)
	old_format["format_version"] = 0
	cases.append({"label": "old format", "snapshot": old_format})
	var future_format: Dictionary = baseline.duplicate(true)
	future_format["format_version"] = 2
	cases.append({"label": "future format", "snapshot": future_format})
	var wrong_schema: Dictionary = baseline.duplicate(true)
	wrong_schema["schema_version"] = graph.schema_version + 1
	cases.append({"label": "unknown schema", "snapshot": wrong_schema})
	var foreign_graph: Dictionary = baseline.duplicate(true)
	foreign_graph["graph_id"] = "incompatible-graph"
	cases.append({"label": "foreign graph", "snapshot": foreign_graph})
	var missing_machine: Dictionary = baseline.duplicate(true)
	(missing_machine["machines"] as Array)[0]["machine_id"] = "incompatible-machine"
	cases.append({"label": "foreign machine", "snapshot": missing_machine})
	var missing_active: Dictionary = baseline.duplicate(true)
	(missing_active["machines"] as Array)[0]["active_state_id"] = "incompatible-state"
	cases.append({"label": "unknown active state", "snapshot": missing_active})
	var unknown_template: Dictionary = baseline.duplicate(true)
	(unknown_template["dynamic_states"] as Array)[0]["template_state_id"] = "missing-template"
	cases.append({"label": "missing template", "snapshot": unknown_template})
	var wrong_collection: Dictionary = baseline.duplicate(true)
	wrong_collection["machines"] = {"not": "an array"}
	cases.append({"label": "invalid machine collection", "snapshot": wrong_collection})
	for entry: Dictionary in cases:
		var label: String = entry["label"]
		var snapshot: Dictionary = entry["snapshot"]
		_check(_write_json(snapshot), "Fixture written for " + label)
		_check(not runtime.restore_from_file(FILE_PATH), "Disk restore rejects " + label)
		_check(runtime.get_active_state_id(mid) == alias_id
				and runtime.get_dynamic_state_data(mid, alias_id).get("generation") == 11
				and runtime.export_snapshot() == baseline,
				"Rejected " + label + " preserves live persistent state")
	_check(runtime.pending_request_count() == 1,
			"All invalid disk restores preserve pending owner request")
	runtime.tick(0.1, FlowStateMachineDefinition.TickMode.MANUAL)
	_check(runtime.get_active_state_id(mid) == idle.get_internal_id(),
			"Pending request is still committed after all incompatibility rejects")
	_check(_write_json(baseline), "Original compatible v1 file written")
	_check(runtime.restore_from_file(FILE_PATH), "Exact v1 snapshot restores normally")
	_check(runtime.get_active_state_id(mid) == alias_id
			and runtime.get_dynamic_state_data(mid, alias_id).get("generation") == 11,
			"Compatible restore recovers original alias and data")
	_check(JSON.parse_string(JSON.stringify(runtime.export_snapshot()))
			== JSON.parse_string(JSON.stringify(baseline)),
			"Restored snapshot matches portable v1 representation")
	_cleanup()
	controller.visual_program_enabled = false
	controller.queue_free()
	await get_tree().process_frame
	if failures.is_empty():
		print("[Flujo] Potok 9D1-A snapshot compatibility matrix passed")
	else:
		for failure: String in failures:
			push_error("[Flujo] Potok 9D1-A: " + failure)
	get_tree().quit(0 if failures.is_empty() else 1)


func _write_json(snapshot: Dictionary) -> bool:
	var absolute: String = ProjectSettings.globalize_path(FILE_PATH)
	if DirAccess.make_dir_recursive_absolute(absolute.get_base_dir()) != OK:
		return false
	var file: FileAccess = FileAccess.open(FILE_PATH, FileAccess.WRITE)
	if file == null:
		return false
	owns_file = true
	var serialized: String = JSON.stringify(snapshot)
	file.store_string(serialized)
	file.flush()
	file = null
	return FileAccess.get_file_as_string(FILE_PATH) == serialized


func _cleanup() -> void:
	if owns_file:
		var absolute: String = ProjectSettings.globalize_path(FILE_PATH)
		for path: String in [absolute, absolute + ".tmp", absolute + ".bak"]:
			if FileAccess.file_exists(path):
				DirAccess.remove_absolute(path)


func _check(value: bool, description: String) -> bool:
	if not value:
		failures.append(description)
		push_error("[Flujo] Potok 9D1-A assertion: " + description)
	return value
