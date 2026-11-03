extends Node

## Test-only authored IDs remain stable between independent Godot launches.
@export_enum("write", "restore") var phase: String = "write"
const PATH: String = "user://flujo_fsm_tests/phase9_restart/snapshot.json"
const GRAPH_ID: String = "a91d0000000000000000000000000001"
const MACHINE_ID: String = "a91d0000000000000000000000000002"
const IDLE_ID: String = "a91d0000000000000000000000000003"
const TEMPLATE_ID: String = "a91d0000000000000000000000000004"
var failures: Array[String] = []


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var graph: FlowGraph = _fixture()
	if not _check(not FlowGraphValidator.validate(graph).has_errors(), "Stable graph fixture validates"):
		get_tree().quit(1)
		return
	var owner: PVController = PVController.new()
	owner.flow_graph = graph
	add_child(owner)
	await get_tree().process_frame
	var rt: FlowFSMRuntime = owner.get_fsm_runtime()
	if not _check(rt != null and rt.is_running(), "FSM controller started"):
		owner.queue_free()
		get_tree().quit(1)
		return
	owner.set_process(false)
	owner.set_physics_process(false)
	if phase == "write":
		_write(rt)
	elif phase == "restore":
		_restore(rt)
	else:
		_check(false, "Unexpected scene phase")
	owner.visual_program_enabled = false
	owner.queue_free()
	await get_tree().process_frame
	if failures.is_empty():
		print("[Flujo] Potok 9R1 process " + phase + " passed")
	else:
		for f: String in failures:
			push_error("[Flujo] Potok 9R1: " + f)
	get_tree().quit(0 if failures.is_empty() else 1)


func _fixture() -> FlowGraph:
	var graph: FlowGraph = FlowGraph.new()
	graph._internal_id = GRAPH_ID
	graph.schema_version = FlowGraph.SCHEMA_VERSION_3
	graph.constructor = FlowConstructorDefinition.new()
	var idle: FlowStateDefinition = FlowStateDefinition.new()
	idle._internal_id = IDLE_ID
	idle.display_name = "Idle"
	var template: FlowStateDefinition = FlowStateDefinition.new()
	template._internal_id = TEMPLATE_ID
	template.display_name = "Template"
	var machine: FlowStateMachineDefinition = FlowStateMachineDefinition.new()
	machine._internal_id = MACHINE_ID
	machine.tick_mode = FlowStateMachineDefinition.TickMode.MANUAL
	machine.states = [idle, template]
	machine.initial_state_id = IDLE_ID
	graph.state_machines = [machine]
	return graph


func _write(rt: FlowFSMRuntime) -> void:
	if not _check(not FileAccess.file_exists(PATH), "New isolated path has no old snapshot"):
		return
	var ephemeral: String = rt.register_state(MACHINE_ID, TEMPLATE_ID, "",
			FlowFSMDynamicStateRecord.Lifetime.EPHEMERAL, {"type": "ephemeral"})
	var session: String = rt.register_state(MACHINE_ID, TEMPLATE_ID, "",
			FlowFSMDynamicStateRecord.Lifetime.SESSION, {"type": "session"})
	var persisted: String = rt.register_state(MACHINE_ID, TEMPLATE_ID, "",
			FlowFSMDynamicStateRecord.Lifetime.PERSISTENT,
			{"generation": 42, "nested": {"label": "two-process"}, "items": [2, 4, 6]})
	if not _check(FlowId.is_valid(ephemeral) and FlowId.is_valid(session)
			and FlowId.is_valid(persisted), "All three aliases registered"):
		return
	_check(rt.change_state(MACHINE_ID, persisted), "Persistent alias queued")
	rt.tick(0.1, FlowStateMachineDefinition.TickMode.MANUAL)
	_check(rt.get_active_state_id(MACHINE_ID) == persisted, "Persistent alias activated")
	var snapshot: Dictionary = rt.export_snapshot()
	var entries: Array = snapshot.get("dynamic_states", [])
	_check(snapshot.get("format_version") == 1 and entries.size() == 1,
			"Only persistent alias is serialized")
	if entries.size() == 1:
		_check((entries[0] as Dictionary).get("runtime_id") == persisted,
				"Saved alias identity is correct")
	_check(rt.save_to_file(PATH), "Process A writes a real user snapshot")
	_check(FileAccess.file_exists(PATH), "File exists after save")
	if FileAccess.file_exists(PATH):
		_check(JSON.parse_string(FileAccess.get_file_as_string(PATH))
				== JSON.parse_string(JSON.stringify(snapshot)),
				"Disk bytes represent the exact v1 snapshot")
	print("[Flujo] Potok 9R1 process A: " + ProjectSettings.globalize_path(PATH))


func _restore(rt: FlowFSMRuntime) -> void:
	if not _check(FileAccess.file_exists(PATH), "Process B sees file written by process A"):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if not _check(parsed is Dictionary, "Disk file is a JSON object"):
		return
	var saved: Dictionary = parsed
	var records: Array = saved.get("dynamic_states", [])
	if not _check(saved.get("format_version") == 1
			and saved.get("graph_id") == GRAPH_ID
			and saved.get("schema_version") == FlowGraph.SCHEMA_VERSION_3
			and records.size() == 1, "Static graph identity matches across processes"):
		return
	var alias: String = String((records[0] as Dictionary).get("runtime_id", ""))
	_check(FlowId.is_valid(alias), "Persistent alias ID is valid")
	_check(rt.get_active_state_id(MACHINE_ID) == IDLE_ID
			and not rt.has_state(MACHINE_ID, alias),
			"New process has no implicit alias or active-state restoration")
	_check((rt.export_snapshot().get("dynamic_states", []) as Array).is_empty(),
			"Fresh instance contains neither session nor ephemeral alias")
	_check(rt.restore_from_file(PATH), "Explicit restore_from_file succeeds")
	_check(rt.has_state(MACHINE_ID, alias)
			and rt.get_active_state_id(MACHINE_ID) == alias,
			"Persistent alias reactivated with exact original ID")
	var data: Dictionary = rt.get_dynamic_state_data(MACHINE_ID, alias)
	_check(data.get("generation") == 42
			and (data.get("nested", {}) as Dictionary).get("label") == "two-process"
			and (data.get("items", []) as Array).size() == 3,
			"Detached persistent data recovered from disk")
	_check(JSON.parse_string(JSON.stringify(rt.export_snapshot())) == saved,
			"Portable snapshot matches source process")
	print("[Flujo] Potok 9R1 process B: " + ProjectSettings.globalize_path(PATH))


func _check(ok: bool, description: String) -> bool:
	if not ok:
		failures.append(description)
		push_error("[Flujo] Potok 9R1 assertion: " + description)
	return ok
