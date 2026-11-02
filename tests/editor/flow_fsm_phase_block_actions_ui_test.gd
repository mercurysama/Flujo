@tool
extends SceneTree

## Potok 7F-1C2D: native UI actions, modal Cancel/Confirm and stable focus.
var failures: Array[String] = []
var host: Control
var drawer: FluoDrawer
var editor: FlowGraphInspectorProperty
var controller: PVController
var state: FlowStateDefinition
var machine: FlowStateMachineDefinition
var original: FlowPrintBlock
var another: FlowPrintBlock


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	for i: int in 5:
		await process_frame
	while EditorInterface.get_resource_filesystem().is_scanning():
		await process_frame
	var manager: EditorUndoRedoManager = EditorInterface.get_editor_undo_redo()
	host = Control.new()
	host.size = Vector2(1100, 770)
	get_root().add_child(host)
	var graph := FlowGraph.new()
	graph.schema_version = FlowGraph.SCHEMA_VERSION_3
	graph.constructor = FlowConstructorDefinition.new()
	state = FlowStateDefinition.new()
	original = FlowPrintBlock.new()
	original.text = "original"
	another = FlowPrintBlock.new()
	state.enter_blocks = [null, original, another]
	state.blocks = [FlowPrintBlock.new()]
	state.exit_blocks = [FlowPrintBlock.new()]
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
	await _frames(5)
	var list: ItemList = _list("Enter")
	if not _check(list != null, "Enter list exists"):
		await _finish()
		return
	list.select(1)
	list.item_selected.emit(1)
	var duplicate: Button = _button("Enter", "Duplicate")
	var up: Button = _button("Enter", "MoveUp")
	var down: Button = _button("Enter", "MoveDown")
	var delete_button: Button = _button("Enter", "Delete")
	if not _check(duplicate != null and up != null and down != null and delete_button != null,
			"Phase row has native Move, Duplicate and Delete buttons (RED gate)"):
		await _finish()
		return
	var history: UndoRedo = manager.get_history_undo_redo(manager.get_object_history_id(controller))
	var old_version: int = history.get_version()
	up.pressed.emit()
	await _frames(4)
	_check(state.enter_blocks[0] == null and state.enter_blocks[1] == original
		and history.get_version() == old_version, "Move cannot jump deliberate null")
	down = _button("Enter", "MoveDown")
	down.pressed.emit()
	await _frames(4)
	_check(state.enter_blocks[1] == another and state.enter_blocks[2] == original,
		"MoveDown moves exact selected ID")
	list = _list("Enter")
	_check(list != null and not list.get_selected_items().is_empty()
		and String((list.get_item_metadata(list.get_selected_items()[0]) as Dictionary).get("id", ""))
			== original.get_internal_id(), "Move selection remains by ID")
	duplicate = _button("Enter", "Duplicate")
	duplicate.pressed.emit()
	await _frames(5)
	_check(state.enter_blocks.size() == 4 and state.enter_blocks[2] == original
		and state.enter_blocks[3] != original,
		"Duplicate inserts directly after original")
	var copy: FlowBlock = state.enter_blocks[3] if state.enter_blocks.size() == 4 else null
	_check(copy != null and copy.get_internal_id() != original.get_internal_id(),
		"Duplicated selection receives a distinct ID")
	delete_button = _button("Enter", "Delete")
	delete_button.pressed.emit()
	await _frames(3)
	var dialog: ConfirmationDialog = editor.find_child(
		"PotokStructureDeleteDialog", true, false) as ConfirmationDialog
	_check(dialog != null and dialog.visible and state.enter_blocks.size() == 4,
		"Delete only opens the canonical confirmation dialog")
	if dialog != null:
		dialog.canceled.emit()
	await _frames(3)
	_check(state.enter_blocks.size() == 4 and history.get_version() == old_version + 2,
		"Cancel leaves graph and undo history unchanged")
	delete_button = _button("Enter", "Delete")
	delete_button.pressed.emit()
	await _frames(3)
	var escape_key := InputEventKey.new()
	escape_key.pressed = true
	escape_key.keycode = KEY_ESCAPE
	drawer.call("_input", escape_key)
	await _frames(3)
	_check(drawer.is_open() and state.enter_blocks.size() == 4
		and history.get_version() == old_version + 2
		and not is_instance_valid(editor.find_child(
			"PotokStructureDeleteDialog", true, false)),
		"Escape cancels phase deletion without exiting Fluo")
	list = _list("Enter")
	_check(list != null and list.has_focus(),
		"Cancel by Escape returns keyboard focus to owning phase list")
	delete_button = _button("Enter", "Delete")
	delete_button.pressed.emit()
	await _frames(3)
	dialog = editor.find_child("PotokStructureDeleteDialog", true, false) as ConfirmationDialog
	if dialog != null:
		dialog.confirmed.emit()
	await _frames(5)
	_check(state.enter_blocks.size() == 3 and state.enter_blocks[0] == null
		and state.enter_blocks[1] == another and state.enter_blocks[2] == original,
		"Confirmed Delete removes selected copy only and keeps null/other phases")
	history.undo()
	_check(state.enter_blocks.size() == 4 and state.enter_blocks[3] == copy,
		"Undo restores deleted UI resource and ID")
	_check(state.blocks.size() == 1 and state.exit_blocks.size() == 1
		and not FlowGraphValidator.validate(graph).has_errors(),
		"Other phases remain valid")
	await _finish()


func _list(phase: String) -> ItemList:
	return drawer.find_child("PotokPhase" + phase + "BlocksList", true, false) as ItemList


func _button(phase: String, action: String) -> Button:
	return drawer.find_child("PotokPhase" + phase + action, true, false) as Button


func _frames(n: int) -> void:
	for i: int in n:
		await process_frame


func _check(value: bool, reason: String) -> bool:
	if not value:
		failures.append(reason)
		push_error("[Flujo] Potok 7F-1C2D UI: " + reason)
	return value


func _finish() -> void:
	if drawer != null:
		drawer.close()
		drawer.set_controller(null)
		drawer.queue_free()
	if host != null:
		host.queue_free()
	await _frames(4)
	if failures.is_empty():
		print("[Flujo] Potok 7F-1C2D native phase action UI passed")
	quit(0 if failures.is_empty() else 1)
