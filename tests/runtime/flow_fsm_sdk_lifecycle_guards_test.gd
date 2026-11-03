extends Node

## Potok 8D1-C1B: retained Update/Exit facades, reset, graph swap and restart.
## A directly constructed facade tests _can_use's graph guard separately from SDK dispatch.
var _failures: Array[String] = []


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var probe_script: Script = load(
		"res://tests/fixtures/fsm_sdk_retained_operations_probe.gd"
	) as Script
	if not _check(probe_script != null and probe_script.can_instantiate(),
			"SDK callback probe can instantiate"):
		get_tree().quit(1)
		return

	var graph: FlowGraph = FlowGraph.new()
	graph.schema_version = FlowGraph.SCHEMA_VERSION_3
	graph.constructor = FlowConstructorDefinition.new()
	var idle: FlowStateDefinition = FlowStateDefinition.new()
	idle.display_name = "Idle"
	var template: FlowStateDefinition = FlowStateDefinition.new()
	template.display_name = "Template"
	var machine: FlowStateMachineDefinition = FlowStateMachineDefinition.new()
	machine.tick_mode = FlowStateMachineDefinition.TickMode.MANUAL
	machine.states = [idle, template]
	machine.initial_state_id = idle.get_internal_id()
	graph.state_machines = [machine]
	idle.enter_blocks = [_probe(probe_script, template.get_internal_id())]
	idle.blocks = [_probe(probe_script, template.get_internal_id())]
	idle.exit_blocks = [_probe(probe_script, template.get_internal_id())]

	var controller: PVController = PVController.new()
	controller.flow_graph = graph
	add_child(controller)
	await get_tree().process_frame
	var runtime: FlowFSMRuntime = controller.get_fsm_runtime()
	if not _check(runtime != null and runtime.is_running(),
			"Runtime starts on controller"):
		controller.queue_free()
		get_tree().quit(1)
		return

	var machine_id: String = machine.get_internal_id()
	runtime.tick(0.1, FlowStateMachineDefinition.TickMode.MANUAL)
	_check(runtime.reset(), "Reset performs Exit then Enter without mutating graph")
	var captured: Array = controller.get_meta("potok_8d1c1_records", [])
	if not _check(captured.size() == 4,
			"Callbacks follow Enter, Update, reset Exit, reset Enter"):
		controller.visual_program_enabled = false
		controller.queue_free()
		get_tree().quit(1)
		return
	var phases: Array[String] = ["StateEnter", "StateUpdate", "StateExit", "StateEnter"]
	var created: Array[String] = []
	for i: int in 4:
		var record: Dictionary = captured[i]
		var operations: FlowFSMOperations = record.get("operations") as FlowFSMOperations
		var alias: String = String(record.get("created_id", ""))
		created.append(alias)
		_check(record.get("phase") == phases[i]
			and operations != null and FlowId.is_valid(alias),
			"Phase %d owns one usable callback-local facade" % i)
		if operations != null:
			_check(not operations.has_state(alias)
				and operations.register_state(template.get_internal_id()) == "",
				"Phase %d retained facade expires immediately on return" % i)
	_check(runtime.get_dynamic_state_ids(machine_id).size() == 4,
		"Session aliases created by callbacks survive reset in the same runtime")

	# This direct construction probes the runtime guard, not SDK authorization.
	var context_guard_probe: FlowFSMOperations = FlowFSMOperations.new(
		runtime, controller, graph, machine_id
	)
	if not created.is_empty():
		_check(context_guard_probe.has_state(created[0]),
			"Guard probe sees its own machine while graph matches")
	var alternate_graph: FlowGraph = FlowGraph.new()
	controller.flow_graph = alternate_graph
	if not created.is_empty():
		_check(not context_guard_probe.has_state(created[0]),
			"Graph replacement immediately rejects a formerly live facade")
	_check(context_guard_probe.register_state(template.get_internal_id()) == "",
		"Graph replacement blocks registration even if controller is still in tree")
	controller.flow_graph = graph
	context_guard_probe.invalidate()

	controller.visual_program_enabled = false
	captured = controller.get_meta("potok_8d1c1_records", [])
	_check(captured.size() == 5 and not runtime.is_running(),
		"Disabling controller runs shutdown Exit and stops prior runtime")
	if captured.size() >= 5:
		var shutdown: Dictionary = captured[4]
		_check(shutdown.get("phase") == "StateExit"
			and String(shutdown.get("created_id", "")).is_empty(),
			"Shutdown Exit callback cannot mutate once controller is disabled")
	_check(context_guard_probe.register_state(template.get_internal_id()) == "",
		"Old runtime facade rejects operations after stop")

	controller.visual_program_enabled = true
	var restarted: FlowFSMRuntime = controller.get_fsm_runtime()
	if _check(restarted != null and restarted != runtime and restarted.is_running(),
			"Reenabled controller creates a fresh independent runtime"):
		captured = controller.get_meta("potok_8d1c1_records", [])
		_check(captured.size() == 6
			and captured[5].get("phase") == "StateEnter",
			"Restart executes one new StateEnter callback")
		if captured.size() == 6:
			var new_alias: String = String(captured[5].get("created_id", ""))
			_check(FlowId.is_valid(new_alias)
				and restarted.get_dynamic_state_ids(machine_id) == [new_alias],
				"Restart contains only a newly registered dynamic state")
		for i: int in 4:
			var record: Dictionary = captured[i]
			var old_operations: FlowFSMOperations = record.get("operations") as FlowFSMOperations
			if old_operations != null:
				_check(not old_operations.has_state(String(record.get("created_id", "")))
					and not old_operations.change_state(idle.get_internal_id()),
					"Prior phase %d facade cannot act on restarted runtime" % i)

	_check(machine.states.size() == 2
		and not FlowGraphValidator.validate(graph).has_errors(),
		"Reset, graph swap and restart preserve authored FlowGraph")
	controller.visual_program_enabled = false
	controller.queue_free()
	await get_tree().process_frame
	if _failures.is_empty():
		print("[Flujo] Potok 8D1-C1B SDK lifecycle guards passed")
	else:
		for failure: String in _failures:
			push_error("[Flujo] Potok 8D1-C1B assertion: " + failure)
	get_tree().quit(0 if _failures.is_empty() else 1)


func _probe(script: Script, template_id: String) -> FlowBlock:
	var block: FlowBlock = script.new() as FlowBlock
	if block != null:
		block.set("template_state_id", template_id)
	return block


func _check(ok: bool, description: String) -> bool:
	if not ok:
		_failures.append(description)
		push_error("[Flujo] Potok 8D1-C1B: " + description)
	return ok
