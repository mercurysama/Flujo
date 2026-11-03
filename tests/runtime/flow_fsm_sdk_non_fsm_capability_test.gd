extends Node

## Potok 8D1-C3: live Ready, Timer, Constructor and method callbacks stay
## outside the FSM capability boundary, including nested method StateUpdate.
var _failures: Array[String] = []


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var script: Script = load("res://tests/fixtures/fsm_sdk_non_fsm_capability_probe.gd") as Script
	if not _check(script != null and script.can_instantiate(),
			"SDK probe is instantiable without class_name"):
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

	var method: FlowMethodDefinition = FlowMethodDefinition.new()
	method.blocks = [_probe(script, "Method", template.get_internal_id())]
	graph.methods = [method]
	graph.constructor.blocks = [_probe(script, "Constructor", template.get_internal_id())]
	var ready: FlowProcess = FlowProcess.new()
	ready.process_type = FlowProcess.ProcessType.READY
	ready.blocks = [
		_probe(script, "Ready", template.get_internal_id()),
		_call(method.get_internal_id())
	]
	var timer: FlowTimerDefinition = FlowTimerDefinition.new()
	timer.interval_seconds = 3600.0
	timer.repeat = true
	timer.blocks = [
		_probe(script, "Timer", template.get_internal_id()),
		_call(method.get_internal_id())
	]
	graph.processes = [ready, timer]
	idle.enter_blocks = [_probe(script, "StateEnter", template.get_internal_id())]
	idle.blocks = [
		_probe(script, "StateUpdate", template.get_internal_id()),
		_call(method.get_internal_id())
	]
	idle.exit_blocks = [_probe(script, "StateExit", template.get_internal_id())]
	if not _check(not FlowGraphValidator.validate(graph).has_errors(),
			"Schema 3 Ready, Timer, Constructor, Method and FSM fixture validates"):
		get_tree().quit(1)
		return

	var controller: PVController = PVController.new()
	controller.flow_graph = graph
	add_child(controller)
	await get_tree().process_frame
	var runtime: FlowFSMRuntime = controller.get_fsm_runtime()
	if not _check(runtime != null and runtime.is_running(),
			"Ready and Constructor execute before real FSM runtime starts"):
		controller.queue_free()
		get_tree().quit(1)
		return
	var machine_id: String = machine.get_internal_id()
	_check(runtime.get_dynamic_state_ids(machine_id).size() == 1,
		"Only the real StateEnter callback registered during startup")

	var timer_runtime: FlowTimerRuntime = controller.get("_timer_runtime") as FlowTimerRuntime
	if _check(timer_runtime != null, "Real Timer scheduler is attached to PVController"):
		var timers: Array[Node] = timer_runtime.get_children(true)
		if _check(timers.size() == 1 and timers[0] is Timer,
				"Exactly one real Timer callback exists"):
			(timers[0] as Timer).timeout.emit()
	_check(runtime.get_dynamic_state_ids(machine_id).size() == 1,
		"Timer and its nested Method cannot register despite live FSM runtime")

	FlowReadyExecutor.new().execute(controller, graph, controller.runtime_output)
	FlowReadyExecutor.new().execute(controller, graph, controller.runtime_output, &"Constructor")
	_check(runtime.get_dynamic_state_ids(machine_id).size() == 1,
		"Replayed Ready, Method and Constructor remain incapable after FSM start")

	runtime.tick(0.1, FlowStateMachineDefinition.TickMode.MANUAL)
	_check(runtime.get_dynamic_state_ids(machine_id).size() == 2,
		"StateUpdate registers, while nested Method in StateUpdate does not")

	# A phase-like string without an explicitly passed FSM runtime is insufficient.
	var wrapper: FlowBlockContainer = FlowBlockContainer.new()
	wrapper.blocks = [_probe(script, "SyntheticPhaseNoRuntime", template.get_internal_id())]
	FlowReadyExecutor.new()._execute_blocks(
		controller, graph, wrapper, "synthetic.fsm.no-runtime",
		controller.runtime_output, &"StateEnter", machine_id,
		controller.get_value_resolution_context(), [], false
	)
	_check(runtime.get_dynamic_state_ids(machine_id).size() == 2,
		"Generic executor cannot create capability from a phase label alone")

	runtime.stop()
	_check(not runtime.is_running() and runtime.get_dynamic_state_ids(machine_id).is_empty(),
		"Stop executes StateExit then clears the controller-local registry")
	var actual: Array = controller.get_meta("potok_8d1c3_records", [])
	var expected: Array[Dictionary] = [
		{"label": "Constructor", "entry": "Constructor", "allowed": false},
		{"label": "Ready", "entry": "Ready", "allowed": false},
		{"label": "Method", "entry": "Ready", "allowed": false},
		{"label": "StateEnter", "entry": "StateEnter", "allowed": true},
		{"label": "Timer", "entry": "Timer", "allowed": false},
		{"label": "Method", "entry": "Timer", "allowed": false},
		{"label": "Ready", "entry": "Ready", "allowed": false},
		{"label": "Method", "entry": "Ready", "allowed": false},
		{"label": "Constructor", "entry": "Constructor", "allowed": false},
		{"label": "StateUpdate", "entry": "StateUpdate", "allowed": true},
		{"label": "Method", "entry": "StateUpdate", "allowed": false},
		{"label": "SyntheticPhaseNoRuntime", "entry": "StateEnter", "allowed": false},
		{"label": "StateExit", "entry": "StateExit", "allowed": true}
	]
	if _check(actual.size() == expected.size(),
			"All expected real and synthetic callbacks execute exactly once in order"):
		for i: int in expected.size():
			var observation: Dictionary = actual[i]
			var target: Dictionary = expected[i]
			var operations: FlowFSMOperations = observation.get("operations") as FlowFSMOperations
			var alias: String = String(observation.get("alias", ""))
			var allowed: bool = bool(target.get("allowed", false))
			_check(observation.get("label") == target.get("label")
				and observation.get("entry") == target.get("entry"),
				"Callback %d matches exact location and entry point" % i)
			_check((operations != null) == allowed
				and (FlowId.is_valid(alias) if allowed else alias.is_empty()),
				"Callback %d has exactly its authorized capability and result" % i)
			if operations != null:
				_check(not operations.has_state(alias)
					and operations.register_state(template.get_internal_id()) == "",
					"Callback %d retained facade expires on return" % i)
	_check(graph.state_machines.size() == 1
		and machine.states == [idle, template]
		and ready.blocks.size() == 2 and timer.blocks.size() == 2
		and method.blocks.size() == 1
		and not FlowGraphValidator.validate(graph).has_errors(),
		"All SDK callbacks leave the authored graph unchanged")

	controller.visual_program_enabled = false
	controller.queue_free()
	await get_tree().process_frame
	if _failures.is_empty():
		print("[Flujo] Potok 8D1-C3 non-FSM SDK capability exclusion passed")
	else:
		for failure: String in _failures:
			push_error("[Flujo] Potok 8D1-C3 assertion: " + failure)
	get_tree().quit(0 if _failures.is_empty() else 1)


func _probe(script: Script, label: String, template_id: String) -> FlowBlock:
	var probe: FlowBlock = script.new() as FlowBlock
	if probe != null:
		probe.set("probe_label", label)
		probe.set("template_state_id", template_id)
	return probe


func _call(target: String) -> FlowMethodCallBlock:
	var block: FlowMethodCallBlock = FlowMethodCallBlock.new()
	block.method_id = target
	return block


func _check(ok: bool, description: String) -> bool:
	if not ok:
		_failures.append(description)
		push_error("[Flujo] Potok 8D1-C3: " + description)
	return ok
