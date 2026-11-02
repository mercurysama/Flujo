@tool
extends SceneTree

## Potok 7F-1C1D: session snapshot, UndoRedo, Escape and same-ID focus.
var failures: Array[String] = []
var host: Control
var drawer: FluoDrawer
var editor: FlowGraphInspectorProperty
var controller: PVController
var block: FlowPrintBlock
var other: FlowPrintBlock
var machine: FlowStateMachineDefinition
var state: FlowStateDefinition


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	for i: int in 5:
		await process_frame
	while EditorInterface.get_resource_filesystem().is_scanning():
		await process_frame
	var manager: EditorUndoRedoManager = EditorInterface.get_editor_undo_redo()
	if manager == null:
		_fail("Godot EditorUndoRedoManager unavailable")
		quit(1)
		return
	host = Control.new()
	host.size = Vector2(1100, 770)
	get_root().add_child(host)
	var graph := FlowGraph.new()
	graph.schema_version = FlowGraph.SCHEMA_VERSION_3
	graph.constructor = FlowConstructorDefinition.new()
	state = FlowStateDefinition.new()
	block = FlowPrintBlock.new()
	block.text = "before"
	other = FlowPrintBlock.new()
	other.text = "other"
	state.enter_blocks = [null, block]
	state.exit_blocks = [other]
	machine = FlowStateMachineDefinition.new()
	machine.states = [state]
	machine.initial_state_id = state.get_internal_id()
	graph.state_machines = [machine]
	controller = PVController.new()
	controller.flow_graph = graph
	host.add_child(controller)
	drawer = FluoDrawer.new()
	EditorInterface.get_base_control().add_child(drawer)
	drawer.configure(manager)
	drawer.open_container(controller, FlowGraphEditorCommands.Collection.STATE_MACHINES,
		machine.get_internal_id())
	editor = drawer.find_child("FluoFlowEditor", true, false) as FlowGraphInspectorProperty
	await _frames(6)
	if not _check(editor != null, "Fluo editor exists"):
		await _finish()
		return
	var list: ItemList = _list("Enter")
	if not _check(list != null, "Enter native list exists"):
		await _finish()
		return
	list.select(1)
	list.item_selected.emit(1)
	list.item_activated.emit(1)
	await _frames(5)
	var input: TextEdit = drawer.find_child(
		"PotokPhaseBlockPrintText", true, false) as TextEdit
	var revert: Button = drawer.find_child(
		"PotokPhaseBlockRevert", true, false) as Button
	var close_button: Button = drawer.find_child(
		"PotokPhaseBlockClose", true, false) as Button
	if not _check(input != null and revert != null and close_button != null,
			"Native text, Revertir and Close are present"):
		await _finish()
		return
	var history: UndoRedo = manager.get_history_undo_redo(
		manager.get_object_history_id(controller))
	input.text = "new"
	input.text_changed.emit()
	_check(block.text == "new", "Flusso writes immediately")
	var before_revert: int = history.get_version()
	revert.pressed.emit()
	await _frames(5)
	_check(block.text == "before" and other.text == "other",
		"Revertir restores exact opening text and leaves sibling phase untouched")
	_check(history.get_version() == before_revert + 1,
		"Revertir creates one atomic UndoRedo action")
	history.undo()
	await _frames(3)
	_check(block.text == "new", "Undo of Revertir restores most recent live edit")
	history.redo()
	await _frames(3)
	_check(block.text == "before", "Redo of Revertir restores opening value")
	# A new accepted edit survives closing: Close does not undo.
	input = drawer.find_child("PotokPhaseBlockPrintText", true, false) as TextEdit
	if input != null:
		input.text = "persist"
		input.text_changed.emit()
	close_button = drawer.find_child("PotokPhaseBlockClose", true, false) as Button
	if close_button != null:
		close_button.pressed.emit()
	await _frames(6)
	_check(block.text == "persist" and drawer.is_open()
		and drawer.find_child("PotokPhaseBlockProperties", true, false) == null,
		"Close preserves edits and does not close Fluo")
	list = _list("Enter")
	var index: int = list.get_selected_items()[0] if list != null 		and not list.get_selected_items().is_empty() else -1
	_check(list != null and list.has_focus() and index == 1
		and String((list.get_item_metadata(index) as Dictionary).get("id", "")) == block.get_internal_id(),
		"Closing Flusso restores actual focus and stable ID selection")
	# Reopen creates a new baseline; changing phase invalidates old snapshot.
	if list != null:
		list.item_activated.emit(1)
	await _frames(5)
	var session: Dictionary = editor.get("_potok_phase_block_session")
	_check((session.get("values", {}) as Dictionary).get(&"text", "") == "persist",
		"Reopening captures the new opening state")
	var exit_list: ItemList = _list("Exit")
	if exit_list != null:
		exit_list.select(0)
		exit_list.item_selected.emit(0)
	_check(editor.get("_potok_phase_block_session").is_empty(),
		"Switching blocks discards opening snapshot of prior selection")
	_check(other.text == "other" and block.text == "persist",
		"Phase switch does not write data")
	await _finish()


func _list(name: String) -> ItemList:
	return drawer.find_child("PotokPhase" + name + "BlocksList", true, false) as ItemList


func _frames(n: int) -> void:
	for i: int in n:
		await process_frame


func _check(ok: bool, message: String) -> bool:
	if not ok:
		_fail(message)
	return ok


func _fail(message: String) -> void:
	failures.append(message)
	push_error("[Flujo] Potok 7F-1C1D: " + message)


func _finish() -> void:
	if drawer != null:
		drawer.close()
		drawer.set_controller(null)
		drawer.queue_free()
	if host != null:
		host.queue_free()
	await _frames(4)
	if failures.is_empty():
		print("[Flujo] Potok 7F-1C1D phase block Revertir and focus passed")
	quit(0 if failures.is_empty() else 1)
