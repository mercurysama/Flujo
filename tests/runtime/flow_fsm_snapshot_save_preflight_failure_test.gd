extends Node

## Potok 9B3-B2 / F3: safely characterize an early save failure when
## a path component is a regular file, without fault injection or runtime edits.
const VALID_PATH: String = "user://flujo_fsm_tests/phase9_9b3_valid.json"
const BLOCKER_PATH: String = "user://flujo_fsm_tests/phase9_9b3_blocker"
const REJECTED_PATH: String = BLOCKER_PATH + "/blocked.json"
const MARKER: String = "Potok-9B3-B2-file-sentinel"
var _failures: Array[String] = []
var _owns_valid: bool = false
var _owns_blocker: bool = false


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	# Never delete or overwrite an existing file from a different run/user.
	if FileAccess.file_exists(VALID_PATH) or FileAccess.file_exists(BLOCKER_PATH) \
			or DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(BLOCKER_PATH)):
		_check(false, "Reserved F3 fixture paths must be unused")
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
	if not _check(runtime != null, "Running FSM controller is available"):
		_cleanup()
		controller.queue_free()
		get_tree().quit(1)
		return
	var alias_id: String = runtime.register_state(
		mid, active.get_internal_id(), "",
		FlowFSMDynamicStateRecord.Lifetime.PERSISTENT,
		{"generation": 1, "nested": {"safe": true}}
	)
	_check(FlowId.is_valid(alias_id), "Persistent alias registered")
	_check(runtime.change_state(mid, alias_id), "Alias activation requested")
	runtime.tick(0.1, FlowStateMachineDefinition.TickMode.MANUAL)
	_check(runtime.get_active_state_id(mid) == alias_id, "Persistent alias active")
	var snapshot_before: Dictionary = runtime.export_snapshot()
	_check(runtime.save_to_file(VALID_PATH), "Independent valid S1 saved")
	_owns_valid = FileAccess.file_exists(VALID_PATH)
	var file_before: String = FileAccess.get_file_as_string(VALID_PATH)
	_check(JSON.parse_string(file_before)
			== JSON.parse_string(JSON.stringify(snapshot_before)),
			"Independent S1 contains the expected portable snapshot")
	_check(not FileAccess.file_exists(VALID_PATH + ".bak")
			and not FileAccess.file_exists(VALID_PATH + ".tmp"),
			"No existing backup or temporary for independent S1")

	# A file occupying a directory component must make recursive mkdir fail.
	var blocker: FileAccess = FileAccess.open(BLOCKER_PATH, FileAccess.WRITE)
	if not _check(blocker != null, "Sentinel file can be created"):
		_cleanup()
		controller.queue_free()
		get_tree().quit(1)
		return
	blocker.store_string(MARKER)
	blocker.flush()
	blocker = null
	_owns_blocker = true
	_check(FileAccess.file_exists(BLOCKER_PATH)
			and not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(BLOCKER_PATH)),
			"Blocker is an ordinary file rather than a directory")
	_check(runtime.change_state(mid, idle.get_internal_id()),
			"Direct transition queued before failed save")
	var save_result: bool = runtime.save_to_file(REJECTED_PATH)
	_check(not save_result, "Save fails before touching disk beneath file sentinel")
	_check(FileAccess.get_file_as_string(BLOCKER_PATH) == MARKER,
			"Sentinel bytes preserved after failed recursive directory creation")
	_check(not FileAccess.file_exists(REJECTED_PATH)
			and not FileAccess.file_exists(REJECTED_PATH + ".tmp")
			and not FileAccess.file_exists(REJECTED_PATH + ".bak"),
			"No snapshot or temporary file created beneath sentinel")
	_check(FileAccess.get_file_as_string(VALID_PATH) == file_before
			and FileAccess.file_exists(VALID_PATH),
			"Independent valid snapshot bytes unchanged")
	_check(not FileAccess.file_exists(VALID_PATH + ".bak")
			and not FileAccess.file_exists(VALID_PATH + ".tmp"),
			"Failed save does not touch valid snapshot backup or temp")
	_check(runtime.get_active_state_id(mid) == alias_id
			and runtime.get_dynamic_state_data(mid, alias_id).get("generation") == 1
			and runtime.export_snapshot() == snapshot_before,
			"Failed save does not mutate runtime, alias or persistent data")
	runtime.tick(0.1, FlowStateMachineDefinition.TickMode.MANUAL)
	_check(runtime.get_active_state_id(mid) == idle.get_internal_id(),
			"Pending direct request survives failed save and commits on tick")
	_cleanup()
	controller.visual_program_enabled = false
	controller.queue_free()
	await get_tree().process_frame
	if _failures.is_empty():
		print("[Flujo] Potok 9B3-B2 F3 early save failure passed")
	else:
		for failure: String in _failures:
			push_error("[Flujo] Potok 9B3-B2: " + failure)
	get_tree().quit(0 if _failures.is_empty() else 1)


func _cleanup() -> void:
	if _owns_blocker and FileAccess.file_exists(BLOCKER_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(BLOCKER_PATH))
	if _owns_valid:
		for path: String in [VALID_PATH, VALID_PATH + ".tmp", VALID_PATH + ".bak"]:
			if FileAccess.file_exists(path):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _check(ok: bool, detail: String) -> bool:
	if not ok:
		_failures.append(detail)
		push_error("[Flujo] Potok 9B3-B2 assertion: " + detail)
	return ok
