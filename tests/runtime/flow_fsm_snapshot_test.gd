extends Node

const FILE_PATH: String = "user://flujo_fsm_tests/fsm_snapshot.json"
var _failures: Array[String] = []


func _ready() -> void:
	get_tree().create_timer(12.0).timeout.connect(func() -> void:
		push_error("[Flujo] FSM 004 snapshot test timed out before quit.")
		get_tree().quit(1)
	)
	_run.call_deferred()


func _run() -> void:
	var graph: FlowGraph = FlowGraph.new()
	graph.schema_version = FlowGraph.SCHEMA_VERSION_3
	graph.constructor = FlowConstructorDefinition.new()
	var idle: FlowStateDefinition = FlowStateDefinition.new()
	idle.display_name = "Idle"
	var stunned: FlowStateDefinition = FlowStateDefinition.new()
	stunned.display_name = "Stunned"
	var machine: FlowStateMachineDefinition = FlowStateMachineDefinition.new()
	machine.tick_mode = FlowStateMachineDefinition.TickMode.MANUAL
	machine.states = [idle, stunned]
	machine.initial_state_id = idle.get_internal_id()
	graph.state_machines = [machine]
	var mid: String = machine.get_internal_id()
	var a: PVController = PVController.new()
	a.flow_graph = graph
	add_child(a)
	await get_tree().process_frame
	var runtime: FlowFSMRuntime = a.get_fsm_runtime()
	if not _check(runtime != null, "FSM runtime exists"):
		get_tree().quit(1)
		return
	var ephemeral: String = runtime.register_state(
		mid, stunned.get_internal_id(), "",
		FlowFSMDynamicStateRecord.Lifetime.EPHEMERAL, {"count": 1}
	)
	var session: String = runtime.register_state(
		mid, stunned.get_internal_id(), "",
		FlowFSMDynamicStateRecord.Lifetime.SESSION, {"count": 2}
	)
	var persistent: String = runtime.register_state(
		mid, stunned.get_internal_id(), "",
		FlowFSMDynamicStateRecord.Lifetime.PERSISTENT, {"count": 3}
	)
	_check(FlowId.is_valid(ephemeral) and FlowId.is_valid(session) and FlowId.is_valid(persistent),
		"Three dynamic lifetimes register.")
	_check(runtime.change_state(mid, persistent), "Request persistent alias.")
	runtime.tick(0.1, FlowStateMachineDefinition.TickMode.MANUAL)
	_check(runtime.get_active_state_id(mid) == persistent, "Persistent alias becomes active.")
	var saved: Dictionary = runtime.export_snapshot()
	_check(saved.get("format_version") == 1 and saved.get("graph_id") == graph.get_internal_id(),
		"Snapshot identifies format and authored graph.")
	var dynamic_entries: Array = saved.get("dynamic_states", [])
	_check(dynamic_entries.size() == 1 and dynamic_entries[0]["runtime_id"] == persistent,
		"Only PERSISTENT aliases serialize.")
	_check((saved.get("machines", []) as Array)[0]["active_state_id"] == persistent,
		"Persistent active alias is saved.")

	var bad_version: Dictionary = saved.duplicate(true)
	bad_version["format_version"] = 999
	_check(not runtime.restore_snapshot(bad_version), "Unsupported version rejects.")
	_check(runtime.get_active_state_id(mid) == persistent, "Failed restore keeps active state.")
	var bad_target: Dictionary = saved.duplicate(true)
	(bad_target["dynamic_states"] as Array)[0]["template_state_id"] = "missing"
	_check(not runtime.restore_snapshot(bad_target), "Unknown template rejects.")
	_check(runtime.get_dynamic_state_data(mid, persistent)["count"] == 3,
		"Rejected snapshot preserves existing data.")
	var malicious: Dictionary = saved.duplicate(true)
	(malicious["dynamic_states"] as Array)[0]["data"] = {"value": Node.new()}
	_check(not runtime.restore_snapshot(malicious), "Live Godot object rejected.")
	var object: Node = (malicious["dynamic_states"] as Array)[0]["data"]["value"]
	object.free()
	_check(runtime.reset(), "FSM reset succeeds.")
	_check(not runtime.has_state(mid, ephemeral), "EPHEMERAL alias is cleared on reset.")
	_check(runtime.has_state(mid, session), "SESSION alias survives reset.")
	_check(runtime.has_state(mid, persistent), "PERSISTENT alias survives reset.")
	_check(runtime.get_active_state_id(mid) == idle.get_internal_id(), "Reset selects authored initial state.")

	_check(runtime.restore_snapshot(saved), "Valid snapshot restores.")
	_check(runtime.get_active_state_id(mid) == persistent, "Restored active alias matches saved ID.")
	_check(not runtime.has_state(mid, session), "Snapshot replacement discards unsaved SESSION aliases.")
	_check(runtime.get_dynamic_state_data(mid, persistent)["count"] == 3, "Persistent payload restored.")
	_check(runtime.save_to_file(FILE_PATH), "Snapshot saved under user://.")
	_check(FileAccess.file_exists(FILE_PATH), "Snapshot file exists.")
	_check(runtime.save_to_file(FILE_PATH), "Second save replaces file and retains backup.")
	_check(FileAccess.file_exists(FILE_PATH + ".bak"), "Last valid snapshot backup exists.")
	_check(not runtime.save_to_file("res://unexpected.json"), "Project resource path is disallowed.")
	_check(not runtime.save_to_file("user://../escape.json"), "Traversal is disallowed.")

	var b: PVController = PVController.new()
	b.flow_graph = graph
	add_child(b)
	await get_tree().process_frame
	var runtime_b: FlowFSMRuntime = b.get_fsm_runtime()
	_check(runtime_b != null and runtime_b.restore_from_file(FILE_PATH),
		"Second controller loads portable user snapshot.")
	if runtime_b != null:
		_check(runtime_b.get_active_state_id(mid) == persistent, "Second instance restores active alias.")
		_check(runtime_b.get_dynamic_state_data(mid, persistent)["count"] == 3,
			"Second instance receives detached persistent data.")
		_check(runtime_b.set_dynamic_state_data(mid, persistent, {"count": 90}),
			"Second instance can change its local data.")
	_check(runtime.get_dynamic_state_data(mid, persistent)["count"] == 3,
		"Restoring in controller B never mutates controller A.")

	var writer: FileAccess = FileAccess.open(FILE_PATH, FileAccess.WRITE)
	if writer != null:
		writer.store_string("{bad json")
		writer = null
		_check(not runtime_b.restore_from_file(FILE_PATH), "Corrupt JSON rejects.")
		_check(runtime_b.get_active_state_id(mid) == persistent, "Corrupt file cannot change active state.")
	_cleanup()
	a.queue_free()
	b.queue_free()
	await get_tree().process_frame
	if _failures.is_empty():
		print("[Flujo] FSM 004 snapshot test passed")
	else:
		for failure: String in _failures:
			push_error("[Flujo] FSM 004: " + failure)
	get_tree().quit(0 if _failures.is_empty() else 1)


func _cleanup() -> void:
	var absolute: String = ProjectSettings.globalize_path(FILE_PATH)
	for path: String in [absolute, absolute + ".tmp", absolute + ".bak"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)


func _check(value: bool, description: String) -> bool:
	if not value:
		_failures.append(description)
		push_error("[Flujo] FSM 004 assertion: " + description)
	return value
