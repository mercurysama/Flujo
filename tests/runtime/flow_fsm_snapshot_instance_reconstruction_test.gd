extends Node

## Potok 9C2-A: true controller teardown followed by a fresh controller
## restoring a portable persistent snapshot explicitly from user://.
const FILE_PATH: String = "user://flujo_fsm_tests/phase9_9c2_reconstruct.json"
var _failures: Array[String] = []
var _owns_file: bool = false


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	if FileAccess.file_exists(FILE_PATH):
		_check(false, "Dedicated 9C2 path must be absent before the test")
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

	var source: PVController = PVController.new()
	source.flow_graph = graph
	add_child(source)
	await get_tree().process_frame
	var runtime: FlowFSMRuntime = source.get_fsm_runtime()
	if not _check(runtime != null, "Original controller runtime exists"):
		source.queue_free()
		get_tree().quit(1)
		return
	var session_id: String = runtime.register_state(
		mid, active.get_internal_id(), "",
		FlowFSMDynamicStateRecord.Lifetime.SESSION, {"source": "session"}
	)
	var persistent_id: String = runtime.register_state(
		mid, active.get_internal_id(), "",
		FlowFSMDynamicStateRecord.Lifetime.PERSISTENT,
		{"generation": 7, "nested": {"label": "disk"}}
	)
	_check(FlowId.is_valid(session_id) and FlowId.is_valid(persistent_id),
			"Session and persistent aliases registered")
	_check(runtime.change_state(mid, persistent_id), "Persistent alias activation requested")
	runtime.tick(0.1, FlowStateMachineDefinition.TickMode.MANUAL)
	_check(runtime.get_active_state_id(mid) == persistent_id,
			"Persistent alias active before save")
	var snapshot_before: Dictionary = runtime.export_snapshot()
	var portable_before: Variant = JSON.parse_string(JSON.stringify(snapshot_before))
	_check(runtime.save_to_file(FILE_PATH), "First controller saves persistent snapshot")
	_owns_file = FileAccess.file_exists(FILE_PATH)
	_check(FileAccess.file_exists(FILE_PATH), "Snapshot file exists")
	_check(JSON.parse_string(FileAccess.get_file_as_string(FILE_PATH)) == portable_before,
			"Disk JSON equals original portable snapshot")
	var source_runtime_id: int = runtime.get_instance_id()
	source.visual_program_enabled = false
	source.queue_free()
	await get_tree().process_frame

	var replacement: PVController = PVController.new()
	replacement.flow_graph = graph
	add_child(replacement)
	await get_tree().process_frame
	var runtime_b: FlowFSMRuntime = replacement.get_fsm_runtime()
	if not _check(runtime_b != null and runtime_b.is_running()
			and runtime_b.get_instance_id() != source_runtime_id,
			"Fresh controller has an independent running FSM runtime"):
		replacement.queue_free()
		_cleanup()
		get_tree().quit(1)
		return
	_check(runtime_b.get_active_state_id(mid) == idle.get_internal_id(),
			"Fresh controller starts in authored initial state, not auto-restored")
	_check(not runtime_b.has_state(mid, persistent_id)
			and not runtime_b.has_state(mid, session_id),
			"Neither dynamic alias auto-survives instance teardown")
	_check(runtime_b.restore_from_file(FILE_PATH),
			"Fresh controller explicitly restores disk snapshot")
	_check(runtime_b.get_active_state_id(mid) == persistent_id
			and runtime_b.has_state(mid, persistent_id),
			"Persistent alias and active identity are recovered")
	_check(not runtime_b.has_state(mid, session_id),
			"SESSION alias from original instance is never restored")
	_check(runtime_b.get_dynamic_state_data(mid, persistent_id).get("generation") == 7,
			"Persistent data restored after instance reconstruction")
	var portable_after: Variant = JSON.parse_string(JSON.stringify(runtime_b.export_snapshot()))
	_check(portable_after == portable_before,
			"Fresh runtime exports same portable snapshot after restore")
	_check(FileAccess.get_file_as_string(FILE_PATH) != "",
			"Explicit restore leaves disk file intact")
	_cleanup()
	replacement.visual_program_enabled = false
	replacement.queue_free()
	await get_tree().process_frame
	if _failures.is_empty():
		print("[Flujo] Potok 9C2-A instance reconstruction disk restore passed")
	else:
		for failure: String in _failures:
			push_error("[Flujo] Potok 9C2-A: " + failure)
	get_tree().quit(0 if _failures.is_empty() else 1)


func _cleanup() -> void:
	if _owns_file:
		var absolute: String = ProjectSettings.globalize_path(FILE_PATH)
		for file_path: String in [absolute, absolute + ".tmp", absolute + ".bak"]:
			if FileAccess.file_exists(file_path):
				DirAccess.remove_absolute(file_path)


func _check(ok: bool, detail: String) -> bool:
	if not ok:
		_failures.append(detail)
		push_error("[Flujo] Potok 9C2-A assertion: " + detail)
	return ok
