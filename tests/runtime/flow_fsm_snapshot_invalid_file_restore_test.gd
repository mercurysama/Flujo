extends Node

## Potok 9C1-A: disk restore preflight rejects hostile or incompatible files
## without changing live state or dropping a previously queued transition.
const ROOT: String = "user://flujo_fsm_tests/"
const INVALID_PATH: String = ROOT + "phase9_9c1_invalid.json"
const ABSENT_PATH: String = ROOT + "phase9_9c1_absent.json"
const MAX_LENGTH: int = FlowFSMDataValidator.MAX_JSON_LENGTH
var _failures: Array[String] = []
var _owns_file: bool = false


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	if FileAccess.file_exists(INVALID_PATH) or FileAccess.file_exists(ABSENT_PATH):
		_check(false, "Reserved 9C1 fixture paths must be unused")
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
	if not _check(runtime != null, "Controller provides an FSM runtime"):
		controller.queue_free()
		get_tree().quit(1)
		return
	var alias_id: String = runtime.register_state(
		mid, active.get_internal_id(), "",
		FlowFSMDynamicStateRecord.Lifetime.PERSISTENT,
		{"generation": 9, "label": "live"}
	)
	_check(FlowId.is_valid(alias_id), "Persistent runtime state registered")
	_check(runtime.change_state(mid, alias_id), "Persistent state activation requested")
	runtime.tick(0.1, FlowStateMachineDefinition.TickMode.MANUAL)
	_check(runtime.get_active_state_id(mid) == alias_id, "Persistent state active")
	var before: Dictionary = runtime.export_snapshot()
	_check(runtime.change_state(mid, idle.get_internal_id()),
			"Direct request enqueued before invalid disk restorations")

	_check(not runtime.restore_from_file(ABSENT_PATH),
			"Missing snapshot file is rejected")
	_assert_unchanged(runtime, mid, alias_id, before, "missing file")
	_check(_write_fixture("{bad json"), "Corrupt JSON fixture written")
	_check(not runtime.restore_from_file(INVALID_PATH),
			"Malformed JSON is rejected")
	_assert_unchanged(runtime, mid, alias_id, before, "malformed JSON")
	_check(_write_fixture("[]"), "JSON array fixture written")
	_check(not runtime.restore_from_file(INVALID_PATH),
			"Non-dictionary JSON root is rejected")
	_assert_unchanged(runtime, mid, alias_id, before, "non-dictionary root")
	_check(_write_fixture("x".repeat(MAX_LENGTH + 1)), "Over-budget fixture written")
	_check(not runtime.restore_from_file(INVALID_PATH),
			"Excessively long file is rejected before parsing")
	_assert_unchanged(runtime, mid, alias_id, before, "oversized file")
	var invalid_version: Dictionary = before.duplicate(true)
	invalid_version["format_version"] = 999
	_check(_write_fixture(JSON.stringify(invalid_version)),
			"Incompatible version fixture written")
	_check(not runtime.restore_from_file(INVALID_PATH),
			"Unsupported snapshot format version rejected")
	_assert_unchanged(runtime, mid, alias_id, before, "bad format version")
	var foreign_graph: Dictionary = before.duplicate(true)
	foreign_graph["graph_id"] = "different-graph-id"
	_check(_write_fixture(JSON.stringify(foreign_graph)),
			"Foreign graph fixture written")
	_check(not runtime.restore_from_file(INVALID_PATH),
			"Foreign graph identity rejected")
	_assert_unchanged(runtime, mid, alias_id, before, "foreign graph")

	runtime.tick(0.1, FlowStateMachineDefinition.TickMode.MANUAL)
	_check(runtime.get_active_state_id(mid) == idle.get_internal_id(),
			"Pending transition survives every failed file restore")
	_check(runtime.has_state(mid, alias_id)
			and runtime.get_dynamic_state_data(mid, alias_id).get("generation") == 9,
			"Rejected files retain persistent state registration and data")
	_cleanup()
	controller.visual_program_enabled = false
	controller.queue_free()
	await get_tree().process_frame
	if _failures.is_empty():
		print("[Flujo] Potok 9C1-A invalid file restore passed")
	else:
		for failure: String in _failures:
			push_error("[Flujo] Potok 9C1-A: " + failure)
	get_tree().quit(0 if _failures.is_empty() else 1)


func _write_fixture(content: String) -> bool:
	var absolute: String = ProjectSettings.globalize_path(INVALID_PATH)
	if DirAccess.make_dir_recursive_absolute(absolute.get_base_dir()) != OK:
		return false
	var output: FileAccess = FileAccess.open(INVALID_PATH, FileAccess.WRITE)
	if output == null:
		return false
	_owns_file = true
	output.store_string(content)
	output.flush()
	output = null
	return FileAccess.get_file_as_string(INVALID_PATH) == content


func _assert_unchanged(runtime: FlowFSMRuntime, mid: String, alias_id: String,
		expected: Dictionary, label: String) -> void:
	_check(runtime.get_active_state_id(mid) == alias_id
			and runtime.export_snapshot() == expected
			and runtime.get_dynamic_state_data(mid, alias_id).get("generation") == 9,
			"Rejected " + label + " keeps active state, alias and data")


func _cleanup() -> void:
	if _owns_file:
		var absolute: String = ProjectSettings.globalize_path(INVALID_PATH)
		if FileAccess.file_exists(absolute):
			DirAccess.remove_absolute(absolute)


func _check(ok: bool, detail: String) -> bool:
	if not ok:
		_failures.append(detail)
		push_error("[Flujo] Potok 9C1-A assertion: " + detail)
	return ok
