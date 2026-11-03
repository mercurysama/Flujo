extends Node

## Potok 8D1-B1 intentionally RED: contract for a machine-scoped FSM
## capability supplied to external-style FlowBlock execution in FSM phases.
var _failures: Array[String] = []

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	var probe_script: Script = load("res://tests/fixtures/fsm_sdk_capability_probe.gd") as Script
	if not _check(probe_script != null and probe_script.can_instantiate(),
			"Fixture block script can instantiate without a global class_name"):
		get_tree().quit(1)
		return

	var graph: FlowGraph = FlowGraph.new()
	graph.schema_version = FlowGraph.SCHEMA_VERSION_3
	graph.constructor = FlowConstructorDefinition.new()

	var idle: FlowStateDefinition = FlowStateDefinition.new()
	idle.display_name = "Idle"
	var template: FlowStateDefinition = FlowStateDefinition.new()
	template.display_name = "DynamicTemplate"
	var exit_target: FlowStateDefinition = FlowStateDefinition.new()
	exit_target.display_name = "Other"
	var main_machine: FlowStateMachineDefinition = FlowStateMachineDefinition.new()
	main_machine.tick_mode = FlowStateMachineDefinition.TickMode.MANUAL
	main_machine.states = [idle, template, exit_target]
	main_machine.initial_state_id = idle.get_internal_id()
	var unrelated: FlowStateDefinition = FlowStateDefinition.new()
	unrelated.display_name = "Independent"
	var second_machine: FlowStateMachineDefinition = FlowStateMachineDefinition.new()
	second_machine.tick_mode = FlowStateMachineDefinition.TickMode.MANUAL
	second_machine.states = [unrelated]
	second_machine.initial_state_id = unrelated.get_internal_id()
	graph.state_machines = [main_machine, second_machine]

	var ready_probe: FlowBlock = _make_probe(probe_script, template.get_internal_id())
	var enter_probe: FlowBlock = _make_probe(probe_script, template.get_internal_id())
	var update_probe: FlowBlock = _make_probe(probe_script, template.get_internal_id())
	var exit_probe: FlowBlock = _make_probe(probe_script, template.get_internal_id())
	var ready_process: FlowProcess = FlowProcess.new()
	ready_process.process_type = FlowProcess.ProcessType.READY
	ready_process.blocks = [ready_probe]
	graph.processes = [ready_process]
	idle.enter_blocks = [enter_probe]
	idle.blocks = [update_probe]
	idle.exit_blocks = [exit_probe]

	var controller: PVController = PVController.new()
	controller.flow_graph = graph
	add_child(controller)
	await get_tree().process_frame
	var runtime: FlowFSMRuntime = controller.get_fsm_runtime()
	if not _check(runtime != null and runtime.is_running(),
			"Controller FSM is running"):
		controller.queue_free()
		get_tree().quit(1)
		return
	var machine_id: String = main_machine.get_internal_id()
	var second_id: String = second_machine.get_internal_id()
	var observations: Array = controller.get_meta("potok_8d1_observations", [])
	_check(observations.size() == 2, "Ready and StateEnter each execute exactly once")
	if observations.size() >= 2:
		_check(observations[0].get("phase") == "Ready"
			and not observations[0].get("available", false),
			"Ready block cannot receive an FSM capability")
		_check(observations[1].get("phase") == "StateEnter"
			and observations[1].get("available", false)
			and FlowId.is_valid(String(observations[1].get("id", ""))),
			"StateEnter receives live machine-scoped register_state capability")

	runtime.tick(0.1, FlowStateMachineDefinition.TickMode.MANUAL)
	observations = controller.get_meta("potok_8d1_observations", [])
	_check(observations.size() == 3
		and observations[2].get("phase") == "StateUpdate"
		and observations[2].get("available", false)
		and FlowId.is_valid(String(observations[2].get("id", ""))),
		"StateUpdate receives same-machine capability")
	_check(runtime.change_state(machine_id, exit_target.get_internal_id()),
		"External direct request can transition out of probed state")
	runtime.tick(0.1, FlowStateMachineDefinition.TickMode.MANUAL)
	observations = controller.get_meta("potok_8d1_observations", [])
	_check(observations.size() == 4
		and observations[3].get("phase") == "StateExit"
		and observations[3].get("available", false)
		and FlowId.is_valid(String(observations[3].get("id", ""))),
		"StateExit receives capability via the shared executor")
	_check(runtime.get_dynamic_state_ids(machine_id).size() == 3,
		"Three FSM callbacks register distinct instance-local aliases")
	_check(runtime.get_dynamic_state_ids(second_id).is_empty(),
		"Facade cannot create aliases in a sibling machine")
	_check(main_machine.states.size() == 3 and second_machine.states.size() == 1
		and not FlowGraphValidator.validate(graph).has_errors(),
		"Authored FlowGraph stays immutable after block-requested aliases")

	controller.visual_program_enabled = false
	controller.queue_free()
	await get_tree().process_frame
	if _failures.is_empty():
		print("[Flujo] Potok 8D1-B1 FSM context capability contract passed")
	else:
		for failure: String in _failures:
			push_error("[Flujo] Potok 8D1-B1 assertion: " + failure)
	get_tree().quit(0 if _failures.is_empty() else 1)

func _make_probe(script: Script, template_id: String) -> FlowBlock:
	var probe: FlowBlock = script.new() as FlowBlock
	if probe != null:
		probe.set("template_state_id", template_id)
	return probe

func _check(ok: bool, description: String) -> bool:
	if not ok:
		_failures.append(description)
		push_error("[Flujo] Potok 8D1-B1: " + description)
	return ok
