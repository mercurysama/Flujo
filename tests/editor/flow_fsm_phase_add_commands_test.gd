@tool
extends SceneTree

## Potok 7F-1A: catalog Add must target exactly one authored FSM phase.
const SDK_ROOT: String = "res://tests/fixtures/manual_block_sdk"
const EXTERNAL_ID: String = "manual_output:output"
const AUTHORING_SCRIPT: Script = preload(
	"res://addons/vp_flujo/editor/flow_editor_block_authoring_context.gd"
)
const METHOD_NAME: StringName = &"add_fsm_phase_block_by_authoring_id"

class CountingAuthoringContext extends RefCounted:
	var delegate: RefCounted
	var calls: int = 0

	func _init(source: RefCounted) -> void:
		delegate = source

	func create_block(authoring_id: String) -> Variant:
		calls += 1
		return delegate.call(&"create_block", authoring_id)


var failures: Array[String] = []


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	for _i: int in 5:
		await process_frame
	while EditorInterface.get_resource_filesystem().is_scanning():
		await process_frame

	var manager: EditorUndoRedoManager = EditorInterface.get_editor_undo_redo()
	if not _check(manager != null, "Editor UndoRedo manager exists"):
		quit(1)
		return

	var host := Node.new()
	host.name = "Potok7F1AHost"
	get_root().add_child(host)
	var graph := FlowGraph.new()
	graph.schema_version = FlowGraph.SCHEMA_VERSION_3
	graph.constructor = FlowConstructorDefinition.new()
	var a := FlowStateDefinition.new()
	a.display_name = "A"
	var sibling := FlowStateDefinition.new()
	sibling.display_name = "Sibling"
	var sentinel := FlowPrintBlock.new()
	sentinel.display_name = "Existing"
	var update_seed := FlowPrintBlock.new()
	update_seed.display_name = "Print"
	a.enter_blocks = [null, sentinel]
	a.blocks = [update_seed]
	var machine := FlowStateMachineDefinition.new()
	machine.states = [a, sibling]
	machine.initial_state_id = a.get_internal_id()
	var other := FlowStateMachineDefinition.new()
	var other_state := FlowStateDefinition.new()
	other.states = [other_state]
	other.initial_state_id = other_state.get_internal_id()
	graph.state_machines = [machine, other]
	var ready := FlowProcess.new()
	graph.processes = [ready]
	var controller := PVController.new()
	controller.name = "PhaseController"
	controller.flow_graph = graph
	host.add_child(controller)
	var delegate: RefCounted = AUTHORING_SCRIPT.new(SDK_ROOT) as RefCounted
	var counting := CountingAuthoringContext.new(delegate)
	var commands := FlowGraphEditorCommands.new(manager, counting)
	if not _check(commands.has_method(METHOD_NAME),
			"7F-1A must expose an FSM phase Add command (test-first RED)"):
		await _finish(host)
		return

	var mid: String = machine.get_internal_id()
	var aid: String = a.get_internal_id()
	var bid: String = sibling.get_internal_id()
	var other_mid: String = other.get_internal_id()
	var other_sid: String = other_state.get_internal_id()
	var history: UndoRedo = manager.get_history_undo_redo(
		manager.get_object_history_id(controller)
	)
	var version: int = history.get_version()
	var original_machine_id: String = mid
	var original_sentinel_id: String = sentinel.get_internal_id()
	var original_update_id: String = update_seed.get_internal_id()
	var baseline_diagnostics: int = FlowGraphValidator.validate(graph).diagnostics.size()
	_check(_add(commands, controller, mid, aid, &"bogus", "print").is_empty()
		and _add(commands, controller, mid, aid, &"Enter", "print").is_empty()
		and _add(commands, controller, mid, aid, &"", "print").is_empty(),
		"Unknown or incorrectly cased phases are never inferred")
	_check(_add(commands, controller, mid, "foreign", &"enter", "print").is_empty()
		and _add(commands, controller, other_mid, aid, &"enter", "print").is_empty()
		and _add(commands, controller, mid, other_sid, &"enter", "print").is_empty()
		and _add(commands, controller, "missing", bid, &"enter", "print").is_empty(),
		"Owner IDs must resolve in exactly the authored machine and state")
	_check(counting.calls == 0 and history.get_version() == version,
		"Bad phase/owner combinations create neither block nor undo step")

	var enter_id: String = _add(commands, controller, mid, aid, &"enter", "print")
	_check(not enter_id.is_empty() and a.enter_blocks.size() == 3
		and a.enter_blocks[0] == null and a.enter_blocks[1] == sentinel
		and a.enter_blocks[2] is FlowPrintBlock
		and a.enter_blocks[2].get_internal_id() == enter_id,
		"Enter adds one catalog block after existing null and authored slot")
	_check(a.blocks.size() == 1 and a.blocks[0] == update_seed
		and a.exit_blocks.is_empty() and sibling.enter_blocks.is_empty()
		and ready.blocks.is_empty() and history.get_version() == version + 1,
		"Enter Add does not write Update, Exit, Ready or another state")
	var entered_block: FlowBlock = a.enter_blocks[2]
	history.undo()
	_check(a.enter_blocks.size() == 2 and a.enter_blocks[0] == null
		and a.enter_blocks[1] == sentinel and a.blocks.size() == 1,
		"Undo Enter Add restores existing null and state phase order")
	history.redo()
	_check(a.enter_blocks.size() == 3 and a.enter_blocks[2] == entered_block
		and entered_block.get_internal_id() == enter_id,
		"Redo Enter returns exact original resource and stable ID")
	_check(counting.calls == 1,
		"Enter Undo/Redo never invokes authoring factory again")

	version = history.get_version()
	var update_id: String = _add(commands, controller, mid, aid, &"update", "print")
	_check(not update_id.is_empty() and a.blocks.size() == 2
		and a.blocks[1].get_internal_id() == update_id
		and a.blocks[0] == update_seed and a.blocks[1].display_name != update_seed.display_name,
		"Update adds to inherited blocks with phase-local unique name")
	_check(a.enter_blocks[2] == entered_block and a.exit_blocks.is_empty()
		and history.get_version() == version + 1,
		"Update Add registers one action and leaves Enter and Exit intact")
	var update_block: FlowBlock = a.blocks[1]
	history.undo()
	_check(a.blocks.size() == 1 and a.blocks[0] == update_seed
		and a.enter_blocks[2] == entered_block,
		"Update Undo only changes the Update phase")
	history.redo()
	_check(a.blocks.size() == 2 and a.blocks[1] == update_block
		and a.blocks[1].get_internal_id() == update_id,
		"Update Redo preserves newly authored block resource and ID")

	version = history.get_version()
	var external_id: String = _add(commands, controller, mid, aid, &"exit", EXTERNAL_ID)
	_check(not external_id.is_empty() and a.exit_blocks.size() == 1
		and a.exit_blocks[0].get_internal_id() == external_id
		and a.exit_blocks[0].get_script().resource_path.ends_with(
			"/tests/fixtures/manual_block_sdk/manual_output/block.gd"
		), "Exit accepts a validated external catalog block with original script")
	_check(history.get_version() == version + 1 and a.enter_blocks[2] == entered_block
		and a.blocks[1] == update_block and sibling.exit_blocks.is_empty()
		and ready.blocks.is_empty(),
		"External Exit Add modifies exactly one phase and records one undo action")
	var external_block: FlowBlock = a.exit_blocks[0]
	var calls_before_redo: int = counting.calls
	history.undo()
	_check(a.exit_blocks.is_empty() and a.blocks[1] == update_block,
		"Exit Undo preserves Update")
	history.redo()
	_check(a.exit_blocks.size() == 1 and a.exit_blocks[0] == external_block
		and external_block.get_internal_id() == external_id
		and counting.calls == calls_before_redo,
		"Exit Redo reuses the same external object without factory invocation")

	var second_exit_id: String = _add(commands, controller, mid, aid, &"exit", EXTERNAL_ID)
	_check(second_exit_id != external_id and not second_exit_id.is_empty()
		and a.exit_blocks.size() == 2
		and a.exit_blocks[1].display_name != a.exit_blocks[0].display_name,
		"Repeated Exit Add yields fresh ID and unique name in that phase")

	version = history.get_version()
	var before_calls: int = counting.calls
	_check(_add(commands, controller, mid, aid, &"exit", "").is_empty(),
		"Missing authoring ID rejected")
	_check(counting.calls == before_calls, "Empty catalog ID never calls factory")
	_check(_add(commands, controller, mid, aid, &"exit", "missing:stale").is_empty(),
		"Unknown external authoring entry rejected without fallback")
	_check(counting.calls == before_calls + 1
		and history.get_version() == version and a.exit_blocks.size() == 2,
		"Invalid catalog Add leaves all live arrays and UndoRedo history unchanged")
	_check(_has_diagnostic(commands.get_last_diagnostics(),
			&"editor_authoring_entry_missing"),
		"Rejected external authoring ID publishes existing catalog diagnostic")

	var foreign_controller := PVController.new()
	var foreign_graph := FlowGraph.new()
	foreign_graph.schema_version = FlowGraph.SCHEMA_VERSION_2
	foreign_controller.flow_graph = foreign_graph
	host.add_child(foreign_controller)
	_check(_add(commands, foreign_controller, mid, aid, &"enter", "print").is_empty()
		and _add(commands, null, mid, aid, &"enter", "print").is_empty(),
		"Non-schema3 or null controller rejects phase Add")
	_check(counting.calls == before_calls + 1 and history.get_version() == version,
		"Stale controllers do not invoke catalog or write history")

	_check(machine.get_internal_id() == original_machine_id
		and sentinel.get_internal_id() == original_sentinel_id
		and update_seed.get_internal_id() == original_update_id
		and machine.states[0] == a and machine.states[1] == sibling
		and other.states[0] == other_state and a.transitions.is_empty()
		and ready.blocks.is_empty(),
		"All authored state/machine IDs, sibling objects and transitions remain intact")
	_check(FlowGraphValidator.validate(graph).diagnostics.size() <= baseline_diagnostics
		and not _has_new_graph_errors(graph, baseline_diagnostics),
		"Candidate Add introduces no additional graph validation problems")
	await _finish(host)


func _add(
		commands: FlowGraphEditorCommands, controller: PVController,
		mid: String, sid: String, phase: StringName, authoring_id: String
) -> String:
	return String(commands.call(METHOD_NAME, controller, mid, sid, phase, authoring_id))


func _has_diagnostic(diagnostics: Array[FlowDiagnostic], code: StringName) -> bool:
	for item: FlowDiagnostic in diagnostics:
		if item.code == code:
			return true
	return false


func _has_new_graph_errors(graph: FlowGraph, baseline_count: int) -> bool:
	var issues: FlowValidationResult = FlowGraphValidator.validate(graph)
	return issues.has_errors() and issues.diagnostics.size() > baseline_count


func _check(ok: bool, message: String) -> bool:
	if not ok:
		failures.append(message)
		push_error("[Flujo] Potok 7F-1A: " + message)
	return ok


func _finish(host: Node) -> void:
	host.queue_free()
	for _i: int in 4:
		await process_frame
	if failures.is_empty():
		print("[Flujo] Potok 7F-1A per-phase catalog Add and UndoRedo passed")
	quit(0 if failures.is_empty() else 1)
