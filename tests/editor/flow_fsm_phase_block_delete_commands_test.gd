@tool
extends SceneTree

## 7F-1C2C: delete exactly one owned phase block; null slots remain.
const DELETE: StringName = &"delete_fsm_phase_block"
const SDK: Script = preload("res://tests/fixtures/manual_block_sdk/manual_output/block.gd")
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
	var a := FlowPrintBlock.new()
	var b := FlowPrintBlock.new()
	var update := FlowPrintBlock.new()
	var external: FlowBlock = SDK.new() as FlowBlock
	external.set(&"message", "keep external properties")
	state.enter_blocks = [null, a, null, b]
	state.blocks = [update]
	state.exit_blocks = [external]
	var machine := FlowStateMachineDefinition.new()
	machine.states = [state, sibling]
	machine.initial_state_id = state.get_internal_id()
	graph.state_machines = [machine]
	var ready := FlowProcess.new()
	graph.processes = [ready]
	var controller := PVController.new()
	controller.flow_graph = graph
	host.add_child(controller)
	var commands := FlowGraphEditorCommands.new(manager)
	if not commands.has_method(DELETE):
		_fail("7F-1C2C phase Delete command is present (RED gate)")
		await _finish(host)
		return
	var mid: String = machine.get_internal_id()
	var sid: String = state.get_internal_id()
	var history: UndoRedo = manager.get_history_undo_redo(manager.get_object_history_id(controller))
	var start: int = history.get_version()
	var aid: String = a.get_internal_id()
	_check(not _delete(commands, controller, mid, sid, &"enter", "")
		and not _delete(commands, controller, mid, sid, &"enter", "missing")
		and not _delete(commands, controller, mid, sid, &"Enter", aid)
		and not _delete(commands, controller, mid, sid, &"exit", aid)
		and not _delete(commands, controller, mid, sibling.get_internal_id(), &"enter", aid)
		and not _delete(commands, controller, "missing", sid, &"enter", aid),
		"Invalid phase, empty ID and cross-owner delete fail closed")
	_check(history.get_version() == start and state.enter_blocks.size() == 4,
		"Rejected delete has no UndoRedo or mutation")
	_check(_delete(commands, controller, mid, sid, &"enter", aid),
		"Enter deletion removes selected block")
	_check(state.enter_blocks.size() == 3 and state.enter_blocks[0] == null
		and state.enter_blocks[1] == null and state.enter_blocks[2] == b
		and history.get_version() == start + 1,
		"Only selected item removed, original null slots preserved in order")
	_check(not _delete(commands, controller, mid, sid, &"enter", aid),
		"Stale duplicate Delete is rejected without extra history")
	_check(history.get_version() == start + 1,
		"Duplicate Delete rejection has no UndoRedo action")
	history.undo()
	_check(state.enter_blocks.size() == 4 and state.enter_blocks[1] == a
		and state.enter_blocks[2] == null and a.get_internal_id() == aid,
		"Undo restores same resource and persistent ID at original index")
	history.redo()
	_check(state.enter_blocks.size() == 3 and state.enter_blocks[2] == b,
		"Redo removes the original target again")
	var update_id: String = update.get_internal_id()
	var version: int = history.get_version()
	_check(_delete(commands, controller, mid, sid, &"update", update_id)
		and state.blocks.is_empty() and history.get_version() == version + 1,
		"Update deletion works on inherited blocks array")
	history.undo()
	_check(state.blocks.size() == 1 and state.blocks[0] == update,
		"Update Undo restores identical resource")
	version = history.get_version()
	var external_id: String = external.get_internal_id()
	_check(_delete(commands, controller, mid, sid, &"exit", external_id)
		and state.exit_blocks.is_empty() and history.get_version() == version + 1,
		"Exit supports external SDK block deletion")
	history.undo()
	_check(state.exit_blocks.size() == 1 and state.exit_blocks[0] == external
		and external.get_internal_id() == external_id
		and String(external.get(&"message")) == "keep external properties",
		"Undo restores external SDK script, object, ID and values")
	_check(sibling.enter_blocks.is_empty() and ready.blocks.is_empty()
		and state.enter_blocks[0] == null and state.enter_blocks[1] == null
		and state.enter_blocks[2] == b
		and not FlowGraphValidator.validate(graph).has_errors(),
		"Final graph valid; sibling phase state, null positions and Ready untouched")
	await _finish(host)


func _delete(
		commands: FlowGraphEditorCommands, controller: PVController,
		mid: String, sid: String, phase: StringName, block_id: String
) -> bool:
	return bool(commands.call(DELETE, controller, mid, sid, phase, block_id))


func _check(ok: bool, message: String) -> void:
	if not ok:
		_fail(message)


func _fail(message: String) -> void:
	failures.append(message)
	push_error("[Flujo] Potok 7F-1C2C: " + message)


func _finish(host: Node) -> void:
	host.queue_free()
	for i: int in 4:
		await process_frame
	if failures.is_empty():
		print("[Flujo] Potok 7F-1C2C strict phase Delete UndoRedo SDK passed")
	quit(0 if failures.is_empty() else 1)
