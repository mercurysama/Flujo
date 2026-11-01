extends Node
## Potok 6H-1: disabled/unstarted ID rejection and scene-tree order independence.
var failures: Array[String] = []

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	var graph := FlowGraph.new()
	graph.schema_version = FlowGraph.SCHEMA_VERSION_3
	graph.constructor = FlowConstructorDefinition.new()
	var a0 := FlowStateDefinition.new()
	var a1 := FlowStateDefinition.new()
	var dormant_state := FlowStateDefinition.new()
	var disabled_state := FlowStateDefinition.new()
	var active := _machine([a0, a1], a0.get_internal_id())
	var dormant := _machine([dormant_state], dormant_state.get_internal_id())
	dormant.auto_start = false
	var disabled := _machine([disabled_state], disabled_state.get_internal_id())
	disabled.enabled = false
	graph.state_machines = [active, dormant, disabled]
	_check(not FlowGraphValidator.validate(graph).has_errors(), "Valid authored graph")
	var first := PVController.new()
	first.flow_graph = graph
	var second := PVController.new()
	second.flow_graph = graph
	add_child(first)
	add_child(second)
	await get_tree().process_frame
	var x: FlowFSMRuntime = first.get_fsm_runtime()
	var y: FlowFSMRuntime = second.get_fsm_runtime()
	if x == null or y == null or not x.is_running() or not y.is_running():
		push_error("Potok 6H-1: both runtimes must start")
		get_tree().quit(1)
		return
	first.set_process(false)
	first.set_physics_process(false)
	second.set_process(false)
	second.set_physics_process(false)
	var main_id: String = active.get_internal_id()
	var dormant_id: String = dormant.get_internal_id()
	var disabled_id: String = disabled.get_internal_id()
	var diagnostics: Array[String] = []
	x.request_rejected.connect(func(id: String, kind: StringName, code: StringName) -> void:
		diagnostics.append(id + ":" + String(kind) + ":" + String(code))
	)
	_check(not x.request_transition(dormant_id, dormant_state.get_internal_id()), "Unstarted direct denied")
	_check(not x.emit_event(dormant_id, &"go"), "Unstarted event denied")
	_check(not x.request_transition(disabled_id, disabled_state.get_internal_id()), "Disabled direct denied")
	_check(not x.emit_event(disabled_id, &"go"), "Disabled event denied")
	_check(not x.request_transition("absent", a1.get_internal_id()), "Unknown direct denied")
	_check(not x.emit_event("absent", &"go"), "Unknown event denied")
	_check(not x.request_transition(main_id, dormant_state.get_internal_id()), "Foreign target denied")
	_check(diagnostics == [
		dormant_id + ":direct:invalid_machine", dormant_id + ":event:invalid_machine",
		disabled_id + ":direct:invalid_machine", disabled_id + ":event:invalid_machine",
		"absent:direct:invalid_machine", "absent:event:invalid_machine",
		main_id + ":direct:invalid_target"
	], "Seven stable diagnostics in request order")
	_check(x.pending_request_count() == 0 and y.pending_request_count() == 0,
		"No rejected packet changes either controller queue")
	_check(x.get_active_machine_ids().size() == 1 and x.get_active_state_id(main_id) == a0.get_internal_id(),
		"Only active machine starts on first controller")
	_check(y.get_active_machine_ids().size() == 1 and y.get_active_state_id(main_id) == a0.get_internal_id(),
		"Second controller starts independently")
	_check(y.request_transition(main_id, a1.get_internal_id()), "Second root admitted")
	y.tick(0.1, FlowStateMachineDefinition.TickMode.MANUAL)
	_check(y.get_active_state_id(main_id) == a1.get_internal_id(), "Second commits")
	_check(x.get_active_state_id(main_id) == a0.get_internal_id(), "First remains unchanged")
	move_child(second, 0)
	_check(x.request_transition(main_id, a1.get_internal_id()), "First root admitted after reorder")
	x.tick(0.1, FlowStateMachineDefinition.TickMode.MANUAL)
	_check(x.get_active_state_id(main_id) == a1.get_internal_id(), "First commits regardless of tree order")
	_check(y.get_active_state_id(main_id) == a1.get_internal_id(), "Second remains stable after reorder")
	_check(diagnostics.size() == 7 and not FlowGraphValidator.validate(graph).has_errors(),
		"Neither tree reordering nor transitions change authored data")
	first.visual_program_enabled = false
	second.visual_program_enabled = false
	first.queue_free()
	second.queue_free()
	await get_tree().process_frame
	if failures.is_empty():
		print("[Flujo] Potok 6H-1 negative routing and scene order passed")
	get_tree().quit(0 if failures.is_empty() else 1)

func _machine(states: Array[FlowStateDefinition], initial: String) -> FlowStateMachineDefinition:
	var machine := FlowStateMachineDefinition.new()
	machine.states = states
	machine.initial_state_id = initial
	machine.tick_mode = FlowStateMachineDefinition.TickMode.MANUAL
	return machine

func _check(ok: bool, description: String) -> void:
	if not ok:
		failures.append(description)
		push_error("[Flujo] Potok 6H-1: " + description)
