extends Node

## Potok 8D1-C4C2: actual StateUpdate must reject active alias deletion;
## the shared executor can provide a machine-bound SDK callback outside tick.
## No production runtime or public SDK API is added for this test seam.
var _failures: Array[String] = []
var _trace: Array[String] = []


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var sdk: Script = load("res://tests/fixtures/fsm_sdk_active_removal_probe.gd") as Script
	if not _check(sdk != null and sdk.can_instantiate(),
			"External-style SDK callback fixture can instantiate"):
		get_tree().quit(1)
		return
	var graph: FlowGraph = FlowGraph.new()
	graph.schema_version = FlowGraph.SCHEMA_VERSION_3
	graph.constructor = FlowConstructorDefinition.new()
	var idle: FlowStateDefinition = FlowStateDefinition.new()
	idle.display_name = "Idle"
	var active_template: FlowStateDefinition = FlowStateDefinition.new()
	active_template.display_name = "ActiveTemplate"
	var fallback_template: FlowStateDefinition = FlowStateDefinition.new()
	fallback_template.display_name = "FallbackTemplate"
	var disabled: FlowStateDefinition = FlowStateDefinition.new()
	disabled.display_name = "Disabled"
	disabled.enabled = false
	var foreign: FlowStateDefinition = FlowStateDefinition.new()
	foreign.display_name = "Foreign"
	var machine: FlowStateMachineDefinition = FlowStateMachineDefinition.new()
	machine.tick_mode = FlowStateMachineDefinition.TickMode.MANUAL
	machine.states = [idle, active_template, fallback_template, disabled]
	machine.initial_state_id = idle.get_internal_id()
	var sibling: FlowStateMachineDefinition = FlowStateMachineDefinition.new()
	sibling.tick_mode = FlowStateMachineDefinition.TickMode.MANUAL
	sibling.states = [foreign]
	sibling.initial_state_id = foreign.get_internal_id()
	graph.state_machines = [machine, sibling]

	var creation: FlowBlock = _probe(sdk, "create", active_template.get_internal_id())
	var deletion: FlowBlock = _probe(sdk, "remove", "")
	idle.enter_blocks = [creation]
	active_template.enter_blocks = [_print_block("active-enter")]
	active_template.blocks = [deletion]
	active_template.exit_blocks = [_print_block("active-exit")]
	fallback_template.enter_blocks = [_print_block("fallback-enter")]
	fallback_template.exit_blocks = [_print_block("fallback-exit")]
	idle.exit_blocks = [_print_block("idle-exit")]
	if not _check(not FlowGraphValidator.validate(graph).has_errors(),
			"Schema 3 authored FSM with SDK and lifecycle blocks validates"):
		get_tree().quit(1)
		return

	var controller: PVController = PVController.new()
	controller.flow_graph = graph
	controller.set_meta("potok_8d1c4c2_fallback_template", fallback_template.get_internal_id())
	controller.set_meta("potok_8d1c4c2_disabled", disabled.get_internal_id())
	controller.set_meta("potok_8d1c4c2_foreign", foreign.get_internal_id())
	controller.runtime_output.entry_message_emitted.connect(_on_output)
	add_child(controller)
	await get_tree().process_frame
	var runtime: FlowFSMRuntime = controller.get_fsm_runtime()
	if not _check(runtime != null and runtime.is_running(),
			"Real PVController starts its MANUAL FSM"):
		controller.queue_free()
		get_tree().quit(1)
		return
	var mid: String = machine.get_internal_id()
	runtime.state_exited.connect(_on_exit)
	runtime.state_entered.connect(_on_enter)
	runtime.transition_committed.connect(_on_commit)
	var active_alias: String = controller.get_meta("potok_8d1c4c2_active_id", "")
	var backup: String = controller.get_meta("potok_8d1c4c2_fallback_id", "")
	if not _check(FlowId.is_valid(active_alias) and FlowId.is_valid(backup)
			and active_alias != backup,
			"Real initial StateEnter SDK callback registered two different aliases"):
		controller.visual_program_enabled = false
		controller.queue_free()
		get_tree().quit(1)
		return
	var registered: Array = controller.get_meta("potok_8d1c4c2_records", [])
	_check(registered.size() == 1 and registered[0].get("role") == "create"
		and registered[0].get("authorized") == true
		and registered[0].get("queued") == true,
		"SDK requested activation from a real initial Enter callback")
	_check(runtime.get_active_state_id(mid) == idle.get_internal_id()
		and runtime.pending_request_count() == 1,
		"Registered alias remains inactive until the first manual tick")
	runtime.tick(0.1, FlowStateMachineDefinition.TickMode.MANUAL)
	_check(runtime.get_active_state_id(mid) == active_alias
		and runtime.pending_request_count() == 0,
		"First manual tick activates the SDK alias without reentry")

	controller.set_meta("potok_8d1c4c2_target", active_alias)
	controller.set_meta("potok_8d1c4c2_target_fallback", backup)
	_trace.clear()
	runtime.tick(0.1, FlowStateMachineDefinition.TickMode.MANUAL)
	var records: Array = controller.get_meta("potok_8d1c4c2_records", [])
	_check(records.size() == 2 and records[1].get("role") == "remove"
		and records[1].get("phase") == "StateUpdate"
		and records[1].get("authorized") == true
		and records[1].get("removed") == false,
		"Real SDK StateUpdate rejects removal of active alias during tick")
	_check(runtime.get_active_state_id(mid) == active_alias
		and runtime.get_dynamic_state_ids(mid) == [active_alias, backup]
		and _trace.is_empty(),
		"Tick-time active removal is atomic and emits no lifecycle or transition events")

	# A genuine FSM lifecycle entry outside tick has no safe user trigger here:
	# reset/stop would nest a synchronous fallback in its own Exit callback.
	# Instead invoke the SAME shared block executor with the real running FSM,
	# machine ID and callback-scoped facade (not a simulated operation object).
	var wrapper: FlowBlockContainer = FlowBlockContainer.new()
	wrapper.blocks = [deletion]
	_check(runtime.change_state(mid, active_alias),
		"Queue stale self-target direct request before removing active alias")
	var sibling_id: String = sibling.get_internal_id()
	_check(runtime.emit_event(sibling_id, &"unmatched", {"source": "sibling"}),
		"Queue unrelated second-machine event before removal")
	_check(runtime.pending_request_count() == 2,
		"Two queued requests exist before controlled SDK deletion")
	_trace.clear()
	_invoke_sdk_outside_tick(controller, graph, runtime, wrapper, mid)
	records = controller.get_meta("potok_8d1c4c2_records", [])
	_check(records.size() == 3 and _matches_success(records[2], active_alias, backup),
		"Authorized SDK callback rejects bad fallbacks and removes active alias once")
	_check(runtime.get_active_state_id(mid) == backup
		and runtime.get_dynamic_state_ids(mid) == [backup]
		and not runtime.has_state(mid, active_alias),
		"Successful SDK removal activates dynamic fallback and deletes source alias")
	_check(runtime.pending_request_count() == 1,
		"Only direct request to removed active alias is purged; unrelated event stays")
	_check(_trace == [
		"StateExit:active-exit",
		"Exit:" + active_alias,
		"StateEnter:fallback-enter",
		"Enter:" + backup,
		"Commit:" + active_alias + ">" + backup + ":dynamic-removal"
	], "Synchronous fallback preserves source Exit, target Enter, then one commit")

	controller.set_meta("potok_8d1c4c2_target", backup)
	controller.set_meta("potok_8d1c4c2_target_fallback", idle.get_internal_id())
	_trace.clear()
	_invoke_sdk_outside_tick(controller, graph, runtime, wrapper, mid)
	records = controller.get_meta("potok_8d1c4c2_records", [])
	_check(records.size() == 4
		and _matches_success(records[3], backup, idle.get_internal_id()),
		"Second SDK callback can remove active fallback alias to an authored state")
	_check(runtime.get_active_state_id(mid) == idle.get_internal_id()
		and runtime.get_dynamic_state_ids(mid).is_empty(),
		"Both aliases are removed; authored fallback is active")
	_check(_trace == [
		"StateExit:fallback-exit",
		"Exit:" + backup,
		"Enter:" + idle.get_internal_id(),
		"Commit:" + backup + ">" + idle.get_internal_id() + ":dynamic-removal"
	], "Second fallback preserves Exit→Enter→Commit without recursive SDK creation")
	_check(controller.get_meta("potok_8d1c4c2_records", []).size() == 4,
		"Lifecycle callbacks never reenter the SDK creation/removal probes")
	_check(runtime.pending_request_count() == 1,
		"Unrelated event is retained across both active SDK removals")
	runtime.tick(0.1, FlowStateMachineDefinition.TickMode.MANUAL)
	_check(runtime.pending_request_count() == 0
		and runtime.get_active_state_id(mid) == idle.get_internal_id(),
		"Retained sibling event drains on the next clock without altering main FSM")

	for row: Dictionary in records:
		var operations: FlowFSMOperations = row.get("facade") as FlowFSMOperations
		if operations != null:
			_check(not operations.remove_state(backup, idle.get_internal_id())
				and operations.get_state_data(backup).is_empty(),
				"Every retained SDK facade expires on callback return")
	_check(graph.state_machines == [machine, sibling]
		and machine.states == [idle, active_template, fallback_template, disabled]
		and sibling.states == [foreign]
		and not FlowGraphValidator.validate(graph).has_errors(),
		"Runtime SDK operations never modify authored FlowGraph")

	controller.visual_program_enabled = false
	controller.queue_free()
	await get_tree().process_frame
	if _failures.is_empty():
		print("[Flujo] Potok 8D1-C4C2 SDK active fallback contract passed")
	else:
		for failure: String in _failures:
			push_error("[Flujo] Potok 8D1-C4C2: " + failure)
	get_tree().quit(0 if _failures.is_empty() else 1)


