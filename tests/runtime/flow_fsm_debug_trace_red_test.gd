extends Node

## Potok 10B-1A isolated RED candidate. Never register in mandatory CI until GREEN.
## This script tests only a small approved core API candidate; no editor or SDK calls.
var _failures: Array[String] = []


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var graph: FlowGraph = FlowGraph.new()
	graph.schema_version = FlowGraph.SCHEMA_VERSION_3
	graph.constructor = FlowConstructorDefinition.new()
	var idle: FlowStateDefinition = FlowStateDefinition.new()
	idle.display_name = "Idle"
	var machine: FlowStateMachineDefinition = FlowStateMachineDefinition.new()
	machine.states = [idle]
	machine.initial_state_id = idle.get_internal_id()
	machine.tick_mode = FlowStateMachineDefinition.TickMode.MANUAL
	graph.state_machines = [machine]
	if not _check(not FlowGraphValidator.validate(graph).has_errors(), "Fixture validates"):
		_finish()
		return
	var controller: PVController = PVController.new()
	controller.flow_graph = graph
	add_child(controller)
	await get_tree().process_frame
	var runtime: FlowFSMRuntime = controller.get_fsm_runtime()
	if not _check(runtime != null and runtime.is_running(), "Runtime started"):
		controller.queue_free()
		_finish()
		return
	controller.set_process(false)
	controller.set_physics_process(false)
	var machine_id: String = machine.get_internal_id()
	var idle_id: String = idle.get_internal_id()

	# The current runtime has none of these methods. This is the intended RED
	# blocker, not an excuse to weaken any original FSM baseline or workflow.
	var required: Array[StringName] = [
		&"set_debug_capture_enabled", &"get_debug_records", &"get_debug_snapshot"
	]
	var missing: Array[String] = []
	for method: StringName in required:
		if not runtime.has_method(method):
			missing.append(String(method))
	if not missing.is_empty():
		_check(false, "Expected RED: missing approved core debug API: " + ", ".join(missing))
		controller.visual_program_enabled = false
		controller.queue_free()
		_finish()
		return

	var initial_records: Array = runtime.call(&"get_debug_records")
	_check(initial_records.is_empty(), "Capture is OFF by default")
	var before_state: String = runtime.get_active_state_id(machine_id)
	_check(before_state == idle_id, "Initial authored state unchanged")
	_check(runtime.call(&"set_debug_capture_enabled", true) == true, "Explicit capture ON accepted")
	for index: int in range(136):
		_check(runtime.emit_event(machine_id, &"pulse", {"private": "DO_NOT_TRACE_PAYLOAD"}),
				"Packet accepted without changing authored graph")
		runtime.tick(0.01, FlowStateMachineDefinition.TickMode.MANUAL)
	var records: Array = runtime.call(&"get_debug_records")
	_check(records.size() == 128, "Bounded 128-entry ring retains only newest records")
	var sequence_before: int = 0
	for item: Variant in records:
		if not _check(item is Dictionary, "Every record is inert Dictionary"):
			continue
		var row: Dictionary = item
		var serialized: String = JSON.stringify(row)
		_check(serialized.to_utf8_buffer().size() <= 1024,
				"Every record fits approved 1024 UTF-8 JSON bytes")
		_check(not serialized.contains("DO_NOT_TRACE_PAYLOAD"), "No arbitrary payload data in trace")
		var sequence: int = int(row.get("sequence", 0))
		_check(sequence > sequence_before, "Per-runtime sequence strictly increasing")
		sequence_before = sequence
	_check(runtime.get_active_state_id(machine_id) == idle_id,
			"Observability cannot change the state of a machine with no edges")
	var snapshot: Dictionary = runtime.call(&"get_debug_snapshot")
	_check(bool(snapshot.get("running", false)), "Late snapshot describes live runtime")
	_check(runtime.get_active_machine_ids() == [machine_id],
			"Single-machine fixture preserves authored identity")
	_check(graph.state_machines == [machine] and machine.states == [idle],
			"Authored resource remains unchanged")
	controller.visual_program_enabled = false
	controller.queue_free()
	await get_tree().process_frame
	_finish()


func _check(ok: bool, description: String) -> bool:
	if not ok:
		_failures.append(description)
		push_error("[Flujo] Potok-10B1A: " + description)
	return ok


func _finish() -> void:
	if _failures.is_empty():
		print("[Flujo] Potok-10B1A opt-in bounded debug trace passed")
	get_tree().quit(0 if _failures.is_empty() else 1)
