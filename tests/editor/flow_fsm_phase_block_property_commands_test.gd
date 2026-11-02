@tool
extends SceneTree

## 7F-1C1C test-first: phase-owned live property edits and UndoRedo.
const METHOD: StringName = &"set_fsm_phase_block_property_live"
const DESCRIPTOR_METHOD: StringName = &"set_fsm_phase_block_descriptor_live"
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
		_fail("Godot editor UndoRedoManager exists")
		quit(1)
		return
	var host := Node.new()
	get_root().add_child(host)
	var graph := FlowGraph.new()
	graph.schema_version = FlowGraph.SCHEMA_VERSION_3
	graph.constructor = FlowConstructorDefinition.new()
	var state := FlowStateDefinition.new()
	var sibling := FlowStateDefinition.new()
	var enter := FlowPrintBlock.new()
	var update := FlowPrintBlock.new()
	var exit_block := FlowPrintBlock.new()
	enter.text = "enter original"
	update.text = "update original"
	exit_block.text = "exit original"
	state.enter_blocks = [null, enter]
	state.blocks = [update]
	state.exit_blocks = [exit_block]
	var machine := FlowStateMachineDefinition.new()
	machine.states = [state, sibling]
	machine.initial_state_id = state.get_internal_id()
	graph.state_machines = [machine]
	var controller := PVController.new()
	controller.flow_graph = graph
	host.add_child(controller)
	var commands := FlowGraphEditorCommands.new(manager)
	if not commands.has_method(METHOD) or not commands.has_method(DESCRIPTOR_METHOD):
		_fail("Dedicated phase-owned scalar and descriptor commands exist (RED gate)")
		await _finish(host)
		return
	var mid := machine.get_internal_id()
	var sid := state.get_internal_id()
	var history: UndoRedo = manager.get_history_undo_redo(manager.get_object_history_id(controller))
	var before: int = history.get_version()
	var old_id: String = enter.get_internal_id()
	_check(not bool(commands.call(METHOD, controller, mid, sid, &"enter",
		"missing-block", &"text", "bad"))
		and not bool(commands.call(METHOD, controller, mid, "missing-state", &"enter",
		old_id, &"text", "bad"))
		and not bool(commands.call(METHOD, controller, mid, sid, &"update",
		old_id, &"text", "bad"))
		and not bool(commands.call(METHOD, controller, mid, sid, &"Enter",
		old_id, &"text", "bad")), "Invalid owner and phase cannot mutate")
	_check(history.get_version() == before and enter.text == "enter original",
		"Rejected edits create no history or writes")
	_check(bool(commands.call(METHOD, controller, mid, sid, &"enter",
		old_id, &"text", "enter changed")), "Live Enter edit succeeds")
	_check(enter.text == "enter changed" and update.text == "update original"
		and exit_block.text == "exit original" and state.enter_blocks[0] == null,
		"Enter text changes only the owned phase and keeps deliberate null slot")
	history.undo()
	_check(enter.text == "enter original", "Undo restores Enter text")
	history.redo()
	_check(enter.text == "enter changed" and enter.get_internal_id() == old_id,
		"Redo preserves stable ID and new text")
	_check(bool(commands.call(METHOD, controller, mid, sid, &"exit",
		exit_block.get_internal_id(), &"enabled", false)),
		"Exit enabled is editable with UndoRedo")
	_check(not exit_block.enabled and update.enabled, "Exit and Update stay isolated")
	history.undo()
	_check(exit_block.enabled, "Undo restores Exit enabled")
	_check(not bool(commands.call(METHOD, controller, mid, sid, &"enter",
		old_id, &"internal_id", "forged")), "Internal IDs are not authorable")
	_check(not bool(commands.call(METHOD, controller, mid, sid, &"enter",
		old_id, &"enabled", "false")), "Type mismatch rejected")
	_check(not FlowGraphValidator.validate(graph).has_errors(),
		"Graph retains valid state and phase references")
	await _finish(host)


func _check(ok: bool, message: String) -> void:
	if not ok:
		_fail(message)


func _fail(message: String) -> void:
	failures.append(message)
	push_error("[Flujo] Potok 7F-1C1C: " + message)


func _finish(host: Node) -> void:
	host.queue_free()
	for i: int in 4:
		await process_frame
	if failures.is_empty():
		print("[Flujo] Potok 7F-1C1C per-phase editable property UndoRedo passed")
	quit(0 if failures.is_empty() else 1)