func _invoke_sdk_outside_tick(controller: PVController, graph: FlowGraph,
		runtime: FlowFSMRuntime, wrapper: FlowBlockContainer, machine_id: String) -> void:
	FlowReadyExecutor.new()._execute_blocks(
		controller, graph, wrapper, "fsm.sdk.c4c2.outside_tick",
		controller.runtime_output, &"StateExit", machine_id,
		controller.get_value_resolution_context(), [], true, "", "", runtime
	)


func _matches_success(row: Dictionary, target: String, fallback: String) -> bool:
	return row.get("role") == "remove" and row.get("phase") == "StateExit"
		and row.get("authorized") == true
		and row.get("target") == target and row.get("fallback") == fallback
		and row.get("invalid_fallbacks_rejected") == true
		and row.get("before_valid_still_present") == true
		and row.get("removed") == true and row.get("target_absent") == true
		and row.get("fallback_present") == true
		and row.get("second_remove_rejected") == true
		and row.get("target_data_empty") == true


func _probe(script: Script, role: String, template_id: String) -> FlowBlock:
	var block: FlowBlock = script.new() as FlowBlock
	if block != null:
		block.set("role", role)
		block.set("template_state_id", template_id)
	return block


func _print_block(message: String) -> FlowPrintBlock:
	var block: FlowPrintBlock = FlowPrintBlock.new()
	block.text = message
	return block


func _on_output(_controller: Node, _container_id: String, _block_id: String,
		message: String, phase: StringName) -> void:
	_trace.append(String(phase) + ":" + message)


func _on_exit(_machine_id: String, state_id: String) -> void:
	_trace.append("Exit:" + state_id)


func _on_enter(_machine_id: String, state_id: String) -> void:
	_trace.append("Enter:" + state_id)


func _on_commit(_machine_id: String, from_id: String, to_id: String,
		trigger_id: String) -> void:
	_trace.append("Commit:" + from_id + ">" + to_id + ":" + trigger_id)


func _check(ok: bool, description: String) -> bool:
	if not ok:
		_failures.append(description)
		push_error("[Flujo] Potok 8D1-C4C2: " + description)
	return ok
