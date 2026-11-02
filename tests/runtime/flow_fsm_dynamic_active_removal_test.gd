extends Node

## Potok 8C1 — active dynamic-state deletion must be transactional and safe.
var _failures: Array[String] = []
var _events: Array[String] = []
var _runtime: FlowFSMRuntime
var _machine_id: String = ""
var _active_alias_id: String = ""
var _tick_fallback_id: String = ""
var _attempt_during_tick: bool = false
var _tick_remove_result: bool = true

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	var graph: FlowGraph = FlowGraph.new()
	graph.schema_version = FlowGraph.SCHEMA_VERSION_3
	graph.constructor = FlowConstructorDefinition.new()
	var idle: FlowStateDefinition = FlowStateDefinition.new()
	idle.display_name = "Idle"
	var template: FlowStateDefinition = FlowStateDefinition.new()
	template.display_name = "ActiveTemplate"
	var fallback_template: FlowStateDefinition = FlowStateDefinition.new()
	fallback_template.display_name = "FallbackTemplate"
	var disabled: FlowStateDefinition = FlowStateDefinition.new()
	disabled.display_name = "Disabled"
	disabled.enabled = false
	var foreign: FlowStateDefinition = FlowStateDefinition.new()
	foreign.display_name = "Foreign"
	var machine: FlowStateMachineDefinition = FlowStateMachineDefinition.new()
	machine.tick_mode = FlowStateMachineDefinition.TickMode.MANUAL
	machine.states = [idle, template, fallback_template, disabled]
	machine.initial_state_id = idle.get_internal_id()
	var other_machine: FlowStateMachineDefinition = FlowStateMachineDefinition.new()
	other_machine.tick_mode = FlowStateMachineDefinition.TickMode.MANUAL
	other_machine.states = [foreign]
	other_machine.initial_state_id = foreign.get_internal_id()
	graph.state_machines = [machine, other_machine]
	var controller: PVController = PVController.new()
	controller.flow_graph = graph
	add_child(controller)
	await get_tree().process_frame
	_runtime = controller.get_fsm_runtime()
	if not _check(_runtime != null and _runtime.is_running(), "FSM runtime started"):
		get_tree().quit(1)
		return
	_machine_id = machine.get_internal_id()
	_runtime.state_exited.connect(_on_state_exited)
	_runtime.state_entered.connect(_on_state_entered)
	_runtime.transition_committed.connect(_on_committed)
	_runtime.state_updated.connect(_on_state_updated)
	var alias: String = _runtime.register_state(_machine_id, template.get_internal_id())
	var backup: String = _runtime.register_state(_machine_id, fallback_template.get_internal_id())
	if not _check(FlowId.is_valid(alias) and FlowId.is_valid(backup),
			"Two distinct runtime aliases registered"):
		get_tree().quit(1)
		return
	_check(_runtime.change_state(_machine_id, alias), "Alias activation requested")
	_runtime.tick(0.2, FlowStateMachineDefinition.TickMode.MANUAL)
	_check(_runtime.get_active_state_id(_machine_id) == alias, "Alias active")
	_events.clear()
	var original_ids: Array[String] = _runtime.get_dynamic_state_ids(_machine_id)
	var failures: Array[String] = ["", alias, "absent", disabled.get_internal_id(),
		foreign.get_internal_id()]
	for fallback_id: String in failures:
		_check(not _runtime.remove_state(_machine_id, alias, fallback_id),
			"Invalid active fallback '%s' must reject" % fallback_id)
		_check(_runtime.get_active_state_id(_machine_id) == alias
			and _runtime.get_dynamic_state_ids(_machine_id) == original_ids
			and _events.is_empty(), "Rejected fallback leaves machine and signals unchanged")
	_attempt_during_tick = true
	_active_alias_id = alias
	_tick_fallback_id = backup
	_tick_remove_result = true
	_runtime.tick(0.2, FlowStateMachineDefinition.TickMode.MANUAL)
	_attempt_during_tick = false
	_check(not _tick_remove_result, "Active removal during tick rejected")
	_check(_runtime.get_active_state_id(_machine_id) == alias
		and _runtime.get_dynamic_state_ids(_machine_id) == original_ids
		and _events.is_empty(), "Tick-time rejection does not mutate runtime")
	_check(_runtime.remove_state(_machine_id, alias, backup),
		"Active alias transitions safely to another dynamic alias")
	_check(_runtime.get_active_state_id(_machine_id) == backup
		and not _runtime.has_state(_machine_id, alias)
		and _runtime.get_dynamic_state_ids(_machine_id) == [backup],
		"Fallback dynamic alias active and deleted source no longer resolvable")
	_check(_events == [
		"exit:" + alias,
		"enter:" + backup,
		"commit:" + alias + ">" + backup + ":dynamic-removal"
	], "Active alias fallback preserves Exit, Enter, commit signal order")
	_events.clear()
	_check(_runtime.remove_state(_machine_id, backup, idle.get_internal_id()),
		"Second dynamic alias can fall back to authored initial state")
	_check(_runtime.get_active_state_id(_machine_id) == idle.get_internal_id()
		and _runtime.get_dynamic_state_ids(_machine_id).is_empty(),
		"Final alias removed without changing authored initial state")
	_check(_events == [
		"exit:" + backup,
		"enter:" + idle.get_internal_id(),
		"commit:" + backup + ">" + idle.get_internal_id() + ":dynamic-removal"
	], "Dynamic to authored fallback signal order")
	_check(not _runtime.remove_state(_machine_id, alias, idle.get_internal_id()),
		"Second removal of removed ID rejects without mutation")
	_check(machine.states.size() == 4
		and other_machine.states.size() == 1
		and not FlowGraphValidator.validate(graph).has_errors(),
		"Graph structure untouched by dynamic transitions and deletions")
	controller.visual_program_enabled = false
	controller.queue_free()
	await get_tree().process_frame
	if _failures.is_empty():
		print("[Flujo] Potok 8C1 active alias fallback and lifecycle passed")
	else:
		for failure: String in _failures:
			push_error("[Flujo] Potok 8C1: " + failure)
	get_tree().quit(0 if _failures.is_empty() else 1)

func _on_state_exited(machine_id: String, state_id: String) -> void:
	if machine_id == _machine_id:
		_events.append("exit:" + state_id)

func _on_state_entered(machine_id: String, state_id: String) -> void:
	if machine_id == _machine_id:
		_events.append("enter:" + state_id)

func _on_committed(machine_id: String, old_id: String, new_id: String, trigger: String) -> void:
	if machine_id == _machine_id:
		_events.append("commit:" + old_id + ">" + new_id + ":" + trigger)

func _on_state_updated(machine_id: String, state_id: String) -> void:
	if _attempt_during_tick and machine_id == _machine_id and state_id == _active_alias_id:
		_tick_remove_result = _runtime.remove_state(_machine_id, _active_alias_id, _tick_fallback_id)

func _check(value: bool, description: String) -> bool:
	if not value:
		_failures.append(description)
		push_error("[Flujo] Potok 8C1 assertion: " + description)
	return value
