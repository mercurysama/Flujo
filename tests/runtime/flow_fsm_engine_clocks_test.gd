extends Node

## FSM-4C: real Godot clocks, scene pause and deferred stop in callbacks.
var failures: Array[String] = []
var entries: Array[String] = []


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var graph: FlowGraph = FlowGraph.new()
	graph.schema_version = FlowGraph.SCHEMA_VERSION_3
	graph.constructor = FlowConstructorDefinition.new()
	var update_process: FlowStateDefinition = _state("process")
	var update_physics: FlowStateDefinition = _state("physics")
	var a: FlowStateMachineDefinition = FlowStateMachineDefinition.new()
	a.states = [update_process]
	a.initial_state_id = update_process.get_internal_id()
	a.tick_mode = FlowStateMachineDefinition.TickMode.PROCESS
	var b: FlowStateMachineDefinition = FlowStateMachineDefinition.new()
	b.states = [update_physics]
	b.initial_state_id = update_physics.get_internal_id()
	b.tick_mode = FlowStateMachineDefinition.TickMode.PHYSICS
	graph.state_machines = [a, b]

	var controller: PVController = PVController.new()
	controller.process_mode = Node.PROCESS_MODE_PAUSABLE
	controller.flow_graph = graph
	controller.runtime_output.entry_message_emitted.connect(_on_output)
	get_tree().root.add_child(controller)
	await get_tree().create_timer(0.16).timeout
	var runtime: FlowFSMRuntime = controller.get_fsm_runtime()
	if not _check(runtime != null and runtime.is_running(), "FSM starts for two engine clocks"):
		controller.queue_free()
		_finish()
		return
	var process_before: int = entries.count("StateUpdate:process")
	var physics_before: int = entries.count("StateUpdate:physics")
	_check(process_before > 0, "Godot _process drives PROCESS state.")
	_check(physics_before > 0, "Godot _physics_process drives PHYSICS state.")
	_check(entries.count("StateEnter:process") == 1 and entries.count("StateEnter:physics") == 1,
		"Both machines Enter exactly once before pause.")

	get_tree().paused = true
	var frozen_process: int = entries.count("StateUpdate:process")
	var frozen_physics: int = entries.count("StateUpdate:physics")
	await get_tree().create_timer(0.12, true).timeout
	_check(entries.count("StateUpdate:process") == frozen_process, "SceneTree pause freezes PROCESS.")
	_check(entries.count("StateUpdate:physics") == frozen_physics, "SceneTree pause freezes PHYSICS.")
	get_tree().paused = false
	await get_tree().create_timer(0.12).timeout
	_check(entries.count("StateUpdate:process") > frozen_process, "PROCESS resumes after unpause.")
	_check(entries.count("StateUpdate:physics") > frozen_physics, "PHYSICS resumes after unpause.")

	var before_exit: int = entries.count("StateExit:process")
	var callback_calls: Array[String] = []
	runtime.state_updated.connect(func(machine_id: String, _state_id: String) -> void:
		if machine_id != a.get_internal_id() or not callback_calls.is_empty():
			return
		callback_calls.append("update")
		runtime.stop()
		callback_calls.append("stop_queued")
	)
	await get_tree().create_timer(0.1).timeout
	_check(callback_calls == ["update", "stop_queued"], "Stop callback invoked once.")
	_check(not runtime.is_running(), "Stop during Update is deferred and eventually completes.")
	_check(entries.count("StateExit:process") == before_exit + 1,
		"Deferred stop triggers exactly one source Exit.")
	_check(entries.count("StateExit:physics") == 1, "Deferred stop exits second clock exactly once.")

	controller.queue_free()
	await get_tree().process_frame
	_check(entries.count("StateExit:process") == before_exit + 1,
		"Teardown does not execute a duplicate Exit after deferred stop.")
	_finish()


func _state(message: String) -> FlowStateDefinition:
	var state: FlowStateDefinition = FlowStateDefinition.new()
	var on_enter: FlowPrintBlock = FlowPrintBlock.new()
	on_enter.text = message
	var on_update: FlowPrintBlock = FlowPrintBlock.new()
	on_update.text = message
	var on_exit: FlowPrintBlock = FlowPrintBlock.new()
	on_exit.text = message
	state.enter_blocks = [on_enter]
	state.blocks = [on_update]
	state.exit_blocks = [on_exit]
	return state


func _on_output(_controller: Node, _container_id: String, _block_id: String, message: String,
		entry_point: StringName) -> void:
	entries.append("%s:%s" % [String(entry_point), message])


func _check(condition: bool, text: String) -> bool:
	if not condition:
		failures.append(text)
		push_error("[Flujo] FSM-4C: " + text)
	return condition


func _finish() -> void:
	get_tree().paused = false
	if failures.is_empty():
		print("[Flujo] FSM-4C clocks and pause test passed")
	get_tree().quit(0 if failures.is_empty() else 1)
