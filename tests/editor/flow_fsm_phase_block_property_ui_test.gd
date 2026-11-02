@tool
extends SceneTree

## 7F-1C1C: native Fluo editing routes to exactly one phase-owned block.
var failures: Array[String] = []
var host: Control
var drawer: FluoDrawer
var controller: PVController
var editor: FlowGraphInspectorProperty
var graph: FlowGraph
var state: FlowStateDefinition
var other: FlowStateDefinition
var machine: FlowStateMachineDefinition
var enter: FlowPrintBlock
var update: FlowPrintBlock
var exit_block: FlowPrintBlock


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	for i: int in 5:
		await process_frame
	while EditorInterface.get_resource_filesystem().is_scanning():
		await process_frame
	var manager: EditorUndoRedoManager = EditorInterface.get_editor_undo_redo()
	if not _check(manager != null, "EditorUndoRedoManager exists"):
		quit(1)
		return
	host = Control.new()
	host.size = Vector2(1100, 770)
	get_root().add_child(host)
	graph = FlowGraph.new()
	graph.schema_version = FlowGraph.SCHEMA_VERSION_3
	graph.constructor = FlowConstructorDefinition.new()
	state = FlowStateDefinition.new()
	other = FlowStateDefinition.new()
	enter = FlowPrintBlock.new()
	enter.text = "Enter before"
	update = FlowPrintBlock.new()
	update.text = "Update before"
	exit_block = FlowPrintBlock.new()
	exit_block.text = "Exit before"
	state.enter_blocks = [null, enter]
	state.blocks = [update]
	state.exit_blocks = [exit_block]
	machine = FlowStateMachineDefinition.new()
	machine.states = [state, other]
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
	if not _check(editor != null, "Existing Fluo editor exists"):
		await _finish()
		return
	var history: UndoRedo = manager.get_history_undo_redo(
		manager.get_object_history_id(controller))
	for phase: String in ["Enter", "Update", "Exit"]:
		var list: ItemList = drawer.find_child(
			"PotokPhase" + phase + "BlocksList", true, false) as ItemList
		if not _check(list != null, "Native " + phase + " list exists"):
			continue
		var index: int = 1 if phase == "Enter" else 0
		list.select(index)
		list.item_selected.emit(index)
		list.item_activated.emit(index)
		await _frames(5)
		var input: TextEdit = drawer.find_child(
			"PotokPhaseBlockPrintText", true, false) as TextEdit
		var block: FlowPrintBlock = enter if phase == "Enter" else (
			update if phase == "Update" else exit_block)
		if not _check(input != null, phase + " has native Print text editing"):
			continue
		var prior: String = block.text
		input.text = phase + " changed"
		input.text_changed.emit()
		_check(block.text == phase + " changed", phase + " edit persists immediately")
		history.undo()
		_check(block.text == prior, phase + " Undo restores original value")
		history.redo()
		_check(block.text == phase + " changed", phase + " Redo restores live text")
		_check(state.enter_blocks[0] == null and other.blocks.is_empty(),
			"Null slot and sibling state are untouched")
	# Reopen Enter and verify stale field from another phase cannot edit it.
	var old_exit: TextEdit = drawer.find_child(
		"PotokPhaseBlockPrintText", true, false) as TextEdit
	var enter_list: ItemList = drawer.find_child(
		"PotokPhaseEnterBlocksList", true, false) as ItemList
	if old_exit != null and enter_list != null:
		enter_list.select(1)
		enter_list.item_selected.emit(1)
		old_exit.text_changed.emit()
		_check(exit_block.text == "Exit changed",
			"Callback from previously selected phase does not edit old block")
	_check(update.text == "Update changed" and enter.text == "Enter changed"
		and exit_block.text == "Exit changed",
		"All phase values persist independently with stable ownership")
	_check(not FlowGraphValidator.validate(graph).has_errors(),
		"Final graph remains valid")
	await _finish()


func _frames(n: int) -> void:
	for i: int in n:
		await process_frame


func _check(ok: bool, message: String) -> bool:
	if not ok:
		failures.append(message)
		push_error("[Flujo] Potok 7F-1C1C UI: " + message)
	return ok


func _finish() -> void:
	if drawer != null:
		drawer.close()
		drawer.set_controller(null)
		drawer.queue_free()
	if host != null:
		host.queue_free()
	await _frames(4)
	if failures.is_empty():
		print("[Flujo] Potok 7F-1C1C native Flusso live property UndoRedo passed")
	quit(0 if failures.is_empty() else 1)
