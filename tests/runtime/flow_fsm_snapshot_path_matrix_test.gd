extends Node

## Potok 9B2-A: bounded user:// save/restore path policy and rejected operations.
const FILE_PATH: String = "user://flujo_fsm_tests/phase9_9b2_paths.json"
const NESTED_FILE: String = "user://flujo_fsm_tests/phase9_9b2_nested/valid.json"
const INVALID_PATHS: Array[String] = [
	"",
	"snapshot.json",
	"res://unexpected.json",
	"/tmp/flujo_forbidden_snapshot.json",
	"user://../escape.json",
	"user://flujo_fsm_tests/../escape.json",
	"user://flujo_fsm_tests/bad\\name.json",
	"user://flujo_fsm_tests/unexpected.txt",
	"user://flujo_fsm_tests/no_extension",
]
var _failures: Array[String] = []


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
	var mid: String = machine.get_internal_id()
	var controller: PVController = PVController.new()
	controller.flow_graph = graph
	add_child(controller)
	await get_tree().process_frame
	var runtime: FlowFSMRuntime = controller.get_fsm_runtime()
	if not _check(runtime != null, "Running FSM controller available"):
		_cleanup()
		controller.queue_free()
		get_tree().quit(1)
		return
	var alias_id: String = runtime.register_state(
		mid, active.get_internal_id(), "",
		FlowFSMDynamicStateRecord.Lifetime.PERSISTENT,
		{"generation": 2, "nested": {"valid": true}}
	)
	_check(FlowId.is_valid(alias_id), "Persistent alias registered")
	_check(runtime.change_state(mid, alias_id), "Alias transition requested")
	runtime.tick(0.1, FlowStateMachineDefinition.TickMode.MANUAL)
	_check(runtime.get_active_state_id(mid) == alias_id, "Alias active")

	var expected: Dictionary = runtime.export_snapshot()
	var json_expected: Variant = JSON.parse_string(JSON.stringify(expected))
	_check(runtime.save_to_file(FILE_PATH), "Valid user:// JSON file saved")
	_check(runtime.save_to_file(NESTED_FILE), "Valid nested user:// JSON file saved")
	_check(FileAccess.file_exists(FILE_PATH) and FileAccess.file_exists(NESTED_FILE),
			"Both valid paths contain files")
	_check(JSON.parse_string(FileAccess.get_file_as_string(FILE_PATH)) == json_expected
			and JSON.parse_string(FileAccess.get_file_as_string(NESTED_FILE)) == json_expected,
			"Valid paths contain the same portable snapshot")
	_check(not FileAccess.file_exists(FILE_PATH + ".bak")
			and not FileAccess.file_exists(FILE_PATH + ".tmp"),
			"One successful save has no backup or stranded temporary")

	_check(runtime.change_state(mid, idle.get_internal_id()),
			"Direct request queued before invalid restore operations")
	for path: String in INVALID_PATHS:
		_check(not runtime.save_to_file(path),
				"Save rejects forbidden path: " + path)
		_check(not runtime.restore_from_file(path),
				"Restore rejects forbidden path: " + path)
		_check(runtime.get_active_state_id(mid) == alias_id
				and runtime.export_snapshot() == expected,
				"Invalid path leaves live FSM unchanged: " + path)
	_check(FileAccess.file_exists(FILE_PATH) and FileAccess.file_exists(NESTED_FILE),
			"Rejected operations keep both valid files")
	_check(not FileAccess.file_exists(FILE_PATH + ".bak")
			and not FileAccess.file_exists(FILE_PATH + ".tmp"),
			"Rejected operations create no backup or temp for valid file")
	runtime.tick(0.1, FlowStateMachineDefinition.TickMode.MANUAL)
	_check(runtime.get_active_state_id(mid) == idle.get_internal_id(),
			"Previously queued direct request survives every rejected restore")

	_check(runtime.restore_from_file(NESTED_FILE), "Valid nested snapshot restores")
	_check(runtime.get_active_state_id(mid) == alias_id
			and runtime.get_dynamic_state_data(mid, alias_id).get("generation") == 2,
			"Valid restore recovers original active persistent alias and detached data")
	_check(runtime.export_snapshot() == expected, "Successful restore reproduces snapshot")
	_cleanup()
	controller.visual_program_enabled = false
	controller.queue_free()
	await get_tree().process_frame
	if _failures.is_empty():
		print("[Flujo] Potok 9B2-A user path matrix passed")
	else:
		for failure: String in _failures:
			push_error("[Flujo] Potok 9B2-A: " + failure)
	get_tree().quit(0 if _failures.is_empty() else 1)


func _cleanup() -> void:
	for path: String in [FILE_PATH, NESTED_FILE]:
		var absolute: String = ProjectSettings.globalize_path(path)
		for candidate: String in [absolute, absolute + ".tmp", absolute + ".bak"]:
			if FileAccess.file_exists(candidate):
				DirAccess.remove_absolute(candidate)


func _check(ok: bool, detail: String) -> bool:
	if not ok:
		_failures.append(detail)
		push_error("[Flujo] Potok 9B2-A assertion: " + detail)
	return ok
