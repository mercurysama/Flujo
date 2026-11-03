extends Node

## Potok 9B1-A: the second disk save must keep the previous distinct
## snapshot in .bak, not merely create an empty or duplicate backup.
const FILE_PATH: String = "user://flujo_fsm_tests/phase9_9b1_backup.json"
var failures: Array[String] = []


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	_cleanup()
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
	var controller: PVController = PVController.new()
	controller.flow_graph = graph
	add_child(controller)
	await get_tree().process_frame
	var runtime: FlowFSMRuntime = controller.get_fsm_runtime()
	if not _check(runtime != null, "Running FSM controller exists"):
		_cleanup()
		controller.queue_free()
		get_tree().quit(1)
		return
	var mid: String = machine.get_internal_id()
	var alias_id: String = runtime.register_state(
		mid, active.get_internal_id(), "",
		FlowFSMDynamicStateRecord.Lifetime.PERSISTENT,
		{"generation": 1, "nested": {"label": "first"}, "values": [1, 2]}
	)
	_check(FlowId.is_valid(alias_id), "Persistent alias is registered")
	_check(runtime.change_state(mid, alias_id), "Persistent alias transition is queued")
	runtime.tick(0.1, FlowStateMachineDefinition.TickMode.MANUAL)
	_check(runtime.get_active_state_id(mid) == alias_id,
		"Persistent alias is active before first save")

	var snapshot_s1: Dictionary = runtime.export_snapshot()
	var normalized_s1: Variant = JSON.parse_string(JSON.stringify(snapshot_s1))
	_check(not snapshot_s1.is_empty() and normalized_s1 is Dictionary
			and snapshot_s1.get("format_version") == 1,
			"First snapshot is portable format v1")
	_check(runtime.save_to_file(FILE_PATH), "S1 is saved to user://")
	_check(FileAccess.file_exists(FILE_PATH)
			and not FileAccess.file_exists(FILE_PATH + ".bak"),
			"First save creates destination without an old backup")
	_check(_parse_file(FILE_PATH) == normalized_s1,
			"First saved JSON exactly matches S1 snapshot")

	_check(runtime.set_dynamic_state_data(mid, alias_id,
			{"generation": 2, "nested": {"label": "second"}, "values": [3, 4, 5]}),
			"Persistent alias data is replaced for S2")
	var snapshot_s2: Dictionary = runtime.export_snapshot()
	var normalized_s2: Variant = JSON.parse_string(JSON.stringify(snapshot_s2))
	_check(normalized_s1 != normalized_s2
			and snapshot_s2.get("graph_id") == snapshot_s1.get("graph_id")
			and snapshot_s2.get("format_version") == 1,
			"S1 and S2 differ in saved data but use the same graph and format")
	_check(runtime.save_to_file(FILE_PATH), "S2 replaces the existing destination")
	_check(FileAccess.file_exists(FILE_PATH) and FileAccess.file_exists(FILE_PATH + ".bak"),
			"Both destination and backup exist after second save")

	var disk_s2: Variant = _parse_file(FILE_PATH)
	var disk_s1: Variant = _parse_file(FILE_PATH + ".bak")
	_check(disk_s2 is Dictionary and disk_s1 is Dictionary,
			"Destination and backup are both valid JSON objects")
	_check(disk_s2 == normalized_s2, "Destination contains S2 exactly")
	_check(disk_s1 == normalized_s1, "Backup contains the previous S1 exactly")
	if disk_s2 is Dictionary and disk_s1 is Dictionary:
		var new_data: Array = (disk_s2 as Dictionary).get("dynamic_states", [])
		var old_data: Array = (disk_s1 as Dictionary).get("dynamic_states", [])
		_check(new_data.size() == 1 and old_data.size() == 1,
				"Both snapshots contain exactly one saved persistent alias")
		if new_data.size() == 1 and old_data.size() == 1:
			_check((new_data[0] as Dictionary).get("runtime_id") == alias_id
					and (old_data[0] as Dictionary).get("runtime_id") == alias_id,
					"Persistent alias identity is unchanged across both saves")
			_check((new_data[0] as Dictionary).get("data", {}).get("generation") == 2
					and (old_data[0] as Dictionary).get("data", {}).get("generation") == 1,
					"Backup retains old nested payload and main file retains new payload")
	_check(not FileAccess.file_exists(FILE_PATH + ".tmp"),
			"Successful replacement leaves no temporary file")
	_check(runtime.export_snapshot() == snapshot_s2
			and runtime.get_active_state_id(mid) == alias_id,
			"Disk operations never mutate the live runtime")
	_cleanup()
	controller.visual_program_enabled = false
	controller.queue_free()
	await get_tree().process_frame
	if failures.is_empty():
		print("[Flujo] Potok 9B1-A backup contents passed")
	else:
		for failure: String in failures:
			push_error("[Flujo] Potok 9B1-A: " + failure)
	get_tree().quit(0 if failures.is_empty() else 1)


func _parse_file(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	return JSON.parse_string(FileAccess.get_file_as_string(path))


func _cleanup() -> void:
	var absolute: String = ProjectSettings.globalize_path(FILE_PATH)
	for path: String in [absolute, absolute + ".tmp", absolute + ".bak"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)


func _check(ok: bool, detail: String) -> bool:
	if not ok:
		failures.append(detail)
		push_error("[Flujo] Potok 9B1-A assertion: " + detail)
	return ok
