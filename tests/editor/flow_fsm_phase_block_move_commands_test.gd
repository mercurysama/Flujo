@tool
extends SceneTree

## 7F-1C2A test-first: strict phase-owned adjacent Move with UndoRedo.
const MOVE: StringName = &"move_fsm_phase_block"
var failures: Array[String] = []


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	for i: int in 5:
		await process_frame
	while EditorInterface.get_resource_filesystem().is_scanning():
		await process_frame
	var manager: EditorUndoRedoManager = EditorInterface.get_editor_undo_redo()
	if manager == null:
		_fail("EditorUndoRedoManager exists")
		quit(1)
		return
	var host := Node.new()
	get_root().add_child(host)
	var graph := FlowGraph.new()
	graph.schema_version = FlowGraph.SCHEMA_VERSION_3
	graph.constructor = FlowConstructorDefinition.new()
	var state := FlowStateDefinition.new()
	var sibling := FlowStateDefinition.new()
	var enter_a := FlowPrintBlock.new()
	var enter_b := FlowPrintBlock.new()
	var update_a := FlowPrintBlock.new()
	var update_b := FlowPrintBlock.new()
	var exit_a := FlowPrintBlock.new()
	var exit_b := FlowPrintBlock.new()
	state.enter_blocks = [null, enter_a, enter_b]
	state.blocks = [update_a, update_b]
	state.exit_blocks = [exit_a, exit_b]
	var machine := FlowStateMachineDefinition.new()
	machine.states = [state, sibling]
	machine.initial_state_id = state.get_internal_id()
	graph.state_machines = [machine]
	var controller := PVController.new()
	controller.flow_graph = graph
	host.add_child(controller)
	var commands := FlowGraphEditorCommands.new(manager)
	if not commands.has_method(MOVE):
		_fail("7F-1C2A exposes strict phase block Move command (RED gate)")
		await _finish(host)
		return
	var mid: String = machine.get_internal_id()
	var sid: String = state.get_internal_id()
	var history: UndoRedo = manager.get_history_undo_redo(
		manager.get_object_history_id(controller))
	var version: int = history.get_version()
	var enter_id: String = enter_a.get_internal_id()
	_check(not _move(commands, controller, mid, sid, &"enter", enter_id, -1)
		and not _move(commands, controller, mid, sid, &"enter", enter_id, 0)
		and not _move(commands, controller, mid, sid, &"enter", enter_id, 2)
		and not _move(commands, controller, mid, sid, &"exit", enter_id, 1)
		and not _move(commands, controller, mid, sibling.get_internal_id(), &"enter", enter_id, 1)
		and not _move(commands, controller, "missing-machine", sid, &"enter", enter_id, 1)
		and not _move(commands, controller, mid, sid, &"Enter", enter_id, 1)
		and not _move(commands, controller, mid, sid, &"enter", "", 1),
		"Null-adjacent, unknown IDs, bad directions and foreign phase fail closed")
	_check(history.get_version() == version and state.enter_blocks[0] == null
		and state.enter_blocks[1] == enter_a and state.enter_blocks[2] == enter_b,
		"Rejected edits produce neither writes nor UndoRedo")
	_check(_move(commands, controller, mid, sid, &"enter", enter_id, 1),
		"Enter Move swaps adjacent authored blocks")
	_check(state.enter_blocks[0] == null and state.enter_blocks[1] == enter_b
		and state.enter_blocks[2] == enter_a and history.get_version() == version + 1,
		"Move retains null slot, block instances and one history action")
	history.undo()
	_check(state.enter_blocks[1] == enter_a and state.enter_blocks[2] == enter_b,
		"Undo Enter Move restores exact references and order")
	history.redo()
	_check(state.enter_blocks[1] == enter_b and state.enter_blocks[2] == enter_a
		and enter_a.get_internal_id() == enter_id,
		"Redo Enter Move preserves stable IDs and references")
	version = history.get_version()
	_check(_move(commands, controller, mid, sid, &"update",
		update_b.get_internal_id(), -1),
		"Update Move works on inherited state.blocks")
	_check(state.blocks[0] == update_b and state.blocks[1] == update_a
		and state.exit_blocks[0] == exit_a and state.exit_blocks[1] == exit_b
		and history.get_version() == version + 1,
		"Update Move changes only Update array")
	history.undo()
	_check(state.blocks[0] == update_a and state.blocks[1] == update_b,
		"Update Move Undo restores inherited collection")
	version = history.get_version()
	_check(_move(commands, controller, mid, sid, &"exit",
		exit_a.get_internal_id(), 1), "Exit Move works on exit_blocks")
	_check(state.exit_blocks[0] == exit_b and state.exit_blocks[1] == exit_a
		and history.get_version() == version + 1,
		"Exit Move is atomic and phase-local")
	history.undo()
	_check(state.exit_blocks[0] == exit_a and state.exit_blocks[1] == exit_b,
		"Exit Move Undo restores order")
	_check(sibling.blocks.is_empty() and sibling.enter_blocks.is_empty()
		and not FlowGraphValidator.validate(graph).has_errors(),
		"Sibling state untouched; graph remains valid")
	await _finish(host)


func _move(
		commands: FlowGraphEditorCommands, controller: PVController,
		mid: String, sid: String, phase: StringName, id: String, direction: int
) -> bool:
	return bool(commands.call(MOVE, controller, mid, sid, phase, id, direction))


func _check(ok: bool, message: String) -> void:
	if not ok:
		_fail(message)


func _fail(message: String) -> void:
	failures.append(message)
	push_error("[Flujo] Potok 7F-1C2A Move: " + message)


func _finish(host: Node) -> void:
	host.queue_free()
	for i: int in 4:
		await process_frame
	if failures.is_empty():
		print("[Flujo] Potok 7F-1C2A strict phase block Move UndoRedo passed")
	quit(0 if failures.is_empty() else 1)
